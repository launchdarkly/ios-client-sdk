import Vapor
import LaunchDarkly

struct CreateInstance: Content {
    var tag: String?
    var configuration: Configuration
}

struct Configuration: Content {
    var credential: String
    var startWaitTimeMs: Double?
    var initCanFail: Bool?
    // TODO(mmk) Add serviceEndpoints
    var streaming: StreamingParameters?
    var polling: PollingParameters?
    var events: EventParameters?
    var tags: TagParameters?
    var clientSide: ClientSideParameters
    var hooks: HookParameters?
}

struct StreamingParameters: Content {
    var baseUri: String?
    var initialRetryDelayMs: Int?
}

struct PollingParameters: Content {
    var baseUri: String?
    // TODO(mmk) Add pollIntervalMs
}

struct EventParameters: Content {
    var baseUri: String?
    var capacity: Int?
    var enableDiagnostics: Bool?
    var allAttributesPrivate: Bool?
    var globalPrivateAttributes: [String]?
    var flushIntervalMs: Double?
}

struct TagParameters: Content {
    var applicationId: String?
    var applicationName: String?
    var applicationVersion: String?
    var applicationVersionName: String?
}

struct ClientSideParameters: Content {
    var initialContext: LDContext
    var evaluationReasons: Bool?
    var useReport: Bool?
    var includeEnvironmentAttributes: Bool?
}

struct HookParameters: Content {
    var hooks: [HookParameter]
}

struct HookParameter: Content {
    var name: String
    var callbackUri: String
    var data: [String: [String: LDValue]]?
    var errors: [String: LDValue]?
}
