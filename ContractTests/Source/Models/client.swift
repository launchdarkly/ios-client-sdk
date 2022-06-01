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
    var applicationVersion: String?
}

struct ClientSideParameters: Content {
    // TODO(mmk) Remove this user when you have converted everything
    var initialUser: LDUser?
    var initialContext: LDContext?
    var evaluationReasons: Bool?
    var useReport: Bool?
}
