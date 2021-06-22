//
//  Any.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

struct AnyComparer {
    private init() { }

    // If editing this method to add classes here, update AnySpec with tests that verify the comparison for that class
    // swiftlint:disable:next cyclomatic_complexity
    static func isEqual(_ value: Any, to other: Any) -> Bool {
        switch (value, other) {
        case let (value, other) as (Bool, Bool):
            if value != other {
                return false
            }
        case let (value, other) as (Int, Int):
            if value != other {
                return false
            }
        case let (value, other) as (Int, Double):
            if Double(value) != other {
                return false
            }
        case let (value, other) as (Double, Int):
            if value != Double(other) {
                return false
            }
        case let (value, other) as (Int64, Int64):
            if value != other {
                return false
            }
        case let (value, other) as (Int64, Double):
            if Double(value) != other {
                return false
            }
        case let (value, other) as (Double, Int64):
            if value != Double(other) {
                return false
            }
        case let (value, other) as (Double, Double):
            if value != other {
                return false
            }
        case let (value, other) as (String, String):
            if value != other {
                return false
            }
        case let (value, other) as ([Any], [Any]):
            if value.count != other.count {
                return false
            }
            for index in 0..<value.count where !AnyComparer.isEqual(value[index], to: other[index]) {
                return false
            }
        case let (value, other) as ([String: Any], [String: Any]):
            if value.count != other.count {
                return false
            }
            if value.keys.sorted() != other.keys.sorted() {
                return false
            }
            for key in value.keys {
                if !AnyComparer.isEqual(value[key], to: other[key]) {
                    return false
                }
            }
        case let (value, other) as (Date, Date):
            if value != other {
                return false
            }
        case let (value, other) as (FeatureFlag, FeatureFlag):
            if value != other {
                return false
            }
        case (_ as NSNull, _ as NSNull):
            return true
        default: return false
        }
        return true
    }

    static func isEqual(_ value: Any?, to other: Any?) -> Bool {
        guard let nonNilValue = value, let nonNilOther = other
        else {
            return value == nil && other == nil
        }
        return isEqual(nonNilValue, to: nonNilOther)
    }

    static func isEqual(_ value: Any, to other: Any?) -> Bool {
        guard let other = other
        else {
            return false
        }
        return isEqual(value, to: other)
    }

    static func isEqual(_ value: Any?, to other: Any) -> Bool {
        guard let value = value
        else {
            return false
        }
        return isEqual(value, to: other)
    }
}
