//
//  DeprecatedCacheModelV5.swift
//  LaunchDarkly
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

// Cache model in use from 2.14.0 up to 4.0.0
/* Cache model v5 schema
[<userKey>: [
    “userKey”: <userKey>,                               //LDUserEnvironment dictionary
    “environments”: [
        <mobileKey>: [
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
            ”config”: [
                <flagKey>: [                            //LDFlagConfigModel dictionary
                    “version”: <modelVersion>,          //LDFlagConfigValue dictionary
                    “flagVersion”: <flagVersion>,
                    “variation”: <variation>,
                    “value”: <value>,
                    “trackEvents”: <trackEvents>,
                    “debugEventsUntilDate”: <debugEventsUntilDate>
                    ]
                ],
            “privateAttrs”: <privateAttributes>
            ]
        ]
    ]
]
*/
final class DeprecatedCacheModelV5: DeprecatedCache {

    struct CacheKeys {
        static let userEnvironments = "com.launchdarkly.dataManager.userEnvironments"
        static let environments = "environments"
    }

    let keyedValueCache: KeyedValueCaching
    let cachedDataKey = CacheKeys.userEnvironments

    init(keyedValueCache: KeyedValueCaching) {
        self.keyedValueCache = keyedValueCache
    }

    func retrieveFlags(for userKey: UserKey, and mobileKey: MobileKey) -> (featureFlags: [LDFlagKey: FeatureFlag]?, lastUpdated: Date?) {
        guard let cachedUserEnvironmentsCollection = keyedValueCache.dictionary(forKey: cachedDataKey), !cachedUserEnvironmentsCollection.isEmpty,
            let cachedUserEnvironments = cachedUserEnvironmentsCollection[userKey] as? [String: Any], !cachedUserEnvironments.isEmpty,
            let cachedEnvironments = cachedUserEnvironments[CacheKeys.environments] as? [MobileKey: [String: Any]], !cachedEnvironments.isEmpty,
            let cachedUserDictionary = cachedEnvironments[mobileKey], !cachedUserDictionary.isEmpty,
            let featureFlagDictionaries = cachedUserDictionary[LDUser.CodingKeys.config.rawValue] as? [LDFlagKey: [String: Any]]
        else {
            return (nil, nil)
        }
        let featureFlags = Dictionary(uniqueKeysWithValues: featureFlagDictionaries.compactMap { flagKey, featureFlagDictionary in
            return (flagKey, FeatureFlag(flagKey: flagKey,
                                         value: featureFlagDictionary.value,
                                         variation: featureFlagDictionary.variation,
                                         version: featureFlagDictionary.version,
                                         flagVersion: featureFlagDictionary.flagVersion,
                                         trackEvents: featureFlagDictionary.trackEvents,
                                         debugEventsUntilDate: Date(millisSince1970: featureFlagDictionary.debugEventsUntilDate)))
        })
        return (featureFlags, cachedUserDictionary.lastUpdated)
    }

    func userKeys(from cachedUserData: [UserKey: [String: Any]], olderThan expirationDate: Date) -> [UserKey] {
        cachedUserData.compactMap { userKey, userDictionary in
            let envsDictionary = userDictionary[CacheKeys.environments] as? [MobileKey: [String: Any]]
            let lastUpdated = envsDictionary?.compactMap { $1.lastUpdated }.max() ?? Date.distantFuture
            return lastUpdated.isExpired(expirationDate: expirationDate) ? userKey : nil
        }
    }
}
