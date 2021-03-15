//
//  DeprecatedCacheModelV2Spec.swift
//  LaunchDarklyTests
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class DeprecatedCacheModelV2Spec: QuickSpec, CacheModelTestInterface {
    let cacheKey = CacheConverter.CacheKeys.ldUserModelDictionary
    var supportsMultiEnv = false

    func createDeprecatedCache(keyedValueCache: KeyedValueCaching) -> DeprecatedCache {
        DeprecatedCacheModelV2(keyedValueCache: keyedValueCache)
    }

    func modelDictionary(for users: [LDUser], and userEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags], mobileKeys: [MobileKey]) -> [UserKey: Any]? {
        guard let mobileKey = mobileKeys.first, !users.isEmpty
        else { return nil }

        return Dictionary(uniqueKeysWithValues: users.map { user in
            let featureFlags = userEnvironmentsCollection[user.key]?.environmentFlags[mobileKey]?.featureFlags
            let lastUpdated = userEnvironmentsCollection[user.key]?.lastUpdated
            return (user.key, user.modelV2DictionaryValue(including: featureFlags!, using: lastUpdated))
        })
    }

    func expectedFeatureFlags(originalFlags: [LDFlagKey: FeatureFlag]) -> [LDFlagKey: FeatureFlag] {
        originalFlags.filter { $0.value.value != nil }.compactMapValues { orig in
            FeatureFlag(flagKey: orig.flagKey, value: orig.value)
        }
    }

    override func spec() {
        DeprecatedCacheModelSpec(cacheModelInterface: self).spec()
    }
}

// MARK: Dictionary value to cache

extension LDUser {
    func modelV2DictionaryValue(including featureFlags: [LDFlagKey: FeatureFlag], using lastUpdated: Date?) -> [String: Any] {
        var userDictionary = dictionaryValueWithAllAttributes()
        userDictionary.removeValue(forKey: LDUser.CodingKeys.privateAttributes.rawValue)
        userDictionary.setLastUpdated(lastUpdated)
        userDictionary[LDUser.CodingKeys.config.rawValue] = featureFlags.allFlagValues.withNullValuesRemoved

        return userDictionary
    }
}
