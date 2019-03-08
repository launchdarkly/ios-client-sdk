//
//  Any.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 11/9/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

struct AnyComparer {
    private init() { }
    
    //If editing this method to add classes here, update AnySpec with tests that verify the comparison for that class
    //swiftlint:disable:next cyclomatic_complexity
    public static func isEqual(_ value: Any, to other: Any) -> Bool {
        switch (value, other) {
        case (let value as Bool, let other as Bool):
            if value != other {
                return false
            }
        case (let value as Int, let other as Int):
            if value != other {
                return false
            }
        case (let value as Int, let other as Double):
            if Double(value) != other {
                return false
            }
        case (let value as Double, let other as Int):
            if value != Double(other) {
                return false
            }
        case (let value as Int64, let other as Int64):
            if value != other {
                return false
            }
        case (let value as Int64, let other as Double):
            if Double(value) != other {
                return false
            }
        case (let value as Double, let other as Int64):
            if value != Double(other) {
                return false
            }
        case (let value as Double, let other as Double):
            if value != other {
                return false
            }
        case (let value as String, let other as String):
            if value != other {
                return false
            }
        case (let value as [Any], let other as [Any]):
            if !value.isEqual(to: other) {
                return false
            }
        case (let value as [String: Any], let other as [String: Any]):
            if !value.isEqual(to: other) {
                return false
            }
        case (let value as Date, let other as Date):
            if value != other {
                return false
            }
        case (let value as CacheableUserFlags, let other as CacheableUserFlags):
            if value != other {
                return false
            }
        case (let value as FeatureFlag, let other as FeatureFlag):
            if value != other {
                return false
            }
        case (_ as NSNull, _ as NSNull):
            return true
        default: return false
        }
        return true
    }

    public static func isEqual(_ value: Any?, to other: Any?) -> Bool {
        guard let nonNilValue = value, let nonNilOther = other
        else {
            return value == nil && other == nil
        }
        return isEqual(nonNilValue, to: nonNilOther)
    }

    public static func isEqual(_ value: Any, to other: Any?) -> Bool {
        guard let other = other
        else {
            return false
        }
        return isEqual(value, to: other)
    }

    public static func isEqual(_ value: Any?, to other: Any) -> Bool {
        guard let value = value
        else {
            return false
        }
        return isEqual(value, to: other)
    }
}
