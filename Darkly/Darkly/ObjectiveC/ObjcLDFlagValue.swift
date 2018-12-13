//
//  ObjcLDFlagValue.swift
//  Darkly
//
//  Created by Mark Pokorny on 9/12/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

///Defines the types and values of a feature flag. The SDK limits feature flags to these types by use of the `LDFlagValueConvertible` protocol, which uses this type. Client app developers should not construct an LDFlagValue. See `LDFlagValue` for the types of feature flags available.
@objc(LDFlagValue)
public final class ObjcLDFlagValue: NSObject {
    let flagVal: LDFlagValue
    
    ///String representation of the type of the feature flag.
    @objc public var flagValueType: String? { return flagVal.typeString }

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

///Defines the possible sources for feature flag values.
///See also: `LDClient.variationAndSource(forKey:fallback:)` and `LDChangedFlag`
@objc(LDFlagValueSource)
public class ObjcLDFlagValueSource: NSObject {
    let flagValueSource: LDFlagValueSource?
    let typeMismatch: Bool

    @objc public static let nilSource = -1
    @objc public static let server = 0
    @objc public static let cache = 1
    @objc public static let fallback = 2
    @objc public static let typeMismatch = 3

    struct StringConstants {
        static let typeMismatch = "type mismatch"
        static let nilSource = "<nil>"
    }

    init(_ source: LDFlagValueSource?, typeMismatch: Bool = false) {
        flagValueSource = source
        self.typeMismatch = typeMismatch
    }

    @objc public init?(rawValue: Int) {
        guard rawValue >= ObjcLDFlagValueSource.nilSource && rawValue <= ObjcLDFlagValueSource.typeMismatch
        else {
            return nil
        }
        self.typeMismatch = rawValue == ObjcLDFlagValueSource.typeMismatch
        self.flagValueSource = LDFlagValueSource(rawValue: rawValue)
        super.init()
    }

    @objc public var rawValue: Int {
        if typeMismatch {
            return ObjcLDFlagValueSource.typeMismatch
        }
        guard let flagValueSource = flagValueSource
        else {
            return ObjcLDFlagValueSource.nilSource
        }
        return flagValueSource.intValue
    }

    @objc public var stringValue: String {
        if typeMismatch {
            return StringConstants.typeMismatch
        }
        guard let flagValueSource = flagValueSource
        else {
            return StringConstants.nilSource
        }
        return "\(flagValueSource)"
    }

    @objc public func isEqual(object: Any?) -> Bool {
        guard let other = object as? ObjcLDFlagValueSource
        else {
            return false
        }
        return self.rawValue == other.rawValue
    }

    @objc public func isEqual(toConstant constantValue: Int) -> Bool {
        return rawValue == constantValue
    }
}

private extension LDFlagValueSource {
    init?(rawValue: Int) {
        guard rawValue >= ObjcLDFlagValueSource.server && rawValue <= ObjcLDFlagValueSource.fallback
        else {
            return nil
        }
        switch rawValue {
        case ObjcLDFlagValueSource.server:
            self = .server
        case ObjcLDFlagValueSource.cache:
            self = .cache
        case ObjcLDFlagValueSource.fallback:
            self = .fallback
        default:
            return nil
        }
    }

    var intValue: Int {
        switch self {
        case .server: return ObjcLDFlagValueSource.server
        case .cache: return ObjcLDFlagValueSource.cache
        case .fallback: return ObjcLDFlagValueSource.fallback
        }
    }
}

#if DEBUG
extension LDFlagValueSource {
    init?(intValue: Int) {
        self.init(rawValue: intValue)
    }
    var intRawValue: Int {
        return self.intValue
    }
}
#endif
