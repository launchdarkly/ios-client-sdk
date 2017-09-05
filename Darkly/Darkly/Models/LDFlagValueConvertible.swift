//
//  LDFlagValueConvertible.swift
//  Darkly
//
//  Created by Mark Pokorny on 9/5/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

//Protocol to convert base LDFlagType into an LDFlagValue
protocol LDFlagValueConvertible {
    func toLDFlagValue() -> LDFlagValue
}

// MARK: - Bool

//let boolFlag: LDFlagValue = true.toLDFlagValue()
extension Bool: LDFlagValueConvertible {
    func toLDFlagValue() -> LDFlagValue {
        return .bool(self)
    }
}

// MARK: - Int

extension Int: LDFlagValueConvertible {
    func toLDFlagValue() -> LDFlagValue {
        return .int(self)
    }
}

// MARK: - Double

extension Double: LDFlagValueConvertible {
    func toLDFlagValue() -> LDFlagValue {
        return .double(self)
    }
}

// MARK: - String

extension String: LDFlagValueConvertible {
    func toLDFlagValue() -> LDFlagValue {
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

extension Array: LDFlagValueConvertible {
    func toLDFlagValue() -> LDFlagValue {
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
        var flagValues = [String: LDFlagValue]()
        for (key, value) in self {
            flagValues[String(describing: key)] = value.toLDFlagValue()
        }
        return .dictionary(flagValues)
    }
}

extension Dictionary: LDFlagValueConvertible {
    public func toLDFlagValue() -> LDFlagValue {
        guard let flagValues = Dictionary.convertToFlagValues(self as? [String: LDFlagValueConvertible]) else { return .null }
        return .dictionary(flagValues)
    }
    
    static func convertToFlagValues(_ dictionary: [String: LDFlagValueConvertible]?) -> [String: LDFlagValue]? {
        guard let dictionary = dictionary else { return nil }
        var flagValues = [String: LDFlagValue]()
        for (key, value) in dictionary {
            flagValues[String(describing: key)] = value.toLDFlagValue()
        }
        return flagValues
    }
}
