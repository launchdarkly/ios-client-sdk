import Foundation

struct HTTPHeaders {

    struct HeaderKey {
        static let authorization = "Authorization"
        static let userAgent = "User-Agent"
        static let contentType = "Content-Type"
        static let accept = "Accept"
        static let eventSchema = "X-LaunchDarkly-Event-Schema"
        static let ifNoneMatch = "If-None-Match"
        static let eventPayloadIDHeader = "X-LaunchDarkly-Payload-ID"
        static let sdkWrapper = "X-LaunchDarkly-Wrapper"
        static let tags = "X-LaunchDarkly-Tags"
    }

    struct HeaderValue {
        static let apiKey = "api_key"
        static let applicationJson = "application/json"
        static let eventSchema4 = "4"
    }

    private let mobileKey: String
    private let additionalHeaders: [String: String]
    private let authKey: String
    private let userAgent: String
    private let wrapperHeaderVal: String?
    private let applicationTag: String

    init(config: LDConfig, environmentReporter: EnvironmentReporting) {
        self.mobileKey = config.mobileKey
        self.additionalHeaders = config.additionalHeaders
        self.userAgent = "\(SystemCapabilities.systemName)/\(ReportingConsts.sdkVersion)"
        self.authKey = "\(HeaderValue.apiKey) \(config.mobileKey)"
        self.applicationTag = environmentReporter.applicationInfo.buildTag()

      if let wrapperName = config.wrapperName {
            if let wrapperVersion = config.wrapperVersion {
                wrapperHeaderVal = "\(wrapperName)/\(wrapperVersion)"
            } else {
                wrapperHeaderVal = wrapperName
            }
        } else {
            wrapperHeaderVal = nil
        }
    }

    private var baseHeaders: [String: String] {
        var headers = [HeaderKey.authorization: authKey,
                       HeaderKey.userAgent: userAgent]

        if let wrapperHeader = wrapperHeaderVal {
            headers[HeaderKey.sdkWrapper] = wrapperHeader
        }

        if !self.applicationTag.isEmpty {
            headers[HeaderKey.tags] = self.applicationTag
        }

        return headers
    }

    var eventSourceHeaders: [String: String] { withAdditionalHeaders(baseHeaders) }
    var flagRequestHeaders: [String: String] { withAdditionalHeaders(baseHeaders) }

    var eventRequestHeaders: [String: String] {
        var headers = baseHeaders
        headers[HeaderKey.contentType] = HeaderValue.applicationJson
        headers[HeaderKey.accept] = HeaderValue.applicationJson
        headers[HeaderKey.eventSchema] = HeaderValue.eventSchema4
        return withAdditionalHeaders(headers)
    }

    var diagnosticRequestHeaders: [String: String] {
        var headers = baseHeaders
        headers[HeaderKey.contentType] = HeaderValue.applicationJson
        headers[HeaderKey.accept] = HeaderValue.applicationJson
        return withAdditionalHeaders(headers)
    }

    private func withAdditionalHeaders(_ headers: [String: String]) -> [String: String] {
        headers.merging(additionalHeaders) { $1 }
    }
}
