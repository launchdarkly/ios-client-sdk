//
//  HTTPHeadersSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import XCTest

@testable import LaunchDarkly

final class HTTPHeadersSpec: XCTestCase {

    private static var stubEtags: [String: String] = {
        var etags: [String: String] = [:]
        (0..<3).forEach { _ in etags[UUID().uuidString] = UUID().uuidString }
        return etags
    }()

    override func tearDown() {
        HTTPHeaders.removeFlagRequestEtags()
    }

    func testSettingFlagRequestEtags() {
        HTTPHeadersSpec.stubEtags.forEach { mobileKey, etag in
            HTTPHeaders.setFlagRequestEtag(etag, for: mobileKey)
        }
        XCTAssertEqual(HTTPHeaders.flagRequestEtags, HTTPHeadersSpec.stubEtags)
    }

    func testClearingIndividialFlagRequestEtags() {
        HTTPHeadersSpec.stubEtags.forEach { mobileKey, etag in
            HTTPHeaders.setFlagRequestEtag(etag, for: mobileKey)
        }
        HTTPHeadersSpec.stubEtags.forEach { mobileKey, _ in
            HTTPHeaders.setFlagRequestEtag(nil, for: mobileKey)
        }
        XCTAssert(HTTPHeaders.flagRequestEtags.isEmpty)
    }

    func testClearingAllFlagRequestEtags() {
        HTTPHeadersSpec.stubEtags.forEach { mobileKey, etag in
            HTTPHeaders.setFlagRequestEtag(etag, for: mobileKey)
        }
        HTTPHeaders.removeFlagRequestEtags()
        XCTAssert(HTTPHeaders.flagRequestEtags.isEmpty)
    }

    func testHasFlagRequestEtag() {
        let config = LDConfig(mobileKey: "with-etag")
        HTTPHeaders.setFlagRequestEtag("foo", for: "with-etag")
        let withoutEtag = HTTPHeaders(config: LDConfig.stub, environmentReporter: EnvironmentReportingMock())
        let withEtag = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        XCTAssertFalse(withoutEtag.hasFlagRequestEtag)
        XCTAssert(withEtag.hasFlagRequestEtag)
    }

    func testFlagRequestDefaultHeaders() {
        let config = LDConfig.stub
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let headers = httpHeaders.flagRequestHeaders
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.authorization],
                       "\(HTTPHeaders.HeaderValue.apiKey) \(config.mobileKey)")
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.userAgent],
               "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)")
        XCTAssertNil(headers[HTTPHeaders.HeaderKey.ifNoneMatch])
    }

    func testFlagRequestHeadersWithEtag() {
        let config = LDConfig.stub
        HTTPHeaders.setFlagRequestEtag("etag", for: config.mobileKey)
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let headers = httpHeaders.flagRequestHeaders
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.authorization],
                       "\(HTTPHeaders.HeaderValue.apiKey) \(config.mobileKey)")
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.userAgent],
               "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)")
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.ifNoneMatch], "etag")
    }

    func testEventSourceDefaultHeaders() {
        let config = LDConfig.stub
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let headers = httpHeaders.eventSourceHeaders
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.authorization],
                       "\(HTTPHeaders.HeaderValue.apiKey) \(config.mobileKey)")
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.userAgent],
                       "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)")
    }

    func testEventRequestDefaultHeaders() {
        let config = LDConfig.stub
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let headers = httpHeaders.eventRequestHeaders
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.authorization],
                       "\(HTTPHeaders.HeaderValue.apiKey) \(config.mobileKey)")
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.userAgent],
                       "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)")
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.contentType], HTTPHeaders.HeaderValue.applicationJson)
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.accept], HTTPHeaders.HeaderValue.applicationJson)
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.eventSchema], HTTPHeaders.HeaderValue.eventSchema3)
    }

    func testDiagnosticRequestDefaultHeaders() {
        let config = LDConfig.stub
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let headers = httpHeaders.diagnosticRequestHeaders
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.authorization],
                       "\(HTTPHeaders.HeaderValue.apiKey) \(config.mobileKey)")
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.userAgent],
                       "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)")
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.contentType], HTTPHeaders.HeaderValue.applicationJson)
        XCTAssertEqual(headers[HTTPHeaders.HeaderKey.accept], HTTPHeaders.HeaderValue.applicationJson)
        XCTAssertNil(headers[HTTPHeaders.HeaderKey.eventSchema])
    }

    func testWrapperNameIncludedInHeaders() {
        var config = LDConfig.stub
        config.wrapperName = "test-wrapper"
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let allRequestTypes = [httpHeaders.flagRequestHeaders,
                               httpHeaders.eventSourceHeaders,
                               httpHeaders.eventRequestHeaders,
                               httpHeaders.diagnosticRequestHeaders]
        allRequestTypes.forEach { headers in
            XCTAssertEqual(headers["X-LaunchDarkly-Wrapper"], "test-wrapper")
        }
    }

    func testOnlyWrapperVersionNotIncludedInHeaders() {
        var config = LDConfig.stub
        config.wrapperVersion = "0.1.0"
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let allRequestTypes = [httpHeaders.flagRequestHeaders,
                               httpHeaders.eventSourceHeaders,
                               httpHeaders.eventRequestHeaders,
                               httpHeaders.diagnosticRequestHeaders]
        allRequestTypes.forEach { headers in
            XCTAssertNil(headers["X-LaunchDarkly-Wrapper"])
        }
    }

    func testWrapperNameAndVersionIncludedInHeaders() {
        var config = LDConfig.stub
        config.wrapperName = "test-wrapper"
        config.wrapperVersion = "0.1.0"
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let allRequestTypes = [httpHeaders.flagRequestHeaders,
                               httpHeaders.eventSourceHeaders,
                               httpHeaders.eventRequestHeaders,
                               httpHeaders.diagnosticRequestHeaders]
        allRequestTypes.forEach { headers in
            XCTAssertEqual(headers["X-LaunchDarkly-Wrapper"], "test-wrapper/0.1.0")
        }
    }

    func testAdditionalHeadersInConfig() {
        var config = LDConfig.stub
        config.additionalHeaders = ["Proxy-Authorization": "token",
                                    HTTPHeaders.HeaderKey.authorization: "feh"]
        let httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
        let allRequestTypes = [httpHeaders.flagRequestHeaders,
                               httpHeaders.eventSourceHeaders,
                               httpHeaders.eventRequestHeaders,
                               httpHeaders.diagnosticRequestHeaders]
        allRequestTypes.forEach { headers in
            XCTAssertEqual(headers["Proxy-Authorization"], "token", "Should include additional headers")
            XCTAssertEqual(headers[HTTPHeaders.HeaderKey.authorization], "feh", "Should overwrite headers")
        }
    }
}
