//
//  DarklyService.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 9/19/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import DarklyEventSource

typealias ServiceResponse = (data: Data?, urlResponse: URLResponse?, error: Error?)
typealias ServiceCompletionHandler = (ServiceResponse) -> Void

protocol DarklyServiceProvider: class {
    func getFeatureFlags(useReport: Bool, completion: ServiceCompletionHandler?)
    func clearFlagResponseCache()
    func createEventSource(useReport: Bool) -> DarklyStreamingProvider
    func publishEventDictionaries(_ eventDictionaries: [[String: Any]], completion: ServiceCompletionHandler?)
    var config: LDConfig { get }
    var user: LDUser { get }
}

//sourcery: autoMockable
protocol DarklyStreamingProvider: class {
    func onMessageEvent(_ handler: LDEventSourceEventHandler?)
    func onErrorEvent(_ handler: LDEventSourceEventHandler?)
    func open()
    func close()
}

extension LDEventSource: DarklyStreamingProvider {
    func onMessageEvent(_ handler: LDEventSourceEventHandler?) {
        guard let handler = handler
        else {
            return
        }
        self.onMessage(handler)
    }

    func onErrorEvent(_ handler: LDEventSourceEventHandler?) {
        guard let handler = handler
        else {
            return
        }
        self.onError(handler)
    }
}

final class DarklyService: DarklyServiceProvider {
    
    struct EventRequestPath {
        static let bulk = "mobile/events/bulk"
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
    
    let config: LDConfig
    let user: LDUser
    let httpHeaders: HTTPHeaders
    private (set) var serviceFactory: ClientServiceCreating
    private var session: URLSession

    init(config: LDConfig, user: LDUser, serviceFactory: ClientServiceCreating) {
        self.config = config
        self.user = user
        self.serviceFactory = serviceFactory
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
        let dataTask = self.session.dataTask(with: flagRequest) { [weak self] (data, response, error) in
            DispatchQueue.main.async {
                self?.processEtag(from: (data, response, error))
                completion?((data, response, error))
            }
        }
        dataTask.resume()
    }
    
    private func flagRequest(useReport: Bool) -> URLRequest? {
        guard let flagRequestUrl = flagRequestUrl(useReport: useReport)
        else {
            return nil
        }
        var request = URLRequest(url: flagRequestUrl, cachePolicy: flagRequestCachePolicy, timeoutInterval: config.connectionTimeout)
        request.appendHeaders(httpHeaders.flagRequestHeaders)
        if useReport {
            guard let userData = user.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config).jsonData
            else {
                return nil
            }
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
            return config.baseUrl.appendingPathComponent(FlagRequestPath.report)
        }
        guard let encodedUser = user
            .dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
            .base64UrlEncodedString
        else {
            return nil
        }
        return config.baseUrl.appendingPathComponent(FlagRequestPath.get).appendingPathComponent(encodedUser)
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
    
    func createEventSource(useReport: Bool) -> DarklyStreamingProvider {
        if useReport {
            return serviceFactory.makeStreamingProvider(url: reportStreamRequestUrl,
                                                        httpHeaders: httpHeaders.eventSourceHeaders,
                                                        connectMethod: DarklyService.HTTPRequestMethod.report,
                                                        connectBody: user
                                                            .dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                                                            .jsonData)

        }
        return serviceFactory.makeStreamingProvider(url: getStreamRequestUrl, httpHeaders: httpHeaders.eventSourceHeaders)
    }

    private var getStreamRequestUrl: URL {
        return config.streamUrl.appendingPathComponent(StreamRequestPath.meval)
            .appendingPathComponent(user
                .dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                .base64UrlEncodedString ?? "")
    }
    private var reportStreamRequestUrl: URL {
        return config.streamUrl.appendingPathComponent(StreamRequestPath.meval)
    }

    // MARK: Publish Events
    
    func publishEventDictionaries(_ eventDictionaries: [[String: Any]], completion: ServiceCompletionHandler?) {
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
        let dataTask = self.session.dataTask(with: eventRequest(eventDictionaries: eventDictionaries)) { (data, response, error) in
            completion?((data, response, error))
        }
        dataTask.resume()
    }
    
    private func eventRequest(eventDictionaries: [[String: Any]]) -> URLRequest {
        var request = URLRequest(url: eventUrl, cachePolicy: .useProtocolCachePolicy, timeoutInterval: config.connectionTimeout)
        request.appendHeaders(httpHeaders.eventRequestHeaders)
        request.httpMethod = URLRequest.HTTPMethods.post
        request.httpBody = eventDictionaries.jsonData

        return request
    }
    
    private var eventUrl: URL {
        return config.eventsUrl.appendingPathComponent(EventRequestPath.bulk)
    }
}

extension DarklyService: TypeIdentifying { }

extension URLRequest {
    mutating func appendHeaders(_ newHeaders: [String: String]) {
        var headers = self.allHTTPHeaderFields ?? [:]
        headers.merge(newHeaders) { (_, newValue) in
            newValue
        }
        self.allHTTPHeaderFields = headers
    }
}
