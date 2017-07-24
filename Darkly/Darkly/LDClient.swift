//
//  LDClient.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

public enum LDClientRunMode {
    case foreground, background
}

public protocol LDClientDelegate: class {
    func featureFlagsUpdated(updatedKeys: [String])
}

public typealias LDFlagUpdateHandler = ((_ updatedKeys: [String]) -> Void)

//Get configuration object from LDClient that has current settings
//LDClient should accept new config object: that stops, reconfigure, then start
//Review Android SDK, match where possible
public class LDClient {
    struct Constants {
        fileprivate static let notificationKeyUserUpdated = "Darkly.UserUpdatedNotification"
    }
    
    public static let featureFlagUpdatedNotificationName = Notification.Name(Constants.notificationKeyUserUpdated)
    
    private(set) var isStarted: Bool = false                    //TODO: this feels like it could be sdk internal...the LDClient should respond to app exit notifications and the client app shouldn't have to set this
    public var isOnline: Bool = true                            //TODO: this feels like it should be the only client app control. Sequence LDClient.shared.start(config: user:), then offline / online as needed. start() puts LDClient online
    public var backgroundMode: LDClientRunMode = .foreground    //TODO: this feels like it should be sdk internal...the LDClient should respond to fg/bg notifications and the client app shouldn't have to set this
    
    public static let shared = LDClient()
    
    private(set) var configuration: LDClientConfig?    //sdk readable, only settable thru either start(config: user:) or change(config:); public access only via copyConfiguration()
    public private(set) var user: LDUser?               //Java sdk doesn't have the concept of a user included with the LDClient...it's passed in for eval requests
    
    private let userManager = LDUserManager()
    private let flagManager = LDFlagManager()
    private let eventManager = LDEventManager()
    
    // MARK: - Public
    ///Copy of the client's current configuration, client app can change without affecting the LDClient
    ///nil if the client has not been started
    ///Call change(configuration:) once you have changed to the desired configuration
    public func copyConfiguration() -> LDClientConfig? {
        return configuration?.copy()
    }
    
    ///Updates the client to the new configuration. If there are no differences between the current configuration and the new configuration, does nothing
    ///If the LDClient is online, this method takes the LDClient offline, updates the configuration, and puts the LDClient back online. The user is unchanged.
    ///If the LDClient is offline, this method only updates the configuration leaving the LDClient offline.
    public func change(config: LDClientConfig) {
        
    }
    
    ///Updates the client to the new user. If there are no differences between the current user and the new user, does nothing
    ///If the LDClient is online, updates the user and requests feature flags from the server
    ///If the LDClient of offline, updates the user only. If a cached user is available, uses the cached feature flags until the LDClient is put online. If no cached user is available, any feature flag requests will result in the fallback until the LDClient is put online.
    ///NOTE: If the LDClient is online, there may be a brief delay before an update to the feature flags is available, depending upon network conditions. Prior to receiving a feature flag update, LDClient will return cached feature flags if they are available. If no cached feature flags are available, the LDClient will return fallback values.
    public func change(user: LDUser) {
        
    }
    
    //We discussed start/stop & online/offline. Arun doesn't see much benefit in both definitions, and it has been confusing to clients
    //started (or running) & online means: collecting events, syncing events, monitoring flags (polling or sse)
    //started (or running) & offline means: collecting events
    //stopped means: no activity
    public func start(config: LDClientConfig, user: LDUser = LDUser.anonymous) {
        
    }
    
    ///Call this method when done prior to being done
    //TODO: If we can register to receive notification when the app is shutting down, and run this, then a client app wont have to
    public func stop() {
        
    }
    
    public func trackEvent(key: String, data: [AnyHashable: Any]) {

    }
    
    public func flushEvents() {
        
    }
    
    /* Threading
     We discussed a potential threading model that might be used.
     LDClient runs on the main thread.
     FF value requests are handled in whatever thread the client app makes the request
     FF sse/polling & update requests run in a LDClient launched bg thread instantiated at creation
     Event processing runs in a LDClient launched bg thread instantiated at creation
    */
    
    // MARK: - Feature Flag Updates
    /* Notification
     There are potentially 3 models LDClient could use to notify client apps when FF changes occur
     A. Notifications. LDClient posts a notification via NotificationCenter. Listeners then request flags from LDClient.
     B. Closures. LDClient registers closures to execute on FF change.
     C. Delegation. LDClient calls delegate method on FF change.
     
     Each has merit, and perhaps for flexibility, we should implement all 3. That gives client apps max flexibility for code style.
     
     Regardless of the method, a set of flag keys indicating the changed flags should be sent. The client app can then use the changed flag keys to decide whether to request an update from the LDClient. Note: I don't think the updated flag value should be included. While that forces the client app to request the update from the LDClient, it also preserves the LDClient as the source of truth for the system...
     LDClient should only invoke the notification method when it is running.
    */
    ///Client apps may listen for LDClient.featureFlagUpdatedNotificationName notifications
    
    ///Client apps may set a closure to be called when feature flags are updated. If the handler is set when start(config: user:) is called, LDClient will execute the handler on receipt of the flags from the server (not when flags are retrieved from the cache, if available)
    //TODO: Should LDClient accept multiple handlers? (The idea would be to then hide this and provide a method setFeatureFlagUpdate(handler: forKey:)
    public var featureFlagsUpdatedHandler: LDFlagUpdateHandler?
    
    ///Client apps may set a delegate which LDClient will call when feature flags are updated. If the delegate is set when start(config: user:) is called, LDClient will call featureFlagsUpdated(updatedKeys:) on receipt of the flags from the server (not when flags are retrieved from the cache, if available)
    public weak var delegate: LDClientDelegate?
    
    /* FF Value Requests
     Arun prefers to maintain the naming convention <type>Variation(key:)-><type> for the flag getters. These names are used in the other SDKs.
     The LDClient should also provide an allFlags method -> [String: Any]
     Internally, the LDClient should maintain a [String: Any] for flags. Flag requests should respond using this structure.
     Additionally, some metadata about the flag dictionary should be maintained about it's source (server, cache)
     At start, the LDClient should load the cached user's flags and ask the flag processor to request an update and start monitoring (sse/poll)
     What should the LDClient do if it is instantiated but not started, and a client app requests a flag value?
    */
    
    // MARK: - Feature Flag values
    public var allFeatureFlags: [String: Any] {
        return [:]
    }

    public func boolVariation(key: String, fallback: Bool) -> Bool {
        return fallback
    }
    
    public func numberVariation(key: String, fallback: NSNumber) -> NSNumber {
        return fallback
    }
    
    public func stringVariation(key: String, fallback: String) -> String {
        return fallback
    }

    public func arrayVariation(key: String, fallback: [Any]) -> [Any] {
        return fallback
    }

    public func dictionaryVariation(key: String, fallback: [String: Any]) -> [String: Any] {
        return fallback
    }

    // MARK: - Private
    
    private init() { }  //Disable default constructor
    
    private func startPolling() {
        guard isOnline else { return }
    }
    
    private func stopPolling() {

    }
    
    private func requestFlagsFromServer(for user: LDUser) { }
    
    private func sendEventsToServer(events: [LDEvent]) { }
}
