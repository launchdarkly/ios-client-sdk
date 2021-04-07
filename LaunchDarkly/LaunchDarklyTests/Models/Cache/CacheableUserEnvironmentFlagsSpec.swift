//
//  CacheableUserEnvironmentsSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class CacheableUserEnvironmentFlagsSpec: QuickSpec {

    private struct TestValues {
        static let userKey = UUID().uuidString
        static let environments = CacheableEnvironmentFlags.stubCollection(userKey: TestValues.userKey, environmentCount: 3)
        static let updated = Date().stringEquivalentDate

        static func defaultEnvironment(withEnvironments: [String: CacheableEnvironmentFlags] = environments) -> CacheableUserEnvironmentFlags {
            CacheableUserEnvironmentFlags(userKey: userKey, environmentFlags: withEnvironments, lastUpdated: updated)
        }
    }

    override func spec() {
        initWithElementsSpec()
        initWithDictionarySpec()
        initWithObjectSpec()
        dictionaryValueSpec()
    }

    private func initWithElementsSpec() {
        describe("init") {
            it("with no environments") {
                let userEnvironmentFlags = TestValues.defaultEnvironment(withEnvironments: [:])
                expect(userEnvironmentFlags.userKey) == TestValues.userKey
                expect(userEnvironmentFlags.environmentFlags) == [:]
                expect(userEnvironmentFlags.lastUpdated) == TestValues.updated
            }
            it("with environments") {
                let userEnvironmentFlags = TestValues.defaultEnvironment()
                expect(userEnvironmentFlags.userKey) == TestValues.userKey
                expect(userEnvironmentFlags.environmentFlags) == TestValues.environments
                expect(userEnvironmentFlags.lastUpdated) == TestValues.updated
            }
        }
    }

    private func initWithDictionarySpec() {
        let defaultDictionary = TestValues.defaultEnvironment().dictionaryValue
        describe("initWithDictionary") {
            context("creates a matching cacheableUserEnvironments") {
                it("with all elements") {
                    let userEnv = CacheableUserEnvironmentFlags(dictionary: defaultDictionary)
                    expect(userEnv?.userKey) == TestValues.userKey
                    expect(userEnv?.environmentFlags) == TestValues.environments
                    expect(userEnv?.lastUpdated) == TestValues.updated
                }
                it("with extra dictionary items") {
                    var testDictionary = defaultDictionary
                    testDictionary["extraKey"] = "abc"
                    let userEnv = CacheableUserEnvironmentFlags(dictionary: testDictionary)
                    expect(userEnv?.userKey) == TestValues.userKey
                    expect(userEnv?.environmentFlags) == TestValues.environments
                    expect(userEnv?.lastUpdated) == TestValues.updated
                }
            }
            for key in CacheableUserEnvironmentFlags.CodingKeys.allCases {
                it("returns nil when \(key.rawValue) missing or invalid") {
                    var testDictionary = defaultDictionary
                    testDictionary[key.rawValue] = 3 // Invalid value for all fields
                    expect(CacheableUserEnvironmentFlags(dictionary: testDictionary)).to(beNil())
                    testDictionary.removeValue(forKey: key.rawValue)
                    expect(CacheableUserEnvironmentFlags(dictionary: testDictionary)).to(beNil())
                }
            }
        }
    }

    private func initWithObjectSpec() {
        describe("initWithObject") {
            it("inits when object is a valid dictionary") {
                let userEnv = CacheableUserEnvironmentFlags(object: TestValues.defaultEnvironment().dictionaryValue)
                expect(userEnv?.userKey) == TestValues.userKey
                expect(userEnv?.environmentFlags) == TestValues.environments
                expect(userEnv?.lastUpdated) == TestValues.updated
            }
            it("return nil when object is not a valid dictionary") {
                expect(CacheableUserEnvironmentFlags(object: 12 as Any)).to(beNil())
            }
        }
    }

    private func dictionaryValueSpec() {
        describe("dictionaryValue") {
            it("creates a dictionary with matching elements") {
                let dict = TestValues.defaultEnvironment().dictionaryValue
                expect(dict["userKey"] as? String) == TestValues.userKey
                let dictEnvs = dict["environmentFlags"] as? [String: [String: Any]]
                expect(dictEnvs?.compactMapValues { CacheableEnvironmentFlags(dictionary: $0)}) == TestValues.environments
                expect(dict["lastUpdated"] as? String) == TestValues.updated.stringValue
            }
            it("creates a dictionary without environments") {
                let dict = TestValues.defaultEnvironment(withEnvironments: [:]).dictionaryValue
                expect(dict["userKey"] as? String) == TestValues.userKey
                expect((dict["environmentFlags"] as? [String: Any])?.isEmpty) == true
                expect(dict["lastUpdated"] as? String) == TestValues.updated.stringValue
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
                                                                   trackEvents: true,
                                                                   debugEventsUntilDate: Date().addingTimeInterval(30.0),
                                                                   reason: DarklyServiceMock.Constants.reason,
                                                                   trackReason: false)
        flagCollection[StubConstants.mobileKey] = FeatureFlag(flagKey: StubConstants.mobileKey,
                                                              value: mobileKey,
                                                              variation: DarklyServiceMock.Constants.variation,
                                                              version: DarklyServiceMock.Constants.version,
                                                              flagVersion: DarklyServiceMock.Constants.flagVersion,
                                                              trackEvents: true,
                                                              debugEventsUntilDate: Date().addingTimeInterval(30.0),
                                                              reason: DarklyServiceMock.Constants.reason,
                                                              trackReason: false)
        return flagCollection
    }
}

extension Date {
    static let stubString = "2018-02-21T18:10:40.823Z"
    static let stubDate = stubString.dateValue
}

extension CacheableEnvironmentFlags {
    static func stubCollection(userKey: String, environmentCount: Int) -> [MobileKey: CacheableEnvironmentFlags] {
        (0..<environmentCount).reduce(into: [:]) { (collection: inout [MobileKey: CacheableEnvironmentFlags], index) in
            let mobileKey = "MobileKey.\(index)"
            let featureFlags = FeatureFlag.stubFlagCollection(userKey: userKey, mobileKey: mobileKey)
            collection[mobileKey] = CacheableEnvironmentFlags(userKey: userKey, mobileKey: mobileKey, featureFlags: featureFlags)
        }
    }
}

extension CacheableUserEnvironmentFlags {
    struct Constants {
        static let environmentCount = 3
        static let userCount = LDConfig.Defaults.maxCachedUsers
    }

    static func stubCollection(userCount: Int = Constants.userCount) -> (users: [LDUser], collection: [UserKey: CacheableUserEnvironmentFlags], mobileKeys: [MobileKey]) {
        var pastSeconds = 0.0

        let users = (0..<userCount).map { i in LDUser.stub(key: "User.\(i)") }

        var userEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags] = [:]
        var mobileKeys: [MobileKey] = []
        users.forEach { user in
            let environmentFlags: [MobileKey: CacheableEnvironmentFlags]
            environmentFlags = CacheableEnvironmentFlags.stubCollection(userKey: user.key, environmentCount: Constants.environmentCount)
            if mobileKeys.isEmpty {
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
