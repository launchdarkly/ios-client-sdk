//
//  DeprecatedCacheModelV6Spec.swift
//  LaunchDarklyTests
//
//  Created by Joe Cieslik on 11/25/19.
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class DeprecatedCacheModelV6Spec: QuickSpec {
    
    struct Constants {
        static let offsetInterval: TimeInterval = 0.1
    }
    
    struct TestContext {
        var clientServiceFactoryMock = ClientServiceMockFactory()
        var keyedValueCacheMock: KeyedValueCachingMock
        var modelV6cache: DeprecatedCacheModelV6
        var users: [LDUser]
        var userEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags]
        var uncachedUser: LDUser
        var mobileKeys: [MobileKey]
        var uncachedMobileKey: MobileKey
        var lastUpdatedDates: [UserKey: Date] {
            return userEnvironmentsCollection.compactMapValues { (cacheableUserFlags)  in
                return cacheableUserFlags.lastUpdated
            }
        }
        var sortedLastUpdatedDates: [(userKey: UserKey, lastUpdated: Date)] {
            return lastUpdatedDates.map { (userKey, lastUpdated) in
                return (userKey, lastUpdated)
            }.sorted { (tuple1, tuple2) in
                return tuple1.lastUpdated.isEarlierThan(tuple2.lastUpdated)
            }
        }
        var userKeys: [UserKey] {
            return users.map { (user) in
                return user.key
            }
        }
        
        init(userCount: Int = 0) {
            keyedValueCacheMock = clientServiceFactoryMock.makeKeyedValueCache() as! KeyedValueCachingMock
            modelV6cache = DeprecatedCacheModelV6(keyedValueCache: keyedValueCacheMock)
            
            (users, userEnvironmentsCollection, mobileKeys) = CacheableUserEnvironmentFlags.stubCollection(userCount: userCount)
            
            uncachedUser = LDUser.stub()
            uncachedMobileKey = UUID().uuidString
            
            keyedValueCacheMock.dictionaryReturnValue = modelV6Dictionary(for: users, and: userEnvironmentsCollection, mobileKeys: mobileKeys)
        }
        
        func featureFlags(for userKey: UserKey, and mobileKey: MobileKey) -> [LDFlagKey: FeatureFlag]? {
            return userEnvironmentsCollection[userKey]?.environmentFlags[mobileKey]?.featureFlags.modelV6flagCollection
        }
        
        func modelV6Dictionary(for users: [LDUser], and userEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags], mobileKeys: [MobileKey]) -> [UserKey: Any]? {
            guard !users.isEmpty
            else {
                return nil
            }
            
            var cacheDictionary = [UserKey: [String: Any]]()
            users.forEach { (user) in
                guard let userEnvironment = userEnvironmentsCollection[user.key]
                else {
                    return
                }
                var environmentsDictionary = [MobileKey: Any]()
                let lastUpdated = userEnvironmentsCollection[user.key]?.lastUpdated
                mobileKeys.forEach { (mobileKey) in
                    guard let featureFlags = userEnvironment.environmentFlags[mobileKey]?.featureFlags
                    else {
                        return
                    }
                    environmentsDictionary[mobileKey] = user.modelV6DictionaryValue(including: featureFlags, using: lastUpdated)
                }
                cacheDictionary[user.key] = [CacheableEnvironmentFlags.CodingKeys.userKey.rawValue: user.key,
                                             DeprecatedCacheModelV6.CacheKeys.environments: environmentsDictionary]
            }
            return cacheDictionary
        }
        
        func expiredUserKeys(for expirationDate: Date) -> [UserKey] {
            return sortedLastUpdatedDates.compactMap { (tuple) in
                guard tuple.lastUpdated.isEarlierThan(expirationDate)
                else {
                    return nil
                }
                return tuple.userKey
            }
        }
    }
    
    override func spec() {
        initSpec()
        retrieveFlagsSpec()
        removeDataSpec()
    }
    
    private func initSpec() {
        var testContext: TestContext!
        describe("init") {
            context("with keyed value cache") {
                beforeEach {
                    testContext = TestContext()
                }
                it("creates a model version 6 cache with the keyed value cache") {
                    expect(testContext.modelV6cache.keyedValueCache) === testContext.keyedValueCacheMock
                }
            }
        }
    }
    
    private func retrieveFlagsSpec() {
        var testContext: TestContext!
        var cachedData: (featureFlags: [LDFlagKey: FeatureFlag]?, lastUpdated: Date?)!
        describe("retrieveFlags") {
            context("when no cached data exists") {
                beforeEach {
                    testContext = TestContext()
                    
                    cachedData = testContext.modelV6cache.retrieveFlags(for: testContext.uncachedUser.key, and: testContext.uncachedMobileKey)
                }
                it("returns nil values") {
                    expect(cachedData.featureFlags).to(beNil())
                    expect(cachedData.lastUpdated).to(beNil())
                }
            }
            context("when cached data exists") {
                context("and a cached user is requested") {
                    beforeEach {
                        testContext = TestContext(userCount: UserEnvironmentFlagCache.Constants.maxCachedUsers)
                    }
                    it("retrieves the cached data") {
                        testContext.users.forEach { (user) in
                            let expectedLastUpdated = testContext.userEnvironmentsCollection.lastUpdated(forKey: user.key)?.stringEquivalentDate
                            testContext.mobileKeys.forEach { (mobileKey) in
                                let expectedFlags = testContext.featureFlags(for: user.key, and: mobileKey)
                                cachedData = testContext.modelV6cache.retrieveFlags(for: user.key, and: mobileKey)
                                expect(cachedData.featureFlags) == expectedFlags
                                expect(cachedData.lastUpdated) == expectedLastUpdated
                            }
                        }
                    }
                }
                context("and an uncached mobileKey is requested") {
                    beforeEach {
                        testContext = TestContext(userCount: UserEnvironmentFlagCache.Constants.maxCachedUsers)
                        
                        cachedData = testContext.modelV6cache.retrieveFlags(for: testContext.users.first!.key, and: testContext.uncachedMobileKey)
                    }
                    it("returns nil values") {
                        expect(cachedData.featureFlags).to(beNil())
                        expect(cachedData.lastUpdated).to(beNil())
                    }
                }
                context("and an uncached user is requested") {
                    beforeEach {
                        testContext = TestContext(userCount: UserEnvironmentFlagCache.Constants.maxCachedUsers)
                        
                        cachedData = testContext.modelV6cache.retrieveFlags(for: testContext.uncachedUser.key, and: testContext.mobileKeys.first!)
                    }
                    it("returns nil values") {
                        expect(cachedData.featureFlags).to(beNil())
                        expect(cachedData.lastUpdated).to(beNil())
                    }
                }
            }
        }
    }
    
    private func removeDataSpec() {
        var testContext: TestContext!
        var expirationDate: Date!
        describe("removeData") {
            context("no modelV6 cached data expired") {
                beforeEach {
                    testContext = TestContext(userCount: UserEnvironmentFlagCache.Constants.maxCachedUsers)
                    let oldestLastUpdatedDate = testContext.sortedLastUpdatedDates.first!
                    expirationDate = oldestLastUpdatedDate.lastUpdated.addingTimeInterval(-Constants.offsetInterval)
                    
                    testContext.modelV6cache.removeData(olderThan: expirationDate)
                }
                it("does not remove any modelV6 cached data") {
                    expect(testContext.keyedValueCacheMock.setCallCount) == 0
                }
            }
            context("some modelV6 cached data expired") {
                beforeEach {
                    testContext = TestContext(userCount: UserEnvironmentFlagCache.Constants.maxCachedUsers)
                    let selectedLastUpdatedDate = testContext.sortedLastUpdatedDates[testContext.users.count / 2]
                    expirationDate = selectedLastUpdatedDate.lastUpdated.addingTimeInterval(-Constants.offsetInterval)
                    
                    testContext.modelV6cache.removeData(olderThan: expirationDate)
                }
                it("removes expired modelV6 cached data") {
                    expect(testContext.keyedValueCacheMock.setCallCount) == 1
                    expect(testContext.keyedValueCacheMock.setReceivedArguments?.forKey) == DeprecatedCacheModelV6.CacheKeys.userEnvironments
                    let recachedData = testContext.keyedValueCacheMock.setReceivedArguments?.value as? [String: Any]
                    let expiredUserKeys = testContext.expiredUserKeys(for: expirationDate)
                    testContext.userKeys.forEach { (userKey) in
                        expect(recachedData?.keys.contains(userKey)) == !expiredUserKeys.contains(userKey)
                    }
                }
            }
            context("all modelV6 cached data expired") {
                beforeEach {
                    testContext = TestContext(userCount: UserEnvironmentFlagCache.Constants.maxCachedUsers)
                    let newestLastUpdatedDate = testContext.sortedLastUpdatedDates.last!
                    expirationDate = newestLastUpdatedDate.lastUpdated.addingTimeInterval(Constants.offsetInterval)
                    
                    testContext.modelV6cache.removeData(olderThan: expirationDate)
                }
                it("removes all modelV6 cached data") {
                    expect(testContext.keyedValueCacheMock.removeObjectCallCount) == 1
                    expect(testContext.keyedValueCacheMock.removeObjectReceivedForKey) == DeprecatedCacheModelV6.CacheKeys.userEnvironments
                }
            }
            context("no modelV6 cached data exists") {
                beforeEach {
                    testContext = TestContext(userCount: UserEnvironmentFlagCache.Constants.maxCachedUsers)
                    let newestLastUpdatedDate = testContext.sortedLastUpdatedDates.last!
                    expirationDate = newestLastUpdatedDate.lastUpdated.addingTimeInterval(Constants.offsetInterval)
                    testContext.keyedValueCacheMock.dictionaryReturnValue = nil     //mock simulates no modelV6 cached data
                    
                    testContext.modelV6cache.removeData(olderThan: expirationDate)
                }
                it("makes no cached data changes") {
                    expect(testContext.keyedValueCacheMock.setCallCount) == 0
                }
            }
        }
    }
    
}

extension Dictionary where Key == LDFlagKey, Value == FeatureFlag {
    var modelV6flagCollection: [LDFlagKey: FeatureFlag] {
        return compactMapValues { (originalFeatureFlag) in
            guard originalFeatureFlag.value != nil
                else {
                    return nil
            }
            return originalFeatureFlag
        }
    }
}

extension LDUser {
    func modelV6DictionaryValue(including featureFlags: [LDFlagKey: FeatureFlag], using lastUpdated: Date?) -> [String: Any] {
        var userDictionary = dictionaryValueWithAllAttributes(includeFlagConfig: false)
        userDictionary.setLastUpdated(lastUpdated)
        userDictionary[LDUser.CodingKeys.config.rawValue] = featureFlags.compactMapValues { (featureFlag) in
            return featureFlag.modelV6dictionaryValue
        }
        
        return userDictionary
    }
}

extension FeatureFlag {
    var modelV6dictionaryValue: [String: Any]? {
        guard value != nil
            else {
                return nil
        }
        return dictionaryValue
    }
}
