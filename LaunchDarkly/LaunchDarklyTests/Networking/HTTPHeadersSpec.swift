//
//  HTTPHeadersSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 3/12/19. +JMJ
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class HTTPHeadersSpec: QuickSpec {

    struct Constants {
        static let mobileKeyCount = 3
    }

    struct TestContext {
        var config: LDConfig
        var httpHeaders: HTTPHeaders
        var flagRequestEtags = [String: String]()

        init(mobileKeyCount: Int = Constants.mobileKeyCount) {
            config = LDConfig.stub

            httpHeaders = HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())

            while flagRequestEtags.count < mobileKeyCount {
                flagRequestEtags[UUID().uuidString] = UUID().uuidString
            }
        }
    }

    override func spec() {
        initSpec()
        eventSourceHeadersSpec()
        flagRequestHeadersSpec()
        flagRequestEtagsSpec()
        hasFlagRequestEtagSpec()
        eventRequestHeadersSpec()
    }

    private func initSpec() {
        var testContext: TestContext!
        describe("init") {
            context("with basic elements") {
                beforeEach {
                    testContext = TestContext()
                }
                it("creates a HTTPHeaders instance with the corresponding elements") {
                    expect(testContext.httpHeaders.mobileKey) == testContext.config.mobileKey
                    expect(testContext.httpHeaders.systemName) == EnvironmentReportingMock.Constants.systemName
                    expect(testContext.httpHeaders.sdkVersion) == EnvironmentReportingMock.Constants.sdkVersion
                }
            }
        }
    }

    private func eventSourceHeadersSpec() {
        var testContext: TestContext!
        describe("eventSourceHeaders") {
            context("with basic elements") {
                var headers: [String: String]!
                beforeEach {
                    testContext = TestContext()

                    headers = testContext.httpHeaders.eventSourceHeaders
                }
                it("creates headers with authorization and user agent") {
                    expect(headers[HTTPHeaders.HeaderKey.authorization]) == "\(HTTPHeaders.HeaderValue.apiKey) \(testContext.config.mobileKey)"
                    expect(headers[HTTPHeaders.HeaderKey.userAgent]) == "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)"
                }
            }
        }
    }

    private func flagRequestHeadersSpec() {
        var testContext: TestContext!
        describe("flagRequestHeaders") {
            afterEach {
                HTTPHeaders.removeFlagRequestEtags()
            }
            context("without etags") {
                var headers: [String: String]!
                beforeEach {
                    testContext = TestContext()

                    headers = testContext.httpHeaders.flagRequestHeaders
                }
                it("creates headers with authorization and user agent") {
                    expect(headers[HTTPHeaders.HeaderKey.authorization]) == "\(HTTPHeaders.HeaderValue.apiKey) \(testContext.config.mobileKey)"
                    expect(headers[HTTPHeaders.HeaderKey.userAgent]) == "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)"
                    expect(headers[HTTPHeaders.HeaderKey.ifNoneMatch]).to(beNil())
                }
            }
            context("with an etag for the selected environment") {
                var etag: String!
                var headers: [String: String]!
                beforeEach {
                    testContext = TestContext()
                    etag = UUID().uuidString
                    HTTPHeaders.setFlagRequestEtag(etag, for: testContext.config.mobileKey)
                    testContext.flagRequestEtags.forEach { (mobileKey, otherEtag) in
                        HTTPHeaders.setFlagRequestEtag(otherEtag, for: mobileKey)
                    }

                    headers = testContext.httpHeaders.flagRequestHeaders
                }
                it("creates headers with authorization and user agent") {
                    expect(headers[HTTPHeaders.HeaderKey.authorization]) == "\(HTTPHeaders.HeaderValue.apiKey) \(testContext.config.mobileKey)"
                    expect(headers[HTTPHeaders.HeaderKey.userAgent]) == "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)"
                    expect(headers[HTTPHeaders.HeaderKey.ifNoneMatch]) == etag
                }
            }
        }
    }

    private func flagRequestEtagsSpec() {
        var testContext: TestContext!
        describe("flagRequestEtags") {
            afterEach {
                HTTPHeaders.removeFlagRequestEtags()
            }
            context("setting tags") {
                beforeEach {
                    testContext = TestContext()

                    testContext.flagRequestEtags.forEach { (mobileKey, etag) in
                        HTTPHeaders.setFlagRequestEtag(etag, for: mobileKey)
                    }
                }
                it("sets the etag for each mobileKey") {
                    expect(HTTPHeaders.flagRequestEtags.count) == testContext.flagRequestEtags.count
                    testContext.flagRequestEtags.forEach { (mobileKey, etag) in
                        expect(HTTPHeaders.flagRequestEtags[mobileKey]) == etag
                    }
                }
            }
            context("clearing all tags") {
                beforeEach {
                    testContext = TestContext()

                    testContext.flagRequestEtags.forEach { (mobileKey, etag) in
                        HTTPHeaders.setFlagRequestEtag(etag, for: mobileKey)
                    }

                    HTTPHeaders.removeFlagRequestEtags()
                }
                it("removes all etags") {
                    expect(HTTPHeaders.flagRequestEtags.count) == 0
                }
            }
            context("clearing single tags") {
                beforeEach {
                    testContext = TestContext()
                    testContext.flagRequestEtags.forEach { (mobileKey, etag) in
                        HTTPHeaders.setFlagRequestEtag(etag, for: mobileKey)
                    }

                    testContext.flagRequestEtags.keys.forEach { (mobileKey) in
                        HTTPHeaders.setFlagRequestEtag(nil, for: mobileKey)
                    }
                }
                it("removes all etags") {
                    expect(HTTPHeaders.flagRequestEtags.count) == 0
                }
            }
        }
    }

    private func hasFlagRequestEtagSpec() {
        var testContext: TestContext!
        describe("hasFlagRequestEtag") {
            afterEach {
                HTTPHeaders.removeFlagRequestEtags()
            }
            context("when etag exists") {
                beforeEach {
                    testContext = TestContext()
                    //while not really needed, sets a population of etags to pick from for the test
                    testContext.flagRequestEtags.forEach { (mobileKey, etag) in
                        HTTPHeaders.setFlagRequestEtag(etag, for: mobileKey)
                    }
                    HTTPHeaders.setFlagRequestEtag(UUID().uuidString, for: testContext.config.mobileKey)
                }
                it("returns true") {
                    expect(testContext.httpHeaders.hasFlagRequestEtag) == true
                }
            }
            context("when etag does not exist") {
                beforeEach {
                    testContext = TestContext()
                    //while not really needed, sets a population of etags to pick from for the test
                    testContext.flagRequestEtags.forEach { (mobileKey, etag) in
                        HTTPHeaders.setFlagRequestEtag(etag, for: mobileKey)
                    }
                }
                it("returns false") {
                    expect(testContext.httpHeaders.hasFlagRequestEtag) == false
                }
            }
        }
    }

    private func eventRequestHeadersSpec() {
        var testContext: TestContext!
        describe("eventRequestHeaders") {
            context("with basic elements") {
                var headers: [String: String]!
                beforeEach {
                    testContext = TestContext()

                    headers = testContext.httpHeaders.eventRequestHeaders
                }
                it("creates headers with elements") {
                    expect(headers[HTTPHeaders.HeaderKey.authorization]) == "\(HTTPHeaders.HeaderValue.apiKey) \(testContext.config.mobileKey)"
                    expect(headers[HTTPHeaders.HeaderKey.userAgent]) == "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)"
                    expect(headers[HTTPHeaders.HeaderKey.contentType]) == HTTPHeaders.HeaderValue.applicationJson
                    expect(headers[HTTPHeaders.HeaderKey.accept]) == HTTPHeaders.HeaderValue.applicationJson
                    expect(headers[HTTPHeaders.HeaderKey.eventSchema]) == HTTPHeaders.HeaderValue.eventSchema3
                }
            }
        }
    }
}

extension HTTPHeaders {
    struct Constants {
        static let eventSourceHeaders =
            [HTTPHeaders.HeaderKey.authorization: "\(HTTPHeaders.HeaderValue.apiKey) \(LDConfig.Constants.mockMobileKey)",
            HTTPHeaders.HeaderKey.userAgent: "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)"]
    }

    //TODO: Remove if unused
    static func stub(config: LDConfig) -> HTTPHeaders {
        return HTTPHeaders(config: config, environmentReporter: EnvironmentReportingMock())
    }
}
