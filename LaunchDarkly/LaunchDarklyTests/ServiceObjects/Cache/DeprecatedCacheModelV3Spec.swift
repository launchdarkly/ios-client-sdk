//
//  DeprecatedCacheModelV3Spec.swift
//  LaunchDarklyTests
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class DeprecatedCacheModelV3Spec: QuickSpec, CacheModelTestInterface {

    let cacheKey = CacheConverter.CacheKeys.ldUserModelDictionary
    let supportsMultiEnv = false

    func createDeprecatedCache(keyedValueCache: KeyedValueCaching) -> DeprecatedCache {
        DeprecatedCacheModelV3(keyedValueCache: keyedValueCache)
    }

    func modelDictionary(for users: [LDUser], and userEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags], mobileKeys: [MobileKey]) -> [UserKey: Any]? {
        guard let mobileKey = mobileKeys.first, !users.isEmpty
        else { return nil }

        return Dictionary(uniqueKeysWithValues: users.map { user in
            let featureFlags = userEnvironmentsCollection[user.key]?.environmentFlags[mobileKey]?.featureFlags
            let lastUpdated = userEnvironmentsCollection[user.key]?.lastUpdated
            return (user.key, user.modelV3DictionaryValue(including: featureFlags!, using: lastUpdated))
        })
    }

    func expectedFeatureFlags(originalFlags: [LDFlagKey: FeatureFlag]) -> [LDFlagKey: FeatureFlag] {
        originalFlags.filter { $0.value.value != nil }.compactMapValues { orig in
            FeatureFlag(flagKey: orig.flagKey, value: orig.value, version: orig.version)
        }
    }

    override func spec() {
        DeprecatedCacheModelSpec(cacheModelInterface: self).spec()
    }
}

// MARK: Dictionary value to cache

extension LDUser {
    func modelV3DictionaryValue(including featureFlags: [LDFlagKey: FeatureFlag], using lastUpdated: Date?) -> [String: Any] {
        var userDictionary = dictionaryValueWithAllAttributes()
        userDictionary.setLastUpdated(lastUpdated)
        userDictionary[LDUser.CodingKeys.config.rawValue] = featureFlags.compactMapValues { $0.modelV3dictionaryValue }

        return userDictionary
    }
}

extension FeatureFlag {
/*
     [“version”: <modelVersion>,
      “value”: <value>]
*/
    var modelV3dictionaryValue: [String: Any]? {
        guard value != nil
        else { return nil }
        var flagDictionary = dictionaryValue
        flagDictionary.removeValue(forKey: FeatureFlag.CodingKeys.flagKey.rawValue)
        flagDictionary.removeValue(forKey: FeatureFlag.CodingKeys.variation.rawValue)
        flagDictionary.removeValue(forKey: FeatureFlag.CodingKeys.flagVersion.rawValue)
        flagDictionary.removeValue(forKey: FeatureFlag.CodingKeys.trackEvents.rawValue)
        flagDictionary.removeValue(forKey: FeatureFlag.CodingKeys.debugEventsUntilDate.rawValue)
        flagDictionary.removeValue(forKey: FeatureFlag.CodingKeys.reason.rawValue)
        return flagDictionary
    }
}
