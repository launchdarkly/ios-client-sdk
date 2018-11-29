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
        case value, variation, version, flagVersion

        static var allKeys: [CodingKeys] { return [.value, .variation, .version, .flagVersion] }
        static var allKeyStrings: [String] { return allKeys.map { (key) in key.rawValue } }
    }

    let value: Any?
    let variation: Int?
    let version: Int?
    let flagVersion: Int?
    let eventTrackingContext: EventTrackingContext?

    //TODO: Add the flag key into this to help with debugging
    init(value: Any?, variation: Int?, version: Int?, flagVersion: Int?, eventTrackingContext: EventTrackingContext?) {
        self.value = value is NSNull ? nil : value
        self.variation = variation
        self.version = version
        self.flagVersion = flagVersion
        self.eventTrackingContext = eventTrackingContext
    }

    init?(dictionary: [String: Any]?) {
        guard let dictionary = dictionary else { return nil }
        guard dictionary.hasAtLeastOneFeatureFlagKey else { return nil }
        let eventTrackingContext = EventTrackingContext(dictionary: dictionary)
        self.init(value: dictionary.value, variation: dictionary.variation, version: dictionary.version, flagVersion: dictionary.flagVersion, eventTrackingContext: eventTrackingContext)
    }

    init?(object: Any?) {
        guard let object = object as? [String: Any] else { return nil }
        self.init(dictionary: object)
    }

    var dictionaryValue: [String: Any] {
        var dictionaryValue = [String: Any]()
        dictionaryValue[CodingKeys.value.rawValue] = value ?? NSNull()
        dictionaryValue[CodingKeys.variation.rawValue] = variation ?? NSNull()
        dictionaryValue[CodingKeys.version.rawValue] = version ?? NSNull()
        dictionaryValue[CodingKeys.flagVersion.rawValue] = flagVersion ?? NSNull()
        if let eventTrackingContext = eventTrackingContext {
            dictionaryValue.merge(eventTrackingContext.dictionaryValue) { (_, eventTrackingContextValue) in
                return eventTrackingContextValue
            }
        }

        return dictionaryValue
    }
}

extension FeatureFlag: Equatable {
    static func == (lhs: FeatureFlag, rhs: FeatureFlag) -> Bool {
        if lhs.variation == nil {
            if rhs.variation != nil { return false }
        } else {
            if lhs.variation != rhs.variation { return false }
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
    func matchesVariation(_ other: FeatureFlag) -> Bool {
        guard variation != nil else { return other.variation == nil }
        return variation == other.variation
    }
}

extension Dictionary where Key == LDFlagKey, Value == FeatureFlag {
    var dictionaryValue: [String: Any] {
        return self.compactMapValues { (featureFlag) in featureFlag.dictionaryValue }
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

    var flagVersion: Int? {
        return self[FeatureFlag.CodingKeys.flagVersion.rawValue] as? Int
    }

    var flagCollection: [LDFlagKey: FeatureFlag]? {
        guard !(self is [LDFlagKey: FeatureFlag]) else { return self as? [LDFlagKey: FeatureFlag] }
        let flagCollection = compactMapValues { (flagValue) in return FeatureFlag(object: flagValue) }
        guard flagCollection.count == self.count else { return nil }
        return flagCollection
    }

    var hasAtLeastOneFeatureFlagKey: Bool {
        guard !keys.isEmpty else { return false }
        return !Set(keys).isDisjoint(with: Set(FeatureFlag.CodingKeys.allKeyStrings))
    }
}
