//
//  LDClient.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

enum LDClientRunMode {
    case foreground, background
}

public class LDClient {
    public static let shared = LDClient()
    
    ///Tells the online/offline state of the LDClient. Use setOnline to change the online/offline state
    public private (set) var isOnline: Bool = false {
        didSet {
            flagSynchronizer.isOnline = isOnline
            eventReporter.isOnline = isOnline
        }
    }

    //Keeps the state of the last setOnline goOnline parameter
    private var lastSetOnlineCallValue = false

    /**
     * Set the LDClient to online/offline mode. When online, the LDClient will sync events to the server. (Default)
     *
     * - parameter goOnline:    Desired online/offline mode for the client
     * - parameter completion:  Completion closure called when setOnline completes (Optional)
     */
    public func setOnline(_ goOnline: Bool, completion: (() -> Void)? = nil) {
        lastSetOnlineCallValue = goOnline
        guard goOnline, canGoOnline
        else {
            //go offline, which is not throttled
            go(online: false, reasonOnlineUnavailable: reasonOnlineUnavailable(goOnline: goOnline), completion: completion)
            return
        }

        throttler.runThrottled {
            //since going online was throttled, check the last called setOnline value and whether we can go online
            self.go(online: self.lastSetOnlineCallValue && self.canGoOnline, reasonOnlineUnavailable: self.reasonOnlineUnavailable(goOnline: self.lastSetOnlineCallValue), completion: completion)
        }
    }

    private var canGoOnline: Bool {
        return hasStarted && isInSupportedRunMode
    }

    private var isInSupportedRunMode: Bool {
        return runMode == .foreground || config.enableBackgroundUpdates
    }

    private func go(online goOnline: Bool, reasonOnlineUnavailable: String, completion:(() -> Void)?) {
        isOnline = goOnline
        Log.debug(typeName(and: "setOnline", appending: ": \(self.isOnline).") + reasonOnlineUnavailable)
        completion?()
    }

    private func reasonOnlineUnavailable(goOnline: Bool) -> String {
        if !goOnline { return "" }
        if !hasStarted { return " LDClient not started." }
        if !isInSupportedRunMode { return " LDConfig background updates not enabled." }
        return ""
    }

    ///Takes the client offline and reconfigures using the new config. If the client was online, it brings the client online again.
    ///Make config changes by getting the config from the client, adjusting values, and then setting the new config
    ///If the config is unchanged, returns immediately.
    ///Usage:
    ///     LDClient.shared.config = newConfig
    public var config: LDConfig {
        didSet {
            guard config != oldValue else {
                Log.debug(typeName(and: #function) + "aborted. New config matches old config")
                return
            }

            Log.level = environmentReporter.isDebugBuild && config.isDebugMode ? .debug : .noLogging
            Log.debug(typeName(and: #function) + "new config set")
            let wasOnline = isOnline
            setOnline(false)

            service = serviceFactory.makeDarklyServiceProvider(mobileKey: mobileKey, config: config, user: user)
            eventReporter.config = config

            setOnline(wasOnline)
        }
    }
    
    ///The LDUser set into the LDClient controls the set of feature flags returned by the LD server, and ties event tracking to the user.
    ///Setting the user takes the client offline and configures for the new user. If the client was online, it brings the client online again.
    ///Make user changes by getting the user from the client, adjusting values, and then setting the new user
    ///Usage:
    ///     LDClient.shared.user = newUser
    public var user: LDUser {
        didSet {
            Log.debug(typeName(and: #function) + "new user set with key: " + user.key )
            let wasOnline = isOnline
            setOnline(false)

            if let cachedFlags = flagCache.retrieveFlags(for: user), !cachedFlags.flags.isEmpty {
                user.flagStore.replaceStore(newFlags: cachedFlags.flags, source: .cache, completion: nil)
            }
            service = serviceFactory.makeDarklyServiceProvider(mobileKey: mobileKey, config: config, user: user)

            if hasStarted {
                eventReporter.recordSummaryEvent()
                eventReporter.record(Event.identifyEvent(user: user))
            }

            setOnline(wasOnline)
        }
    }

    private(set) var service: DarklyServiceProvider {
        didSet {
            Log.debug(typeName(and: #function) + "new service set")
            eventReporter.service = service
            flagSynchronizer = serviceFactory.makeFlagSynchronizer(streamingMode: effectiveStreamingMode(runMode: runMode, config: config),
                                                                   pollingInterval: config.flagPollingInterval(runMode: runMode),
                                                                   useReport: config.useReport,
                                                                   service: service,
                                                                   onSyncComplete: onSyncComplete)
        }
    }

    private(set) var hasStarted = false
    // MARK: - Public
    
    ///Starts the LDClient using the passed in mobile key, config, & user
    ///Starting the LDClient means setting the config & user, taking the client online if config.startOnline is true (the default setting), and starting event recording
    ///Uses the previously set config and user if those parameters are not included. If a config or user was not previously set, uses a default config or user
    ///Usage:
    ///     LDClient.shared.start(mobileKey: appMobileKey, config: appConfig, user: appUser)
    ///Call this before you want to capture feature flags. The LDClient will not go online until you call this method.
    ///Subsequent calls to this method cause the LDClient to go offline, reconfigure using the new config & user (if supplied), and then go online if it was online when start was called
    public func start(mobileKey: String, config: LDConfig? = nil, user: LDUser? = nil, completion: (() -> Void)? = nil) {
        Log.debug(typeName(and: #function, appending: ": ") + "starting")
        let wasStarted = hasStarted
        let wasOnline = isOnline
        hasStarted = true

        setOnline(false)

        self.mobileKey = mobileKey
        self.config = config ?? self.config
        self.user = user ?? self.user

        setOnline((wasStarted && wasOnline) || (!wasStarted && self.config.startOnline)) {
            Log.debug(self.typeName(and: #function, appending: ": ") + "started")
            completion?()
        }
    }

    private func effectiveStreamingMode(runMode: LDClientRunMode, config: LDConfig) -> LDStreamingMode {
        var reason = ""
        let streamingMode: LDStreamingMode = (runMode == .foreground || config.enableBackgroundUpdates) && config.streamingMode == .streaming && config.allowStreamingMode ? .streaming : .polling
        if config.streamingMode == .streaming && runMode != .foreground && !config.enableBackgroundUpdates {
            reason = " LDClient is in background mode with background updates disabled."
        }
        if reason.isEmpty && config.streamingMode == .streaming && !config.allowStreamingMode {
            reason = " LDConfig disallowed streaming mode. "
            reason += !environmentReporter.operatingSystem.isStreamingEnabled ? "Streaming is not allowed on \(environmentReporter.operatingSystem)." : "Unknown reason."
        }
        Log.debug(typeName(and: #function, appending: ": ") + "\(streamingMode)\(reason)")
        return streamingMode
    }

    ///Stops the LDClient. Stopping the client means take the client offline and stop recording events.
    ///Usage:
    ///     LDClient.shared.stop()
    ///After the client has stopped, variation requests will be answered with the last received feature flags.
    public func stop() {
        Log.debug(typeName(and: #function, appending: "- ") + "stopping")
        setOnline(false)
        hasStarted = false
        Log.debug(typeName(and: #function, appending: "- ") + "stopped")
    }
    
    /* Event tracking
     Conceptual model
     The LDClient appears to keep an event dictionary that it transmits periodically to LD. An app sends an event and optional data by calling trackEvent(key:, data:) supplying at least the key.
    */
    ///Adds an event to the LDClient event store. LDClient periodically transmits events to LD based on the frequency set in LDConfig.eventFlushIntervalMillis.
    ///Usage:   LDClient.shared.trackEvent(key: "app-event-key", data: appEventData)
    ///Once an app has called trackEvent(), the app cannot remove the event from the event store.
    ///If the client is offline, the client stores the event until the app takes the client online, and the client has transmitted the event.
    public func trackEvent(key: String, data: [String: Any]? = nil) {
        guard hasStarted else {
            Log.debug(typeName(and: #function) + "aborted. LDClient not started")
            return
        }
        let event = Event.customEvent(key: key, user: user, data: data)
        Log.debug(typeName(and: #function) + "event: \(event), data: \(String(describing: data))")
        eventReporter.record(event)
    }
    
    // MARK: Feature Flag values
    
    /* FF Value Requests
     Conceptual Model
     The LDClient is the focal point for flag value requests. It should appear to the app that the client contains a store of [key: value] pairs where the keys are all strings and the values any of the supported LD flag types (Bool, Int, Double, String, Array, Dictionary).
     When asked for a variation value, the LDClient provides either the value, or the value and LDVariationSource as a tuple.
    */
    
    ///Usage
    ///
    /// let boolFeatureFlagValue = LDClient.shared.variation(forKey: "bool-flag-key", fallback: false) //boolFeatureFlagValue is a Bool
    ///
    /// Pay close attention to the type of the fallback value for collections. If the fallback collection type is more restrictive than the feature flag, the sdk will return the fallback even though the
    /// feature flag is present because it cannot convert the feature flag into the type requested via the fallback value.
    ///
    /// For example, if the feature flag has the type [LDFlagKey: Any], but the fallback has the type [LDFlagKey: Int], the sdk will not be able to convert the flags into the requested type,
    /// and will return the fallback value.
    ///
    /// To avoid this, make sure the fallback type matches the expected feature flag type. Either specify the fallback value type to be the feature flag type, or cast the fallback value to the feature
    /// flag type prior to making the variation request
    ///
    /// In the above example, either specify that the fallback value's type is [LDFlagKey: Any]:
    ///
    ///     let fallbackValue: [LDFlagKey: Any] = ["a": 1, "b": 2]
    ///
    /// or cast the fallback value into the feature flag type prior to calling variation:
    ///
    ///     let dictionaryFlagValue = LDClient.shared.variation(forKey: "dictionary-key", fallback: ["a": 1, "b": 2] as [LDFlagKey: Any])
    public func variation<T: LDFlagValueConvertible>(forKey flagKey: LDFlagKey, fallback: T) -> T {
        guard hasStarted
        else {
            Log.debug(typeName(and: #function) + "returning fallback: \(fallback)." + " LDClient not started.")
            return fallback
        }
        let featureFlag = user.flagStore.featureFlag(for: flagKey)
        let value: T = self.value(from: featureFlag, fallback: fallback)
        Log.debug(typeName(and: #function) + "flagKey: \(flagKey), value: \(value), fallback: \(fallback), featureFlag: \(String(describing: featureFlag))")
        eventReporter.recordFlagEvaluationEvents(flagKey: flagKey, value: value, defaultValue: fallback, featureFlag: featureFlag, user: user)
        return value
    }

    ///Usage
    ///
    /// let (boolFeatureFlagValue, boolFeatureFlagSource) = LDClient.shared.variationAndSource(forKey: "bool-flag-key", fallback: false)    //boolFeatureFlagValue is a Bool
    ///
    /// Pay close attention to the type of the fallback value for collections. If the fallback collection type is more restrictive than the feature flag, the sdk will return the fallback even though the
    /// feature flag is present because it cannot convert the feature flag into the type requested via the fallback value.
    ///
    /// For example, if the feature flag has the type [LDFlagKey: Any], but the fallback has the type [LDFlagKey: Int], the sdk will not be able to convert the flags into the requested type,
    /// and will return the fallback value.
    ///
    /// To avoid this, make sure the fallback type matches the expected feature flag type. Either specify the fallback value type to be the feature flag type, or cast the fallback value to the feature
    /// flag type prior to making the variation request
    ///
    /// In the above example, either specify that the fallback value's type is [LDFlagKey: Any]:
    ///
    ///     let fallbackValue: [LDFlagKey: Any] = ["a": 1, "b": 2]
    ///
    /// or cast the fallback value into the feature flag type prior to calling variation:
    ///
    ///     let (dictionaryFlagValue, dictionaryFeatureFlagSource) = LDClient.shared.variationAndSource(forKey: "dictionary-key", fallback: ["a": 1, "b": 2] as [LDFlagKey: Any])
    public func variationAndSource<T: LDFlagValueConvertible>(forKey flagKey: LDFlagKey, fallback: T) -> (T, LDFlagValueSource) {
        guard hasStarted
        else {
            Log.debug(typeName(and: #function) + "returning fallback: \(fallback), source: \(LDFlagValueSource.fallback)." + " LDClient not started.")
            return (fallback, .fallback)
        }
        let (featureFlag, flagStoreSource) = user.flagStore.featureFlagAndSource(for: flagKey)
        let source = flagStoreSource ?? .fallback
        let value: T = self.value(from: featureFlag, fallback: fallback)
        Log.debug(typeName(and: #function) + "flagKey: \(flagKey), value: \(value), fallback: \(fallback), featureFlag: \(String(describing: featureFlag)), source: \(source)")
        eventReporter.recordFlagEvaluationEvents(flagKey: flagKey, value: value, defaultValue: fallback, featureFlag: featureFlag, user: user)
        return (value, source)
    }

    private func value<T>(from featureFlag: FeatureFlag?, fallback: T) -> T {
        return featureFlag?.value as? T ?? fallback
    }

    // MARK: Feature Flag Updates
    
    /* FF Change Notification
     Conceptual Model
     LDClient keeps a list of two types of closure observers, either Flag Change Observers or Flags Unchanged Observers.
     There are 3 types of Flag Change Observers, Individual Flag Change Observers, Flag Collection Change Observers, and All Flags Change Observers. LDClient executes Individual Flag observers when it detects a change to a single flag being observed. LDClient executes Flag Collection Change Observers one time when it detects a change to any flag in the observed flag collection. LDClient executes All Flags observers one time when it detects a change to any flag. The Individual Flag Change Observer has closure that takes a LDChangedFlag input parameter which communicates the flag's old & new value. Flag Collection and All Flags Observers will have a closure that takes a dictionary of [LDFlagKey: LDChangeFlag] that communicates all of the changed flags.
     An app registers an Individual Flag observer using observe(key:, owner:, handler:). An app registers a Flag Collection Observer using observe(keys: owner: handler), An app registers an All Flags observer using observeAll(owner:, handler:). An app can register multiple closures for each type by calling these methods multiple times. When the value of a flag changes, LDClient calls each registered closure 1 time.
     Flags Unchanged Observers allow the LDClient to communicate to the app when it receives flags from the LD server that doesn't change any values from what the LDClient had already. For example, at launch the LDClient restores cached flag values before requesting flags from the LD server. If there has been no change to the flag values, the LDClient will execute the Flags Unchanged Observers that the app has registered. An app registers a Flags Unchanged Observer using observeFlagsUnchanged(owner: handler:).
     LDClient will automatically remove observers when the owner is nil. This means an app does not need to stop observing flags, the LDClient will remove the observer after it has gone out of scope. An app can stop observers explicitly using stopObserver(owner:).
     LDClient executes observers on the main thread.
    */
    
    ///Usage
    ///     LDClient.shared.observe("flag-key", owner: self, observer: { [weak self] (changedFlag) in
    ///         if let oldValue = Bool(changedFlag.oldValue) {
    ///             //do something with the oldValue. oldValue & newValue have constructors that take an LDFlagValue for any of the LD supported types
    ///         }
    ///         if let newValue = changedFlag.newValue?.baseValue as? Bool {
    ///             //do something with the newValue. oldValue & newValue can be converted to their base value and cast to their LD supported type
    ///         }
    ///     }
    ///LDClient keeps a weak reference to the owner. Apps should keep only weak references to self in observers to avoid memory leaks
    public func observe(_ key: LDFlagKey, owner: LDFlagChangeOwner, handler: @escaping LDFlagChangeHandler) {
        Log.debug(typeName(and: #function) + "flagKey: \(key), owner: \(String(describing: owner))")
        flagChangeNotifier.addFlagChangeObserver(FlagChangeObserver(key: key, owner: owner, flagChangeHandler: handler))
    }
    
    ///Usage
    ///     LDClient.shared.observe(flagKeys, owner: self, observer: { (changedFlags) in
    ///         //There will be an LDChangedFlag entry in changedFlags for each changed flag. The closure will only be called once regardless of how many flags changed.
    ///         if let someChangedFlag = changedFlags["some-flag-key"] {
    ///             //do something with someChangedFlag
    ///         }
    ///     }
    /// changedFlags is a [LDFlagKey: LDChangedFlag]
    public func observe(_ keys: [LDFlagKey], owner: LDFlagChangeOwner, handler: @escaping LDFlagCollectionChangeHandler) {
        Log.debug(typeName(and: #function) + "flagKeys: \(keys), owner: \(String(describing: owner))")
        flagChangeNotifier.addFlagChangeObserver(FlagChangeObserver(keys: keys, owner: owner, flagCollectionChangeHandler: handler))
    }

    ///Usage
    ///     LDClient.shared.observeAll(owner: self, observer: { (changedFlags) in
    ///         //There will be an LDChangedFlag entry in changedFlags for each changed flag. The closure will only be called once regardless of how many flags changed.
    ///         if let someChangedFlag = changedFlags["some-flag-key"] {
    ///             //do something with someChangedFlag
    ///         }
    ///     }
    /// changedFlags is a [LDFlagKey: LDChangedFlag]
    public func observeAll(owner: LDFlagChangeOwner, handler: @escaping LDFlagCollectionChangeHandler) {
        Log.debug(typeName(and: #function) + " owner: \(String(describing: owner))")
        flagChangeNotifier.addFlagChangeObserver(FlagChangeObserver(keys: LDFlagKey.anyKey, owner: owner, flagCollectionChangeHandler: handler))
    }
    
    ///Sets a handler called when a flag update leaves the flags unchanged from their previous values.
    public func observeFlagsUnchanged(owner: LDFlagChangeOwner, handler: @escaping LDFlagsUnchangedHandler) {
        Log.debug(typeName(and: #function) + " owner: \(String(describing: owner))")
        flagChangeNotifier.addFlagsUnchangedObserver(FlagsUnchangedObserver(owner: owner, flagsUnchangedHandler: handler))
    }

    ///Removes all observers for the given owner, including the flagsUnchangedObserver
    public func stopObserving(owner: LDFlagChangeOwner) {
        Log.debug(typeName(and: #function) + " owner: \(String(describing: owner))")
        flagChangeNotifier.removeObserver(owner: owner)
    }

    ///Called if the client is unable to contact the server
    public var onServerUnavailable: (() -> Void)? = nil {
        didSet {
            Log.debug(typeName(and: #function, appending: ": ") + (onServerUnavailable == nil ? "<nil>" : "set"))
        }
    }

    private func onSyncComplete(result: SyncResult) {
        Log.debug(typeName(and: #function) + "result: \(result)")
        switch result {
        case let .success(flagDictionary, streamingEvent):
            let oldFlags = user.flagStore.featureFlags
            let oldFlagSource = user.flagStore.flagValueSource
            switch streamingEvent {
            case nil, .ping?, .put?:
                user.flagStore.replaceStore(newFlags: flagDictionary, source: .server) {
                    self.updateCacheAndReportChanges(flagCache: self.flagCache, changeNotifier: self.flagChangeNotifier, user: self.user, oldFlags: oldFlags, oldFlagSource: oldFlagSource)
                }
            case .patch?:
                user.flagStore.updateStore(updateDictionary: flagDictionary, source: .server) {
                    self.updateCacheAndReportChanges(flagCache: self.flagCache, changeNotifier: self.flagChangeNotifier, user: self.user, oldFlags: oldFlags, oldFlagSource: oldFlagSource)
                }
            case .delete?:
                user.flagStore.deleteFlag(deleteDictionary: flagDictionary) {
                    self.updateCacheAndReportChanges(flagCache: self.flagCache, changeNotifier: self.flagChangeNotifier, user: self.user, oldFlags: oldFlags, oldFlagSource: oldFlagSource)
                }
            default: break
            }
        case let .error(synchronizingError):
            if synchronizingError.isClientUnauthorized {
                Log.debug(typeName(and: #function) + "LDClient is unauthorized")
                setOnline(false)
            }
            executeCallback(onServerUnavailable)
        }
    }

    private func updateCacheAndReportChanges(flagCache: UserFlagCaching, changeNotifier: FlagChangeNotifying, user: LDUser, oldFlags: [LDFlagKey: FeatureFlag], oldFlagSource: LDFlagValueSource) {
        flagCache.cacheFlags(for: user)
        changeNotifier.notifyObservers(user: user, oldFlags: oldFlags, oldFlagSource: oldFlagSource)
    }

    private func executeCallback(_ callback: (() -> Void)?) {
        guard let callback = callback else { return }
        DispatchQueue.main.async {
            callback()
        }
    }

    // MARK: - Events
    ///The LDClient will report events on the LDConfig.eventFlushInterval and when the client app moves to the background. There should normally not be a need to call reportEvents.
    public func reportEvents() {
        eventReporter.reportEvents()
    }

    // MARK: - Foreground / Background notification
    @objc private func didEnterBackground() {
        Log.debug(typeName(and: #function))
        Thread.performOnMain {
            runMode = .background
        }
    }

    @objc private func willEnterForeground() {
        Log.debug(typeName(and: #function))
        Thread.performOnMain {
            runMode = .foreground
        }
    }

    // MARK: - Private
    private(set) var serviceFactory: ClientServiceCreating = ClientServiceFactory()
    private var mobileKey = ""

    private(set) var runMode: LDClientRunMode = .foreground {
        didSet {
            guard runMode != oldValue
            else {
                Log.debug(typeName(and: #function) + " aborted. Old runMode equals new runMode.")
                return
            }
            Log.debug(typeName(and: #function, appending: ": ") + "\(runMode)")
            if runMode == .background {
                eventReporter.reportEvents()
            }
            eventReporter.isOnline = isOnline && runMode == .foreground

            let willSetSynchronizerOnline = isOnline && isInSupportedRunMode
            //The only time the flag synchronizer configuration WILL match is if the client sets flag polling with the polling interval set to the background polling interval.
            //if it does match, keeping the synchronizer precludes an extra flag request
            if !flagSynchronizerConfigMatchesConfigAndRunMode {
                flagSynchronizer.isOnline = false
                flagSynchronizer = serviceFactory.makeFlagSynchronizer(streamingMode: effectiveStreamingMode(runMode: runMode, config: config),
                                                                       pollingInterval: config.flagPollingInterval(runMode: runMode),
                                                                       useReport: config.useReport,
                                                                       service: service,
                                                                       onSyncComplete: onSyncComplete)
            }
            flagSynchronizer.isOnline = willSetSynchronizerOnline
        }
    }
    private var flagSynchronizerConfigMatchesConfigAndRunMode: Bool {
        return flagSynchronizer.streamingMode == effectiveStreamingMode(runMode: runMode, config: config)
            && (flagSynchronizer.streamingMode == .streaming
                || flagSynchronizer.streamingMode == .polling && flagSynchronizer.pollingInterval == config.flagPollingInterval(runMode: runMode))
    }
    private var allowBackgroundFlagUpdates: Bool { return config.enableBackgroundUpdates && environmentReporter.operatingSystem.isBackgroundEnabled }

    private(set) var flagCache: UserFlagCaching
    private(set) var flagSynchronizer: LDFlagSynchronizing
    private(set) var flagChangeNotifier: FlagChangeNotifying
    private(set) var eventReporter: EventReporting
    private(set) var environmentReporter: EnvironmentReporting
    private(set) var throttler: Throttling

    private init(serviceFactory: ClientServiceCreating? = nil) {
        if let serviceFactory = serviceFactory {
            self.serviceFactory = serviceFactory
        }
        environmentReporter = self.serviceFactory.makeEnvironmentReporter()
        flagCache = self.serviceFactory.makeUserFlagCache()
        LDUserWrapper.configureKeyedArchiversToHandleVersion2_3_0AndOlderUserCacheFormat()
        self.serviceFactory.makeCacheConverter().convertUserCacheToFlagCache()
        flagChangeNotifier = self.serviceFactory.makeFlagChangeNotifier()
        throttler = self.serviceFactory.makeThrottler(maxDelay: Throttler.Constants.defaultDelay)

        //dummy objects replaced by client at start
        config = LDConfig(environmentReporter: environmentReporter)
        user = LDUser(environmentReporter: environmentReporter)
        service = self.serviceFactory.makeDarklyServiceProvider(mobileKey: "", config: config, user: user)
        flagSynchronizer = self.serviceFactory.makeFlagSynchronizer(streamingMode: .polling,
                                                                    pollingInterval: config.flagPollInterval,
                                                                    useReport: config.useReport,
                                                                    service: service,
                                                                    onSyncComplete: nil)
        eventReporter = self.serviceFactory.makeEventReporter(config: config, service: service)

        if let backgroundNotification = environmentReporter.backgroundNotification {
            NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: backgroundNotification, object: nil)
        }
        if let foregroundNotification = environmentReporter.foregroundNotification {
            NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: foregroundNotification, object: nil)
        }
    }

    private convenience init(serviceFactory: ClientServiceCreating, config: LDConfig, user: LDUser, runMode: LDClientRunMode) {
        self.init(serviceFactory: serviceFactory)
        //Setting these inside the init do not trigger the didSet closures
        self.runMode = runMode
        self.config = config
        self.user = user

        //dummy objects replaced by client at start
        service = self.serviceFactory.makeDarklyServiceProvider(mobileKey: "", config: config, user: user)  //didSet not triggered here
        flagSynchronizer = self.serviceFactory.makeFlagSynchronizer(streamingMode: effectiveStreamingMode(runMode: runMode, config: config),
                                                                    pollingInterval: config.flagPollingInterval(runMode: runMode),
                                                                    useReport: config.useReport,
                                                                    service: service,
                                                                    onSyncComplete: onSyncComplete)
        eventReporter = self.serviceFactory.makeEventReporter(config: config, service: service)
    }
}

extension LDClient: TypeIdentifying { }

#if DEBUG
    extension LDClient {
        class func makeClient(with serviceFactory: ClientServiceCreating, config: LDConfig, user: LDUser, runMode: LDClientRunMode = .foreground) -> LDClient {
            return LDClient(serviceFactory: serviceFactory, config: config, user: user, runMode: runMode)
        }

        func setRunMode(_ runMode: LDClientRunMode) {
            self.runMode = runMode
        }

        public var allFeatureFlagValues: [LDFlagKey: Any]? {
            guard hasStarted else { return nil }
            return user.flagStore.featureFlags.flatMapValues { (featureFlag) -> Any? in featureFlag.value }
        }
    }
#endif
