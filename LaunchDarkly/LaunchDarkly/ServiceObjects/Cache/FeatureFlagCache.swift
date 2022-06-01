import Foundation

// sourcery: autoMockable
protocol FeatureFlagCaching {
    // sourcery: defaultMockValue = KeyedValueCachingMock()
    var keyedValueCache: KeyedValueCaching { get }

    func retrieveFeatureFlags(contextKey: String) -> [LDFlagKey: FeatureFlag]?
    func storeFeatureFlags(_ featureFlags: [LDFlagKey: FeatureFlag], contextKey: String, lastUpdated: Date)
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

    func retrieveFeatureFlags(contextKey: String) -> [LDFlagKey: FeatureFlag]? {
        guard let cachedData = keyedValueCache.data(forKey: "flags-\(Util.sha256base64(contextKey))"),
              let cachedFlags = try? JSONDecoder().decode(FeatureFlagCollection.self, from: cachedData)
        else { return nil }
        return cachedFlags.flags
    }

    func storeFeatureFlags(_ featureFlags: [LDFlagKey: FeatureFlag], contextKey: String, lastUpdated: Date) {
        guard self.maxCachedUsers != 0, let encoded = try? JSONEncoder().encode(featureFlags)
        else { return }

        let contextSha = Util.sha256base64(contextKey)
        self.keyedValueCache.set(encoded, forKey: "flags-\(contextSha)")

        var cachedUsers: [String: Int64] = [:]
        if let cacheMetadata = self.keyedValueCache.data(forKey: "cached-users") {
            cachedUsers = (try? JSONDecoder().decode([String: Int64].self, from: cacheMetadata)) ?? [:]
        }
        cachedUsers[contextSha] = lastUpdated.millisSince1970
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
