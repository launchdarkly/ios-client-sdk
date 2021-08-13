//
//  UserEnvironmentCache.swift
//  LaunchDarkly
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

enum FlagCachingStoreMode: CaseIterable {
    case async, sync
}

// sourcery: autoMockable
protocol FeatureFlagCaching {
    // sourcery: defaultMockValue = 5
    var maxCachedUsers: Int { get set }

    func retrieveFeatureFlags(forUserWithKey userKey: String, andMobileKey mobileKey: String) -> [LDFlagKey: FeatureFlag]?
    func storeFeatureFlags(_ featureFlags: [LDFlagKey: FeatureFlag], userKey: String, mobileKey: String, lastUpdated: Date, storeMode: FlagCachingStoreMode)
}

final class UserEnvironmentFlagCache: FeatureFlagCaching {

    struct Constants {
        static let cacheStoreOperationQueueLabel = "com.launchDarkly.FeatureFlagCaching.cacheStoreOperationQueue"
    }

    struct CacheKeys {
        static let cachedUserEnvironmentFlags = "com.launchDarkly.cachedUserEnvironmentFlags"
    }

    private(set) var keyedValueCache: KeyedValueCaching
    var maxCachedUsers: Int

    private static let cacheStoreOperationQueue = DispatchQueue(label: Constants.cacheStoreOperationQueueLabel, qos: .background)

    init(withKeyedValueCache keyedValueCache: KeyedValueCaching, maxCachedUsers: Int) {
        self.keyedValueCache = keyedValueCache
        self.maxCachedUsers = maxCachedUsers
    }

    func retrieveFeatureFlags(forUserWithKey userKey: String, andMobileKey mobileKey: String) -> [LDFlagKey: FeatureFlag]? {
        let cacheableUserEnvironmentsCollection = retrieveCacheableUserEnvironmentsCollection()
        return cacheableUserEnvironmentsCollection[userKey]?.environmentFlags[mobileKey]?.featureFlags
    }

    func storeFeatureFlags(_ featureFlags: [LDFlagKey: FeatureFlag], userKey: String, mobileKey: String, lastUpdated: Date, storeMode: FlagCachingStoreMode) {
        storeFeatureFlags(featureFlags, userKey: userKey, mobileKey: mobileKey, lastUpdated: lastUpdated, storeMode: storeMode, completion: nil)
    }

    func storeFeatureFlags(_ featureFlags: [LDFlagKey: FeatureFlag],
                           userKey: String,
                           mobileKey: String,
                           lastUpdated: Date,
                           storeMode: FlagCachingStoreMode = .async,
                           completion: (() -> Void)?) {
        if storeMode == .async {
            UserEnvironmentFlagCache.cacheStoreOperationQueue.async {
                self.storeFlags(featureFlags, userKey: userKey, mobileKey: mobileKey, lastUpdated: lastUpdated)
                if let completion = completion {
                    DispatchQueue.main.async(execute: completion)
                }
            }
        } else {
            UserEnvironmentFlagCache.cacheStoreOperationQueue.sync {
                self.storeFlags(featureFlags, userKey: userKey, mobileKey: mobileKey, lastUpdated: lastUpdated)
            }
        }
    }

    private func storeFlags(_ featureFlags: [LDFlagKey: FeatureFlag], userKey: String, mobileKey: String, lastUpdated: Date) {
        var cacheableUserEnvironmentsCollection = self.retrieveCacheableUserEnvironmentsCollection()
        let selectedCacheableUserEnvironments = cacheableUserEnvironmentsCollection[userKey] ?? CacheableUserEnvironmentFlags(userKey: userKey, environmentFlags: [:], lastUpdated: Date())
        var environmentFlags = selectedCacheableUserEnvironments.environmentFlags
        environmentFlags[mobileKey] = CacheableEnvironmentFlags(userKey: userKey, mobileKey: mobileKey, featureFlags: featureFlags)
        cacheableUserEnvironmentsCollection[userKey] = CacheableUserEnvironmentFlags(userKey: userKey, environmentFlags: environmentFlags, lastUpdated: lastUpdated)
        self.store(cacheableUserEnvironmentsCollection: cacheableUserEnvironmentsCollection)
    }

    // MARK: - CacheableUserEnvironmentsCollection
    private func store(cacheableUserEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags]) {
        let userEnvironmentsCollection = removeOldestUsersIfNeeded(from: cacheableUserEnvironmentsCollection)
        keyedValueCache.set(userEnvironmentsCollection.compactMapValues { $0.dictionaryValue }, forKey: CacheKeys.cachedUserEnvironmentFlags)
    }

    private func removeOldestUsersIfNeeded(from cacheableUserEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags]) -> [UserKey: CacheableUserEnvironmentFlags] {
        guard cacheableUserEnvironmentsCollection.count > maxCachedUsers && maxCachedUsers >= 0
        else {
            return cacheableUserEnvironmentsCollection
        }
        // sort collection into key-value pairs in descending order...youngest to oldest
        var userEnvironmentsCollection = cacheableUserEnvironmentsCollection.sorted { pair1, pair2 -> Bool in
            pair2.value.lastUpdated.isEarlierThan(pair1.value.lastUpdated)
        }
        while userEnvironmentsCollection.count > maxCachedUsers && maxCachedUsers >= 0 {
            userEnvironmentsCollection.removeLast()
        }
        return [UserKey: CacheableUserEnvironmentFlags](userEnvironmentsCollection, uniquingKeysWith: { value1, _ in
            value1
        })
    }

    private func retrieveCacheableUserEnvironmentsCollection() -> [UserKey: CacheableUserEnvironmentFlags] {
        keyedValueCache.dictionary(forKey: CacheKeys.cachedUserEnvironmentFlags)?.compactMapValues { CacheableUserEnvironmentFlags(object: $0) } ?? [:]
    }
}
