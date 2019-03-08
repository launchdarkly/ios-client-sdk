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
    func createEventSource(useReport: Bool) -> DarklyStreamingProvider
    func publishEventDictionaries(_ eventDictionaries: [[String: Any]], completion: ServiceCompletionHandler?)
    var config: LDConfig { get }
    var user: LDUser { get }
}

//sourcery: AutoMockable
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
        let dataTask = self.session.dataTask(with: flagRequest) { (data, response, error) in
            DispatchQueue.main.async {
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
        var request = URLRequest(url: flagRequestUrl, cachePolicy: .useProtocolCachePolicy, timeoutInterval: config.connectionTimeout)
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
