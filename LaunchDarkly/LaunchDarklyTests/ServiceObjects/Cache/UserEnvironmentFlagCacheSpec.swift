//
//  UserEnvironmentCacheSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class UserEnvironmentFlagCacheSpec: QuickSpec {

    struct Constants {
        static let newFlagKey = "newFlagKey"
        static let newFlagValue = "newFlagValue"
    }

    struct TestContext {
        var keyedValueCacheMock = KeyedValueCachingMock()
        var userEnvironmentFlagCache: UserEnvironmentFlagCache
        var users: [LDUser]
        var userEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags]
        var mobileKeys = Set<MobileKey>()
        var selectedUser: LDUser {
            users.selectedUser
        }
        var selectedMobileKey: String {
            userEnvironmentsCollection[selectedUser.key]!.environmentFlags.keys.selectedMobileKey
        }
        var oldestUser: LDUser {
            //sort <userKey, lastUpdated> pairs youngest to oldest
            let sortedLastUpdatedPairs = userEnvironmentsCollection.compactMapValues { cacheableUserEnvironments in
                return cacheableUserEnvironments.lastUpdated
            }.sorted { pair1, pair2 -> Bool in
                return pair2.value.isEarlierThan(pair1.value)
            }
            let oldestUserKey = sortedLastUpdatedPairs.last!.key
            return users.first { user in
                user.key == oldestUserKey
            }!
        }

        init(userCount: Int = 1, maxUsers: Int = 5) {
            userEnvironmentFlagCache = UserEnvironmentFlagCache(withKeyedValueCache: keyedValueCacheMock, maxCachedUsers: maxUsers)
            let mobileKeys: [MobileKey]
            (users, userEnvironmentsCollection, mobileKeys) = CacheableUserEnvironmentFlags.stubCollection(userCount: userCount)
            self.mobileKeys.formUnion(Set(mobileKeys))
            keyedValueCacheMock.dictionaryReturnValue = userEnvironmentsCollection.dictionaryValues
        }

        func featureFlags(forUserKey userKey: UserKey, andMobileKey mobileKey: MobileKey) -> [LDFlagKey: FeatureFlag]? {
            userEnvironmentsCollection[userKey]?.environmentFlags[mobileKey]?.featureFlags
        }

        func storeFlags(_ featureFlags: [LDFlagKey: FeatureFlag],
                        forUser user: LDUser,
                        andMobileKey mobileKey: String,
                        lastUpdated: Date,
                        storeMode: FlagCachingStoreMode = .async) {
            switch storeMode {
            case .async:
                waitUntil { done in
                    self.userEnvironmentFlagCache.storeFeatureFlags(featureFlags,
                                                                    forUser: user,
                                                                    andMobileKey: mobileKey,
                                                                    lastUpdated: lastUpdated,
                                                                    storeMode: .async,
                                                                    completion: {
                        done()
                    })
                }
            case .sync:
                self.userEnvironmentFlagCache.storeFeatureFlags(featureFlags,
                                                                forUser: user,
                                                                andMobileKey: mobileKey,
                                                                lastUpdated: lastUpdated,
                                                                storeMode: .async,
                                                                completion: nil)
            }
        }
    }

    override func spec() {
        initSpec()
        retrieveFeatureFlagsSpec()
        storeFeatureFlagsSpec(maxUsers: LDConfig.Defaults.maxCachedUsers)
        storeFeatureFlagsSpec(maxUsers: 3)
        storeUnlimitedUsersSpec(maxUsers: -1)
    }

    private func initSpec() {
        var testContext: TestContext!
        describe("init") {
            context("with keyedValueCache") {
                beforeEach {
                    testContext = TestContext()
                }
                it("creates a UserEnvironmentCache with the passed in keyedValueCache") {
                    expect(testContext.userEnvironmentFlagCache.keyedValueCache) === testContext.keyedValueCacheMock
                }
            }
        }
    }

    private func retrieveFeatureFlagsSpec() {
        var testContext: TestContext!
        var retrievingUser: LDUser!
        var retrievingMobileKey: MobileKey!
        var retrievedFlags: [LDFlagKey: FeatureFlag]?
        describe("retrieveFeatureFlags") {
            context("when no feature flags are stored") {
                beforeEach {
                    testContext = TestContext(userCount: 0)
                    retrievingUser = LDUser.stub()
                    retrievingMobileKey = UUID().uuidString

                    retrievedFlags = testContext.userEnvironmentFlagCache.retrieveFeatureFlags(forUserWithKey: retrievingUser.key, andMobileKey: retrievingMobileKey)
                }
                it("returns nil") {
                    expect(retrievedFlags).to(beNil())
                }
            }
            context("when feature flags are stored") {
                context("the user is stored") {
                    context("and the environment is stored") {
                        beforeEach {
                            testContext = TestContext(userCount: LDConfig.Defaults.maxCachedUsers)
                            retrievingUser = testContext.selectedUser
                            retrievingMobileKey = testContext.selectedMobileKey

                            retrievedFlags = testContext.userEnvironmentFlagCache.retrieveFeatureFlags(forUserWithKey: retrievingUser.key, andMobileKey: retrievingMobileKey)
                        }
                        it("returns the feature flags") {
                            expect(retrievedFlags) == testContext.userEnvironmentsCollection[retrievingUser.key]?.environmentFlags[retrievingMobileKey]?.featureFlags
                        }
                    }
                    context("and the environment is not stored") {
                        beforeEach {
                            testContext = TestContext(userCount: LDConfig.Defaults.maxCachedUsers)
                            retrievingUser = testContext.selectedUser
                            retrievingMobileKey = (CacheableUserEnvironmentFlags.Constants.environmentCount + 1).mobileKey

                            retrievedFlags = testContext.userEnvironmentFlagCache.retrieveFeatureFlags(forUserWithKey: retrievingUser.key, andMobileKey: retrievingMobileKey)
                        }
                        it("returns nil") {
                            expect(retrievedFlags).to(beNil())
                        }
                    }
                }
                context("the user is not stored") {
                    beforeEach {
                        testContext = TestContext(userCount: LDConfig.Defaults.maxCachedUsers)
                        retrievingUser = LDUser.stub()
                        retrievingMobileKey = testContext.selectedMobileKey

                        retrievedFlags = testContext.userEnvironmentFlagCache.retrieveFeatureFlags(forUserWithKey: retrievingUser.key, andMobileKey: retrievingMobileKey)
                    }
                    it("returns nil") {
                        expect(retrievedFlags).to(beNil())
                    }
                }
            }
        }
    }
    
    private func storeUnlimitedUsersSpec(maxUsers: Int) {
        var testContext: TestContext!
        var storingUser: LDUser!
        var storingMobileKey: String!
        var storingLastUpdated: Date!
        var userCount: Int!
        var newFeatureFlags: [LDFlagKey: FeatureFlag]!
        
        context("and an existing user adds a new environment") {
            beforeEach {
                userCount = 5
                testContext = TestContext(userCount: userCount, maxUsers: maxUsers)
                storingUser = testContext.selectedUser
                storingMobileKey = (CacheableUserEnvironmentFlags.Constants.environmentCount + 1).mobileKey
                newFeatureFlags = [Constants.newFlagKey: FeatureFlag.stub(flagKey: Constants.newFlagKey, flagValue: Constants.newFlagValue)]
                storingLastUpdated = Date()
            }
            it("stores the users flags") {
                FlagCachingStoreMode.allCases.forEach { storeMode in
                    testContext.storeFlags(newFeatureFlags,
                                           forUser: storingUser,
                                           andMobileKey: storingMobileKey,
                                           lastUpdated: storingLastUpdated,
                                           storeMode: storeMode)

                    expect(testContext.keyedValueCacheMock.setReceivedArguments?.forKey) == UserEnvironmentFlagCache.CacheKeys.cachedUserEnvironmentFlags

                    let setCachedUserEnvironmentsCollection = testContext.keyedValueCacheMock.setReceivedArguments?.value as? [UserKey: [String: Any]]
                    expect(setCachedUserEnvironmentsCollection?.count) == userCount
                    testContext.users.forEach { user in
                        expect(setCachedUserEnvironmentsCollection?.keys.contains(user.key)) == true

                        let setCachedUserEnvironments = setCachedUserEnvironmentsCollection?[user.key]
                        expect(setCachedUserEnvironments?.userKey) == user.key
                        if user.key == storingUser.key {
                            expect(setCachedUserEnvironments?.cacheableLastUpdated) == storingLastUpdated.stringEquivalentDate
                        } else {
                            expect(setCachedUserEnvironments?.cacheableLastUpdated) == testContext.userEnvironmentsCollection.lastUpdated(forKey: user.key)?.stringEquivalentDate
                        }

                        let setCachedEnvironmentFlagsCollection = setCachedUserEnvironments?.environmentFlags
                        if user.key == storingUser.key {
                            expect(setCachedEnvironmentFlagsCollection?.count) == CacheableUserEnvironmentFlags.Constants.environmentCount + 1
                        } else {
                            expect(setCachedEnvironmentFlagsCollection?.count) == CacheableUserEnvironmentFlags.Constants.environmentCount
                        }

                        var mobileKeys = [MobileKey](testContext.mobileKeys)
                        mobileKeys.append(storingMobileKey)
                        mobileKeys.forEach { mobileKey in
                            guard mobileKey != storingMobileKey || user.key == storingUser.key
                            else { return }
                            expect(setCachedEnvironmentFlagsCollection?.keys.contains(mobileKey)) == true

                            let setCachedEnvironmentFlags = setCachedEnvironmentFlagsCollection?[mobileKey]
                            expect(setCachedEnvironmentFlags?.userKey) == user.key
                            expect(setCachedEnvironmentFlags?.mobileKey) == mobileKey
                            if user.key == storingUser.key && mobileKey == storingMobileKey {
                                expect(setCachedEnvironmentFlags?.featureFlags) == newFeatureFlags
                            } else {
                                expect(setCachedEnvironmentFlags?.featureFlags) == testContext.featureFlags(forUserKey: user.key, andMobileKey: mobileKey)
                            }
                        }
                    }
                }
            }
        }
    }

    private func storeFeatureFlagsSpec(maxUsers: Int) {
        var testContext: TestContext!
        var storingUser: LDUser!
        var storingMobileKey: String!
        var storingLastUpdated: Date!
        var userCount: Int!
        var newFeatureFlags: [LDFlagKey: FeatureFlag]!
        var flagStore: FlagMaintaining!

        describe("storeFeatureFlags") {
            context("when no user flags are stored") {
                beforeEach {
                    userCount = 0
                    testContext = TestContext(userCount: userCount, maxUsers: maxUsers)
                    storingUser = LDUser.stub()
                    flagStore = FlagMaintainingMock(flags: FlagMaintainingMock.stubFlags())
                    storingLastUpdated = Date().addingTimeInterval(-1.0 * 24 * 60 * 60) // one day
                    storingMobileKey = UUID().uuidString
                }
                it("stores the users flags") {
                    FlagCachingStoreMode.allCases.forEach { storeMode in
                        testContext.storeFlags(flagStore.featureFlags,
                                               forUser: storingUser,
                                               andMobileKey: storingMobileKey,
                                               lastUpdated: storingLastUpdated,
                                               storeMode: storeMode)

                        expect(testContext.keyedValueCacheMock.setReceivedArguments?.forKey) == UserEnvironmentFlagCache.CacheKeys.cachedUserEnvironmentFlags

                        let setCachedUserEnvironmentsCollection = testContext.keyedValueCacheMock.setReceivedArguments?.value as? [UserKey: [String: Any]]
                        expect(setCachedUserEnvironmentsCollection?.count) == userCount + 1
                        expect(setCachedUserEnvironmentsCollection?.keys.first) == storingUser.key

                        let setCachedUserEnvironments = setCachedUserEnvironmentsCollection?[storingUser.key]
                        expect(setCachedUserEnvironments?.userKey) == storingUser.key
                        expect(setCachedUserEnvironments?.cacheableLastUpdated) == storingLastUpdated.stringEquivalentDate

                        let setCachedEnvironmentFlagsCollection = setCachedUserEnvironments?.environmentFlags
                        expect(setCachedEnvironmentFlagsCollection?.count) == 1
                        expect(setCachedEnvironmentFlagsCollection?.keys.first) == storingMobileKey

                        let setCachedEnvironmentFlags = setCachedEnvironmentFlagsCollection?[storingMobileKey]
                        expect(setCachedEnvironmentFlags?.userKey) == storingUser.key
                        expect(setCachedEnvironmentFlags?.mobileKey) == storingMobileKey
                        expect(setCachedEnvironmentFlags?.featureFlags) == flagStore.featureFlags
                    }
                }
            }
            context("when less than the max number of users flags are stored") {
                context("and an existing users flags are changed") {
                    beforeEach {
                        userCount = maxUsers - 1
                        testContext = TestContext(userCount: userCount, maxUsers: maxUsers)
                        storingUser = testContext.selectedUser
                        storingMobileKey = testContext.selectedMobileKey
                        newFeatureFlags = [Constants.newFlagKey: FeatureFlag.stub(flagKey: Constants.newFlagKey, flagValue: Constants.newFlagValue)]
                        flagStore = FlagMaintainingMock(flags: newFeatureFlags)
                        storingLastUpdated = Date()
                    }
                    it("stores the users flags") {
                        FlagCachingStoreMode.allCases.forEach { storeMode in
                            testContext.storeFlags(flagStore.featureFlags,
                                                   forUser: storingUser,
                                                   andMobileKey: storingMobileKey,
                                                   lastUpdated: storingLastUpdated,
                                                   storeMode: storeMode)

                            expect(testContext.keyedValueCacheMock.setReceivedArguments?.forKey) == UserEnvironmentFlagCache.CacheKeys.cachedUserEnvironmentFlags

                            let setCachedUserEnvironmentsCollection = testContext.keyedValueCacheMock.setReceivedArguments?.value as? [UserKey: [String: Any]]
                            expect(setCachedUserEnvironmentsCollection?.count) == userCount
                            testContext.users.forEach { user in
                                expect(setCachedUserEnvironmentsCollection?.keys.contains(user.key)) == true

                                let setCachedUserEnvironments = setCachedUserEnvironmentsCollection?[user.key]
                                expect(setCachedUserEnvironments?.userKey) == user.key
                                if user.key == storingUser.key {
                                    expect(setCachedUserEnvironments?.cacheableLastUpdated) == storingLastUpdated.stringEquivalentDate
                                } else {
                                    expect(setCachedUserEnvironments?.cacheableLastUpdated) == testContext.userEnvironmentsCollection.lastUpdated(forKey: user.key)?.stringEquivalentDate
                                }

                                let setCachedEnvironmentFlagsCollection = setCachedUserEnvironments?.environmentFlags
                                expect(setCachedEnvironmentFlagsCollection?.count) == CacheableUserEnvironmentFlags.Constants.environmentCount
                                testContext.mobileKeys.forEach { mobileKey in
                                    expect(setCachedEnvironmentFlagsCollection?.keys.contains(mobileKey)) == true

                                    let setCachedEnvironmentFlags = setCachedEnvironmentFlagsCollection?[mobileKey]
                                    expect(setCachedEnvironmentFlags?.userKey) == user.key
                                    expect(setCachedEnvironmentFlags?.mobileKey) == mobileKey
                                    //verify the storing user feature flags
                                    if user.key == storingUser.key && mobileKey == storingMobileKey {
                                        expect(setCachedEnvironmentFlags?.featureFlags) == newFeatureFlags
                                    } else {
                                        expect(setCachedEnvironmentFlags?.featureFlags) == testContext.featureFlags(forUserKey: user.key, andMobileKey: mobileKey)
                                    }
                                }
                            }
                        }
                    }
                }
                context("and an existing user adds a new environment") {
                    beforeEach {
                        userCount = maxUsers - 1
                        testContext = TestContext(userCount: userCount, maxUsers: maxUsers)
                        storingUser = testContext.selectedUser
                        storingMobileKey = (CacheableUserEnvironmentFlags.Constants.environmentCount + 1).mobileKey
                        newFeatureFlags = [Constants.newFlagKey: FeatureFlag.stub(flagKey: Constants.newFlagKey, flagValue: Constants.newFlagValue)]
                        flagStore = FlagMaintainingMock(flags: newFeatureFlags)
                        storingLastUpdated = Date()
                    }
                    it("stores the users flags") {
                        FlagCachingStoreMode.allCases.forEach { storeMode in
                            testContext.storeFlags(newFeatureFlags,
                                                   forUser: storingUser,
                                                   andMobileKey: storingMobileKey,
                                                   lastUpdated: storingLastUpdated,
                                                   storeMode: storeMode)

                            expect(testContext.keyedValueCacheMock.setReceivedArguments?.forKey) == UserEnvironmentFlagCache.CacheKeys.cachedUserEnvironmentFlags

                            let setCachedUserEnvironmentsCollection = testContext.keyedValueCacheMock.setReceivedArguments?.value as? [UserKey: [String: Any]]
                            expect(setCachedUserEnvironmentsCollection?.count) == userCount
                            testContext.users.forEach { user in
                                expect(setCachedUserEnvironmentsCollection?.keys.contains(user.key)) == true

                                let setCachedUserEnvironments = setCachedUserEnvironmentsCollection?[user.key]
                                expect(setCachedUserEnvironments?.userKey) == user.key
                                if user.key == storingUser.key {
                                    expect(setCachedUserEnvironments?.cacheableLastUpdated) == storingLastUpdated.stringEquivalentDate
                                } else {
                                    expect(setCachedUserEnvironments?.cacheableLastUpdated) == testContext.userEnvironmentsCollection.lastUpdated(forKey: user.key)?.stringEquivalentDate
                                }

                                let setCachedEnvironmentFlagsCollection = setCachedUserEnvironments?.environmentFlags
                                if user.key == storingUser.key {
                                    expect(setCachedEnvironmentFlagsCollection?.count) == CacheableUserEnvironmentFlags.Constants.environmentCount + 1
                                } else {
                                    expect(setCachedEnvironmentFlagsCollection?.count) == CacheableUserEnvironmentFlags.Constants.environmentCount
                                }

                                var mobileKeys = [MobileKey](testContext.mobileKeys)
                                mobileKeys.append(storingMobileKey)
                                mobileKeys.forEach { mobileKey in
                                    guard mobileKey != storingMobileKey || user.key == storingUser.key
                                    else { return }
                                    expect(setCachedEnvironmentFlagsCollection?.keys.contains(mobileKey)) == true

                                    let setCachedEnvironmentFlags = setCachedEnvironmentFlagsCollection?[mobileKey]
                                    expect(setCachedEnvironmentFlags?.userKey) == user.key
                                    expect(setCachedEnvironmentFlags?.mobileKey) == mobileKey
                                    if user.key == storingUser.key && mobileKey == storingMobileKey {
                                        expect(setCachedEnvironmentFlags?.featureFlags) == newFeatureFlags
                                    } else {
                                        expect(setCachedEnvironmentFlags?.featureFlags) == testContext.featureFlags(forUserKey: user.key, andMobileKey: mobileKey)
                                    }
                                }
                            }
                        }
                    }
                }
                context("and a new users flags are stored") {
                    beforeEach {
                        userCount = maxUsers - 1
                        testContext = TestContext(userCount: userCount, maxUsers: maxUsers)
                        storingUser = LDUser.stub(key: (userCount + 1).userKey)
                        storingMobileKey = 1.mobileKey
                        newFeatureFlags = [Constants.newFlagKey: FeatureFlag.stub(flagKey: Constants.newFlagKey, flagValue: Constants.newFlagValue)]
                        flagStore = FlagMaintainingMock(flags: newFeatureFlags)
                        storingLastUpdated = Date()
                    }
                    it("stores the users flags") {
                        FlagCachingStoreMode.allCases.forEach { storeMode in
                            testContext.storeFlags(newFeatureFlags,
                                                   forUser: storingUser,
                                                   andMobileKey: storingMobileKey,
                                                   lastUpdated: storingLastUpdated,
                                                   storeMode: storeMode)

                            expect(testContext.keyedValueCacheMock.setReceivedArguments?.forKey) == UserEnvironmentFlagCache.CacheKeys.cachedUserEnvironmentFlags

                            let setCachedUserEnvironmentsCollection = testContext.keyedValueCacheMock.setReceivedArguments?.value as? [UserKey: [String: Any]]
                            expect(setCachedUserEnvironmentsCollection?.count) == userCount + 1

                            var users = testContext.users
                            users.append(storingUser)
                            users.forEach { user in
                                expect(setCachedUserEnvironmentsCollection?.keys.contains(user.key)) == true

                                let setCachedUserEnvironments = setCachedUserEnvironmentsCollection?[user.key]
                                expect(setCachedUserEnvironments?.userKey) == user.key
                                if user.key == storingUser.key {
                                    expect(setCachedUserEnvironments?.cacheableLastUpdated) == storingLastUpdated.stringEquivalentDate
                                } else {
                                    expect(setCachedUserEnvironments?.cacheableLastUpdated) == testContext.userEnvironmentsCollection.lastUpdated(forKey: user.key)?.stringEquivalentDate
                                }

                                let setCachedEnvironmentFlagsCollection = setCachedUserEnvironments?.environmentFlags
                                expect(setCachedEnvironmentFlagsCollection?.count) == (user.key != storingUser.key ? CacheableUserEnvironmentFlags.Constants.environmentCount : 1)
                                testContext.mobileKeys.forEach { mobileKey in
                                    guard user.key != storingUser.key || mobileKey == storingMobileKey
                                    else { return }
                                    expect(setCachedEnvironmentFlagsCollection?.keys.contains(mobileKey)) == true

                                    let setCachedEnvironmentFlags = setCachedEnvironmentFlagsCollection?[mobileKey]
                                    expect(setCachedEnvironmentFlags?.userKey) == user.key
                                    expect(setCachedEnvironmentFlags?.mobileKey) == mobileKey

                                    if user.key == storingUser.key && mobileKey == storingMobileKey {
                                        expect(setCachedEnvironmentFlags?.featureFlags) == newFeatureFlags
                                    } else {
                                        expect(setCachedEnvironmentFlags?.featureFlags) == testContext.featureFlags(forUserKey: user.key, andMobileKey: mobileKey)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            context("when max number of users flags are stored") {
                context("and an existing users flags are changed") {
                    beforeEach {
                        userCount = maxUsers
                        testContext = TestContext(userCount: userCount, maxUsers: maxUsers)
                        storingUser = testContext.selectedUser
                        storingMobileKey = testContext.selectedMobileKey
                        newFeatureFlags = [Constants.newFlagKey: FeatureFlag.stub(flagKey: Constants.newFlagKey, flagValue: Constants.newFlagValue)]
                        flagStore = FlagMaintainingMock(flags: newFeatureFlags)
                        storingLastUpdated = Date()
                    }
                    it("stores the users flags") {
                        FlagCachingStoreMode.allCases.forEach { storeMode in
                            testContext.storeFlags(newFeatureFlags,
                                                   forUser: storingUser,
                                                   andMobileKey: storingMobileKey,
                                                   lastUpdated: storingLastUpdated,
                                                   storeMode: storeMode)

                            expect(testContext.keyedValueCacheMock.setReceivedArguments?.forKey) == UserEnvironmentFlagCache.CacheKeys.cachedUserEnvironmentFlags

                            let setCachedUserEnvironmentsCollection = testContext.keyedValueCacheMock.setReceivedArguments?.value as? [UserKey: [String: Any]]
                            expect(setCachedUserEnvironmentsCollection?.count) == userCount
                            testContext.users.forEach { user in
                                expect(setCachedUserEnvironmentsCollection?.keys.contains(user.key)) == true

                                let setCachedUserEnvironments = setCachedUserEnvironmentsCollection?[user.key]
                                expect(setCachedUserEnvironments?.userKey) == user.key
                                if user.key == storingUser.key {
                                    expect(setCachedUserEnvironments?.cacheableLastUpdated) == storingLastUpdated.stringEquivalentDate
                                } else {
                                    expect(setCachedUserEnvironments?.cacheableLastUpdated) == testContext.userEnvironmentsCollection.lastUpdated(forKey: user.key)?.stringEquivalentDate
                                }

                                let setCachedEnvironmentFlagsCollection = setCachedUserEnvironments?.environmentFlags
                                expect(setCachedEnvironmentFlagsCollection?.count) == CacheableUserEnvironmentFlags.Constants.environmentCount
                                testContext.mobileKeys.forEach { mobileKey in
                                    expect(setCachedEnvironmentFlagsCollection?.keys.contains(mobileKey)) == true

                                    let setCachedEnvironmentFlags = setCachedEnvironmentFlagsCollection?[mobileKey]
                                    expect(setCachedEnvironmentFlags?.userKey) == user.key
                                    expect(setCachedEnvironmentFlags?.mobileKey) == mobileKey

                                    if user.key == storingUser.key && mobileKey == storingMobileKey {
                                        expect(setCachedEnvironmentFlags?.featureFlags) == newFeatureFlags
                                    } else {
                                        expect(setCachedEnvironmentFlags?.featureFlags) == testContext.featureFlags(forUserKey: user.key, andMobileKey: mobileKey)
                                    }
                                }
                            }
                        }
                    }
                }
                context("and an existing user adds a new environment") {
                    beforeEach {
                        userCount = maxUsers
                        testContext = TestContext(userCount: userCount, maxUsers: maxUsers)
                        storingUser = testContext.selectedUser
                        storingMobileKey = (CacheableUserEnvironmentFlags.Constants.environmentCount + 1).mobileKey
                        newFeatureFlags = [Constants.newFlagKey: FeatureFlag.stub(flagKey: Constants.newFlagKey, flagValue: Constants.newFlagValue)]
                        flagStore = FlagMaintainingMock(flags: newFeatureFlags)
                        storingLastUpdated = Date()
                    }
                    it("stores the users flags") {
                        FlagCachingStoreMode.allCases.forEach { storeMode in
                            testContext.storeFlags(newFeatureFlags,
                                                   forUser: storingUser,
                                                   andMobileKey: storingMobileKey,
                                                   lastUpdated: storingLastUpdated,
                                                   storeMode: storeMode)

                            expect(testContext.keyedValueCacheMock.setReceivedArguments?.forKey) == UserEnvironmentFlagCache.CacheKeys.cachedUserEnvironmentFlags

                            let setCachedUserEnvironmentsCollection = testContext.keyedValueCacheMock.setReceivedArguments?.value as? [UserKey: [String: Any]]
                            expect(setCachedUserEnvironmentsCollection?.count) == userCount
                            testContext.users.forEach { user in
                                expect(setCachedUserEnvironmentsCollection?.keys.contains(user.key)) == true

                                let setCachedUserEnvironments = setCachedUserEnvironmentsCollection?[user.key]
                                expect(setCachedUserEnvironments?.userKey) == user.key
                                if user.key == storingUser.key {
                                    expect(setCachedUserEnvironments?.cacheableLastUpdated) == storingLastUpdated.stringEquivalentDate
                                } else {
                                    expect(setCachedUserEnvironments?.cacheableLastUpdated) == testContext.userEnvironmentsCollection.lastUpdated(forKey: user.key)?.stringEquivalentDate
                                }

                                let setCachedEnvironmentFlagsCollection = setCachedUserEnvironments?.environmentFlags
                                if user.key == storingUser.key {
                                    expect(setCachedEnvironmentFlagsCollection?.count) == CacheableUserEnvironmentFlags.Constants.environmentCount + 1
                                } else {
                                    expect(setCachedEnvironmentFlagsCollection?.count) == CacheableUserEnvironmentFlags.Constants.environmentCount
                                }

                                var mobileKeys = [MobileKey](testContext.mobileKeys)
                                mobileKeys.append(storingMobileKey)
                                mobileKeys.forEach { mobileKey in
                                    guard mobileKey != storingMobileKey || user.key == storingUser.key
                                    else { return }
                                    expect(setCachedEnvironmentFlagsCollection?.keys.contains(mobileKey)) == true

                                    let setCachedEnvironmentFlags = setCachedEnvironmentFlagsCollection?[mobileKey]
                                    expect(setCachedEnvironmentFlags?.userKey) == user.key
                                    expect(setCachedEnvironmentFlags?.mobileKey) == mobileKey
                                    if user.key == storingUser.key && mobileKey == storingMobileKey {
                                        expect(setCachedEnvironmentFlags?.featureFlags) == newFeatureFlags
                                    } else {
                                        expect(setCachedEnvironmentFlags?.featureFlags) == testContext.featureFlags(forUserKey: user.key, andMobileKey: mobileKey)
                                    }
                                }
                            }
                        }
                    }
                }
                context("and a new users flags are stored") {
                    beforeEach {
                        userCount = maxUsers
                        testContext = TestContext(userCount: userCount, maxUsers: maxUsers)
                        storingUser = LDUser.stub(key: (userCount + 1).userKey)
                        storingMobileKey = 1.mobileKey
                        newFeatureFlags = [Constants.newFlagKey: FeatureFlag.stub(flagKey: Constants.newFlagKey, flagValue: Constants.newFlagValue)]
                        flagStore = FlagMaintainingMock(flags: newFeatureFlags)
                        storingLastUpdated = Date()
                    }
                    it("stores the youngest users flags") {
                        FlagCachingStoreMode.allCases.forEach { storeMode in
                            testContext.storeFlags(newFeatureFlags,
                                                   forUser: storingUser,
                                                   andMobileKey: storingMobileKey,
                                                   lastUpdated: storingLastUpdated,
                                                   storeMode: storeMode)

                            expect(testContext.keyedValueCacheMock.setReceivedArguments?.forKey) == UserEnvironmentFlagCache.CacheKeys.cachedUserEnvironmentFlags

                            let setCachedUserEnvironmentsCollection = testContext.keyedValueCacheMock.setReceivedArguments?.value as? [UserKey: [String: Any]]
                            expect(setCachedUserEnvironmentsCollection?.count) == userCount

                            var users = testContext.users
                            users.append(storingUser)
                            users.forEach { user in
                                if user.key == testContext.oldestUser.key {
                                    expect(setCachedUserEnvironmentsCollection?.keys.contains(user.key)) == false
                                    return
                                }
                                expect(setCachedUserEnvironmentsCollection?.keys.contains(user.key)) == true

                                let setCachedUserEnvironments = setCachedUserEnvironmentsCollection?[user.key]
                                expect(setCachedUserEnvironments?.userKey) == user.key
                                if user.key == storingUser.key {
                                    expect(setCachedUserEnvironments?.cacheableLastUpdated) == storingLastUpdated.stringEquivalentDate
                                } else {
                                    expect(setCachedUserEnvironments?.cacheableLastUpdated) == testContext.userEnvironmentsCollection.lastUpdated(forKey: user.key)?.stringEquivalentDate
                                }

                                let setCachedEnvironmentFlagsCollection = setCachedUserEnvironments?.environmentFlags
                                expect(setCachedEnvironmentFlagsCollection?.count) == (user.key != storingUser.key ? CacheableUserEnvironmentFlags.Constants.environmentCount : 1)
                                testContext.mobileKeys.forEach { mobileKey in
                                    guard user.key != storingUser.key || mobileKey == storingMobileKey
                                    else { return }
                                    expect(setCachedEnvironmentFlagsCollection?.keys.contains(mobileKey)) == true

                                    let setCachedEnvironmentFlags = setCachedEnvironmentFlagsCollection?[mobileKey]
                                    expect(setCachedEnvironmentFlags?.userKey) == user.key
                                    expect(setCachedEnvironmentFlags?.mobileKey) == mobileKey
                                    if user.key == storingUser.key && mobileKey == storingMobileKey {
                                        expect(setCachedEnvironmentFlags?.featureFlags) == newFeatureFlags
                                    } else {
                                        expect(setCachedEnvironmentFlags?.featureFlags) == testContext.featureFlags(forUserKey: user.key, andMobileKey: mobileKey)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private extension Array where Element == LDUser {
    var selectedUser: LDUser {
        self[count / 2]
    }
}

private extension Dictionary.Keys where Key == MobileKey {
    var selectedMobileKey: MobileKey {
        let mobileKeys = [MobileKey](self)
        return mobileKeys[mobileKeys.count / 2]
    }
}

extension FeatureFlag {
    static func stub(flagKey: LDFlagKey, flagValue: Any?) -> FeatureFlag {
        return FeatureFlag(flagKey: flagKey,
                           value: flagValue,
                           variation: DarklyServiceMock.Constants.variation,
                           version: DarklyServiceMock.Constants.version,
                           flagVersion: DarklyServiceMock.Constants.flagVersion,
                           trackEvents: true,
                           debugEventsUntilDate: Date().addingTimeInterval(30.0),
                           reason: DarklyServiceMock.Constants.reason,
                           trackReason: false)
    }
}

extension Dictionary where Key == String {
    var cacheableLastUpdated: Date? {
        (self[CacheableUserEnvironmentFlags.CodingKeys.lastUpdated.rawValue] as? String)?.dateValue
    }
}

extension Dictionary where Key == UserKey, Value == CacheableUserEnvironmentFlags {
    func lastUpdated(forKey key: UserKey) -> Date? {
        self[key]?.lastUpdated
    }
}
