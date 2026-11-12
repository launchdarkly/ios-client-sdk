import Foundation
@preconcurrency import LaunchDarkly

/// Starts, restarts and reports on the `LDClient` the app uses, with a second environment where the build gives a key.
///
/// Every button acts on the selected environment's client, which is nil while a restart is under way, so a tap
/// meanwhile does nothing rather than reaching a client that is closing. Some calls reach every environment whichever
/// client they are made on: `flush`, `flushAndWait`, `setOnline`, `identify` and `close`.
@MainActor
final class ClientController: ObservableObject {
    static let defaultUserKey = "user key"

    // Two hooks with different windows, to show that each one is deduplicated on its own.
    static let fastDedupeWindow: TimeInterval = 5
    static let slowDedupeWindow: TimeInterval = 10

    /// How long starting waits for the first flags before going on with whatever is cached.
    private nonisolated static let startWaitSeconds: TimeInterval = 10

    private static let persistenceKey = "eventPersistence"
    private static let environmentKey = "selectedEnvironment"
    private static let defaultPersistence = EventPersistence.immediate

    let configuration = TestAppConfiguration.current

    /// Saved rather than held in memory: the kill and crash scenarios are only answered on the next launch, and that
    /// launch has to read the disk the same way. Under `.disabled` the events a dead process left there are not
    /// delivered.
    @Published private(set) var persistence: EventPersistence
    /// Saved too, so the launch that answers a kill scenario shows the environment it was run against.
    @Published private(set) var environment: TestEnvironment
    @Published private(set) var isOffline = false
    @Published private(set) var isRestarting = false
    @Published private(set) var connectionStatus = "Not started"
    @Published private(set) var dedupeStatus = ""
    @Published var result = ""

    private(set) var evaluationsRequested = 0

    /// Flags each running client already reports changes of, so evaluating one again does not add another observer.
    private var observedFlags: [TestEnvironment: Set<String>] = [:]

    /// What the running client was started with, for the scenarios that depend on its limits.
    private(set) var config: LDConfig?

    private lazy var fastHook = ExposureCountingHook(label: "fast") { [weak self] in self?.dedupeStatusChanged() }
    private lazy var slowHook = ExposureCountingHook(label: "slow") { [weak self] in self?.dedupeStatusChanged() }

    /// Closing waits on the event store and starting on the first flags, so both happen here rather than on the main
    /// thread, one at a time.
    private let lifecycleQueue = DispatchQueue(label: "com.launchdarkly.testapp.client-lifecycle")

    init() {
        let saved = UserDefaults.standard.object(forKey: Self.persistenceKey) as? Int
        persistence = saved.flatMap(EventPersistence.init(rawValue:)) ?? Self.defaultPersistence
        let available = TestAppConfiguration.current.environments
        let savedEnvironment = UserDefaults.standard.string(forKey: Self.environmentKey).flatMap(TestEnvironment.init)
        environment = savedEnvironment.flatMap { available.contains($0) ? $0 : nil } ?? .primary
        refreshDedupeStatus()
    }

    var client: LDClient? {
        client(for: environment)
    }

    func client(for environment: TestEnvironment) -> LDClient? {
        isRestarting ? nil : LDClient.get(environment: environment.sdkName)
    }

    var mobileKey: String {
        configuration.mobileKey(for: environment)
    }

    func select(_ chosen: TestEnvironment) {
        guard chosen != environment, configuration.environments.contains(chosen)
        else { return }
        environment = chosen
        UserDefaults.standard.set(chosen.rawValue, forKey: Self.environmentKey)
        refreshConnectionStatus()
    }

    func start() {
        guard !configuration.isMissingMobileKey, config == nil
        else {
            if configuration.isMissingMobileKey {
                result = "Set LAUNCHDARKLY_MOBILE_KEY in TestApp/Config/Secrets.xcconfig and rebuild."
            }
            return
        }
        restart(reason: "Started")
    }

    func setPersistence(_ chosen: EventPersistence) {
        guard chosen != persistence
        else { return }
        persistence = chosen
        UserDefaults.standard.set(chosen.rawValue, forKey: Self.persistenceKey)
        restart(reason: "Restarted with \(chosen.name)")
    }

    func setOffline(_ offline: Bool) {
        isOffline = offline
        client?.setOnline(!offline) { [weak self] in
            Task { @MainActor in self?.refreshConnectionStatus() }
        }
    }

    /// Closes the client and starts another, which is also what recovers the logs another instance left when it was
    /// killed: recovery runs as a client starts.
    ///
    /// The replacement starts in the offline toggle's state rather than being switched after it starts, because
    /// starting waits for flags, and a client online for that long can deliver the events stored before the change.
    func restart(reason: String = "Restarted") {
        guard !configuration.isMissingMobileKey, !isRestarting
        else { return }
        isRestarting = true
        let config = makeConfig()
        let context = Self.context(key: Self.defaultUserKey)
        let environments = configuration.environments
        lifecycleQueue.async {
            if let previous = LDClient.get() {
                for environment in environments {
                    LDClient.get(environment: environment.sdkName)?.stopObserving(owner: self)
                }
                // Closes every environment.
                previous.close()
            }
            LDClient.start(config: config, context: context, startWaitSeconds: Self.startWaitSeconds) { timedOut in
                Task { @MainActor in
                    self.config = config
                    self.observedFlags.removeAll()
                    self.isRestarting = false
                    self.observeConnection()
                    // Starting offline also reports a timeout, without waiting for anything.
                    if !config.startOnline {
                        self.result = "\(reason) offline"
                    } else {
                        self.result = timedOut ? "\(reason); flags did not arrive in time" : reason
                    }
                }
            }
        }
    }

    func identify(key typed: String) {
        let key = typed.trimmingCharacters(in: .whitespaces)
        // An empty key builds an invalid context, which identify rejects before it resets the hooks' dedupe caches.
        // Falling back to the key the client started with still demonstrates that the reset happens either way.
        client?.identify(context: Self.context(key: key.isEmpty ? Self.defaultUserKey : key)) { [weak self] result in
            Task { @MainActor in
                self?.result = "Identify: \(result)"
                self?.refreshDedupeStatus()
            }
        }
    }

    func countEvaluation() {
        evaluationsRequested += 1
        refreshDedupeStatus()
    }

    /// Calls `changed` with the key of a flag and the environment it is in each time its value changes, from the first
    /// call for that key in the selected environment on.
    func observeFlag(_ key: String, changed: @escaping @MainActor (String, TestEnvironment) -> Void) {
        let environment = self.environment
        guard let client, observedFlags[environment, default: []].insert(key).inserted
        else { return }
        client.observe(key: key, owner: self) { change in
            Task { @MainActor in changed(change.key, environment) }
        }
    }

    func refreshConnectionStatus() {
        guard let info = client?.getConnectionInformation()
        else {
            connectionStatus = isRestarting ? "Restarting" : "Not started"
            return
        }
        var status = "\(info.currentConnectionMode.rawValue) · flags \(info.lastKnownFlagValidity.map(Self.format) ?? "never")"
        if let failed = info.lastFailedConnection {
            status += "\nfailed \(Self.format(failed)): \(info.lastConnectionFailureReason)"
        }
        connectionStatus = status
    }

    /// Every environment, not only the selected one, so switching shows the other's status without observing it again.
    private func observeConnection() {
        refreshConnectionStatus()
        for environment in configuration.environments {
            client(for: environment)?.observeCurrentConnectionMode(owner: self) { [weak self] _ in
                Task { @MainActor in self?.refreshConnectionStatus() }
            }
        }
    }

    private func makeConfig() -> LDConfig {
        var config = LDConfig(mobileKey: configuration.mobileKey, autoEnvAttributes: .enabled)
        if configuration.hasSecondaryEnvironment {
            do {
                try config.setSecondaryMobileKeys([TestEnvironment.secondary.sdkName: configuration.secondaryMobileKey])
            } catch {
                print("secondary environment not started: \(error)")
            }
        }
        config.startOnline = !isOffline
        config.eventPersistence = persistence
        // Same shape an application uses for any hook: wrap it at registration. Each wrapper has its own window, so
        // neither suppresses the other.
        config.hooks = [
            DedupingHook(fastHook, window: Self.fastDedupeWindow),
            DedupingHook(slowHook, window: Self.slowDedupeWindow),
        ]
        configuration.applyEndpoints(to: &config)
        return config
    }

    private nonisolated func dedupeStatusChanged() {
        Task { @MainActor in self.refreshDedupeStatus() }
    }

    private func refreshDedupeStatus() {
        dedupeStatus = """
            evaluations \(evaluationsRequested)
            \(fastHook.status(window: Self.fastDedupeWindow)) · \(slowHook.status(window: Self.slowDedupeWindow))
            """
    }

    static func context(key: String) -> LDContext {
        var builder = LDContextBuilder(key: key)
        builder.trySetValue("email", .string("fake@example.com"))
        switch builder.build() {
        case .success(let context):
            return context
        case .failure:
            // Only a key the builder refuses gets here; the default one never is.
            return try! LDContextBuilder(key: defaultUserKey).build().get()
        }
    }

    private static func format(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .standard)
    }
}

extension EventPersistence {
    static let choices: [EventPersistence] = [.disabled, .deferred, .immediate]

    var name: String {
        switch self {
        case .disabled: return "disabled"
        case .deferred: return "deferred"
        case .immediate: return "immediate"
        @unknown default: return "unknown"
        }
    }
}
