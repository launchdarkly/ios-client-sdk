//
//  HTTPHeaders.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 9/19/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

struct HTTPHeaders {
    
    struct HeaderKey {
        static let authorization = "Authorization"
        static let userAgent = "User-Agent"
        static let contentType = "Content-Type"
        static let accept = "Accept"
        static let eventSchema = "X-LaunchDarkly-Event-Schema"
    }

    struct HeaderValue {
        static let apiKey = "api_key"
        static let applicationJson = "application/json"
        static let eventSchema = "3"
    }
    
    let mobileKey: String
    let systemName: String
    let sdkVersion: String
    
    init(config: LDConfig, environmentReporter: EnvironmentReporting) {
        self.mobileKey = config.mobileKey
        self.systemName = environmentReporter.systemName
        self.sdkVersion = environmentReporter.sdkVersion
    }
    
    var authKey: String {
        return "\(HeaderValue.apiKey) \(mobileKey)"
    }
    var userAgent: String {
        return "\(systemName)/\(sdkVersion)"
    }
    
    var eventSourceHeaders: [String: String] {
        return [HeaderKey.authorization: authKey, HeaderKey.userAgent: userAgent]
    }
    var flagRequestHeaders: [String: String] {
        return [HeaderKey.authorization: authKey, HeaderKey.userAgent: userAgent]
    }
    var eventRequestHeaders: [String: String] {
        return [HeaderKey.authorization: authKey,
                HeaderKey.userAgent: userAgent,
                HeaderKey.contentType: HeaderValue.applicationJson,
                HeaderKey.accept: HeaderValue.applicationJson,
                HeaderKey.eventSchema: HeaderValue.eventSchema]
    }
}
