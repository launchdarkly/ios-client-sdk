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
