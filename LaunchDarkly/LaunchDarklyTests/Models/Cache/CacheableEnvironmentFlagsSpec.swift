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
                // Ultimately, this is not desired behavior, but currently we are unable to store internal nil/null values
                // inside of the `KeyedValueCache`. When we update our cache format, we can encode all data to get around this.
                it("removes internal nulls") {
                    let flags = ["flag1": FeatureFlag(flagKey: "flag1", value: ["abc": [1, nil, 3]]),
                                 "flag2": FeatureFlag(flagKey: "flag2", value: [1, ["abc": nil], 3])]
                    let cacheable = CacheableEnvironmentFlags(userKey: "user", mobileKey: "mobile", featureFlags: flags)
                    let dictionaryFlags = cacheable.dictionaryValue["featureFlags"] as! [String: [String: Any]]
                    let flag1 = FeatureFlag(dictionary: dictionaryFlags["flag1"])
                    let flag2 = FeatureFlag(dictionary: dictionaryFlags["flag2"])
                    // Manually comparing fields, `==` on `FeatureFlag` does not compare values.
                    expect(flag1?.flagKey) == "flag1"
                    expect(AnyComparer.isEqual(flag1?.value, to: ["abc": [1, 3]])).to(beTrue())
                    expect(flag2?.flagKey) == "flag2"
                    expect(AnyComparer.isEqual(flag2?.value, to: [1, [:], 3])).to(beTrue())
                }
            }
        }
    }
}

extension CacheableEnvironmentFlags: Equatable {
    public static func == (lhs: CacheableEnvironmentFlags, rhs: CacheableEnvironmentFlags) -> Bool {
        lhs.userKey == rhs.userKey
        && lhs.mobileKey == rhs.mobileKey
        && lhs.featureFlags == rhs.featureFlags
    }
}
