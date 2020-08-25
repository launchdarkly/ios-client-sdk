//
//  KeyedValueCacheSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class KeyedValueCacheSpec: QuickSpec {
    struct Keys {
        fileprivate static let cachedUsers = "ldUserModelDictionary"
        fileprivate static let cachedFlags = "LDFlagCacheDictionary"
    }

    struct TestContext {
        var users: [LDUser]
        var userEnvironmentFlagsCollection: [UserKey: CacheableUserEnvironmentFlags]
        var mobileKeys: [MobileKey]

        var keyedValueCache: KeyedValueCaching!

        init() {
            (users, userEnvironmentFlagsCollection, mobileKeys) = CacheableUserEnvironmentFlags.stubCollection()
            keyedValueCache = UserDefaults.standard
            keyedValueCache.removeObject(forKey: Keys.cachedUsers)
            keyedValueCache.removeObject(forKey: Keys.cachedFlags)
            keyedValueCache.removeObject(forKey: UserEnvironmentFlagCache.CacheKeys.cachedUserEnvironmentFlags)
        }
    }

    override func spec() {
        var testContext: TestContext!
        var retrievedUserEnvironmentCollectionDictionary: [UserKey: Any]?
        describe("store and retrieve flags using user defaults") {
            context("with feature flags") {
                beforeEach {
                    testContext = TestContext()

                    testContext.keyedValueCache.set(testContext.userEnvironmentFlagsCollection.dictionaryValues, forKey: UserEnvironmentFlagCache.CacheKeys.cachedUserEnvironmentFlags)

                    retrievedUserEnvironmentCollectionDictionary = testContext.keyedValueCache.dictionary(forKey: UserEnvironmentFlagCache.CacheKeys.cachedUserEnvironmentFlags)
                }
                it("retrieves matching flags") {
                    expect(retrievedUserEnvironmentCollectionDictionary).toNot(beNil())
                    let retrievedUserEnvironmentsCollection = retrievedUserEnvironmentCollectionDictionary?.compactMapValues { retrievedObject in
                        CacheableUserEnvironmentFlags(object: retrievedObject)
                    }
                    expect(retrievedUserEnvironmentsCollection).toNot(beNil())
                    testContext.userEnvironmentFlagsCollection.keys.forEach { userKey in
                        let cacheableUserEnvironments = testContext.userEnvironmentFlagsCollection[userKey]!
                        let retrievedCacheableUserEnvironments = retrievedUserEnvironmentsCollection?[userKey]
                        expect(retrievedCacheableUserEnvironments?.userKey) == userKey
                        expect(retrievedCacheableUserEnvironments?.environmentFlags) == cacheableUserEnvironments.environmentFlags
                    }
                }
            }
        }
        afterEach {
            UserDefaults.standard.removeObject(forKey: UserEnvironmentFlagCache.CacheKeys.cachedUserEnvironmentFlags)
        }
    }
}
