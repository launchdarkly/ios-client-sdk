//
//  LDConfigObject.swift
//  Darkly
//
//  Created by Mark Pokorny on 9/7/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

@objc(LDConfig)
public final class ObjcLDConfig: NSObject {
    var config: LDConfig
    
    @objc public var baseUrl: URL {
        get { return config.baseUrl }
        set { config.baseUrl = newValue }
    }
    @objc public var eventsUrl: URL {
        get { return config.eventsUrl }
        set { config.eventsUrl = newValue }
    }
    @objc public var streamUrl: URL {
        get { return config.streamUrl }
        set { config.streamUrl = newValue }
    }
    
    @objc public var eventCapacity: Int {
        get { return config.eventCapacity }
        set { config.eventCapacity = newValue }
    }
    
    @objc public var connectionTimeoutMillis: Int {
        get { return config.connectionTimeoutMillis }
        set { config.connectionTimeoutMillis = newValue }
    }
    
    @objc public var debugMode: Bool {
        get { return config.isDebugMode }
        set { config.isDebugMode = newValue }
    }
    
    @objc public var minimumBackgroundPollIntervalMillis: Int { return config.minima.backgroundPollIntervalMillis }
    
    @objc public override init() { config = LDConfig() }
    init(_ config: LDConfig) { self.config = config }
}

protocol Settable { }

extension Settable {
    
}
