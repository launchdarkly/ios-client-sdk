//
//  LDConfig.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/12/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

public enum LDStreamingMode {
    case streaming, polling
}

public struct LDConfig {

    fileprivate struct Constants {
        static let millisPerSecond: Double = 1000
    }

    fileprivate struct Defaults {
        static let baseUrl = URL(string: "https://app.launchdarkly.com")!
        static let eventsUrl = URL(string: "https://mobile.launchdarkly.com")!
        static let streamUrl = URL(string: "https://clientstream.launchdarkly.com")!  //Android SDK has this, ios has it hard-coded
        
        static let eventCapacity = 100

        static let connectionTimeoutMillis = 10_000
        static let eventFlushIntervalMillis = 30_000    //Android SDK uses 5_000
        static let pollIntervalMillis = 300_000
        static let backgroundPollIntervalMillis = 3_600_000  //Android SDK uses 15m min, 1h default

        static let streaming = LDStreamingMode.streaming
        static let enableBackgroundUpdates = true   //Android sdk has this config item
        static let online = true

        static let debugMode = false
    }

    public struct Minima {
        public let backgroundPollIntervalMillis = 900_000   ///The minimum background polling interval in milliseconds. Value: 15 minutes
        public let pollingIntervalMillis = isDebug ? 60_000 : 300_000   ///The minimum polling interval in milliseconds. Value: 5 minutes
    }

    public var baseUrl: URL = Defaults.baseUrl                ///You probably don't need to set this unless instructed by LaunchDarkly.
    public var eventsUrl: URL = Defaults.eventsUrl            ///You probably don't need to set this unless instructed by LaunchDarkly.
    public var streamUrl: URL = Defaults.streamUrl            ///You probably don't need to set this unless instructed by LaunchDarkly.

    ///The max number of analytics events to queue before sending them to LaunchDarkly. Default: 100
    public var eventCapacity: Int = Defaults.eventCapacity

    //Time configuration
    ///The timeout in milliseconds when connecting to LaunchDarkly. Default: 10 seconds
    public var connectionTimeoutMillis: Int = Defaults.connectionTimeoutMillis
    var connectionTimeout: TimeInterval { return connectionTimeoutMillis.timeInterval }
    ///The minimum amount of time in milliseconds to wait in between sending analytics events to LaunchDarkly.
    public var eventFlushIntervalMillis: Int = Defaults.eventFlushIntervalMillis
    var eventFlushInterval: TimeInterval { return eventFlushIntervalMillis.timeInterval }
    ///The interval between feature flag updates. Only relevant when not streaming Default: 5 minutes. Minimum: 5 minutes
    public var pollIntervalMillis: Int = Defaults.pollIntervalMillis
    var flagPollInterval: TimeInterval { return pollIntervalMillis.timeInterval }
    ///The interval in milliseconds that we will poll for flag updates when your app is in the background. Default: 1 hour. Minimum: 15 minutes
    public var backgroundPollIntervalMillis: Int = Defaults.backgroundPollIntervalMillis
    var backgroundFlagPollInterval: TimeInterval { return backgroundPollIntervalMillis.timeInterval }

    ///Enables real-time streaming flag updates. When set to .polling, an efficient polling mechanism is used. Default: .streaming
    public var streamingMode: LDStreamingMode = Defaults.streaming
    ///Enables feature flag updates when your app is in the background. Default: true
    public var enableBackgroundUpdates: Bool = Defaults.enableBackgroundUpdates
    ///Determines whether LDClient will be online / offline at start. If offline at start, set the client online to receive flag updates. Default: true
    public var startOnline: Bool = Defaults.online

    //Private Attributes
    ///Treat all user attributes as private for event reporting for all users. When set, ignores values in either LDConfig.privateUserAttributes or LDUser.privateAttributes. Default: false
    public var allUserAttributesPrivate: Bool = false
    ///List of user attributes and top level custom dictionary keys to treat as private for event reporting for all users. Private attribute values will not be included in events reported to Launch Darkly, but the attribute name will still be sent. All user attributes can be declared private except key, anonymous, device, & os. Access the user attribute names that can be declared private through the identifiers included in LDUser.swift. To declare all user attributes private, either set privateUserAttributes to LDUser.allUserAttributes or raise LDConfig.allUserAttributesPrivate. Default: nil
    public var privateUserAttributes: [String]? = nil

    //Flag Requests using REPORT method
    /// Flag that enables REPORT HTTP method for feature flag requests. When useReport is false, feature flag requests use the GET HTTP method. Do not use unless advised by LaunchDarkly. Default: false
    public var useReport: Bool = false
    private static let flagRetryStatusCodes = [HTTPURLResponse.StatusCodes.methodNotAllowed, HTTPURLResponse.StatusCodes.badRequest, HTTPURLResponse.StatusCodes.notImplemented]

    ///Enables additional logging for development. Default: false
    public var isDebugMode: Bool = Defaults.debugMode

    ///LD defined minima
    public let minima = Minima()

    public init() { }   //Even though the struct is public, the default constructor is internal

    func flagPollingInterval(runMode: LDClientRunMode) -> TimeInterval {
        let pollingIntervalMillis = runMode == .foreground ? max(pollIntervalMillis, minima.pollingIntervalMillis) : max(backgroundPollIntervalMillis, minima.backgroundPollIntervalMillis)
        return pollingIntervalMillis.timeInterval
    }

    static func isReportRetryStatusCode(_ statusCode: Int) -> Bool {
        return LDConfig.flagRetryStatusCodes.contains(statusCode)
    }
}

extension Int {
    var timeInterval: TimeInterval { return TimeInterval(self) / LDConfig.Constants.millisPerSecond }
}

extension LDConfig: Equatable {
    public static func == (lhs: LDConfig, rhs: LDConfig) -> Bool {
        return lhs.baseUrl == rhs.baseUrl
            && lhs.eventsUrl == rhs.eventsUrl
            && lhs.streamUrl == rhs.streamUrl
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
            && lhs.isDebugMode == rhs.isDebugMode
    }
}

#if DEBUG
    extension LDConfig {
        static let reportRetryStatusCodes = LDConfig.flagRetryStatusCodes
    }
#endif
