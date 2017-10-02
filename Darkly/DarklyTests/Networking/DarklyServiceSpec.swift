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
    }
    
    let mockMobileKey = "mockMobileKey"
    let user = LDUser()

    var config: LDConfig!
    var subject: DarklyService!
    
    // swiftlint:disable:next function_body_length
    override func spec() {
        beforeSuite {
            self.config = LDConfig.stub
        }
        beforeEach {
            self.subject = DarklyService(mobileKey: self.mockMobileKey, config: self.config)
        }
        
        describe("getFeatureFlags") {
            var flagRequest: URLRequest?
            var serviceMock: DarklyServiceMock!
            beforeEach {
                serviceMock = DarklyServiceMock(config: self.config)
                waitUntil { done in
                    serviceMock.stubFlagRequest(success: true) { (request, _, _) in
                        flagRequest = request
                        done()
                    }
                    self.subject.getFeatureFlags(user: self.user, completion: nil)
                }
            }
            it("makes valid request") {
                self.verifyFlagRequest(flagRequest, serviceMock: serviceMock)
            }
            context("success") {
                var responses: ServiceResponses
                beforeEach {
                    waitUntil { done in
                        serviceMock.stubFlagRequest(success: true)
                        self.subject.getFeatureFlags(user: self.user) { (data, response, error) in
                            responses = (data, response, error)
                            done()
                        }
                    }
                }
                it("calls completion with data, response, and no error") {
                    self.verifyCompletion(hasData: true, hasResponse: true, hasError: false, serviceResponses: responses)
                }
            }
            context("failure") {
                var responses: ServiceResponses
                beforeEach {
                    waitUntil { done in
                        serviceMock.stubFlagRequest(success: false)
                        self.subject.getFeatureFlags(user: self.user) { (data, response, error) in
                            responses = (data, response, error)
                            done()
                        }
                    }
                }
                it("calls completion with error and no data or response") {
                    self.verifyCompletion(hasData: false, hasResponse: false, hasError: true, serviceResponses: responses)
                }
            }
            context("empty mobile key") {
                var responses: ServiceResponses = (nil, nil, nil)
                var flagsRequested = false
                beforeEach {
                    self.subject = DarklyService(mobileKey: Constants.emptyMobileKey, config: self.config)
                    serviceMock.stubFlagRequest(success: true)
                    self.subject.getFeatureFlags(user: self.user) { (data, response, error) in
                        responses = (data, response, error)
                        flagsRequested = true
                    }
                }
                it("does not make a request") {
                    expect(flagsRequested) == false
                    self.verifyCompletion(hasData: false, hasResponse: false, hasError: false, serviceResponses: responses)
                }
            }
        }

        describe("createEventSource") {
            var streamRequest: URLRequest?
            var serviceMock: DarklyServiceMock!
            beforeEach {
                serviceMock = DarklyServiceMock(config: self.config)
                // The LDEventSource constructor waits ~1s and then triggers a request to open the streaming connection. Adding the timeout gives it time to make the request.
                waitUntil(timeout: 3) { done in
                    serviceMock.stubStreamRequest(success: true) { (request, _, _) in
                        streamRequest = request
                        done()
                    }
                    _ = self.subject.createEventSource()
                }
            }
            it("creates an event source and makes valid request") {
                self.verifyStreamRequest(streamRequest, serviceMock: serviceMock)
            }
        }

        describe("publishEvents") {
            var eventRequest: URLRequest?
            let mockEvents = LDarklyEvent.stubEvents(Constants.eventCount, user: self.user)
            var serviceMock: DarklyServiceMock!
            beforeEach {
                serviceMock = DarklyServiceMock(config: self.config)
                waitUntil { done in
                    serviceMock.stubEventRequest(success: true) { (request, _, _) in
                        eventRequest = request
                        done()
                    }
                    self.subject.publishEvents(mockEvents, completion: nil)
                }
            }
            it("makes valid request") {
                self.verifyEventRequest(eventRequest, serviceMock: serviceMock)
            }
            context("success") {
                var responses: ServiceResponses
                beforeEach {
                    waitUntil { done in
                        serviceMock.stubEventRequest(success: true)
                        self.subject.publishEvents(mockEvents) { (data, response, error) in
                            responses = (data, response, error)
                            done()
                        }
                    }
                }
                it("calls completion with data, response, and no error") {
                    self.verifyCompletion(hasData: true, hasResponse: true, hasError: false, serviceResponses: responses)
                }
            }
            context("failure") {
                var responses: ServiceResponses
                beforeEach {
                    waitUntil { done in
                        serviceMock.stubEventRequest(success: false)
                        self.subject.publishEvents(mockEvents) { (data, response, error) in
                            responses = (data, response, error)
                            done()
                        }
                    }
                }
                it("calls completion with error and no data or response") {
                    self.verifyCompletion(hasData: false, hasResponse: false, hasError: true, serviceResponses: responses)
                }
            }
            context("empty mobile key") {
                var responses: ServiceResponses = (nil, nil, nil)
                var eventsPublished = false
                beforeEach {
                    self.subject = DarklyService(mobileKey: Constants.emptyMobileKey, config: self.config)
                    serviceMock.stubEventRequest(success: true)
                    self.subject.publishEvents(mockEvents) { (data, response, error) in
                        responses = (data, response, error)
                        eventsPublished = true
                    }
                }
                it("does not make a request") {
                    expect(eventsPublished) == false
                    self.verifyCompletion(hasData: false, hasResponse: false, hasError: false, serviceResponses: responses)
                }
            }
            context("empty event list") {
                var responses: ServiceResponses = (nil, nil, nil)
                var eventsPublished = false
                let emptyEventList: [LDarklyEvent] = []
                beforeEach {
                    self.subject = DarklyService(mobileKey: Constants.emptyMobileKey, config: self.config)
                    serviceMock.stubEventRequest(success: true)
                    self.subject.publishEvents(emptyEventList) { (data, response, error) in
                        responses = (data, response, error)
                        eventsPublished = true
                    }
                }
                it("does not make a request") {
                    expect(eventsPublished) == false
                    self.verifyCompletion(hasData: false, hasResponse: false, hasError: false, serviceResponses: responses)
                }
            }
        }
        
        afterEach {
            OHHTTPStubs.removeAllStubs()
        }
    }
    
    // MARK: Feature Flags
    
    private func verifyFlagRequest(_ flagRequest: URLRequest?, serviceMock: DarklyServiceMock) {
        expect(flagRequest?.url?.host) == serviceMock.flagHost
        expect(flagRequest?.url?.path) == "/\(DarklyService.Constants.flagRequestPath)/\(user.base64UrlEncoded)"
        verifyHeaders([HTTPHeaders.Constants.authorization, HTTPHeaders.Constants.userAgent], headers: flagRequest?.allHTTPHeaderFields, httpHeaders: subject.httpHeaders)
    }
    
    // MARK: Streaming
    
    private func verifyStreamRequest(_ streamRequest: URLRequest?, serviceMock: DarklyServiceMock) {
        expect(streamRequest?.url?.host) == serviceMock.streamHost
        expect(streamRequest?.url?.path) == "/\(DarklyService.Constants.streamRequestPath)"
        verifyHeaders([HTTPHeaders.Constants.authorization, HTTPHeaders.Constants.userAgent], headers: streamRequest?.allHTTPHeaderFields, httpHeaders: subject.httpHeaders)
    }
    
    // MARK: Publish Events
    
    private func verifyEventRequest(_ eventRequest: URLRequest?, serviceMock: DarklyServiceMock) {
        expect(eventRequest?.url?.host) == serviceMock.eventHost
        expect(eventRequest?.url?.path) == "/\(DarklyService.Constants.eventRequestPath)"
        verifyHeaders([HTTPHeaders.Constants.authorization, HTTPHeaders.Constants.userAgent, HTTPHeaders.Constants.contentType, HTTPHeaders.Constants.accept], headers: eventRequest?.allHTTPHeaderFields, httpHeaders: subject.httpHeaders)
    }
    
    // MARK: Headers
    private func verifyHeaders(_ keys: [String], headers: [String: String]?, httpHeaders: HTTPHeaders) {
        expect(headers).toNot(beNil())
        guard let headers = headers else { return }
        for key in keys {
            switch key {
            case HTTPHeaders.Constants.authorization: expect(headers[key]) == httpHeaders.authKey
            case HTTPHeaders.Constants.userAgent: expect(headers[key]) == httpHeaders.userAgent
            case HTTPHeaders.Constants.contentType, HTTPHeaders.Constants.accept: expect(headers[key]) == HTTPHeaders.Constants.applicationJson
            default: expect(key) == ""
            }
        }
    }
    
    // MARK: Completion
    
    private func verifyCompletion(hasData: Bool, hasResponse: Bool, hasError: Bool, serviceResponses: ServiceResponses) {
        hasData ? expect(serviceResponses.data).toNot(beNil()) : expect(serviceResponses.data).to(beNil())
        hasResponse ? expect(serviceResponses.urlResponse).toNot(beNil()) : expect(serviceResponses.urlResponse).to(beNil())
        hasError ? expect(serviceResponses.error).toNot(beNil()) : expect(serviceResponses.error).to(beNil())
    }
    
}
