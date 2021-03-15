//
//  KeyedValueCacheSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import XCTest

@testable import LaunchDarkly

final class KeyedValueCacheSpec: XCTestCase {
    private let cacheKey = UserEnvironmentFlagCache.CacheKeys.cachedUserEnvironmentFlags

    override func setUp() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    func testKeyValueCache() {
        let testDictionary = CacheableUserEnvironmentFlags.stubCollection().collection
        let cache: KeyedValueCaching = UserDefaults.standard
        // Returns nil when nothing stored
        XCTAssertNil(cache.dictionary(forKey: cacheKey))
        // Can store flags collection
        cache.set(testDictionary.compactMapValues { $0.dictionaryValue }, forKey: cacheKey)
        XCTAssertEqual(cache.dictionary(forKey: cacheKey)?.compactMapValues { CacheableUserEnvironmentFlags(object: $0) }, testDictionary)
        // Set nil should remove value
        cache.set(nil, forKey: cacheKey)
        XCTAssertNil(cache.dictionary(forKey: cacheKey))
        // Remove should also remove value
        cache.set(testDictionary.compactMapValues { $0.dictionaryValue }, forKey: cacheKey)
        cache.removeObject(forKey: cacheKey)
        XCTAssertNil(cache.dictionary(forKey: cacheKey))
    }
}
