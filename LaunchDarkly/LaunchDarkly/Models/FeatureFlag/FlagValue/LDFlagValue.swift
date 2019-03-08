//
//  LDFlagValue.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 9/5/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

///Defines the sources for feature flag values.
///See also: `LDClient.variationAndSource(forKey:fallback:)` and `LDChangedFlag`
public enum LDFlagValueSource: CaseIterable {
    ///Feature flag comes from the server, either the `clientstream` or a feature flag request
    case server
    ///Feature flag comes from the cache. Cached feature flags are used on app launch until the SDK gets the first feature flag update
    case cache
    ///Feature flag comes from the client provided fallback. The SDK will serve fallback values when the flag key is not found, or when the SDK cannot convert the feature flag to the client provided type. Since the client provides this value in the `LDClient.variationAndSource(forKey:fallback:)`, an LDChangedFlag will not contain a `fallback` valueSource
    case fallback
}

///Defines the types and values of a feature flag. The SDK limits feature flags to these types by use of the `LDFlagValueConvertible` protocol, which uses this type. Client app developers should not construct an LDFlagValue.
public enum LDFlagValue {
    ///Bool flag value
    case bool(Bool)
    ///Int flag value
    case int(Int)
    ///Double flag value
    case double(Double)
    ///String flag value
    case string(String)
    ///Array flag value
    case array([LDFlagValue])
    ///Dictionary flag value
    case dictionary([LDFlagKey: LDFlagValue])
    ///Null flag value
    case null

    ///An NSObject wrapper for the Swift LDFlagValue enum. Intended for use in mixed apps when Swift code needs to pass a LDFlagValue into an Objective-C method.
    public var objcLdFlagValue: ObjcLDFlagValue {
        return ObjcLDFlagValue(self)
    }
}

// The commented out code in this file is intended to support automated typing from the json, which is not implemented in the 3.0.0 release. When that capability can be supported with later Swift versions, uncomment this code to support it.

// MARK: - Bool

//extension LDFlagValue: ExpressibleByBooleanLiteral {
//    init(_ value: Bool) {
//        self = .bool(value)
//    }
//
//    public init(booleanLiteral value: Bool) {
//        self.init(value)
//    }
//}

// MARK: - Int

//extension LDFlagValue: ExpressibleByIntegerLiteral {
//    public init(_ value: Int) {
//        self = .int(value)
//    }
//
//    public init(integerLiteral value: Int) {
//        self.init(value)
//    }
//}

// MARK: - Double

//extension LDFlagValue: ExpressibleByFloatLiteral {
//    public init(_ value: FloatLiteralType) {
//        self = .double(value)
//    }
//
//    public init(floatLiteral value: FloatLiteralType) {
//        self.init(value)
//    }
//}

// MARK: - String

//extension LDFlagValue: ExpressibleByStringLiteral {
//    public init(_ value: StringLiteralType) {
//        self = .string(value)
//    }
//
//    public init(unicodeScalarLiteral value: StringLiteralType) {
//        self.init(value)
//    }
//
//    public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
//        self.init(value)
//    }
//
//    public init(stringLiteral value: StringLiteralType) {
//        self.init(value)
//    }
//}

// MARK: - Array

//extension LDFlagValue: ExpressibleByArrayLiteral {
//    public init<Collection: Swift.Collection>(_ collection: Collection) where Collection.Iterator.Element == LDFlagValue {
//        self = .array(Array(collection))
//    }
//    
//    public init(arrayLiteral elements: LDFlagValue...) {
//        self.init(elements)
//    }
//}

extension LDFlagValue {
    var flagValueArray: [LDFlagValue]? {
        guard case let .array(array) = self
        else {
            return nil
        }
        return array
    }
}

// MARK: - Dictionary

//extension LDFlagValue: ExpressibleByDictionaryLiteral {
//    public typealias Key = LDFlagKey
//    public typealias Value = LDFlagValue
//
//    public init<Dictionary: Sequence>(_ keyValuePairs: Dictionary) where Dictionary.Iterator.Element == (Key, Value) {
//        var dictionary = [Key: Value]()
//        for (key, value) in keyValuePairs {
//            dictionary[key] = value
//        }
//        self.init(dictionary)
//    }
//
//    public init(dictionaryLiteral elements: (Key, Value)...) {
//        self.init(elements)
//    }
//
//    public init(_ dictionary: Dictionary<Key, Value>) {
//        self = .dictionary(dictionary)
//    }
//}

extension LDFlagValue {
    var flagValueDictionary: [LDFlagKey: LDFlagValue]? {
        guard case let .dictionary(value) = self
        else {
            return nil
        }
        return value
    }
}

extension LDFlagValue: Equatable {
    public static func == (lhs: LDFlagValue, rhs: LDFlagValue) -> Bool {
        switch (lhs, rhs) {
        case let (.bool(leftValue), .bool(rightValue)): return leftValue == rightValue
        case let (.int(leftValue), .int(rightValue)): return leftValue == rightValue
        case let (.double(leftValue), .double(rightValue)): return leftValue == rightValue
        case let (.string(leftValue), .string(rightValue)): return leftValue == rightValue
        case let (.array(leftValue), .array(rightValue)): return leftValue == rightValue
        case let (.dictionary(leftValue), .dictionary(rightValue)): return leftValue == rightValue
        case (.null, .null): return true
        default: return false
        }
    }
}

extension Array where Element == LDFlagValue {
    static func == (lhs: [LDFlagValue], rhs: [LDFlagValue]) -> Bool {
        guard lhs.count == rhs.count
        else {
            return false
        }
        //the idea for this came from https://stackoverflow.com/questions/39161168/how-to-compare-two-array-of-objects
        return zip(lhs, rhs).enumerated().filter { (item) -> Bool in
            let (_, (left, right)) = item
            return left != right
        }.isEmpty
    }

    func isEqual(to other: [LDFlagValue]) -> Bool {
        return self == other
    }
}

extension Dictionary where Key == LDFlagKey, Value == LDFlagValue {
    static func == (lhs: [LDFlagKey: LDFlagValue], rhs: [LDFlagKey: LDFlagValue]) -> Bool {
        guard lhs.count == rhs.count
        else {
            return false
        }
        let leftKeys = lhs.keys.sorted()
        let rightKeys = rhs.keys.sorted()
        guard leftKeys == rightKeys
        else {
            return false
        }
        let leftValues = leftKeys.map { (key) -> LDFlagValue in
            return lhs[key] ?? .null
        }
        let rightValues = rightKeys.map { (key) -> LDFlagValue in
            return rhs[key] ?? .null
        }
        return leftValues == rightValues
    }
}
