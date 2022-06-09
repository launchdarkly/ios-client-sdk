import Foundation

// sourcery: autoMockable
protocol FeatureFlagCaching {
    // sourcery: defaultMockValue = KeyedValueCachingMock()
    var keyedValueCache: KeyedValueCaching { get }

    func retrieveFeatureFlags(userKey: String) -> StoredItems?
    func storeFeatureFlags(_ storedItems: StoredItems, userKey: String, lastUpdated: Date)
}

final class FeatureFlagCache: FeatureFlagCaching {
    let keyedValueCache: KeyedValueCaching
    let maxCachedUsers: Int

    init(serviceFactory: ClientServiceCreating, mobileKey: MobileKey, maxCachedUsers: Int) {
        let cacheKey: String
        if let bundleId = Bundle.main.bundleIdentifier {
            cacheKey = "\(Util.sha256base64(bundleId)).\(Util.sha256base64(mobileKey))"
        } else {
            cacheKey = Util.sha256base64(mobileKey)
        }
        self.keyedValueCache = serviceFactory.makeKeyedValueCache(cacheKey: "com.launchdarkly.client.\(cacheKey)")
        self.maxCachedUsers = maxCachedUsers
    }

    func retrieveFeatureFlags(userKey: String) -> StoredItems? {
        guard let cachedData = keyedValueCache.data(forKey: "flags-\(Util.sha256base64(userKey))"),
              let cachedFlags = try? JSONDecoder().decode(StoredItemCollection.self, from: cachedData)
        else { return nil }
        return cachedFlags.flags
    }

    func storeFeatureFlags(_ storedItems: StoredItems, userKey: String, lastUpdated: Date) {
        guard self.maxCachedUsers != 0, let encoded = try? JSONEncoder().encode(StoredItemCollection(storedItems))
        else { return }

        let userSha = Util.sha256base64(userKey)
        self.keyedValueCache.set(encoded, forKey: "flags-\(userSha)")

        var cachedUsers: [String: Int64] = [:]
        if let cacheMetadata = self.keyedValueCache.data(forKey: "cached-users") {
            cachedUsers = (try? JSONDecoder().decode([String: Int64].self, from: cacheMetadata)) ?? [:]
        }
        cachedUsers[userSha] = lastUpdated.millisSince1970
        if cachedUsers.count > self.maxCachedUsers && self.maxCachedUsers > 0 {
            let sorted = cachedUsers.sorted { $0.value < $1.value }
            sorted.prefix(cachedUsers.count - self.maxCachedUsers).forEach { sha, _ in
                cachedUsers.removeValue(forKey: sha)
                self.keyedValueCache.removeObject(forKey: "flags-\(sha)")
            }
        }
        if let encoded = try? JSONEncoder().encode(cachedUsers) {
            self.keyedValueCache.set(encoded, forKey: "cached-users")
        }
    }
}
