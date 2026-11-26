import Foundation
@preconcurrency import LaunchDarkly

/// Starts, restarts and reports on the `LDClient` the app uses, with a secondary and a deferred environment where the
/// build gives their keys.
///
/// Every button acts on the selected environment's client, which is nil while a restart is under way, so a tap
/// meanwhile does nothing rather than reaching a client that is closing. Some calls reach every environment whichever
/// client they are made on: `flush`, `flushAndWait`, `setOnline`, `identify` and `close`. A deferred environment takes
/// `setOnline` for its events and `identify` for its context and cached flags, but requests flags only once started.
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
    /// Whether the selected environment's client is deferred and not started yet.
    @Published private(set) var isDeferred = false
    @Published private(set) var loadStates: [TestEnvironment: LoadState] = [:]
    /// The environments that have their flags, in the order they got them, with how long each took from its request.
    @Published private(set) var loadOrder: [(environment: TestEnvironment, seconds: TimeInterval)] = []
    private var loadStartedAt: [TestEnvironment: Date] = [:]
    /// How many flags the selected environment's client holds, nil while there is no client.
    @Published private(set) var flagCount: Int?
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
        // The completion waits for every environment's flags but the deferred one's, which then follows.
        client?.setOnline(!offline) { [weak self] in
            Task { @MainActor in
                guard let self
                else { return }
                self.refreshConnectionStatus()
                if !self.isOffline {
                    self.startDeferredEnvironments()
                }
            }
        }
        if client != nil {
            beginLoading(configuration.environments, online: !offline)
        }
    }

    func loadState(of environment: TestEnvironment) -> LoadState {
        loadStates[environment] ?? .inactive
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
        loadStates.removeAll()
        loadOrder.removeAll()
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
                    self.refreshConnectionStatus()
                    // Starting offline also reports a timeout, without waiting for anything.
                    if !config.startOnline {
                        self.result = "\(reason) offline"
                    } else {
                        self.result = timedOut ? "\(reason); flags did not arrive in time" : reason
                        // As an app would: the less important environments once the others have their flags. Started
                        // offline, they wait for the toggle instead, so that they still load after them.
                        self.startDeferredEnvironments(after: self.result)
                    }
                }
            }
            // The clients exist once start returns, and their first flags are a request away, so observing now
            // catches every environment's first load rather than only those after the primary one's.
            Task { @MainActor in
                self.observeEnvironments()
                self.beginLoading(environments, online: config.startOnline)
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

    /// Starts every deferred environment, in the order they were added, each once the one before it has its flags, as
    /// an app would once the others have theirs. Does nothing once they are started. `earlier` heads the result line.
    private func startDeferredEnvironments(after earlier: String? = nil) {
        guard configuration.environments.contains(where: { LDClient.get(environment: $0.sdkName)?.isDeferred == true })
        else { return }
        let started = Date()
        let prefix = earlier.map { "\($0)\n" } ?? ""
        result = "\(prefix)Starting deferred environments…"
        LDClient.startDeferredEnvironments(startWaitSeconds: Self.startWaitSeconds) { [weak self] timedOut in
            let elapsed = Date().timeIntervalSince(started)
            Task { @MainActor in
                guard let self
                else { return }
                self.result = prefix + (timedOut
                    ? "Deferred environments started; not every one got its flags"
                    : String(format: "Deferred environments started; flags in %.2f s", elapsed))
                self.refreshConnectionStatus()
            }
        }
    }

    /// Starts the flag connection of the deferred environment by hand, which until now served only the flags cached on
    /// the device. Does nothing once it is started.
    func startDeferredEnvironment() {
        guard let client = client(for: .deferred), client.isDeferred
        else { return }
        let started = Date()
        result = "Starting \(TestEnvironment.deferred.title)…"
        defer { beginLoading([.deferred], online: !isOffline) }
        LDClient.start(environment: TestEnvironment.deferred.sdkName, startWaitSeconds: Self.startWaitSeconds) { [weak self] timedOut in
            let elapsed = Date().timeIntervalSince(started)
            Task { @MainActor in
                guard let self
                else { return }
                // Offline, it reports a timeout at once, and requests the flags when the app next goes online.
                self.result = timedOut
                    ? "\(TestEnvironment.deferred.title) started; flags did not arrive"
                    : String(format: "%@ started; flags in %.2f s", TestEnvironment.deferred.title, elapsed)
                self.refreshConnectionStatus()
            }
        }
        refreshConnectionStatus()
    }

    /// The flag count too, since it changes when flags arrive and when the client or the environment does.
    func refreshConnectionStatus() {
        flagCount = client?.allFlags?.count
        isDeferred = client?.isDeferred ?? false
        if isDeferred {
            connectionStatus = "deferred · cached flags only, until started"
            return
        }
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
    /// From `LDClient.get` rather than `client(for:)`, which is nil until the restart completes.
    private func observeEnvironments() {
        for environment in configuration.environments {
            guard let client = LDClient.get(environment: environment.sdkName)
            else { continue }
            client.observeCurrentConnectionMode(owner: self) { [weak self] _ in
                Task { @MainActor in self?.connectionModeChanged(in: environment) }
            }
            client.observeAll(owner: self) { [weak self] _ in
                Task { @MainActor in self?.flagsArrived(in: environment) }
            }
            client.observeFlagsUnchanged(owner: self) { [weak self] in
                Task { @MainActor in self?.flagsArrived(in: environment) }
            }
        }
    }

    /// Marks the environments that now request flags as loading, and the others, offline or deferred, as inactive.
    /// Takes the online state rather than reading it, since `setOnline` may apply it later.
    private func beginLoading(_ environments: [TestEnvironment], online: Bool) {
        for environment in environments {
            loadOrder.removeAll { $0.environment == environment }
            guard online, let client = LDClient.get(environment: environment.sdkName), !client.isDeferred
            else {
                loadStates[environment] = .inactive
                continue
            }
            loadStates[environment] = .loading
            loadStartedAt[environment] = Date()
        }
    }

    /// Catches a deferred environment starting its flag connection, whoever starts it, `startDeferredEnvironments` among them.
    private func connectionModeChanged(in environment: TestEnvironment) {
        refreshConnectionStatus()
        guard loadState(of: environment) == .inactive, !isOffline,
              let client = LDClient.get(environment: environment.sdkName), !client.isDeferred
        else { return }
        beginLoading([environment], online: true)
    }

    private func flagsArrived(in environment: TestEnvironment) {
        refreshConnectionStatus()
        guard loadStates[environment] == .loading
        else { return }
        loadStates[environment] = .loaded
        loadOrder.append((environment, loadStartedAt[environment].map { Date().timeIntervalSince($0) } ?? 0))
    }

    private func makeConfig() -> LDConfig {
        var config = LDConfig(mobileKey: configuration.mobileKey, autoEnvAttributes: .enabled)
        let filter = configuration.payloadFilter.isEmpty ? nil : configuration.payloadFilter
        config.payloadFilter = filter
        for environment in configuration.environments where environment != .primary {
            do {
                try config.addSecondaryEnvironment(environment.sdkName,
                                                   mobileKey: configuration.mobileKey(for: environment),
                                                   payloadFilter: filter,
                                                   deferred: environment == .deferred)
            } catch {
                print("\(environment.sdkName) environment not started: \(error)")
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

/// Whether an environment has its flags, as the dot beside its name in the environment picker shows.
enum LoadState {
    /// No client, offline, or deferred and not started, so no flags requested.
    case inactive
    /// Flags requested, and none arrived yet.
    case loading
    /// Flags arrived, or the server confirmed the cached ones, since the last request.
    case loaded

    var dot: String {
        switch self {
        case .inactive: return "⚪️"
        case .loading: return "🟡"
        case .loaded: return "🟢"
        }
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
