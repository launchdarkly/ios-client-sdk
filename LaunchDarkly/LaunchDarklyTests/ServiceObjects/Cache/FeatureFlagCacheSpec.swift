import Foundation
import XCTest

@testable import LaunchDarkly

final class FeatureFlagCacheSpec: XCTestCase {

    let testFlagCollection = StoredItemCollection(["flag1": .item(FeatureFlag(flagKey: "flag1", variation: 1, flagVersion: 2))])

    private var serviceFactory: ClientServiceMockFactory!
    private var mockValueCache: KeyedValueCachingMock { serviceFactory.makeKeyedValueCacheReturnValue }

    override func setUp() {
        serviceFactory = ClientServiceMockFactory()
    }

    func testInit() {
        let flagCache = FeatureFlagCache(serviceFactory: serviceFactory, mobileKey: "abc", maxCachedContexts: 2)
        XCTAssertEqual(flagCache.maxCachedContexts, 2)
        XCTAssertEqual(serviceFactory.makeKeyedValueCacheCallCount, 1)
        let bundleHashed = Util.sha256base64(Bundle.main.bundleIdentifier!)
        let keyHashed = Util.sha256base64("abc")
        let expectedCacheKey = "com.launchdarkly.client.\(bundleHashed).\(keyHashed)"
        XCTAssertEqual(serviceFactory.makeKeyedValueCacheReceivedCacheKey, expectedCacheKey)
        XCTAssertTrue(flagCache.keyedValueCache as? KeyedValueCachingMock === mockValueCache)
    }

    func testRetrieveNoData() {
        let flagCache = FeatureFlagCache(serviceFactory: serviceFactory, mobileKey: "abc", maxCachedContexts: 0)
        let (items, etag) = flagCache.getCachedData(cacheKey: "context1")

        XCTAssertNil(items)
        XCTAssertNil(etag)
        XCTAssertEqual(mockValueCache.dataCallCount, 1)
        XCTAssertEqual(mockValueCache.dataReceivedForKey, "flags-context1")
    }

    func testRetrieveInvalidData() {
        mockValueCache.dataReturnValue = Data("invalid".utf8)
        let flagCache = FeatureFlagCache(serviceFactory: serviceFactory, mobileKey: "abc", maxCachedContexts: 1)
        let (items, etag) = flagCache.getCachedData(cacheKey: "context1")

        XCTAssertNil(items)
        XCTAssertNil(etag)
    }

    func testRetrieveEmptyData() throws {
        mockValueCache.dataReturnValue = try JSONEncoder().encode(StoredItemCollection([:]))
        let flagCache = FeatureFlagCache(serviceFactory: serviceFactory, mobileKey: "abc", maxCachedContexts: 2)
        XCTAssertEqual(flagCache.getCachedData(cacheKey: "context1").items?.count, 0)
    }

    func testRetrieveValidData() throws {
        mockValueCache.dataReturnValue = try JSONEncoder().encode(testFlagCollection)
        let flagCache = FeatureFlagCache(serviceFactory: serviceFactory, mobileKey: "abc", maxCachedContexts: 1)
        let retrieved = flagCache.getCachedData(cacheKey: "context1")
        XCTAssertEqual(retrieved.items, testFlagCollection.flags)
        XCTAssertEqual(mockValueCache.dataCallCount, 2)
        XCTAssertEqual(mockValueCache.dataReceivedForKey, "etag-context1")
    }

    func testStoreCacheDisabled() {
        let flagCache = FeatureFlagCache(serviceFactory: serviceFactory, mobileKey: "abc", maxCachedContexts: 0)
        flagCache.saveCachedData([:], cacheKey: "context1", lastUpdated: Date(), etag: nil)
        XCTAssertEqual(mockValueCache.setCallCount, 0)
        XCTAssertEqual(mockValueCache.dataCallCount, 0)
        XCTAssertEqual(mockValueCache.removeObjectCallCount, 0)
    }

    func testStoreEmptyData() throws {
        let now = Date()
        var count = 0
        mockValueCache.setCallback = {
            if self.mockValueCache.setReceivedArguments?.forKey == "cached-contexts" {
                let setData = self.mockValueCache.setReceivedArguments!.value
                XCTAssertEqual(setData, try JSONEncoder().encode(["context1": now.millisSince1970]))
                count += 1
            } else if let received = self.mockValueCache.setReceivedArguments {
                XCTAssertEqual(received.forKey, "flags-context1")
                XCTAssertEqual(received.value, try JSONEncoder().encode(StoredItemCollection([:])))
                count += 2
            }
        }
        let flagCache = FeatureFlagCache(serviceFactory: serviceFactory, mobileKey: "abc", maxCachedContexts: -1)
        flagCache.saveCachedData([:], cacheKey: "context1", lastUpdated: now, etag: nil)
        XCTAssertEqual(count, 3)
    }

    func testStoreValidData() throws {
        mockValueCache.setCallback = {
            if let received = self.mockValueCache.setReceivedArguments, received.forKey.starts(with: "flags-") {
                XCTAssertEqual(received.value, try JSONEncoder().encode(self.testFlagCollection))
            }
        }
        let flagCache = FeatureFlagCache(serviceFactory: serviceFactory, mobileKey: "abc", maxCachedContexts: 1)
        flagCache.saveCachedData(testFlagCollection.flags, cacheKey: "context1", lastUpdated: Date(), etag: nil)
        XCTAssertEqual(mockValueCache.setCallCount, 2)
    }

    func testStoreMaxCachedContextsStored() throws {
        let hashedContextKey = Util.sha256base64("context1")
        let now = Date()
        let earlier = now.addingTimeInterval(-30.0)
        mockValueCache.dataReturnValue = try JSONEncoder().encode(["key1": earlier.millisSince1970])
        let flagCache = FeatureFlagCache(serviceFactory: serviceFactory, mobileKey: "abc", maxCachedContexts: 1)
        flagCache.saveCachedData(testFlagCollection.flags, cacheKey: hashedContextKey, lastUpdated: now, etag: nil)
        XCTAssertEqual(mockValueCache.removeObjectCallCount, 2)
        XCTAssertEqual(mockValueCache.removeObjectReceivedForKey, "etag-key1")
        let setMetadata = try JSONDecoder().decode([String: Int64].self, from: mockValueCache.setReceivedArguments!.value)
        XCTAssertEqual(setMetadata, [hashedContextKey: now.millisSince1970])
    }

    func testStoreAboveMaxCachedContextsStored() throws {
        let hashedContextKey = Util.sha256base64("context1")
        let now = Date()
        let earlier = now.addingTimeInterval(-30.0)
        let later = now.addingTimeInterval(30.0)
        mockValueCache.dataReturnValue = try JSONEncoder().encode(["key1": now.millisSince1970,
                                                                   "key2": earlier.millisSince1970,
                                                                   "key3": later.millisSince1970])
        let flagCache = FeatureFlagCache(serviceFactory: serviceFactory, mobileKey: "abc", maxCachedContexts: 2)
        var removedObjects: [String] = []
        mockValueCache.removeObjectCallback = { removedObjects.append(self.mockValueCache.removeObjectReceivedForKey!) }
        flagCache.saveCachedData(testFlagCollection.flags, cacheKey: hashedContextKey, lastUpdated: later, etag: nil)
        XCTAssertEqual(mockValueCache.removeObjectCallCount, 4)
        XCTAssertTrue(removedObjects.contains("flags-key1"))
        XCTAssertTrue(removedObjects.contains("etag-key1"))
        XCTAssertTrue(removedObjects.contains("flags-key2"))
        XCTAssertTrue(removedObjects.contains("etag-key2"))
        let setMetadata = try JSONDecoder().decode([String: Int64].self, from: mockValueCache.setReceivedArguments!.value)
        XCTAssertEqual(setMetadata, [hashedContextKey: later.millisSince1970, "key3": later.millisSince1970])
    }

    func testStoreInvalidMetadataStored() throws {
        let hashedContxtKey = Util.sha256base64("context1")
        let now = Date()
        mockValueCache.dataReturnValue = try JSONEncoder().encode(["key1": "123"])
        let flagCache = FeatureFlagCache(serviceFactory: serviceFactory, mobileKey: "abc", maxCachedContexts: 1)
        flagCache.saveCachedData(testFlagCollection.flags, cacheKey: hashedContxtKey, lastUpdated: now, etag: nil)
        XCTAssertEqual(mockValueCache.removeObjectCallCount, 0)
        let setMetadata = try JSONDecoder().decode([String: Int64].self, from: mockValueCache.setReceivedArguments!.value)
        XCTAssertEqual(setMetadata, [hashedContxtKey: now.millisSince1970])
    }
}
