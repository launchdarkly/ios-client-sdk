//
//  Collection.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 10/26/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

extension Collection {
    //swiftlint:disable:next cyclomatic_complexity
    public static func isEqual(_ value: Any, to other: Any) -> Bool {
        switch (value, other) {
        case (let value as Bool, let other as Bool): if value != other { return false }
        case (let value as Int, let other as Int): if value != other { return false }
        case (let value as Int, let other as Double): if Double(value) != other { return false }
        case (let value as Double, let other as Double): if value != other { return false }
        case (let value as Double, let other as Int): if value != Double(other) { return false }
        case (let value as String, let other as String): if value != other { return false }
        case (let value as [Any], let other as [Any]): if !value.isEqual(to: other) { return false }
        case (let value as [String: Any], let other as [String: Any]): if !value.isEqual(to: other) { return false }
        default: return false
        }
        return true
    }
}
