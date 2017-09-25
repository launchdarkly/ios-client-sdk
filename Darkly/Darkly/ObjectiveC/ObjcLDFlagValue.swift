//
//  ObjcLDFlagValue.swift
//  Darkly
//
//  Created by Mark Pokorny on 9/12/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

@objc(LDFlagValue)
public final class ObjcLDFlagValue: NSObject {
    let flagVal: LDFlagValue
    
    @objc public var flagValueType: String? { return flagVal.typeString }

    init?(_ flagValue: LDFlagValue?) {
        guard let flagValue = flagValue else { return nil }
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

@objc(LDFlagValueSource)
public enum ObjcLDFlagValueSource: Int {
    case nilSource = -1, server, cache, fallback, typeMismatch
    
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
}

extension NSString {
    @objc public class func stringWithFlagValueSource(_ source: ObjcLDFlagValueSource) -> NSString {
        switch source {
        case .nilSource: return "<nil>"
        case .server: return "server"
        case .cache: return "cache"
        case .fallback: return "fallback"
        case .typeMismatch: return "type mismatch"
        }
    }
}
