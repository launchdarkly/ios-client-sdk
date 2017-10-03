//
//  LDFlagValue.swift
//  Darkly
//
//  Created by Mark Pokorny on 9/5/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

public enum LDFlagValueSource {
    case server, cache, fallback
}

public enum LDFlagValue {
    case bool(Bool)
    //swiftlint:disable:next identifier_name
    case int(Int)
    case double(Double)
    case string(String)
    case array([LDFlagValue])
    case dictionary([String: LDFlagValue])
    case null   //TODO: try to get rid of this
}

// MARK: - Bool

extension LDFlagValue: ExpressibleByBooleanLiteral {
    public init(_ value: Bool) {
        self = .bool(value)
    }
    
    public init(booleanLiteral value: Bool) {
        self.init(value)
    }
}

// MARK: - Int

extension LDFlagValue: ExpressibleByIntegerLiteral {
    public init(_ value: Int) {
        self = .int(value)
    }
    
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

// MARK: - Double

extension LDFlagValue: ExpressibleByFloatLiteral {
    public init(_ value: FloatLiteralType) {
        self = .double(value)
    }
    
    public init(floatLiteral value: FloatLiteralType) {
        self.init(value)
    }
}

// MARK: - String

extension LDFlagValue: ExpressibleByStringLiteral {
    public init(_ value: StringLiteralType) {
        self = .string(value)
    }
    
    public init(unicodeScalarLiteral value: StringLiteralType) {
        self.init(value)
    }
    
    public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
        self.init(value)
    }
    
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}

// MARK: - Array

extension LDFlagValue: ExpressibleByArrayLiteral {
    public init<Collection: Swift.Collection>(_ collection: Collection) where Collection.Iterator.Element == LDFlagValue {
        self = .array(Array(collection))
    }
    
    public init(arrayLiteral elements: LDFlagValue...) {
        self.init(elements)
    }
}

extension LDFlagValue {
    public var flagValueArray: [LDFlagValue]? {
        guard case let .array(array) = self else { return nil }
        return array
    }
}

// MARK: - Dictionary

extension LDFlagValue: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = LDFlagValue
    
    public init<Dictionary: Sequence>(_ keyValuePairs: Dictionary) where Dictionary.Iterator.Element == (Key, Value) {
        var dictionary = [Key: Value]()
        for (key, value) in keyValuePairs {
            dictionary[key] = value
        }
        self.init(dictionary)
    }
    
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(elements)
    }
    
    public init(_ dictionary: Dictionary<Key, Value>) {
        self = .dictionary(dictionary)
    }
}

extension LDFlagValue {
    public var flagValueDictionary: [String: LDFlagValue]? {
        guard case let .dictionary(value) = self else { return nil }
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
        default: return false
        }
    }
}

extension Array where Element == LDFlagValue {
    public static func == (lhs: [LDFlagValue], rhs: [LDFlagValue]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        //the idea for this came from https://stackoverflow.com/questions/39161168/how-to-compare-two-array-of-objects
        return zip(lhs, rhs).enumerated().filter { (item) -> Bool in
            let (_, (left, right)) = item
            return left != right
        }.isEmpty
    }

    public func isEqual(to other: [LDFlagValue]) -> Bool {
        return self == other
    }
}

extension Dictionary where Key == String, Value == LDFlagValue {
    public static func == (lhs: [String: LDFlagValue], rhs: [String: LDFlagValue]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        let leftKeys = lhs.keys.sorted()
        let rightKeys = rhs.keys.sorted()
        guard leftKeys == rightKeys else { return false }
        let leftValues = leftKeys.map { (key) -> LDFlagValue in return lhs[key] ?? .null }
        let rightValues = rightKeys.map { (key) -> LDFlagValue in return rhs[key] ?? .null }
        return leftValues == rightValues
    }
}
