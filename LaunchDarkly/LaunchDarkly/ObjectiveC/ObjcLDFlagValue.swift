//
//  ObjcLDFlagValue.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

///Defines the types and values of a feature flag. The SDK limits feature flags to these types by use of the `LDFlagValueConvertible` protocol, which uses this type. Client app developers should not construct an LDFlagValue. See `LDFlagValue` for the types of feature flags available.
@objc(LDFlagValue)
public final class ObjcLDFlagValue: NSObject {
    let flagVal: LDFlagValue

    ///String representation of the type of the feature flag.
    @objc public var flagValueType: String? {
        flagVal.typeString
    }

    init(_ flagValue: LDFlagValue) {
        self.flagVal = flagValue
    }
}

extension LDFlagValue {
    var typeString: String? {
        switch self {
        case .bool: return "BOOL"
        case .int: return "NSInteger"
        case .double: return "double"
        case .string: return "NSString"
        case .array: return "NSArray"
        case .dictionary: return "NSDictionary"
        default: return nil
        }
    }
}
