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

    public struct Defaults {
        static let baseUrl = URL(string: "https://app.launchdarkly.com")!
        static let eventsUrl = URL(string: "https://mobile.launchdarkly.com")!
        static let streamUrl = URL(string: "https://clientstream.launchdarkly.com")!
        
        static let eventCapacity = 100

        static let connectionTimeoutMillis = 10_000
        static let eventFlushIntervalMillis = 30_000
        static let pollIntervalMillis = 300_000
        static let backgroundPollIntervalMillis = 3_600_000

        static let streamingMode = LDStreamingMode.streaming
        static let enableBackgroundUpdates = false
        static let startOnline = true

        static let allUserAttributesPrivate = false
        static let privateUserAttributes: [String]? = nil

        static let useReport = false

        static let inlineUserInEvents = false

        static let debugMode = false
    }

    public struct Minima {

        //swiftlint:disable:next nesting
        struct Production {
            static let pollingIntervalMillis = 300_000
            static let backgroundPollIntervalMillis = 900_000
        }

        //swiftlint:disable:next nesting
        struct Debug {
            static let pollingIntervalMillis = 60_000
            static let backgroundPollIntervalMillis = 60_000
        }

        public let pollingIntervalMillis: Int   ///The minimum polling interval in milliseconds. Value: 5 minutes
        public let backgroundPollIntervalMillis: Int    ///The minimum background polling interval in milliseconds. Value: 15 minutes

        init(environmentReporter: EnvironmentReporting = EnvironmentReporter()) {
            self.pollingIntervalMillis = environmentReporter.isDebugBuild ? Debug.pollingIntervalMillis : Production.pollingIntervalMillis
            self.backgroundPollIntervalMillis = environmentReporter.isDebugBuild ? Debug.backgroundPollIntervalMillis : Production.backgroundPollIntervalMillis
        }
    }

    public var baseUrl: URL = Defaults.baseUrl                ///Don't set this unless instructed by LaunchDarkly.
    public var eventsUrl: URL = Defaults.eventsUrl            ///Don't set this unless instructed by LaunchDarkly.
    public var streamUrl: URL = Defaults.streamUrl            ///Don't set this unless instructed by LaunchDarkly.

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
    public var streamingMode: LDStreamingMode = Defaults.streamingMode
    private(set) var allowStreamingMode: Bool

    private var enableBgUpdates: Bool = Defaults.enableBackgroundUpdates
    ///Enables feature flag updates when your app is in the background. Allowed on macOS only. Default: false
    public var enableBackgroundUpdates: Bool {
        set { enableBgUpdates = newValue && allowBackgroundUpdates }
        get { return enableBgUpdates }
    }
    private var allowBackgroundUpdates: Bool
    
    ///Determines whether LDClient will be online / offline at start. If offline at start, set the client online to receive flag updates. Default: true
    public var startOnline: Bool = Defaults.startOnline

    //Private Attributes
    ///Treat all user attributes as private for event reporting for all users. When set, ignores values in either LDConfig.privateUserAttributes or LDUser.privateAttributes. Default: false
    public var allUserAttributesPrivate: Bool = Defaults.allUserAttributesPrivate
    ///List of user attributes and top level custom dictionary keys to treat as private for event reporting for all users. Private attribute values will not be included in events reported to Launch Darkly, but the attribute name will still be sent. All user attributes can be declared private except key, anonymous, device, & os. Access the user attribute names that can be declared private through the identifiers included in LDUser.swift. To declare all user attributes private, either set privateUserAttributes to LDUser.allUserAttributes or raise LDConfig.allUserAttributesPrivate. Default: nil
    public var privateUserAttributes: [String]? = Defaults.privateUserAttributes

    //Flag Requests using REPORT method
    /// Flag that enables REPORT HTTP method for feature flag requests. When useReport is false, feature flag requests use the GET HTTP method. Do not use unless advised by LaunchDarkly. Default: false
    public var useReport: Bool = Defaults.useReport
    private static let flagRetryStatusCodes = [HTTPURLResponse.StatusCodes.methodNotAllowed, HTTPURLResponse.StatusCodes.badRequest, HTTPURLResponse.StatusCodes.notImplemented]

    /// Flag that tells the SDK to include the user attributes in analytics event reports. When set to true, event reports will contain the user attributes, except attributes marked as private. When set to false, event reports will contain the user's key only, reducing the size of event reports. Default: false
    public var inlineUserInEvents: Bool = Defaults.inlineUserInEvents

    ///Enables additional logging for development. Default: false
    public var isDebugMode: Bool = Defaults.debugMode

    ///LD defined minima
    public let minima: Minima

    init(environmentReporter: EnvironmentReporting) {
        minima = Minima(environmentReporter: environmentReporter)
        allowStreamingMode = environmentReporter.operatingSystem != .watchOS
        allowBackgroundUpdates = environmentReporter.isDebugBuild || environmentReporter.operatingSystem.isBackgroundEnabled
    }

    public init() {
        self.init(environmentReporter: EnvironmentReporter())
    }

    func flagPollingInterval(runMode: LDClientRunMode) -> TimeInterval {
        let pollingIntervalMillis = runMode == .foreground ? max(pollIntervalMillis, minima.pollingIntervalMillis) : max(backgroundPollIntervalMillis, minima.backgroundPollIntervalMillis)
        Log.debug(typeName(and: #function, appending: ": ") + "\(pollingIntervalMillis.timeInterval)")
        return pollingIntervalMillis.timeInterval
    }

    static func isReportRetryStatusCode(_ statusCode: Int) -> Bool {
        let isRetryStatusCode = LDConfig.flagRetryStatusCodes.contains(statusCode)
        Log.debug(LDConfig.typeName(and: #function, appending: ": ") + "\(isRetryStatusCode)")
        return isRetryStatusCode
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
