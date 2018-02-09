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
        let config = LDConfig.stub
        let mockEventDictionaries: [[String: Any]]?
        var serviceMock: DarklyServiceMock!
        var subject: DarklyService!

        init(mobileKey: String, includeMockEventDictionaries: Bool = false) {
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
            var flagRequest: URLRequest?
            beforeEach {
                flagRequest = nil
                testContext = TestContext(mobileKey: Constants.mockMobileKey)
            }
            context("success") {
                var responses: ServiceResponses
                beforeEach {
                    waitUntil { done in
                        testContext.serviceMock.stubFlagRequest(success: true, useReport: false) { (request, _, _) in
                            flagRequest = request
                        }
                        testContext.subject.getFeatureFlags(completion: { (data, response, error) in
                            responses = (data, response, error)
                            done()
                        })
                    }
                }
                it("makes a valid request") {
                    expect(flagRequest).toNot(beNil())
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
                        testContext.serviceMock.stubFlagRequest(success: false, useReport: false) { (request, _, _) in
                            flagRequest = request
                        }
                        testContext.subject.getFeatureFlags(completion: { (data, response, error) in
                            responses = (data, response, error)
                            done()
                        })
                    }
                }
                it("makes a valid request") {
                    expect(flagRequest).toNot(beNil())
                }
                it("calls completion with error and no data or response") {
                    expect(responses.data).to(beNil())
                    expect(responses.urlResponse).to(beNil())
                    expect(responses.error).toNot(beNil())
                }
            }
            context("empty mobile key") {
                var responses: ServiceResponses
                var flagsRequested = false
                beforeEach {
                    testContext = TestContext(mobileKey: Constants.emptyMobileKey)
                    testContext.serviceMock.stubFlagRequest(success: true, useReport: false) { (request, _, _) in
                        flagRequest = request
                    }
                    testContext.subject.getFeatureFlags(completion: { (data, response, error) in
                        responses = (data, response, error)
                        flagsRequested = true
                    })
                }
                it("does not make a request") {
                    expect(flagRequest).to(beNil())
                    expect(flagsRequested) == false
                    expect(responses).to(beNil())
                }
            }
        }
    }

    private func createEventSourceSpec() {
        var testContext: TestContext!

        describe("createEventSource") {
            var streamRequest: URLRequest?
            var eventSource: DarklyStreamingProvider!
            beforeEach {
                testContext = TestContext(mobileKey: Constants.mockMobileKey)
                // The LDEventSource constructor waits ~1s and then triggers a request to open the streaming connection. Adding the timeout gives it time to make the request.
                waitUntil(timeout: 3) { done in
                    testContext.serviceMock.stubStreamRequest(success: true) { (request, _, _) in
                        streamRequest = request
                        done()
                    }

                    eventSource = testContext.subject.createEventSource()
                }
            }
            it("creates an event source and makes valid request") {
                expect(eventSource).toNot(beNil())
                expect(streamRequest).toNot(beNil())
            }
            afterEach {
                eventSource.close()
            }
        }
    }

    private func publishEventDictionariesSpec() {
        var testContext: TestContext!

        describe("publishEventDictionaries") {
            var eventRequest: URLRequest?

            beforeEach {
                eventRequest = nil
                testContext = TestContext(mobileKey: Constants.mockMobileKey, includeMockEventDictionaries: true)
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
                    testContext = TestContext(mobileKey: Constants.emptyMobileKey, includeMockEventDictionaries: true)
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
                    testContext = TestContext(mobileKey: Constants.emptyMobileKey, includeMockEventDictionaries: true)
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
