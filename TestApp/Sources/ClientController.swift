import Foundation
@preconcurrency import LaunchDarkly

/// Starts, restarts and reports on the one `LDClient` the app uses.
///
/// Every button acts on `LDClient.get()`, which is nil while a restart is under way, so a tap meanwhile does nothing
/// rather than reaching a client that is closing.
@MainActor
final class ClientController: ObservableObject {
    static let defaultUserKey = "user key"

    // Two hooks with different windows, to show that each one is deduplicated on its own.
    static let fastDedupeWindow: TimeInterval = 5
    static let slowDedupeWindow: TimeInterval = 10

    /// How long starting waits for the first flags before going on with whatever is cached.
    private nonisolated static let startWaitSeconds: TimeInterval = 10

    private static let persistenceKey = "eventPersistence"
    private static let defaultPersistence = EventPersistence.immediate

    let configuration = TestAppConfiguration.current

    /// Saved rather than held in memory: the kill and crash scenarios are only answered on the next launch, and that
    /// launch has to read the disk the same way. Under `.disabled` the events a dead process left there are not
    /// delivered.
    @Published private(set) var persistence: EventPersistence
    @Published private(set) var isOffline = false
    @Published private(set) var isRestarting = false
    @Published private(set) var connectionStatus = "Not started"
    @Published private(set) var dedupeStatus = ""
    @Published var result = ""

    private(set) var evaluationsRequested = 0

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
        refreshDedupeStatus()
    }

    var client: LDClient? {
        isRestarting ? nil : LDClient.get()
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
        lifecycleQueue.async {
            if let previous = LDClient.get() {
                previous.stopObserving(owner: self)
                previous.close()
            }
            LDClient.start(config: config, context: context, startWaitSeconds: Self.startWaitSeconds) { timedOut in
                Task { @MainActor in
                    self.config = config
                    self.isRestarting = false
                    self.observeConnection()
                    self.result = timedOut ? "\(reason); flags did not arrive in time" : reason
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

    private func observeConnection() {
        refreshConnectionStatus()
        client?.observeCurrentConnectionMode(owner: self) { [weak self] _ in
            Task { @MainActor in self?.refreshConnectionStatus() }
        }
    }

    private func makeConfig() -> LDConfig {
        var config = LDConfig(mobileKey: configuration.mobileKey, autoEnvAttributes: .enabled)
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
