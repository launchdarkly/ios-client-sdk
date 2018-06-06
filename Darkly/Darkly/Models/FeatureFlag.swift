//
//  FeatureFlag.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/24/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

struct FeatureFlag {

    enum CodingKeys: String, CodingKey {
        case value, variation, version
    }

    struct Constants {
        static let nilVersionPlaceholder = -1
    }
    
    let value: Any?
    let variation: Int?
    let version: Int?

    init(value: Any?, variation: Int?, version: Int?) {
        self.value = value is NSNull ? nil : value
        self.variation = variation
        self.version = version
    }

    init?(dictionary: [String: Any]?) {
        guard let dictionary = dictionary else { return nil }
        if dictionary.containsValueAndVersionKeys {
            self.init(value: dictionary[CodingKeys.value.rawValue], variation: nil, version: dictionary[CodingKeys.version.rawValue] as? Int)
            return
        }
        self.init(value: dictionary, variation: nil, version: nil)
    }

    init?(object: Any?) {
        if let object = object as? [String: Any] {
            self.init(dictionary: object)
            return
        }
        if let object = object {
            self.init(value: object, variation: nil, version: nil)
            return
        }
        return nil
    }

    func dictionaryValue(exciseNil: Bool) -> [String: Any]? {
        if exciseNil && value == nil { return nil }
        var dictionaryValue = [String: Any]()
        var nilExcisedValue = value
        if exciseNil, let dictionaryValue = value as? [LDFlagKey: Any] {
            nilExcisedValue = dictionaryValue.filter { (_, value) -> Bool in
                if value is NSNull { return false }
                return true
            }
        }
        dictionaryValue[CodingKeys.value.rawValue] = nilExcisedValue ?? NSNull()
        dictionaryValue[CodingKeys.version.rawValue] = version ?? (exciseNil ? Constants.nilVersionPlaceholder : NSNull())
        return dictionaryValue
    }
}

extension FeatureFlag: Equatable {
    public static func == (lhs: FeatureFlag, rhs: FeatureFlag) -> Bool {
        if lhs.value == nil {
            if rhs.value != nil { return false }
        } else {
            if !AnyComparer.isEqual(lhs.value, to: rhs.value) { return false }
        }
        if lhs.version == nil {
            if rhs.version != nil { return false }
        } else {
            if lhs.version != rhs.version { return false }
        }
        return true
    }
}

extension FeatureFlag {
    func matchesValue(_ other: FeatureFlag) -> Bool {
        guard value != nil else { return other.value == nil }
        return AnyComparer.isEqual(self.value, to: other.value)
    }
}

extension Dictionary where Key == String, Value == FeatureFlag {
    func dictionaryValue(exciseNil: Bool) -> [String: Any] {
        return self.flatMapValues { (featureFlag) in featureFlag.dictionaryValue(exciseNil: exciseNil) }
    }
}

extension Dictionary where Key == String, Value == Any {
    var value: Any? {
        return self[FeatureFlag.CodingKeys.value.rawValue]
    }

    var variation: Int? {
        return self[FeatureFlag.CodingKeys.variation.rawValue] as? Int
    }

    var version: Int? {
        return self[FeatureFlag.CodingKeys.version.rawValue] as? Int
    }

    var flagCollection: [LDFlagKey: FeatureFlag]? {
        guard !(self is [LDFlagKey: FeatureFlag]) else { return self as? [LDFlagKey: FeatureFlag] }
        let flagCollection = flatMapValues { (flagValue) in return FeatureFlag(object: flagValue) }
        guard flagCollection.count == self.count else { return nil }
        return flagCollection
    }
    var containsValueAndVersionKeys: Bool {
        let keySet = Set(self.keys)
        let valueAndVersionKeySet = Set([FeatureFlag.CodingKeys.value.rawValue, FeatureFlag.CodingKeys.version.rawValue])
        return valueAndVersionKeySet.isSubset(of: keySet)
    }
}
