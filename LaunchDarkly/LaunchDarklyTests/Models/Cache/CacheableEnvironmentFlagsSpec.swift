//
//  CacheableEnvironmentFlagsSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 3/19/19. +JMJ
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class CacheableEnvironmentFlagsSpec: QuickSpec {

    struct Constants {
        static let int = 3
    }

    private struct TestContext {
        var user: LDUser
        var mobileKey = UUID().uuidString
        var cacheableEnvironmentFlags: CacheableEnvironmentFlags

        init(includeNullValue: Bool = true, emptyFeatureFlags: Bool = false) {
            user  = LDUser.stub(includeNullValue: includeNullValue)
            if emptyFeatureFlags {
                user.flagStore = FlagMaintainingMock(flags: [:])
            }
            cacheableEnvironmentFlags = CacheableEnvironmentFlags(userKey: user.key, mobileKey: mobileKey, featureFlags: user.flagStore.featureFlags)
        }
    }

    override func spec() {
        initSpec()
        dictionaryValueSpec()
        equalsSpec()
    }

    private func initSpec() {
        initWithElementsSpec()
        initWithDictionarySpec()
        initWithObjectSpec()
    }

    private func initWithElementsSpec() {
        var testContext: TestContext!
        describe("initWithElements") {
            context("with elements") {
                beforeEach {
                    testContext = TestContext()
                }
                it("creates a CacheableEnvironmentFlags with the elements") {
                    expect(testContext.cacheableEnvironmentFlags.userKey) == testContext.user.key
                    expect(testContext.cacheableEnvironmentFlags.mobileKey) == testContext.mobileKey
                    expect(testContext.cacheableEnvironmentFlags.featureFlags) == testContext.user.flagStore.featureFlags
                }
            }
        }
    }

    private func initWithDictionarySpec() {
        var testContext: TestContext!
        var otherDictionary: [String: Any]!
        var other: CacheableEnvironmentFlags?
        describe("initWithDictionary") {
            context("with elements") {
                beforeEach {
                    testContext = TestContext()
                    otherDictionary = testContext.cacheableEnvironmentFlags.dictionaryValue

                    other = CacheableEnvironmentFlags(dictionary: otherDictionary)
                }
                it("creates a new CacheableEnvironmentFlags") {
                    expect(other?.userKey) == testContext.user.key
                    expect(other?.mobileKey) == testContext.mobileKey
                    expect(other?.featureFlags) == testContext.user.flagStore.featureFlags
                }
            }
            context("has other keys") {
                beforeEach {
                    testContext = TestContext()
                    otherDictionary = testContext.cacheableEnvironmentFlags.dictionaryValue
                    otherDictionary.merge(testContext.user.dictionaryValueWithAllAttributes(includeFlagConfig: false), uniquingKeysWith: { (current, _) in
                        return current
                    })

                    other = CacheableEnvironmentFlags(dictionary: otherDictionary)
                }
                it("creates a new CacheableEnvironmentFlags") {
                    expect(other?.userKey) == testContext.user.key
                    expect(other?.mobileKey) == testContext.mobileKey
                    expect(other?.featureFlags) == testContext.user.flagStore.featureFlags
                }
            }
            context("missing an element") {
                context("missing userKey") {
                    beforeEach {
                        testContext = TestContext()
                        otherDictionary = testContext.cacheableEnvironmentFlags.dictionaryValue
                        otherDictionary.removeValue(forKey: CacheableEnvironmentFlags.CodingKeys.userKey.rawValue)

                        other = CacheableEnvironmentFlags(dictionary: otherDictionary)
                    }
                    it("returns nil") {
                        expect(other).to(beNil())
                    }
                }
                context("missing mobileKey") {
                    beforeEach {
                        testContext = TestContext()
                        otherDictionary = testContext.cacheableEnvironmentFlags.dictionaryValue
                        otherDictionary.removeValue(forKey: CacheableEnvironmentFlags.CodingKeys.mobileKey.rawValue)

                        other = CacheableEnvironmentFlags(dictionary: otherDictionary)
                    }
                    it("returns nil") {
                        expect(other).to(beNil())
                    }
                }
                context("missing featureFlags") {
                    beforeEach {
                        testContext = TestContext()
                        otherDictionary = testContext.cacheableEnvironmentFlags.dictionaryValue
                        otherDictionary.removeValue(forKey: CacheableEnvironmentFlags.CodingKeys.featureFlags.rawValue)

                        other = CacheableEnvironmentFlags(dictionary: otherDictionary)
                    }
                    it("returns nil") {
                        expect(other).to(beNil())
                    }
                }
            }
            context("type mismatch on an element") {
                context("mismatched userKey") {
                    beforeEach {
                        testContext = TestContext()
                        otherDictionary = testContext.cacheableEnvironmentFlags.dictionaryValue
                        otherDictionary?[CacheableEnvironmentFlags.CodingKeys.userKey.rawValue] = Constants.int

                        other = CacheableEnvironmentFlags(dictionary: otherDictionary)
                    }
                    it("returns nil") {
                        expect(other).to(beNil())
                    }
                }
                context("mismatched mobileKey") {
                    beforeEach {
                        testContext = TestContext()
                        otherDictionary = testContext.cacheableEnvironmentFlags.dictionaryValue
                        otherDictionary?[CacheableEnvironmentFlags.CodingKeys.mobileKey.rawValue] = Constants.int

                        other = CacheableEnvironmentFlags(dictionary: otherDictionary)
                    }
                    it("returns nil") {
                        expect(other).to(beNil())
                    }
                }
                context("mismatched featureFlags") {
                    beforeEach {
                        testContext = TestContext()
                        otherDictionary = testContext.cacheableEnvironmentFlags.dictionaryValue
                        otherDictionary?[CacheableEnvironmentFlags.CodingKeys.featureFlags.rawValue] = Constants.int

                        other = CacheableEnvironmentFlags(dictionary: otherDictionary)
                    }
                    it("returns nil") {
                        expect(other).to(beNil())
                    }
                }
            }
        }
    }

    private func initWithObjectSpec() {
        var testContext: TestContext!
        var object: Any!
        var other: CacheableEnvironmentFlags?
        describe("initWithObject") {
            context("object is a well-formed dictionary") {
                beforeEach {
                    testContext = TestContext()
                    object = testContext.cacheableEnvironmentFlags.dictionaryValue

                    other = CacheableEnvironmentFlags(object: object!)
                }
                it("creates a new CacheableEnvironmentFlags") {
                    expect(other?.userKey) == testContext.user.key
                    expect(other?.mobileKey) == testContext.mobileKey
                    expect(other?.featureFlags) == testContext.user.flagStore.featureFlags
                }
            }
            context("object is not a dictionary") {
                beforeEach {
                    object = Constants.int

                    other = CacheableEnvironmentFlags(object: object!)
                }
                it("returns nil") {
                    expect(other).to(beNil())
                }
            }
        }
    }

    private func dictionaryValueSpec() {
        var testContext: TestContext!
        var cacheableEnvironmentFlagsDictionary: [String: Any]!
        describe("dictionaryValue") {
            context("with null feature flag value") {
                beforeEach {
                    testContext = TestContext(includeNullValue: true)

                    cacheableEnvironmentFlagsDictionary = testContext.cacheableEnvironmentFlags.dictionaryValue
                }
                it("creates a dictionary with the elements") {
                    expect(cacheableEnvironmentFlagsDictionary.userKey) == testContext.user.key
                    expect(cacheableEnvironmentFlagsDictionary.mobileKey) == testContext.mobileKey
                    expect(cacheableEnvironmentFlagsDictionary.featureFlags) == testContext.user.flagStore.featureFlags
                }
            }
            context("without feature flags") {
                beforeEach {
                    testContext = TestContext(emptyFeatureFlags: true)

                    cacheableEnvironmentFlagsDictionary = testContext.cacheableEnvironmentFlags.dictionaryValue
                }
                it("creates a dictionary with the elements") {
                    expect(cacheableEnvironmentFlagsDictionary.userKey) == testContext.user.key
                    expect(cacheableEnvironmentFlagsDictionary.mobileKey) == testContext.mobileKey
                    expect(cacheableEnvironmentFlagsDictionary.featureFlags?.isEmpty) == true
                }
            }
        }
    }

    private func equalsSpec() {
        var testContext: TestContext!
        var other: CacheableEnvironmentFlags!
        describe("equals") {
            context("when elements are equal") {
                beforeEach {
                    testContext = TestContext()
                    other = CacheableEnvironmentFlags(userKey: testContext.user.key,
                                                      mobileKey: testContext.mobileKey,
                                                      featureFlags: testContext.user.flagStore.featureFlags)
                }
                it("returns true") {
                    expect(testContext.cacheableEnvironmentFlags == other) == true
                }
            }
            context("when an element differs") {
                context("when the userKey differs") {
                    beforeEach {
                        testContext = TestContext()
                        other = CacheableEnvironmentFlags(userKey: UUID().uuidString,
                                                          mobileKey: testContext.mobileKey,
                                                          featureFlags: testContext.user.flagStore.featureFlags)
                    }
                    it("returns false") {
                        expect(testContext.cacheableEnvironmentFlags == other) == false
                    }
                }
                context("when the mobileKey differs") {
                    beforeEach {
                        testContext = TestContext()
                        other = CacheableEnvironmentFlags(userKey: testContext.user.key,
                                                          mobileKey: UUID().uuidString,
                                                          featureFlags: testContext.user.flagStore.featureFlags)
                    }
                    it("returns false") {
                        expect(testContext.cacheableEnvironmentFlags == other) == false
                    }
                }
                context("when the featureFlags differ") {
                    beforeEach {
                        testContext = TestContext()
                        var otherFlags = testContext.user.flagStore.featureFlags
                        otherFlags.removeValue(forKey: otherFlags.first!.key)
                        other = CacheableEnvironmentFlags(userKey: testContext.user.key,
                                                          mobileKey: testContext.mobileKey,
                                                          featureFlags: otherFlags)
                    }
                    it("returns false") {
                        expect(testContext.cacheableEnvironmentFlags == other) == false
                    }
                }
            }
        }
    }
}

extension Dictionary where Key == String, Value == Any {
    var userKey: String? {
        return self[CacheableEnvironmentFlags.CodingKeys.userKey.rawValue] as? String
    }
    var mobileKey: String? {
        return self[CacheableEnvironmentFlags.CodingKeys.mobileKey.rawValue] as? String
    }
    var featureFlags: [LDFlagKey: FeatureFlag]? {
        let flagDictionary = self[CacheableEnvironmentFlags.CodingKeys.featureFlags.rawValue] as? [LDFlagKey: Any]
        return flagDictionary?.flagCollection
    }
}

extension CacheableEnvironmentFlags {
    static func stubCollection(userKey: String, environmentCount: Int) -> [MobileKey: CacheableEnvironmentFlags] {
        var environmentFlags = [MobileKey: CacheableEnvironmentFlags]()
        while environmentFlags.count < environmentCount {
            let mobileKey = (environmentFlags.count + 1).mobileKey
            let featureFlags = FeatureFlag.stubFlagCollection(userKey: userKey, mobileKey: mobileKey)
            environmentFlags[mobileKey] = CacheableEnvironmentFlags(userKey: userKey, mobileKey: mobileKey, featureFlags: featureFlags)
        }
        return environmentFlags
    }
}
