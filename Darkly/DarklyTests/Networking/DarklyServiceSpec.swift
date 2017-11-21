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
    let user = LDUser.stub()

    var config: LDConfig!
    var subject: DarklyService!
    
    // swiftlint:disable:next function_body_length
    override func spec() {
        beforeEach {
            self.config = LDConfig.stub
            self.subject = DarklyService(mobileKey: self.mockMobileKey, config: self.config, user: self.user)
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
                    self.subject.getFeatureFlags(completion: nil)
                }
            }
           it("makes valid request") {
                expect({ self.verifyFlagRequest(flagRequest, serviceMock: serviceMock) }).to(succeed())
            }
            context("success") {
                var responses: ServiceResponses
                beforeEach {
                    waitUntil { done in
                        serviceMock.stubFlagRequest(success: true)
                        self.subject.getFeatureFlags(completion: { (data, response, error) in
                            responses = (data, response, error)
                            done()
                        })
                    }
                }
                it("calls completion with data, response, and no error") {
                    expect({ self.verifyCompletion(hasData: true, hasResponse: true, hasError: false, serviceResponses: responses) }).to(succeed())
                }
            }
            context("failure") {
                var responses: ServiceResponses
                beforeEach {
                    waitUntil { done in
                        serviceMock.stubFlagRequest(success: false)
                        self.subject.getFeatureFlags(completion: { (data, response, error) in
                            responses = (data, response, error)
                            done()
                        })
                    }
                }
                it("calls completion with error and no data or response") {
                    expect({ self.verifyCompletion(hasData: false, hasResponse: false, hasError: true, serviceResponses: responses) }).to(succeed())
                }
            }
            context("empty mobile key") {
                var responses: ServiceResponses = (nil, nil, nil)
                var flagsRequested = false
                beforeEach {
                    self.subject = DarklyService(mobileKey: Constants.emptyMobileKey, config: self.config, user: self.user)
                    serviceMock.stubFlagRequest(success: true)
                    self.subject.getFeatureFlags(completion: { (data, response, error) in
                        responses = (data, response, error)
                        flagsRequested = true
                    })
                }
                it("does not make a request") {
                    expect(flagsRequested) == false
                    expect({ self.verifyCompletion(hasData: false, hasResponse: false, hasError: false, serviceResponses: responses) }).to(succeed())
                }
            }
        }

        describe("createEventSource") {
            var streamRequest: URLRequest?
            var serviceMock: DarklyServiceMock!
            var eventSource: DarklyStreamingProvider!
            beforeEach {
                serviceMock = DarklyServiceMock(config: self.config)
                // The LDEventSource constructor waits ~1s and then triggers a request to open the streaming connection. Adding the timeout gives it time to make the request.
                waitUntil(timeout: 3) { done in
                    serviceMock.stubStreamRequest(success: true) { (request, _, _) in
                        streamRequest = request
                        done()
                    }

                    eventSource = self.subject.createEventSource()
                }
            }
            it("creates an event source and makes valid request") {
                expect({ self.verifyStreamRequest(streamRequest, serviceMock: serviceMock) }).to(succeed())
            }
            afterEach {
                eventSource.close()
            }
        }

        describe("publishEvents") {
            var eventRequest: URLRequest?
            let mockEvents = LDEvent.stubEvents(Constants.eventCount, user: self.user)
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
                expect({ self.verifyEventRequest(eventRequest, serviceMock: serviceMock) }).to(succeed())
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
                    expect({ self.verifyCompletion(hasData: true, hasResponse: true, hasError: false, serviceResponses: responses) }).to(succeed())
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
                    expect({ self.verifyCompletion(hasData: false, hasResponse: false, hasError: true, serviceResponses: responses) }).to(succeed())
                }
            }
            context("empty mobile key") {
                var responses: ServiceResponses = (nil, nil, nil)
                var eventsPublished = false
                beforeEach {
                    self.subject = DarklyService(mobileKey: Constants.emptyMobileKey, config: self.config, user: self.user)
                    serviceMock.stubEventRequest(success: true)
                    self.subject.publishEvents(mockEvents) { (data, response, error) in
                        responses = (data, response, error)
                        eventsPublished = true
                    }
                }
                it("does not make a request") {
                    expect(eventsPublished) == false
                    expect({ self.verifyCompletion(hasData: false, hasResponse: false, hasError: false, serviceResponses: responses) }).to(succeed())
                }
            }
            context("empty event list") {
                var responses: ServiceResponses = (nil, nil, nil)
                var eventsPublished = false
                let emptyEventList: [Darkly.LDEvent] = []
                beforeEach {
                    self.subject = DarklyService(mobileKey: Constants.emptyMobileKey, config: self.config, user: self.user)
                    serviceMock.stubEventRequest(success: true)
                    self.subject.publishEvents(emptyEventList) { (data, response, error) in
                        responses = (data, response, error)
                        eventsPublished = true
                    }
                }
                it("does not make a request") {
                    expect(eventsPublished) == false
                    expect({ self.verifyCompletion(hasData: false, hasResponse: false, hasError: false, serviceResponses: responses) }).to(succeed())
                }
            }
        }
        
        afterEach {
            OHHTTPStubs.removeAllStubs()
        }
    }
    
    // MARK: Feature Flags
    
    private func verifyFlagRequest(_ flagRequest: URLRequest?, serviceMock: DarklyServiceMock) -> ToSucceedResult {
        var messages = [String]()

        if let requestHost = flagRequest?.url?.host, requestHost != serviceMock.flagHost { messages.append("host is \(requestHost)") }
        guard let encodedUser = user.jsonDictionaryWithoutConfig.base64UrlEncodedString, !encodedUser.isEmpty
        else {
            messages.append("base 64 URL encoded user is nil or empty")
            return .failed(reason: messages.joined(separator: ", "))
        }
        if let requestPath = flagRequest?.url?.path, requestPath !=  "/\(DarklyService.Constants.flagRequestPath)/\(encodedUser)" { messages.append("path is \(requestPath)") }
        messages.append(contentsOf: verifyHeaders([HTTPHeaders.Constants.authorization, HTTPHeaders.Constants.userAgent], headers: flagRequest?.allHTTPHeaderFields, httpHeaders: subject.httpHeaders))

        return messages.isEmpty ? .succeeded : .failed(reason: messages.joined(separator: ", "))
    }
    
    // MARK: Streaming
    
    private func verifyStreamRequest(_ streamRequest: URLRequest?, serviceMock: DarklyServiceMock) -> ToSucceedResult {
        var messages = [String]()

        if let requestHost = streamRequest?.url?.host, requestHost != serviceMock.streamHost { messages.append("host is \(requestHost)") }
        if let requestPath = streamRequest?.url?.path, requestPath !=  "/\(DarklyService.Constants.streamRequestPath)" { messages.append("path is \(requestPath)") }
        messages.append(contentsOf: verifyHeaders([HTTPHeaders.Constants.authorization, HTTPHeaders.Constants.userAgent], headers: streamRequest?.allHTTPHeaderFields, httpHeaders: subject.httpHeaders))

        return messages.isEmpty ? .succeeded : .failed(reason: messages.joined(separator: ", "))
    }
    
    // MARK: Publish Events
    
    private func verifyEventRequest(_ eventRequest: URLRequest?, serviceMock: DarklyServiceMock) -> ToSucceedResult {
        var messages = [String]()

        guard let eventRequest = eventRequest
        else {
            messages.append("eventRequest is missing")
            return .failed(reason: messages.joined(separator: ", "))
        }

        if let requestHost = eventRequest.url?.host, requestHost != serviceMock.eventHost { messages.append("host is \(requestHost)") }
        if let requestPath = eventRequest.url?.path, requestPath !=  "/\(DarklyService.Constants.eventRequestPath)" { messages.append("path is \(requestPath)") }
        messages.append(contentsOf: verifyHeaders([HTTPHeaders.Constants.authorization, HTTPHeaders.Constants.userAgent, HTTPHeaders.Constants.contentType, HTTPHeaders.Constants.accept],
                                                  headers: eventRequest.allHTTPHeaderFields, httpHeaders: subject.httpHeaders))

        return messages.isEmpty ? .succeeded : .failed(reason: messages.joined(separator: ", "))
    }
    
    // MARK: Headers
    private func verifyHeaders(_ keys: [String], headers: [String: String]?, httpHeaders: HTTPHeaders) -> [String] {
        var messages = [String]()

        guard let headers = headers
        else {
            messages.append("headers is nil")
            return messages
        }

        for key in keys {
            if let header = headers[key] {
                switch key {
                case HTTPHeaders.Constants.authorization: if header != httpHeaders.authKey { messages.append("\(key) equals \(header)") }
                case HTTPHeaders.Constants.userAgent: if header != httpHeaders.userAgent { messages.append("\(key) equals \(header)") }
                case HTTPHeaders.Constants.contentType, HTTPHeaders.Constants.accept: if header != HTTPHeaders.Constants.applicationJson { messages.append("\(key) equals \(header)") }
                default: messages.append("unexpected header \(key)")
                }
            } else {
                messages.append("\(key) is missing")
            }
        }

        return messages
    }
    
    // MARK: Completion
    
    private func verifyCompletion(hasData: Bool, hasResponse: Bool, hasError: Bool, serviceResponses: ServiceResponses) -> ToSucceedResult {
        var messages = [String]()

        if hasData {
            if serviceResponses.data == nil { messages.append("data is missing") }
        } else {
            if serviceResponses.data != nil { messages.append("data is present") }
        }
        if hasResponse {
            if serviceResponses.urlResponse == nil { messages.append("urlResponse is missing") }
        } else {
            if serviceResponses.urlResponse != nil { messages.append("urlResponse is present") }
        }
        hasError ? expect(serviceResponses.error).toNot(beNil()) : expect(serviceResponses.error).to(beNil())
        if hasError {
            if serviceResponses.error == nil { messages.append("error is missing") }
        } else {
            if serviceResponses.error != nil { messages.append("error is present") }
        }

        return messages.isEmpty ? .succeeded : .failed(reason: messages.joined(separator: ", "))

    }
    
}
