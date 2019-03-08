//
//  CacheableUserFlagsSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 2/21/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class CacheableUserFlagsSpec: QuickSpec {
    struct Constants {
        static let lastUpdatedString = "2018-02-21T18:10:40.823Z"
        static let lastUpdatedDate = lastUpdatedString.dateValue
    }

    struct TestContext {
        var userStub: LDUser
        var flagStoreMock: FlagMaintainingMock {
            return userStub.flagStore as! FlagMaintainingMock
        }
        var featureFlags: [LDFlagKey: FeatureFlag] {
            return flagStoreMock.featureFlags
        }
        var cacheableUserFlags: CacheableUserFlags?
        var elementDictionary: [String: Any]
        var dictionaryValue: [String: Any]? {
            return cacheableUserFlags?.dictionaryValue
        }
        var userKeyDictionaryElement: String? {
            return dictionaryValue?[CacheableUserFlags.CodingKeys.userKey.rawValue] as? String
        }
        var flagsDictionaryElement: [LDFlagKey: Any]? {
            return dictionaryValue?[CacheableUserFlags.CodingKeys.flags.rawValue] as? [String: Any]
        }
        var featureFlagsDictionaryElement: [LDFlagKey: FeatureFlag]? {
            return flagsDictionaryElement?.flagCollection
        }
        var lastUpdatedDictionaryElement: String? {
            return dictionaryValue?[CacheableUserFlags.CodingKeys.lastUpdated.rawValue] as? String
        }

        init(includeNullValue: Bool = false,
             includeVersions: Bool = true,
             userKeyTypeMismatch: Bool = false,
             flagTypeMismatch: Bool = false,
             lastUpdatedTypeMismatch: Bool = false,
             withoutKey omitKey: CacheableUserFlags.CodingKeys? = nil) {

            userStub = LDUser.stub(includeNullValue: includeNullValue, includeVersions: includeVersions)
            let featureFlags = userStub.flagStore.featureFlags
            cacheableUserFlags = CacheableUserFlags(userKey: userStub.key, flags: featureFlags, lastUpdated: Constants.lastUpdatedDate)
            elementDictionary = [CacheableUserFlags.CodingKeys.userKey.rawValue: userKeyTypeMismatch ? 1 : userStub.key,
                                 CacheableUserFlags.CodingKeys.flags.rawValue: flagTypeMismatch ? Constants.lastUpdatedString : featureFlags,
                                 CacheableUserFlags.CodingKeys.lastUpdated.rawValue: lastUpdatedTypeMismatch ? Constants.lastUpdatedDate : Constants.lastUpdatedString]
            if let omitKey = omitKey {
                elementDictionary.removeValue(forKey: omitKey.rawValue)
            }
        }
    }

    override func spec() {
        initSpec()
        dictionaryValueSpec()
        equalsSpec()
    }

    private func initSpec() {
        var testContext: TestContext!
        var cacheableUserFlags: CacheableUserFlags?

        describe("init with elements") {
            beforeEach {
                testContext = TestContext()
            }
            it("creates a matching CacheableUserFlags") {
                expect(testContext.cacheableUserFlags?.userKey) == testContext.userStub.key
                expect(AnyComparer.isEqual(testContext.cacheableUserFlags?.flags, to: testContext.featureFlags)).to(beTrue())
                expect(testContext.cacheableUserFlags?.lastUpdated) == Constants.lastUpdatedDate
            }
        }

        describe("init with user") {
            beforeEach {
                testContext = TestContext()

                testContext.cacheableUserFlags = CacheableUserFlags(user: testContext.userStub)
            }
            it("creates a matching CacheableUserFlags") {
                expect(testContext.cacheableUserFlags?.userKey) == testContext.userStub.key
                expect(AnyComparer.isEqual(testContext.cacheableUserFlags?.flags, to: testContext.featureFlags)).to(beTrue())
                expect(testContext.cacheableUserFlags?.lastUpdated) == testContext.userStub.lastUpdated
            }
        }

        describe("init with dictionary") {
            context("with elements") {
                context("matching types") {
                    beforeEach {
                        testContext = TestContext()

                        testContext.cacheableUserFlags = CacheableUserFlags(dictionary: testContext.elementDictionary)
                    }
                    it("creates a matching CacheableUserFlags") {
                        expect(testContext.cacheableUserFlags).toNot(beNil())
                        expect(testContext.cacheableUserFlags?.userKey) == testContext.userStub.key
                        expect(AnyComparer.isEqual(testContext.cacheableUserFlags?.flags, to: testContext.featureFlags)).to(beTrue())
                        expect(testContext.cacheableUserFlags?.lastUpdated) == Constants.lastUpdatedDate
                    }
                }
                context("userKey type mismatch") {
                    beforeEach {
                        testContext = TestContext(userKeyTypeMismatch: true)

                        testContext.cacheableUserFlags = CacheableUserFlags(dictionary: testContext.elementDictionary)
                    }
                    it("returns nil") {
                        expect(testContext.cacheableUserFlags).to(beNil())
                    }
                }
                context("flag type mismatch") {
                    beforeEach {
                        testContext = TestContext(flagTypeMismatch: true)

                        testContext.cacheableUserFlags = CacheableUserFlags(dictionary: testContext.elementDictionary)
                    }
                    it("returns nil") {
                        expect(testContext.cacheableUserFlags).to(beNil())
                    }
                }
                context("date type mismatch") {
                    beforeEach {
                        testContext = TestContext(lastUpdatedTypeMismatch: true)

                        testContext.cacheableUserFlags = CacheableUserFlags(dictionary: testContext.elementDictionary)
                    }
                    it("creates a matching CacheableUserFlags with the current date") {
                        expect(testContext.cacheableUserFlags).toNot(beNil())
                        expect(testContext.cacheableUserFlags?.userKey) == testContext.userStub.key
                        expect(AnyComparer.isEqual(testContext.cacheableUserFlags?.flags, to: testContext.featureFlags)).to(beTrue())
                        expect(testContext.cacheableUserFlags?.lastUpdated.timeIntervalSinceNow) > -0.1   //The exact date won't be right, this is close enough
                    }
                }
            }
            context("missing an element") {
                context("without userKey") {
                    beforeEach {
                        testContext = TestContext(withoutKey: CacheableUserFlags.CodingKeys.userKey)

                        testContext.cacheableUserFlags = CacheableUserFlags(dictionary: testContext.elementDictionary)
                    }
                    it("returns nil") {
                        expect(testContext.cacheableUserFlags).to(beNil())
                    }
                }
                context("without flags") {
                    beforeEach {
                        testContext = TestContext(withoutKey: CacheableUserFlags.CodingKeys.flags)

                        testContext.cacheableUserFlags = CacheableUserFlags(dictionary: testContext.elementDictionary)
                    }
                    it("returns nil") {
                        expect(testContext.cacheableUserFlags).to(beNil())
                    }
                }
                context("without lastUpdated") {
                    beforeEach {
                        testContext = TestContext(withoutKey: CacheableUserFlags.CodingKeys.lastUpdated)

                        testContext.cacheableUserFlags = CacheableUserFlags(dictionary: testContext.elementDictionary)
                    }
                    it("creates a matching CacheableUserFlags with the current date") {
                        expect(testContext.cacheableUserFlags).toNot(beNil())
                        expect(testContext.cacheableUserFlags?.userKey) == testContext.userStub.key
                        expect(AnyComparer.isEqual(testContext.cacheableUserFlags?.flags, to: testContext.featureFlags)).to(beTrue())
                        expect(testContext.cacheableUserFlags?.lastUpdated.timeIntervalSinceNow) > -0.1   //The exact date won't be right, this is close enough
                    }
                }
            }
        }

        describe("init with object") {
            var object: Any!
            context("object is a dictionary") {
                beforeEach {
                    testContext = TestContext()
                    object = testContext.elementDictionary

                    testContext.cacheableUserFlags = CacheableUserFlags(object: object)
                }
                it("creates a matching CacheableUserFlags") {
                    expect(testContext.cacheableUserFlags).toNot(beNil())
                    expect(testContext.cacheableUserFlags?.userKey) == testContext.userStub.key
                    expect(AnyComparer.isEqual(testContext.cacheableUserFlags?.flags, to: testContext.featureFlags)).to(beTrue())
                    expect(testContext.cacheableUserFlags?.lastUpdated) == Constants.lastUpdatedDate
                }
            }
            context("object is not a dictionary") {
                beforeEach {
                    object = Constants.lastUpdatedString

                    cacheableUserFlags = CacheableUserFlags(object: object)
                }
                it("returns nil") {
                    expect(cacheableUserFlags).to(beNil())
                }
            }
        }
    }

    private func dictionaryValueSpec() {
        var testContext: TestContext!
        describe("dictionaryValue") {
            context("when flags do not contain null values") {
                beforeEach {
                    testContext = TestContext(includeNullValue: false)
                }
                it("creates a matching dictionary") {
                    expect(testContext.userKeyDictionaryElement) == testContext.userStub.key
                    expect(AnyComparer.isEqual(testContext.featureFlagsDictionaryElement, to: testContext.featureFlags)).to(beTrue())
                    expect(testContext.lastUpdatedDictionaryElement) == Constants.lastUpdatedString
                }
            }
            context("when flags contain null values") {
                beforeEach {
                    testContext = TestContext(includeNullValue: true)
                }
                it("creates a matching dictionary without null values") {
                    expect(testContext.userKeyDictionaryElement) == testContext.userStub.key
                    expect(AnyComparer.isEqual(testContext.featureFlagsDictionaryElement, to: testContext.featureFlags)).to(beTrue())
                    expect(testContext.lastUpdatedDictionaryElement) == Constants.lastUpdatedString
                }
            }
            context("when flags contain null versions") {
                var flagDictionary: [String: Any]?
                var flagDictionaryValue: Any? {
                    return flagDictionary?[FeatureFlag.CodingKeys.value.rawValue]
                }
                var flagDictionaryVersion: Int? {
                    return flagDictionary?[FeatureFlag.CodingKeys.version.rawValue] as? Int
                }
                beforeEach {
                    testContext = TestContext(includeVersions: false)
                }
                it("creates a matching dictionary with version placeholders") {
                    testContext.featureFlags.keys.forEach { (key) in
                        flagDictionary = testContext.flagsDictionaryElement?[key] as? [String: Any]
                        expect(AnyComparer.isEqual(flagDictionaryValue, to: testContext.featureFlags[key]?.value)).to(beTrue())
                        expect(flagDictionaryVersion).to(beNil())
                    }
                }
            }
        }
    }

    private func equalsSpec() {
        var testContext: TestContext!
        var other: CacheableUserFlags!
        describe("equals") {
            context("when elements match") {
                beforeEach {
                    testContext = TestContext()
                    other = CacheableUserFlags(userKey: testContext.userStub.key,
                                               flags: testContext.featureFlags,
                                               lastUpdated: Constants.lastUpdatedDate)
                }
                it("returns true") {
                    expect(testContext.cacheableUserFlags) == other
                }
            }
            context("when userKeys do not match") {
                beforeEach {
                    testContext = TestContext()
                    other = CacheableUserFlags(userKey: UUID().uuidString, flags: testContext.featureFlags, lastUpdated: Constants.lastUpdatedDate)
                }
                it("returns false") {
                    expect(testContext.cacheableUserFlags) != other
                }
            }
            context("when flags do not match") {
                beforeEach {
                    testContext = TestContext()
                    other = CacheableUserFlags(userKey: testContext.userStub.key,
                                               flags: DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false),
                                               lastUpdated: Constants.lastUpdatedDate)
                }
                it("returns false") {
                    expect(testContext.cacheableUserFlags) != other
                }
            }
            context("when last updates does not match") {
                beforeEach {
                    testContext = TestContext()
                    other = CacheableUserFlags(userKey: testContext.userStub.key, flags: testContext.featureFlags, lastUpdated: Date())
                }
                it("returns false") {
                    expect(testContext.cacheableUserFlags) != other
                }
            }
        }
    }
}
