import Foundation

/// The feature flag key is a String. This typealias helps define where the SDK expects the string to be a feature flag key.
public typealias LDFlagKey = String

/// An object can own an observer for as long as the object exists. Swift structs and enums cannot be observer owners.
public typealias LDObserverOwner = AnyObject
/// A closure used to notify an observer owner of a change to a single feature flag's value.
public typealias LDFlagChangeHandler = (LDChangedFlag) -> Void
/// A closure used to notify an observer owner of a change to the feature flags in a collection of `LDChangedFlag`.
public typealias LDFlagCollectionChangeHandler = ([LDFlagKey: LDChangedFlag]) -> Void
/// A closure used to notify an observer owner that a feature flag request resulted in no changes to any feature flag.
public typealias LDFlagsUnchangedHandler = () -> Void
/// A closure used to notify an observer owner that the current connection mode has changed.
public typealias LDConnectionModeChangedHandler = (ConnectionInformation.ConnectionMode) -> Void

extension LDFlagKey {
    private static var anyKeyIdentifier: LDFlagKey { "Darkly.FlagKeyList.Any" }
    static var anyKey: [LDFlagKey] { [anyKeyIdentifier] }
}

/// An error thrown from APIs when an invalid argument is provided.
@objc public class LDInvalidArgumentError: NSObject, Error {
    /// A description of the error.
    public let localizedDescription: String

    init(_ description: String) {
        self.localizedDescription = description
    }
}

struct DynamicKey: CodingKey {
    let intValue: Int? = nil
    let stringValue: String

    init?(intValue: Int) {
        return nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }
}

/**
 An immutable instance of any data type that is allowed in JSON.

 An `LDValue` can be a null (that is, an instance that represents a JSON null value), a boolean, a number (always
 encoded internally as double-precision floating-point), a string, an ordered list of `LDValue` values (a JSON array),
 or a map of strings to `LDValue` values (a JSON object).

 This can be used to represent complex data in a context attribute, or to get a feature flag value that uses a
 complex type or does not always use the same type.
 */
public enum LDValue: Codable,
                     Equatable,
                     ExpressibleByNilLiteral,
                     ExpressibleByBooleanLiteral,
                     ExpressibleByIntegerLiteral,
                     ExpressibleByFloatLiteral,
                     ExpressibleByStringLiteral,
                     ExpressibleByArrayLiteral,
                     ExpressibleByDictionaryLiteral {

    public typealias StringLiteralType = String

    public typealias ArrayLiteralElement = LDValue

    public typealias Key = String
    public typealias Value = LDValue

    public typealias IntegerLiteralType = Double
    public typealias FloatLiteralType = Double

    /// Represents a JSON null value.
    case null
    /// Represents a JSON boolean value.
    case bool(Bool)
    /// Represents a JSON number value.
    case number(Double)
    /// Represents a JSON string value.
    case string(String)
    /// Represents an array of JSON values.
    case array([LDValue])
    /// Represents a JSON object.
    case object([String: LDValue])

    public init(nilLiteral: ()) {
        self = .null
    }

    public init(booleanLiteral: Bool) {
        self = .bool(booleanLiteral)
    }

    /// Create an LDValue representation from the provided Double value.
    ///
    /// This method DOES NOT truncate the provided Double. As JSON numeric
    /// values are always treated as double-precision, this method will
    /// store the given Double as it.
    @available(*, deprecated, message: "Use LDValue.init(integerLiteral: Int) or LDValue.init(floatLiteral: Double)")
    public init(integerLiteral: Double) {
        self = .number(integerLiteral)
    }

    /// Create an LDValue representation from the provided Int.
    ///
    /// All JSON numeric types are represented as double-precision so the
    /// provided Int will be cast to a Double.
    public init(integerLiteral: Int) {
        self = .number(Double(integerLiteral))
    }

    /// Create an LDValue representation from the provided Double.
    public init(floatLiteral: Double) {
        self = .number(floatLiteral)
    }

    public init(stringLiteral: String) {
        self = .string(stringLiteral)
    }

    public init(arrayLiteral: LDValue...) {
        self = .array(arrayLiteral)
    }

    public init(dictionaryLiteral: (String, LDValue)...) {
        self = .object(dictionaryLiteral.reduce(into: [:]) { $0[$1.0] = $1.1 })
    }

    public init(from decoder: Decoder) throws {
        if var array = try? decoder.unkeyedContainer() {
            var valueArr: [LDValue] = []
            while !array.isAtEnd {
                valueArr.append(try array.decode(LDValue.self))
            }
            self = .array(valueArr)
        } else if let dict = try? decoder.container(keyedBy: DynamicKey.self) {
            var valueDict: [String: LDValue] = [:]
            let keys = dict.allKeys
            for key in keys {
                valueDict[key.stringValue] = try dict.decode(LDValue.self, forKey: key)
            }
            self = .object(valueDict)
        } else {
            let single = try decoder.singleValueContainer()
            if let str = try? single.decode(String.self) {
                self = .string(str)
            } else if let num = try? single.decode(Double.self) {
                self = .number(num)
            } else if let bool = try? single.decode(Bool.self) {
                self = .bool(bool)
            } else if single.decodeNil() {
                self = .null
            } else {
                throw DecodingError.dataCorruptedError(in: single, debugDescription: "Unexpected type when decoding LDValue")
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var sve = encoder.singleValueContainer()
            try sve.encodeNil()
        case .bool(let boolValue):
            var sve = encoder.singleValueContainer()
            try sve.encode(boolValue)
        case .number(let doubleValue):
            var sve = encoder.singleValueContainer()
            try sve.encode(doubleValue)
        case .string(let stringValue):
            var sve = encoder.singleValueContainer()
            try sve.encode(stringValue)
        case .array(let arrayValue):
            var unkeyedEncoder = encoder.unkeyedContainer()
            try arrayValue.forEach { try unkeyedEncoder.encode($0) }
        case .object(let dictValue):
            var keyedEncoder = encoder.container(keyedBy: DynamicKey.self)
            try dictValue.forEach { try keyedEncoder.encode($1, forKey: DynamicKey(stringValue: $0)!) }
        }
    }
}
