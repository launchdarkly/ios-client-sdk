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
    @objc public var eventFlushIntervalMillis: Int {
        get { return config.eventFlushIntervalMillis }
        set { config.eventFlushIntervalMillis = newValue }
    }
    @objc public var pollIntervalMillis: Int {
        get { return config.pollIntervalMillis }
        set { config.pollIntervalMillis = newValue }
    }
    @objc public var backgroundPollIntervalMillis: Int {
        get { return config.backgroundPollIntervalMillis }
        set { config.backgroundPollIntervalMillis = newValue }
    }

    @objc public var minBackgroundPollIntervalMillis: Int { return config.minima.backgroundPollIntervalMillis }
    @objc public var minPollingIntervalMillis: Int { return config.minima.pollingIntervalMillis }

    @objc public var streamingMode: Bool {
        get { return config.streamingMode == .streaming }
        set { config.streamingMode = newValue ? .streaming : .polling }
    }
    @objc public var enableBackgroundUpdates: Bool {
        get { return config.enableBackgroundUpdates }
        set { config.enableBackgroundUpdates = newValue }
    }
    @objc public var startOnline: Bool {
        get { return config.startOnline }
        set { config.startOnline = newValue }
    }

    @objc public var allUserAttributesPrivate: Bool {
        get { return config.allUserAttributesPrivate }
        set { config.allUserAttributesPrivate = newValue }
    }
    @objc public var privateUserAttributes: [String]? {
        get { return config.privateUserAttributes }
        set { config.privateUserAttributes = newValue }
    }

    @objc public var useReport: Bool {
        get { return config.useReport }
        set { config.useReport = newValue }
    }

    @objc public var debugMode: Bool {
        get { return config.isDebugMode }
        set { config.isDebugMode = newValue }
    }
    
    @objc public var minimumBackgroundPollIntervalMillis: Int { return config.minima.backgroundPollIntervalMillis }
    
    @objc public override init() { config = LDConfig() }
    init(_ config: LDConfig) { self.config = config }

    @objc public func isEqual(object: Any?) -> Bool {
        guard let other = object as? ObjcLDConfig else { return false }
        return config == other.config
    }
}

protocol Settable { }

extension Settable {
    
}
