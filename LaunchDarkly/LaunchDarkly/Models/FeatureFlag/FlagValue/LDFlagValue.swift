//
//  LDFlagValue.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

/// Defines the types and values of a feature flag. The SDK limits feature flags to these types by use of the `LDFlagValueConvertible` protocol, which uses this type. Client app developers should not construct an LDFlagValue.
enum LDFlagValue: Equatable {
    /// Bool flag value
    case bool(Bool)
    /// Int flag value
    case int(Int)
    /// Double flag value
    case double(Double)
    /// String flag value
    case string(String)
    /// Array flag value
    case array([LDFlagValue])
    /// Dictionary flag value
    case dictionary([LDFlagKey: LDFlagValue])
    /// Null flag value
    case null
}

// The commented out code in this file is intended to support automated typing from the json, which is not implemented in the 4.0.0 release. When that capability can be supported with later Swift versions, uncomment this code to support it.

// MARK: - Bool

// extension LDFlagValue: ExpressibleByBooleanLiteral {
//     init(_ value: Bool) {
//         self = .bool(value)
//     }
//
//     public init(booleanLiteral value: Bool) {
//         self.init(value)
//     }
// }

// MARK: - Int

// extension LDFlagValue: ExpressibleByIntegerLiteral {
//     public init(_ value: Int) {
//         self = .int(value)
//     }
//
//     public init(integerLiteral value: Int) {
//         self.init(value)
//     }
// }

// MARK: - Double

// extension LDFlagValue: ExpressibleByFloatLiteral {
//     public init(_ value: FloatLiteralType) {
//         self = .double(value)
//     }
//
//     public init(floatLiteral value: FloatLiteralType) {
//         self.init(value)
//     }
// }

// MARK: - String

// extension LDFlagValue: ExpressibleByStringLiteral {
//     public init(_ value: StringLiteralType) {
//         self = .string(value)
//     }
//
//     public init(unicodeScalarLiteral value: StringLiteralType) {
//         self.init(value)
//     }
//
//     public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
//         self.init(value)
//     }
//
//     public init(stringLiteral value: StringLiteralType) {
//         self.init(value)
//     }
// }

// MARK: - Array

// extension LDFlagValue: ExpressibleByArrayLiteral {
//     public init<Collection: Swift.Collection>(_ collection: Collection) where Collection.Iterator.Element == LDFlagValue {
//         self = .array(Array(collection))
//     }
//
//     public init(arrayLiteral elements: LDFlagValue...) {
//         self.init(elements)
//     }
// }

extension LDFlagValue {
    var flagValueArray: [LDFlagValue]? {
        guard case let .array(array) = self
        else { return nil }
        return array
    }
}

// MARK: - Dictionary

// extension LDFlagValue: ExpressibleByDictionaryLiteral {
//     public typealias Key = LDFlagKey
//     public typealias Value = LDFlagValue
//
//     public init<Dictionary: Sequence>(_ keyValuePairs: Dictionary) where Dictionary.Iterator.Element == (Key, Value) {
//         var dictionary = [Key: Value]()
//         for (key, value) in keyValuePairs {
//             dictionary[key] = value
//         }
//         self.init(dictionary)
//     }
//
//     public init(dictionaryLiteral elements: (Key, Value)...) {
//         self.init(elements)
//     }
//
//     public init(_ dictionary: Dictionary<Key, Value>) {
//         self = .dictionary(dictionary)
//     }
// }

extension LDFlagValue {
    var flagValueDictionary: [LDFlagKey: LDFlagValue]? {
        guard case let .dictionary(value) = self
        else { return nil }
        return value
    }
}
