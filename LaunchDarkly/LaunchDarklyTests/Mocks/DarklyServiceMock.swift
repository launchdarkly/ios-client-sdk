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

        static var knownFlags: [LDFlagKey] {
            [bool, int, double, string, array, dictionary, null]
        }
    }

    struct FlagValues {
        static let bool: LDValue = true
        static let int: LDValue = 7
        static let double: LDValue = 3.14159
        static let string: LDValue = "string value"
        static let array: LDValue = [1, 2, 3]
        static let dictionary: LDValue = ["sub-flag-a": false, "sub-flag-b": 3, "sub-flag-c": 2.71828]
        static let null: LDValue = nil

        static func value(from flagKey: LDFlagKey) -> LDValue {
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
    }

    struct Constants {
        static let error = NSError(domain: NSURLErrorDomain, code: Int(CFNetworkErrors.cfurlErrorResourceUnavailable.rawValue), userInfo: nil)
        static let jsonErrorString = "Bad json data"
        static let errorData = jsonErrorString.data(using: .utf8)!

        static let schemeHttps = "https"
        static let httpVersion = "1.1"

        static let mockBaseUrl = URL(string: "https://dummy.base.com")!
        static let mockEventsUrl = URL(string: "https://dummy.events.com")!
        static let mockStreamUrl = URL(string: "https://dummy.stream.com")!

        static let variation = 2
        static let version = 4
        static let flagVersion = 3
        static let trackEvents = true
        static let debugEventsUntilDate = Date().addingTimeInterval(30.0)
        static let reason: [String: LDValue] = ["kind": "OFF"]

        static func stubFeatureFlags(debugEventsUntilDate: Date? = Date().addingTimeInterval(30.0)) -> [LDFlagKey: FeatureFlag] {
            let flagKeys = FlagKeys.knownFlags
            let featureFlagTuples = flagKeys.map { flagKey in
                (flagKey, stubFeatureFlag(for: flagKey, debugEventsUntilDate: debugEventsUntilDate))
            }

            return Dictionary(uniqueKeysWithValues: featureFlagTuples)
        }

        private static func version(for flagKey: LDFlagKey, useAlternateVersion: Bool) -> Int? {
            return useAlternateVersion ? version + 1 : version
        }

        static func stubFeatureFlag(for flagKey: LDFlagKey,
                                    useAlternateVersion: Bool = false,
                                    trackEvents: Bool = true,
                                    debugEventsUntilDate: Date? = Date().addingTimeInterval(30.0)) -> FeatureFlag {
            FeatureFlag(flagKey: flagKey,
                        value: FlagValues.value(from: flagKey),
                        variation: variation,
                        version: version(for: flagKey, useAlternateVersion: useAlternateVersion),
                        flagVersion: flagVersion,
                        trackEvents: trackEvents,
                        debugEventsUntilDate: debugEventsUntilDate,
                        reason: nil,
                        trackReason: false)
        }
    }

    var config: LDConfig
    var context: LDContext
    var diagnosticCache: DiagnosticCaching? = nil

    var activationBlocks = [(testBlock: HTTPStubsTestBlock, callback: ((URLRequest, HTTPStubsDescriptor, HTTPStubsResponse) -> Void))]()

    init(config: LDConfig = LDConfig.stub, context: LDContext = LDContext.stub()) {
        self.config = config
        self.context = context
    }

    var stubbedFlagResponse: ServiceResponse?
    var getFeatureFlagsUseReportCalledValue = [Bool]()
    var getFeatureFlagsCallCount = 0
    func getFeatureFlags(useReport: Bool, completion: ServiceCompletionHandler?) {
        getFeatureFlagsCallCount += 1
        getFeatureFlagsUseReportCalledValue.append(useReport)
        completion?(stubbedFlagResponse ?? (nil, nil, nil, nil))
    }

    var clearFlagResponseCacheCallCount = 0
    func resetFlagResponseCache(etag: String?) {
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
    var publishEventDataCallCount = 0
    var publishedEventData: Data?
    func publishEventData(_ eventData: Data, _ payloadId: String, completion: ServiceCompletionHandler?) {
        publishEventDataCallCount += 1
        publishedEventData = eventData
        completion?(stubbedEventResponse ?? (nil, nil, nil, nil))
    }

    var stubbedDiagnosticResponse: ServiceResponse?
    var publishDiagnosticCallCount = 0
    var publishedDiagnostic: DiagnosticEvent?
    var publishDiagnosticCallback: (() -> Void)?
    func publishDiagnostic<T: DiagnosticEvent & Encodable>(diagnosticEvent: T, completion: ServiceCompletionHandler?) {
        publishDiagnosticCallCount += 1
        publishedDiagnostic = diagnosticEvent
        publishDiagnosticCallback?()
        completion?(stubbedDiagnosticResponse ?? (nil, nil, nil, nil))
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

    /// Use when testing requires the mock service to actually make a flag request
    func stubFlagRequest(statusCode: Int,
                         featureFlags: [LDFlagKey: FeatureFlag]? = nil,
                         useReport: Bool,
                         flagResponseEtag: String? = nil,
                         onActivation activate: ((URLRequest) -> Void)? = nil) {
        let stubbedFeatureFlags = featureFlags ?? Constants.stubFeatureFlags()
        let responseData = statusCode == HTTPURLResponse.StatusCodes.ok ? try! JSONEncoder().encode(stubbedFeatureFlags) : Data()
        let stubResponse: HTTPStubsResponseBlock = { _ in
            var headers: [String: String] = [:]
            if let flagResponseEtag = flagResponseEtag {
                headers = [HTTPURLResponse.HeaderKeys.etag: flagResponseEtag,
                           "Cache-Control": "max-age=0"]
            }
            return HTTPStubsResponse(data: responseData, statusCode: Int32(statusCode), headers: headers)
        }
        stubRequest(passingTest: useReport ? reportFlagRequestStubTest : getFlagRequestStubTest,
                    stub: stubResponse,
                    name: flagStubName(statusCode: statusCode, useReport: useReport)) { request, _, _ in
            activate?(request)
        }
    }

    /// Use when testing requires the mock service to simulate a service response to the flag request callback
    func stubFlagResponse(statusCode: Int, badData: Bool = false, responseOnly: Bool = false, errorOnly: Bool = false, responseDate: Date? = nil) {
        let response = HTTPURLResponse(url: config.baseUrl, statusCode: statusCode, httpVersion: Constants.httpVersion, headerFields: HTTPURLResponse.dateHeader(from: responseDate))
        if statusCode == HTTPURLResponse.StatusCodes.ok {
            let flagData = try? JSONEncoder().encode(Constants.stubFeatureFlags())
            stubbedFlagResponse = (flagData, response, nil, nil)
            if badData {
                stubbedFlagResponse = (Constants.errorData, response, nil, nil)
            }
            return
        }

        if responseOnly {
            stubbedFlagResponse = (nil, response, nil, nil)
        } else if errorOnly {
            stubbedFlagResponse = (nil, nil, Constants.error, nil)
        } else {
            stubbedFlagResponse = (nil, response, Constants.error, nil)
        }
    }

    func flagStubName(statusCode: Int, useReport: Bool) -> String {
        "Flag request stub using method \(useReport ? URLRequest.HTTPMethods.report : URLRequest.HTTPMethods.get) with response status code \(statusCode)"
    }

    // MARK: Publish Event

    var eventHost: String? {
        config.eventsUrl.host
    }
    var eventRequestStubTest: HTTPStubsTestBlock {
        isScheme(Constants.schemeHttps) && isHost(eventHost!) && isMethodPOST()
    }

    /// Use when testing requires the mock service to actually make an event request
    func stubEventRequest(success: Bool, onActivation activate: ((URLRequest) -> Void)? = nil) {
        let stubResponse: HTTPStubsResponseBlock = success ? { _ in
            HTTPStubsResponse(data: Data(), statusCode: Int32(HTTPURLResponse.StatusCodes.accepted), headers: nil)
        } : { _ in
            HTTPStubsResponse(error: Constants.error)
        }
        stubRequest(passingTest: eventRequestStubTest, stub: stubResponse, name: "Event report stub") { request, _, _ in
            activate?(request)
        }
    }

    /// Use when testing requires the mock service to provide a service response to the event request callback
    func stubEventResponse(success: Bool, responseOnly: Bool = false, errorOnly: Bool = false, responseDate: Date? = nil) {
        if success {
            let response = HTTPURLResponse(url: config.eventsUrl,
                                           statusCode: HTTPURLResponse.StatusCodes.accepted,
                                           httpVersion: Constants.httpVersion,
                                           headerFields: HTTPURLResponse.dateHeader(from: responseDate))
            stubbedEventResponse = (nil, response, nil, nil)
            return
        }

        if responseOnly {
            stubbedEventResponse = (nil, errorEventHTTPURLResponse, nil, nil)
        } else if errorOnly {
            stubbedEventResponse = (nil, nil, Constants.error, nil)
        } else {
            stubbedEventResponse = (nil, errorEventHTTPURLResponse, Constants.error, nil)
        }
    }
    var errorEventHTTPURLResponse: HTTPURLResponse! {
        HTTPURLResponse(url: config.eventsUrl, statusCode: HTTPURLResponse.StatusCodes.internalServerError, httpVersion: Constants.httpVersion, headerFields: nil)
    }

    // MARK: Publish Diagnostic

    /// Use when testing requires the mock service to actually make an diagnostic request
    func stubDiagnosticRequest(success: Bool, onActivation activate: ((URLRequest, HTTPStubsDescriptor, HTTPStubsResponse) -> Void)? = nil) {
        let stubResponse: HTTPStubsResponseBlock = success ? { _ in
            HTTPStubsResponse(data: Data(), statusCode: Int32(HTTPURLResponse.StatusCodes.accepted), headers: nil)
        } : { _ in
            HTTPStubsResponse(error: Constants.error)
        }
        stubRequest(passingTest: eventRequestStubTest, stub: stubResponse, name: "Diagnostic report stub", onActivation: activate)
    }

    // MARK: Stub

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
