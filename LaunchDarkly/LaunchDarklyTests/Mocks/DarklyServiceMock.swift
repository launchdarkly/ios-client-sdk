//
//  DarklyServiceMock.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
import OHHTTPStubs
import OHHTTPStubsSwift
import LDSwiftEventSource
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
        static let unknown = "unknown-flag"

        static var knownFlags: [LDFlagKey] {        //known means the SDK has the feature flag value
            [bool, int, double, string, array, dictionary, null]
        }
        static var flagsWithAnAlternateValue: [LDFlagKey] {
            [bool, int, double, string, array, dictionary]
        }
    }

    struct FlagValues {
        static let bool = true
        static let int = 7
        static let double = 3.14159
        static let string = "string value"
        static let array = [1, 2, 3]
        static let dictionary: [String: Any] = ["sub-flag-a": false, "sub-flag-b": 3, "sub-flag-c": 2.71828]
        static let null = NSNull()

        static var knownFlags: [Any] {
            [bool, int, double, string, array, dictionary, null]
        }

        static func value(from flagKey: LDFlagKey) -> Any? {
            switch flagKey {
            case FlagKeys.bool: return FlagValues.bool
            case FlagKeys.int: return FlagValues.int
            case FlagKeys.double: return FlagValues.double
            case FlagKeys.string: return FlagValues.string
            case FlagKeys.array: return FlagValues.array
            case FlagKeys.dictionary: return FlagValues.dictionary
            case FlagKeys.null: return FlagValues.null
            default: return nil
            }
        }

        static func alternateValue(from flagKey: LDFlagKey) -> Any? {
            alternate(value(from: flagKey))
        }

        static func alternate<T>(_ value: T) -> T {
            switch value {
            case let value as Bool: return !value as! T
            case let value as Int: return value + 1 as! T
            case let value as Double: return value + 1.0 as! T
            case let value as String: return value + "-alternate" as! T
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
        static var streamData: Data {
            let featureFlags = stubFeatureFlags(includeNullValue: false)
            let featureFlagDictionaries = featureFlags.dictionaryValue
            let eventStreamString = "event: put\ndata:\(featureFlagDictionaries.jsonString!)"

            return eventStreamString.data(using: .utf8)!
        }
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
        static let stubNameDiagnostic = "Diagnostic Report Stub"

        static let variation = 2
        static let version = 4
        static let flagVersion = 3
        static let trackEvents = true
        static let debugEventsUntilDate = Date().addingTimeInterval(30.0)
        static let reason = Optional(["kind": "OFF"])
        
        static func stubFeatureFlags(includeNullValue: Bool = true,
                                     includeVariations: Bool = true,
                                     includeVersions: Bool = true,
                                     includeFlagVersions: Bool = true,
                                     alternateVariationNumber: Bool = true,
                                     bumpFlagVersions: Bool = false,
                                     alternateValuesForKeys alternateValueKeys: [LDFlagKey] = [],
                                     trackEvents: Bool? = true,
                                     debugEventsUntilDate: Date? = Date().addingTimeInterval(30.0)) -> [LDFlagKey: FeatureFlag] {

            let flagKeys = includeNullValue ? FlagKeys.knownFlags : FlagKeys.flagsWithAnAlternateValue
            let featureFlagTuples = flagKeys.map { flagKey in
                return (flagKey, stubFeatureFlag(for: flagKey,
                                                 includeVariation: includeVariations,
                                                 includeVersion: includeVersions,
                                                 includeFlagVersion: includeFlagVersions,
                                                 useAlternateValue: useAlternateValue(for: flagKey, alternateValueKeys: alternateValueKeys),
                                                 useAlternateVersion: bumpFlagVersions && useAlternateValue(for: flagKey, alternateValueKeys: alternateValueKeys),
                                                 useAlternateFlagVersion: bumpFlagVersions && useAlternateValue(for: flagKey, alternateValueKeys: alternateValueKeys),
                                                 useAlternateVariationNumber: alternateVariationNumber,
                                                 trackEvents: trackEvents,
                                                 debugEventsUntilDate: debugEventsUntilDate))
            }

            return Dictionary(uniqueKeysWithValues: featureFlagTuples)
        }

        private static func useAlternateValue(for flagKey: LDFlagKey, alternateValueKeys: [LDFlagKey]) -> Bool {
            alternateValueKeys.contains(flagKey)
        }

        private static func value(for flagKey: LDFlagKey, alternateValueKeys: [LDFlagKey]) -> Any? {
            value(for: flagKey, useAlternateValue: useAlternateValue(for: flagKey, alternateValueKeys: alternateValueKeys))
        }

        private static func value(for flagKey: LDFlagKey, useAlternateValue: Bool) -> Any? {
            useAlternateValue ? FlagValues.alternateValue(from: flagKey) : FlagValues.value(from: flagKey)
        }

        private static func variation(for flagKey: LDFlagKey, includeVariation: Bool, alternateValueKeys: [LDFlagKey]) -> Int? {
            variation(for: flagKey, includeVariation: includeVariation, useAlternateValue: useAlternateValue(for: flagKey, alternateValueKeys: alternateValueKeys))
        }

        private static func variation(for flagKey: LDFlagKey, includeVariation: Bool, useAlternateValue: Bool) -> Int? {
            guard includeVariation
            else { return nil }
            return useAlternateValue ? variation + 1 : variation
        }

        private static func variation(for flagKey: LDFlagKey, includeVariation: Bool) -> Int? {
            guard includeVariation
            else { return nil }
            return variation
        }

        private static func version(for flagKey: LDFlagKey, includeVersion: Bool, alternateValueKeys: [LDFlagKey]) -> Int? {
            version(for: flagKey, includeVersion: includeVersion, useAlternateVersion: useAlternateValue(for: flagKey, alternateValueKeys: alternateValueKeys))
        }
        private static func version(for flagKey: LDFlagKey, includeVersion: Bool, useAlternateVersion: Bool) -> Int? {
            guard includeVersion
            else { return nil }
            return useAlternateVersion ? version + 1 : version
        }

        private static func flagVersion(for flagKey: LDFlagKey, includeFlagVersion: Bool, alternateValueKeys: [LDFlagKey]) -> Int? {
            flagVersion(for: flagKey, includeFlagVersion: includeFlagVersion, useAlternateFlagVersion: useAlternateValue(for: flagKey, alternateValueKeys: alternateValueKeys))
        }
        private static func flagVersion(for flagKey: LDFlagKey, includeFlagVersion: Bool, useAlternateFlagVersion: Bool) -> Int? {
            guard includeFlagVersion
            else { return nil }
            return useAlternateFlagVersion ? flagVersion + 1 : flagVersion
        }
        private static func reason(includeEvaluationReason: Bool) -> [String: Any]? {
            includeEvaluationReason ? reason : nil
        }

        static func stubFeatureFlag(for flagKey: LDFlagKey,
                                    includeVariation: Bool = true,
                                    includeVersion: Bool = true,
                                    includeFlagVersion: Bool = true,
                                    useAlternateValue: Bool = false,
                                    useAlternateVersion: Bool = false,
                                    useAlternateFlagVersion: Bool = false,
                                    useAlternateVariationNumber: Bool = true,
                                    trackEvents: Bool? = true,
                                    debugEventsUntilDate: Date? = Date().addingTimeInterval(30.0),
                                    includeEvaluationReason: Bool = false,
                                    includeTrackReason: Bool = false) -> FeatureFlag {
            FeatureFlag(flagKey: flagKey,
                        value: value(for: flagKey, useAlternateValue: useAlternateValue),
                         variation: useAlternateVariationNumber ? variation(for: flagKey, includeVariation: includeVariation, useAlternateValue: useAlternateValue) : variation(for: flagKey, includeVariation: includeVariation),
                         version: version(for: flagKey, includeVersion: includeVersion, useAlternateVersion: useAlternateValue || useAlternateVersion),
                         flagVersion: flagVersion(for: flagKey, includeFlagVersion: includeFlagVersion, useAlternateFlagVersion: useAlternateValue || useAlternateFlagVersion),
                         trackEvents: trackEvents,
                         debugEventsUntilDate: debugEventsUntilDate,
                         reason: reason(includeEvaluationReason: includeEvaluationReason),
                         trackReason: includeTrackReason)
        }
    }

    var config: LDConfig
    var user: LDUser
    var diagnosticCache: DiagnosticCaching? = nil

    var activationBlocks = [(testBlock: HTTPStubsTestBlock, callback: ((URLRequest, HTTPStubsDescriptor, HTTPStubsResponse) -> Void))]()

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

    var clearFlagResponseCacheCallCount = 0
    func clearFlagResponseCache() {
        clearFlagResponseCacheCallCount += 1
    }
    
    var createdEventSource: DarklyStreamingProviderMock?
    var createEventSourceCallCount = 0
    var createEventSourceReceivedUseReport: Bool?
    var createEventSourceReceivedHandler: EventHandler?
    var createEventSourceReceivedConnectionErrorHandler: ConnectionErrorHandler?
    func createEventSource(useReport: Bool, handler: EventHandler, errorHandler: ConnectionErrorHandler?) -> DarklyStreamingProvider {
        createEventSourceCallCount += 1
        createEventSourceReceivedUseReport = useReport
        createEventSourceReceivedHandler = handler
        createEventSourceReceivedConnectionErrorHandler = errorHandler
        let mock = DarklyStreamingProviderMock()
        createdEventSource = mock
        return mock
    }
    
    var stubbedEventResponse: ServiceResponse?
    var publishEventDictionariesCallCount = 0
    var publishedEventDictionaries: [[String: Any]]?
    var publishedEventDictionaryKeys: [String]? {
        publishedEventDictionaries?.compactMap { $0.eventKey }
    }
    var publishedEventDictionaryKinds: [Event.Kind]? {
        publishedEventDictionaries?.compactMap { $0.eventKind }
    }
    func publishEventDictionaries(_ eventDictionaries: [[String: Any]], _ payloadId: String, completion: ServiceCompletionHandler?) {
        publishEventDictionariesCallCount += 1
        publishedEventDictionaries = eventDictionaries
        completion?(stubbedEventResponse ?? (nil, nil, nil))
    }

    var stubbedDiagnosticResponse: ServiceResponse?
    var publishDiagnosticCallCount = 0
    var publishedDiagnostic: DiagnosticEvent?
    func publishDiagnostic<T: DiagnosticEvent & Encodable>(diagnosticEvent: T, completion: ServiceCompletionHandler?) {
        publishDiagnosticCallCount += 1
        publishedDiagnostic = diagnosticEvent
        completion?(stubbedDiagnosticResponse ?? (nil, nil, nil))
    }
}

extension DarklyServiceMock {

    // MARK: Flag Request

    var flagHost: String? {
        config.baseUrl.host
    }
    var flagRequestStubTest: HTTPStubsTestBlock {
        isScheme(Constants.schemeHttps) && isHost(flagHost!)
    }
    var getFlagRequestStubTest: HTTPStubsTestBlock {
        flagRequestStubTest && isMethodGET()
    }
    var reportFlagRequestStubTest: HTTPStubsTestBlock {
        flagRequestStubTest && isMethodREPORT()
    }

    ///Use when testing requires the mock service to actually make a flag request
    func stubFlagRequest(statusCode: Int,
                         featureFlags: [LDFlagKey: FeatureFlag]? = nil,
                         useReport: Bool,
                         flagResponseEtag: String? = nil,
                         onActivation activate: ((URLRequest, HTTPStubsDescriptor, HTTPStubsResponse) -> Void)? = nil) {

        let stubbedFeatureFlags = featureFlags ?? Constants.stubFeatureFlags()
        let responseData = statusCode == HTTPURLResponse.StatusCodes.ok ? stubbedFeatureFlags.dictionaryValue.jsonData! : Data()
        let stubResponse: HTTPStubsResponseBlock = { _ in
            var headers = [String: String]()
            if let flagResponseEtag = flagResponseEtag {
                headers = [HTTPURLResponse.HeaderKeys.etag: flagResponseEtag,
                           HTTPURLResponse.HeaderKeys.cacheControl: HTTPURLResponse.HeaderValues.maxAge]
            }
            return HTTPStubsResponse(data: responseData, statusCode: Int32(statusCode), headers: headers)
        }
        stubRequest(passingTest: useReport ? reportFlagRequestStubTest : getFlagRequestStubTest,
                    stub: stubResponse,
                    name: flagStubName(statusCode: statusCode, useReport: useReport), onActivation: activate)
    }

    ///Use when testing requires the mock service to simulate a service response to the flag request callback
    func stubFlagResponse(statusCode: Int, badData: Bool = false, responseOnly: Bool = false, errorOnly: Bool = false, responseDate: Date? = nil) {
        let response = HTTPURLResponse(url: config.baseUrl, statusCode: statusCode, httpVersion: Constants.httpVersion, headerFields: HTTPURLResponse.dateHeader(from: responseDate))
        if statusCode == HTTPURLResponse.StatusCodes.ok {
            let flagData = try? JSONSerialization.data(withJSONObject: Constants.stubFeatureFlags(includeNullValue: false).dictionaryValue,
                                                       options: [])
            stubbedFlagResponse = (flagData, response, nil)
            if badData {
                stubbedFlagResponse = (Constants.errorData, response, nil)
            }
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
        "\(Constants.stubNameFlag) using method \(useReport ? URLRequest.HTTPMethods.report : URLRequest.HTTPMethods.get) with response status code \(statusCode)"
    }

    // MARK: Stream

    var streamHost: String? {
        config.streamUrl.host
    }
    var getStreamRequestStubTest: HTTPStubsTestBlock {
        isScheme(Constants.schemeHttps) && isHost(streamHost!) && isMethodGET()
    }
    var reportStreamRequestStubTest: HTTPStubsTestBlock {
        isScheme(Constants.schemeHttps) && isHost(streamHost!) && isMethodREPORT()
    }

    ///Use when testing requires the mock service to actually make an event source connection request
    func stubStreamRequest(useReport: Bool, success: Bool, onActivation activate: ((URLRequest, HTTPStubsDescriptor, HTTPStubsResponse) -> Void)? = nil) {
        var stubResponse: HTTPStubsResponseBlock = { _ in
            HTTPStubsResponse(error: Constants.error)
        }
        if success {
            stubResponse = { _ in
                HTTPStubsResponse(data: Constants.streamData, statusCode: Int32(HTTPURLResponse.StatusCodes.ok), headers: nil)
            }
        }
        stubRequest(passingTest: useReport ? reportStreamRequestStubTest : getStreamRequestStubTest, stub: stubResponse, name: Constants.stubNameStream, onActivation: activate)
    }

    // MARK: Publish Event

    var eventHost: String? {
        config.eventsUrl.host
    }
    var eventRequestStubTest: HTTPStubsTestBlock {
        isScheme(Constants.schemeHttps) && isHost(eventHost!) && isMethodPOST()
    }

    ///Use when testing requires the mock service to actually make an event request
    func stubEventRequest(success: Bool, onActivation activate: ((URLRequest, HTTPStubsDescriptor, HTTPStubsResponse) -> Void)? = nil) {
        let stubResponse: HTTPStubsResponseBlock = success ? { _ in
            HTTPStubsResponse(data: Data(), statusCode: Int32(HTTPURLResponse.StatusCodes.accepted), headers: nil)
        } : { _ in
            HTTPStubsResponse(error: Constants.error)
        }
        stubRequest(passingTest: eventRequestStubTest, stub: stubResponse, name: Constants.stubNameEvent, onActivation: activate)
    }

    ///Use when testing requires the mock service to provide a service response to the event request callback
    func stubEventResponse(success: Bool, responseOnly: Bool = false, errorOnly: Bool = false, responseDate: Date? = nil) {
        if success {
            let response = HTTPURLResponse(url: config.eventsUrl,
                                           statusCode: HTTPURLResponse.StatusCodes.accepted,
                                           httpVersion: Constants.httpVersion,
                                           headerFields: HTTPURLResponse.dateHeader(from: responseDate))
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
    var errorEventHTTPURLResponse: HTTPURLResponse! {
        HTTPURLResponse(url: config.eventsUrl, statusCode: HTTPURLResponse.StatusCodes.internalServerError, httpVersion: Constants.httpVersion, headerFields: nil)
    }

    // MARK: Publish Diagnostic

    ///Use when testing requires the mock service to actually make an diagnostic request
    func stubDiagnosticRequest(success: Bool, onActivation activate: ((URLRequest, HTTPStubsDescriptor, HTTPStubsResponse) -> Void)? = nil) {
        let stubResponse: HTTPStubsResponseBlock = success ? { _ in
            HTTPStubsResponse(data: Data(), statusCode: Int32(HTTPURLResponse.StatusCodes.accepted), headers: nil)
        } : { _ in
            HTTPStubsResponse(error: Constants.error)
        }
        stubRequest(passingTest: eventRequestStubTest, stub: stubResponse, name: Constants.stubNameDiagnostic, onActivation: activate)
    }

    ///Use when testing requires the mock service to provide a service response to the diagnostic request callback
    func stubDiagnosticResponse(success: Bool, responseOnly: Bool = false, errorOnly: Bool = false) {
        if success {
            let response = HTTPURLResponse(url: config.eventsUrl,
                                           statusCode: HTTPURLResponse.StatusCodes.accepted,
                                           httpVersion: Constants.httpVersion,
                                           headerFields: [:])
            stubbedDiagnosticResponse = (nil, response, nil)
            return
        }

        if responseOnly {
            stubbedDiagnosticResponse = (nil, errorDiagnosticHTTPURLResponse, nil)
        } else if errorOnly {
            stubbedDiagnosticResponse = (nil, nil, Constants.error)
        } else {
            stubbedDiagnosticResponse = (nil, errorDiagnosticHTTPURLResponse, Constants.error)
        }
    }
    var errorDiagnosticHTTPURLResponse: HTTPURLResponse! {
        HTTPURLResponse(url: config.eventsUrl, statusCode: HTTPURLResponse.StatusCodes.internalServerError, httpVersion: Constants.httpVersion, headerFields: nil)
    }

    // MARK: Stub

    var anyRequestStubTest: HTTPStubsTestBlock { { _ in true } }

    private func stubRequest(passingTest test: @escaping HTTPStubsTestBlock,
                             stub: @escaping HTTPStubsResponseBlock,
                             name: String,
                             onActivation activation: ((URLRequest, HTTPStubsDescriptor, HTTPStubsResponse) -> Void)? = nil) {
        HTTPStubs.stubRequests(passingTest: test, withStubResponse: stub).name = name
        if let activation = activation {
            activationBlocks.append((test, activation))
        }
        HTTPStubs.onStubActivation(onActivation)
    }

    private func onActivation(request: URLRequest, stubDescriptor: HTTPStubsDescriptor, stubResponse: HTTPStubsResponse) {
        for activationBlock in activationBlocks.reversed() {
            if !activationBlock.testBlock(request) {
                continue
            }
            activationBlock.callback(request, stubDescriptor, stubResponse)
            return
        }
    }
}

extension HTTPStubs {
    class func stub(named name: String) -> HTTPStubsDescriptor? {
        (HTTPStubs.allStubs() as? [HTTPStubsDescriptor])?.first { $0.name == name }
    }
}

/**
 * Matcher testing that the `NSURLRequest` is using the **REPORT** `HTTPMethod`
 *
 * - Returns: a matcher (HTTPStubsTestBlock) that succeeds only if the request
 *            is using the REPORT method
 */
public func isMethodREPORT() -> HTTPStubsTestBlock { { $0.httpMethod == URLRequest.HTTPMethods.report } }

extension HTTPURLResponse {
    static func dateHeader(from date: Date?) -> [String: String]? {
        guard let date = date
        else { return nil }
        return [HTTPURLResponse.HeaderKeys.date: DateFormatter.httpUrlHeaderFormatter.string(from: date)]
    }
}

extension LDFlagKey {
    var isKnownFlagKey: Bool {
        DarklyServiceMock.FlagKeys.knownFlags.contains(self)
    }
    var hasAlternateValue: Bool {
        DarklyServiceMock.FlagKeys.flagsWithAnAlternateValue.contains(self)
    }
}
