//
//  UserEnvironmentCache.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 3/20/19. +JMJ
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

enum FlagCachingStoreMode: CaseIterable {
    case async, sync
}

//sourcery: autoMockable
protocol FeatureFlagCaching {
    func retrieveFeatureFlags(forUserWithKey userKey: String, andMobileKey mobileKey: String) -> [LDFlagKey: FeatureFlag]?
    func storeFeatureFlags(_ featureFlags: [LDFlagKey: FeatureFlag], forUser user: LDUser, andMobileKey mobileKey: String, lastUpdated: Date, storeMode: FlagCachingStoreMode)
}

final class UserEnvironmentFlagCache: FeatureFlagCaching {

    struct Constants {
        static let cacheStoreOperationQueueLabel = "com.launchDarkly.FeatureFlagCaching.cacheStoreOperationQueue"
        static let maxCachedUsers = 5
    }

    struct CacheKeys {
        static let cachedUserEnvironmentFlags = "com.launchDarkly.cachedUserEnvironmentFlags"
    }

    private(set) var keyedValueCache: KeyedValueCaching

    static private let cacheStoreOperationQueue = DispatchQueue(label: Constants.cacheStoreOperationQueueLabel, qos: .background)

    init(withKeyedValueCache keyedValueCache: KeyedValueCaching) {
        self.keyedValueCache = keyedValueCache
    }

    func retrieveFeatureFlags(forUserWithKey userKey: String, andMobileKey mobileKey: String) -> [LDFlagKey: FeatureFlag]? {
        let cacheableUserEnvironmentsCollection = retrieveCacheableUserEnvironmentsCollection()
        return cacheableUserEnvironmentsCollection[userKey]?.environmentFlags[mobileKey]?.featureFlags
    }

    func storeFeatureFlags(_ featureFlags: [LDFlagKey: FeatureFlag], forUser user: LDUser, andMobileKey mobileKey: String, lastUpdated: Date) {
        storeFeatureFlags(featureFlags, forUser: user, andMobileKey: mobileKey, lastUpdated: lastUpdated, completion: nil)
    }

    func storeFeatureFlags(_ featureFlags: [LDFlagKey: FeatureFlag], forUser user: LDUser, andMobileKey mobileKey: String, lastUpdated: Date, storeMode: FlagCachingStoreMode) {
        storeFeatureFlags(featureFlags, forUser: user, andMobileKey: mobileKey, lastUpdated: lastUpdated, storeMode: storeMode, completion: nil)
    }

    func storeFeatureFlags(_ featureFlags: [LDFlagKey: FeatureFlag],
                           forUser user: LDUser,
                           andMobileKey mobileKey: String,
                           lastUpdated: Date,
                           storeMode: FlagCachingStoreMode = .async,
                           completion: (() -> Void)?) {
        if storeMode == .async {
            UserEnvironmentFlagCache.cacheStoreOperationQueue.async {
                self.storeFlags(featureFlags, forUser: user, andMobileKey: mobileKey, lastUpdated: lastUpdated)
                if let completion = completion {
                    DispatchQueue.main.async(execute: completion)
                }
            }
        } else {
            UserEnvironmentFlagCache.cacheStoreOperationQueue.sync {
                self.storeFlags(featureFlags, forUser: user, andMobileKey: mobileKey, lastUpdated: lastUpdated)
            }
        }
    }

    private func storeFlags(_ featureFlags: [LDFlagKey: FeatureFlag], forUser user: LDUser, andMobileKey mobileKey: String, lastUpdated: Date) {
        var cacheableUserEnvironmentsCollection = self.retrieveCacheableUserEnvironmentsCollection()
        let selectedCacheableUserEnvironments = cacheableUserEnvironmentsCollection[user.key] ?? CacheableUserEnvironmentFlags(userKey: user.key, environmentFlags: [:], lastUpdated: Date())
        var environmentFlags = selectedCacheableUserEnvironments.environmentFlags
        environmentFlags[mobileKey] = CacheableEnvironmentFlags(userKey: user.key, mobileKey: mobileKey, featureFlags: featureFlags)
        cacheableUserEnvironmentsCollection[user.key] = CacheableUserEnvironmentFlags(userKey: user.key, environmentFlags: environmentFlags, lastUpdated: lastUpdated)
        self.store(cacheableUserEnvironmentsCollection: cacheableUserEnvironmentsCollection)
    }

    // MARK: - CacheableUserEnvironmentsCollection
    private func store(cacheableUserEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags]) {
        let userEnvironmentsCollection = removeOldestUsersIfNeeded(from: cacheableUserEnvironmentsCollection)
        keyedValueCache.set(userEnvironmentsCollection.dictionaryValues, forKey: CacheKeys.cachedUserEnvironmentFlags)
    }

    private func removeOldestUsersIfNeeded(from cacheableUserEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags]) -> [UserKey: CacheableUserEnvironmentFlags] {
        guard cacheableUserEnvironmentsCollection.count > Constants.maxCachedUsers
        else {
            return cacheableUserEnvironmentsCollection
        }
        //sort collection into key-value pairs in descending order...youngest to oldest
        var userEnvironmentsCollection = cacheableUserEnvironmentsCollection.sorted { (pair1, pair2) -> Bool in
            return pair2.value.lastUpdated.isEarlierThan(pair1.value.lastUpdated)
        }
        while userEnvironmentsCollection.count > Constants.maxCachedUsers {
            userEnvironmentsCollection.removeLast()
        }
        return [UserKey: CacheableUserEnvironmentFlags](userEnvironmentsCollection, uniquingKeysWith: { (value1, _) in
            return value1
        })
    }

    private func retrieveCacheableUserEnvironmentsCollection() -> [UserKey: CacheableUserEnvironmentFlags] {
        guard let retrievedCollection = keyedValueCache.dictionary(forKey: CacheKeys.cachedUserEnvironmentFlags),
            let cacheableUserEnvironmentsCollection = CacheableUserEnvironmentFlags.makeCollection(from: retrievedCollection)
        else {
            return [:]
        }
        return cacheableUserEnvironmentsCollection
    }
}
