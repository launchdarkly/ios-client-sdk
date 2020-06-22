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
        static let sdkWrapper = "X-LaunchDarkly-Wrapper"
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

    private let mobileKey: String
    private let authKey: String
    private let userAgent: String
    private let wrapperHeaderVal: String?

    init(config: LDConfig, environmentReporter: EnvironmentReporting) {
        self.mobileKey = config.mobileKey
        self.userAgent = "\(environmentReporter.systemName)/\(environmentReporter.sdkVersion)"
        self.authKey = "\(HeaderValue.apiKey) \(config.mobileKey)"

        if let wrapperName = config.wrapperName {
            if let wrapperVersion = config.wrapperVersion {
                wrapperHeaderVal = "\(wrapperName)/\(wrapperVersion)"
            } else {
                wrapperHeaderVal = wrapperName
            }
        } else {
            wrapperHeaderVal = nil
        }
    }

    private var baseHeaders: [String: String] {
        var headers = [HeaderKey.authorization: authKey,
                       HeaderKey.userAgent: userAgent]

        if let wrapperHeader = wrapperHeaderVal {
            headers[HeaderKey.sdkWrapper] = wrapperHeader
        }

        return headers
    }

    var eventSourceHeaders: [String: String] { baseHeaders }

    var flagRequestHeaders: [String: String] {
        var headers = baseHeaders
        if let etag = HTTPHeaders.flagRequestEtags[mobileKey] {
            headers[HeaderKey.ifNoneMatch] = etag
        }
        return headers
    }

    var hasFlagRequestEtag: Bool {
        HTTPHeaders.flagRequestEtags[mobileKey] != nil
    }

    var eventRequestHeaders: [String: String] {
        var headers = baseHeaders
        headers[HeaderKey.contentType] = HeaderValue.applicationJson
        headers[HeaderKey.accept] = HeaderValue.applicationJson
        headers[HeaderKey.eventSchema] = HeaderValue.eventSchema3
        return headers
    }

    var diagnosticRequestHeaders: [String: String] {
        var headers = baseHeaders
        headers[HeaderKey.contentType] = HeaderValue.applicationJson
        headers[HeaderKey.accept] = HeaderValue.applicationJson
        return headers
    }
}
