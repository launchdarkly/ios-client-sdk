//
//  DarklyServiceSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 9/27/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
import OHHTTPStubs
import DarklyEventSource
@testable import Darkly

final class DarklyServiceSpec: QuickSpec {
    
    typealias ServiceResponses = (data: Data?, urlResponse: URLResponse?, error: Error?)!
    
    struct Constants {
        static let eventCount = 3

        static let emptyMobileKey = ""
        static let mockMobileKey = "mockMobileKey"
    }

    struct TestContext {
        let user = LDUser.stub()
        var config: LDConfig!
        let mockEventDictionaries: [[String: Any]]?
        var serviceMock: DarklyServiceMock!
        var subject: DarklyService!

        init(mobileKey: String, useReport: Bool, includeMockEventDictionaries: Bool = false) {
            config = LDConfig.stub
            config.useReport = useReport
            mockEventDictionaries = includeMockEventDictionaries ? LDEvent.stubEventDictionaries(Constants.eventCount, user: user, config: config) : nil
            serviceMock = DarklyServiceMock(config: config)
            subject = DarklyService(mobileKey: mobileKey, config: config, user: user)
        }
    }
    
    override func spec() {
        getFeatureFlagsSpec()
        createEventSourceSpec()
        publishEventDictionariesSpec()

        afterEach {
            OHHTTPStubs.removeAllStubs()
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
                    testContext = TestContext(mobileKey: Constants.mockMobileKey, useReport: false)
                }
                context("success") {
                    beforeEach {
                        waitUntil { done in
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok, useReport: true) { (_, _, _) in
                                reportRequestCount += 1
                            }
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok, useReport: false) { (_, _, _) in
                                getRequestCount += 1
                            }
                            testContext.subject.getFeatureFlags(useReport: false, completion: { (data, response, error) in
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
                        expect(responses?.data == DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true).dictionaryValue(exciseNil: false).jsonData).to(beTrue())
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
                            testContext.subject.getFeatureFlags(useReport: false, completion: { (data, response, error) in
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
                        testContext.subject.getFeatureFlags(useReport: false, completion: { (data, response, error) in
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
                    testContext = TestContext(mobileKey: Constants.mockMobileKey, useReport: true)
                }
                context("success") {
                    beforeEach {
                        waitUntil { done in
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok, useReport: false) { (_, _, _) in
                                getRequestCount += 1
                            }
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok, useReport: true) { (_, _, _) in
                                reportRequestCount += 1
                            }
                            testContext.subject.getFeatureFlags(useReport: true, completion: { (data, response, error) in
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
                        expect(responses?.data == DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true).dictionaryValue(exciseNil: false).jsonData).to(beTrue())
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
                            testContext.subject.getFeatureFlags(useReport: true, completion: { (data, response, error) in
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
                        testContext.subject.getFeatureFlags(useReport: true, completion: { (data, response, error) in
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
            var streamRequest: URLRequest?
            var eventSource: DarklyStreamingProvider!
            context("when using GET method to connect") {
                beforeEach {
                    testContext = TestContext(mobileKey: Constants.mockMobileKey, useReport: false)
                    // The LDEventSource constructor waits ~1s and then triggers a request to open the streaming connection. Adding the timeout gives it time to make the request.
                    waitUntil(timeout: 3) { done in
                        testContext.serviceMock.stubStreamRequest(useReport: false, success: true) { (request, _, _) in
                            streamRequest = request
                            OHHTTPStubs.removeAllStubs()
                            done()
                        }

                        eventSource = testContext.subject.createEventSource(useReport: false)
                    }
                }
                it("creates an event source that makes valid GET request") {
                    expect(eventSource).toNot(beNil())
                    expect(streamRequest?.httpMethod) == DarklyService.HTTPRequestMethod.get
                    expect(streamRequest?.httpBody).to(beNil())
                    expect(streamRequest?.httpBodyStream).to(beNil())
                    expect(streamRequest?.url).toNot(beNil())
                    guard let requestUrl = streamRequest?.url else { return }
                    expect(requestUrl.host) == testContext.config.streamUrl.host
                    expect(requestUrl.pathComponents.contains(DarklyService.StreamRequestPath.meval)).to(beTrue())
                    expect(requestUrl.pathComponents.contains(DarklyService.StreamRequestPath.mping)).to(beFalse())
                    expect(requestUrl.lastPathComponent) == testContext.user.dictionaryValueWithAllAttributes(includeFlagConfig: false).base64UrlEncodedString
                }
                afterEach {
                    eventSource.close()
                }
            }
            context("when using REPORT method to connect") {
                beforeEach {
                    testContext = TestContext(mobileKey: Constants.mockMobileKey, useReport: true)
                    // The LDEventSource constructor waits ~1s and then triggers a request to open the streaming connection. Adding the timeout gives it time to make the request.
                    waitUntil(timeout: 3) { done in
                        testContext.serviceMock.stubStreamRequest(useReport: true, success: true) { (request, _, _) in
                            streamRequest = request
                            OHHTTPStubs.removeAllStubs()
                            done()
                        }

                        eventSource = testContext.subject.createEventSource(useReport: true)
                    }
                }
                it("creates an event source that makes valid REPORT request") {
                    expect(eventSource).toNot(beNil())
                    expect(streamRequest?.httpMethod) == DarklyService.HTTPRequestMethod.report
                    //NOTE: Apple's url loading system might be replacing httpBody with httpBodyStream, so by the time its captured, httpBody is nil and httpBodyStream is set.
                    //See https://stackoverflow.com/questions/36061918/how-can-i-get-data-out-of-nsurlrequest-config-object/37095907#37095907
                    if streamRequest?.httpBody != nil {
                        expect(streamRequest?.httpBody) == testContext.user.dictionaryValueWithAllAttributes(includeFlagConfig: false).jsonData
                    } else {
                        expect(streamRequest?.httpBodyStream).toNot(beNil())
                    }
                    expect(streamRequest?.url).toNot(beNil())
                    guard let requestUrl = streamRequest?.url else { return }
                    expect(requestUrl.host) == testContext.config.streamUrl.host
                    expect(requestUrl.pathComponents.contains(DarklyService.StreamRequestPath.mping)).to(beFalse())
                    expect(requestUrl.lastPathComponent) == DarklyService.StreamRequestPath.meval
                }
                afterEach {
                    eventSource.close()
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
                testContext = TestContext(mobileKey: Constants.mockMobileKey, useReport: false, includeMockEventDictionaries: true)
            }
            context("success") {
                var responses: ServiceResponses
                beforeEach {
                    waitUntil { done in
                        testContext.serviceMock.stubEventRequest(success: true) { (request, _, _) in
                            eventRequest = request
                        }
                        testContext.subject.publishEventDictionaries(testContext.mockEventDictionaries!) { (data, response, error) in
                            responses = (data, response, error)
                            done()
                        }
                    }
                }
                it("makes a valid request") {
                    expect(eventRequest).toNot(beNil())
                }
                it("calls completion with data, response, and no error") {
                    expect(responses.data).toNot(beNil())
                    expect(responses.urlResponse).toNot(beNil())
                    expect(responses.error).to(beNil())
                }
            }
            context("failure") {
                var responses: ServiceResponses
                beforeEach {
                    waitUntil { done in
                        testContext.serviceMock.stubEventRequest(success: false) { (request, _, _) in
                            eventRequest = request
                        }
                        testContext.subject.publishEventDictionaries(testContext.mockEventDictionaries!) { (data, response, error) in
                            responses = (data, response, error)
                            done()
                        }
                    }
                }
                it("makes a valid request") {
                    expect(eventRequest).toNot(beNil())
                }
                it("calls completion with error and no data or response") {
                    expect(responses.data).to(beNil())
                    expect(responses.urlResponse).to(beNil())
                    expect(responses.error).toNot(beNil())
                }
            }
            context("empty mobile key") {
                var responses: ServiceResponses
                var eventsPublished = false
                beforeEach {
                    testContext = TestContext(mobileKey: Constants.emptyMobileKey, useReport: false, includeMockEventDictionaries: true)
                    testContext.serviceMock.stubEventRequest(success: true) { (request, _, _) in
                        eventRequest = request
                    }
                    testContext.subject.publishEventDictionaries(testContext.mockEventDictionaries!) { (data, response, error) in
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
                var responses: ServiceResponses
                var eventsPublished = false
                let emptyEventDictionaryList: [[String: Any]] = []
                beforeEach {
                    testContext = TestContext(mobileKey: Constants.emptyMobileKey, useReport: false, includeMockEventDictionaries: true)
                    testContext.serviceMock.stubEventRequest(success: true) { (request, _, _) in
                        eventRequest = request
                    }
                    testContext.subject.publishEventDictionaries(emptyEventDictionaryList) { (data, response, error) in
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
