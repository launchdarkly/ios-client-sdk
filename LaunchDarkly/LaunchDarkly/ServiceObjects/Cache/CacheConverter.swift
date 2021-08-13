//
//  CacheConverter.swift
//  LaunchDarkly
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

// sourcery: autoMockable
protocol CacheConverting {
    func convertCacheData(for user: LDUser, and config: LDConfig)
}

// CacheConverter is not thread-safe; run it from a single thread and don't allow other threads to call convertCacheData or data corruption could occur
final class CacheConverter: CacheConverting {

    struct Constants {
        static let maxAge: TimeInterval = -90.0 * 24 * 60 * 60 // 90 days
    }

    struct CacheKeys {
        static let ldUserModelDictionary = "ldUserModelDictionary"
        static let cachedDataKeyStub = "com.launchdarkly.test.deprecatedCache.cachedDataKey"
    }

    let currentCache: FeatureFlagCaching
    private(set) var deprecatedCaches = [DeprecatedCacheModel: DeprecatedCache]()

    init(serviceFactory: ClientServiceCreating, maxCachedUsers: Int) {
        currentCache = serviceFactory.makeFeatureFlagCache(maxCachedUsers: maxCachedUsers)
        DeprecatedCacheModel.allCases.forEach { version in
            deprecatedCaches[version] = serviceFactory.makeDeprecatedCacheModel(version)
        }
    }

    func convertCacheData(for user: LDUser, and config: LDConfig) {
        convertCacheData(for: user, mobileKey: config.mobileKey)
        removeData()
    }

    private func convertCacheData(for user: LDUser, mobileKey: String) {
        guard currentCache.retrieveFeatureFlags(forUserWithKey: user.key, andMobileKey: mobileKey) == nil
        else { return }
        for deprecatedCacheModel in DeprecatedCacheModel.allCases {
            let deprecatedCache = deprecatedCaches[deprecatedCacheModel]
            guard let cachedData = deprecatedCache?.retrieveFlags(for: user.key, and: mobileKey),
                let cachedFlags = cachedData.featureFlags
            else { continue }
            currentCache.storeFeatureFlags(cachedFlags, userKey: user.key, mobileKey: mobileKey, lastUpdated: cachedData.lastUpdated ?? Date(), storeMode: .sync)
            return  // If we hit on a cached user, bailout since we converted the flags for that userKey-mobileKey combination; This prefers newer caches over older
        }
    }

    private func removeData() {
        let maxAge = Date().addingTimeInterval(Constants.maxAge)
        deprecatedCaches.values.forEach { deprecatedCache in
            deprecatedCache.removeData(olderThan: maxAge)
        }
    }
}

extension Date {
    func isExpired(expirationDate: Date) -> Bool {
        let stringEquivalentDate = self.stringEquivalentDate
        let stringEquivalentExpirationDate = expirationDate.stringEquivalentDate
        return stringEquivalentDate.isEarlierThan(stringEquivalentExpirationDate)
    }
}
