import Foundation
import LaunchDarkly

class TestHook: Hook {
    private let name: String
    private let callbackUrl: URL
    private let data: [String: [String: Encodable]]
    private let errors: [String: LDValue]

    init(name: String, callbackUrl: URL, data: [String: [String: Encodable]], errors: [String: LDValue]) {
        self.name = name
        self.callbackUrl = callbackUrl
        self.data = data
        self.errors = errors
    }

    func metadata() -> Metadata {
        return Metadata(name: self.name)
    }

    func beforeEvaluation(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData) -> LaunchDarkly.EvaluationSeriesData {
        return processHook(seriesContext: seriesContext, seriesData: seriesData, evaluationDetail: nil, stage: "beforeEvaluation")
    }

    func afterEvaluation(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData, evaluationDetail: LDEvaluationDetail<LDValue>) -> EvaluationSeriesData {
        return processHook(seriesContext: seriesContext, seriesData: seriesData, evaluationDetail: evaluationDetail, stage: "afterEvaluation")
    }

    private func processHook(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData, evaluationDetail: LDEvaluationDetail<LDValue>?, stage: String) -> EvaluationSeriesData {
        guard self.errors[stage] == nil else { return seriesData }

        let payload = EvaluationPayload(evaluationSeriesContext: seriesContext, evaluationSeriesData: seriesData, stage: stage, evaluationDetail: evaluationDetail)

        let data = try! JSONEncoder().encode(payload)

        var request = URLRequest(url: self.callbackUrl)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { (data, response, error) in
        }.resume()

        var updatedData = seriesData
        if let be = self.data[stage] {
            be.forEach { (key, value) in
                updatedData[key] = value
            }
        }

        return updatedData
    }
}

struct EvaluationPayload: Encodable {
    var evaluationSeriesContext: EvaluationSeriesContext
    var evaluationSeriesData: EvaluationSeriesData
    var stage: String
    var evaluationDetail: LDEvaluationDetail<LDValue>?

    init(evaluationSeriesContext: EvaluationSeriesContext, evaluationSeriesData: EvaluationSeriesData, stage: String, evaluationDetail: LDEvaluationDetail<LDValue>? = nil) {
        self.evaluationSeriesContext = evaluationSeriesContext
        self.evaluationSeriesData = evaluationSeriesData
        self.stage = stage
        self.evaluationDetail = evaluationDetail
    }

    private enum CodingKeys: String, CodingKey {
        case evaluationSeriesContext
        case evaluationSeriesData
        case stage
        case evaluationDetail
    }

    struct DynamicKey: CodingKey {
        let intValue: Int? = nil
        let stringValue: String

        init?(intValue: Int) {
            return nil
        }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }
    }


    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(evaluationSeriesContext, forKey: .evaluationSeriesContext)
        try container.encode(stage, forKey: .stage)

        try container.encodeIfPresent(evaluationDetail, forKey: .evaluationDetail)

        var nested = container.nestedContainer(keyedBy: DynamicKey.self, forKey: .evaluationSeriesData)
        try evaluationSeriesData.forEach { (key, value) in
            try evaluationSeriesData.forEach { try nested.encode($1, forKey: DynamicKey(stringValue: $0)!) }
        }
    }
}

extension EvaluationSeriesContext: Encodable {
    private enum CodingKeys: String, CodingKey {
        case flagKey
        case context
        case defaultValue
        case method
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(flagKey, forKey: .flagKey)
        try container.encode(context, forKey: .context)
        try container.encode(defaultValue, forKey: .defaultValue)
        try container.encode(methodName, forKey: .method)
    }
}

extension LDEvaluationDetail<LDValue>: Encodable {
    private enum CodingKeys: String, CodingKey {
        case value
        case variationIndex
        case reason
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(variationIndex, forKey: .variationIndex)
        try container.encode(reason, forKey: .reason)
    }
}
