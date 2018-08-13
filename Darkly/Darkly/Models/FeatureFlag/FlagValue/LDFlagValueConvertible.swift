//
//  LDFlagValueConvertible.swift
//  Darkly
//
//  Created by Mark Pokorny on 9/5/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

//Protocol to convert base LDFlagType into an LDFlagValue
public protocol LDFlagValueConvertible {
    /// :nodoc:
    func toLDFlagValue() -> LDFlagValue
}

// MARK: - Bool

/// :nodoc:
extension Bool: LDFlagValueConvertible {
    public func toLDFlagValue() -> LDFlagValue {
        return .bool(self)
    }
}

// MARK: - Int

/// :nodoc:
extension Int: LDFlagValueConvertible {
    public func toLDFlagValue() -> LDFlagValue {
        return .int(self)
    }
}

// MARK: - Double

/// :nodoc:
extension Double: LDFlagValueConvertible {
    public func toLDFlagValue() -> LDFlagValue {
        return .double(self)
    }
}

// MARK: - String

/// :nodoc:
extension String: LDFlagValueConvertible {
    public func toLDFlagValue() -> LDFlagValue {
        return .string(self)
    }
}

// MARK: - Array

extension Array where Element: LDFlagValueConvertible {
    func toLDFlagValue() -> LDFlagValue {
        let flagValues = self.map { (element) in element.toLDFlagValue() }
        return .array(flagValues)
    }
}

/// :nodoc:
extension Array: LDFlagValueConvertible {
    public func toLDFlagValue() -> LDFlagValue {
        guard let flags = self as? [LDFlagValueConvertible] else {
            return .null
        }
        let flagValues = flags.map { (element) in element.toLDFlagValue() }
        return .array(flagValues)
    }
}

// MARK: - Dictionary

extension Dictionary where Value: LDFlagValueConvertible {
    func toLDFlagValue() -> LDFlagValue {
        var flagValues = [LDFlagKey: LDFlagValue]()
        for (key, value) in self {
            flagValues[String(describing: key)] = value.toLDFlagValue()
        }
        return .dictionary(flagValues)
    }
}

/// :nodoc:
extension Dictionary: LDFlagValueConvertible {
    public func toLDFlagValue() -> LDFlagValue {
        if let flagValueDictionary = self as? [LDFlagKey: LDFlagValue] { return .dictionary(flagValueDictionary) }
        guard let flagValues = Dictionary.convertToFlagValues(self as? [LDFlagKey: LDFlagValueConvertible]) else { return .null }
        return .dictionary(flagValues)
    }
    
    static func convertToFlagValues(_ dictionary: [LDFlagKey: LDFlagValueConvertible]?) -> [LDFlagKey: LDFlagValue]? {
        guard let dictionary = dictionary else { return nil }
        var flagValues = [LDFlagKey: LDFlagValue]()
        for (key, value) in dictionary {
            flagValues[String(describing: key)] = value.toLDFlagValue()
        }
        return flagValues
    }
}

/// :nodoc:
extension NSNull: LDFlagValueConvertible {
    public func toLDFlagValue() -> LDFlagValue {
        return .null
    }
}

extension LDFlagValueConvertible {
    func isEqual(to other: LDFlagValueConvertible) -> Bool {
        switch (self.toLDFlagValue(), other.toLDFlagValue()) {
        case (.bool(let value), .bool(let otherValue)): return value == otherValue
        case (.int(let value), .int(let otherValue)): return value == otherValue
        case (.double(let value), .double(let otherValue)): return value == otherValue
        case (.string(let value), .string(let otherValue)): return value == otherValue
        case (.array(let value), .array(let otherValue)): return value == otherValue
        case (.dictionary(let value), .dictionary(let otherValue)): return value == otherValue 
        case (.null, .null): return true
        default: return false
        }
    }
}

extension Optional where Wrapped == LDFlagValueConvertible {
    func isEqual(to other: LDFlagValueConvertible?) -> Bool {
        guard case .some(let value) = self, case .some(let otherValue) = other else { return false }
        return value.isEqual(to: otherValue)
    }
}
