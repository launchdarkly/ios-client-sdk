//
//  CacheableUserEnvironmentsSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 3/19/19. +JMJ
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class CacheableUserEnvironmentFlagsSpec: QuickSpec {

    struct Constants {
        static let environmentCount = 3
        static let badDictionaryValue = 12
    }

    struct TestContext {
        //single user
        var user: LDUser
        var environmentFlags = [MobileKey: CacheableEnvironmentFlags]()
        var cacheableUserEnvironmentFlags: CacheableUserEnvironmentFlags

        //multiple users
        var users = [LDUser]()
        var userEnvironmentFlagsCollection = [UserKey: CacheableUserEnvironmentFlags]()

        var extraCacheableUserEnvironmentFlags: CacheableUserEnvironmentFlags!  //The ! allows init to populate users before creating this property

        init(environmentCount: Int = Constants.environmentCount, userCount: Int = 1) {
            let effectiveUserCount = userCount > 0 ? userCount : 1

            (users, userEnvironmentFlagsCollection, _) = CacheableUserEnvironmentFlags.stubCollection(environmentCount: environmentCount, userCount: effectiveUserCount + 1)

            user = users.first!
            cacheableUserEnvironmentFlags = userEnvironmentFlagsCollection[user.key]!
            environmentFlags = cacheableUserEnvironmentFlags.environmentFlags

            let extraUser = users.removeLast()
            extraCacheableUserEnvironmentFlags = userEnvironmentFlagsCollection.removeValue(forKey: extraUser.key)
        }
    }

    override func spec() {
        initSpec()
        dictionaryValueSpec()
        dictionaryValuesSpec()  //For a collection of CacheableUserEnvironments
        makeCacheableUserEnvironmentsCollectionSpec()
    }

    private func initSpec() {
        initWithElementsSpec()
        initWithDictionarySpec()
        initWithObjectSpec()
    }

    private func initWithElementsSpec() {
        var testContext: TestContext!
        var cacheableUserEnvironments: CacheableUserEnvironmentFlags!
        describe("init") {
            context("with elements") {
                beforeEach {
                    testContext = TestContext()

                    cacheableUserEnvironments = CacheableUserEnvironmentFlags(userKey: testContext.user.key,
                                                                              environmentFlags: testContext.environmentFlags,
                                                                              lastUpdated: Date.stubDate)
                }
                it("creates a cacheableUserEnvironments with matching elements") {
                    expect(cacheableUserEnvironments.userKey) == testContext.user.key
                    expect(cacheableUserEnvironments.environmentFlags) == testContext.environmentFlags
                }
            }
            context("with empty featureFlags") {
                beforeEach {
                    testContext = TestContext(environmentCount: 0)

                    cacheableUserEnvironments = CacheableUserEnvironmentFlags(userKey: testContext.user.key,
                                                                              environmentFlags: testContext.environmentFlags,
                                                                              lastUpdated: Date.stubDate)
                }
                it("creates a cacheableUserEnvironments with no feature flags") {
                    expect(cacheableUserEnvironments.userKey) == testContext.user.key
                    expect(cacheableUserEnvironments.environmentFlags.isEmpty) == true
                }
            }
        }
    }

    private func initWithDictionarySpec() {
        var testContext: TestContext!
        var cacheableUserEnvironmentsDictionary: [String: Any]!
        var cacheableUserEnvironments: CacheableUserEnvironmentFlags?
        describe("initWithDictionary") {
            context("with elements") {
                beforeEach {
                    testContext = TestContext()
                    cacheableUserEnvironmentsDictionary = testContext.cacheableUserEnvironmentFlags.dictionaryValue

                    cacheableUserEnvironments = CacheableUserEnvironmentFlags(dictionary: cacheableUserEnvironmentsDictionary)
                }
                it("creates a matching cacheableUserEnvironments") {
                    expect(cacheableUserEnvironments?.userKey) == cacheableUserEnvironmentsDictionary.userKey
                    expect(cacheableUserEnvironments?.environmentFlags) == cacheableUserEnvironmentsDictionary.environmentFlags
                }
            }
            context("with no feature flags") {
                beforeEach {
                    testContext = TestContext(environmentCount: 0)
                    cacheableUserEnvironmentsDictionary = testContext.cacheableUserEnvironmentFlags.dictionaryValue

                    cacheableUserEnvironments = CacheableUserEnvironmentFlags(dictionary: cacheableUserEnvironmentsDictionary)
                }
                it("creates a matching cacheableUserEnvironments with no feature flags") {
                    expect(cacheableUserEnvironments?.userKey) == cacheableUserEnvironmentsDictionary.userKey
                    expect(cacheableUserEnvironments?.environmentFlags.isEmpty) == true
                }
            }
            context("with extra dictionary items") {
                beforeEach {
                    testContext = TestContext()
                    cacheableUserEnvironmentsDictionary = testContext.cacheableUserEnvironmentFlags.dictionaryValue
                    cacheableUserEnvironmentsDictionary.merge(testContext.user.dictionaryValueWithAllAttributes(includeFlagConfig: true), uniquingKeysWith: { (original, _) in
                        return original
                    })

                    cacheableUserEnvironments = CacheableUserEnvironmentFlags(dictionary: cacheableUserEnvironmentsDictionary)
                }
                it("creates a matching cacheableUserEnvironments") {
                    expect(cacheableUserEnvironments?.userKey) == cacheableUserEnvironmentsDictionary.userKey
                    expect(cacheableUserEnvironments?.environmentFlags) == cacheableUserEnvironmentsDictionary.environmentFlags
                }
            }
            context("without an element") {
                context("without userKey") {
                    beforeEach {
                        testContext = TestContext()
                        cacheableUserEnvironmentsDictionary = testContext.cacheableUserEnvironmentFlags.dictionaryValue
                        cacheableUserEnvironmentsDictionary.removeValue(forKey: CacheableUserEnvironmentFlags.CodingKeys.userKey.rawValue)

                        cacheableUserEnvironments = CacheableUserEnvironmentFlags(dictionary: cacheableUserEnvironmentsDictionary)
                    }
                    it("returns nil") {
                        expect(cacheableUserEnvironments).to(beNil())
                    }
                }
                context("without environmentFlags") {
                    beforeEach {
                        testContext = TestContext()
                        cacheableUserEnvironmentsDictionary = testContext.cacheableUserEnvironmentFlags.dictionaryValue
                        cacheableUserEnvironmentsDictionary.removeValue(forKey: CacheableUserEnvironmentFlags.CodingKeys.environmentFlags.rawValue)

                        cacheableUserEnvironments = CacheableUserEnvironmentFlags(dictionary: cacheableUserEnvironmentsDictionary)
                    }
                    it("returns nil") {
                        expect(cacheableUserEnvironments).to(beNil())
                    }
                }
            }
            context("with a type mismatched element") {
                context("with a type mismatched userKey") {
                    beforeEach {
                        testContext = TestContext()
                        cacheableUserEnvironmentsDictionary = testContext.cacheableUserEnvironmentFlags.dictionaryValue
                        cacheableUserEnvironmentsDictionary[CacheableUserEnvironmentFlags.CodingKeys.userKey.rawValue] = Constants.badDictionaryValue

                        cacheableUserEnvironments = CacheableUserEnvironmentFlags(dictionary: cacheableUserEnvironmentsDictionary)
                    }
                    it("returns nil") {
                        expect(cacheableUserEnvironments).to(beNil())
                    }
                }
                context("with a type mismatched environmentFlags") {
                    beforeEach {
                        testContext = TestContext()
                        cacheableUserEnvironmentsDictionary = testContext.cacheableUserEnvironmentFlags.dictionaryValue
                        cacheableUserEnvironmentsDictionary[CacheableUserEnvironmentFlags.CodingKeys.environmentFlags.rawValue] = Constants.badDictionaryValue

                        cacheableUserEnvironments = CacheableUserEnvironmentFlags(dictionary: cacheableUserEnvironmentsDictionary)
                    }
                    it("returns nil") {
                        expect(cacheableUserEnvironments).to(beNil())
                    }
                }
            }
        }
    }

    private func initWithObjectSpec() {
        var testContext: TestContext!
        var object: Any!
        var cacheableUserEnvironments: CacheableUserEnvironmentFlags?
        describe("initWithObject") {
            context("object is a valid dictionary") {
                beforeEach {
                    testContext = TestContext()
                    object = testContext.cacheableUserEnvironmentFlags.dictionaryValue

                    cacheableUserEnvironments = CacheableUserEnvironmentFlags(object: object!)
                }
                it("creates a matching cacheableUserEnvironments object") {
                    expect(cacheableUserEnvironments?.userKey) == testContext.cacheableUserEnvironmentFlags.userKey
                    expect(cacheableUserEnvironments?.environmentFlags) == testContext.cacheableUserEnvironmentFlags.environmentFlags
                }
            }
            context("object is not a valid dictionary") {
                beforeEach {
                    object = Constants.badDictionaryValue

                    cacheableUserEnvironments = CacheableUserEnvironmentFlags(object: object!)
                }
                it("returns nil") {
                    expect(cacheableUserEnvironments).to(beNil())
                }
            }
        }
    }

    private func dictionaryValueSpec() {
        var testContext: TestContext!
        var cacheableUserEnvironmentsDictionary: [String: Any]!
        describe("dictionaryValue") {
            context("when environmentFlags exist") {
                beforeEach {
                    testContext = TestContext()

                    cacheableUserEnvironmentsDictionary = testContext.cacheableUserEnvironmentFlags.dictionaryValue
                }
                it("creates a dictionary with matching elements") {
                    expect(cacheableUserEnvironmentsDictionary.userKey) == testContext.cacheableUserEnvironmentFlags.userKey
                    expect(cacheableUserEnvironmentsDictionary.environmentFlags) == testContext.cacheableUserEnvironmentFlags.environmentFlags
                }
            }
            context("when environmentFlags is empty") {
                beforeEach {
                    testContext = TestContext(environmentCount: 0)

                    cacheableUserEnvironmentsDictionary = testContext.cacheableUserEnvironmentFlags.dictionaryValue
                }
                it("creates a dictionary with no environmentFlags") {
                    expect(cacheableUserEnvironmentsDictionary.userKey) == testContext.cacheableUserEnvironmentFlags.userKey
                    expect(cacheableUserEnvironmentsDictionary.environmentFlags?.isEmpty) == true
                }
            }
        }
    }

    // Verifies converting a collection of [UserKey: CacheableUserEnvironments] into a dictionary
    private func dictionaryValuesSpec() {
        var testContext: TestContext!
        var cacheableUserEnvironmentsCollectionDictionary: [UserKey: Any]!
        describe("dictionaryValues") {
            context("with multiple CacheableUserEnvironments") {
                beforeEach {
                    testContext = TestContext(userCount: UserEnvironmentFlagCache.Constants.maxCachedUsers)

                    cacheableUserEnvironmentsCollectionDictionary = testContext.userEnvironmentFlagsCollection.dictionaryValues
                }
                it("creates a matching dictionary") {
                    testContext.userEnvironmentFlagsCollection.forEach { (userKey, cacheableUserEnvironments) in
                        let cacheableUserEnvironmentsDictionary = cacheableUserEnvironmentsCollectionDictionary[userKey] as? [String: Any]
                        expect(cacheableUserEnvironmentsDictionary?.userKey) == userKey
                        expect(cacheableUserEnvironmentsDictionary?.environmentFlags) == cacheableUserEnvironments.environmentFlags
                    }
                }
            }
            context("with no environments") {
                beforeEach {
                    let cacheableUserEnvironmentsCollection = [UserKey: CacheableUserEnvironmentFlags]()
                    
                    cacheableUserEnvironmentsCollectionDictionary = cacheableUserEnvironmentsCollection.dictionaryValues
                }
                it("creates an empty dictionary") {
                    expect(cacheableUserEnvironmentsCollectionDictionary.isEmpty) == true
                }
            }
        }
    }

    private func makeCacheableUserEnvironmentsCollectionSpec() {
        var testContext: TestContext!
        var cacheableUserEnvironmentsCollectionDictionary: [String: Any]!
        var cacheableUserEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags]?
        describe("makeCacheableUserEnvironmentsCollection") {
            context("with multiple CacheableUserEnvironments dictionaries") {
                beforeEach {
                    testContext = TestContext(userCount: UserEnvironmentFlagCache.Constants.maxCachedUsers)
                    cacheableUserEnvironmentsCollectionDictionary = testContext.userEnvironmentFlagsCollection.dictionaryValues

                    cacheableUserEnvironmentsCollection = CacheableUserEnvironmentFlags.makeCollection(from: cacheableUserEnvironmentsCollectionDictionary)
                }
                it("creates a matching CacheableUserEnvironments collection") {
                    expect(cacheableUserEnvironmentsCollection?.count) == testContext.userEnvironmentFlagsCollection.count
                    testContext.userEnvironmentFlagsCollection.forEach { (userKey, originalCacheableUserEnvironments) in
                        let reinflatedCacheableUserEnvironment = cacheableUserEnvironmentsCollection?[userKey]
                        expect(reinflatedCacheableUserEnvironment?.userKey) == userKey
                        expect(reinflatedCacheableUserEnvironment?.environmentFlags) == originalCacheableUserEnvironments.environmentFlags
                    }
                }
            }
            context("with no dictionaries") {
                beforeEach {
                    cacheableUserEnvironmentsCollection = CacheableUserEnvironmentFlags.makeCollection(from: [:])
                }
                it("creates an empty CacheableUserEnvironments collection") {
                    expect(cacheableUserEnvironmentsCollection?.isEmpty) == true
                }
            }
            context("with no well-formed dictionaries") {
                beforeEach {
                    cacheableUserEnvironmentsCollection = CacheableUserEnvironmentFlags.makeCollection(from: [0.userKey: [0.mobileKey: "dummy"]])
                }
                it("returns nil") {
                    expect(cacheableUserEnvironmentsCollection).to(beNil())
                }
            }
            context("with missing sub-dictionary element") {
                var badUserKey: String!
                context("missing userKey") {
                    beforeEach {
                        testContext = TestContext(userCount: UserEnvironmentFlagCache.Constants.maxCachedUsers)
                        cacheableUserEnvironmentsCollectionDictionary = testContext.userEnvironmentFlagsCollection.dictionaryValues

                        //Create a new CacheableUserEnvironment
                        badUserKey = testContext.extraCacheableUserEnvironmentFlags.userKey
                        var badCacheableUserEnvironmentsDictionary = testContext.extraCacheableUserEnvironmentFlags.dictionaryValue
                        badCacheableUserEnvironmentsDictionary.removeValue(forKey: CacheableUserEnvironmentFlags.CodingKeys.userKey.rawValue)
                        cacheableUserEnvironmentsCollectionDictionary[badUserKey] = badCacheableUserEnvironmentsDictionary

                        cacheableUserEnvironmentsCollection = CacheableUserEnvironmentFlags.makeCollection(from: cacheableUserEnvironmentsCollectionDictionary)
                    }
                    it("creates a CacheableUserEnvironments collection omitting the malformed sub-dictionary") {
                        expect(cacheableUserEnvironmentsCollection?.count) == testContext.userEnvironmentFlagsCollection.count
                        expect(cacheableUserEnvironmentsCollection?.keys.contains(badUserKey)) == false
                        testContext.userEnvironmentFlagsCollection.forEach { (userKey, originalCacheableUserEnvironments) in
                            let reinflatedCacheableUserEnvironment = cacheableUserEnvironmentsCollection?[userKey]
                            expect(reinflatedCacheableUserEnvironment?.userKey) == userKey
                            expect(reinflatedCacheableUserEnvironment?.environmentFlags) == originalCacheableUserEnvironments.environmentFlags
                        }
                    }
                }
                context("missing environmentFlags") {
                    beforeEach {
                        testContext = TestContext(userCount: UserEnvironmentFlagCache.Constants.maxCachedUsers)
                        cacheableUserEnvironmentsCollectionDictionary = testContext.userEnvironmentFlagsCollection.dictionaryValues

                        //Create a new CacheableUserEnvironment
                        badUserKey = testContext.extraCacheableUserEnvironmentFlags.userKey
                        var badCacheableUserEnvironmentsDictionary = testContext.extraCacheableUserEnvironmentFlags.dictionaryValue
                        badCacheableUserEnvironmentsDictionary.removeValue(forKey: CacheableUserEnvironmentFlags.CodingKeys.environmentFlags.rawValue)
                        cacheableUserEnvironmentsCollectionDictionary[badUserKey] = badCacheableUserEnvironmentsDictionary

                        cacheableUserEnvironmentsCollection = CacheableUserEnvironmentFlags.makeCollection(from: cacheableUserEnvironmentsCollectionDictionary)
                    }
                    it("creates a CacheableUserEnvironments collection omitting the malformed sub-dictionary") {
                        expect(cacheableUserEnvironmentsCollection?.count) == testContext.userEnvironmentFlagsCollection.count
                        expect(cacheableUserEnvironmentsCollection?.keys.contains(badUserKey)) == false
                        testContext.userEnvironmentFlagsCollection.forEach { (userKey, originalCacheableUserEnvironments) in
                            let reinflatedCacheableUserEnvironment = cacheableUserEnvironmentsCollection?[userKey]
                            expect(reinflatedCacheableUserEnvironment?.userKey) == userKey
                            expect(reinflatedCacheableUserEnvironment?.environmentFlags) == originalCacheableUserEnvironments.environmentFlags
                        }
                    }
                }
            }
            context("with type mismatch for sub-dictionary") {
                var badUserKey: String!
                context("type mismatched userKey") {
                    beforeEach {
                        testContext = TestContext(userCount: UserEnvironmentFlagCache.Constants.maxCachedUsers)
                        cacheableUserEnvironmentsCollectionDictionary = testContext.userEnvironmentFlagsCollection.dictionaryValues

                        //Create a new CacheableUserEnvironment
                        badUserKey = testContext.extraCacheableUserEnvironmentFlags.userKey
                        var badCacheableUserEnvironmentsDictionary = testContext.extraCacheableUserEnvironmentFlags.dictionaryValue
                        badCacheableUserEnvironmentsDictionary[CacheableUserEnvironmentFlags.CodingKeys.userKey.rawValue] = Constants.badDictionaryValue
                        cacheableUserEnvironmentsCollectionDictionary[badUserKey] = badCacheableUserEnvironmentsDictionary

                        cacheableUserEnvironmentsCollection = CacheableUserEnvironmentFlags.makeCollection(from: cacheableUserEnvironmentsCollectionDictionary)
                    }
                    it("creates a CacheableUserEnvironments collection omitting the malformed sub-dictionary") {
                        expect(cacheableUserEnvironmentsCollection?.count) == testContext.userEnvironmentFlagsCollection.count
                        expect(cacheableUserEnvironmentsCollection?.keys.contains(badUserKey)) == false
                        testContext.userEnvironmentFlagsCollection.forEach { (userKey, originalCacheableUserEnvironments) in
                            let reinflatedCacheableUserEnvironment = cacheableUserEnvironmentsCollection?[userKey]
                            expect(reinflatedCacheableUserEnvironment?.userKey) == userKey
                            expect(reinflatedCacheableUserEnvironment?.environmentFlags) == originalCacheableUserEnvironments.environmentFlags
                        }
                    }
                }
                context("type mismatched environmentFlags") {
                    beforeEach {
                        testContext = TestContext(userCount: UserEnvironmentFlagCache.Constants.maxCachedUsers)
                        cacheableUserEnvironmentsCollectionDictionary = testContext.userEnvironmentFlagsCollection.dictionaryValues

                        //Create a new CacheableUserEnvironment
                        badUserKey = testContext.extraCacheableUserEnvironmentFlags.userKey
                        var badCacheableUserEnvironmentsDictionary = testContext.extraCacheableUserEnvironmentFlags.dictionaryValue
                        badCacheableUserEnvironmentsDictionary[CacheableUserEnvironmentFlags.CodingKeys.environmentFlags.rawValue] = Constants.badDictionaryValue
                        cacheableUserEnvironmentsCollectionDictionary[badUserKey] = badCacheableUserEnvironmentsDictionary

                        cacheableUserEnvironmentsCollection = CacheableUserEnvironmentFlags.makeCollection(from: cacheableUserEnvironmentsCollectionDictionary)
                    }
                    it("creates a CacheableUserEnvironments collection omitting the malformed sub-dictionary") {
                        expect(cacheableUserEnvironmentsCollection?.count) == testContext.userEnvironmentFlagsCollection.count
                        expect(cacheableUserEnvironmentsCollection?.keys.contains(badUserKey)) == false
                        testContext.userEnvironmentFlagsCollection.forEach { (userKey, originalCacheableUserEnvironments) in
                            let reinflatedCacheableUserEnvironment = cacheableUserEnvironmentsCollection?[userKey]
                            expect(reinflatedCacheableUserEnvironment?.userKey) == userKey
                            expect(reinflatedCacheableUserEnvironment?.environmentFlags) == originalCacheableUserEnvironments.environmentFlags
                        }
                    }
                }
            }
        }
    }
}

extension FeatureFlag {
    struct StubConstants {
        static let mobileKey = "mobileKey"
    }

    static func stubFlagCollection(userKey: String, mobileKey: String) -> [LDFlagKey: FeatureFlag] {
        var flagCollection = DarklyServiceMock.Constants.stubFeatureFlags()
        flagCollection[LDUser.StubConstants.userKey] = FeatureFlag(flagKey: LDUser.StubConstants.userKey,
                                                                   value: userKey,
                                                                   variation: DarklyServiceMock.Constants.variation,
                                                                   version: DarklyServiceMock.Constants.version,
                                                                   flagVersion: DarklyServiceMock.Constants.flagVersion,
                                                                   eventTrackingContext: EventTrackingContext.stub())
        flagCollection[StubConstants.mobileKey] = FeatureFlag(flagKey: StubConstants.mobileKey,
                                                              value: mobileKey,
                                                              variation: DarklyServiceMock.Constants.variation,
                                                              version: DarklyServiceMock.Constants.version,
                                                              flagVersion: DarklyServiceMock.Constants.flagVersion,
                                                              eventTrackingContext: EventTrackingContext.stub())
        return flagCollection
    }
}

extension Date {
    static let stubString = "2018-02-21T18:10:40.823Z"
    static let stubDate = stubString.dateValue
}

extension Dictionary where Key == String, Value == Any {
    var environmentFlags: [MobileKey: CacheableEnvironmentFlags]? {
        guard let environmentFlagsDictionary = self[CacheableUserEnvironmentFlags.CodingKeys.environmentFlags.rawValue] as? [MobileKey: Any]
        else {
            return nil
        }
        return environmentFlagsDictionary.compactMapValues({ (cacheableEnvironmentFlagsDictionary) -> CacheableEnvironmentFlags? in
            return CacheableEnvironmentFlags(object: cacheableEnvironmentFlagsDictionary)
        })
    }
}

extension Int {
    static let userKeyPrefix = "User."
    static let mobileKeyPrefix = "MobileKey."

    var userKey: String {
        return "\(Int.userKeyPrefix)\(self)"
    }
    var mobileKey: String {
        return "\(Int.mobileKeyPrefix)\(self)"
    }
}

extension CacheableUserEnvironmentFlags {
    struct Constants {
        static let environmentCount = 3
        static let userCount = UserEnvironmentFlagCache.Constants.maxCachedUsers
    }

    static func stubCollection(environmentCount: Int = Constants.environmentCount,
                               userCount: Int = Constants.userCount) -> (users: [LDUser], collection: [UserKey: CacheableUserEnvironmentFlags], mobileKeys: [MobileKey]) {
        var pastSeconds = 0.0

        var users = [LDUser]()
        while users.count < userCount {
            let user = LDUser.stub(key: (users.count + 1).userKey)
            users.append(user)
        }

        var userEnvironmentsCollection = [UserKey: CacheableUserEnvironmentFlags]()
        var mobileKeys = [MobileKey]()
        users.forEach { (user) in
            let environmentFlags: [MobileKey: CacheableEnvironmentFlags]
            environmentFlags = CacheableEnvironmentFlags.stubCollection(userKey: user.key, environmentCount: environmentCount)
            if mobileKeys.isEmpty && environmentCount > 0 {
                mobileKeys.append(contentsOf: environmentFlags.keys)
            }
            let lastUpdated = Date.stubDate.addingTimeInterval(pastSeconds)
            pastSeconds -= 1.0
            let cacheableUserEnvironments = CacheableUserEnvironmentFlags(userKey: user.key, environmentFlags: environmentFlags, lastUpdated: lastUpdated)
            userEnvironmentsCollection[user.key] = cacheableUserEnvironments
        }

        return (users, userEnvironmentsCollection, mobileKeys)
    }
}
