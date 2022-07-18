import Foundation

// sourcery: autoMockable
protocol FeatureFlagCaching {
    // sourcery: defaultMockValue = KeyedValueCachingMock()
    var keyedValueCache: KeyedValueCaching { get }

    func retrieveFeatureFlags(contextKey: String) -> StoredItems?
    func storeFeatureFlags(_ storedItems: StoredItems, contextKey: String, lastUpdated: Date)
}

final class FeatureFlagCache: FeatureFlagCaching {
    let keyedValueCache: KeyedValueCaching
    let maxCachedContexts: Int

    init(serviceFactory: ClientServiceCreating, mobileKey: MobileKey, maxCachedContexts: Int) {
        let cacheKey: String
        if let bundleId = Bundle.main.bundleIdentifier {
            cacheKey = "\(Util.sha256base64(bundleId)).\(Util.sha256base64(mobileKey))"
        } else {
            cacheKey = Util.sha256base64(mobileKey)
        }
        self.keyedValueCache = serviceFactory.makeKeyedValueCache(cacheKey: "com.launchdarkly.client.\(cacheKey)")
        self.maxCachedContexts = maxCachedContexts
    }

    func retrieveFeatureFlags(contextKey: String) -> StoredItems? {
        guard let cachedData = keyedValueCache.data(forKey: "flags-\(contextKey)"),
              let cachedFlags = try? JSONDecoder().decode(StoredItemCollection.self, from: cachedData)
        else { return nil }
        return cachedFlags.flags
    }

    func storeFeatureFlags(_ storedItems: StoredItems, contextKey: String, lastUpdated: Date) {
        guard self.maxCachedContexts != 0, let encoded = try? JSONEncoder().encode(StoredItemCollection(storedItems))
        else { return }

        self.keyedValueCache.set(encoded, forKey: "flags-\(contextKey)")

        var cachedContexts: [String: Int64] = [:]
        if let cacheMetadata = self.keyedValueCache.data(forKey: "cached-contexts") {
            cachedContexts = (try? JSONDecoder().decode([String: Int64].self, from: cacheMetadata)) ?? [:]
        }
        cachedContexts[contextKey] = lastUpdated.millisSince1970
        if cachedContexts.count > self.maxCachedContexts && self.maxCachedContexts > 0 {
            let sorted = cachedContexts.sorted { $0.value < $1.value }
            sorted.prefix(cachedContexts.count - self.maxCachedContexts).forEach { sha, _ in
                cachedContexts.removeValue(forKey: sha)
                self.keyedValueCache.removeObject(forKey: "flags-\(sha)")
            }
        }
        if let encoded = try? JSONEncoder().encode(cachedContexts) {
            self.keyedValueCache.set(encoded, forKey: "cached-contexts")
        }
    }
}
