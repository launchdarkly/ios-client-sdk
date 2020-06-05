//
//  DeprecatedCacheModelV6.swift
//  LaunchDarkly_iOS
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

//Cache model in use from 4.3.0
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
                    “debugEventsUntilDate”: <debugEventsUntilDate>,
                    "reason": <reason>,
                    "trackReason": <trackReason>
                    ]
                ],
            “privateAttrs”: <privateAttributes>
            ]
        ]
    ]
]
*/
final class DeprecatedCacheModelV6: DeprecatedCache {

    struct CacheKeys {
        static let userEnvironments = "com.launchdarkly.dataManager.userEnvironments"
        static let environments = "environments"
    }

    let model = DeprecatedCacheModel.version6
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
            (flagKey, FeatureFlag(flagKey: flagKey,
                                  value: featureFlagDictionary.value,
                                  variation: featureFlagDictionary.variation,
                                  version: featureFlagDictionary.version,
                                  flagVersion: featureFlagDictionary.flagVersion,
                                  eventTrackingContext: EventTrackingContext(dictionary: featureFlagDictionary),
                                  reason: featureFlagDictionary.reason,
                                  trackReason: featureFlagDictionary.trackReason))
        })
        return (featureFlags, cachedUserDictionary.lastUpdated)
    }

    func userKeys(from cachedUserData: [UserKey: [String: Any]], olderThan expirationDate: Date) -> [UserKey] {
        cachedUserData.compactMap { userKey, userEnvsDictionary in
            let lastUpdated = userEnvsDictionary.environments?.lastUpdatedDates?.youngest ?? Date.distantFuture
            return lastUpdated.isExpired(expirationDate: expirationDate) ? userKey : nil
        }
    }
}

extension Dictionary where Key == String, Value == Any {
    var environments: [MobileKey: [String: Any]]? {
        self[DeprecatedCacheModelV6.CacheKeys.environments] as? [MobileKey: [String: Any]]
    }
}

extension Dictionary where Key == MobileKey, Value == [String: Any] {
    var lastUpdatedDates: [Date]? {
        compactMap { (_, userDictionary) in userDictionary.lastUpdated }
    }
}

extension Array where Element == Date {
    var youngest: Date? { sorted.last }
    var sorted: [Date] {
        self.sorted { date1, date2 -> Bool in
            date1.isEarlierThan(date2)
        }
    }
}
