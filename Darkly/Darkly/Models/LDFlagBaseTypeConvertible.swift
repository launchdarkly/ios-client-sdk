//
//  LDFlagBaseTypeConvertible.swift
//  Darkly
//
//  Created by Mark Pokorny on 9/5/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

//Protocol to convert LDFlagValue into it's Base Type
public protocol LDFlagBaseTypeConvertible {
    init?(_ flag: LDFlagValue?)
}

// MARK: - Bool

//let boolValue: Bool? = Bool(boolFlag)
extension Bool: LDFlagBaseTypeConvertible {
    public init?(_ flag: LDFlagValue?) {
        guard let flag = flag,
            case let .bool(bool) = flag else { return nil }
        self = bool
    }
}

// MARK: - Int

extension Int: LDFlagBaseTypeConvertible {
    public init?(_ flag: LDFlagValue?) {
        //TODO: Assess whether we need to initialize with a double or string too
        guard let flag = flag,
            case let .int(value) = flag else { return nil }
        self = value
    }
}

// MARK: - Double

extension Double: LDFlagBaseTypeConvertible {
    public init?(_ flag: LDFlagValue?) {
        //TODO: Assess whether we need to initialize with an int or string too
        guard let flag = flag,
            case let .double(value) = flag else { return nil }
        self = value
    }
}

// MARK: - String

extension String: LDFlagBaseTypeConvertible {
    public init?(_ flag: LDFlagValue?) {
        guard let flag = flag,
            case let .string(value) = flag else { return nil }
        self = value
    }
}

// MARK: - Array

extension Array where Element: LDFlagBaseTypeConvertible {
    public init?(_ flag: LDFlagValue?) {
        guard let flagArray: [Element] = flag?.toBaseTypeArray() else { return nil }
        self = flagArray
    }
}

extension LDFlagValue {
    func toBaseTypeArray<BaseType: LDFlagBaseTypeConvertible>() -> [BaseType]? {
        return self.flagValueArray?.flatMap{ BaseType($0) }
    }
}
