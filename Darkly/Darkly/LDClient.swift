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
    
    private var _isOnline = false {
        didSet {
            flagSynchronizer.isOnline = isOnline
            eventReporter.isOnline = isOnline
        }
    }

    ///Controls whether client contacts launch darkly for feature flags and events. When offline, client only collects events.
    public var isOnline: Bool {
        set { _isOnline = hasStarted && newValue && (runMode != .background || config.enableBackgroundUpdates)}
        get { return _isOnline }
    }
    
    ///Takes the client offline and reconfigures using the new config. If the client was online, it brings the client online again.
    ///Make config changes by getting the config from the client, adjusting values, and then setting the new config
    ///If the config is unchanged, returns immediately.
    ///Usage:
    ///     LDClient.shared.config = newConfig
    public var config = LDConfig() {
        didSet {
            guard config != oldValue else { return }

            let wasOnline = isOnline
            isOnline = false

            service = serviceFactory.makeDarklyServiceProvider(mobileKey: mobileKey, config: config, user: user)
            flagSynchronizer = serviceFactory.makeFlagSynchronizer(mobileKey: mobileKey,
                                                                   streamingMode: effectiveStreamingMode(runMode: runMode),
                                                                   pollingInterval: config.flagPollingInterval(runMode: effectiveRunMode),
                                                                   service: service,
                                                                   store: user.flagStore)

            self.isOnline = wasOnline
        }
    }
    
    ///The LDUser set into the LDClient controls the set of feature flags returned by the LD server, and ties event tracking to the user.
    ///Setting the user takes the client offline and configures for the new user. If the client was online, it brings the client online again.
    ///Make user changes by getting the user from the client, adjusting values, and then setting the new user
    ///Usage:
    ///     LDClient.shared.user = newUser
    public var user = LDUser() {
        didSet {
            let wasOnline = isOnline
            isOnline = false

            service = serviceFactory.makeDarklyServiceProvider(mobileKey: mobileKey, config: config, user: user)
            if let cachedFlags = flagCache.retrieveFlags(for: user), !cachedFlags.isEmpty {
                user.flagStore.replaceStore(newFlags: cachedFlags, source: .cache)
            }
            flagSynchronizer = serviceFactory.makeFlagSynchronizer(mobileKey: mobileKey,
                                                                   streamingMode: effectiveStreamingMode(runMode: runMode),
                                                                   pollingInterval: config.flagPollingInterval(runMode: effectiveRunMode),
                                                                   service: service,
                                                                   store: user.flagStore)
            if hasStarted {
                eventReporter.record(LDEvent.identifyEvent(key: UUID().uuidString, user: user))
            }

            isOnline = wasOnline
        }
    }

    private(set) var service: DarklyServiceProvider {
        didSet {
            eventReporter.config = config
            eventReporter.service = service
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
    public func start(mobileKey: String, config: LDConfig? = nil, user: LDUser? = nil) {
        let wasStarted = hasStarted
        let wasOnline = isOnline
        hasStarted = true

        isOnline = false

        self.mobileKey = mobileKey
        self.config = config ?? self.config
        self.user = user ?? self.user

        self.isOnline = (wasStarted && wasOnline) || (!wasStarted && self.config.startOnline)
    }

    private func effectiveStreamingMode(runMode: LDClientRunMode) -> LDStreamingMode {
        return runMode == .foreground && self.config.streamingMode == .streaming ? .streaming : .polling
    }

    private var effectiveRunMode: LDClientRunMode {
        return config.enableBackgroundUpdates ? runMode : .foreground
    }

    ///Stops the LDClient. Stopping the client means take the client offline and stop recording events.
    ///Usage:
    ///     LDClient.shared.stop()
    ///After the client has stopped, variation requests will be answered with the last received feature flags.
    public func stop() {
        isOnline = false
        hasStarted = false
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
        guard hasStarted else { return }
        let event = LDEvent.customEvent(key: key, user: user, data: data)
        eventReporter.record(event)
    }
    
    // MARK: Feature Flag values
    
    /* FF Value Requests
     Conceptual Model
     The LDClient is the focal point for flag value requests. It should appear to the app that the client contains a store of [key: value] pairs where the keys are all strings and the values any of the supported LD flag types (Bool, number (int, float), String, Array, Dictionary). The LDFlaggable protocol defines the LD supported flag types.
     When asked for a variation value, the LDClient provides either the LDFlaggable value, or a (LDFlaggable, LDVariationSource) that reports the value and value source.
     
     At launch, the LDClient should ask the LDFlagCache to load the cached user's flags (if any) and then ask the flag synchronizer to start synchronizing (via streaming / polling)
    */
    
    ///Usage
    /// let boolFeatureFlagValue = LDClient.shared.variation(forKey: "bool-flag-key", fallback: false) //boolFeatureFlagValue is a Bool
    public func variation<T: LDFlagValueConvertible>(forKey key: String, fallback: T) -> T {
        return fallback
    }

    ///Usage
    /// let (boolFeatureFlagValue, boolFeatureFlagSource) = LDClient.shared.variationAndSource(forKey: "bool-flag-key", fallback: false)    //boolFeatureFlagValue is a Bool
    public func variationAndSource<T: LDFlagValueConvertible>(forKey key: String, fallback: T) -> (T, LDFlagValueSource) {
        return (fallback, .fallback)
    }
    
    // MARK: Feature Flag Updates
    
    /* FF Change Notification
     Conceptual Model
     LDClient keeps a list of two types of closure observers, either Individual Flag observers or All Flags observers. LDClient executes Individual Flag observers when it detects a change to that flag being observed. LDClient executes All Flags observers when it detects a change to any flag for the current LDUser. The closure has a LDChangedFlag input parameter that communicates the flag's old & new value. Individual Flag observers will have an LDChangedFlag passed into the parameter directly. All Flags observers will have a dictionary of [String: LDChangeFlag] that use the flag key as the dictionary key.
     An app registers an Individual Flag observer using observe(key:, owner:, observer:), or an All Flags observer using observeAll(owner:, observer:). An app can register multiple closures for each type by calling these methods multiple times. When the value of a flag changes, LDClient calls each registered closure 1 time.
     LDClient will automatically remove observer closures that cannot be executed. This means an app does not need to stop observing flags, the LDClient will remove the observer after it has gone out of scope. An app can stop observers explicitly using stopObserver(owner:).
    */
    
    ///Usage
    ///     LDClient.shared.observe("flag-key", owner: self, observer: { [weak self] (changedFlag) in
    ///         if let oldValue = Bool(changedFlag.oldValue) {
    ///             //do something with the oldValue. oldValue & newValue have constructors that take an LDFlagValue for any of the LD supported types
    ///         }
    ///         if let newValue = changedFlag.newValue?.baseValue as? Bool {
    ///             //do something with the newValue. oldValue & newValue can be converted to their base value and cast to their LD supported type
    ///         }
    ///          //client's change observing code here
    ///     }
    ///LDClient keeps a weak reference to the owner. Apps should keep only weak references to self in observers to avoid memory leaks
    public func observe(_ key: String, owner: LDFlagChangeOwner, observer: @escaping LDFlagChangeObserver) {

    }
    
    ///Usage
    ///     LDClient.shared.observeAll(owner: self, observer: { (changedFlags) in
    ///         //There will be an LDChangedFlag entry for each changed flag. The closure will only be called once regardless of how many flags changed.
    ///         if let someChangedFlag = changedFlags["some-flag-key"] {
    ///             //do something with someChangedFlag
    ///         }
    ///         //client's change observing code here
    ///     }
    /// changedFlags is a [String: LDChangedFlag] with this structure [<flagKey>: LDChangedFlag]
    public func observeAll(owner: LDFlagChangeOwner, observer: @escaping LDFlagCollectionChangeObserver) {

    }
    
    ///Removes all observers (both Individual Flag and All Flags) for the given owner
    public func stopObserving(owner: LDFlagChangeOwner) {
        
    }
    
    // MARK: - Private
    private var serviceFactory: ClientServiceCreating = ClientServiceFactory()
    private var mobileKey = ""

    private(set) var runMode: LDClientRunMode = .foreground

    private let flagCache = LDFlagCache()
    private(set) var flagSynchronizer: LDFlagSynchronizing
    private let flagChangeNotifier = LDFlagChangeNotifier()
    private(set) var eventReporter: LDEventReporting
    
    private init() {
        LDUserWrapper.configureKeyedArchiversToHandleVersion2_3_0AndOlderUserCacheFormat()
        flagCache.convertUserCacheToFlagCache()

        //dummy objects replaced by start call
        service = serviceFactory.makeDarklyServiceProvider(mobileKey: "", config: config, user: user)
        flagSynchronizer = serviceFactory.makeFlagSynchronizer(mobileKey: mobileKey, streamingMode: .polling, pollingInterval: config.flagPollInterval, service: service, store: user.flagStore)
        eventReporter = serviceFactory.makeEventReporter(mobileKey: "", config: config, service: service)
    }

    private convenience init(serviceFactory: ClientServiceCreating, runMode: LDClientRunMode) {
        self.init()
        self.runMode = runMode
        self.serviceFactory = serviceFactory

        //dummy objects replaced by start call
        service = serviceFactory.makeDarklyServiceProvider(mobileKey: "", config: config, user: user)
        flagSynchronizer = serviceFactory.makeFlagSynchronizer(mobileKey: mobileKey, streamingMode: .polling, pollingInterval: config.flagPollInterval, service: service, store: user.flagStore)
        eventReporter = serviceFactory.makeEventReporter(mobileKey: "", config: config, service: service)
    }
}

#if DEBUG
    extension LDClient {
        class func makeClient(with serviceFactory: ClientServiceCreating, runMode: LDClientRunMode = .foreground) -> LDClient {
            return LDClient(serviceFactory: serviceFactory, runMode: runMode)
        }
    }
#endif
