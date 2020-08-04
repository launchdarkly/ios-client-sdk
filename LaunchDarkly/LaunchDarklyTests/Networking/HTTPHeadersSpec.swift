//
//  HTTPHeadersSpec.swift
//  LaunchDarklyTests
//
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

        init(config: LDConfig? = nil, mobileKeyCount: Int = Constants.mobileKeyCount) {
            self.config = config ?? LDConfig.stub

            httpHeaders = HTTPHeaders(config: self.config, environmentReporter: EnvironmentReportingMock())

            while flagRequestEtags.count < mobileKeyCount {
                flagRequestEtags[UUID().uuidString] = UUID().uuidString
            }
        }
    }

    override func spec() {
        eventSourceHeadersSpec()
        flagRequestHeadersSpec()
        flagRequestEtagsSpec()
        hasFlagRequestEtagSpec()
        eventRequestHeadersSpec()
        diagnosticRequestHeadersSpec()
    }

    private func eventSourceHeadersSpec() {
        var testContext: TestContext!
        var headers: [String: String]!
        describe("eventSourceHeaders") {
            context("with basic elements") {
                beforeEach {
                    testContext = TestContext()
                    headers = testContext.httpHeaders.eventSourceHeaders
                }
                it("creates headers with authorization and user agent") {
                    expect(headers[HTTPHeaders.HeaderKey.authorization]) == "\(HTTPHeaders.HeaderValue.apiKey) \(testContext.config.mobileKey)"
                    expect(headers[HTTPHeaders.HeaderKey.userAgent]) == "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)"
                }
            }
            context("with wrapperName set") {
                beforeEach {
                    var config = LDConfig.stub
                    config.wrapperName = "test-wrapper"
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.eventSourceHeaders
                }
                it("creates headers with wrapper set") {
                    expect(headers["X-LaunchDarkly-Wrapper"]) == "test-wrapper"
                }
            }
            context("with wrapperVersion set") {
                beforeEach {
                    var config = LDConfig.stub
                    config.wrapperVersion = "0.1.0"
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.eventSourceHeaders
                }
                it("creates headers without wrapper set") {
                    expect(headers["X-LaunchDarkly-Wrapper"]).to(beNil())
                }
            }
            context("with wrapperName and wrapperVersion set") {
                beforeEach {
                    var config = LDConfig.stub
                    config.wrapperName = "test-wrapper"
                    config.wrapperVersion = "0.1.0"
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.eventSourceHeaders
                }
                it("creates headers with wrapper set to combined values") {
                    expect(headers["X-LaunchDarkly-Wrapper"]) == "test-wrapper/0.1.0"
                }
            }
            context("with additional headers") {
                beforeEach {
                    var config = LDConfig.stub
                    config.additionalHeaders = ["Proxy-Authorization": "token",
                                                HTTPHeaders.HeaderKey.authorization: "feh"]
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.eventSourceHeaders
                }
                it("creates headers including new headers") {
                    expect(headers["Proxy-Authorization"]) == "token"
                }
                it("overrides SDK set headers") {
                    expect(headers[HTTPHeaders.HeaderKey.authorization]) == "feh"
                }
            }
        }
    }

    private func flagRequestHeadersSpec() {
        var testContext: TestContext!
        var headers: [String: String]!
        describe("flagRequestHeaders") {
            afterEach {
                HTTPHeaders.removeFlagRequestEtags()
            }
            context("without etags") {
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
                beforeEach {
                    testContext = TestContext()
                    etag = UUID().uuidString
                    HTTPHeaders.setFlagRequestEtag(etag, for: testContext.config.mobileKey)
                    testContext.flagRequestEtags.forEach { mobileKey, otherEtag in
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
            context("with wrapperName set") {
                beforeEach {
                    var config = LDConfig.stub
                    config.wrapperName = "test-wrapper"
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.flagRequestHeaders
                }
                it("creates headers with wrapper set") {
                    expect(headers["X-LaunchDarkly-Wrapper"]) == "test-wrapper"
                }
            }
            context("with wrapperVersion set") {
                beforeEach {
                    var config = LDConfig.stub
                    config.wrapperVersion = "0.1.0"
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.flagRequestHeaders
                }
                it("creates headers without wrapper set") {
                    expect(headers["X-LaunchDarkly-Wrapper"]).to(beNil())
                }
            }
            context("with wrapperName and wrapperVersion set") {
                beforeEach {
                    var config = LDConfig.stub
                    config.wrapperName = "test-wrapper"
                    config.wrapperVersion = "0.1.0"
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.flagRequestHeaders
                }
                it("creates headers with wrapper set to combined values") {
                    expect(headers["X-LaunchDarkly-Wrapper"]) == "test-wrapper/0.1.0"
                }
            }
            context("with additional headers") {
                beforeEach {
                    var config = LDConfig.stub
                    config.additionalHeaders = ["Proxy-Authorization": "token",
                                                HTTPHeaders.HeaderKey.authorization: "feh"]
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.flagRequestHeaders
                }
                it("creates headers including new headers") {
                    expect(headers["Proxy-Authorization"]) == "token"
                }
                it("overrides SDK set headers") {
                    expect(headers[HTTPHeaders.HeaderKey.authorization]) == "feh"
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

                    testContext.flagRequestEtags.forEach { mobileKey, etag in
                        HTTPHeaders.setFlagRequestEtag(etag, for: mobileKey)
                    }
                }
                it("sets the etag for each mobileKey") {
                    expect(HTTPHeaders.flagRequestEtags.count) == testContext.flagRequestEtags.count
                    testContext.flagRequestEtags.forEach { mobileKey, etag in
                        expect(HTTPHeaders.flagRequestEtags[mobileKey]) == etag
                    }
                }
            }
            context("clearing all tags") {
                beforeEach {
                    testContext = TestContext()

                    testContext.flagRequestEtags.forEach { mobileKey, etag in
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
                    testContext.flagRequestEtags.forEach { mobileKey, etag in
                        HTTPHeaders.setFlagRequestEtag(etag, for: mobileKey)
                    }

                    testContext.flagRequestEtags.keys.forEach { mobileKey in
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
                    testContext.flagRequestEtags.forEach { mobileKey, etag in
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
                    testContext.flagRequestEtags.forEach { mobileKey, etag in
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
        var headers: [String: String]!
        describe("eventRequestHeaders") {
            context("with basic elements") {
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
            context("with wrapperName set") {
                beforeEach {
                    var config = LDConfig.stub
                    config.wrapperName = "test-wrapper"
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.eventRequestHeaders
                }
                it("creates headers with wrapper set") {
                    expect(headers["X-LaunchDarkly-Wrapper"]) == "test-wrapper"
                }
            }
            context("with wrapperVersion set") {
                beforeEach {
                    var config = LDConfig.stub
                    config.wrapperVersion = "0.1.0"
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.eventRequestHeaders
                }
                it("creates headers without wrapper set") {
                    expect(headers["X-LaunchDarkly-Wrapper"]).to(beNil())
                }
            }
            context("with wrapperName and wrapperVersion set") {
                beforeEach {
                    var config = LDConfig.stub
                    config.wrapperName = "test-wrapper"
                    config.wrapperVersion = "0.1.0"
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.eventRequestHeaders
                }
                it("creates headers with wrapper set to combined values") {
                    expect(headers["X-LaunchDarkly-Wrapper"]) == "test-wrapper/0.1.0"
                }
            }
            context("with additional headers") {
                beforeEach {
                    var config = LDConfig.stub
                    config.additionalHeaders = ["Proxy-Authorization": "token",
                                                HTTPHeaders.HeaderKey.authorization: "feh"]
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.flagRequestHeaders
                }
                it("creates headers including new headers") {
                    expect(headers["Proxy-Authorization"]) == "token"
                }
                it("overrides SDK set headers") {
                    expect(headers[HTTPHeaders.HeaderKey.authorization]) == "feh"
                }
            }
        }
    }

    private func diagnosticRequestHeadersSpec() {
        var testContext: TestContext!
        var headers: [String: String]!
        describe("diagnosticRequestHeaders") {
            context("with basic elements") {
                beforeEach {
                    testContext = TestContext()
                    headers = testContext.httpHeaders.diagnosticRequestHeaders
                }
                it("creates headers with elements") {
                    expect(headers[HTTPHeaders.HeaderKey.authorization]) == "\(HTTPHeaders.HeaderValue.apiKey) \(testContext.config.mobileKey)"
                    expect(headers[HTTPHeaders.HeaderKey.userAgent]) == "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)"
                    expect(headers[HTTPHeaders.HeaderKey.contentType]) == HTTPHeaders.HeaderValue.applicationJson
                    expect(headers[HTTPHeaders.HeaderKey.accept]) == HTTPHeaders.HeaderValue.applicationJson
                    expect(headers[HTTPHeaders.HeaderKey.eventSchema]).to(beNil())
                }
            }
            context("with wrapperName set") {
                beforeEach {
                    var config = LDConfig.stub
                    config.wrapperName = "test-wrapper"
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.diagnosticRequestHeaders
                }
                it("creates headers with wrapper set") {
                    expect(headers["X-LaunchDarkly-Wrapper"]) == "test-wrapper"
                }
            }
            context("with wrapperVersion set") {
                beforeEach {
                    var config = LDConfig.stub
                    config.wrapperVersion = "0.1.0"
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.diagnosticRequestHeaders
                }
                it("creates headers without wrapper set") {
                    expect(headers["X-LaunchDarkly-Wrapper"]).to(beNil())
                }
            }
            context("with wrapperName and wrapperVersion set") {
                beforeEach {
                    var config = LDConfig.stub
                    config.wrapperName = "test-wrapper"
                    config.wrapperVersion = "0.1.0"
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.diagnosticRequestHeaders
                }
                it("creates headers with wrapper set to combined values") {
                    expect(headers["X-LaunchDarkly-Wrapper"]) == "test-wrapper/0.1.0"
                }
            }
            context("with additional headers") {
                beforeEach {
                    var config = LDConfig.stub
                    config.additionalHeaders = ["Proxy-Authorization": "token",
                                                HTTPHeaders.HeaderKey.authorization: "feh"]
                    testContext = TestContext(config: config)
                    headers = testContext.httpHeaders.flagRequestHeaders
                }
                it("creates headers including new headers") {
                    expect(headers["Proxy-Authorization"]) == "token"
                }
                it("overrides SDK set headers") {
                    expect(headers[HTTPHeaders.HeaderKey.authorization]) == "feh"
                }
            }
        }
    }
}
