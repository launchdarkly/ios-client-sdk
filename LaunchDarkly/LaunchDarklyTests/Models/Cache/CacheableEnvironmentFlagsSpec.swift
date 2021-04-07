//
//  CacheableEnvironmentFlagsSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class CacheableEnvironmentFlagsSpec: QuickSpec {

    private struct TestValues {
        static let userKey = UUID().uuidString
        static let mobKey = UUID().uuidString
        static let flags = FlagMaintainingMock.stubFlags()

        static func defaultEnvironment(withFlags: [String: FeatureFlag] = flags) -> CacheableEnvironmentFlags {
            CacheableEnvironmentFlags(userKey: userKey, mobileKey: mobKey, featureFlags: withFlags)
        }
    }

    override func spec() {
        initWithElementsSpec()
        initWithDictionarySpec()
        dictionaryValueSpec()
        equalsSpec()
    }

    private func initWithElementsSpec() {
        describe("initWithElements") {
            it("creates a CacheableEnvironmentFlags with the elements") {
                let environmentFlags = TestValues.defaultEnvironment()
                expect(environmentFlags.userKey) == TestValues.userKey
                expect(environmentFlags.mobileKey) == TestValues.mobKey
                expect(environmentFlags.featureFlags) == TestValues.flags
            }
        }
    }

    private func initWithDictionarySpec() {
        let defaultDictionary = TestValues.defaultEnvironment().dictionaryValue
        describe("initWithDictionary") {
            context("creates a new CacheableEnvironmentFlags") {
                it("with all elements") {
                    let other = CacheableEnvironmentFlags(dictionary: defaultDictionary)
                    expect(other?.userKey) == TestValues.userKey
                    expect(other?.mobileKey) == TestValues.mobKey
                    expect(other?.featureFlags) == TestValues.flags
                }
                it("with extra elements") {
                    var testDictionary = defaultDictionary
                    testDictionary["extraKey"] = "abc"
                    let other = CacheableEnvironmentFlags(dictionary: testDictionary)
                    expect(other?.userKey) == TestValues.userKey
                    expect(other?.mobileKey) == TestValues.mobKey
                    expect(other?.featureFlags) == TestValues.flags
                }
            }
            for key in CacheableEnvironmentFlags.CodingKeys.allCases {
                it("returns nil when \(key.rawValue) missing or invalid") {
                    var testDictionary = defaultDictionary
                    testDictionary[key.rawValue] = 3 // Invalid value for all fields
                    expect(CacheableEnvironmentFlags(dictionary: testDictionary)).to(beNil())
                    testDictionary.removeValue(forKey: key.rawValue)
                    expect(CacheableEnvironmentFlags(dictionary: testDictionary)).to(beNil())
                }
            }
        }
    }

    private func dictionaryValueSpec() {
        describe("dictionaryValue") {
            context("creates a dictionary with the elements") {
                it("with null feature flag value") {
                    let cacheDictionary = TestValues.defaultEnvironment().dictionaryValue
                    expect(cacheDictionary["userKey"] as? String) == TestValues.userKey
                    expect(cacheDictionary["mobileKey"] as? String) == TestValues.mobKey
                    expect((cacheDictionary["featureFlags"] as? [LDFlagKey: Any])?.flagCollection) == TestValues.flags
                }
                it("without feature flags") {
                    let cacheDictionary = TestValues.defaultEnvironment(withFlags: [:]).dictionaryValue
                    expect(cacheDictionary["userKey"] as? String) == TestValues.userKey
                    expect(cacheDictionary["mobileKey"] as? String) == TestValues.mobKey
                    expect(AnyComparer.isEqual(cacheDictionary["featureFlags"], to: [:])) == true
                }
            }
        }
    }

    private func equalsSpec() {
        let environmentFlags = TestValues.defaultEnvironment()
        describe("equals") {
            it("returns true when elements are equal") {
                let other = CacheableEnvironmentFlags(userKey: environmentFlags.userKey,
                                                      mobileKey: environmentFlags.mobileKey,
                                                      featureFlags: environmentFlags.featureFlags)
                expect(environmentFlags == other) == true
            }
            context("returns false") {
                it("when the userKey differs") {
                    let other = CacheableEnvironmentFlags(userKey: UUID().uuidString,
                                                          mobileKey: environmentFlags.mobileKey,
                                                          featureFlags: environmentFlags.featureFlags)
                    expect(environmentFlags == other) == false
                }
                it("when the mobileKey differs") {
                    let other = CacheableEnvironmentFlags(userKey: environmentFlags.userKey,
                                                          mobileKey: UUID().uuidString,
                                                          featureFlags: environmentFlags.featureFlags)
                    expect(environmentFlags == other) == false
                }
                it("when the featureFlags differ") {
                    var otherFlags = environmentFlags.featureFlags
                    otherFlags.removeValue(forKey: otherFlags.first!.key)
                    let other = CacheableEnvironmentFlags(userKey: environmentFlags.userKey,
                                                          mobileKey: environmentFlags.mobileKey,
                                                          featureFlags: otherFlags)
                    expect(environmentFlags == other) == false
                }
            }
        }
    }
}
