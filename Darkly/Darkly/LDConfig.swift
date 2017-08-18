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
        struct Default {
            static let baseUrl = URL(string: "https://app.launchdarkly.com")!
            static let eventsUrl = URL(string: "https://mobile.launchdarkly.com")!
            static let streamUrl = URL(string: "https://clientstream.launchdarkly.com/mping")!  //Android SDK has this, ios has it hard-coded
            
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
    }
    
    public struct Minima {
        public static let backgroundPollIntervalMillis = 900_000   ///The minimum background polling interval in milliseconds. Value: 15 minutes
        public static let pollingIntervalMillis = 60_000   ///The minimum polling interval in milliseconds. Value: 1 minute
    }
    
    public var baseUrl: URL = Constants.Default.baseUrl                ///You probably don't need to set this unless instructed by LaunchDarkly.
    public var eventsUrl: URL = Constants.Default.eventsUrl            ///You probably don't need to set this unless instructed by LaunchDarkly.
    public var streamUrl: URL = Constants.Default.streamUrl            ///You probably don't need to set this unless instructed by LaunchDarkly.
    
    ///The max number of analytics events to queue before sending them to LaunchDarkly. Default: 100
    public var eventCapacity: Int = Constants.Default.eventCapacity
    
    //Time configuration
    ///The timeout in milliseconds when connecting to LaunchDarkly. Default: 10 seconds
    public var connectionTimeoutMillis: Int = Constants.Default.connectionTimeoutMillis
    ///The maximum amount of time in milliseconds to wait in between sending analytics events to LaunchDarkly.
    public var eventFlushIntervalMillis: Int = Constants.Default.eventFlushIntervalMillis
    ///The interval between feature flag updates. Only relevant when not streaming Default: 5 minutes. Minimum: 1 minute
    public var pollIntervalMillis: Int = Constants.Default.pollIntervalMillis
    ///The interval in milliseconds that we will poll for flag updates when your app is in the background. Default: 1 hour. Minimum: 15 minutes
    public var backgroundPollIntervalMillis: Int = Constants.Default.backgroundPollIntervalMillis
    
    ///Enables real-time streaming flag updates. When set to .polling, an efficient polling mechanism is used. Default: .streaming
    public var streamingMode: LDStreamingMode = Constants.Default.streaming
    ///Enables feature flag updates when your app is in the background. Default: true
    public var enableBackgroundUpdates: Bool = Constants.Default.enableBackgroundUpdates
    ///Determines whether LDClient will be online / offline at launch. If offline at launch, set the client online to receive flag updates. Default: true
    public var launchOnline: Bool = Constants.Default.online
    ///Enables additional logging for development. Default: false
    public var isDebugMode: Bool = Constants.Default.debugMode
    
    ///LD defined minima
    public let min = Minima()
}
