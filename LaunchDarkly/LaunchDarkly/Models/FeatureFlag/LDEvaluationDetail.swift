import Foundation

/**
 An object returned by the SDK's `variationDetail` methods, combining the result of a flag evaluation with an
 explanation of how it is calculated.
 */
public final class LDEvaluationDetail<T> {
    /// The value of the flag for the current context.
    public let value: T
    /// The index of the returned value within the flag's list of variations, or `nil` if the default was returned.
    public let variationIndex: Int?
    /// A structure representing the main factor that influenced the resultant flag evaluation value.
    public let reason: [String: LDValue]?

    internal init(value: T, variationIndex: Int?, reason: [String: LDValue]?) {
        self.value = value
        self.variationIndex = variationIndex
        self.reason = reason
    }

    /// Apply the `transform` function to the detail's inner value property, converting an
    /// `LDEvaluationDetail<T>` to an `LDEvaluationDetail<U>`.
    public func map<U>(transform: ((_: T) -> U)) -> LDEvaluationDetail<U> {
        return LDEvaluationDetail<U>(
            value: transform(self.value),
            variationIndex: self.variationIndex,
            reason: self.reason)
    }
}
