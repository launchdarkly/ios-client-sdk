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

    /**
     The key identifying the result this evaluation will return, for a hook that decides what to do with an evaluation by
     whether it has seen the same result before. `DedupingHook` is such a hook.

     The key describes the flag as this evaluation reads it, which is the flag the result is derived from, so it is
     available to `beforeEvaluation` as well as to the after stage and identifies the result either stage is about to
     see.

     This is nil when the context was not built by the SDK, and so has no result to describe.
     */
    public let evaluationExposureKey: EvaluationExposureKey?

    init(flagKey: String, context: LDContext, defaultValue: LDValue, methodName: String,
         evaluationExposureKey: EvaluationExposureKey? = nil) {
        self.flagKey = flagKey
        self.context = context
        self.defaultValue = defaultValue
        self.methodName = methodName
        self.evaluationExposureKey = evaluationExposureKey
    }
}
