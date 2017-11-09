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
    
    ///Controls whether client contacts launch darkly for feature flags and events. When offline, client only collects events.
    private var _isOnline = false {
        didSet {
            flagSynchronizer.isOnline = isOnline
            eventReporter.isOnline = isOnline
        }
    }
    public var isOnline: Bool {
        set { _isOnline = hasStarted && newValue && (runMode != .background || config.enableBackgroundUpdates)}
        get { return _isOnline }
    }
    
    public private(set) var config = LDConfig()
    public private(set) var user = LDUser()
    private(set) var service: DarklyServiceProvider
    private(set) var flagStore: LDFlagMaintaining
    
    private(set) var hasStarted = false
    // MARK: - Public
    
    ///Starts the LDClient using the passed in mobile key, config, & user
    ///Uses the default config and a new user if those parameters are not included
    ///Usage:
    ///     LDClient.shared.start(mobileKey: appMobileKey, config: appConfig, user: appUser)
    ///Call this before you want to capture feature flags. The LDClient will not go online until you call this method.
    ///Subsequent calls to this method cause the LDClient to go offline, reconfigure using the new config & user (if supplied), and then go online
    public func start(mobileKey: String, config: LDConfig? = nil, user: LDUser? = nil) {
        let wasStarted = hasStarted
        hasStarted = true

        isOnline = false

        self.mobileKey = mobileKey
        change(config: config, user: user ?? userCache.retrieveLatest() ?? self.user)   //TODO: When implementing Client Management - User, make sure all 3 of these are tested

        self.isOnline = wasStarted || (!wasStarted && self.config.startOnline)
    }

    ///Changes the LDClient config and user.
    ///Takes the client offline and reconfigures using the new config & user. If the client was online, it brings the client online again.
    ///If the user was previously cached, uses the cached feature flags until the LDClient receives flags from the server. Otherwise, feature flag requests will result in the fallback value.
    ///NOTE: Even if the LDClient is online, there will be a brief delay before an update to the feature flags is available.
    ///If a client app wants to be notified when the LDClient receives the updated user flags, pass in a completion closure. The LDClient will call the closure once after the first feature flag update from the LD server. The closure will NOT be called when a cached user's flags have been retrieved. If the client is offline, the closure will not be called until the app sets the client online and the client has received the first flag update from the LD server.
    ///If the config and user are both unchanged or omitted, this does nothing (not even calling the completion closure).
    ///Usage:
    ///     LDClient.shared.change(config: newConfig, user: newUser) { [weak self] in
    ///         //client app code responding to the arrival of flags...
    ///         //self?.reload()
    ///     }
    ///If a client app doesn't want to be notified, omit the completion closure:
    ///     LDClient.shared.change(config: newConfig, user: newUser)
    ///You can make config and/or user changes by getting the config and/or user from the client, adjusting values, and then calling change(config:, user:)
    public func change(config: LDConfig? = nil, user: LDUser? = nil, completion: (() -> Void)? = nil) {
        guard config != nil || user != nil else { return }
        let targetConfig = config ?? self.config
        let targetUser = user ?? self.user
        //TODO: Implement this as part of ClientManagement - User. The idea is that if there was a passed in user whose key matches self.user, then merge the passed in user with self.user, and if the result is a user with different values, execute the change body.
//        if let user = user, user.key == self.user.key {
//            targetUser = self.user.merge(with: user)
//        }
        guard targetConfig != self.config || targetUser != self.user else { return }

        let wasOnline = isOnline
        isOnline = false

        if targetConfig != self.config {
            self.config = targetConfig
            service = serviceFactory.makeDarklyServiceProvider(mobileKey: mobileKey, config: self.config)
            eventReporter.config = self.config
        }

        if targetUser != self.user {
            flagStore = serviceFactory.makeFlagStore()
        }
        self.user = targetUser
        self.user.flagStore = flagStore
        flagSynchronizer = serviceFactory.makeFlagSynchronizer(mobileKey: mobileKey, pollingInterval: self.config.flagPollingInterval(runMode: effectiveRunMode), user: self.user, service: service, store: flagStore)
        flagSynchronizer.streamingMode = effectiveStreamingMode(runMode: runMode)

        self.isOnline = wasOnline

        //TODO: When the notification engine is installed, call the completion closure when the user's flags are updated the first time
    }

    private func effectiveStreamingMode(runMode: LDClientRunMode) -> LDStreamingMode {
        return runMode == .foreground && self.config.streamingMode == .streaming ? .streaming : .polling
    }

    private var effectiveRunMode: LDClientRunMode {
        return config.enableBackgroundUpdates ? runMode : .foreground
    }
    
    /* Event tracking
     Conceptual model
     The LDClient appears to keep an event dictionary that it transmits periodically to LD. An app sends an event and optional data by calling trackEvent(key:, data:) supplying at least the key.
    */
    ///Adds an event to the LDClient event store. LDClient periodically transmits events to LD based on the frequency set in LDConfig.eventFlushIntervalMillis.
    ///Usage:   LDClient.shared.trackEvent(key: "app-event-key", data: appEventData)
    ///Once an app has called trackEvent(), the app cannot remove the event from the event store.
    ///If the client is offline, the client stores the event until the app takes the client online, and the client has transmitted the event.
    public func trackEvent(key: String, data: [AnyHashable: Any]? = nil) {

    }
    
    // MARK: Feature Flag values
    
    /* FF Value Requests
     Conceptual Model
     The LDClient is the focal point for flag value requests. It should appear to the app that the client contains a store of [key: value] pairs where the keys are all strings and the values any of the supported LD flag types (Bool, number (int, float), String, Array, Dictionary). The LDFlaggable protocol defines the LD supported flag types.
     When asked for a variation value, the LDClient provides either the LDFlaggable value, or a (LDFlaggable, LDVariationSource) that reports the value and value source.
     
     At launch, the LDClient should ask the LDUserCache to load the cached user's flags (if any) and then ask the flag synchronizer to start synchronizing (via streaming / polling)
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

    private let userCache = LDUserCache()
    private(set) var flagSynchronizer: LDFlagSynchronizing
    private let flagChangeNotifier = LDFlagChangeNotifier()
    private(set) var eventReporter: LDEventReporting
    
    private init() {
        config.startOnline = false //prevents supporting players from trying to contact the LD server
        LDUserWrapper.configureKeyedArchiversToHandleVersion2_3_0AndOlderUserCacheFormat()
        flagStore = serviceFactory.makeFlagStore()
        service = serviceFactory.makeDarklyServiceProvider(mobileKey: "", config: config) //dummy object replaced by start call
        flagSynchronizer = serviceFactory.makeFlagSynchronizer(mobileKey: mobileKey, pollingInterval: config.flagPollInterval, user: user, service: service, store: flagStore)  //dummy object replaced by start call
        eventReporter = serviceFactory.makeEventReporter(mobileKey: "", config: config, service: service)    //dummy object replaced by start call
    }

    convenience init(serviceFactory: ClientServiceCreating, runMode: LDClientRunMode = .foreground) {
        self.init()
        self.runMode = runMode
        self.serviceFactory = serviceFactory
        flagStore = serviceFactory.makeFlagStore()
        service = serviceFactory.makeDarklyServiceProvider(mobileKey: "", config: config) //dummy object replaced by start call
        flagSynchronizer = serviceFactory.makeFlagSynchronizer(mobileKey: mobileKey, pollingInterval: config.flagPollInterval, user: user, service: service, store: flagStore)  //dummy object replaced by start call
        eventReporter = serviceFactory.makeEventReporter(mobileKey: "", config: config, service: service)    //dummy object replaced by start call
    }
}
