//
//  LDUserSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 10/23/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
@testable import LaunchDarkly

final class LDUserSpec: QuickSpec {

    struct Constants {
        fileprivate static let userCount = 3
    }

    override func spec() {
        initSpec()
        dictionaryValueSpec()
    }

    private func initSpec() {
        initSubSpec()
        initFromDictionarySpec()
        initWithEnvironmentReporterSpec()
    }

    private func initSubSpec() {
        var user: LDUser!
        describe("init") {
            context("called with optional elements") {
                context("including system values") {
                    beforeEach {
                        user = LDUser(key: LDUser.StubConstants.key, name: LDUser.StubConstants.name, firstName: LDUser.StubConstants.firstName, lastName: LDUser.StubConstants.lastName,
                                      country: LDUser.StubConstants.country, ipAddress: LDUser.StubConstants.ipAddress, email: LDUser.StubConstants.email, avatar: LDUser.StubConstants.avatar,
                                      custom: LDUser.StubConstants.custom(includeSystemValues: true), isAnonymous: LDUser.StubConstants.isAnonymous,
                                      privateAttributes: LDUser.privatizableAttributes)
                    }
                    it("creates a LDUser with optional elements") {
                        expect(user.key) == LDUser.StubConstants.key
                        expect(user.name) == LDUser.StubConstants.name
                        expect(user.firstName) == LDUser.StubConstants.firstName
                        expect(user.lastName) == LDUser.StubConstants.lastName
                        expect(user.isAnonymous) == LDUser.StubConstants.isAnonymous
                        expect(user.country) == LDUser.StubConstants.country
                        expect(user.ipAddress) == LDUser.StubConstants.ipAddress
                        expect(user.email) == LDUser.StubConstants.email
                        expect(user.avatar) == LDUser.StubConstants.avatar
                        expect(user.device) == LDUser.StubConstants.device
                        expect(user.operatingSystem) == LDUser.StubConstants.operatingSystem
                        expect(user.custom).toNot(beNil())
                        if let subjectCustom = user.custom {
                            expect(subjectCustom == LDUser.StubConstants.custom(includeSystemValues: true)).to(beTrue())
                        }
                        expect(user.lastUpdated).toNot(beNil())
                        expect(user.privateAttributes).toNot(beNil())
                        if let privateAttributes = user.privateAttributes {
                            expect(privateAttributes) == LDUser.privatizableAttributes
                        }
                    }
                }
                context("excluding system values") {
                    beforeEach {
                        user = LDUser(key: LDUser.StubConstants.key, name: LDUser.StubConstants.name, firstName: LDUser.StubConstants.firstName, lastName: LDUser.StubConstants.lastName,
                                      country: LDUser.StubConstants.country, ipAddress: LDUser.StubConstants.ipAddress, email: LDUser.StubConstants.email, avatar: LDUser.StubConstants.avatar,
                                      custom: LDUser.StubConstants.custom(includeSystemValues: false), isAnonymous: LDUser.StubConstants.isAnonymous, device: LDUser.StubConstants.device, operatingSystem: LDUser.StubConstants.operatingSystem, privateAttributes: LDUser.privatizableAttributes)
                    }
                    it("creates a LDUser with optional elements") {
                        expect(user.key) == LDUser.StubConstants.key
                        expect(user.name) == LDUser.StubConstants.name
                        expect(user.firstName) == LDUser.StubConstants.firstName
                        expect(user.lastName) == LDUser.StubConstants.lastName
                        expect(user.isAnonymous) == LDUser.StubConstants.isAnonymous
                        expect(user.country) == LDUser.StubConstants.country
                        expect(user.ipAddress) == LDUser.StubConstants.ipAddress
                        expect(user.email) == LDUser.StubConstants.email
                        expect(user.avatar) == LDUser.StubConstants.avatar
                        expect(user.device) == LDUser.StubConstants.device
                        expect(user.operatingSystem) == LDUser.StubConstants.operatingSystem
                        expect(user.custom).toNot(beNil())
                        if let subjectCustom = user.custom {
                            expect(subjectCustom == LDUser.StubConstants.custom(includeSystemValues: false)).to(beTrue())
                        }
                        expect(user.lastUpdated).toNot(beNil())
                        expect(user.privateAttributes).toNot(beNil())
                        if let privateAttributes = user.privateAttributes {
                            expect(privateAttributes) == LDUser.privatizableAttributes
                        }
                    }
                }
            }
            context("called without optional elements") {
                var environmentReporter: EnvironmentReporter!
                beforeEach {
                    user = LDUser()
                    environmentReporter = EnvironmentReporter()
                }
                it("creates a LDUser without optional elements") {
                    expect(user.key) == LDUser.defaultKey(environmentReporter: environmentReporter)
                    expect(user.isAnonymous) == true
                    expect(user.lastUpdated).toNot(beNil())

                    expect(user.name).to(beNil())
                    expect(user.firstName).to(beNil())
                    expect(user.lastName).to(beNil())
                    expect(user.country).to(beNil())
                    expect(user.ipAddress).to(beNil())
                    expect(user.email).to(beNil())
                    expect(user.avatar).to(beNil())
                    expect(user.device) == environmentReporter.deviceModel
                    expect(user.operatingSystem) == environmentReporter.systemVersion
                    expect(user.custom).to(beNil())
                    expect(user.privateAttributes).to(beNil())
                }
            }
            context("called without a key multiple times") {
                var users = [LDUser]()
                beforeEach {
                    while users.count < Constants.userCount {
                        users.append(LDUser())
                    }
                }
                it("creates each LDUser with the default key and isAnonymous set") {
                    let environmentReporter = EnvironmentReporter()
                    users.forEach { (user) in
                        expect(user.key) == LDUser.defaultKey(environmentReporter: environmentReporter)
                        expect(user.isAnonymous) == true
                    }
                }
            }
        }
    }

    private func initFromDictionarySpec() {
        describe("init from dictionary") {
            var user: LDUser!
            var originalUser: LDUser!
            let mockLastUpdated = "2017-10-24T17:51:49.142Z"
            context("called with config") {
                context("and optional elements") {
                    beforeEach {
                        originalUser = LDUser.stub()
                        var userDictionary = originalUser.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: true, config: LDConfig.stub)
                        userDictionary[LDUser.CodingKeys.lastUpdated.rawValue] = mockLastUpdated
                        userDictionary[LDUser.CodingKeys.privateAttributes.rawValue] = LDUser.privatizableAttributes
                        user = LDUser(userDictionary: userDictionary)
                    }
                    it("creates a user with optional elements and feature flags") {
                        expect(user.key) == originalUser.key
                        expect(user.name) == originalUser.name
                        expect(user.firstName) == originalUser.firstName
                        expect(user.lastName) == originalUser.lastName
                        expect(user.isAnonymous) == originalUser.isAnonymous
                        expect(user.country) == originalUser.country
                        expect(user.ipAddress) == originalUser.ipAddress
                        expect(user.email) == originalUser.email
                        expect(user.avatar) == originalUser.avatar

                        expect(originalUser.custom).toNot(beNil())
                        expect(user.custom).toNot(beNil())
                        if let originalCustom = originalUser.custom,
                            let subjectCustom = user.custom {
                            expect(subjectCustom == originalCustom).to(beTrue())
                        }

                        expect(user.device) == originalUser.device
                        expect(user.operatingSystem) == originalUser.operatingSystem
                        expect(user.lastUpdated) == DateFormatter.ldDateFormatter.date(from: mockLastUpdated)

                        expect(user.privateAttributes).toNot(beNil())
                        if let privateAttributes = user.privateAttributes {
                            expect(privateAttributes) == LDUser.privatizableAttributes
                        }

                        expect(user.flagStore.featureFlags == originalUser.flagStore.featureFlags).to(beTrue())
                    }
                }
                context("but without optional elements") {
                    beforeEach {
                        originalUser = LDUser(isAnonymous: true)
                        var userDictionary = originalUser.dictionaryValueWithAllAttributes(includeFlagConfig: true)
                        userDictionary[LDUser.CodingKeys.lastUpdated.rawValue] = mockLastUpdated
                        user = LDUser(userDictionary: userDictionary)

                    }
                    it("creates a user without optional elements and with feature flags") {
                        expect(user.key) == originalUser.key
                        expect(user.isAnonymous) == originalUser.isAnonymous
                        expect(user.lastUpdated) == DateFormatter.ldDateFormatter.date(from: mockLastUpdated)

                        expect(user.name).to(beNil())
                        expect(user.firstName).to(beNil())
                        expect(user.lastName).to(beNil())
                        expect(user.country).to(beNil())
                        expect(user.ipAddress).to(beNil())
                        expect(user.email).to(beNil())
                        expect(user.avatar).to(beNil())
                        expect(user.device).toNot(beNil())
                        expect(user.operatingSystem).toNot(beNil())

                        expect(user.custom).toNot(beNil())
                        if let customDictionary = user.customWithoutSdkSetAttributes {
                            expect(customDictionary.isEmpty) == true
                        }
                        expect(user.privateAttributes).to(beNil())

                        expect(user.flagStore.featureFlags == originalUser.flagStore.featureFlags).to(beTrue())
                    }
                }
            }
            context("called without config") {
                context("but with optional elements") {
                    beforeEach {
                        originalUser = LDUser.stub()
                        originalUser.privateAttributes = LDUser.privatizableAttributes
                        var userDictionary = originalUser.dictionaryValueWithAllAttributes(includeFlagConfig: false)
                        userDictionary[LDUser.CodingKeys.lastUpdated.rawValue] = mockLastUpdated
                        userDictionary[LDUser.CodingKeys.privateAttributes.rawValue] = LDUser.privatizableAttributes
                        user = LDUser(userDictionary: userDictionary)
                    }
                    it("creates a user with optional elements") {
                        expect(user.key) == originalUser.key
                        expect(user.name) == originalUser.name
                        expect(user.firstName) == originalUser.firstName
                        expect(user.lastName) == originalUser.lastName
                        expect(user.isAnonymous) == originalUser.isAnonymous
                        expect(user.country) == originalUser.country
                        expect(user.ipAddress) == originalUser.ipAddress
                        expect(user.email) == originalUser.email
                        expect(user.avatar) == originalUser.avatar

                        expect(originalUser.custom).toNot(beNil())
                        expect(user.custom).toNot(beNil())
                        if let originalCustom = originalUser.custom,
                            let subjectCustom = user.custom {
                            expect(subjectCustom == originalCustom).to(beTrue())
                        }

                        expect(user.device) == originalUser.device
                        expect(user.operatingSystem) == originalUser.operatingSystem
                        expect(user.lastUpdated) == DateFormatter.ldDateFormatter.date(from: mockLastUpdated)

                        expect(user.privateAttributes).toNot(beNil())
                        if let privateAttributes = user.privateAttributes {
                            expect(privateAttributes) == LDUser.privatizableAttributes
                        }

                        expect(user.flagStore.featureFlags.isEmpty).to(beTrue())
                    }
                }
                context("or optional elements") {
                    beforeEach {
                        originalUser = LDUser(isAnonymous: true)
                        var userDictionary = originalUser.dictionaryValueWithAllAttributes(includeFlagConfig: false)
                        userDictionary[LDUser.CodingKeys.lastUpdated.rawValue] = mockLastUpdated
                        user = LDUser(userDictionary: userDictionary)
                    }
                    it("creates a user without optional elements or feature flags") {
                        expect(user.key) == originalUser.key
                        expect(user.isAnonymous) == originalUser.isAnonymous
                        expect(user.lastUpdated) == DateFormatter.ldDateFormatter.date(from: mockLastUpdated)

                        expect(user.name).to(beNil())
                        expect(user.firstName).to(beNil())
                        expect(user.lastName).to(beNil())
                        expect(user.country).to(beNil())
                        expect(user.ipAddress).to(beNil())
                        expect(user.email).to(beNil())
                        expect(user.avatar).to(beNil())
                        expect(user.device).toNot(beNil())
                        expect(user.operatingSystem).toNot(beNil())
                        expect(user.custom).toNot(beNil())
                        if let customDictionary = user.customWithoutSdkSetAttributes {
                            expect(customDictionary.isEmpty) == true
                        }
                        expect(user.privateAttributes).to(beNil())

                        expect(user.flagStore.featureFlags.isEmpty).to(beTrue())
                    }
                }
                context("and with an empty dictionary") {
                    beforeEach {
                        user = LDUser(userDictionary: [:])
                    }
                    it("creates a user without optional elements or feature flags") {
                        expect(user.key).toNot(beNil())
                        expect(user.key.isEmpty).to(beFalse())
                        expect(user.isAnonymous) == false
                        expect(user.lastUpdated).toNot(beNil())

                        expect(user.name).to(beNil())
                        expect(user.firstName).to(beNil())
                        expect(user.lastName).to(beNil())
                        expect(user.country).to(beNil())
                        expect(user.ipAddress).to(beNil())
                        expect(user.email).to(beNil())
                        expect(user.avatar).to(beNil())
                        expect(user.device).to(beNil())
                        expect(user.operatingSystem).to(beNil())
                        expect(user.custom).to(beNil())
                        expect(user.privateAttributes).to(beNil())

                        expect(user.flagStore.featureFlags.isEmpty).to(beTrue())
                    }
                }
                context("but with an incorrect last updated format") {
                    let invalidLastUpdated = "2017-10-24T17:51:49Z"
                    beforeEach {
                        user = LDUser(userDictionary: [LDUser.CodingKeys.lastUpdated.rawValue: invalidLastUpdated])
                    }
                    it("creates a user without optional elements or feature flags") {
                        expect(user.key).toNot(beNil())
                        expect(user.key.isEmpty).to(beFalse())
                        expect(user.isAnonymous) == false
                        expect(user.lastUpdated).toNot(beNil())
                        expect(DateFormatter.ldDateFormatter.string(from: user.lastUpdated)) != invalidLastUpdated

                        expect(user.name).to(beNil())
                        expect(user.firstName).to(beNil())
                        expect(user.lastName).to(beNil())
                        expect(user.country).to(beNil())
                        expect(user.ipAddress).to(beNil())
                        expect(user.email).to(beNil())
                        expect(user.avatar).to(beNil())
                        expect(user.device).to(beNil())
                        expect(user.operatingSystem).to(beNil())
                        expect(user.custom).to(beNil())
                        expect(user.privateAttributes).to(beNil())

                        expect(user.flagStore.featureFlags.isEmpty).to(beTrue())
                    }
                }
            }
        }
    }

    private func initWithEnvironmentReporterSpec() {
        describe("initWithEnvironmentReporter") {
            var user: LDUser!
            var environmentReporter: EnvironmentReportingMock!
            beforeEach {
                environmentReporter = EnvironmentReportingMock()
                user = LDUser(environmentReporter: environmentReporter)
            }
            it("creates a user with system values matching the environment reporter") {
                expect(user.key) == LDUser.defaultKey(environmentReporter: environmentReporter)
                expect(user.isAnonymous) == true
                expect(user.lastUpdated).toNot(beNil())

                expect(user.name).to(beNil())
                expect(user.firstName).to(beNil())
                expect(user.lastName).to(beNil())
                expect(user.country).to(beNil())
                expect(user.ipAddress).to(beNil())
                expect(user.email).to(beNil())
                expect(user.avatar).to(beNil())
                expect(user.device) == environmentReporter.deviceModel
                expect(user.operatingSystem) == environmentReporter.systemVersion

                expect(user.custom).to(beNil())
                expect(user.privateAttributes).to(beNil())

                expect(user.flagStore.featureFlags.isEmpty).to(beTrue())
            }
        }
    }

    private func dictionaryValueSpec() {
        describe("dictionaryValue") {
            var user: LDUser!
            var config: LDConfig!
            var userDictionary: [String: Any]!
            var privateAttributes: [String]!
            context("including private attributes") {
                context("with individual private attributes") {
                    context("contained in the config") {
                        beforeEach {
                            config = LDConfig.stub
                            user = LDUser.stub()
                            privateAttributes = LDUser.privatizableAttributes + user.customAttributes!
                        }
                        it("creates a matching dictionary") {
                            privateAttributes.forEach { (attribute) in
                                config.privateUserAttributes = [attribute]
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                    //creates a dictionary with matching key value pairs
                                    expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                    expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                    expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                    expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())

                                    //creates a dictionary without redacted attributes
                                    expect(userDictionary.redactedAttributes).to(beNil())

                                    //creates a dictionary with or without a matching flag config
                                    includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                        : expect(userDictionary.flagConfig).to(beNil())
                                }
                            }
                        }
                    }
                    context("contained in the user") {
                        context("on a populated user") {
                            beforeEach {
                                config = LDConfig.stub
                                user = LDUser.stub()
                                privateAttributes = LDUser.privatizableAttributes + user.customAttributes!
                            }
                            it("creates a matching dictionary") {
                                privateAttributes.forEach { (attribute) in
                                    user.privateAttributes = [attribute]
                                    [true, false].forEach { (includeFlagConfig) in
                                        userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                        //creates a dictionary with matching key value pairs
                                        expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                        expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                        expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                        expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())

                                        //creates a dictionary without redacted attributes
                                        expect(userDictionary.redactedAttributes).to(beNil())

                                        //creates a dictionary with or without a matching flag config
                                        includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                            : expect(userDictionary.flagConfig).to(beNil())
                                    }
                                }
                            }
                        }
                        context("on an empty user") {
                            beforeEach {
                                config = LDConfig.stub
                                user = LDUser()
                                privateAttributes = LDUser.privatizableAttributes
                            }
                            it("creates a matching dictionary") {
                                privateAttributes.forEach { (attribute) in
                                    user.privateAttributes = [attribute]
                                    [true, false].forEach { (includeFlagConfig) in
                                        userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                        //creates a dictionary with matching key value pairs
                                        expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                        expect({ user.optionalAttributeMissingValueKeysDontExist(userDictionary: userDictionary) }).to(match())
                                        expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                        expect({ user.customDictionaryContainsOnlySdkSetAttributes(userDictionary: userDictionary) }).to(match())

                                        //creates a dictionary without redacted attributes
                                        expect(userDictionary.redactedAttributes).to(beNil())

                                        //creates a dictionary with or without a matching flag config
                                        includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                            : expect(userDictionary.flagConfig).to(beNil())
                                    }
                                }
                            }
                        }
                    }
                }
                context("with all private attributes") {
                    context("using the config flag") {
                        beforeEach {
                            config = LDConfig.stub
                            config.allUserAttributesPrivate = true
                            user = LDUser.stub()
                        }
                        it("creates a dictionary with matching key value pairs") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            }
                        }
                        it("creates a dictionary without redacted attributes") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                expect(userDictionary.redactedAttributes).to(beNil())
                            }
                        }
                        it("creates a dictionary with or without a matching flag config") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                    : expect(userDictionary.flagConfig).to(beNil())
                            }
                        }
                    }
                    context("contained in the config") {
                        beforeEach {
                            config = LDConfig.stub
                            config.privateUserAttributes = LDUser.privatizableAttributes
                            user = LDUser.stub()
                        }
                        it("creates a dictionary with matching key value pairs") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            }
                        }
                        it("creates a dictionary without redacted attributes") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                expect(userDictionary.redactedAttributes).to(beNil())
                            }
                        }
                        it("creates a dictionary with or without a matching flag config") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                    : expect(userDictionary.flagConfig).to(beNil())
                            }
                        }
                    }
                    context("contained in the user") {
                        beforeEach {
                            config = LDConfig.stub
                            user = LDUser.stub()
                            user.privateAttributes = LDUser.privatizableAttributes
                        }
                        it("creates a dictionary with matching key value pairs") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            }
                        }
                        it("creates a dictionary without redacted attributes") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                expect(userDictionary.redactedAttributes).to(beNil())
                            }
                        }
                        it("creates a dictionary with or without a matching flag config") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                    : expect(userDictionary.flagConfig).to(beNil())
                            }
                        }
                    }
                }
                context("with no private attributes") {
                    context("by setting private attributes to nil") {
                        beforeEach {
                            config = LDConfig.stub
                            user = LDUser.stub()
                        }
                        it("creates a dictionary with matching key value pairs") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            }
                        }
                        it("creates a dictionary without redacted attributes") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                expect(userDictionary.redactedAttributes).to(beNil())
                            }
                        }
                        it("creates a dictionary with or without a matching flag config") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                    : expect(userDictionary.flagConfig).to(beNil())
                            }
                        }
                    }
                    context("by setting config private attributes to empty") {
                        beforeEach {
                            config = LDConfig.stub
                            config.privateUserAttributes = []
                            user = LDUser.stub()
                        }
                        it("creates a dictionary with matching key value pairs") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            }
                        }
                        it("creates a dictionary without redacted attributes") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                expect(userDictionary.redactedAttributes).to(beNil())
                            }
                        }
                        it("creates a dictionary with or without a matching flag config") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match()) : expect(userDictionary.flagConfig).to(beNil())
                            }
                        }
                    }
                    context("by setting user private attributes to empty") {
                        beforeEach {
                            config = LDConfig.stub
                            user = LDUser.stub()
                            user.privateAttributes = []
                        }
                        it("creates a dictionary with matching key value pairs") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            }
                        }
                        it("creates a dictionary without redacted attributes") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)
                                expect(userDictionary.redactedAttributes).to(beNil())
                            }
                        }
                        it("creates a dictionary with or without a matching flag config") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                    : expect(userDictionary.flagConfig).to(beNil())
                            }
                        }
                    }
                }
                context("with custom as the private attribute") {
                    context("on a user with no custom dictionary") {
                        context("with a device and os") {
                            beforeEach {
                                config = LDConfig.stub
                                user = LDUser.stub()
                                user.custom = nil
                                user.privateAttributes = [LDUser.CodingKeys.custom.rawValue]
                            }
                            it("creates a dictionary with matching key value pairs") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                    expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                    expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                    expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                    expect({ user.customDictionaryContainsOnlySdkSetAttributes(userDictionary: userDictionary) }).to(match())
                                }
                            }
                            it("creates a dictionary without redacted attributes") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                    expect(userDictionary.redactedAttributes).to(beNil())
                                }
                            }
                            it("creates a dictionary with or without a matching flag config") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                    includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                        : expect(userDictionary.flagConfig).to(beNil())
                                }
                            }
                        }
                        context("without a device and os") {
                            beforeEach {
                                config = LDConfig.stub
                                user = LDUser.stub()
                                user.custom = nil
                                user.operatingSystem = nil
                                user.device = nil
                                user.privateAttributes = [LDUser.CodingKeys.custom.rawValue]
                            }
                            it("creates a dictionary with matching key value pairs") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                    expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                    expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                }
                            }
                            it("creates a dictionary without redacted attributes") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                    expect(userDictionary.redactedAttributes).to(beNil())
                                }
                            }
                            it("creates a dictionary without a custom dictionary") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                    expect(userDictionary.customDictionary(includeSdkSetAttributes: true)).to(beNil())
                                }
                            }
                            it("creates a dictionary with or without a matching flag config") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                    includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                        : expect(userDictionary.flagConfig).to(beNil())
                                }
                            }
                        }
                    }
                    context("on a user with a custom dictionary") {
                        context("without a device and os") {
                            beforeEach {
                                config = LDConfig.stub
                                user = LDUser.stub() //The user stub puts device & operating system in both the user attributes and the custom dictionary
                                user.custom = user.customWithoutSdkSetAttributes
                                user.device = nil
                                user.operatingSystem = nil
                                user.privateAttributes = [LDUser.CodingKeys.custom.rawValue]
                            }
                            it("creates a dictionary with matching key value pairs") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                    expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                    expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                    expect({ user.sdkSetAttributesDontExist(userDictionary: userDictionary) }).to(match())
                                    expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                }
                            }
                            it("creates a dictionary without redacted attributes") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                    expect(userDictionary.redactedAttributes).to(beNil())
                                }
                            }
                            it("creates a dictionary with or without a matching flag config") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: config)

                                    includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                        : expect(userDictionary.flagConfig).to(beNil())
                                }
                            }
                        }
                    }
                }
            }
            context("excluding private attributes") {
                context("with individual private attributes") {
                    context("contained in the config") {
                        beforeEach {
                            config = LDConfig.stub
                            user = LDUser.stub()
                            privateAttributes = LDUser.privatizableAttributes + user.customAttributes!
                        }
                        it("creates a matching dictionary") {
                            privateAttributes.forEach { (attribute) in
                                let privateAttributesForTest = [attribute]
                                config.privateUserAttributes = privateAttributesForTest
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                    //creates a dictionary with matching key value pairs
                                    expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                    expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: privateAttributesForTest) }).to(match())
                                    expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())

                                    //creates a dictionary without private keys
                                    expect({ user.optionalAttributePrivateKeysDontExist(userDictionary: userDictionary, privateAttributes: privateAttributesForTest) }).to(match())

                                    //creates a dictionary with redacted attributes
                                    expect({ user.optionalAttributePrivateKeysAppearInPrivateAttrsWhenRedacted(userDictionary: userDictionary,
                                                                                                                  privateAttributes: privateAttributesForTest) }).to(match())
                                    expect({ user.optionalAttributePublicOrMissingKeysDontAppearInPrivateAttrs(userDictionary: userDictionary,
                                                                                                                  privateAttributes: privateAttributesForTest) }).to(match())

                                    //creates a custom dictionary with matching key value pairs, without private keys, and with redacted attributes
                                    if privateAttributesForTest.contains(LDUser.CodingKeys.custom.rawValue) {
                                        expect({ user.customDictionaryContainsOnlySdkSetAttributes(userDictionary: userDictionary) }).to(match())
                                        expect(user.privateAttrsContainsCustom(userDictionary: userDictionary)).to(beTrue())
                                    } else {
                                        expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: privateAttributesForTest) }).to(match())
                                        expect({ user.customDictionaryPrivateKeysDontExist(userDictionary: userDictionary, privateAttributes: privateAttributesForTest) }).to(match())

                                        expect({ user.customPrivateKeysAppearInPrivateAttrsWhenRedacted(userDictionary: userDictionary,
                                                                                                           privateAttributes: privateAttributesForTest) }).to(match())
                                        expect({ user.customPublicOrMissingKeysDontAppearInPrivateAttrs(userDictionary: userDictionary,
                                                                                                           privateAttributes: privateAttributesForTest) }).to(match())
                                    }

                                    //creates a dictionary with or without matching flag config
                                    includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                        : expect(userDictionary.flagConfig).to(beNil())
                                }
                            }
                        }
                    }
                    context("contained in the user") {
                        context("on a populated user") {
                            beforeEach {
                                config = LDConfig.stub
                                user = LDUser.stub()
                                privateAttributes = LDUser.privatizableAttributes + user.customAttributes!
                            }
                            it("creates a matching dictionary") {
                                privateAttributes.forEach { (attribute) in
                                    let privateAttributesForTest = [attribute]
                                    user.privateAttributes = privateAttributesForTest
                                    [true, false].forEach { (includeFlagConfig) in
                                        userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                        //creates a dictionary with matching key value pairs
                                        expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                        expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: privateAttributesForTest) }).to(match())
                                        expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())

                                        //creates a dictionary without private keys
                                        expect({ user.optionalAttributePrivateKeysDontExist(userDictionary: userDictionary, privateAttributes: privateAttributesForTest) }).to(match())

                                        //creates a dictionary with redacted attributes
                                        expect({ user.optionalAttributePrivateKeysAppearInPrivateAttrsWhenRedacted(userDictionary: userDictionary,
                                                                                                                      privateAttributes: privateAttributesForTest) }).to(match())
                                        expect({ user.optionalAttributePublicOrMissingKeysDontAppearInPrivateAttrs(userDictionary: userDictionary,
                                                                                                                      privateAttributes: privateAttributesForTest) }).to(match())

                                        //creates a custom dictionary with matching key value pairs, without private keys, and with redacted attributes
                                        if privateAttributesForTest.contains(LDUser.CodingKeys.custom.rawValue) {
                                            expect({ user.customDictionaryContainsOnlySdkSetAttributes(userDictionary: userDictionary) }).to(match())
                                            expect(user.privateAttrsContainsCustom(userDictionary: userDictionary)).to(beTrue())
                                        } else {
                                            expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary,
                                                                                                      privateAttributes: privateAttributesForTest) }).to(match())
                                            expect({ user.customDictionaryPrivateKeysDontExist(userDictionary: userDictionary,
                                                                                                  privateAttributes: privateAttributesForTest) }).to(match())

                                            expect({ user.customPrivateKeysAppearInPrivateAttrsWhenRedacted(userDictionary: userDictionary,
                                                                                                               privateAttributes: privateAttributesForTest) }).to(match())
                                            expect({ user.customPublicOrMissingKeysDontAppearInPrivateAttrs(userDictionary: userDictionary,
                                                                                                               privateAttributes: privateAttributesForTest) }).to(match())
                                        }

                                        //creates a dictionary with or without matching flag config
                                        includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                            : expect(userDictionary.flagConfig).to(beNil())
                                    }
                                }
                            }
                        }
                        context("on an empty user") {
                            beforeEach {
                                config = LDConfig.stub
                                user = LDUser()
                                privateAttributes = LDUser.privatizableAttributes
                            }
                            it("creates a matching dictionary") {
                                privateAttributes.forEach { (attribute) in
                                    let privateAttributesForTest = [attribute]
                                    user.privateAttributes = privateAttributesForTest
                                    [true, false].forEach { (includeFlagConfig) in
                                        userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                        //creates a dictionary with matching key value pairs
                                        expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                        expect({ user.optionalAttributeMissingValueKeysDontExist(userDictionary: userDictionary) }).to(match())
                                        expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())

                                        //creates a dictionary without private keys
                                        expect({ user.customDictionaryContainsOnlySdkSetAttributes(userDictionary: userDictionary) }).to(match())

                                        //creates a dictionary without redacted attributes
                                        expect(userDictionary.redactedAttributes).to(beNil())

                                        //creates a dictionary with or without matching flag config
                                        includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                            : expect(userDictionary.flagConfig).to(beNil())
                                    }
                                }
                            }
                        }
                    }
                }
                context("with all private attributes") {
                    context("using the config flag") {
                        beforeEach {
                            config = LDConfig.stub
                            config.allUserAttributesPrivate = true
                            user = LDUser.stub()
                        }
                        it("creates a dictionary with matching key value pairs") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                                expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                            }
                        }
                        it("creates a dictionary without private keys") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                expect({ user.optionalAttributePrivateKeysDontExist(userDictionary: userDictionary, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                                expect({ user.customDictionaryContainsOnlySdkSetAttributes(userDictionary: userDictionary) }).to(match())
                            }
                        }
                        it("creates a dictionary with redacted attributes") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                expect({ user.optionalAttributePrivateKeysAppearInPrivateAttrsWhenRedacted(userDictionary: userDictionary,
                                                                                                              privateAttributes: LDUser.privatizableAttributes) }).to(match())
                                expect({ user.optionalAttributePublicOrMissingKeysDontAppearInPrivateAttrs(userDictionary: userDictionary,
                                                                                                              privateAttributes: LDUser.privatizableAttributes) }).to(match())
                                expect(user.privateAttrsContainsCustom(userDictionary: userDictionary)).to(beTrue())
                            }
                        }
                        it("creates a dictionary with or without matching flag config") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                    : expect(userDictionary.flagConfig).to(beNil())
                            }
                        }
                    }
                    context("contained in the config") {
                        beforeEach {
                            config = LDConfig.stub
                            config.privateUserAttributes = LDUser.privatizableAttributes
                            user = LDUser.stub()
                        }
                        it("creates a dictionary with matching key value pairs") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                                expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                            }
                        }
                        it("creates a dictionary without private keys") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                expect({ user.optionalAttributePrivateKeysDontExist(userDictionary: userDictionary, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                                expect({ user.customDictionaryContainsOnlySdkSetAttributes(userDictionary: userDictionary) }).to(match())
                            }
                        }
                        it("creates a dictionary with redacted attributes") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                expect({ user.optionalAttributePrivateKeysAppearInPrivateAttrsWhenRedacted(userDictionary: userDictionary,
                                                                                                              privateAttributes: LDUser.privatizableAttributes) }).to(match())
                                expect({ user.optionalAttributePublicOrMissingKeysDontAppearInPrivateAttrs(userDictionary: userDictionary,
                                                                                                              privateAttributes: LDUser.privatizableAttributes) }).to(match())
                                expect(user.privateAttrsContainsCustom(userDictionary: userDictionary)).to(beTrue())
                            }
                        }
                        it("creates a dictionary with or without matching flag config") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                    : expect(userDictionary.flagConfig).to(beNil())
                            }
                        }
                    }
                    context("contained in the user") {
                        beforeEach {
                            config = LDConfig.stub
                            user = LDUser.stub()
                            user.privateAttributes = LDUser.privatizableAttributes
                        }
                        it("creates a dictionary with matching key value pairs") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                                expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                            }
                        }
                        it("creates a dictionary without private keys") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                expect({ user.optionalAttributePrivateKeysDontExist(userDictionary: userDictionary, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                                expect({ user.customDictionaryContainsOnlySdkSetAttributes(userDictionary: userDictionary) }).to(match())
                            }
                        }
                        it("creates a dictionary with redacted attributes") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                expect({ user.optionalAttributePrivateKeysAppearInPrivateAttrsWhenRedacted(userDictionary: userDictionary,
                                                                                                              privateAttributes: LDUser.privatizableAttributes) }).to(match())
                                expect({ user.optionalAttributePublicOrMissingKeysDontAppearInPrivateAttrs(userDictionary: userDictionary,
                                                                                                              privateAttributes: LDUser.privatizableAttributes) }).to(match())
                                expect(user.privateAttrsContainsCustom(userDictionary: userDictionary)).to(beTrue())
                            }
                        }
                        it("creates a dictionary with or without matching flag config") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match()) : expect(userDictionary.flagConfig).to(beNil())
                            }
                        }
                    }
                }
                context("with no private attributes") {
                    context("by setting private attributes to nil") {
                        beforeEach {
                            config = LDConfig.stub
                            user = LDUser.stub()
                        }
                        it("creates a dictionary with matching key value pairs") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            }
                        }
                        it("creates a dictionary without redacted attributes") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                expect(userDictionary.redactedAttributes).to(beNil())
                            }
                        }
                        it("creates a dictionary with or without matching flag config") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                    : expect(userDictionary.flagConfig).to(beNil())
                            }
                        }
                    }
                    context("by setting config private attributes to empty") {
                        beforeEach {
                            config = LDConfig.stub
                            config.privateUserAttributes = []
                            user = LDUser.stub()
                        }
                        it("creates a dictionary with matching key value pairs") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            }
                        }
                        it("creates a dictionary without redacted attributes") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                expect(userDictionary.redactedAttributes).to(beNil())
                            }
                        }
                        it("creates a dictionary with or without matching flag config") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                    : expect(userDictionary.flagConfig).to(beNil())
                            }
                        }
                    }
                    context("by setting user private attributes to empty") {
                        beforeEach {
                            config = LDConfig.stub
                            user = LDUser.stub()
                            user.privateAttributes = []
                        }
                        it("creates a dictionary with matching key value pairs") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            }
                        }
                        it("creates a dictionary without redacted attributes") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                expect(userDictionary.redactedAttributes).to(beNil())
                            }
                        }
                        it("creates a dictionary with or without matching flag config") {
                            [true, false].forEach { (includeFlagConfig) in
                                userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                    : expect(userDictionary.flagConfig).to(beNil())
                            }
                        }
                    }
                }
                context("with custom as the private attribute") {
                    context("on a user with no custom dictionary") {
                        context("with a device and os") {
                            beforeEach {
                                config = LDConfig.stub
                                user = LDUser.stub()
                                user.custom = nil
                                user.privateAttributes = [LDUser.CodingKeys.custom.rawValue]
                            }
                            it("creates a dictionary with matching key value pairs") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                    expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                    expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                    expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                    expect({ user.customDictionaryContainsOnlySdkSetAttributes(userDictionary: userDictionary) }).to(match())
                                }
                            }
                            it("creates a dictionary without redacted attributes") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                    expect(userDictionary.redactedAttributes).to(beNil())
                                }
                            }
                            it("creates a dictionary with or without matching flag config") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                    includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                        : expect(userDictionary.flagConfig).to(beNil())
                                }
                            }
                        }
                        context("without a device and os") {
                            beforeEach {
                                config = LDConfig.stub
                                user = LDUser.stub()
                                user.custom = nil
                                user.operatingSystem = nil
                                user.device = nil
                                user.privateAttributes = [LDUser.CodingKeys.custom.rawValue]
                            }
                            it("creates a dictionary with matching key value pairs") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                    expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                    expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                }
                            }
                            it("creates a dictionary without redacted attributes") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                    expect(userDictionary.redactedAttributes).to(beNil())
                                }
                            }
                            it("creates a dictionary without a custom dictionary") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                    expect(userDictionary.customDictionary(includeSdkSetAttributes: true)).to(beNil())
                                }
                            }
                            it("creates a dictionary with or without matching flag config") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                    includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                        : expect(userDictionary.flagConfig).to(beNil())
                                }
                            }
                        }
                    }
                    context("on a user with a custom dictionary") {
                        context("without a device and os") {
                            beforeEach {
                                config = LDConfig.stub
                                user = LDUser.stub() //The user stub puts device & operating system in both the user attributes and the custom dictionary
                                user.custom = user.customWithoutSdkSetAttributes
                                user.device = nil
                                user.operatingSystem = nil
                                user.privateAttributes = [LDUser.CodingKeys.custom.rawValue]
                            }
                            it("creates a dictionary with matching key value pairs") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                    expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                    expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                    expect({ user.sdkSetAttributesDontExist(userDictionary: userDictionary) }).to(match())
                                }
                            }
                            it("creates a dictionary with custom redacted") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                    expect(user.privateAttrsContainsOnlyCustom(userDictionary: userDictionary)) == true
                                }
                            }
                            it("creates a dictionary without a custom dictionary") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                    expect(userDictionary.customDictionary(includeSdkSetAttributes: true)).to(beNil())
                                }
                            }
                            it("creates a dictionary with or without matching flag config") {
                                [true, false].forEach { (includeFlagConfig) in
                                    userDictionary = user.dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: false, config: config)

                                    includeFlagConfig ? expect({ user.flagConfigMatches(userDictionary: userDictionary) }).to(match())
                                        : expect(userDictionary.flagConfig).to(beNil())
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func isEqualSpec() {
        var user: LDUser!
        var otherUser: LDUser!

        describe("isEqual") {
            context("when users are equal") {
                context("with all properties set") {
                    beforeEach {
                        user = LDUser.stub()
                        otherUser = user
                    }
                    it("returns true") {
                        expect(user.isEqual(to: otherUser)) == true
                    }
                }
                context("with no properties set") {
                    beforeEach {
                        user = LDUser()
                        otherUser = user
                    }
                    it("returns true") {
                        expect(user.isEqual(to: otherUser)) == true
                    }
                }
            }
            context("when users are not equal") {
                context("keys differ") {
                    beforeEach {
                        user = LDUser.stub()
                        otherUser = user
                        otherUser.key = "dummy"
                    }
                    it("returns false") {
                        expect(user.isEqual(to: otherUser)) == false
                    }
                }
                context("names differ") {
                    context("other name exists") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.name = "dummy"
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                    context("other name does not exist") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.name = nil
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                }
                context("firstNames differ") {
                    context("other firstName exists") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.firstName = "dummy"
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                    context("other firstName does not exist") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.firstName = nil
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                }
                context("lastNames differ") {
                    context("other lastName exists") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.lastName = "dummy"
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                    context("other lastName does not exist") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.lastName = nil
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                }
                context("countries differ") {
                    context("other country exists") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.country = "dummy"
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                    context("other country does not exist") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.country = nil
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                }
                context("ipAddresses differ") {
                    context("other ipAddress exists") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.ipAddress = "dummy"
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                    context("other ipAddress does not exist") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.ipAddress = nil
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                }
                context("email addresses differ") {
                    context("other email exists") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.email = "dummy"
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                    context("other email does not exist") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.email = nil
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                }
                context("avatars differ") {
                    context("other avatar exists") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.avatar = "dummy"
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                    context("other avatar does not exist") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.avatar = nil
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                }
                context("custom dictionaries differ") {
                    context("other custom dictionary exists") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.custom = ["dummy": true]
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                    context("other custom dictionary does not exist") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.custom = nil
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                }
                context("isAnonymous differs") {
                    beforeEach {
                        user = LDUser.stub()
                        otherUser = user
                        otherUser.isAnonymous = !user.isAnonymous
                    }
                    it("returns false") {
                        expect(user.isEqual(to: otherUser)) == false
                    }
                }
                context("devices differ") {
                    context("other device exists") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.device = "dummy"
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                    context("other device does not exist") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.device = nil
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                }
                context("operatingSystems differ") {
                    context("other operatingSystem exists") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.operatingSystem = "dummy"
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                    context("other operatingSystem does not exist") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.operatingSystem = nil
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                }
                context("privateAttributes differ") {
                    context("other privateAttributes exists") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.privateAttributes = ["dummy"]
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                    context("other privateAttributes does not exist") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                            otherUser.privateAttributes = nil
                        }
                        it("returns false") {
                            expect(user.isEqual(to: otherUser)) == false
                        }
                    }
                }
            }
        }
    }
}

extension LDUser {
    static var requiredAttributes: [String] {
        return [CodingKeys.key.rawValue, CodingKeys.lastUpdated.rawValue, CodingKeys.isAnonymous.rawValue]
    }
    static var optionalAttributes: [String] {
        return [CodingKeys.name.rawValue, CodingKeys.firstName.rawValue, CodingKeys.lastName.rawValue, CodingKeys.country.rawValue, CodingKeys.ipAddress.rawValue, CodingKeys.email.rawValue,
                CodingKeys.avatar.rawValue]
    }
    var customAttributes: [String]? {
        return custom?.keys.filter { (key) in !LDUser.sdkSetAttributes.contains(key) }
    }

    struct MatcherMessages {
        static let valuesDontMatch = "dictionary does not match attribute "
        static let dictionaryShouldNotContain = "dictionary contains attribute "
        static let dictionaryShouldContain = "dictionary does not contain attribute "
        static let attributeListShouldNotContain = "private attributes list contains attribute "
        static let attributeListShouldContain = "private attributes list does not contain attribute "
    }

    fileprivate func requiredAttributeKeyValuePairsMatch(userDictionary: [String: Any]) -> ToMatchResult {
        var messages = [String]()

        LDUser.requiredAttributes.forEach { (attribute) in
            if let message = messageIfMissingValue(in: userDictionary, for: attribute) {
                messages.append(message)
            }

            let value = attribute == CodingKeys.lastUpdated.rawValue ? DateFormatter.ldDateFormatter.string(from: lastUpdated) : self.value(forAttribute: attribute)
            if let message = messageIfValueDoesntMatch(value: value, in: userDictionary, for: attribute) {
                messages.append(message)
            }
        }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    fileprivate func optionalAttributePublicKeyValuePairsMatch(userDictionary: [String: Any], privateAttributes: [String]) -> ToMatchResult {
        var messages = [String]()

        LDUser.optionalAttributes.forEach { (attribute) in
            if !privateAttributes.contains(attribute) {
                if let message = messageIfValueDoesntMatch(value: value(forAttribute: attribute), in: userDictionary, for: attribute) {
                    messages.append(message)
                }
            }
        }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    fileprivate func optionalAttributePrivateKeysDontExist(userDictionary: [String: Any], privateAttributes: [String]) -> ToMatchResult {
        var messages = [String]()

        LDUser.optionalAttributes.forEach { (attribute) in
            if privateAttributes.contains(attribute) {
                if let message = messageIfAttributeExists(in: userDictionary, for: attribute) {
                    messages.append(message)
                }
            }
        }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    fileprivate func optionalAttributeMissingValueKeysDontExist(userDictionary: [String: Any]) -> ToMatchResult {
        var messages = [String]()

        LDUser.optionalAttributes.forEach { (attribute) in
            if value(forAttribute: attribute) == nil {
                if let message = messageIfAttributeExists(in: userDictionary, for: attribute) {
                    messages.append(message)
                }
            }
        }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    fileprivate func optionalAttributePrivateKeysAppearInPrivateAttrsWhenRedacted(userDictionary: [String: Any], privateAttributes: [String]) -> ToMatchResult {
        var messages = [String]()

        let redactedAttributes = userDictionary.redactedAttributes

        LDUser.optionalAttributes.forEach { (attribute) in
            if value(forAttribute: attribute) != nil && privateAttributes.contains(attribute) {
                if let message = messageIfRedactedAttributeDoesNotExist(in: redactedAttributes, for: attribute) {
                    messages.append(message)
                }
            }
        }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    fileprivate func optionalAttributeKeysDontAppearInPrivateAttrs(userDictionary: [String: Any]) -> ToMatchResult {
        var messages = [String]()

        let redactedAttributes = userDictionary.redactedAttributes

        LDUser.optionalAttributes.forEach { (attribute) in
            if let message = messageIfAttributeExists(in: redactedAttributes, for: attribute) {
                messages.append(message)
            }
        }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    fileprivate func optionalAttributePublicOrMissingKeysDontAppearInPrivateAttrs(userDictionary: [String: Any], privateAttributes: [String]) -> ToMatchResult {
        var messages = [String]()

        let redactedAttributes = userDictionary.redactedAttributes

        LDUser.optionalAttributes.forEach { (attribute) in
            if value(forAttribute: attribute) == nil || !privateAttributes.contains(attribute) {
                if let message = messageIfPublicOrMissingAttributeIsRedacted(in: redactedAttributes, for: attribute) {
                    messages.append(message)
                }
            }
        }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    fileprivate func sdkSetAttributesKeyValuePairsMatch(userDictionary: [String: Any]) -> ToMatchResult {
        guard let customDictionary = userDictionary.customDictionary(includeSdkSetAttributes: true)
        else {
            return .failed(reason: MatcherMessages.dictionaryShouldContain + CodingKeys.custom.rawValue)
        }

        var messages = [String]()

        LDUser.sdkSetAttributes.forEach { (attribute) in
            if let message = messageIfMissingValue(in: customDictionary, for: attribute) {
                messages.append(message)
            }
            if let message = messageIfValueDoesntMatch(value: value(forAttribute: attribute), in: customDictionary, for: attribute) {
                messages.append(message)
            }
        }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    fileprivate func sdkSetAttributesDontExist(userDictionary: [String: Any]) -> ToMatchResult {
        guard let customDictionary = userDictionary.customDictionary(includeSdkSetAttributes: true) else {
            return .matched
        }

        var messages = [String]()

        LDUser.sdkSetAttributes.forEach { (attribute) in
            if let message = messageIfAttributeExists(in: customDictionary, for: attribute) {
                messages.append(message)
            }
        }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    fileprivate func customDictionaryContainsOnlySdkSetAttributes(userDictionary: [String: Any]) -> ToMatchResult {
        guard let customDictionary = userDictionary.customDictionary(includeSdkSetAttributes: false)
        else {
            return .failed(reason: MatcherMessages.dictionaryShouldContain + CodingKeys.custom.rawValue)
        }

        if !customDictionary.isEmpty {
            return .failed(reason: MatcherMessages.dictionaryShouldNotContain + CodingKeys.custom.rawValue)
        }

        return .matched
    }

    fileprivate func privateAttrsContainsCustom(userDictionary: [String: Any]) -> Bool {
        guard let redactedAttributes = userDictionary.redactedAttributes
        else {
            return false
        }
        return redactedAttributes.contains(CodingKeys.custom.rawValue)
    }

    fileprivate func privateAttrsContainsOnlyCustom(userDictionary: [String: Any]) -> Bool {
        guard let redactedAttributes = userDictionary.redactedAttributes, redactedAttributes.contains(CodingKeys.custom.rawValue)
        else {
            return false
        }
        return redactedAttributes.count == 1
    }

    fileprivate func customDictionaryPublicKeyValuePairsMatch(userDictionary: [String: Any], privateAttributes: [String]) -> ToMatchResult {
        guard let custom = custom
        else {
            return userDictionary.customDictionary(includeSdkSetAttributes: false).isNilOrEmpty ? .matched
                : .failed(reason: MatcherMessages.dictionaryShouldNotContain + CodingKeys.custom.rawValue)
        }
        guard let customDictionary = userDictionary.customDictionary(includeSdkSetAttributes: false)
        else {
            return .failed(reason: MatcherMessages.dictionaryShouldContain + CodingKeys.custom.rawValue)
        }

        var messages = [String]()

        customAttributes?.forEach { (customAttribute) in
            if !privateAttributes.contains(customAttribute) {
                if let message = messageIfMissingValue(in: customDictionary, for: customAttribute) {
                    messages.append(message)
                }
                if let message = messageIfValueDoesntMatch(value: custom[customAttribute], in: customDictionary, for: customAttribute) {
                    messages.append(message)
                }
            }
        }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    fileprivate func customDictionaryPrivateKeysDontExist(userDictionary: [String: Any], privateAttributes: [String]) -> ToMatchResult {
        guard let customDictionary = userDictionary.customDictionary(includeSdkSetAttributes: false)
        else {
            return .failed(reason: MatcherMessages.dictionaryShouldContain + CodingKeys.custom.rawValue)
        }

        var messages = [String]()

        customAttributes?.forEach { (customAttribute) in
            if privateAttributes.contains(customAttribute) {
                if let message = messageIfAttributeExists(in: customDictionary, for: customAttribute) {
                    messages.append(message)
                }
            }
        }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    fileprivate func customPrivateKeysAppearInPrivateAttrsWhenRedacted(userDictionary: [String: Any], privateAttributes: [String]) -> ToMatchResult {
        guard let custom = custom
        else {
            return userDictionary.customDictionary(includeSdkSetAttributes: false).isNilOrEmpty ? .matched
                : .failed(reason: MatcherMessages.dictionaryShouldNotContain + CodingKeys.custom.rawValue)
        }

        var messages = [String]()

        customAttributes?.forEach { (customAttribute) in
            if privateAttributes.contains(customAttribute) && custom[customAttribute] != nil {
                if let message = messageIfRedactedAttributeDoesNotExist(in: userDictionary.redactedAttributes, for: customAttribute) {
                    messages.append(message)
                }
            }
        }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    fileprivate func customPublicOrMissingKeysDontAppearInPrivateAttrs(userDictionary: [String: Any], privateAttributes: [String]) -> ToMatchResult {
        guard let custom = custom
        else {
            return userDictionary.customDictionary(includeSdkSetAttributes: false).isNilOrEmpty ? .matched
                : .failed(reason: MatcherMessages.dictionaryShouldNotContain + CodingKeys.custom.rawValue)
        }

        var messages = [String]()

        customAttributes?.forEach { (customAttribute) in
            if !privateAttributes.contains(customAttribute) || custom[customAttribute] == nil {
                if let message = messageIfPublicOrMissingAttributeIsRedacted(in: userDictionary.redactedAttributes, for: customAttribute) {
                    messages.append(message)
                }
            }
        }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    fileprivate func flagConfigMatches(userDictionary: [String: Any]) -> ToMatchResult {
        let flagConfig = flagStore.featureFlags
        guard let flagConfigDictionary = userDictionary.flagConfig
        else {
            return .failed(reason: MatcherMessages.dictionaryShouldContain + CodingKeys.config.rawValue)
        }
        if flagConfig != flagConfigDictionary {
            return .failed(reason: MatcherMessages.valuesDontMatch + CodingKeys.config.rawValue)

        }
        return .matched
    }

    private func messageIfMissingValue(in dictionary: [String: Any], for attribute: String) -> String? {
        guard dictionary[attribute] != nil
        else {
            return MatcherMessages.dictionaryShouldContain + attribute
        }
        return nil
    }

    private func messageIfValueDoesntMatch(value: Any?, in dictionary: [String: Any], for attribute: String) -> String? {
        if !AnyComparer.isEqual(value, to: dictionary[attribute]) {
            return MatcherMessages.valuesDontMatch + attribute
        }
        return nil
    }

    private func messageIfAttributeExists(in dictionary: [String: Any], for attribute: String) -> String? {
        if dictionary[attribute] != nil {
            return MatcherMessages.dictionaryShouldNotContain + attribute
        }
        return nil
    }

    private func messageIfRedactedAttributeDoesNotExist(in redactedAttributes: [String]?, for attribute: String) -> String? {
        guard let redactedAttributes = redactedAttributes
        else {
            return MatcherMessages.dictionaryShouldContain + CodingKeys.privateAttributes.rawValue
        }
        if !redactedAttributes.contains(attribute) {
            return MatcherMessages.attributeListShouldContain + attribute
        }
        return nil
    }

    private func messageIfAttributeExists(in redactedAttributes: [String]?, for attribute: String) -> String? {
        guard let redactedAttributes = redactedAttributes
        else {
            return nil
        }
        if redactedAttributes.contains(attribute) {
            return MatcherMessages.attributeListShouldNotContain + attribute
        }
        return nil
    }

    private func messageIfPublicOrMissingAttributeIsRedacted(in redactedAttributes: [String]?, for attribute: String) -> String? {
        guard let redactedAttributes = redactedAttributes
        else {
            return nil
        }
        if redactedAttributes.contains(attribute) {
            return MatcherMessages.attributeListShouldNotContain + attribute
        }
        return nil
    }

    public func dictionaryValueWithAllAttributes(includeFlagConfig: Bool) -> [String: Any] {
        var dictionary = dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: LDConfig.stub)
        dictionary[CodingKeys.privateAttributes.rawValue] = privateAttributes
        return dictionary
    }
}

extension Dictionary where Key == String, Value == Any {
    fileprivate var redactedAttributes: [String]? {
        return self[LDUser.CodingKeys.privateAttributes.rawValue] as? [String]
    }
    fileprivate func customDictionary(includeSdkSetAttributes: Bool) -> [String: Any]? {
        var customDictionary = self[LDUser.CodingKeys.custom.rawValue] as? [String: Any]
        if !includeSdkSetAttributes {
            customDictionary = customDictionary?.filter { (key, _) in
                !LDUser.sdkSetAttributes.contains(key)
            }
        }
        return customDictionary
    }
    fileprivate var flagConfig: [String: Any]? {
        return self[LDUser.CodingKeys.config.rawValue] as? [LDFlagKey: Any]
    }
}
