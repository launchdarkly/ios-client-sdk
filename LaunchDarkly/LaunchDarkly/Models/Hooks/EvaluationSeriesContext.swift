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

    init(flagKey: String, context: LDContext, defaultValue: LDValue, methodName: String) {
        self.flagKey = flagKey
        self.context = context
        self.defaultValue = defaultValue
        self.methodName = methodName
    }
}
