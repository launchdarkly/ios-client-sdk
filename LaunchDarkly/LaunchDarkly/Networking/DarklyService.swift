import Foundation
import LDSwiftEventSource

typealias ServiceResponse = (data: Data?, urlResponse: URLResponse?, error: Error?)
typealias ServiceCompletionHandler = (ServiceResponse) -> Void

// sourcery: autoMockable
protocol DarklyStreamingProvider: AnyObject {
    func start()
    func stop()
}

extension EventSource: DarklyStreamingProvider {}

protocol DarklyServiceProvider: AnyObject {
    var config: LDConfig { get }
    var user: LDUser { get set }
    var diagnosticCache: DiagnosticCaching? { get }

    func getFeatureFlags(useReport: Bool, completion: ServiceCompletionHandler?)
    func clearFlagResponseCache()
    func createEventSource(useReport: Bool, handler: EventHandler, errorHandler: ConnectionErrorHandler?) -> DarklyStreamingProvider
    func publishEventData(_ eventData: Data, _ payloadId: String, completion: ServiceCompletionHandler?)
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

    let config: LDConfig
    var user: LDUser
    let httpHeaders: HTTPHeaders
    let diagnosticCache: DiagnosticCaching?
    private (set) var serviceFactory: ClientServiceCreating
    private var session: URLSession
    var flagRequestEtag: String?

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
        // URLSessionConfiguration is a class, but `.default` creates a new instance. This does not effect other session configuration.
        let sessionConfig = URLSessionConfiguration.default
        // We always revalidate the cache which we handle manually
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfig.urlCache = nil
        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: Feature Flags

    func clearFlagResponseCache() {
        flagRequestEtag = nil
    }

    func getFeatureFlags(useReport: Bool, completion: ServiceCompletionHandler?) {
        guard hasMobileKey(#function) else { return }
        let encoder = JSONEncoder()
        encoder.userInfo[LDUser.UserInfoKeys.includePrivateAttributes] = true
        guard let userJsonData = try? encoder.encode(user)
        else {
            Log.debug(typeName(and: #function, appending: ": ") + "Aborting. Unable to create flagRequest.")
            return
        }

        var headers = httpHeaders.flagRequestHeaders
        if let etag = flagRequestEtag {
            headers.merge([HTTPHeaders.HeaderKey.ifNoneMatch: etag]) { orig, _ in orig }
        }
        var request = URLRequest(url: flagRequestUrl(useReport: useReport, getData: userJsonData),
                                 ldHeaders: headers,
                                 ldConfig: config)
        if useReport {
            request.httpMethod = URLRequest.HTTPMethods.report
            request.httpBody = userJsonData
        }

        self.session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.processEtag(from: (data, response, error))
                completion?((data, response, error))
            }
        }.resume()
    }

    private func flagRequestUrl(useReport: Bool, getData: Data) -> URL {
        var flagRequestUrl = config.baseUrl
        if !useReport {
            flagRequestUrl.appendPathComponent(FlagRequestPath.get, isDirectory: true)
            flagRequestUrl.appendPathComponent(getData.base64UrlEncodedString, isDirectory: false)
        } else {
            flagRequestUrl.appendPathComponent(FlagRequestPath.report, isDirectory: false)
        }
        return shouldGetReasons(url: flagRequestUrl)
    }

    private func shouldGetReasons(url: URL) -> URL {
        guard config.evaluationReasons
        else { return url }

        var urlComponent = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponent?.queryItems = [URLQueryItem(name: "withReasons", value: "true")]
        return urlComponent?.url ?? url
    }

    private func processEtag(from serviceResponse: ServiceResponse) {
        guard serviceResponse.error == nil,
            serviceResponse.urlResponse?.httpStatusCode == HTTPURLResponse.StatusCodes.ok,
            serviceResponse.data?.jsonDictionary != nil
        else {
            if serviceResponse.urlResponse?.httpStatusCode != HTTPURLResponse.StatusCodes.notModified {
                flagRequestEtag = nil
            }
            return
        }
        flagRequestEtag = serviceResponse.urlResponse?.httpHeaderEtag
    }

    // MARK: Streaming

    func createEventSource(useReport: Bool, 
                           handler: EventHandler, 
                           errorHandler: ConnectionErrorHandler?) -> DarklyStreamingProvider {
        let encoder = JSONEncoder()
        encoder.userInfo[LDUser.UserInfoKeys.includePrivateAttributes] = true
        let userJsonData = try? encoder.encode(user)

        var streamRequestUrl = config.streamUrl.appendingPathComponent(StreamRequestPath.meval)
        var connectMethod = HTTPRequestMethod.get
        var connectBody: Data?

        if useReport {
            connectMethod = HTTPRequestMethod.report
            connectBody = userJsonData
        } else {
            streamRequestUrl.appendPathComponent(userJsonData?.base64UrlEncodedString ?? "", isDirectory: false)
        }

        return serviceFactory.makeStreamingProvider(url: shouldGetReasons(url: streamRequestUrl),
                                                    httpHeaders: httpHeaders.eventSourceHeaders,
                                                    connectMethod: connectMethod,
                                                    connectBody: connectBody,
                                                    handler: handler,
                                                    delegate: config.headerDelegate,
                                                    errorHandler: errorHandler)
    }

    // MARK: Publish Events

    func publishEventData(_ eventData: Data, _ payloadId: String, completion: ServiceCompletionHandler?) {
        guard hasMobileKey(#function) else { return }
        let url = config.eventsUrl.appendingPathComponent(EventRequestPath.bulk)
        let headers = [HTTPHeaders.HeaderKey.eventPayloadIDHeader: payloadId].merging(httpHeaders.eventRequestHeaders) { $1 }
        doPublish(url: url, headers: headers, body: eventData, completion: completion)
    }

    func publishDiagnostic<T: DiagnosticEvent & Encodable>(diagnosticEvent: T, completion: ServiceCompletionHandler?) {
        guard hasMobileKey(#function),
              let bodyData = try? JSONEncoder().encode(diagnosticEvent)
        else { return }

        let url = config.eventsUrl.appendingPathComponent(EventRequestPath.diagnostic)
        doPublish(url: url, headers: httpHeaders.diagnosticRequestHeaders, body: bodyData, completion: completion)
    }

    private func doPublish(url: URL, headers: [String: String], body: Data, completion: ServiceCompletionHandler?) {
        var request = URLRequest(url: url, ldHeaders: headers, ldConfig: config)
        request.httpMethod = URLRequest.HTTPMethods.post
        request.httpBody = body

        session.dataTask(with: request) { data, response, error in
            completion?((data, response, error))
        }.resume()
    }

    private func hasMobileKey(_ location: String) -> Bool {
        if config.mobileKey.isEmpty {
            Log.debug(typeName(and: location, appending: ": ") + "Aborting. No mobile key.")
        }
        return !config.mobileKey.isEmpty
    }
}

extension DarklyService: TypeIdentifying { }

extension URLRequest {
    init(url: URL, ldHeaders: [String: String], ldConfig: LDConfig) {
        self.init(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: ldConfig.connectionTimeout)
        var headers = self.allHTTPHeaderFields ?? [:]
        headers.merge(ldHeaders) { $1 }
        self.allHTTPHeaderFields = ldConfig.headerDelegate?(url, headers) ?? headers
    }
}
