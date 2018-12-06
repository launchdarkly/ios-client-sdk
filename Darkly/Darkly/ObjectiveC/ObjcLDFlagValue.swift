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
public enum ObjcLDFlagValueSource: Int {
    ///ObjcLDFlagValueSourceNilSource indicates the feature flag value's source is not available (Objective-C only)
    case nilSource = -1
    ///ObjcLDFlagValueSourceServer indicates the feature flag value's source is the LaunchDarkly server
    case server
    ///ObjcLDFlagValueSourceCache indicates the feature flag value's source is the SDK's local cache
    case cache
    ///ObjcLDFlagValueSourceFallback indicates the feature flag value's source is the fallback value provided by the client app
    case fallback
    ///ObjcLDFlagValueSourceTypeMismatch indicates the type of feature flag requested differs from the actual feature flag type (Objective-C only)
    case typeMismatch
    
    init(_ source: LDFlagValueSource?, typeMismatch: Bool = false) {
        if typeMismatch {
            self = .typeMismatch
            return
        }
        if let source = source {
            switch source {
            case .server: self = .server
            case .cache: self = .cache
            case .fallback: self = .fallback
            }
            return
        }
        self = .nilSource
    }

    var stringValue: String {
        switch self {
        case .nilSource: return "<nil>"
        case .server: return "server"
        case .cache: return "cache"
        case .fallback: return "fallback"
        case .typeMismatch: return "type mismatch"
        }
    }
}

extension NSString {
    ///String representation of an ObjcLDFlagValueSource 
    @objc public class func stringWithFlagValueSource(_ source: ObjcLDFlagValueSource) -> NSString {
        return source.stringValue as NSString
    }
}
