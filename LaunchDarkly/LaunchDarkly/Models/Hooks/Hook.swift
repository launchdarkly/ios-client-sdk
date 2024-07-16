import Foundation

/// Implementation specific hook data for evaluation stages.
///
/// Hook implementations can use this to store data needed between stages.
public typealias EvaluationSeriesData = [String: Encodable]

/// Protocol for extending SDK functionality via hooks.
public protocol Hook {
    /// Get metadata about the hook implementation.
    func metadata() -> Metadata
    /// The before method is called during the execution of a variation method before the flag value has been
    /// determined. The method is executed synchronously.
    func beforeEvaluation(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData) -> EvaluationSeriesData
    /// The after method is called during the execution of the variation method after the flag value has been
    /// determined. The method is executed synchronously.
    func afterEvaluation(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData, evaluationDetail: LDEvaluationDetail<LDValue>) -> EvaluationSeriesData
}

public extension Hook {
    /// Get metadata about the hook implementation.
    func metadata() -> Metadata {
        return Metadata(name: "UNDEFINED")
    }

    /// The before method is called during the execution of a variation method before the flag value has been
    /// determined. The method is executed synchronously.
    func beforeEvaluation(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData) -> EvaluationSeriesData {
        return seriesData
    }

    /// The after method is called during the execution of the variation method after the flag value has been
    /// determined. The method is executed synchronously.
    func afterEvaluation(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData, evaluationDetail: LDEvaluationDetail<LDValue>) -> EvaluationSeriesData {
        return seriesData
    }
}
