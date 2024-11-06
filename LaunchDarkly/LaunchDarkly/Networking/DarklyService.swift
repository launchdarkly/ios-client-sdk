import Foundation
import LDSwiftEventSource
import OSLog
import DataCompression

typealias ServiceResponse = (data: Data?, urlResponse: URLResponse?, error: Error?, etag: String?)
typealias ServiceCompletionHandler = (ServiceResponse) -> Void

// sourcery: autoMockable
protocol DarklyStreamingProvider: AnyObject {
    func start()
    func stop()
}

extension EventSource: DarklyStreamingProvider {}

protocol DarklyServiceProvider: AnyObject {
    var config: LDConfig { get }
    var context: LDContext { get set }
    var diagnosticCache: DiagnosticCaching? { get }

    func getFeatureFlags(useReport: Bool, completion: ServiceCompletionHandler?)
    func resetFlagResponseCache(etag: String?)
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
        static let get = "msdk/evalx/contexts"
        static let report = "msdk/evalx/context"
    }

    struct StreamRequestPath {
        static let meval = "meval"
    }

    struct HTTPRequestMethod {
        static let get = "GET"
        static let report = "REPORT"
    }

    let config: LDConfig
    var context: LDContext
    let httpHeaders: HTTPHeaders
    let diagnosticCache: DiagnosticCaching?
    private(set) var serviceFactory: ClientServiceCreating
    private var session: URLSession
    var flagRequestEtag: String?

  init(config: LDConfig, context: LDContext, envReporter: EnvironmentReporting, serviceFactory: ClientServiceCreating) {
        self.config = config
        self.context = context
        self.serviceFactory = serviceFactory

        if !config.mobileKey.isEmpty && !config.diagnosticOptOut && config.sendEvents {
            self.diagnosticCache = serviceFactory.makeDiagnosticCache(sdkKey: config.mobileKey)
        } else {
            self.diagnosticCache = nil
        }

        self.httpHeaders = HTTPHeaders(config: config, environmentReporter: envReporter)
        // URLSessionConfiguration is a class, but `.default` creates a new instance. This does not effect other session configuration.
        let sessionConfig = URLSessionConfiguration.default

        if #available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *) {
            sessionConfig.tlsMinimumSupportedProtocolVersion = .TLSv12
        } else {
            sessionConfig.tlsMinimumSupportedProtocol = .tlsProtocol12
        }

        // We always revalidate the cache which we handle manually
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfig.urlCache = nil
        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: Feature Flags

    func resetFlagResponseCache(etag: String?) {
        flagRequestEtag = etag
    }

    func getFeatureFlags(useReport: Bool, completion: ServiceCompletionHandler?) {
        guard hasMobileKey(#function) else { return }
        let encoder = JSONEncoder()
        encoder.userInfo[LDContext.UserInfoKeys.includePrivateAttributes] = true
        encoder.userInfo[LDContext.UserInfoKeys.redactAttributes] = false
        encoder.outputFormatting = [.sortedKeys]

        guard let contextJsonData = try? encoder.encode(context)
        else {
            os_log("%s Aborting. Unable to create flag request.", log: config.logger, type: .debug, typeName(and: #function))
            return
        }

        var headers = httpHeaders.flagRequestHeaders
        if let etag = flagRequestEtag {
            headers.merge([HTTPHeaders.HeaderKey.ifNoneMatch: etag]) { orig, _ in orig }
        }
        var request = URLRequest(url: flagRequestUrl(useReport: useReport, getData: contextJsonData),
                                 ldHeaders: headers,
                                 ldConfig: config)
        if useReport {
            request.httpMethod = URLRequest.HTTPMethods.report
            request.httpBody = contextJsonData
        }

        self.session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.processEtag(from: (data: data, urlResponse: response, error: error, etag: self?.flagRequestEtag))
                completion?((data: data, urlResponse: response, error: error, etag: self?.flagRequestEtag))
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
        encoder.userInfo[LDContext.UserInfoKeys.includePrivateAttributes] = true
        encoder.userInfo[LDContext.UserInfoKeys.redactAttributes] = false
        encoder.outputFormatting = [.sortedKeys]

        let contextJsonData = try? encoder.encode(context)

        var streamRequestUrl = config.streamUrl.appendingPathComponent(StreamRequestPath.meval)
        var connectMethod = HTTPRequestMethod.get
        var connectBody: Data?

        if useReport {
            connectMethod = HTTPRequestMethod.report
            connectBody = contextJsonData
        } else {
            streamRequestUrl.appendPathComponent(contextJsonData?.base64UrlEncodedString ?? "", isDirectory: false)
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
        var headers = headers

        var httpBody = body
        if config.enableCompression {
            if let compressed = body.gzip() {
                httpBody = compressed
                headers.updateValue("gzip", forKey: "Content-Encoding")
            }
        }

        var request = URLRequest(url: url, ldHeaders: headers, ldConfig: config)
        request.httpMethod = URLRequest.HTTPMethods.post
        request.httpBody = httpBody

        session.dataTask(with: request) { data, response, error in
            completion?((data: data, urlResponse: response, error: error, etag: nil))
        }.resume()
    }

    private func hasMobileKey(_ location: String) -> Bool {
        if config.mobileKey.isEmpty {
            os_log("%s Aborting. No mobile key.", log: config.logger, type: .debug, typeName(and: #function))
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
