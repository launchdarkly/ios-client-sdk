import Foundation

/// Resolves what the result of an evaluation identifies. Implemented by the client, which is what holds the flags.
///
/// The whole evaluation is the parameter, rather than the parts of it a key is built from today, so that a component
/// added to `EvaluationExposureKey` later does not change this signature.
protocol EvaluationExposureKeyResolving: AnyObject {
    func exposureKey(seriesContext: EvaluationSeriesContext) -> EvaluationExposureKey
}

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

    // Weak so that a hook holding on to a series context cannot keep a client alive. A client that has gone leaves the
    // evaluation with no result to describe, which is the same as not having been asked by the SDK at all.
    private weak var exposureKeyResolver: EvaluationExposureKeyResolving?
    private var resolvedExposureKey: EvaluationExposureKey?
    private let exposureKeyLock = NSLock()

    init(flagKey: String, context: LDContext, defaultValue: LDValue, methodName: String,
         exposureKeyResolver: EvaluationExposureKeyResolving? = nil) {
        self.flagKey = flagKey
        self.context = context
        self.defaultValue = defaultValue
        self.methodName = methodName
        self.exposureKeyResolver = exposureKeyResolver
    }

    /**
     The key identifying the result this evaluation will return, for a hook that decides what to do with an evaluation by
     whether it has seen the same result before. `DedupingHook` is such a hook.

     The key describes the result as the SDK has it stored, which is what the evaluation is about to return, so it is
     available to `beforeEvaluation` as well as to the after stage. It is resolved on the first ask, so an evaluation
     costs a flag lookup only when a hook wants one, and every hook in an evaluation is told about the same result even
     if the store changes while the evaluation is in progress.

     This is nil when the context was not built by the SDK, and so has no result to describe.
     */
    public var evaluationExposureKey: EvaluationExposureKey? {
        guard let resolver = exposureKeyResolver else {
            return nil
        }
        exposureKeyLock.lock()
        defer { exposureKeyLock.unlock() }
        if resolvedExposureKey == nil {
            resolvedExposureKey = resolver.exposureKey(seriesContext: self)
        }
        return resolvedExposureKey
    }
}
