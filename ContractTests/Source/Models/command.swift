import Vapor
import LaunchDarkly

enum CommandResponse: Content, Encodable {
    case evaluateFlag(EvaluateFlagResponse)
    case evaluateAll(EvaluateAllFlagsResponse)
    case contextBuild(ContextBuildResponse)
    case contextConvert(ContextBuildResponse)
    case ok

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .evaluateFlag(let response):
            try container.encode(response)
            return
        case .evaluateAll(let response):
            try container.encode(response)
            return
        case .contextBuild(let response):
            try container.encode(response)
            return
        case .contextConvert(let response):
            try container.encode(response)
            return
        case .ok:
            try container.encode(true)
            return
        }
    }
}

struct CommandParameters: Content {
    var command: String
    var evaluate: EvaluateFlagParameters?
    var evaluateAll: EvaluateAllFlagsParameters?
    var customEvent: CustomEventParameters?
    var identifyEvent: IdentifyEventParameters?
    var contextBuild: ContextBuildParameters?
    var contextConvert: ContextConvertParameters?
}

struct EvaluateFlagParameters: Content {
     var flagKey: String
     var valueType: String
     var defaultValue: LDValue
     var detail: Bool
}

struct EvaluateFlagResponse: Content {
    var value: LDValue
    var variationIndex: Int?
    var reason: [String: LDValue]?
}

struct EvaluateAllFlagsParameters: Content {
    // TODO(mmk) Add support for withReasons, clientSideOnly, and detailsOnlyForTrackedFlags
}

struct EvaluateAllFlagsResponse: Content {
    var state: [LDFlagKey: LDValue]?
}

struct CustomEventParameters: Content {
    var eventKey: String
    var data: LDValue?
    var omitNullData: Bool
    var metricValue: Double?
}

struct IdentifyEventParameters: Content, Decodable {
    var context: LDContext
}

struct ContextBuildParameters: Content, Decodable {
    var single: SingleContextParameters?
    var multi: [SingleContextParameters]?
}

struct SingleContextParameters: Content, Decodable {
    var kind: String?
    var key: String
    var name: String?
    var anonymous: Bool?
    var secondary: String?
    var privateAttribute: [String]?
    var custom: [String:LDValue]?

    private enum CodingKeys: String, CodingKey {
        case kind, key, name, anonymous, secondary, privateAttribute = "private", custom
    }
}

struct ContextBuildResponse: Content, Encodable {
    var output: String?
    var error: String?
}

struct ContextConvertParameters: Content, Decodable {
    var input: String
}
