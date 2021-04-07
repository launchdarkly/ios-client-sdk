//
//  DeprecatedCacheModelV4Spec.swift
//  LaunchDarklyTests
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class DeprecatedCacheModelV4Spec: QuickSpec, CacheModelTestInterface {

    let cacheKey = CacheConverter.CacheKeys.ldUserModelDictionary
    let supportsMultiEnv = false

    func createDeprecatedCache(keyedValueCache: KeyedValueCaching) -> DeprecatedCache {
        DeprecatedCacheModelV4(keyedValueCache: keyedValueCache)
    }

    func modelDictionary(for users: [LDUser], and userEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags], mobileKeys: [MobileKey]) -> [UserKey: Any]? {
        guard let mobileKey = mobileKeys.first, !users.isEmpty
        else { return nil }

        return Dictionary(uniqueKeysWithValues: users.map { user in
            let featureFlags = userEnvironmentsCollection[user.key]?.environmentFlags[mobileKey]?.featureFlags
            let lastUpdated = userEnvironmentsCollection[user.key]?.lastUpdated
            return (user.key, user.modelV4DictionaryValue(including: featureFlags!, using: lastUpdated))
        })
    }

    func expectedFeatureFlags(originalFlags: [LDFlagKey: FeatureFlag]) -> [LDFlagKey: FeatureFlag] {
        originalFlags.filter { $0.value.value != nil }.compactMapValues { orig in
            FeatureFlag(flagKey: orig.flagKey,
                        value: orig.value,
                        variation: orig.variation,
                        version: orig.version,
                        flagVersion: orig.flagVersion,
                        trackEvents: orig.trackEvents,
                        debugEventsUntilDate: orig.debugEventsUntilDate)
        }
    }

    override func spec() {
        DeprecatedCacheModelSpec(cacheModelInterface: self).spec()
    }
}

// MARK: Dictionary value to cache

extension LDUser {
    func modelV4DictionaryValue(including featureFlags: [LDFlagKey: FeatureFlag], using lastUpdated: Date?) -> [String: Any] {
        var userDictionary = dictionaryValueWithAllAttributes()
        userDictionary.setLastUpdated(lastUpdated)
        userDictionary[LDUser.CodingKeys.config.rawValue] = featureFlags.compactMapValues { $0.modelV4dictionaryValue }

        return userDictionary
    }
}

extension FeatureFlag {
/*
    [“version”: <modelVersion>,
     “flagVersion”: <flagVersion>,
     “variation”: <variation>,
     “value”: <value>,
     “trackEvents”: <trackEvents>,
     “debugEventsUntilDate”: <debugEventsUntilDate>]
*/
    var modelV4dictionaryValue: [String: Any]? {
        guard value != nil
        else { return nil }
        var flagDictionary = dictionaryValue
        flagDictionary.removeValue(forKey: FeatureFlag.CodingKeys.flagKey.rawValue)
        flagDictionary.removeValue(forKey: FeatureFlag.CodingKeys.reason.rawValue)
        flagDictionary.removeValue(forKey: FeatureFlag.CodingKeys.trackReason.rawValue)
        return flagDictionary
    }
}
