import Vapor
import LaunchDarkly

enum CommandResponse: Content, Encodable {
    case evaluateFlag(EvaluateFlagResponse)
    case evaluateAll(EvaluateAllFlagsResponse)
    case contextBuild(ContextBuildResponse)
    case contextConvert(ContextBuildResponse)
    case contextComparison(ContextComparisonResponse)
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
        case .contextComparison(let response):
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
    var contextComparison: ContextComparisonPairParameters?
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
    var context: LDContext?
    var user: LDUser?
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
    var privateAttribute: [String]?
    var custom: [String: LDValue]?

    private enum CodingKeys: String, CodingKey {
        case kind, key, name, anonymous, privateAttribute = "private", custom
    }
}

struct ContextBuildResponse: Content, Encodable {
    var output: String?
    var error: String?
}

struct ContextConvertParameters: Content, Decodable {
    var input: String
}

struct ContextComparisonPairParameters: Content, Decodable {
    var context1: ContextComparisonParameters
    var context2: ContextComparisonParameters
}

struct ContextComparisonParameters: Content, Decodable {
    var single: ContextComparisonSingleParams?
    var multi: [ContextComparisonSingleParams]?
}

struct ContextComparisonSingleParams: Content, Decodable {
    var kind: String
    var key: String
    var attributes: [AttributeDefinition]?
    var privateAttributes: [PrivateAttribute]?
}

struct AttributeDefinition: Content, Decodable {
    var name: String
    var value: LDValue
}

struct PrivateAttribute: Content, Decodable {
    var value: String
    var literal: Bool
}

struct ContextComparisonResponse: Content, Encodable {
    var equals: Bool
}
