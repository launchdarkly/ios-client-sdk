import Vapor
import LaunchDarkly

enum CommandResponse: Content, Encodable {
    case evaluateFlag(EvaluateFlagResponse)
    case evaluateAll(EvaluateAllFlagsResponse)
    case ok

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if case let CommandResponse.evaluateFlag(response) = self {
            try container.encode(response)
            return
        }

        if case let CommandResponse.evaluateAll(response) = self {
            try container.encode(response)
            return
        }

        try container.encode(true)

        return
    }
}

struct CommandParameters: Content {
    var command: String
    var evaluate: EvaluateFlagParameters?
    var evaluateAll: EvaluateAllFlagsParameters?
    var customEvent: CustomEventParameters?
    var identifyEvent: IdentifyEventParameters?
    var aliasEvent: AliasEventParameters?
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

struct IdentifyEventParameters: Content,  Decodable {
    var user: LDUser
}

struct AliasEventParameters: Content {
    var user: LDUser
    var previousUser: LDUser
}
