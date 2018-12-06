//
//  LDConfig.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/12/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

/// Defines the connection modes available to set into LDClient.
public enum LDStreamingMode {
    /// In streaming mode, the LDClient opens a long-running connection to LaunchDarkly's streaming server (called *clientstream*). When a flag value changes on the server, the clientstream notifies the SDK to update the value. Streaming mode is not available on watchOS. On iOS and tvOS, the client app must be running in the foreground to connect to clientstream. On macOS the client app may run in either foreground or background to connect to clientstream. If streaming mode is not available, the SDK reverts to polling mode.
    case streaming
    /// In polling mode, the LDClient requests feature flags from LaunchDarkly's app server at regular intervals defined in the LDConfig. When a flag value changes on the server, the LDClient will learn of the change the next time the SDK requests feature flags.
    case polling
}

/**
 Use LDConfig to configure the LDClient. When initialized, a LDConfig contains the default values which can be changed as needed.

 The client app can change the LDConfig by getting the `config` from `LDClient`, adjusting the values, and setting it back into the `LDClient`.
 */
public struct LDConfig {

    fileprivate struct Constants {
        static let millisPerSecond: Double = 1000
    }

    /// The default values set when a LDConfig is initialized
    struct Defaults {
        /// The default url for making feature flag requests
        static let baseUrl = URL(string: "https://app.launchdarkly.com")!
        /// The default url for making event reports
        static let eventsUrl = URL(string: "https://mobile.launchdarkly.com")!
        /// The default url for connecting to the *clientstream*
        static let streamUrl = URL(string: "https://clientstream.launchdarkly.com")!
        
        /// The default maximum number of events the LDClient can store
        static let eventCapacity = 100

        /// The default timeout interval in milliseconds for flag requests and event reports. (10 seconds)
        static let connectionTimeoutMillis = 10_000
        /// The default interval between event reports in milliseconds (30 seconds)
        static let eventFlushIntervalMillis = 30_000
        /// The default interval between feature flag requests in milliseconds. Used only for polling mode. (5 minutes)
        static let pollIntervalMillis = 300_000
        /// The default interval between feature flag requests while running in the background, in milliseconds. Used only for polling mode. (60 minutes)
        static let backgroundPollIntervalMillis = 3_600_000

        /// The default streaming mode (.streaming)
        static let streamingMode = LDStreamingMode.streaming
        /// The default mode for enabling background flag requests. (false)
        static let enableBackgroundUpdates = false
        /// The default mode to set LDClient online on a start call. (true)
        static let startOnline = true

        /// The default setting for private user attributes. (false)
        static let allUserAttributesPrivate = false
        /// The default private user attribute list (nil)
        static let privateUserAttributes: [String]? = nil

        /// The default HTTP request method for `clientstream` connection and feature flag requests. When true, these requests will use the non-standard verb `REPORT`. When false, these requests will use the standard verb `GET`. (false)
        static let useReport = false

        /// The default setting controlling the amount of user data sent in events. When true the SDK will generate events using the full LDUser, excluding private attributes. When false the SDK will generate events using only the LDUser.key. (false)
        static let inlineUserInEvents = false

        /// The default setting controlling information logged to the console, and modifying some setting ranges to facilitate debugging. (false)
        static let debugMode = false
    }

    /// The minimum values allowed to be set into LDConfig.
    public struct Minima {

        //swiftlint:disable:next nesting
        struct Production {
            static let pollingIntervalMillis = 300_000
            static let backgroundPollIntervalMillis = 900_000
        }

        //swiftlint:disable:next nesting
        struct Debug {
            static let pollingIntervalMillis = 30_000
            static let backgroundPollIntervalMillis = 60_000
        }

        /// The minimum interval between feature flag requests in milliseconds. Used only for polling mode. (5 minutes)
        public let pollingIntervalMillis: Int
        /// The minimum interval between feature flag requests while running in the background, in milliseconds. Used only for polling mode. (15 minutes)
        public let backgroundPollIntervalMillis: Int

        init(environmentReporter: EnvironmentReporting = EnvironmentReporter()) {
            self.pollingIntervalMillis = environmentReporter.isDebugBuild ? Debug.pollingIntervalMillis : Production.pollingIntervalMillis
            self.backgroundPollIntervalMillis = environmentReporter.isDebugBuild ? Debug.backgroundPollIntervalMillis : Production.backgroundPollIntervalMillis
        }
    }

    /// The url for making feature flag requests. Do not change unless instructed by LaunchDarkly.
    public var baseUrl: URL = Defaults.baseUrl
    /// The url for making event reports. Do not change unless instructed by LaunchDarkly.
    public var eventsUrl: URL = Defaults.eventsUrl
    /// The url for connecting to the *clientstream*. Do not change unless instructed by LaunchDarkly.
    public var streamUrl: URL = Defaults.streamUrl

    /// The maximum number of analytics events the LDClient can store. When the LDClient event store reaches the eventCapacity, the SDK discards events until it successfully reports them to LaunchDarkly. (Default: 100)
    public var eventCapacity: Int = Defaults.eventCapacity

    // MARK: Time configuration

    /// The timeout interval in milliseconds for flag requests and event reports. (Default: 10 seconds)
    public var connectionTimeoutMillis: Int = Defaults.connectionTimeoutMillis
    /// The connection timeout interval in seconds for flag requests and event reports. Set via `connectionTimeoutMillis`. (Default: 10 seconds)
    var connectionTimeout: TimeInterval { return connectionTimeoutMillis.timeInterval }
    /// The interval between event reports in milliseconds (Default: 30 seconds)
    public var eventFlushIntervalMillis: Int = Defaults.eventFlushIntervalMillis
    /// The interval in seconds between event reports. Set via `eventFlushIntervalMillis`(Default: 30 seconds)
    var eventFlushInterval: TimeInterval { return eventFlushIntervalMillis.timeInterval }
    /// The interval between feature flag requests in milliseconds. Used only for polling mode. (Default: 5 minutes)
    public var pollIntervalMillis: Int = Defaults.pollIntervalMillis
    /// The interval in seconds between feature flag requests. Used only for polling mode. Set via `pollIntervalMillis` (Default: 5 minutes)
    var flagPollInterval: TimeInterval { return pollIntervalMillis.timeInterval }
    /// The interval between feature flag requests while running in the background, in milliseconds. Used only for polling mode. (Default: 60 minutes)
    public var backgroundPollIntervalMillis: Int = Defaults.backgroundPollIntervalMillis
    /// The interval in seconds between feature flag requests while running in the background. Used only for polling mode. Set via `backgroundPollIntervalMillis` (Default: 60 minutes)
    var backgroundFlagPollInterval: TimeInterval { return backgroundPollIntervalMillis.timeInterval }

    /// Controls the method the SDK uses to keep feature flags updated. When set to .streaming, connects to `clientstream` which notifies the SDK of feature flag changes. When set to .polling, an efficient polling mechanism is used to periodically request feature flag values. Ignored for watchOS, which always uses .polling. See `LDStreamingMode` for more details. (Default: .streaming)
    public var streamingMode: LDStreamingMode = Defaults.streamingMode
    /// Indicates whether streaming mode is allowed for the operating system
    private(set) var allowStreamingMode: Bool

    private var enableBgUpdates: Bool = Defaults.enableBackgroundUpdates
    /// Enables feature flag updates when your app is in the background. Allowed on macOS only. (Default: false)
    public var enableBackgroundUpdates: Bool {
        set { enableBgUpdates = newValue && allowBackgroundUpdates }
        get { return enableBgUpdates }
    }
    private var allowBackgroundUpdates: Bool
    
    /// Controls LDClient start behavior. When true, calling start causes LDClient to go online. When false, calling start causes LDClient to remain offline. If offline at start, set the client online to receive flag updates. (Default: true)
    public var startOnline: Bool = Defaults.startOnline

    //Private Attributes
    /**
     Treat all user attributes as private for event reporting for all users.

     The SDK will not include private attribute values in analytics events, but private attribute names will be sent.

     When true, ignores values in either LDConfig.privateUserAttributes or LDUser.privateAttributes. (Default: false)

     See Also: `privateUserAttributes` and `LDUser.privateAttributes`
    */
    public var allUserAttributesPrivate: Bool = Defaults.allUserAttributesPrivate
    /**
     User attributes and top level custom dictionary keys to treat as private for event reporting for all users.

     The SDK will not include private attribute values in analytics events, but private attribute names will be sent.

     See `LDUser.privatizableAttributes` for the attribute names that can be declared private. To set private user attributes for a specific user, see `LDUser.privateAttributes`. (Default: nil)

     See Also: `allUserAttributesPrivate`, `LDUser.privatizableAttributes`, and `LDUser.privateAttributes`.
    */
    public var privateUserAttributes: [String]? = Defaults.privateUserAttributes

    /**
     Directs the SDK to use REPORT for HTTP requests to connect to `clientstream` and make feature flag requests. When false the SDK uses GET for these requests. Do not use unless advised by LaunchDarkly. (Default: false)
    */
    public var useReport: Bool = Defaults.useReport
    private static let flagRetryStatusCodes = [HTTPURLResponse.StatusCodes.methodNotAllowed, HTTPURLResponse.StatusCodes.badRequest, HTTPURLResponse.StatusCodes.notImplemented]

    /**
     Controls how the SDK reports the user in analytics event reports. When set to true, event reports will contain the user attributes, except attributes marked as private. When set to false, event reports will contain the user's key only, reducing the size of event reports. (Default: false)
    */
    public var inlineUserInEvents: Bool = Defaults.inlineUserInEvents

    ///Enables logging for debugging. (Default: false)
    public var isDebugMode: Bool = Defaults.debugMode

    ///LaunchDarkly defined minima for selected configurable items
    public let minima: Minima

    ///An NSObject wrapper for the Swift LDConfig struct. Intended for use in mixed apps when Swift code needs to pass a config into an Objective-C method.
    public var objcLdConfig: ObjcLDConfig {
        return ObjcLDConfig(self)
    }

    //Internal constructor to enable automated testing
    init(environmentReporter: EnvironmentReporting) {
        minima = Minima(environmentReporter: environmentReporter)
        allowStreamingMode = environmentReporter.operatingSystem.isStreamingEnabled
        allowBackgroundUpdates = environmentReporter.operatingSystem.isBackgroundEnabled
    }

    ///LDConfig constructor. Configurable values are all set to their default values. The client app can modify these values as desired. Note that client app developers may prefer to get the LDConfig from `LDClient.config` in order to retain previously set values.
    public init() {
        self.init(environmentReporter: EnvironmentReporter())
    }

    //Determine the effective flag polling interval based on runMode, configured foreground & background polling interval, and minimum foreground & background polling interval.
    func flagPollingInterval(runMode: LDClientRunMode) -> TimeInterval {
        let pollingIntervalMillis = runMode == .foreground ? max(pollIntervalMillis, minima.pollingIntervalMillis) : max(backgroundPollIntervalMillis, minima.backgroundPollIntervalMillis)
        Log.debug(typeName(and: #function, appending: ": ") + "\(pollingIntervalMillis.timeInterval)")
        return pollingIntervalMillis.timeInterval
    }

    //Determines if the status code is a code that should cause the SDK to retry a failed HTTP Request that used the REPORT method. Retried requests will use the GET method.
    static func isReportRetryStatusCode(_ statusCode: Int) -> Bool {
        let isRetryStatusCode = LDConfig.flagRetryStatusCodes.contains(statusCode)
        Log.debug(LDConfig.typeName(and: #function, appending: ": ") + "\(isRetryStatusCode)")
        return isRetryStatusCode
    }
}

extension Int {
    //Converts the Int milliseconds into a TimeInterval
    var timeInterval: TimeInterval { return TimeInterval(self) / LDConfig.Constants.millisPerSecond }
}

extension LDConfig: Equatable {
    ///Compares the settable properties in 2 LDConfig structs
    public static func == (lhs: LDConfig, rhs: LDConfig) -> Bool {
        return lhs.baseUrl == rhs.baseUrl
            && lhs.eventsUrl == rhs.eventsUrl
            && lhs.streamUrl == rhs.streamUrl
            && lhs.eventCapacity == rhs.eventCapacity   //added
            && lhs.connectionTimeoutMillis == rhs.connectionTimeoutMillis
            && lhs.eventFlushIntervalMillis == rhs.eventFlushIntervalMillis
            && lhs.pollIntervalMillis == rhs.pollIntervalMillis
            && lhs.backgroundPollIntervalMillis == rhs.backgroundPollIntervalMillis
            && lhs.streamingMode == rhs.streamingMode
            && lhs.enableBackgroundUpdates == rhs.enableBackgroundUpdates
            && lhs.startOnline == rhs.startOnline
            && lhs.allUserAttributesPrivate == rhs.allUserAttributesPrivate
            && (lhs.privateUserAttributes == nil && rhs.privateUserAttributes == nil
                || (lhs.privateUserAttributes != nil && rhs.privateUserAttributes != nil && lhs.privateUserAttributes! == rhs.privateUserAttributes!))
            && lhs.useReport == rhs.useReport
            && lhs.inlineUserInEvents == rhs.inlineUserInEvents
            && lhs.isDebugMode == rhs.isDebugMode
    }
}

extension LDConfig: TypeIdentifying { }

#if DEBUG
    extension LDConfig {
        static let reportRetryStatusCodes = LDConfig.flagRetryStatusCodes
    }
#endif
