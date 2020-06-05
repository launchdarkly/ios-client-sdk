//
//  HTTPHeaders.swift
//  LaunchDarkly
//
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
        static let ifNoneMatch = "If-None-Match"
        static let eventPayloadIDHeader = "X-LaunchDarkly-Payload-ID"
    }

    struct HeaderValue {
        static let apiKey = "api_key"
        static let applicationJson = "application/json"
        static let eventSchema3 = "3"
    }

    private(set) static var flagRequestEtags = [String: String]()

    static func removeFlagRequestEtags() {
        flagRequestEtags.removeAll()
    }

    static func setFlagRequestEtag(_ etag: String?, for mobileKey: String) {
        flagRequestEtags[mobileKey] = etag
    }
    
    let mobileKey: String
    let systemName: String
    let sdkVersion: String
    
    init(config: LDConfig, environmentReporter: EnvironmentReporting) {
        self.mobileKey = config.mobileKey
        self.systemName = environmentReporter.systemName
        self.sdkVersion = environmentReporter.sdkVersion
    }
    
    private var authKey: String {
        return "\(HeaderValue.apiKey) \(mobileKey)"
    }
    private var userAgent: String {
        return "\(systemName)/\(sdkVersion)"
    }
    var eventSourceHeaders: [String: String] {
        return [HeaderKey.authorization: authKey, HeaderKey.userAgent: userAgent]
    }
    var flagRequestHeaders: [String: String] {
        var headers = [HeaderKey.authorization: authKey, HeaderKey.userAgent: userAgent]
        if let etag = HTTPHeaders.flagRequestEtags[mobileKey] {
            headers[HeaderKey.ifNoneMatch] = etag
        }
        return headers
    }
    var hasFlagRequestEtag: Bool {
        HTTPHeaders.flagRequestEtags[mobileKey] != nil
    }
    var eventRequestHeaders: [String: String] {
        return [HeaderKey.authorization: authKey,
                HeaderKey.userAgent: userAgent,
                HeaderKey.contentType: HeaderValue.applicationJson,
                HeaderKey.accept: HeaderValue.applicationJson,
                HeaderKey.eventSchema: HeaderValue.eventSchema3]
    }
}
