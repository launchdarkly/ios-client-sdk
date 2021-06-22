//
//  DeprecatedCacheModelV2.swift
//  LaunchDarkly
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

// Cache model in use from 2.3.3 up to 2.11.0
/* Cache model v2 schema
[<userKey>: [
    “key: <userKey>,                            //LDUserModel dictionary
    “ip”: <ipAddress>,
    “country”: <country>,
    “email”: <email>,
    “name”: <name>,
    “firstName”: <firstName>,
    “lastName”: <lastName>,
    “avatar”: <avatar>,
    “custom”: [
        “device”: <device>,
        “os”: <os>,
        ...],
    “anonymous”: <anonymous>,
    “updatedAt: <updatedAt>,
    ”config”: [<flagKey>: <flagValue>]
    ]
]
 */
final class DeprecatedCacheModelV2: DeprecatedCache {
    let keyedValueCache: KeyedValueCaching
    let cachedDataKey = CacheConverter.CacheKeys.ldUserModelDictionary

    init(keyedValueCache: KeyedValueCaching) {
        self.keyedValueCache = keyedValueCache
    }

    func retrieveFlags(for userKey: UserKey, and mobileKey: MobileKey) -> (featureFlags: [LDFlagKey: FeatureFlag]?, lastUpdated: Date?) {
        guard let cachedUserDictionaries = keyedValueCache.dictionary(forKey: cachedDataKey), !cachedUserDictionaries.isEmpty,
            let cachedUserDictionary = cachedUserDictionaries[userKey] as? [String: Any], !cachedUserDictionary.isEmpty,
            let featureFlagDictionaries = cachedUserDictionary[LDUser.CodingKeys.config.rawValue] as? [LDFlagKey: Any]
        else {
            return (nil, nil)
        }
        let featureFlags = Dictionary(uniqueKeysWithValues: featureFlagDictionaries.compactMap { flagKey, value in
            (flagKey, FeatureFlag(flagKey: flagKey, value: value))
        })
        return (featureFlags, cachedUserDictionary.lastUpdated)
    }

    func userKeys(from cachedUserData: [UserKey: [String: Any]], olderThan expirationDate: Date) -> [UserKey] {
        cachedUserData.compactMap { userKey, userDictionary in
            let lastUpdated = userDictionary.lastUpdated ?? Date.distantFuture
            return lastUpdated.isExpired(expirationDate: expirationDate) ? userKey : nil
        }
    }
}
