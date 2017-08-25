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
    
    public var isOnline = false   ///Controls whether client contacts launch darkly for feature flags and events. When offline, client only collects events.
    
    public private(set) var config = LDConfig()
    public private(set) var user = LDUser()
    
    // MARK: - Public
    
    ///Launches the LDClient using the passed in mobile key, config, & user
    ///Uses the default config and a new user if those parameters are not included
    ///Usage:
    ///     LDClient.shared.start(mobileKey: appMobileKey, config: appConfig, user: appUser)
    ///Call this one time before you want to capture feature flags. The LDClient will not go online until you call this method.
    public func start(mobileKey: String, config: LDConfig = LDConfig(), user: LDUser? = nil) {
        if isOnline {
            isOnline = false
        }
        
        self.mobileKey = mobileKey
        self.config = config
        let latestUser = userCache.retrieveLatest()
        self.user = user ?? latestUser ?? LDUser()
        self.flagSynchronizer = LDFlagSynchronizer(config: self.config, user: self.user)
        self.eventReporter = LDEventReporter(config: self.config)

        self.isOnline = config.launchOnline
    }

    ///Updates the client to the new user. If there are no differences between the current user and the new user, does nothing
    ///If the LDClient is online, updates the user and requests feature flags from the server
    ///If the LDClient is offline, updates the user only. If a cached user is available, uses the cached feature flags until the LDClient is put online. If no cached user is available, any feature flag requests will result in the fallback until the LDClient is put online.
    ///NOTE: If the LDClient is online, there may be a brief delay before an update to the feature flags is available, depending upon network conditions. Prior to receiving a feature flag update, LDClient will return cached feature flags if they are available. If no cached feature flags are available, the LDClient will return fallback values. 
    ///If a client app wants to be notified when the LDClient receives the updated user flags, pass in a completion closure. The LDClient will call the closure once after the first feature flag update from the LD server, passing in the value of allFeatureFlags. The closure will NOT be called when a cached user's flags have been retrieved. If the client is offline, the closure will not be called until the app sets the client online and the client has received the first flag update from the LD server.
    ///Usage:
    ///     LDClient.shared.change(user: newUser) { (allFlags) in
    ///         //do something with allFlags, which contains the first flag update from the LD server
    ///     }
    ///If a client app doesn't want to be notified, omit the completion closure:
    ///     LDClient.shared.change(user: newUser)
    public func change(user: LDUser, completion:(([String: LDFlaggable]) -> ())? = nil) {
        
    }
    
    ///Changes the LDClient config.
    ///If the config is unchanged, this does nothing. If the client is online, it takes the client offline, reconfigures, and then brings the client online again.
    ///Usage:   LDClient.shared.change(config: newConfig)
    ///You can make config changes by getting the config from the client, adjusting settings, and then calling change(config:)
    public func change(config: LDConfig) {
        
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
     When asked for allFeatureFlags, the LDClient should provide a [String: LDFlaggable] with keys & values. Nil values should not appear in this dictionary...it would be the same as if the key weren't there.
     When asked for a variation value, the LDClient provides either the LDFlaggable value, or a (LDFlaggable, LDVariationSource) that reports the value and value source.
     
     At launch, the LDClient should ask the LDUserCache to load the cached user's flags (if any) and then ask the flag synchronizer to start synchronizing (via streaming / polling)
    */
    
    ///Usage: let flags = LDClient.shared.allFeatureFlags
    public var allFeatureFlags: [String: LDFlaggable] {
        return user.allFlags
    }

    ///Usage
    /// flagValue = LDClient.shared.variation("flag-key", fallback: false)
    public func variation<T>(_ forKey: String, fallback: T) -> T where T: LDFlaggable {
        return fallback
    }

    ///Usage
    /// (flagValue, flagValueSource) = LDClient.shared.variation("flag-key", fallback: false)
    public func variation<T>(_ forKey: String, fallback: T) -> (T, LDVariationSource) where T: LDFlaggable {
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
    ///     LDClient.shared.observe("flag-key", owner: self, observer: { (changedFlag) in
    ///         if let oldValue = changedFlag.oldValue {
    ///             //do something with the oldValue
    ///         }
    ///         if let newValue = changedFlag.newValue {
    ///             //do something with the newValue
    ///         }
    ///          //client's change observing code here
    ///     }
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
    
    // MARK: - Internal

    // MARK: - Private
    private var mobileKey = ""

    private var backgroundMode: LDClientRunMode = .foreground

    private let userCache = LDUserCache()
    private var flagSynchronizer: LDFlagSynchronizer
    private let flagChangeNotifier = LDFlagChangeNotifier()
    private var eventReporter: LDEventReporter
    
    private init() {
        config.launchOnline = false //prevents supporting players from trying to contact the LD server
        self.flagSynchronizer = LDFlagSynchronizer(config: config, user: user)  //dummy object replaced by start call
        self.eventReporter = LDEventReporter(config: config)    //dummy object replaced by start call
    }
}
