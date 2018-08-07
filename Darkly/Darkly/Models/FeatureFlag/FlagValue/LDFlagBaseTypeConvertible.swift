//
//  LDFlagBaseTypeConvertible.swift
//  Darkly
//
//  Created by Mark Pokorny on 9/5/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

//Protocol to convert LDFlagValue into it's Base Type
public protocol LDFlagBaseTypeConvertible {
    init?(_ flag: LDFlagValue?)
}

// MARK: - LDFlagValue

extension LDFlagValue {
    public var baseValue: LDFlagBaseTypeConvertible? {
        switch self {
        case let .bool(value): return value
        case let .int(value): return value
        case let .double(value): return value
        case let .string(value): return value
        case .array: return self.baseArray
        case .dictionary: return self.baseDictionary
        default: return nil
        }
    }
}

// MARK: - Bool

/// :nodoc:
extension Bool: LDFlagBaseTypeConvertible {
    public init?(_ flag: LDFlagValue?) {
        guard let flag = flag,
            case let .bool(bool) = flag
        else { return nil }
        self = bool
    }
}

// MARK: - Int

/// :nodoc:
extension Int: LDFlagBaseTypeConvertible {
    public init?(_ flag: LDFlagValue?) {
        //TODO: Assess whether we need to initialize with a double or string too
        guard let flag = flag,
            case let .int(value) = flag
        else { return nil }
        self = value
    }
}

// MARK: - Double

/// :nodoc:
extension Double: LDFlagBaseTypeConvertible {
    public init?(_ flag: LDFlagValue?) {
        //TODO: Assess whether we need to initialize with an int or string too
        guard let flag = flag,
            case let .double(value) = flag
        else { return nil }
        self = value
    }
}

// MARK: - String

/// :nodoc:
extension String: LDFlagBaseTypeConvertible {
    public init?(_ flag: LDFlagValue?) {
        guard let flag = flag,
            case let .string(value) = flag
        else { return nil }
        self = value
    }
}

// MARK: - Array

/// :nodoc:
extension Array: LDFlagBaseTypeConvertible {
    public init?(_ flag: LDFlagValue?) {
        guard let flagArray = flag?.baseArray as? [Element] else { return nil }
        self = flagArray
    }
}

extension LDFlagValue {
    func toBaseTypeArray<BaseType: LDFlagBaseTypeConvertible>() -> [BaseType]? {
        return self.flagValueArray?.flatMap { BaseType($0) }
    }

    var baseArray: [LDFlagBaseTypeConvertible]? {
        return self.flagValueArray?.flatMap { (flagValue) in flagValue.baseValue}
    }
}

// MARK: - Dictionary

extension LDFlagValue {
    func toBaseTypeDictionary<Value: LDFlagBaseTypeConvertible>() -> [LDFlagKey: Value]? {
        return baseDictionary as? [LDFlagKey: Value]
    }
    
    var baseDictionary: [String: LDFlagBaseTypeConvertible]? {
        guard let flagValues = flagValueDictionary else { return nil }
        return flagValues.flatMapValues { (dictionaryValue) in dictionaryValue.baseValue }
    }
}

/// :nodoc:
extension Dictionary: LDFlagBaseTypeConvertible {
    public init?(_ flag: LDFlagValue?) {
        guard let flagValue = flag?.baseDictionary as? [Key: Value]
            else { return nil }
        self = flagValue
    }
}
