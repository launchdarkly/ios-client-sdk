//
//  LDFlagValueConvertible.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 9/5/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

//Protocol to convert base LDFlagType into an LDFlagValue
///Protocol used by the SDK to limit feature flag types to those representable on LaunchDarkly servers. Client app developers should not need to use this protocol. The protocol is public because `LDClient.variation(forKey:fallback:)` and `LDClient.variationAndSource(forKey:fallback:)` return a type that conforms to this protocol. See `LDFlagValue` for types that LaunchDarkly feature flags can take.
public protocol LDFlagValueConvertible {
// This commented out code here and in each extension will be used to support automatic typing. Version `3.0.0` does not support that capability. When that capability is added, uncomment this code.
//    func toLDFlagValue() -> LDFlagValue
}

// MARK: - Bool

extension Bool: LDFlagValueConvertible {
//    public func toLDFlagValue() -> LDFlagValue {
//        return .bool(self)
//    }
}

// MARK: - Int

extension Int: LDFlagValueConvertible {
//    public func toLDFlagValue() -> LDFlagValue {
//        return .int(self)
//    }
}

// MARK: - Double

extension Double: LDFlagValueConvertible {
//    public func toLDFlagValue() -> LDFlagValue {
//        return .double(self)
//    }
}

// MARK: - String

extension String: LDFlagValueConvertible {
//    public func toLDFlagValue() -> LDFlagValue {
//        return .string(self)
//    }
}

// MARK: - Array

extension Array where Element: LDFlagValueConvertible {
//    func toLDFlagValue() -> LDFlagValue {
//        let flagValues = self.map { (element) in
//            element.toLDFlagValue()
//        }
//        return .array(flagValues)
//    }
}

extension Array: LDFlagValueConvertible {
//    public func toLDFlagValue() -> LDFlagValue {
//        guard let flags = self as? [LDFlagValueConvertible]
//        else {
//            return .null
//        }
//        let flagValues = flags.map { (element) in
//            element.toLDFlagValue()
//        }
//        return .array(flagValues)
//    }
}

// MARK: - Dictionary

extension Dictionary where Value: LDFlagValueConvertible {
//    func toLDFlagValue() -> LDFlagValue {
//        var flagValues = [LDFlagKey: LDFlagValue]()
//        for (key, value) in self {
//            flagValues[String(describing: key)] = value.toLDFlagValue()
//        }
//        return .dictionary(flagValues)
//    }
}

extension Dictionary: LDFlagValueConvertible {
//    public func toLDFlagValue() -> LDFlagValue {
//        if let flagValueDictionary = self as? [LDFlagKey: LDFlagValue] {
//            return .dictionary(flagValueDictionary)
//        }
//        guard let flagValues = Dictionary.convertToFlagValues(self as? [LDFlagKey: LDFlagValueConvertible])
//        else {
//            return .null
//        }
//        return .dictionary(flagValues)
//    }
//
//    static func convertToFlagValues(_ dictionary: [LDFlagKey: LDFlagValueConvertible]?) -> [LDFlagKey: LDFlagValue]? {
//        guard let dictionary = dictionary
//        else {
//            return nil
//        }
//        var flagValues = [LDFlagKey: LDFlagValue]()
//        for (key, value) in dictionary {
//            flagValues[String(describing: key)] = value.toLDFlagValue()
//        }
//        return flagValues
//    }
}

extension NSNull: LDFlagValueConvertible {
//    public func toLDFlagValue() -> LDFlagValue {
//        return .null
//    }
}

//extension LDFlagValueConvertible {
//    func isEqual(to other: LDFlagValueConvertible) -> Bool {
//        switch (self.toLDFlagValue(), other.toLDFlagValue()) {
//        case (.bool(let value), .bool(let otherValue)): return value == otherValue
//        case (.int(let value), .int(let otherValue)): return value == otherValue
//        case (.double(let value), .double(let otherValue)): return value == otherValue
//        case (.string(let value), .string(let otherValue)): return value == otherValue
//        case (.array(let value), .array(let otherValue)): return value == otherValue
//        case (.dictionary(let value), .dictionary(let otherValue)): return value == otherValue
//        case (.null, .null): return true
//        default: return false
//        }
//    }
//}

//extension Optional where Wrapped == LDFlagValueConvertible {
//    func isEqual(to other: LDFlagValueConvertible?) -> Bool {
//        guard case .some(let value) = self, case .some(let otherValue) = other else { return false }
//        return value.isEqual(to: otherValue)
//    }
//}
