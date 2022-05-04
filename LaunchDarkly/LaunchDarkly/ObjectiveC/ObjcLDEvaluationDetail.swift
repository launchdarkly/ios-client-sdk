import Foundation

/// Structure that contains the evaluation result and additional information when evaluating a flag as a boolean.
@objc(LDBoolEvaluationDetail)
public final class ObjcLDBoolEvaluationDetail: NSObject {
    /// The value of the flag for the current user.
    @objc public let value: Bool
    /// The index of the returned value within the flag's list of variations, or `-1` if the default was returned.
    @objc public let variationIndex: Int
    /// A structure representing the main factor that influenced the resultant flag evaluation value.
    @objc public let reason: [String: ObjcLDValue]?
    
    internal init(value: Bool, variationIndex: Int?, reason: [String: ObjcLDValue]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}

/// Structure that contains the evaluation result and additional information when evaluating a flag as a double.
@objc(LDDoubleEvaluationDetail)
public final class ObjcLDDoubleEvaluationDetail: NSObject {
    /// The value of the flag for the current user.
    @objc public let value: Double
    /// The index of the returned value within the flag's list of variations, or `-1` if the default was returned.
    @objc public let variationIndex: Int
    /// A structure representing the main factor that influenced the resultant flag evaluation value.
    @objc public let reason: [String: ObjcLDValue]?
    
    internal init(value: Double, variationIndex: Int?, reason: [String: ObjcLDValue]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}

/// Structure that contains the evaluation result and additional information when evaluating a flag as an integer.
@objc(LDIntegerEvaluationDetail)
public final class ObjcLDIntegerEvaluationDetail: NSObject {
    /// The value of the flag for the current user.
    @objc public let value: Int
    /// The index of the returned value within the flag's list of variations, or `-1` if the default was returned.
    @objc public let variationIndex: Int
    /// A structure representing the main factor that influenced the resultant flag evaluation value.
    @objc public let reason: [String: ObjcLDValue]?
    
    internal init(value: Int, variationIndex: Int?, reason: [String: ObjcLDValue]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}

/// Structure that contains the evaluation result and additional information when evaluating a flag as a string.
@objc(LDStringEvaluationDetail)
public final class ObjcLDStringEvaluationDetail: NSObject {
    /// The value of the flag for the current user.
    @objc public let value: String?
    /// The index of the returned value within the flag's list of variations, or `-1` if the default was returned.
    @objc public let variationIndex: Int
    /// A structure representing the main factor that influenced the resultant flag evaluation value.
    @objc public let reason: [String: ObjcLDValue]?
    
    internal init(value: String?, variationIndex: Int?, reason: [String: ObjcLDValue]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}

/// Structure that contains the evaluation result and additional information when evaluating a flag as a JSON value.
@objc(LDJSONEvaluationDetail)
public final class ObjcLDJSONEvaluationDetail: NSObject {
    /// The value of the flag for the current user.
    @objc public let value: ObjcLDValue
    /// The index of the returned value within the flag's list of variations, or `-1` if the default was returned.
    @objc public let variationIndex: Int
    /// A structure representing the main factor that influenced the resultant flag evaluation value.
    @objc public let reason: [String: ObjcLDValue]?

    internal init(value: ObjcLDValue, variationIndex: Int?, reason: [String: ObjcLDValue]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}
