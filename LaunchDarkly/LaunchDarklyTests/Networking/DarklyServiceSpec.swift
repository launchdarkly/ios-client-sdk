//
//  DarklyServiceSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 9/27/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
import OHHTTPStubs
import DarklyEventSource
@testable import LaunchDarkly

final class DarklyServiceSpec: QuickSpec {
    
    typealias ServiceResponses = (data: Data?, urlResponse: URLResponse?, error: Error?)
    
    struct Constants {
        static let eventCount = 3

        static let emptyMobileKey = ""
    }

    struct TestContext {
        let user = LDUser.stub()
        var featureFlags: [LDFlagKey: FeatureFlag]! {
            return user.flagStore.featureFlags
        }
        var config: LDConfig!
        let mockEventDictionaries: [[String: Any]]?
        var serviceMock: DarklyServiceMock!
        var serviceFactoryMock: ClientServiceMockFactory? {
            return service.serviceFactory as? ClientServiceMockFactory
        }
        var service: DarklyService!

        init(mobileKey: String, useReport: Bool, includeMockEventDictionaries: Bool = false, operatingSystemName: String? = nil) {
            let serviceFactoryMock = ClientServiceMockFactory()
            if let operatingSystemName = operatingSystemName {
                serviceFactoryMock.makeEnvironmentReporterReturnValue.systemName = operatingSystemName
            }
            config = LDConfig.stub(mobileKey: mobileKey, environmentReporter: EnvironmentReportingMock())
            config.useReport = useReport
            mockEventDictionaries = includeMockEventDictionaries ? Event.stubEventDictionaries(Constants.eventCount, user: user, config: config) : nil
            serviceMock = DarklyServiceMock(config: config)
            service = DarklyService(config: config, user: user, serviceFactory: serviceFactoryMock)
        }
    }
    
    override func spec() {
        httpHeaderSpec()
        getFeatureFlagsSpec()
        createEventSourceSpec()
        publishEventDictionariesSpec()

        afterEach {
            OHHTTPStubs.removeAllStubs()
        }
    }

    private func httpHeaderSpec() {
        var testContext: TestContext!

        describe("init httpHeader") {
            beforeEach {
                testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: false, operatingSystemName: EnvironmentReportingMock.Constants.systemName)
            }
            it("creates a header with the specified user agent") {
                expect(testContext.service.httpHeaders.userAgent.hasPrefix(EnvironmentReportingMock.Constants.systemName)).to(beTrue())
            }
        }
    }

    private func getFeatureFlagsSpec() {
        var testContext: TestContext!

        describe("getFeatureFlags") {
            var responses: ServiceResponses?
            var getRequestCount = 0
            var reportRequestCount = 0
            beforeEach {
                responses = nil
                getRequestCount = 0
                reportRequestCount = 0
            }

            context("using GET method") {
                beforeEach {
                    testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: false)
                }
                context("success") {
                    beforeEach {
                        waitUntil { done in
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok, featureFlags: testContext.featureFlags, useReport: true) { (_, _, _) in
                                reportRequestCount += 1
                            }
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok, featureFlags: testContext.featureFlags, useReport: false) { (_, _, _) in
                                getRequestCount += 1
                            }
                            testContext.service.getFeatureFlags(useReport: false, completion: { (data, response, error) in
                                responses = (data, response, error)
                                done()
                            })
                        }
                    }
                    it("makes exactly one valid GET request") {
                        expect(getRequestCount) == 1
                        expect(reportRequestCount) == 0
                    }
                    it("calls completion with data, response, and no error") {
                        expect(responses).toNot(beNil())
                        expect(responses?.data).toNot(beNil())
                        expect(responses?.data == testContext.featureFlags.dictionaryValue.jsonData).to(beTrue())
                        expect(responses?.urlResponse?.httpStatusCode) == HTTPURLResponse.StatusCodes.ok
                        expect(responses?.error).to(beNil())
                    }
                }
                context("failure") {
                    beforeEach {
                        waitUntil { done in
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.internalServerError, useReport: true) { (_, _, _) in
                                reportRequestCount += 1
                            }
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.internalServerError, useReport: false) { (_, _, _) in
                                getRequestCount += 1
                            }
                            testContext.service.getFeatureFlags(useReport: false, completion: { (data, response, error) in
                                responses = (data, response, error)
                                done()
                            })
                        }
                    }
                    it("makes exactly one valid request") {
                        expect(getRequestCount) == 1
                        expect(reportRequestCount) == 0
                    }
                    it("calls completion with error and no data or response") {
                        expect(responses).toNot(beNil())
                        expect(responses?.data).toNot(beNil())
                        expect(responses?.data).to(beEmpty())
                        expect(responses?.urlResponse?.httpStatusCode) == HTTPURLResponse.StatusCodes.internalServerError
                        expect(responses?.error).to(beNil())
                    }
                }
                context("empty mobile key") {
                    beforeEach {
                        testContext = TestContext(mobileKey: Constants.emptyMobileKey, useReport: false)
                        testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok, useReport: true) { (_, _, _) in
                            reportRequestCount += 1
                        }
                        testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok, useReport: false) { (_, _, _) in
                            getRequestCount += 1
                        }
                        testContext.service.getFeatureFlags(useReport: false, completion: { (data, response, error) in
                            responses = (data, response, error)
                        })
                    }
                    it("does not make a request") {
                        expect(getRequestCount) == 0
                        expect(reportRequestCount) == 0
                        expect(responses).to(beNil())
                    }
                }
            }
            context("using REPORT method") {
                beforeEach {
                    testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: true)
                }
                context("success") {
                    beforeEach {
                        waitUntil { done in
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok, featureFlags: testContext.featureFlags, useReport: false) { (_, _, _) in
                                getRequestCount += 1
                            }
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok, featureFlags: testContext.featureFlags, useReport: true) { (_, _, _) in
                                reportRequestCount += 1
                            }
                            testContext.service.getFeatureFlags(useReport: true, completion: { (data, response, error) in
                                responses = (data, response, error)
                                done()
                            })
                        }
                    }
                    it("makes exactly one valid REPORT request") {
                        expect(getRequestCount) == 0
                        expect(reportRequestCount) == 1
                    }
                    it("calls completion with data, response, and no error") {
                        expect(responses).toNot(beNil())
                        expect(responses?.data).toNot(beNil())
                        expect(responses?.data == testContext.featureFlags.dictionaryValue.jsonData).to(beTrue())
                        expect(responses?.urlResponse?.httpStatusCode) == HTTPURLResponse.StatusCodes.ok
                        expect(responses?.error).to(beNil())
                    }
                }
                context("failure") {
                    beforeEach {
                        waitUntil { done in
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.internalServerError, useReport: true) { (_, _, _) in
                                reportRequestCount += 1
                            }
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.internalServerError, useReport: false) { (_, _, _) in
                                getRequestCount += 1
                            }
                            testContext.service.getFeatureFlags(useReport: true, completion: { (data, response, error) in
                                responses = (data, response, error)
                                done()
                            })
                        }
                    }
                    it("makes exactly one valid request") {
                        expect(getRequestCount) == 0
                        expect(reportRequestCount) == 1
                    }
                    it("calls completion with error and no data or response") {
                        expect(responses).toNot(beNil())
                        expect(responses?.data).toNot(beNil())
                        expect(responses?.data).to(beEmpty())
                        expect(responses?.urlResponse?.httpStatusCode) == HTTPURLResponse.StatusCodes.internalServerError
                        expect(responses?.error).to(beNil())
                    }
                }
                context("empty mobile key") {
                    beforeEach {
                        testContext = TestContext(mobileKey: Constants.emptyMobileKey, useReport: true)
                        testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok, useReport: false) { (_, _, _) in
                            getRequestCount += 1
                        }
                        testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok, useReport: true) { (_, _, _) in
                            reportRequestCount += 1
                        }
                        testContext.service.getFeatureFlags(useReport: true, completion: { (data, response, error) in
                            responses = (data, response, error)
                        })
                    }
                    it("does not make a request") {
                        expect(getRequestCount) == 0
                        expect(reportRequestCount) == 0
                        expect(responses).to(beNil())
                    }
                }
            }
        }
    }

    private func createEventSourceSpec() {
        var testContext: TestContext!

        describe("createEventSource") {
            var eventSource: DarklyStreamingProviderMock?
            context("when using GET method to connect") {
                beforeEach {
                    testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: false)
                    eventSource = testContext.service.createEventSource(useReport: false) as? DarklyStreamingProviderMock
                }
                it("creates an event source that makes valid GET request") {
                    expect(eventSource).toNot(beNil())
                    expect(testContext.serviceFactoryMock?.makeStreamingProviderCallCount) == 1
                    expect(testContext.serviceFactoryMock?.makeStreamingProviderReceivedArguments).toNot(beNil())
                    guard let receivedArguments = testContext.serviceFactoryMock?.makeStreamingProviderReceivedArguments
                    else {
                        return
                    }
                    expect(receivedArguments.url.host) == testContext.config.streamUrl.host
                    expect(receivedArguments.url.pathComponents.contains(DarklyService.StreamRequestPath.meval)).to(beTrue())
                    expect(receivedArguments.url.pathComponents.contains(DarklyService.StreamRequestPath.mping)).to(beFalse())
                    expect(receivedArguments.url.lastPathComponent) == testContext.user.dictionaryValueWithAllAttributes(includeFlagConfig: false).base64UrlEncodedString
                    expect(receivedArguments.httpHeaders).toNot(beEmpty())
                    expect(receivedArguments.connectMethod).to(beNil())
                    expect(receivedArguments.connectBody).to(beNil())
                }
            }
            context("when using REPORT method to connect") {
                beforeEach {
                    testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: true)
                    eventSource = testContext.service.createEventSource(useReport: true) as? DarklyStreamingProviderMock
                }
                it("creates an event source that makes valid REPORT request") {
                    expect(eventSource).toNot(beNil())
                    expect(testContext.serviceFactoryMock?.makeStreamingProviderCallCount) == 1
                    expect(testContext.serviceFactoryMock?.makeStreamingProviderReceivedArguments).toNot(beNil())
                    guard let receivedArguments = testContext.serviceFactoryMock?.makeStreamingProviderReceivedArguments
                    else {
                        return
                    }
                    expect(receivedArguments.url.host) == testContext.config.streamUrl.host
                    expect(receivedArguments.url.lastPathComponent) == DarklyService.StreamRequestPath.meval
                    expect(receivedArguments.url.pathComponents.contains(DarklyService.StreamRequestPath.mping)).to(beFalse())
                    expect(receivedArguments.httpHeaders).toNot(beEmpty())
                    expect(receivedArguments.connectMethod) == DarklyService.HTTPRequestMethod.report
                    expect(receivedArguments.connectBody) == testContext.user.dictionaryValueWithAllAttributes(includeFlagConfig: false).jsonData
                }
            }
        }
    }

    private func publishEventDictionariesSpec() {
        var testContext: TestContext!

        describe("publishEventDictionaries") {
            var eventRequest: URLRequest?

            beforeEach {
                eventRequest = nil
                testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: false, includeMockEventDictionaries: true)
            }
            context("success") {
                var responses: ServiceResponses!
                beforeEach {
                    waitUntil { done in
                        testContext.serviceMock.stubEventRequest(success: true) { (request, _, _) in
                            eventRequest = request
                        }
                        testContext.service.publishEventDictionaries(testContext.mockEventDictionaries!) { (data, response, error) in
                            responses = (data, response, error)
                            done()
                        }
                    }
                }
                it("makes a valid request") {
                    expect(eventRequest).toNot(beNil())
                    expect(eventRequest?.allHTTPHeaderFields?[HTTPHeaders.HeaderKey.eventSchema]) == HTTPHeaders.HeaderValue.eventSchema
                }
                it("calls completion with data, response, and no error") {
                    expect(responses.data).toNot(beNil())
                    expect(responses.urlResponse).toNot(beNil())
                    expect(responses.error).to(beNil())
                }
            }
            context("failure") {
                var responses: ServiceResponses!
                beforeEach {
                    waitUntil { done in
                        testContext.serviceMock.stubEventRequest(success: false) { (request, _, _) in
                            eventRequest = request
                        }
                        testContext.service.publishEventDictionaries(testContext.mockEventDictionaries!) { (data, response, error) in
                            responses = (data, response, error)
                            done()
                        }
                    }
                }
                it("makes a valid request") {
                    expect(eventRequest).toNot(beNil())
                    expect(eventRequest?.allHTTPHeaderFields?[HTTPHeaders.HeaderKey.eventSchema]) == HTTPHeaders.HeaderValue.eventSchema
                }
                it("calls completion with error and no data or response") {
                    expect(responses.data?.isEmpty ?? true) == true
                    expect(responses.urlResponse).to(beNil())
                    expect(responses.error).toNot(beNil())
                }
            }
            context("empty mobile key") {
                var responses: ServiceResponses!
                var eventsPublished = false
                beforeEach {
                    testContext = TestContext(mobileKey: Constants.emptyMobileKey, useReport: false, includeMockEventDictionaries: true)
                    testContext.serviceMock.stubEventRequest(success: true) { (request, _, _) in
                        eventRequest = request
                    }
                    testContext.service.publishEventDictionaries(testContext.mockEventDictionaries!) { (data, response, error) in
                        responses = (data, response, error)
                        eventsPublished = true
                    }
                }
                it("does not make a request") {
                    expect(eventRequest).to(beNil())
                    expect(eventsPublished) == false
                    expect(responses).to(beNil())
                }
            }
            context("empty event list") {
                var responses: ServiceResponses!
                var eventsPublished = false
                let emptyEventDictionaryList: [[String: Any]] = []
                beforeEach {
                    testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: false, includeMockEventDictionaries: true)
                    testContext.serviceMock.stubEventRequest(success: true) { (request, _, _) in
                        eventRequest = request
                    }
                    testContext.service.publishEventDictionaries(emptyEventDictionaryList) { (data, response, error) in
                        responses = (data, response, error)
                        eventsPublished = true
                    }
                }
                it("does not make a request") {
                    expect(eventRequest).to(beNil())
                    expect(eventsPublished) == false
                    expect(responses).to(beNil())
                }
            }
        }
    }
}

extension DarklyService.StreamRequestPath {
    static let mping = "mping"
}
