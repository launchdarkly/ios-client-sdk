import Foundation

/// Contextual information that will be provided to handlers during identify series.
public class IdentifySeriesContext {
    /// The context involved in the identify operation.
    public let context: LDContext
    /// A string identifying the name of the method called.
    public let methodName: String

    public init(context: LDContext, methodName: String) {
        self.context = context
        self.methodName = methodName
    }
}
