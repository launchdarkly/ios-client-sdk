//
//  DeprecatedCacheModelV5Spec.swift
//  LaunchDarklyTests
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class DeprecatedCacheModelV5Spec: QuickSpec, CacheModelTestInterface {
    let cacheKey = DeprecatedCacheModelV5.CacheKeys.userEnvironments

    func createDeprecatedCache(keyedValueCache: KeyedValueCaching) -> DeprecatedCache {
        DeprecatedCacheModelV5(keyedValueCache: keyedValueCache)
    }

    func modelDictionary(for users: [LDUser], and userEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags], mobileKeys: [MobileKey]) -> [UserKey: Any]? {
        guard !users.isEmpty
        else { return nil }

        var cacheDictionary = [UserKey: [String: Any]]()
        users.forEach { user in
            guard let userEnvironment = userEnvironmentsCollection[user.key]
            else { return }
            var environmentsDictionary = [MobileKey: Any]()
            let lastUpdated = userEnvironmentsCollection[user.key]?.lastUpdated
            mobileKeys.forEach { mobileKey in
                guard let featureFlags = userEnvironment.environmentFlags[mobileKey]?.featureFlags
                else { return }
                environmentsDictionary[mobileKey] = user.modelV5DictionaryValue(including: featureFlags, using: lastUpdated)
            }
            cacheDictionary[user.key] = [CacheableEnvironmentFlags.CodingKeys.userKey.rawValue: user.key,
                                         DeprecatedCacheModelV5.CacheKeys.environments: environmentsDictionary]
        }
        return cacheDictionary
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
    func modelV5DictionaryValue(including featureFlags: [LDFlagKey: FeatureFlag], using lastUpdated: Date?) -> [String: Any] {
        var userDictionary = dictionaryValueWithAllAttributes()
        userDictionary.setLastUpdated(lastUpdated)
        userDictionary[LDUser.CodingKeys.config.rawValue] = featureFlags.compactMapValues { $0.modelV5dictionaryValue }

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
    var modelV5dictionaryValue: [String: Any]? {
        guard value != nil
        else { return nil }
        var flagDictionary = dictionaryValue
        flagDictionary.removeValue(forKey: FeatureFlag.CodingKeys.flagKey.rawValue)
        flagDictionary.removeValue(forKey: FeatureFlag.CodingKeys.reason.rawValue)
        flagDictionary.removeValue(forKey: FeatureFlag.CodingKeys.trackReason.rawValue)
        return flagDictionary
    }
}
