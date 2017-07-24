//
//  LDClientConfig.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/12/17.
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

public class LDClientConfig {
    
    fileprivate struct Constants {
        struct Default {
            static let baseUrl = "https://app.launchdarkly.com"
            static let eventsUrl = "https://mobile.launchdarkly.com"
            static let eventCapacity = 100       //Java sdk defaults to 10000
            static let connectionTimeoutMillis = 10_000
            static let eventFlushIntervalMillis = 30_000
            static let pollingIntervalMillis = 300_000
            static let backgroundFetchIntervalMillis = 900_000
            static let streaming = true
            static let debugMode = false
        }
    }
    
    var mobileKey: String
    var baseUrl: URL? = URL(string: Constants.Default.baseUrl)
    var eventsUrl: URL? = URL(string: Constants.Default.eventsUrl)
    var eventCapacity: Int = Constants.Default.eventCapacity
    var connectionTimeoutMillis: Int = Constants.Default.connectionTimeoutMillis
    var eventFlushIntervalMillis: Int = Constants.Default.eventFlushIntervalMillis
    var pollingIntervalMillis: Int = Constants.Default.pollingIntervalMillis
    var backgroundFetchIntervalMillis: Int = Constants.Default.backgroundFetchIntervalMillis
    var isStreaming: Bool = Constants.Default.streaming
    var isDebugMode: Bool = Constants.Default.debugMode
    
    init(mobileKey: String) {
        self.mobileKey = mobileKey
    }
    
    //Disabled publically...assert?
    private init() {
        self.mobileKey = UUID().uuidString
    }
    
    public func copy() -> LDClientConfig {
        let copy = LDClientConfig(mobileKey: self.mobileKey)
        //implement
        
        return copy
    }
}

extension LDClientConfig: Equatable {
    public static func ==(lhs: LDClientConfig, rhs: LDClientConfig) -> Bool {
        return false
    }
}
