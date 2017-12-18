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
    func toLDFlagValue() -> LDFlagValue
}

// MARK: - Bool

//let boolFlag: LDFlagValue = true.toLDFlagValue()
extension Bool: LDFlagValueConvertible {
    public func toLDFlagValue() -> LDFlagValue {
        return .bool(self)
    }
}

// MARK: - Int

extension Int: LDFlagValueConvertible {
    public func toLDFlagValue() -> LDFlagValue {
        return .int(self)
    }
}

// MARK: - Double

extension Double: LDFlagValueConvertible {
    public func toLDFlagValue() -> LDFlagValue {
        return .double(self)
    }
}

// MARK: - String

extension String: LDFlagValueConvertible {
    public func toLDFlagValue() -> LDFlagValue {
        return .string(self)
    }
}

// MARK: - Array

extension Array where Element: LDFlagValueConvertible {
    public func toLDFlagValue() -> LDFlagValue {
        let flagValues = self.map { (element) in element.toLDFlagValue() }
        return .array(flagValues)
    }
}

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
    public func toLDFlagValue() -> LDFlagValue {
        var flagValues = [LDFlagKey: LDFlagValue]()
        for (key, value) in self {
            flagValues[String(describing: key)] = value.toLDFlagValue()
        }
        return .dictionary(flagValues)
    }
}

extension Dictionary: LDFlagValueConvertible {
    public func toLDFlagValue() -> LDFlagValue {
        guard let flagValues = Dictionary.convertToFlagValues(self as? [LDFlagKey: LDFlagValueConvertible]) else { return .null }
        return .dictionary(flagValues)
    }
    
    internal static func convertToFlagValues(_ dictionary: [LDFlagKey: LDFlagValueConvertible]?) -> [LDFlagKey: LDFlagValue]? {
        guard let dictionary = dictionary else { return nil }
        var flagValues = [LDFlagKey: LDFlagValue]()
        for (key, value) in dictionary {
            flagValues[String(describing: key)] = value.toLDFlagValue()
        }
        return flagValues
    }
}
