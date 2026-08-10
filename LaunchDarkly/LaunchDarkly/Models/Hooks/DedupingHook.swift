import Foundation

/**
 Wraps a hook so that repeated evaluations resolving to the same result do not reach it again within a time window.

 The wrapped hook is told about a flag when its result changes, and at most once per window while the result stays the
 same. This is useful for reducing the telemetry volume produced by frequent re-evaluations, for example a flag that is
 read on every redraw of a view. Deduplication is opt-in: a hook that is registered unwrapped observes every evaluation.

 ```swift
 config.hooks = [
     MetricsHook(),                                     // observes every evaluation
     DedupingHook(ObservabilityHook()),                  // default window
     DedupingHook(TelemetryHook(), window: 60),
     DedupingHook(ExperimentHook(), deduper: myCustomDeduper)
 ]
 ```

 Two evaluations resolve to the same result when they agree on everything `EvaluationExposureKey` describes. Pass your own
 `EvaluationExposureDeduper` subclass to decide that differently.

 A suppressed evaluation reaches neither `beforeEvaluation` nor `afterEvaluation`, because hooks pair their stages. The
 identify and track stages are always forwarded. Analytics events are unaffected: feature, debug, and summary events are
 still recorded for every evaluation, so the evaluation counts LaunchDarkly reports for your flags do not change.

 What the wrapped hook has been told about is cleared by `LDClient.identify(context:)`, so the first evaluation of each
 flag after an identify always reaches it.

 Give each hook its own instance unless you intend hooks to share a window: the first hook to be told about an evaluation
 starts the window that suppresses the rest.
 */
public final class DedupingHook: HookDecorator {
    // Namespaced because it travels in series data that the wrapped hook may also write to.
    private static let suppressedKey = "com.launchdarkly.DedupingHook.suppressed"

    private let deduper: EvaluationExposureDeduper

    /**
     - parameter delegate: The hook to wrap.
     - parameter window: The dedupe window, in seconds. Defaults to `EvaluationExposureDeduper.defaultWindow`. A value of
     zero or less forwards every evaluation.
     */
    public init(_ delegate: Hook, window: TimeInterval = EvaluationExposureDeduper.defaultWindow) {
        self.deduper = EvaluationExposureDeduper(window: window)
        super.init(delegate)
    }

    /**
     - parameter delegate: The hook to wrap.
     - parameter deduper: Decides which evaluations reach the wrapped hook.
     */
    public init(_ delegate: Hook, deduper: EvaluationExposureDeduper) {
        self.deduper = deduper
        super.init(delegate)
    }

    /**
     Forwards the evaluation unless the wrapped hook has just been told about the same result.

     The decision is made here, before the evaluation runs, so that a suppressed evaluation reaches neither stage of the
     wrapped hook. An evaluation whose result the SDK did not describe, which is to say a series context built by
     something other than the SDK, is always forwarded.
     */
    override public func beforeEvaluation(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData) -> EvaluationSeriesData {
        if let key = seriesContext.evaluationExposureKey, !deduper.shouldRecord(key: key) {
            // Recognized by identity below, so that stacked instances each recognize only their own suppressions.
            return [DedupingHook.suppressedKey: self]
        }
        return super.beforeEvaluation(seriesContext: seriesContext, seriesData: seriesData)
    }

    /// Forwards the result unless this instance suppressed the series in its before stage.
    override public func afterEvaluation(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData, evaluationDetail: LDEvaluationDetail<LDValue>) -> EvaluationSeriesData {
        if let marker = seriesData[DedupingHook.suppressedKey], marker as AnyObject === self {
            return seriesData
        }
        return super.afterEvaluation(seriesContext: seriesContext, seriesData: seriesData, evaluationDetail: evaluationDetail)
    }

    /**
     Forgets which results the wrapped hook has been told about, then forwards the stage.

     Evaluations observed before an identify describe an earlier point in the application's lifecycle, so they are
     reported again afterwards. This happens even when the context is unchanged, so that identify is a reliable way for an
     application to mark a new phase of a session.
     */
    override public func beforeIdentify(seriesContext: IdentifySeriesContext, seriesData: IdentifySeriesData) -> IdentifySeriesData {
        deduper.reset()
        return super.beforeIdentify(seriesContext: seriesContext, seriesData: seriesData)
    }
}
