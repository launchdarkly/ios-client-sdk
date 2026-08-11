import Foundation

/// Contextual information that will be provided to handlers during evaluation series.
public class EvaluationSeriesContext {
    /// The key of the flag being evaluated.
    public let flagKey: String
    /// The context in effect at the time of evaluation.
    public let context: LDContext
    /// The default value provided to the calling evaluation method.
    public let defaultValue: LDValue
    /// A string identifing the name of the method called.
    public let methodName: String

    // The evaluation's own read of the flag, rather than the key describing it, so that an evaluation reaching only
    // hooks that never ask what its result is builds nothing to describe it. A nil environment is what says this
    // context was built by something other than the SDK, and so has no result to describe at all.
    private let environmentName: String?
    private let featureFlag: FeatureFlag?

    init(flagKey: String, context: LDContext, defaultValue: LDValue, methodName: String,
         environmentName: String? = nil, featureFlag: FeatureFlag? = nil) {
        self.flagKey = flagKey
        self.context = context
        self.defaultValue = defaultValue
        self.methodName = methodName
        self.environmentName = environmentName
        self.featureFlag = featureFlag
    }

    /**
     The key identifying the result this evaluation will return, for a hook that decides what to do with an evaluation by
     whether it has seen the same result before. `DedupingHook` is such a hook.

     This describes the flag rather than the evaluation result because a deduping hook decides before the series opens:
     hooks pair their stages, so a hook that opens a span in `beforeEvaluation` and closes it in `afterEvaluation` would
     be left holding an open span were only the after stage suppressed. It is the evaluation's own read of the flag, the
     one its result is derived from, so it identifies the result either stage is about to see, and every hook that asks
     is told about that same result.

     See `EvaluationExposureKey` for what makes two evaluations the same exposure.

     This is nil when the context was not built by the SDK, and so has no result to describe.
     */
    public var evaluationExposureKey: EvaluationExposureKey? {
        guard let environmentName = environmentName else {
            return nil
        }

        return EvaluationExposureKey(
            environmentName: environmentName,
            flagKey: flagKey,
            variation: featureFlag?.variation,
            flagVersion: featureFlag?.versionForEvents,
            inExperiment: featureFlag?.isInExperiment ?? false,
            fullyQualifiedContextKey: context.fullyQualifiedKey()
        )
    }
}
