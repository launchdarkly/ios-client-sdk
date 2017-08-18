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
    public var isOnline: Bool   ///Controls whether client contacts launch darkly for feature flags and events. When offline, client only collects events.
    
    public let config: LDConfig
    public private(set) var user: LDUser
    
    // MARK: - Public
    
    ///Launches the LDClient using the passed in mobile key, config, & user
    ///Uses the default config and a new user if those parameters are not included
    public init(mobileKey: String, config: LDConfig = LDConfig(), user: LDUser? = nil) {
        self.mobileKey = mobileKey
        self.config = config
        let latestUser = userCache.retrieveLatest()
        self.user = user ?? latestUser ?? LDUser()  //Use the passed in user, and then the latestUser, and finally a newly created user
        self.isOnline = config.launchOnline //TODO: This may not be correct...might have to be false until we get other things setup, and then try to go online if launchOnline is true
        self.flagSynchronizer = LDFlagSynchronizer(config: self.config, user: self.user)
        self.eventReporter = LDEventReporter(config: self.config)
    }

    ///Updates the client to the new user. If there are no differences between the current user and the new user, does nothing
    ///If the LDClient is online, updates the user and requests feature flags from the server
    ///If the LDClient is offline, updates the user only. If a cached user is available, uses the cached feature flags until the LDClient is put online. If no cached user is available, any feature flag requests will result in the fallback until the LDClient is put online.
    ///NOTE: If the LDClient is online, there may be a brief delay before an update to the feature flags is available, depending upon network conditions. Prior to receiving a feature flag update, LDClient will return cached feature flags if they are available. If no cached feature flags are available, the LDClient will return fallback values. 
    ///If a client app wants to be notified when the LDClient receives the updated user flags, pass in a completion closure. The LDClient will call the closure once after the first feature flag update from the LD server, passing in the value of allFeatureFlags. The closure will NOT be called when a cached user's flags have been retrieved. If the client is offline, the closure will not be called until the app sets the client online and the client has received the first flag update from the LD server.
    ///Usage:
    ///     client.change(user: newUser) { (allFlags) in
    ///         //do something with allFlags, which contains the first flag update from the LD server
    ///     }
    ///If a client app doesn't want to be notified, omit the completion closure:
    ///     client.change(user: newUser)
    public func change(user: LDUser, completion:(([String: LDFlaggable]) -> ())? = nil) {
        
    }
    
    /* Event tracking
     Conceptual model
     The LDClient appears to keep an event dictionary that it transmits periodically to LD. An app sends an event and optional data by calling trackEvent(key:, data:) supplying at least the key.
    */
    ///Adds an event to the LDClient event store. LDClient periodically transmits events to LD based on the frequency set in LDConfig.eventFlushIntervalMillis.
    ///Usage:   client.trackEvent(key: "app-event-key", data: appEventData)
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
    
    ///Usage: let flags = client.allFeatureFlags
    public var allFeatureFlags: [String: LDFlaggable] {
        return user.allFlags
    }

    ///Usage
    /// flagValue = client.variation("flag-key", fallback: false)
    public func variation<T>(_ forKey: String, fallback: T) -> T where T: LDFlaggable {
        return fallback
    }

    ///Usage
    /// (flagValue, flagValueSource) = client.variation("flag-key", fallback: false)
    public func variation<T>(_ forKey: String, fallback: T) -> (T, LDVariationSource) where T: LDFlaggable {
        return (fallback, .fallback)
    }
    
    // MARK: Feature Flag Updates
    
    /* FF Change Notification
     Conceptual Model
     LDClient keeps a list of two types of closure observers, either Individual Flag observers or All Flag observers. LDClient executes Individual Flag observers when it detects a change to that flag being observed. LDClient executes All Flag observers when it detects a change to any flag for the current LDUser. The closure has a LDChangedFlag input parameter that communicates the flag's old & new value. Individual Flag observers will have an LDChangedFlag passed into the parameter directly. All Flags observers will have a dictionary of [String: LDChangeFlag] that use the flag key as the dictionary key.
     An app registers an Individual Flag observer using observe(key:, owner:, observer:), or an All Flags observer using observeAll(owner:, observer:). An app can register multiple closures for each type by calling these methods multiple times. When the value of a flag changes, LDClient calls each registered closure 1 time.
     LDClient will automatically remove observer closures that cannot be executed. This means an app does not need to stop observing flags, the LDClient will remove the observer the next time the LDClient would have executed the observer. An app can stop observers explicitly using one of several stopObserving methods. An app can stop Individual Flag observers using stopObserving(key:, owner:), or All Flags observers using stopObservingAll(owner:). An app may also choose to stop all observers (of either type, Individual Flag or All Flags) for a given owner using stopObserver(owner:). Finally, an app can store the LDFlagObserverToken returned by the observe(key:, owner:, observer:) and observeAll(owner:, observer:) methods and then use stopObserving(token:) to stop any single observer closure. This gives an app the ability to have very precise control over the observers registered.
    */
    
    ///Usage
    ///     let observerToken = client.observe("flag-key", owner: self, observer: { (changedFlag) in
    ///         if let oldValue = changedFlag.oldValue {
    ///             //do something with the oldValue
    ///         }
    ///         if let newValue = changedFlag.newValue {
    ///             //do something with the newValue
    ///         }
    ///          //client's change observing code here
    ///     }
    /// If you do not want to capture the observerToken, you can call client.observe() without embedding it into an assignment
    ///     client.observe("flag-key", owner: self, observer: { (changedFlag) in ...
    @discardableResult
    public func observe(_ key: String, owner: LDFlagChangeOwner, observer: @escaping LDFlagChangeObserver) -> LDFlagObserverToken {
        return ""
    }
    
    ///Usage
    ///     let observerToken = client.observeAll(owner: self, observer: { (changedFlags) in
    ///         //There will be an LDChangedFlag entry for each changed flag. The closure will only be called once regardless of how many flags changed.
    ///         if let someChangedFlag = changedFlags["some-flag-key"] {
    ///             //do something with someChangedFlag
    ///         }
    ///         //client's change observing code here
    ///     }
    /// changedFlags is a [String: LDChangedFlag] with this structure [<flagKey>: LDChangedFlag]
    /// If you do not want to capture the observerToken, you can call client.observeAll() without embedding it into an assignment
    ///     client.observeAll(owner: self, observer: { (changedFlag) in ...
    @discardableResult
    public func observeAll(owner: LDFlagChangeOwner, observer: @escaping LDFlagCollectionChangeObserver) -> LDFlagObserverToken {
        return ""
    }
    
    ///Removes all Individual Flag observers registered using observe() for the flag key from owner. Does not affect All Flags observers.
    public func stopObserving(_ key: String, owner: LDFlagChangeOwner) {
        
    }
    
    ///Removes all All Flags observers registered using observeAll(). Does not affect Individual Flag observers.
    ///To unregister all observers for a given owner, use stopObserving(owner:)
    public func stopObservingAll(owner: LDFlagChangeOwner) {
        
    }

    ///Removes all observers (both Individual Flag and All Flags) for the given owner
    public func stopObserving(owner: LDFlagChangeOwner) {
        
    }
    
    ///Removes the observer with the LDClient assigned token
    public func stopObserving(token: LDFlagObserverToken) {
        
    }
    
    // MARK: - Internal

    // MARK: - Private
    private let mobileKey: String

    private var backgroundMode: LDClientRunMode = .foreground

    private let userCache = LDUserCache()
    private let flagSynchronizer: LDFlagSynchronizer
    private let flagChangeNotifier = LDFlagChangeNotifier()
    private let eventReporter: LDEventReporter
    
    // MARK: - Test code
    private func test() {
        let flags = self.allFeatureFlags
        print(flags)
        
        let (testBool, boolSource) = self.variation("bool-flag-key", fallback: false)
        print(testBool, boolSource)
        
        let observerToken = observe("bool-flag-key", owner: self) { (changedFlag) in
            if let oldValue = changedFlag.oldValue {
                //do something with the oldValue
                print(oldValue)
            }
            if let newValue = changedFlag.newValue {
                //do something with the newValue
                print(newValue)
            }
        }
        print(observerToken)
        
        let boolChange = LDChangedFlag<Bool>(key:"boolKey", oldValue: nil, newValue: true)
        let oldBoolValue = boolChange.oldValue
        let newBoolValue = boolChange.newValue
        print(oldBoolValue ?? "<nil>", newBoolValue ?? "<nil>")
        
        observeAll(owner: self) { (changedFlags) in
            if let someChangedFlag = changedFlags["some-flag-key"] {
                //do something with someChangedFlag
                print(someChangedFlag)
            }
        }
        
        let newUser = LDUser()
        change(user: newUser) { (allFlags) in
            //do something with allFlags
        }
    }
    

}
