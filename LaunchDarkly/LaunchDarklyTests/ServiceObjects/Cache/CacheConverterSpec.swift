import Foundation
import XCTest

@testable import LaunchDarkly

final class CacheConverterSpec: XCTestCase {

    private var serviceFactory: ClientServiceMockFactory!

    private static var upToDateData: Data!

    override class func setUp() {
        upToDateData = try! JSONEncoder().encode(["version": 7])
    }

    override func setUp() {
        serviceFactory = ClientServiceMockFactory()
    }

    func testNoKeysGiven() {
        CacheConverter().convertCacheData(serviceFactory: serviceFactory, keysToConvert: [], maxCachedUsers: 0)
        XCTAssertEqual(serviceFactory.makeKeyedValueCacheCallCount, 0)
        XCTAssertEqual(serviceFactory.makeFeatureFlagCacheCallCount, 0)
    }

    func testUpToDate() {
        let v7valueCacheMock = KeyedValueCachingMock()
        serviceFactory.makeFeatureFlagCacheReturnValue.keyedValueCache = v7valueCacheMock
        v7valueCacheMock.dataReturnValue = CacheConverterSpec.upToDateData
        CacheConverter().convertCacheData(serviceFactory: serviceFactory, keysToConvert: ["key1", "key2"], maxCachedUsers: 0)
        XCTAssertEqual(serviceFactory.makeFeatureFlagCacheCallCount, 2)
        XCTAssertEqual(v7valueCacheMock.dataCallCount, 2)
    }
}
