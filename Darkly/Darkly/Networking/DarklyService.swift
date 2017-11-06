//
//  DarklyService.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 9/19/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation
import DarklyEventSource

typealias ServiceResponse = (data: Data?, urlResponse: URLResponse?, error: Error?)
typealias ServiceCompletionHandler = (ServiceResponse) -> Void

protocol DarklyServiceProvider: class {
    func getFeatureFlags(user: LDUser, completion: ServiceCompletionHandler?)
    func createEventSource() -> DarklyStreamingProvider
    func publishEvents(_ events: [LDEvent], completion: ServiceCompletionHandler?)
}

//sourcery: AutoMockable
protocol DarklyStreamingProvider: class {
    func onMessageEvent(_ handler: LDEventSourceEventHandler?)
    func close()
}

extension LDEventSource: DarklyStreamingProvider {
    func onMessageEvent(_ handler: LDEventSourceEventHandler?) {
        guard let handler = handler else { return }
        self.onMessage(handler)
    }
}

final class DarklyService: DarklyServiceProvider {
    
    struct Constants {
        static let flagRequestPath = "msdk/eval/users"
        static let streamRequestPath = "mping"
        static let eventRequestPath = "mobile/events/bulk"
        static let httpMethodPost = "POST"
    }
    
    private let mobileKey: String
    private let config: LDConfig
    let httpHeaders: HTTPHeaders
    private var session: URLSession

    init(mobileKey: String, config: LDConfig) {
        self.mobileKey = mobileKey
        self.config = config
        self.httpHeaders = HTTPHeaders(mobileKey: mobileKey)

        self.session = URLSession(configuration: URLSessionConfiguration.default)
    }
    
    // MARK: Feature Flags
    
    func getFeatureFlags(user: LDUser, completion: ServiceCompletionHandler?) {
        guard !mobileKey.isEmpty,
            let flagRequest = flagRequest(user: user)
        else { return }
        let dataTask = self.session.dataTask(with: flagRequest) { (data, response, error) in
            completion?((data, response, error))
        }
        dataTask.resume()
    }
    
    private func flagRequest(user: LDUser) -> URLRequest? {
        guard let flagRequestUrl = flagRequestUrl(user: user) else { return nil }
        var request = URLRequest(url: flagRequestUrl, cachePolicy: .useProtocolCachePolicy, timeoutInterval: config.connectionTimeout)
        request.appendHeaders(httpHeaders.flagRequestHeaders)
        
        return request
    }
    
    private func flagRequestUrl(user: LDUser) -> URL? {
        guard let encodedUser = user.jsonDictionaryWithoutConfig.base64UrlEncodedString else { return nil }
        return config.baseUrl.appendingPathComponent(Constants.flagRequestPath).appendingPathComponent(encodedUser)
    }
    
    // MARK: Streaming
    
    func createEventSource() -> DarklyStreamingProvider {
        return LDEventSource(url: streamRequestUrl, httpHeaders: httpHeaders.eventSourceHeaders)
    }

    private var streamRequestUrl: URL { return config.streamUrl.appendingPathComponent(Constants.streamRequestPath) }
    
    // MARK: Publish Events
    
    func publishEvents(_ events: [LDEvent], completion: ServiceCompletionHandler?) {
        guard !mobileKey.isEmpty,
            !events.isEmpty
        else { return }
        let dataTask = self.session.dataTask(with: eventRequest(events: events)) { (data, response, error) in
            completion?((data, response, error))
        }
        dataTask.resume()
    }
    
    private func eventRequest(events: [LDEvent]) -> URLRequest {
        var request = URLRequest(url: eventUrl, cachePolicy: .useProtocolCachePolicy, timeoutInterval: config.connectionTimeout)
        request.appendHeaders(httpHeaders.eventRequestHeaders)
        request.httpMethod = Constants.httpMethodPost
        request.httpBody = events.jsonData

        return request
    }
    
    private var eventUrl: URL { return config.eventsUrl.appendingPathComponent(Constants.eventRequestPath) }
}

extension URLRequest {
    mutating func appendHeaders(_ newHeaders: [String: String]) {
        var headers = self.allHTTPHeaderFields ?? [:]
        headers.merge(newHeaders) { (_, newValue) in newValue }
        self.allHTTPHeaderFields = headers
    }
}
