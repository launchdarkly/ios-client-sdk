//
//  DeprecatedCacheModelV2Spec.swift
//  LaunchDarklyTests
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class DeprecatedCacheModelV2Spec: QuickSpec {

    struct Constants {
        static let offsetInterval: TimeInterval = 0.1
    }

    struct TestContext {
        var clientServiceFactoryMock = ClientServiceMockFactory()
        var keyedValueCacheMock: KeyedValueCachingMock
        var modelV2cache: DeprecatedCacheModelV2
        var users: [LDUser]
        var userEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags]
        var uncachedUser: LDUser
        var mobileKeys: [MobileKey]
        var uncachedMobileKey: MobileKey
        var firstMobileKey: MobileKey { mobileKeys.first! }
        var sortedLastUpdatedDates: [(userKey: UserKey, lastUpdated: Date)] {
            userEnvironmentsCollection.map { ($0, $1.lastUpdated) }.sorted { tuple1, tuple2 in
                tuple1.lastUpdated.isEarlierThan(tuple2.lastUpdated)
            }
        }
        var userKeys: [UserKey] { users.map { $0.key } }

        init(userCount: Int = 0) {
            keyedValueCacheMock = clientServiceFactoryMock.makeKeyedValueCache() as! KeyedValueCachingMock
            modelV2cache = DeprecatedCacheModelV2(keyedValueCache: keyedValueCacheMock)

            (users, userEnvironmentsCollection, mobileKeys) = CacheableUserEnvironmentFlags.stubCollection(userCount: userCount)

            uncachedUser = LDUser.stub()
            uncachedMobileKey = UUID().uuidString

            keyedValueCacheMock.dictionaryReturnValue = modelV2Dictionary(for: users, and: userEnvironmentsCollection, storingMobileKey: mobileKeys.first)
        }

        func featureFlags(for userKey: UserKey) -> [LDFlagKey: FeatureFlag]? {
            userEnvironmentsCollection[userKey]?.environmentFlags[firstMobileKey]?.featureFlags.modelV2flagCollection
        }

        func modelV2Dictionary(for users: [LDUser], and userEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags], storingMobileKey: MobileKey?) -> [UserKey: Any]? {
            guard let mobileKey = storingMobileKey, !users.isEmpty
            else { return nil }

            return Dictionary(uniqueKeysWithValues: users.map { user in
                let featureFlags = userEnvironmentsCollection[user.key]?.environmentFlags[mobileKey]?.featureFlags
                let lastUpdated = userEnvironmentsCollection[user.key]?.lastUpdated
                return (user.key, user.modelV2DictionaryValue(including: featureFlags!, using: lastUpdated))
            })
        }

        func expiredUserKeys(for expirationDate: Date) -> [UserKey] {
            sortedLastUpdatedDates.compactMap { tuple in
                tuple.lastUpdated.isEarlierThan(expirationDate) ? tuple.userKey : nil
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
                it("creates a model version 2 cache with the keyed value cache") {
                    expect(testContext.modelV2cache.keyedValueCache) === testContext.keyedValueCacheMock
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

                    cachedData = testContext.modelV2cache.retrieveFlags(for: testContext.uncachedUser.key, and: testContext.uncachedMobileKey)
                }
                it("returns nil values") {
                    expect(cachedData.featureFlags).to(beNil())
                    expect(cachedData.lastUpdated).to(beNil())
                }
            }
            context("when cached data exists") {
                context("and a cached user is requested") {
                    beforeEach {
                        testContext = TestContext(userCount: LDConfig.Defaults.maxCachedUsers)
                    }
                    it("retrieves the cached data") {
                        testContext.users.forEach { user in
                            let expectedFlags = testContext.featureFlags(for: user.key)
                            let expectedLastUpdated = testContext.userEnvironmentsCollection.lastUpdated(forKey: user.key)?.stringEquivalentDate
                            testContext.mobileKeys.forEach { mobileKey in
                                cachedData = testContext.modelV2cache.retrieveFlags(for: user.key, and: mobileKey)
                                expect(cachedData.featureFlags) == expectedFlags
                                expect(cachedData.lastUpdated) == expectedLastUpdated
                            }
                        }
                    }
                }
                context("and an uncached user is requested") {
                    beforeEach {
                        testContext = TestContext(userCount: LDConfig.Defaults.maxCachedUsers)

                        cachedData = testContext.modelV2cache.retrieveFlags(for: testContext.uncachedUser.key, and: testContext.uncachedMobileKey)
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
            context("no modelV2 cached data expired") {
                beforeEach {
                    testContext = TestContext(userCount: LDConfig.Defaults.maxCachedUsers)
                    let oldestLastUpdatedDate = testContext.sortedLastUpdatedDates.first!
                    expirationDate = oldestLastUpdatedDate.lastUpdated.addingTimeInterval(-Constants.offsetInterval)

                    testContext.modelV2cache.removeData(olderThan: expirationDate)
                }
                it("does not remove any modelV2 cached data") {
                    expect(testContext.keyedValueCacheMock.setCallCount) == 0
                }
            }
            context("some modelV2 cached data expired") {
                beforeEach {
                    testContext = TestContext(userCount: LDConfig.Defaults.maxCachedUsers)
                    let selectedLastUpdatedDate = testContext.sortedLastUpdatedDates[testContext.users.count / 2]
                    expirationDate = selectedLastUpdatedDate.lastUpdated.addingTimeInterval(-Constants.offsetInterval)

                    testContext.modelV2cache.removeData(olderThan: expirationDate)
                }
                it("removes expired modelV2 cached data") {
                    expect(testContext.keyedValueCacheMock.setCallCount) == 1
                    expect(testContext.keyedValueCacheMock.setReceivedArguments?.forKey) == CacheConverter.CacheKeys.ldUserModelDictionary
                    let recachedData = testContext.keyedValueCacheMock.setReceivedArguments?.value as? [String: Any]
                    let expiredUserKeys = testContext.expiredUserKeys(for: expirationDate)
                    testContext.userKeys.forEach { userKey in
                        expect(recachedData?.keys.contains(userKey)) == !expiredUserKeys.contains(userKey)
                    }
                }
            }
            context("all modelV2 cached data expired") {
                beforeEach {
                    testContext = TestContext(userCount: LDConfig.Defaults.maxCachedUsers)
                    let newestLastUpdatedDate = testContext.sortedLastUpdatedDates.last!
                    expirationDate = newestLastUpdatedDate.lastUpdated.addingTimeInterval(Constants.offsetInterval)

                    testContext.modelV2cache.removeData(olderThan: expirationDate)
                }
                it("removes all modelV2 cached data") {
                    expect(testContext.keyedValueCacheMock.removeObjectCallCount) == 1
                    expect(testContext.keyedValueCacheMock.removeObjectReceivedForKey) == CacheConverter.CacheKeys.ldUserModelDictionary
                }
            }
            context("no modelV2 cached data exists") {
                beforeEach {
                    testContext = TestContext(userCount: LDConfig.Defaults.maxCachedUsers)
                    let newestLastUpdatedDate = testContext.sortedLastUpdatedDates.last!
                    expirationDate = newestLastUpdatedDate.lastUpdated.addingTimeInterval(Constants.offsetInterval)
                    testContext.keyedValueCacheMock.dictionaryReturnValue = nil     //mock simulates no modelV2 cached data

                    testContext.modelV2cache.removeData(olderThan: expirationDate)
                }
                it("makes no cached data changes") {
                    expect(testContext.keyedValueCacheMock.setCallCount) == 0
                }
            }
        }
    }
}

// MARK: Expected value from conversion

extension Dictionary where Key == LDFlagKey, Value == FeatureFlag {
    var modelV2flagCollection: [LDFlagKey: FeatureFlag] { compactMapValues { $0.value != nil ? $0.modelV2FeatureFlag : nil } }
}

extension FeatureFlag {
    var modelV2FeatureFlag: FeatureFlag {
        FeatureFlag(flagKey: flagKey, value: value)
    }
}

// MARK: Dictionary value to cache

extension LDUser {
    func modelV2DictionaryValue(including featureFlags: [LDFlagKey: FeatureFlag], using lastUpdated: Date?) -> [String: Any] {
        var userDictionary = dictionaryValueWithAllAttributes(includeFlagConfig: false)
        userDictionary.removeValue(forKey: LDUser.CodingKeys.privateAttributes.rawValue)
        userDictionary.setLastUpdated(lastUpdated)
        userDictionary[LDUser.CodingKeys.config.rawValue] = featureFlags.allFlagValues.withNullValuesRemoved

        return userDictionary
    }
}
