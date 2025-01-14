import Foundation

// sourcery: autoMockable
protocol FeatureFlagCaching {
    // sourcery: defaultMockValue = KeyedValueCachingMock()
    var keyedValueCache: KeyedValueCaching { get }

    /// Retrieve all cached data for the given cache key.
    ///
    /// The cache key is used as the index into the cache. Values retrieved
    /// using this cache key should be loaded into the store and favored over
    /// the default values.
    ///
    /// The context hash value is used to determine if the cache is considered
    /// out of date. If the hash saved alongside the cached value does not
    /// match, then the cache's etag and lastUpdated responses should be nil as
    /// they are invalid.
    ///
    /// If the hash hasn't changed, then the cache is still considered accurate
    /// and the associated etag and last updated values are meaningful and can
    /// be returned.
    ///
    /// - parameter cacheKey: The index key into the local cache store.
    /// - parameter contextHash: A hash value representing a fully unique context.
    ///
    /// - returns: Returns a tuple of cached value information.
    ///     items: This is the associated flag evaluation results associated with this context.
    ///     etag: The last known e-tag value from a polling request (see saveCachedData
    ///           comments) for more informmation.
    ///     lastUpdated: The date the cache was last considered up-to-date. If there are no cached
    ///            values, this should return nil.
    ///
    ///
    func getCachedData(cacheKey: String, contextHash: String) -> (items: StoredItems?, etag: String?, lastUpdated: Date?)

    /// Retrieve the date the cache for the given key was last updated. See getCachedData for more information.
    ///
    /// - parameter cacheKey: The index key into the local cache store.
    /// - parameter contextHash: A hash value representing a fully unique context.
    ///
    /// - returns: The date the cache was last considered up-to-date. If there are no cached
    ///            values, this should return nil.
    func getCachedDataLastUpdatedDate(cacheKey: String, contextHash: String) -> Date?

    // When we update the cache, we save the flag data and if we have it, an
    // etag. For polling, we should always have the flag data and an etag
    // value. This is not the case for streaming.
    //
    // Streaming will provide the flag values, but it will not include an e-tag
    // header value. Even if the stream did, we don't have any guarantees that
    // the e-tag between streaming and polling would be comparable.
    //
    // If we detect that no e-tag value was provided, instead of removing that
    // cached value, we will leave the last known e-tag value. This is safe
    // because either:
    //
    // 1. No updates have been made between the last polling e-tag header and
    //    the streaming connection, at which point the e-tag is still valid, or
    //
    // 2. Updates have been made at which point the e-tag will be ignored
    //    upstream and we will still receive updated information as expected.
    //
    // The context hash is stored alongside the stored items. This is used as a
    // marker to determine when the values are useful but not potentially
    // accurate.
    func saveCachedData(_ storedItems: StoredItems, cacheKey: String, contextHash: String, lastUpdated: Date, etag: String?)
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

    func getCachedData(cacheKey: String, contextHash: String) -> (items: StoredItems?, etag: String?, lastUpdated: Date?) {

        guard let cachedFlagsData = keyedValueCache.data(forKey: "flags-\(cacheKey)"),
              let cachedFlags = try? JSONDecoder().decode(StoredItemCollection.self, from: cachedFlagsData)
        else { return (items: nil, etag: nil, lastUpdated: nil) }

        guard let cachedContextHashData = keyedValueCache.data(forKey: "fingerprint-\(cacheKey)"),
              let cachedContextHash = try? JSONDecoder().decode(String.self, from: cachedContextHashData)
        else { return (items: cachedFlags.flags, etag: nil, lastUpdated: nil) }

        guard cachedContextHash == contextHash
        else { return (items: cachedFlags.flags, etag: nil, lastUpdated: nil) }

        guard let cachedETagData = keyedValueCache.data(forKey: "etag-\(cacheKey)"),
              let etag = try? JSONDecoder().decode(String.self, from: cachedETagData)
        else { return (items: cachedFlags.flags, etag: nil, lastUpdated: nil) }

        var cachedContexts: [String: Int64] = [:]
        if let cacheMetadata = keyedValueCache.data(forKey: "cached-contexts") {
            cachedContexts = (try? JSONDecoder().decode([String: Int64].self, from: cacheMetadata)) ?? [:]
        }

        guard let lastUpdated = cachedContexts[cacheKey]
        else { return (items: cachedFlags.flags, etag: etag, lastUpdated: nil) }

        return (items: cachedFlags.flags, etag: etag, lastUpdated: Date(timeIntervalSince1970: TimeInterval(lastUpdated / 1_000)))
    }

    func getCachedDataLastUpdatedDate(cacheKey: String, contextHash: String) -> Date? {

        var cachedContexts: [String: Int64] = [:]
        if let cacheMetadata = keyedValueCache.data(forKey: "cached-contexts") {
            cachedContexts = (try? JSONDecoder().decode([String: Int64].self, from: cacheMetadata)) ?? [:]
        }

        guard let lastUpdated = cachedContexts[cacheKey]
        else { return nil }

        return Date(timeIntervalSince1970: TimeInterval(lastUpdated / 1_000))
    }

    func saveCachedData(_ storedItems: StoredItems, cacheKey: String, contextHash: String, lastUpdated: Date, etag: String?) {

        guard self.maxCachedContexts != 0, let encoded = try? JSONEncoder().encode(StoredItemCollection(storedItems))
        else { return }

        self.keyedValueCache.set(encoded, forKey: "flags-\(cacheKey)")

        if let encodedContextHashData = try? JSONEncoder().encode(contextHash) {
            self.keyedValueCache.set(encodedContextHashData, forKey: "fingerprint-\(cacheKey)")

            if let tag = etag, let encodedCachedData = try? JSONEncoder().encode(tag) {
                self.keyedValueCache.set(encodedCachedData, forKey: "etag-\(cacheKey)")
            }
        }

        var cachedContexts: [String: Int64] = [:]
        if let cacheMetadata = self.keyedValueCache.data(forKey: "cached-contexts") {
            cachedContexts = (try? JSONDecoder().decode([String: Int64].self, from: cacheMetadata)) ?? [:]
        }
        cachedContexts[cacheKey] = lastUpdated.millisSince1970
        if cachedContexts.count > self.maxCachedContexts && self.maxCachedContexts > 0 {
            let sorted = cachedContexts.sorted { $0.value < $1.value }
            sorted.prefix(cachedContexts.count - self.maxCachedContexts).forEach { sha, _ in
                cachedContexts.removeValue(forKey: sha)
                self.keyedValueCache.removeObject(forKey: "flags-\(sha)")
                self.keyedValueCache.removeObject(forKey: "etag-\(sha)")
                self.keyedValueCache.removeObject(forKey: "fingerprint-\(sha)")
            }
        }
        if let encoded = try? JSONEncoder().encode(cachedContexts) {
            self.keyedValueCache.set(encoded, forKey: "cached-contexts")
        }
    }
}
