//
//  DarklyServiceMock.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 9/26/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
import OHHTTPStubs
@testable import Darkly

final class DarklyServiceMock: DarklyServiceProvider {

    struct FlagKeys {
        static let bool = "bool-flag"
        static let int = "int-flag"
        static let double = "double-flag"
        static let string = "string-flag"
        static let array = "array-flag"
        static let dictionary = "dictionary-flag"
    }

    struct FlagValues {
        static let bool = true
        static let int = 7
        static let double = 3.14159
        static let string = "string value"
        static let array = [1, 2, 3]
        static let dictionary: [String: Any] = ["sub-flag-a": false, "sub-flag-b": 3, "sub-flag-c": 2.71828]
    }

    struct Constants {
        static let jsonFlags: [String: Any] = [
            FlagKeys.bool: FlagValues.bool,
            FlagKeys.int: FlagValues.int,
            FlagKeys.double: FlagValues.double,
            FlagKeys.string: FlagValues.string,
            FlagKeys.array: FlagValues.array,
            FlagKeys.dictionary: FlagValues.dictionary
        ]
        static let streamData = "event: ping\ndata:\n".data(using: .utf8)!
        static let error = NSError(domain: NSURLErrorDomain, code: Int(CFNetworkErrors.cfurlErrorResourceUnavailable.rawValue), userInfo: nil)
        static let errorData = "Bad json data".data(using: .utf8)!

        static let schemeHttps = "https"
        static let httpVersion = "1.1"

        static let statusCodeOk: Int32 = 200
        static let statusCodeAccept: Int32 = 202
        static let statusCodeInternalServerError = 500

        static let mockBaseUrl = URL(string: "https://dummy.base.com")!
        static let mockEventsUrl = URL(string: "https://dummy.events.com")!
        static let mockStreamUrl = URL(string: "https://dummy.stream.com")!

        static let requestPathStream = "/mping"

        static let stubNameFlag = "Flag Stub"
        static let stubNameStream = "Stream Stub"
        static let stubNameEvent = "Event Stub"
    }

    var config: LDConfig
    var user: LDUser

    init(config: LDConfig = LDConfig.stub, user: LDUser = LDUser.stub()) {
        self.config = config
        self.user = user
    }
    
    var stubbedFlagResponse: ServiceResponse?
    var getFeatureFlagsCallCount = 0
    func getFeatureFlags(completion: ServiceCompletionHandler?) {
        getFeatureFlagsCallCount += 1
        completion?(stubbedFlagResponse ?? (nil, nil, nil))
    }
    
    var createdEventSource: DarklyStreamingProviderMock?
    func createEventSource() -> DarklyStreamingProvider {
        let source = DarklyStreamingProviderMock()
        createdEventSource = source
        return source
    }
    
    var stubbedEventResponse: ServiceResponse?
    var publishEventsCallCount = 0
    var publishedEvents: [LDEvent]?
    func publishEvents(_ events: [LDEvent], completion: ServiceCompletionHandler?) {
        publishEventsCallCount += 1
        publishedEvents = events
        completion?(stubbedEventResponse ?? (nil, nil, nil))
    }
}

extension DarklyServiceMock {

    // MARK: Flag Request

    var flagHost: String? { return config.baseUrl.host }
    var flagRequestStubTest: OHHTTPStubsTestBlock { return isScheme(Constants.schemeHttps) && isHost(flagHost!) && isMethodGET() }

    ///Use when testing requires the mock service to actually make a flag request
    func stubFlagRequest(success: Bool, onActivation activate: ((URLRequest, OHHTTPStubsDescriptor, OHHTTPStubsResponse) -> Void)? = nil) {
        let stubResponse: OHHTTPStubsResponseBlock = success ? { (_) in OHHTTPStubsResponse(jsonObject: Constants.jsonFlags, statusCode: Constants.statusCodeOk, headers: nil) }
            : { (_) in OHHTTPStubsResponse(error: Constants.error) }
        stubRequest(passingTest: flagRequestStubTest, stub: stubResponse, name: Constants.stubNameFlag, onActivation: activate)
    }

    ///Use when testing requires the mock service to provide a service response to the flag request callback
    func stubFlagResponse(success: Bool, badData: Bool = false, responseOnly: Bool = false, errorOnly: Bool = false) {
        if success {
            let flagData = try? JSONSerialization.data(withJSONObject: Constants.jsonFlags, options: [])
            let response = HTTPURLResponse(url: config.baseUrl, statusCode: Int(Constants.statusCodeOk), httpVersion: Constants.httpVersion, headerFields: nil)
            stubbedFlagResponse = (flagData, response, nil)
            if badData { stubbedFlagResponse = (Constants.errorData, response, nil) }
            return
        }

        if responseOnly {
            stubbedFlagResponse = (nil, errorFlagHTTPURLResponse, nil)
        } else if errorOnly {
            stubbedFlagResponse = (nil, nil, Constants.error)
        } else {
            stubbedFlagResponse = (nil, errorFlagHTTPURLResponse, Constants.error)
        }
    }
    var errorFlagHTTPURLResponse: HTTPURLResponse! { return HTTPURLResponse(url: config.baseUrl, statusCode: Constants.statusCodeInternalServerError, httpVersion: Constants.httpVersion, headerFields: nil) }

    // MARK: Stream

    var streamHost: String? { return config.streamUrl.host }
    var streamRequestStubTest: OHHTTPStubsTestBlock { return isScheme(Constants.schemeHttps) && isHost(streamHost!) && isMethodGET() }

    ///Use when testing requires the mock service to actually make an event source connection request
    func stubStreamRequest(success: Bool, onActivation activate: ((URLRequest, OHHTTPStubsDescriptor, OHHTTPStubsResponse) -> Void)? = nil) {
        let stubResponse: OHHTTPStubsResponseBlock = success ? { (_) in OHHTTPStubsResponse(data: Constants.streamData, statusCode: Constants.statusCodeOk, headers: nil) }
            : { (_) in OHHTTPStubsResponse(error: Constants.error) }
        stubRequest(passingTest: streamRequestStubTest, stub: stubResponse, name: Constants.stubNameStream, onActivation: activate)
    }

    // MARK: Publish Event

    var eventHost: String? { return config.eventsUrl.host }
    var eventRequestStubTest: OHHTTPStubsTestBlock { return isScheme(Constants.schemeHttps) && isHost(eventHost!) && isMethodPOST() }

    ///Use when testing requires the mock service to actually make an event request
    func stubEventRequest(success: Bool, onActivation activate: ((URLRequest, OHHTTPStubsDescriptor, OHHTTPStubsResponse) -> Void)? = nil) {
        let stubResponse: OHHTTPStubsResponseBlock = success ? { (_) in OHHTTPStubsResponse(data: Data(), statusCode: Constants.statusCodeAccept, headers: nil) }
            : { (_) in OHHTTPStubsResponse(error: Constants.error) }
        stubRequest(passingTest: eventRequestStubTest, stub: stubResponse, name: Constants.stubNameEvent, onActivation: activate)
    }

    ///Use when testing requires the mock service to provide a service response to the event request callback
    func stubEventResponse(success: Bool, responseOnly: Bool = false, errorOnly: Bool = false) {
        if success {
            let response = HTTPURLResponse(url: config.eventsUrl, statusCode: Int(Constants.statusCodeAccept), httpVersion: Constants.httpVersion, headerFields: nil)
            stubbedEventResponse = (nil, response, nil)
            return
        }

        if responseOnly {
            stubbedEventResponse = (nil, errorEventHTTPURLResponse, nil)
        } else if errorOnly {
            stubbedEventResponse = (nil, nil, Constants.error)
        } else {
            stubbedEventResponse = (nil, errorEventHTTPURLResponse, Constants.error)
        }
    }
    var errorEventHTTPURLResponse: HTTPURLResponse! { return HTTPURLResponse(url: config.eventsUrl, statusCode: Constants.statusCodeInternalServerError, httpVersion: Constants.httpVersion, headerFields: nil) }

    // MARK: Stub

    var anyRequestStubTest: OHHTTPStubsTestBlock { return {_ in return true } }

    private func stubRequest(passingTest test: @escaping OHHTTPStubsTestBlock, stub: @escaping OHHTTPStubsResponseBlock, name: String, onActivation activation: ((URLRequest, OHHTTPStubsDescriptor, OHHTTPStubsResponse) -> Void)? = nil) {
        OHHTTPStubs.stubRequests(passingTest: test, withStubResponse: stub).name = name
        OHHTTPStubs.onStubActivation(activation)
        expect(OHHTTPStubs.stub(named: name)).toNot(beNil())
    }
}

extension OHHTTPStubs {
    class func stub(named name: String) -> OHHTTPStubsDescriptor? {
        return (OHHTTPStubs.allStubs() as? [OHHTTPStubsDescriptor])?.filter { (stub) in stub.name == name }.first
    }
}
