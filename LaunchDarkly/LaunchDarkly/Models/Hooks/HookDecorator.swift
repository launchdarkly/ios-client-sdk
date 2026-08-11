import Foundation

/**
 A hook that wraps another hook, forwarding every stage to it. Subclass this to add behavior to a hook without changing
 it, and register the wrapper in place of the hook it wraps.

 Each stage forwards to the wrapped hook, so a subclass overrides only the stages it changes. `DedupingHook` is the
 decorator the SDK ships: it forwards an evaluation series only when the flag's result is one its hook has not just been
 told about.

 ```swift
 class FlagFilteringHook: HookDecorator {
     private let flagKeys: Set<LDFlagKey>

     init(_ delegate: Hook, flagKeys: Set<LDFlagKey>) {
         self.flagKeys = flagKeys
         super.init(delegate)
     }

     override func beforeEvaluation(seriesContext: EvaluationSeriesContext,
                                    seriesData: EvaluationSeriesData) -> EvaluationSeriesData {
         guard flagKeys.contains(seriesContext.flagKey)
         else { return seriesData }
         return super.beforeEvaluation(seriesContext: seriesContext, seriesData: seriesData)
     }
 }
 ```

 Decorators stack, so a hook may be wrapped in as many as it needs, each wrapping the one inside it:

 ```swift
 config.hooks = [DedupingHook(FlagFilteringHook(ObservabilityHook(), flagKeys: myFlagKeys))]
 ```

 A decorator reports the wrapped hook's metadata as its own, so the SDK names the hook that a stage belongs to rather
 than the wrappers around it.

 A decorator that suppresses a stage must suppress the whole evaluation series, because hooks pair their stages: an
 observability hook opens a span in `beforeEvaluation` and closes it in `afterEvaluation`, so suppressing only the after
 stage leaves that span open. To carry the decision from one stage to the other, return series data the after stage
 recognizes, the way `DedupingHook` does.

 A decorator that does that belongs outermost, because the series data it returns replaces what it was given: a decorator
 outside it does not get back what it stored in its own before stage.
 */
open class HookDecorator: Hook {
    /// The hook each stage is forwarded to.
    public let delegate: Hook

    /// - parameter delegate: The hook to forward each stage to.
    public init(_ delegate: Hook) {
        self.delegate = delegate
    }

    /// Returns the wrapped hook's metadata, so that the SDK names the hook a stage belongs to.
    open func metadata() -> Metadata {
        return delegate.metadata()
    }

    /// Forwards the stage to the wrapped hook.
    open func beforeEvaluation(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData) -> EvaluationSeriesData {
        return delegate.beforeEvaluation(seriesContext: seriesContext, seriesData: seriesData)
    }

    /// Forwards the stage to the wrapped hook.
    open func afterEvaluation(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData, evaluationDetail: LDEvaluationDetail<LDValue>) -> EvaluationSeriesData {
        return delegate.afterEvaluation(seriesContext: seriesContext, seriesData: seriesData, evaluationDetail: evaluationDetail)
    }

    /// Forwards the stage to the wrapped hook.
    open func beforeIdentify(seriesContext: IdentifySeriesContext, seriesData: IdentifySeriesData) -> IdentifySeriesData {
        return delegate.beforeIdentify(seriesContext: seriesContext, seriesData: seriesData)
    }

    /// Forwards the stage to the wrapped hook.
    open func afterIdentify(seriesContext: IdentifySeriesContext, seriesData: IdentifySeriesData, result: IdentifyResult) -> IdentifySeriesData {
        return delegate.afterIdentify(seriesContext: seriesContext, seriesData: seriesData, result: result)
    }

    /// Forwards the stage to the wrapped hook.
    open func afterTrack(seriesContext: TrackSeriesContext) {
        delegate.afterTrack(seriesContext: seriesContext)
    }
}
