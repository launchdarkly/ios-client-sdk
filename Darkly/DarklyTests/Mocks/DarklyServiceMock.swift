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
@testable import LaunchDarkly

final class DarklyServiceMock: DarklyServiceProvider {
    struct FlagKeys {
        static let bool = "bool-flag"
        static let int = "int-flag"
        static let double = "double-flag"
        static let string = "string-flag"
        static let array = "array-flag"
        static let dictionary = "dictionary-flag"
        static let null = "null-flag"

        static var all: [LDFlagKey] { return [bool, int, double, string, array, dictionary, null] }
        static var allThatCanBeInequal: [LDFlagKey] { return [bool, int, double, string, array, dictionary] }
    }

    struct FlagValues {
        static let bool = true
        static let int = 7
        static let double = 3.14159
        static let string = "string value"
        static let array = [1, 2, 3]
        static let dictionary: [String: Any] = ["sub-flag-a": false, "sub-flag-b": 3, "sub-flag-c": 2.71828]
        static let null = NSNull()

        static var all: [Any] { return [bool, int, double, string, array, dictionary, null] }
        static var allThatCanBeInequal: [Any] { return [bool, int, double, string, array, dictionary] }

        static func alternate<T>(_ value: T) -> T {
            switch value {
            case let value as Bool: return !value as! T
            case let value as Int: return value + 1 as! T
            case let value as Double: return value + 1.0 as! T
            case let value as String: return value + "-" as! T
            case var value as [Any]:
                value.append(4)
                return value as! T  //Not sure why, but this crashes if you combine append the value into the return
            case var value as [String: Any]:
                value["new-flag"] = "new-value"
                return value as! T
            default: return value
            }
        }
    }

    struct Constants {
        static let streamData = "event: put\ndata:\(featureFlags(includeNullValue: false, includeVersions: true).dictionaryValue(exciseNil: false).jsonString!)".data(using: .utf8)!
        static let error = NSError(domain: NSURLErrorDomain, code: Int(CFNetworkErrors.cfurlErrorResourceUnavailable.rawValue), userInfo: nil)
        static let jsonErrorString = "Bad json data"
        static let errorData = jsonErrorString.data(using: .utf8)!

        static let schemeHttps = "https"
        static let httpVersion = "1.1"

        static let mockBaseUrl = URL(string: "https://dummy.base.com")!
        static let mockEventsUrl = URL(string: "https://dummy.events.com")!
        static let mockStreamUrl = URL(string: "https://dummy.stream.com")!

        static let requestPathStream = "/mping"

        static let stubNameFlag = "Flag Request Stub"
        static let stubNameStream = "Stream Connect Stub"
        static let stubNameEvent = "Event Report Stub"

        static let version = 2
        static func featureFlags(includeNullValue: Bool, includeVersions: Bool, alternateValuesForKeys: [LDFlagKey] = []) -> [LDFlagKey: FeatureFlag] {
            let version: Int? = includeVersions ? Constants.version : nil
            var featureFlags: [LDFlagKey: FeatureFlag] = [
                FlagKeys.bool: FeatureFlag(value: alternateValuesForKeys.contains(FlagKeys.bool) ? FlagValues.alternate(FlagValues.bool) : FlagValues.bool,
                                           version: version),
                FlagKeys.int: FeatureFlag(value: alternateValuesForKeys.contains(FlagKeys.int) ? FlagValues.alternate(FlagValues.int) : FlagValues.int,
                                          version: version),
                FlagKeys.double: FeatureFlag(value: alternateValuesForKeys.contains(FlagKeys.double) ? FlagValues.alternate(FlagValues.double) : FlagValues.double,
                                             version: version),
                FlagKeys.string: FeatureFlag(value: alternateValuesForKeys.contains(FlagKeys.string) ? FlagValues.alternate(FlagValues.string) : FlagValues.string,
                                             version: version),
                FlagKeys.array: FeatureFlag(value: alternateValuesForKeys.contains(FlagKeys.array) ? FlagValues.alternate(FlagValues.array) : FlagValues.array,
                                            version: version),
                FlagKeys.dictionary: FeatureFlag(value: alternateValuesForKeys.contains(FlagKeys.dictionary) ? FlagValues.alternate(FlagValues.dictionary) : FlagValues.dictionary,
                                                 version: version)
            ]
            if includeNullValue {
                featureFlags[DarklyServiceMock.FlagKeys.null] = FeatureFlag(value: DarklyServiceMock.FlagValues.null, version: version)
            }
            return featureFlags
        }
    }

    var config: LDConfig
    var user: LDUser

    var activationBlocks = [(testBlock: OHHTTPStubsTestBlock, callback: ((URLRequest, OHHTTPStubsDescriptor, OHHTTPStubsResponse) -> Void))]()

    init(config: LDConfig = LDConfig.stub, user: LDUser = LDUser.stub()) {
        self.config = config
        self.user = user
    }
    
    var stubbedFlagResponse: ServiceResponse?
    var getFeatureFlagsUseReportCalledValue = [Bool]()
    var getFeatureFlagsCallCount = 0
    func getFeatureFlags(useReport: Bool, completion: ServiceCompletionHandler?) {
        getFeatureFlagsCallCount += 1
        getFeatureFlagsUseReportCalledValue.append(useReport)
        completion?(stubbedFlagResponse ?? (nil, nil, nil))
    }
    
    var createdEventSource: DarklyStreamingProviderMock?
    var createEventSourceCallCount = 0
    var createEventSourceReceivedUseReport: Bool?
    func createEventSource(useReport: Bool) -> DarklyStreamingProvider {
        createEventSourceCallCount += 1
        createEventSourceReceivedUseReport = useReport
        let source = DarklyStreamingProviderMock()
        createdEventSource = source
        return source
    }
    
    var stubbedEventResponse: ServiceResponse?
    var publishEventDictionariesCallCount = 0
    var publishedEventDictionaries: [[String: Any]]?
    var publishedEventDictionaryKeys: [String]? { return publishedEventDictionaries?.flatMap { (eventDictionary) in eventDictionary[Event.CodingKeys.key.rawValue] as? String } }
    func publishEventDictionaries(_ eventDictionaries: [[String: Any]], completion: ServiceCompletionHandler?) {
        publishEventDictionariesCallCount += 1
        publishedEventDictionaries = eventDictionaries
        completion?(stubbedEventResponse ?? (nil, nil, nil))
    }
}

extension DarklyServiceMock {

    // MARK: Flag Request

    var flagHost: String? { return config.baseUrl.host }
    var flagRequestStubTest: OHHTTPStubsTestBlock { return isScheme(Constants.schemeHttps) && isHost(flagHost!) }
    var getFlagRequestStubTest: OHHTTPStubsTestBlock { return flagRequestStubTest && isMethodGET() }
    var reportFlagRequestStubTest: OHHTTPStubsTestBlock { return flagRequestStubTest && isMethodREPORT() }

    ///Use when testing requires the mock service to actually make a flag request
    func stubFlagRequest(statusCode: Int, useReport: Bool, onActivation activate: ((URLRequest, OHHTTPStubsDescriptor, OHHTTPStubsResponse) -> Void)? = nil) {
        let responseData = statusCode == HTTPURLResponse.StatusCodes.ok ? Constants.featureFlags(includeNullValue: false, includeVersions: true)
            .dictionaryValue(exciseNil: false).jsonData!
            : Data()
        let stubResponse: OHHTTPStubsResponseBlock = { (_) in OHHTTPStubsResponse(data: responseData, statusCode: Int32(statusCode), headers: nil)}
        stubRequest(passingTest: useReport ? reportFlagRequestStubTest : getFlagRequestStubTest,
                    stub: stubResponse,
                    name: flagStubName(statusCode: statusCode, useReport: useReport), onActivation: activate)
    }

    ///Use when testing requires the mock service to simulate a service response to the flag request callback
    func stubFlagResponse(statusCode: Int, badData: Bool = false, responseOnly: Bool = false, errorOnly: Bool = false) {
        let response = HTTPURLResponse(url: config.baseUrl, statusCode: statusCode, httpVersion: Constants.httpVersion, headerFields: nil)
        if statusCode == HTTPURLResponse.StatusCodes.ok {
            let flagData = try? JSONSerialization.data(withJSONObject: Constants.featureFlags(includeNullValue: false, includeVersions: true).dictionaryValue(exciseNil: false),
                                                       options: [])
            stubbedFlagResponse = (flagData, response, nil)
            if badData { stubbedFlagResponse = (Constants.errorData, response, nil) }
            return
        }

        if responseOnly {
            stubbedFlagResponse = (nil, response, nil)
        } else if errorOnly {
            stubbedFlagResponse = (nil, nil, Constants.error)
        } else {
            stubbedFlagResponse = (nil, response, Constants.error)
        }
    }

    func flagStubName(statusCode: Int, useReport: Bool) -> String {
        return "\(Constants.stubNameFlag) using method \(useReport ? URLRequest.HTTPMethods.report : URLRequest.HTTPMethods.get) with response status code \(statusCode)"
    }

    // MARK: Stream

    var streamHost: String? { return config.streamUrl.host }
    var getStreamRequestStubTest: OHHTTPStubsTestBlock { return isScheme(Constants.schemeHttps) && isHost(streamHost!) && isMethodGET() }
    var reportStreamRequestStubTest: OHHTTPStubsTestBlock { return isScheme(Constants.schemeHttps) && isHost(streamHost!) && isMethodREPORT() }

    ///Use when testing requires the mock service to actually make an event source connection request
    func stubStreamRequest(useReport: Bool, success: Bool, onActivation activate: ((URLRequest, OHHTTPStubsDescriptor, OHHTTPStubsResponse) -> Void)? = nil) {
        var stubResponse: OHHTTPStubsResponseBlock = { (_) in OHHTTPStubsResponse(error: Constants.error) }
        if success {
            stubResponse = { (_) in OHHTTPStubsResponse(data: Constants.streamData, statusCode: Int32(HTTPURLResponse.StatusCodes.ok), headers: nil) }
        }
        stubRequest(passingTest: useReport ? reportStreamRequestStubTest : getStreamRequestStubTest, stub: stubResponse, name: Constants.stubNameStream, onActivation: activate)
    }

    // MARK: Publish Event

    var eventHost: String? { return config.eventsUrl.host }
    var eventRequestStubTest: OHHTTPStubsTestBlock { return isScheme(Constants.schemeHttps) && isHost(eventHost!) && isMethodPOST() }

    ///Use when testing requires the mock service to actually make an event request
    func stubEventRequest(success: Bool, onActivation activate: ((URLRequest, OHHTTPStubsDescriptor, OHHTTPStubsResponse) -> Void)? = nil) {
        let stubResponse: OHHTTPStubsResponseBlock = success ? { (_) in OHHTTPStubsResponse(data: Data(), statusCode: Int32(HTTPURLResponse.StatusCodes.accepted), headers: nil) }
            : { (_) in OHHTTPStubsResponse(error: Constants.error) }
        stubRequest(passingTest: eventRequestStubTest, stub: stubResponse, name: Constants.stubNameEvent, onActivation: activate)
    }

    ///Use when testing requires the mock service to provide a service response to the event request callback
    func stubEventResponse(success: Bool, responseOnly: Bool = false, errorOnly: Bool = false) {
        if success {
            let response = HTTPURLResponse(url: config.eventsUrl, statusCode: HTTPURLResponse.StatusCodes.accepted, httpVersion: Constants.httpVersion, headerFields: nil)
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
    var errorEventHTTPURLResponse: HTTPURLResponse! { return HTTPURLResponse(url: config.eventsUrl,
                                                                             statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                                             httpVersion: Constants.httpVersion,
                                                                             headerFields: nil) }

    // MARK: Stub

    var anyRequestStubTest: OHHTTPStubsTestBlock { return {_ in return true } }

    private func stubRequest(passingTest test: @escaping OHHTTPStubsTestBlock,
                             stub: @escaping OHHTTPStubsResponseBlock,
                             name: String,
                             onActivation activation: ((URLRequest, OHHTTPStubsDescriptor, OHHTTPStubsResponse) -> Void)? = nil) {
        OHHTTPStubs.stubRequests(passingTest: test, withStubResponse: stub).name = name
        if let activation = activation { activationBlocks.append((test, activation)) }
        OHHTTPStubs.onStubActivation(onActivation)
    }

    private func onActivation(request: URLRequest, stubDescriptor: OHHTTPStubsDescriptor, stubResponse: OHHTTPStubsResponse) {
        for activationBlock in activationBlocks.reversed() {
            if !activationBlock.testBlock(request) { continue }
            activationBlock.callback(request, stubDescriptor, stubResponse)
            return
        }
    }
}

extension OHHTTPStubs {
    class func stub(named name: String) -> OHHTTPStubsDescriptor? {
        return (OHHTTPStubs.allStubs() as? [OHHTTPStubsDescriptor])?.filter { (stub) in stub.name == name }.first
    }
}

/**
 * Matcher testing that the `NSURLRequest` is using the **REPORT** `HTTPMethod`
 *
 * - Returns: a matcher (OHHTTPStubsTestBlock) that succeeds only if the request
 *            is using the REPORT method
 */
public func isMethodREPORT() -> OHHTTPStubsTestBlock {
    return { request in request.httpMethod == URLRequest.HTTPMethods.report }
}
