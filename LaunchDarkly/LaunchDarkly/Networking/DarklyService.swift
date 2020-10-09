//
//  DarklyService.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import LDSwiftEventSource

typealias ServiceResponse = (data: Data?, urlResponse: URLResponse?, error: Error?)
typealias ServiceCompletionHandler = (ServiceResponse) -> Void

//sourcery: autoMockable
protocol DarklyStreamingProvider: class {
    func start()
    func stop()
}

extension EventSource: DarklyStreamingProvider {}

protocol DarklyServiceProvider: class {
    var config: LDConfig { get }
    var user: LDUser { get }
    var diagnosticCache: DiagnosticCaching? { get }

    func getFeatureFlags(useReport: Bool, completion: ServiceCompletionHandler?)
    func clearFlagResponseCache()
    func createEventSource(useReport: Bool, handler: EventHandler, errorHandler: ConnectionErrorHandler?) -> DarklyStreamingProvider
    func publishEventDictionaries(_ eventDictionaries: [[String: Any]], _ payloadId: String, completion: ServiceCompletionHandler?)
    func publishDiagnostic<T: DiagnosticEvent & Encodable>(diagnosticEvent: T, completion: ServiceCompletionHandler?)
}

final class DarklyService: DarklyServiceProvider {

    struct EventRequestPath {
        static let bulk = "mobile/events/bulk"
        static let diagnostic = "mobile/events/diagnostic"
    }

    struct FlagRequestPath {
        static let get = "msdk/evalx/users"
        static let report = "msdk/evalx/user"
    }

    struct StreamRequestPath {
        static let meval = "meval"
    }

    struct HTTPRequestMethod {
        static let get = "GET"
        static let report = "REPORT"
    }

    struct ReasonsPath {
        static let reasons = URLQueryItem(name: "withReasons", value: "true")
    }

    let config: LDConfig
    let user: LDUser
    let httpHeaders: HTTPHeaders
    let diagnosticCache: DiagnosticCaching?
    private (set) var serviceFactory: ClientServiceCreating
    private var session: URLSession

    init(config: LDConfig, user: LDUser, serviceFactory: ClientServiceCreating) {
        self.config = config
        self.user = user
        self.serviceFactory = serviceFactory

        if !config.mobileKey.isEmpty && !config.diagnosticOptOut {
            self.diagnosticCache = serviceFactory.makeDiagnosticCache(sdkKey: config.mobileKey)
        } else {
            self.diagnosticCache = nil
        }

        self.httpHeaders = HTTPHeaders(config: config, environmentReporter: serviceFactory.makeEnvironmentReporter())
        self.session = URLSession(configuration: URLSessionConfiguration.default)
    }

    // MARK: Feature Flags

    func getFeatureFlags(useReport: Bool, completion: ServiceCompletionHandler?) {
        guard !config.mobileKey.isEmpty,
            let flagRequest = flagRequest(useReport: useReport)
        else {
            if config.mobileKey.isEmpty {
                Log.debug(typeName(and: #function, appending: ": ") + "Aborting. No mobileKey.")
            } else {
                Log.debug(typeName(and: #function, appending: ": ") + "Aborting. Unable to create flagRequest.")
            }
            return
        }
        let dataTask = self.session.dataTask(with: flagRequest) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.processEtag(from: (data, response, error))
                completion?((data, response, error))
            }
        }
        dataTask.resume()
    }

    private func flagRequest(useReport: Bool) -> URLRequest? {
        guard let flagRequestUrl = flagRequestUrl(useReport: useReport)
        else { return nil }
        var request = URLRequest(url: flagRequestUrl, cachePolicy: flagRequestCachePolicy, timeoutInterval: config.connectionTimeout)
        request.appendHeaders(httpHeaders.flagRequestHeaders)
        if useReport {
            guard let userData = user.dictionaryValue(includePrivateAttributes: true, config: config).jsonData
            else { return nil }
            request.httpMethod = URLRequest.HTTPMethods.report
            request.httpBody = userData
        }

        return request
    }

    //The flagRequestCachePolicy varies to allow the SDK to force a reload from the source on a user change. Both the SDK and iOS keep the etag from the last request. On a user change if we use .useProtocolCachePolicy, even though the SDK doesn't supply the etag, iOS does (despite clearing the URLCache!!!). In order to force iOS to ignore the etag, change the policy to .reloadIgnoringLocalCache when there is no etag.
    //Note that after setting .reloadRevalidatingCacheData on the request, the property appears not to accept it, and instead sets .reloadIgnoringLocalCacheData. Despite this, there does appear to be a difference in cache policy, because the SDK behaves as expected: on a new user it requests flags without the cache, and on a request with an etag it requests flags allowing the cache. Although testing shows that we could always set .reloadIgnoringLocalCacheData here, because that is NOT symantecally the desired behavior, the method distinguishes between the use cases.
    //watchOS logs an error when .useProtocolCachePolicy is set for flag requests with an etag. By setting .reloadRevalidatingCacheData, the SDK behaves correctly, but watchOS does not log an error.
    private var flagRequestCachePolicy: URLRequest.CachePolicy {
        return httpHeaders.hasFlagRequestEtag ? .reloadRevalidatingCacheData : .reloadIgnoringLocalCacheData
    }
    
    private func flagRequestUrl(useReport: Bool) -> URL? {
        if useReport {
            return shouldGetReasons(url: config.baseUrl.appendingPathComponent(FlagRequestPath.report))
        }
        guard let encodedUser = user
            .dictionaryValue(includePrivateAttributes: true, config: config)
            .base64UrlEncodedString
        else {
            return nil
        }
        return shouldGetReasons(url: config.baseUrl.appendingPathComponent(FlagRequestPath.get).appendingPathComponent(encodedUser))
    }
    
    private func shouldGetReasons(url: URL) -> URL {
        if config.evaluationReasons {
            var urlComponent = URLComponents(url: url, resolvingAgainstBaseURL: false)
            urlComponent?.queryItems = [ReasonsPath.reasons]
            return urlComponent?.url ?? url
        } else {
            return url
        }
    }

    private func processEtag(from serviceResponse: ServiceResponse) {
        guard serviceResponse.error == nil,
            serviceResponse.urlResponse?.httpStatusCode == HTTPURLResponse.StatusCodes.ok,
            serviceResponse.data?.jsonDictionary != nil
        else {
            if serviceResponse.urlResponse?.httpStatusCode != HTTPURLResponse.StatusCodes.notModified {
                HTTPHeaders.setFlagRequestEtag(nil, for: config.mobileKey)
            }
            return
        }
        HTTPHeaders.setFlagRequestEtag(serviceResponse.urlResponse?.httpHeaderEtag, for: config.mobileKey)
    }

    //Although this does not need any info stored in the DarklyService instance, LDClient shouldn't have to distinguish between an actual and a mock. Making this an instance method does that.
    func clearFlagResponseCache() {
        URLCache.shared.removeAllCachedResponses()
        HTTPHeaders.removeFlagRequestEtags()
    }

    // MARK: Streaming

    func createEventSource(useReport: Bool, handler: EventHandler, errorHandler: ConnectionErrorHandler?) -> DarklyStreamingProvider {
        if useReport {
            return serviceFactory.makeStreamingProvider(url: reportStreamRequestUrl,
                                                        httpHeaders: httpHeaders.eventSourceHeaders,
                                                        connectMethod: DarklyService.HTTPRequestMethod.report,
                                                        connectBody: user
                                                            .dictionaryValue(includePrivateAttributes: true, config: config)
                                                            .jsonData,
                                                        handler: handler,
                                                        errorHandler: errorHandler)
        }
        return serviceFactory.makeStreamingProvider(url: getStreamRequestUrl,
                                                    httpHeaders: httpHeaders.eventSourceHeaders,
                                                    handler: handler,
                                                    errorHandler: errorHandler)
    }

    private var getStreamRequestUrl: URL {
        shouldGetReasons(url: config.streamUrl.appendingPathComponent(StreamRequestPath.meval)
            .appendingPathComponent(user
                .dictionaryValue(includePrivateAttributes: true, config: config)
                .base64UrlEncodedString ?? ""))
    }
    private var reportStreamRequestUrl: URL {
        shouldGetReasons(url: config.streamUrl.appendingPathComponent(StreamRequestPath.meval))
    }

    // MARK: Publish Events

    func publishEventDictionaries(_ eventDictionaries: [[String: Any]], _ payloadId: String, completion: ServiceCompletionHandler?) {
        guard !config.mobileKey.isEmpty,
            !eventDictionaries.isEmpty
        else {
            if config.mobileKey.isEmpty {
                Log.debug(typeName(and: #function, appending: ": ") + "Aborting. No mobileKey.")
            } else {
                Log.debug(typeName(and: #function, appending: ": ") + "Aborting. No event dictionary.")
            }
            return
        }
        let dataTask = self.session.dataTask(with: eventRequest(eventDictionaries: eventDictionaries, payloadId: payloadId)) { (data, response, error) in
            completion?((data, response, error))
        }
        dataTask.resume()
    }

    private func eventRequest(eventDictionaries: [[String: Any]], payloadId: String) -> URLRequest {
        var request = URLRequest(url: eventUrl, cachePolicy: .useProtocolCachePolicy, timeoutInterval: config.connectionTimeout)
        request.appendHeaders([HTTPHeaders.HeaderKey.eventPayloadIDHeader: payloadId])
        request.appendHeaders(httpHeaders.eventRequestHeaders)
        request.httpMethod = URLRequest.HTTPMethods.post
        request.httpBody = eventDictionaries.jsonData

        return request
    }

    private var eventUrl: URL {
        config.eventsUrl.appendingPathComponent(EventRequestPath.bulk)
    }

    func publishDiagnostic<T: DiagnosticEvent & Encodable>(diagnosticEvent: T, completion: ServiceCompletionHandler?) {
        guard !config.mobileKey.isEmpty
        else {
            Log.debug(typeName(and: #function, appending: ": ") + "Aborting. No mobile key.")
            return
        }
        let dataTask = self.session.dataTask(with: diagnosticRequest(diagnosticEvent: diagnosticEvent)) { data, response, error in
            completion?((data, response, error))
        }
        dataTask.resume()
    }

    private func diagnosticRequest<T: DiagnosticEvent & Encodable>(diagnosticEvent: T) -> URLRequest {
        var request = URLRequest(url: diagnosticUrl, cachePolicy: .useProtocolCachePolicy, timeoutInterval: config.connectionTimeout)
        request.appendHeaders(httpHeaders.diagnosticRequestHeaders)
        request.httpMethod = URLRequest.HTTPMethods.post
        request.httpBody = try? JSONEncoder().encode(diagnosticEvent)
        return request
    }

    private var diagnosticUrl: URL {
        config.eventsUrl.appendingPathComponent(EventRequestPath.diagnostic)
    }
}

extension DarklyService: TypeIdentifying { }

extension URLRequest {
    mutating func appendHeaders(_ newHeaders: [String: String]) {
        var headers = self.allHTTPHeaderFields ?? [:]
        headers.merge(newHeaders) { _, newValue in
            newValue
        }
        self.allHTTPHeaderFields = headers
    }
}
