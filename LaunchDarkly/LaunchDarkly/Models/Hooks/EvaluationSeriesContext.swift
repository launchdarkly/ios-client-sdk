import Foundation

/// Contextual information that will be provided to handlers during evaluation series.
public class EvaluationSeriesContext {
    private let flagKey: String
    private let context: LDContext
    private let defaultValue: LDValue
    private let methodName: String

    init(flagKey: String, context: LDContext, defaultValue: LDValue, methodName: String) {
        self.flagKey = flagKey
        self.context = context
        self.defaultValue = defaultValue
        self.methodName = methodName
    }
}
