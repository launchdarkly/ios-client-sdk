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
/// A closure used to notify an observer owner that an error occurred during feature flag processing.
public typealias LDErrorHandler = (Error) -> Void

extension LDFlagKey {
    private static var anyKeyIdentifier: LDFlagKey { "Darkly.FlagKeyList.Any" }
    static var anyKey: [LDFlagKey] { [anyKeyIdentifier] }
}

@objc public class LDInvalidArgumentError: NSObject, Error {
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

    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([LDValue])
    case object([String: LDValue])

    public init(nilLiteral: ()) {
        self = .null
    }

    public init(booleanLiteral: Bool) {
        self = .bool(booleanLiteral)
    }

    public init(integerLiteral: Double) {
        self = .number(integerLiteral)
    }

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

    func booleanValue() -> Bool {
        if case .bool(let val) = self { return val }
        return false
    }

    func intValue() -> Int {
        if case .number(let val) = self {
            // TODO check
            return Int.init(val)
        }
        return 0
    }

    func doubleValue() -> Double {
        if case .number(let val) = self { return val }
        return 0
    }

    func stringValue() -> String {
        if case .string(let val) = self { return val }
        return ""
    }

    func toAny() -> Any? {
        switch self {
        case .null: return nil
        case .bool(let boolValue): return boolValue
        case .number(let doubleValue): return doubleValue
        case .string(let stringValue): return stringValue
        case .array(let arrayValue): return arrayValue.map { $0.toAny() }
        case .object(let dictValue): return dictValue.mapValues { $0.toAny() }
        }
    }

    static func fromAny(_ value: Any?) -> LDValue {
        guard let value = value, !(value is NSNull)
        else { return .null }
        if let boolValue = value as? Bool { return .bool(boolValue) }
        if let numValue = value as? NSNumber { return .number(Double(truncating: numValue)) }
        if let stringValue = value as? String { return .string(stringValue) }
        if let arrayValue = value as? [Any?] { return .array(arrayValue.map { LDValue.fromAny($0) }) }
        if let dictValue = value as? [String: Any?] { return .object(dictValue.mapValues { LDValue.fromAny($0) }) }
        return .null
    }
}
