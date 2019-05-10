//
//  UserEnvironmentCacheModel.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 3/26/19. +JMJ
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

//Cache model in use from 2.14.0 up to 4.0.0
/*
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
                    “trackEvents”: <trackEvents>,       //LDEventTrackingContext
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

    let model = DeprecatedCacheModel.version5
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
        let featureFlags = Dictionary(uniqueKeysWithValues: featureFlagDictionaries.compactMap { (flagKey, featureFlagDictionary) in
            return (flagKey, FeatureFlag(flagKey: flagKey,
                                         value: featureFlagDictionary.value,
                                         variation: featureFlagDictionary.variation,
                                         version: featureFlagDictionary.version,
                                         flagVersion: featureFlagDictionary.flagVersion,
                                         eventTrackingContext: EventTrackingContext(dictionary: featureFlagDictionary)))
        })
        return (featureFlags, cachedUserDictionary.lastUpdated)
    }

    func userKeys(from cachedUserData: [UserKey: [String: Any]], olderThan expirationDate: Date) -> [UserKey] {
        return cachedUserData.filter { (_, userEnvironmentsDictionary) in
            let lastUpdated = userEnvironmentsDictionary.environments?.lastUpdatedDates?.youngest ?? Date.distantFuture
            return lastUpdated.isExpired(expirationDate: expirationDate)
        }.map { (userKey, _) in
            return userKey
        }
    }
}

extension Dictionary where Key == String, Value == Any {
    var environments: [MobileKey: [String: Any]]? {
        return self[DeprecatedCacheModelV5.CacheKeys.environments] as? [MobileKey: [String: Any]]
    }
}

extension Dictionary where Key == MobileKey, Value == [String: Any] {
    var lastUpdatedDates: [Date]? {
        return compactMap { (_, userDictionary) in
            return userDictionary.lastUpdated
        }
    }
}

extension Array where Element == Date {
    var youngest: Date? {
        return sorted.last
    }

    var sorted: [Date] {
        return self.sorted { (date1, date2) -> Bool in
            date1.isEarlierThan(date2)
        }
    }
}
