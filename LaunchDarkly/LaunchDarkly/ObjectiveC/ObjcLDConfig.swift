//
//  LDConfigObject.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 9/7/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

/**
 Use LDConfig to configure the LDClient. When initialized, a LDConfig contains the default values which can be changed as needed.

 The client app can change the LDConfig by getting the `config` from LDClient (`ObjcLDClient`), adjusting the values, and setting it back into the LDClient (`ObjcLDClient`).
 */
@objc(LDConfig)
public final class ObjcLDConfig: NSObject {
    var config: LDConfig
    
    /// The Mobile key from your [LaunchDarkly Account](app.launchdarkly.com) settings (on the left at the bottom). If you have multiple projects be sure to choose the correct Mobile key.
    @objc public var mobileKey: String {
        get {
            return config.mobileKey
        }
        set {
            config.mobileKey = newValue
        }
    }

    /// The url for making feature flag requests. Do not change unless instructed by LaunchDarkly.
    @objc public var baseUrl: URL {
        get {
            return config.baseUrl
        }
        set {
            config.baseUrl = newValue
        }
    }
    /// The url for making event reports. Do not change unless instructed by LaunchDarkly.
    @objc public var eventsUrl: URL {
        get {
            return config.eventsUrl
        }
        set {
            config.eventsUrl = newValue
        }
    }
    /// The url for connecting to the *clientstream*. Do not change unless instructed by LaunchDarkly.
    @objc public var streamUrl: URL {
        get {
            return config.streamUrl
        }
        set {
            config.streamUrl = newValue
        }
    }

    /// The maximum number of analytics events the LDClient can store. When the LDClient event store reaches the eventCapacity, the SDK discards events until it successfully reports them to LaunchDarkly. (Default: 100)
    @objc public var eventCapacity: Int {
        get {
            return config.eventCapacity
        }
        set {
            config.eventCapacity = newValue
        }
    }

    /// The timeout interval for flag requests and event reports. (Default: 10 seconds)
    @objc public var connectionTimeout: TimeInterval {
        get {
            return config.connectionTimeout
        }
        set {
            config.connectionTimeout = newValue
        }
    }
    /// The time interval between event reports (Default: 30 seconds)
    @objc public var eventFlushInterval: TimeInterval {
        get {
            return config.eventFlushInterval
        }
        set {
            config.eventFlushInterval = newValue
        }
    }
    /// The interval between feature flag requests. Used only for polling mode. (Default: 5 minutes)
    @objc public var flagPollingInterval: TimeInterval {
        get {
            return config.flagPollingInterval
        }
        set {
            config.flagPollingInterval = newValue
        }
    }
    /// The interval between feature flag requests while running in the background. Used only for polling mode. (Default: 60 minutes)
    @objc public var backgroundFlagPollingInterval: TimeInterval {
        get {
            return config.backgroundFlagPollingInterval
        }
        set {
            config.backgroundFlagPollingInterval = newValue
        }
    }

    /// The minimum interval between feature flag requests. Used only for polling mode. (5 minutes)
    @objc public var minFlagPollingInterval: TimeInterval {
        return config.minima.flagPollingInterval
    }
    /// The minimum interval between feature flag requests while running in the background. Used only for polling mode. (15 minutes)
    @objc public var minBackgroundFlagPollInterval: TimeInterval {
        return config.minima.backgroundFlagPollingInterval
    }

    /// Controls the method the SDK uses to keep feature flags updated. When set to .streaming, connects to `clientstream` which notifies the SDK of feature flag changes. When set to .polling, an efficient polling mechanism is used to periodically request feature flag values. Ignored for watchOS, which always uses .polling. See `LDStreamingMode` for more details. (Default: .streaming)
    @objc public var streamingMode: Bool {
        get {
            return config.streamingMode == .streaming
        }
        set {
            config.streamingMode = newValue ? .streaming : .polling
        }
    }
    /// Enables feature flag updates when your app is in the background. Allowed on macOS only. (Default: NO)
    @objc public var enableBackgroundUpdates: Bool {
        get {
            return config.enableBackgroundUpdates
        }
        set {
            config.enableBackgroundUpdates = newValue
        }
    }
    /// Controls LDClient start behavior. When YES, calling start causes LDClient to go online. When NO, calling start causes LDClient to remain offline. If offline at start, set the client online to receive flag updates. (Default: YES)
    @objc public var startOnline: Bool {
        get {
            return config.startOnline
        }
        set {
            config.startOnline = newValue
        }
    }

    /**
     Treat all user attributes as private for event reporting for all users.

     The SDK will not include private attribute values in analytics events, but private attribute names will be sent.

     When YES, ignores values in either LDConfig.privateUserAttributes or LDUser.privateAttributes. (Default: NO)

     See Also: `privateUserAttributes` and `LDUser.privateAttributes` (`ObjcLDUser.privateAttributes`)
     */
    @objc public var allUserAttributesPrivate: Bool {
        get {
            return config.allUserAttributesPrivate
        }
        set {
            config.allUserAttributesPrivate = newValue
        }
    }
    /**
     User attributes and top level custom dictionary keys to treat as private for event reporting for all users.

     The SDK will not include private attribute values in analytics events, but private attribute names will be sent.

     See `LDUser.privatizableAttributes` (`ObjcLDUser.privatizableAttributes`) for the attribute names that can be declared private. To set private user attributes for a specific user, see `LDUser.privateAttributes` (`ObjcLDUser.privateAttributes`). (Default: nil)

     See Also: `allUserAttributesPrivate`, `LDUser.privatizableAttributes` (`ObjcLDUser.privatizableAttributes`), and `LDUser.privateAttributes` (`ObjcLDUser.privateAttributes`).
     */
    @objc public var privateUserAttributes: [String]? {
        get {
            return config.privateUserAttributes
        }
        set {
            config.privateUserAttributes = newValue
        }
    }

    /**
     Directs the SDK to use REPORT for HTTP requests to connect to `clientstream` and make feature flag requests. When NO the SDK uses GET for these requests. Do not use unless advised by LaunchDarkly. (Default: NO)
     */
    @objc public var useReport: Bool {
        get {
            return config.useReport
        }
        set {
            config.useReport = newValue
        }
    }

    /**
     Controls how the SDK reports the user in analytics event reports. When set to YES, event reports will contain the user attributes, except attributes marked as private. When set to NO, event reports will contain the user's key only, reducing the size of event reports. (Default: NO)
     */
    @objc public var inlineUserInEvents: Bool {
        get {
            return config.inlineUserInEvents
        }
        set {
            config.inlineUserInEvents = newValue
        }
    }

    ///Enables logging for debugging. (Default: NO)
    @objc public var debugMode: Bool {
        get {
            return config.isDebugMode
        }
        set {
            config.isDebugMode = newValue
        }
    }
    
    ///LDConfig constructor. Configurable values are all set to their default values. The client app can modify these values as desired. Note that client app developers may prefer to get the LDConfig from `LDClient.config` (`ObjcLDClient.config`) in order to retain previously set values.
    @objc public init(mobileKey: String) {
        config = LDConfig(mobileKey: mobileKey)
    }

    //Initializer to wrap the Swift LDConfig into ObjcLDConfig for use in Objective-C apps.
    init(_ config: LDConfig) {
        self.config = config
    }

    ///Compares the settable properties in 2 LDConfig structs
    @objc public func isEqual(object: Any?) -> Bool {
        guard let other = object as? ObjcLDConfig
        else {
            return false
        }
        return config == other.config
    }
}
