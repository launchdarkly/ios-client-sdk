import Foundation

enum DiagnosticKind: String, Codable {
    case diagnosticInit  = "diagnostic-init",
         diagnosticStats = "diagnostic"
}

protocol DiagnosticEvent {
    var kind: DiagnosticKind { get }
    var creationDate: Int64 { get }
    var id: DiagnosticId { get }
}

struct DiagnosticInit: DiagnosticEvent, Encodable {
    let kind = DiagnosticKind.diagnosticInit
    let id: DiagnosticId
    let creationDate: Int64

    let sdk: DiagnosticSdk
    let configuration: DiagnosticConfig
    let platform: DiagnosticPlatform

    init(config: LDConfig, diagnosticId: DiagnosticId, creationDate: Int64) {
        self.id = diagnosticId
        self.creationDate = creationDate

        self.sdk = DiagnosticSdk(config: config)
        self.configuration = DiagnosticConfig(config: config)
        self.platform = DiagnosticPlatform(config: config)
    }
}

struct DiagnosticStats: DiagnosticEvent, Encodable {
    let kind = DiagnosticKind.diagnosticStats
    let id: DiagnosticId
    let creationDate: Int64

    let dataSinceDate: Int64
    let droppedEvents: Int
    let eventsInLastBatch: Int
    let streamInits: [DiagnosticStreamInit]
}

struct DiagnosticStreamInit: Codable {
    let timestamp: Int64
    let durationMillis: Int
    let failed: Bool
}

struct DiagnosticId: Codable {
    let diagnosticId: String
    let sdkKeySuffix: String

    init(diagnosticId: String, sdkKey: String) {
        self.diagnosticId = diagnosticId
        let suffixStart = sdkKey.index(sdkKey.startIndex, offsetBy: max(0, sdkKey.count - 6))
        self.sdkKeySuffix = String(sdkKey[suffixStart...])
    }
}

struct DiagnosticPlatform: Encodable {
    let name: String = "swift"
    let systemName: String
    let systemVersion: String
    let backgroundEnabled: Bool
    let streamingEnabled: Bool

    // Very general device model such as "iPad", "iPhone Simulator", or "Apple Watch"
    let deviceType: String

    init(config: LDConfig) {
        systemName = config.environmentReporter.operatingSystem.rawValue
        systemVersion = config.environmentReporter.systemVersion
        backgroundEnabled = config.environmentReporter.operatingSystem.isBackgroundEnabled
        streamingEnabled = config.environmentReporter.operatingSystem.isStreamingEnabled
        deviceType = config.environmentReporter.deviceType
    }
}

struct DiagnosticSdk: Encodable {
    let name: String = "ios-client-sdk"
    let version: String
    let wrapperName: String?
    let wrapperVersion: String?

    init(config: LDConfig) {
        version = config.environmentReporter.sdkVersion
        wrapperName = config.wrapperName
        wrapperVersion = config.wrapperVersion
    }
}

struct DiagnosticConfig: Codable {
    let autoAliasingOptOut: Bool
    let customBaseURI: Bool
    let customEventsURI: Bool
    let customStreamURI: Bool
    let eventsCapacity: Int
    let connectTimeoutMillis: Int
    let eventsFlushIntervalMillis: Int
    let streamingDisabled: Bool
    let allAttributesPrivate: Bool
    let pollingIntervalMillis: Int
    let backgroundPollingIntervalMillis: Int
    let inlineUsersInEvents: Bool
    let useReport: Bool
    let backgroundPollingDisabled: Bool
    let evaluationReasonsRequested: Bool
    let maxCachedUsers: Int
    let mobileKeyCount: Int
    let diagnosticRecordingIntervalMillis: Int
    let customHeaders: Bool

    init(config: LDConfig) {
        autoAliasingOptOut = config.autoAliasingOptOut
        customBaseURI = config.baseUrl != LDConfig.Defaults.baseUrl
        customEventsURI = config.eventsUrl != LDConfig.Defaults.eventsUrl
        customStreamURI = config.streamUrl != LDConfig.Defaults.streamUrl
        eventsCapacity = config.eventCapacity
        connectTimeoutMillis = Int(exactly: round(config.connectionTimeout * 1_000)) ?? .max
        eventsFlushIntervalMillis = Int(exactly: round(config.eventFlushInterval * 1_000)) ?? .max
        streamingDisabled = config.streamingMode == .polling
        allAttributesPrivate = config.allUserAttributesPrivate
        pollingIntervalMillis = Int(exactly: round(config.flagPollingInterval * 1_000)) ?? .max
        backgroundPollingIntervalMillis = Int(exactly: round(config.backgroundFlagPollingInterval * 1_000)) ?? .max
        inlineUsersInEvents = config.inlineUserInEvents
        useReport = config.useReport
        backgroundPollingDisabled = !config.enableBackgroundUpdates
        evaluationReasonsRequested = config.evaluationReasons
        // While the SDK treats all negative values as unlimited, for consistency we only send -1 for diagnostics
        maxCachedUsers = config.maxCachedUsers >= 0 ? config.maxCachedUsers : -1
        mobileKeyCount = 1 + (config.getSecondaryMobileKeys().count)
        diagnosticRecordingIntervalMillis = Int(exactly: round(config.diagnosticRecordingInterval * 1_000)) ?? .max
        customHeaders = !config.additionalHeaders.isEmpty || config.headerDelegate != nil
    }
}
