import Foundation

/// Implementation specific hook data for evaluation stages.
///
/// Hook implementations can use this to store data needed between stages.
public typealias EvaluationSeriesData = [String: Any]

/// Implementation specific hook data for identify stages.
///
/// Hook implementations can use this to store data needed between stages.
public typealias IdentifySeriesData = [String: Any]

/// Protocol for extending SDK functionality via hooks.
public protocol Hook {
    /// Get metadata about the hook implementation.
    func metadata() -> Metadata

    /// Executed by the SDK at the start of the evaluation of a feature flag.
    ///
    /// This is not executed as part of a call to `LDClient.allFlags()`.
    ///
    /// To provide custom data to the series which will be given back to your Hook at the next stage of the
    /// series, return a dictionary containing the custom data. You should initialize this dictionary from the
    /// `seriesData`.
    ///
    /// - Parameters:
    ///   - seriesContext: Container of parameters associated with this evaluation.
    ///   - seriesData: Immutable data from the previous stage in the evaluation series.
    ///                 `beforeEvaluation` is the first stage in this series, so this will be an empty dictionary.
    /// - Returns: A dictionary containing custom data that will be carried through to the next stage of the series.
    func beforeEvaluation(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData) -> EvaluationSeriesData

    /// Executed by the SDK after the evaluation of a feature flag completes.
    ///
    /// This is not executed as part of a call to `LDClient.allFlags()`.
    ///
    /// This is currently the last stage of the evaluation series in the Hook, but that may not be the case in the
    /// future. To ensure forward compatibility, return the `seriesData` unmodified.
    ///
    /// - Parameters:
    ///   - seriesContext: Container of parameters associated with this evaluation.
    ///   - seriesData: Immutable data from the previous stage in the evaluation series.
    ///   - evaluationDetail: The result of the evaluation that took place before this hook was invoked.
    /// - Returns: A dictionary containing custom data that will be carried through to the next stage of the series (if added in the future).
    func afterEvaluation(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData, evaluationDetail: LDEvaluationDetail<LDValue>) -> EvaluationSeriesData

    /// To provide custom data to the series which will be given back to your Hook at the next stage of the series,
    /// return a dictionary containing the custom data. You should initialize this dictionary from the `seriesData`.
    ///
    /// - Parameters:
    ///   - seriesContext: Contains information about the identify operation being performed. This is not mutable.
    ///   - seriesData: A record associated with each stage of hook invocations. Each stage is called with the data of the previous stage for a series. The input record should not be modified.
    /// - Returns: A dictionary containing custom data that will be carried through to the next stage of the series.
    func beforeIdentify(seriesContext: IdentifySeriesContext, seriesData: IdentifySeriesData) -> IdentifySeriesData

    /// Called during the execution of the identify process, after the operation completes.
    ///
    /// This is currently the last stage of the identify series in the Hook, but that may not be the case in the future.
    /// To ensure forward compatibility, return the `seriesData` unmodified.
    ///
    /// - Parameters:
    ///   - seriesContext: Contains information about the identify operation being performed. This is not mutable.
    ///   - seriesData: A record associated with each stage of hook invocations. Each stage is called with the data of the previous stage for a series. The input record should not be modified.
    ///   - result: The result of the identify operation.
    /// - Returns: A dictionary containing custom data that will be carried through to the next stage of the series (if added in the future).
    func afterIdentify(seriesContext: IdentifySeriesContext, seriesData: IdentifySeriesData, result: IdentifyResult) -> IdentifySeriesData

    /// Executed by the SDK during the execution of the track process, after the event has been enqueued.
    ///
    /// - Parameters:
    ///   - seriesContext: Contains information about the track operation being performed. This is not mutable.
    func afterTrack(seriesContext: TrackSeriesContext)
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

    /// Called during the execution of the identify process before the operation completes,
    /// but after any context modifications are performed.
    ///
    /// Default implementation is a no-op that returns `seriesData` unchanged.
    func beforeIdentify(seriesContext: IdentifySeriesContext, seriesData: IdentifySeriesData) -> IdentifySeriesData {
        return seriesData
    }

    /// Called during the execution of the identify process, after the operation completes.
    ///
    /// Default implementation is a no-op that returns `seriesData` unchanged.
    func afterIdentify(seriesContext: IdentifySeriesContext, seriesData: IdentifySeriesData, result: IdentifyResult) -> IdentifySeriesData {
        return seriesData
    }

    /// Called during the execution of the track process, after the event has been enqueued.
    ///
    /// Default implementation is a no-op.
    func afterTrack(seriesContext: TrackSeriesContext) {
    }
}
