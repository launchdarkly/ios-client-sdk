import Foundation

/**
 Used to represent the type of an `LDValue`.
 */
@objc(LDValueType)
public enum ObjcLDValueType: Int {
    /// The value returned by `LDValue.getType()` when the represented value is a null.
    case null
    /// The value returned by `LDValue.getType()` when the represented value is a boolean.
    case bool
    /// The value returned by `LDValue.getType()` when the represented value is a number.
    case number
    /// The value returned by `LDValue.getType()` when the represented value is a string.
    case string
    /// The value returned by `LDValue.getType()` when the represented value is an array.
    case array
    /// The value returned by `LDValue.getType()` when the represented value is an object.
    case object
}

/**
 Bridged `LDValue` type for Objective-C.

 Can create instances from Objective-C with the provided `of` static functions, for example `[LDValue ofBool:YES]`.
 */
@objc(LDValue)
public final class ObjcLDValue: NSObject {
    /// The Swift `LDValue` enum the instance is wrapping.
    public let wrappedValue: LDValue

    /**
     Create a instance of the bridging object for the given value.

     - parameter wrappedValue: The value to wrap.
     */
    public init(wrappedValue: LDValue) {
        self.wrappedValue = wrappedValue
    }

    /// Create a new `LDValue` that represents a JSON null.
    @objc public static func ofNull() -> ObjcLDValue {
        return ObjcLDValue(wrappedValue: .null)
    }

    /// Create a new `LDValue` from a boolean value.
    @objc public static func of(bool: Bool) -> ObjcLDValue {
        return ObjcLDValue(wrappedValue: .bool(bool))
    }

    /// Create a new `LDValue` from a numeric value.
    @objc public static func of(number: NSNumber) -> ObjcLDValue {
        return ObjcLDValue(wrappedValue: .number(number.doubleValue))
    }

    /// Create a new `LDValue` from a string value.
    @objc public static func of(string: String) -> ObjcLDValue {
        return ObjcLDValue(wrappedValue: .string(string))
    }

    /// Create a new `LDValue` from an array of values.
    @objc public static func of(array: [ObjcLDValue]) -> ObjcLDValue {
        return ObjcLDValue(wrappedValue: .array(array.map { $0.wrappedValue }))
    }

    /// Create a new `LDValue` object from dictionary of values.
    @objc public static func of(dict: [String: ObjcLDValue]) -> ObjcLDValue {
        return ObjcLDValue(wrappedValue: .object(dict.mapValues { $0.wrappedValue }))
    }

    /// Get the type of the value.
    @objc public func getType() -> ObjcLDValueType {
        switch wrappedValue {
        case .null: return .null
        case .bool: return .bool
        case .number: return .number
        case .string: return .string
        case .array: return .array
        case .object: return .object
        }
    }

    /**
     Get the value as a `Bool`.

     - returns: The contained boolean value or `NO` if the value is not a boolean.
     */
    @objc public func boolValue() -> Bool {
        guard case let .bool(value) = wrappedValue
        else { return false }
        return value
    }

    /**
     Get the value as a `Double`.

     - returns: The contained double value or `0.0` if the value is not a number.
     */
    @objc public func doubleValue() -> Double {
        guard case let .number(value) = wrappedValue
        else { return 0.0 }
        return value
    }

    /**
     Get the value as a `String`.

     - returns: The contained string value or the empty string if the value is not a string.
     */
    @objc public func stringValue() -> String {
        guard case let .string(value) = wrappedValue
        else { return "" }
        return value
    }

    /**
     Get the value as an array.

     - returns: An array of the contained values, or the empty array if the value is not an array.
     */
    @objc public func arrayValue() -> [ObjcLDValue] {
        guard case let .array(values) = wrappedValue
        else { return [] }
        return values.map { ObjcLDValue(wrappedValue: $0) }
    }

    /**
     Get the value as a dictionary representing the JSON object

     - returns: A dictionary representing the JSON object, or the empty dictionary if the value is not a dictionary.
     */
    @objc public func dictValue() -> [String: ObjcLDValue] {
        guard case let .object(values) = wrappedValue
        else { return [:] }
        return values.mapValues { ObjcLDValue(wrappedValue: $0) }
    }
}
