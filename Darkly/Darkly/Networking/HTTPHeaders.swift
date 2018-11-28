//
//  HTTPHeaders.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 9/19/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
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
        static let sdkVersion = "3.0.0.28"
        static let applicationJson = "application/json"
        static let eventSchema = "3"
    }
    
    let mobileKey: String
    let systemName: String
    
    init(mobileKey: String, environmentReporter: EnvironmentReporting) {
        self.mobileKey = mobileKey
        self.systemName = environmentReporter.systemName
    }
    
    var authKey: String { return "\(HeaderValue.apiKey) \(mobileKey)" }
    var userAgent: String { return "\(systemName)/\(HeaderValue.sdkVersion)" }
    
    var eventSourceHeaders: [String: String] { return [HeaderKey.authorization: authKey, HeaderKey.userAgent: userAgent] }
    var flagRequestHeaders: [String: String] { return [HeaderKey.authorization: authKey, HeaderKey.userAgent: userAgent] }
    var eventRequestHeaders: [String: String] { return [HeaderKey.authorization: authKey,
                                                        HeaderKey.userAgent: userAgent,
                                                        HeaderKey.contentType: HeaderValue.applicationJson,
                                                        HeaderKey.accept: HeaderValue.applicationJson,
                                                        HeaderKey.eventSchema: HeaderValue.eventSchema] }
}
