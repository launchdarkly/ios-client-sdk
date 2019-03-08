//
//  FeatureFlag.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 7/24/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

struct FeatureFlag {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case flagKey = "key", value, variation, version, flagVersion
    }

    let flagKey: LDFlagKey
    let value: Any?
    let variation: Int?
    ///The "environment" version. It changes whenever any feature flag in the environment changes. Used for version comparisons for streaming patch and delete.
    let version: Int?
    ///The feature flag version. It changes whenever this feature flag changes. Used for event reporting only. Server json lists this as "flagVersion". Event json lists this as "version".
    let flagVersion: Int?
    let eventTrackingContext: EventTrackingContext?

    init(flagKey: LDFlagKey, value: Any?, variation: Int?, version: Int?, flagVersion: Int?, eventTrackingContext: EventTrackingContext?) {
        self.flagKey = flagKey
        self.value = value is NSNull ? nil : value
        self.variation = variation
        self.version = version
        self.flagVersion = flagVersion
        self.eventTrackingContext = eventTrackingContext
    }

    init?(dictionary: [String: Any]?) {
        guard let dictionary = dictionary,
            let flagKey = dictionary.flagKey
        else {
            return nil
        }
        self.init(flagKey: flagKey,
                  value: dictionary.value,
                  variation: dictionary.variation,
                  version: dictionary.version,
                  flagVersion: dictionary.flagVersion,
                  eventTrackingContext: EventTrackingContext(dictionary: dictionary))
    }

    var dictionaryValue: [String: Any] {
        var dictionaryValue = [String: Any]()
        dictionaryValue[CodingKeys.flagKey.rawValue] = flagKey
        dictionaryValue[CodingKeys.value.rawValue] = value ?? NSNull()
        dictionaryValue[CodingKeys.variation.rawValue] = variation ?? NSNull()
        dictionaryValue[CodingKeys.version.rawValue] = version ?? NSNull()
        dictionaryValue[CodingKeys.flagVersion.rawValue] = flagVersion ?? NSNull()
        if let eventTrackingContext = eventTrackingContext {
            dictionaryValue.merge(eventTrackingContext.dictionaryValue) { (_, eventTrackingContextValue) in
                return eventTrackingContextValue    //this should never happen since the feature flag dictionary does not have any keys also used by the eventTrackingContext dictionary
            }
        }

        return dictionaryValue
    }
}

extension FeatureFlag: Equatable {
    static func == (lhs: FeatureFlag, rhs: FeatureFlag) -> Bool {
        if lhs.flagKey != rhs.flagKey {
            return false
        }
        if lhs.variation == nil {
            if rhs.variation != nil {
                return false
            }
        } else {
            if lhs.variation != rhs.variation {
                return false
            }
        }
        if lhs.version == nil {
            if rhs.version != nil {
                return false
            }
        } else {
            if lhs.version != rhs.version {
                return false
            }
        }
        return true
    }
}

extension FeatureFlag {
    func matchesVariation(_ other: FeatureFlag) -> Bool {
        guard variation != nil
        else {
            return other.variation == nil
        }
        return variation == other.variation
    }
}

extension Dictionary where Key == LDFlagKey, Value == FeatureFlag {
    var dictionaryValue: [String: Any] {
        return self.compactMapValues { (featureFlag) in
            featureFlag.dictionaryValue
        }
    }
}

extension Dictionary where Key == String, Value == Any {
    var flagKey: String? {
        return self[FeatureFlag.CodingKeys.flagKey.rawValue] as? String
    }

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
        guard !(self is [LDFlagKey: FeatureFlag])
        else {
            return self as? [LDFlagKey: FeatureFlag]
        }
        let flagCollection = [LDFlagKey: FeatureFlag](uniqueKeysWithValues: compactMap { (flagKey, value) -> (LDFlagKey, FeatureFlag)? in
            var elementDictionary = value as? [String: Any]
            if elementDictionary?[FeatureFlag.CodingKeys.flagKey.rawValue] == nil {
                elementDictionary?[FeatureFlag.CodingKeys.flagKey.rawValue] = flagKey
            }
            guard let featureFlag = FeatureFlag(dictionary: elementDictionary)
            else {
                return nil
            }
            return (flagKey, featureFlag)
        })
        guard flagCollection.count == self.count
        else {
            return nil
        }
        return flagCollection
    }
}
