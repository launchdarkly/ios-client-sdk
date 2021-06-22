//
//  LDFlagValueConvertible.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

/// Protocol used by the SDK to limit feature flag types to those representable on LaunchDarkly servers. Client app developers should not need to use this protocol. The protocol is public because `LDClient.variation(forKey:defaultValue:)` and `LDClient.variationDetail(forKey:defaultValue:)` return a type that conforms to this protocol. See `LDFlagValue` for types that LaunchDarkly feature flags can take.
public protocol LDFlagValueConvertible {
// This commented out code here and in each extension will be used to support automatic typing. Version `4.0.0` does not support that capability. When that capability is added, uncomment this code.
//    func toLDFlagValue() -> LDFlagValue
}

/// :nodoc:
extension Bool: LDFlagValueConvertible {
//    public func toLDFlagValue() -> LDFlagValue {
//        return .bool(self)
//    }
}

/// :nodoc:
extension Int: LDFlagValueConvertible {
//    public func toLDFlagValue() -> LDFlagValue {
//        return .int(self)
//    }
}

/// :nodoc:
extension Double: LDFlagValueConvertible {
//    public func toLDFlagValue() -> LDFlagValue {
//        return .double(self)
//    }
}

/// :nodoc:
extension String: LDFlagValueConvertible {
//    public func toLDFlagValue() -> LDFlagValue {
//        return .string(self)
//    }
}

/// :nodoc:
extension Array where Element: LDFlagValueConvertible {
//    func toLDFlagValue() -> LDFlagValue {
//        let flagValues = self.map { (element) in
//            element.toLDFlagValue()
//        }
//        return .array(flagValues)
//    }
}

/// :nodoc:
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

/// :nodoc:
extension Dictionary where Value: LDFlagValueConvertible {
//    func toLDFlagValue() -> LDFlagValue {
//        var flagValues = [LDFlagKey: LDFlagValue]()
//        for (key, value) in self {
//            flagValues[String(describing: key)] = value.toLDFlagValue()
//        }
//        return .dictionary(flagValues)
//    }
}

/// :nodoc:
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

/// :nodoc:
extension NSNull: LDFlagValueConvertible {
//    public func toLDFlagValue() -> LDFlagValue {
//        return .null
//    }
}

// extension LDFlagValueConvertible {
//     func isEqual(to other: LDFlagValueConvertible) -> Bool {
//         switch (self.toLDFlagValue(), other.toLDFlagValue()) {
//         case (.bool(let value), .bool(let otherValue)): return value == otherValue
//         case (.int(let value), .int(let otherValue)): return value == otherValue
//         case (.double(let value), .double(let otherValue)): return value == otherValue
//         case (.string(let value), .string(let otherValue)): return value == otherValue
//         case (.array(let value), .array(let otherValue)): return value == otherValue
//         case (.dictionary(let value), .dictionary(let otherValue)): return value == otherValue
//         case (.null, .null): return true
//         default: return false
//         }
//     }
// }
