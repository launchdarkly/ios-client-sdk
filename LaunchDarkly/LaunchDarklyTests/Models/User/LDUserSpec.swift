//
//  LDUserSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
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
        isEqualSpec()
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
                    it("creates a LDUser with optional elements") {
                        user = LDUser(key: LDUser.StubConstants.key, name: LDUser.StubConstants.name, firstName: LDUser.StubConstants.firstName, lastName: LDUser.StubConstants.lastName,
                                      country: LDUser.StubConstants.country, ipAddress: LDUser.StubConstants.ipAddress, email: LDUser.StubConstants.email, avatar: LDUser.StubConstants.avatar,
                                      custom: LDUser.StubConstants.custom(includeSystemValues: true), isAnonymous: LDUser.StubConstants.isAnonymous,
                                      privateAttributes: LDUser.privatizableAttributes, secondary: LDUser.StubConstants.secondary)
                        expect(user.key) == LDUser.StubConstants.key
                        expect(user.secondary) == LDUser.StubConstants.secondary
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
                        expect(user.privateAttributes).toNot(beNil())
                        if let privateAttributes = user.privateAttributes {
                            expect(privateAttributes) == LDUser.privatizableAttributes
                        }
                    }
                }
                context("excluding system values") {
                    it("creates a LDUser with optional elements") {
                        user = LDUser(key: LDUser.StubConstants.key, name: LDUser.StubConstants.name, firstName: LDUser.StubConstants.firstName, lastName: LDUser.StubConstants.lastName,
                                      country: LDUser.StubConstants.country, ipAddress: LDUser.StubConstants.ipAddress, email: LDUser.StubConstants.email, avatar: LDUser.StubConstants.avatar,
                                      custom: LDUser.StubConstants.custom(includeSystemValues: false), isAnonymous: LDUser.StubConstants.isAnonymous, device: LDUser.StubConstants.device, operatingSystem: LDUser.StubConstants.operatingSystem, privateAttributes: LDUser.privatizableAttributes, secondary: LDUser.StubConstants.secondary)
                        expect(user.key) == LDUser.StubConstants.key
                        expect(user.secondary) == LDUser.StubConstants.secondary
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
                    expect(user.secondary).to(beNil())
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
                    users.forEach { user in
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
            context("and optional elements") {
                beforeEach {
                    originalUser = LDUser.stub()
                    var userDictionary = originalUser.dictionaryValue(includePrivateAttributes: true, config: LDConfig.stub)
                    userDictionary[LDUser.CodingKeys.privateAttributes.rawValue] = LDUser.privatizableAttributes
                    user = LDUser(userDictionary: userDictionary)
                }
                it("creates a user with optional elements and feature flags") {
                    expect(user.key) == originalUser.key
                    expect(user.secondary) == originalUser.secondary
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

                    expect(user.privateAttributes) == LDUser.privatizableAttributes
                }
            }
            context("without optional elements") {
                beforeEach {
                    originalUser = LDUser(isAnonymous: true)
                    var userDictionary = originalUser.dictionaryValue(includePrivateAttributes: true, config: LDConfig.stub)
                    userDictionary[LDUser.CodingKeys.privateAttributes.rawValue] = originalUser.privateAttributes
                    user = LDUser(userDictionary: userDictionary)
                }
                it("creates a user without optional elements") {
                    expect(user.key) == originalUser.key
                    expect(user.isAnonymous) == originalUser.isAnonymous

                    expect(user.name).to(beNil())
                    expect(user.firstName).to(beNil())
                    expect(user.lastName).to(beNil())
                    expect(user.country).to(beNil())
                    expect(user.ipAddress).to(beNil())
                    expect(user.email).to(beNil())
                    expect(user.avatar).to(beNil())
                    expect(user.secondary).to(beNil())
                    expect(user.device).toNot(beNil())
                    expect(user.operatingSystem).toNot(beNil())

                    expect(user.custom).toNot(beNil())
                    expect(user.customWithoutSdkSetAttributes.isEmpty) == true
                    expect(user.privateAttributes).to(beNil())
                }
            }
            context("with empty dictionary") {
                it("creates a user without optional elements or feature flags") {
                    user = LDUser(userDictionary: [:])
                    expect(user.key).toNot(beNil())
                    expect(user.key.isEmpty).to(beFalse())
                    expect(user.isAnonymous) == false

                    expect(user.secondary).to(beNil())
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

                expect(user.secondary).to(beNil())
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
    }

    private func dictionaryValueInvariants(user: LDUser, userDictionary: [String: Any]) {
        // Always has required attributes
        expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
        // Optional attributes with nil value should never be included in user dictionary
        expect({ user.optionalAttributeMissingValueKeysDontExist(userDictionary: userDictionary) }).to(match())
        // Flag config is legacy, shouldn't be included
        expect(userDictionary.flagConfig).to(beNil())
    }

    private func dictionaryValueSpec() {
        describe("dictionaryValue") {
            var user: LDUser!
            var config: LDConfig!
            var userDictionary: [String: Any]!
            var privateAttributes: [String]!

            beforeEach {
                config = LDConfig.stub
                user = LDUser.stub()
            }

            context("including private attributes") {
                context("with individual private attributes") {
                    let assertions = {
                        it("creates a matching dictionary") {
                            //creates a dictionary with matching key value pairs
                            expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                            expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())

                            //creates a dictionary without redacted attributes
                            expect(userDictionary.redactedAttributes).to(beNil())

                            self.dictionaryValueInvariants(user: user, userDictionary: userDictionary)
                        }
                    }
                    (LDUser.privatizableAttributes + LDUser.StubConstants.custom.keys).forEach { attribute in
                        context("\(attribute) in the config") {
                            beforeEach {
                                user.privateAttributes = [attribute]
                                userDictionary = user.dictionaryValue(includePrivateAttributes: true, config: config)
                            }
                            assertions()
                        }
                        context("\(attribute) in the user") {
                            context("that is populated") {
                                beforeEach {
                                    user.privateAttributes = [attribute]
                                    userDictionary = user.dictionaryValue(includePrivateAttributes: true, config: config)
                                }
                                assertions()
                            }
                            context("that is empty") {
                                beforeEach {
                                    user = LDUser()
                                    user.privateAttributes = [attribute]
                                    userDictionary = user.dictionaryValue(includePrivateAttributes: true, config: config)
                                }
                                assertions()
                            }
                        }
                    }
                }
                context("with all private attributes") {
                    let allPrivateAssertions = {
                        it("creates a dictionary with matching key value pairs") {
                            expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                            expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                        }
                        it("creates a dictionary without redacted attributes") {
                            expect(userDictionary.redactedAttributes).to(beNil())
                        }
                        it("maintains invariants") {
                            self.dictionaryValueInvariants(user: user, userDictionary: userDictionary)
                        }
                    }
                    context("using the config flag") {
                        beforeEach {
                            config.allUserAttributesPrivate = true
                            userDictionary = user.dictionaryValue(includePrivateAttributes: true, config: config)
                        }
                        allPrivateAssertions()
                    }
                    context("contained in the config") {
                        beforeEach {
                            config.privateUserAttributes = LDUser.privatizableAttributes
                            userDictionary = user.dictionaryValue(includePrivateAttributes: true, config: config)
                        }
                        allPrivateAssertions()
                    }
                    context("contained in the user") {
                        beforeEach {
                            user.privateAttributes = LDUser.privatizableAttributes
                            userDictionary = user.dictionaryValue(includePrivateAttributes: true, config: config)
                        }
                        allPrivateAssertions()
                    }
                }
                context("with no private attributes") {
                    let noPrivateAssertions = {
                        it("creates a dictionary with matching key value pairs") {
                            expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                            expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                        }
                        it("creates a dictionary without redacted attributes") {
                            expect(userDictionary.redactedAttributes).to(beNil())
                        }
                        it("maintains invariants") {
                            self.dictionaryValueInvariants(user: user, userDictionary: userDictionary)
                        }
                    }
                    context("by setting private attributes to nil") {
                        beforeEach {
                            userDictionary = user.dictionaryValue(includePrivateAttributes: true, config: config)
                        }
                        noPrivateAssertions()
                    }
                    context("by setting config private attributes to empty") {
                        beforeEach {
                            config.privateUserAttributes = []
                            userDictionary = user.dictionaryValue(includePrivateAttributes: true, config: config)
                        }
                        noPrivateAssertions()
                    }
                    context("by setting user private attributes to empty") {
                        beforeEach {
                            user.privateAttributes = []
                            userDictionary = user.dictionaryValue(includePrivateAttributes: true, config: config)
                        }
                        noPrivateAssertions()
                    }
                }
                context("with custom as the private attribute") {
                    context("on a user with no custom dictionary") {
                        context("with a device and os") {
                            beforeEach {
                                user.custom = nil
                                user.privateAttributes = [LDUser.CodingKeys.custom.rawValue]
                                userDictionary = user.dictionaryValue(includePrivateAttributes: true, config: config)
                            }
                            it("creates a dictionary with matching key value pairs") {
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.customDictionaryContainsOnlySdkSetAttributes(userDictionary: userDictionary) }).to(match())
                            }
                            it("creates a dictionary without redacted attributes") {
                                expect(userDictionary.redactedAttributes).to(beNil())
                            }
                            it("maintains invariants") {
                                self.dictionaryValueInvariants(user: user, userDictionary: userDictionary)
                            }
                        }
                        context("without a device and os") {
                            beforeEach {
                                user.custom = nil
                                user.operatingSystem = nil
                                user.device = nil
                                user.privateAttributes = [LDUser.CodingKeys.custom.rawValue]
                                userDictionary = user.dictionaryValue(includePrivateAttributes: true, config: config)
                            }
                            it("creates a dictionary with matching key value pairs") {
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            }
                            it("creates a dictionary without redacted attributes") {
                                expect(userDictionary.redactedAttributes).to(beNil())
                            }
                            it("creates a dictionary without a custom dictionary") {
                                expect(userDictionary.customDictionary(includeSdkSetAttributes: true)).to(beNil())
                            }
                            it("maintains invariants") {
                                self.dictionaryValueInvariants(user: user, userDictionary: userDictionary)
                            }
                        }
                    }
                    context("on a user with a custom dictionary") {
                        context("without a device and os") {
                            beforeEach {
                                user.custom = user.customWithoutSdkSetAttributes
                                user.device = nil
                                user.operatingSystem = nil
                                user.privateAttributes = [LDUser.CodingKeys.custom.rawValue]
                                userDictionary = user.dictionaryValue(includePrivateAttributes: true, config: config)
                            }
                            it("creates a dictionary with matching key value pairs") {
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                expect({ user.sdkSetAttributesDontExist(userDictionary: userDictionary) }).to(match())
                                expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            }
                            it("creates a dictionary without redacted attributes") {
                                expect(userDictionary.redactedAttributes).to(beNil())
                            }
                            it("maintains invariants") {
                                self.dictionaryValueInvariants(user: user, userDictionary: userDictionary)
                            }
                        }
                    }
                }
            }
            context("excluding private attributes") {
                context("with individual private attributes") {
                    context("contained in the config") {
                        beforeEach {
                            privateAttributes = LDUser.privatizableAttributes + user.customAttributes!
                        }
                        it("creates a matching dictionary") {
                            privateAttributes.forEach { attribute in
                                let privateAttributesForTest = [attribute]
                                config.privateUserAttributes = privateAttributesForTest
                                userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)

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
                                if attribute == LDUser.CodingKeys.custom.rawValue {
                                    expect({ user.customDictionaryContainsOnlySdkSetAttributes(userDictionary: userDictionary) }).to(match())
                                    expect(user.customWithoutSdkSetAttributes.allSatisfy { k, _ in userDictionary.redactedAttributes!.contains(k) }).to(beTrue())
                                } else {
                                    expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: privateAttributesForTest) }).to(match())
                                    expect({ user.customDictionaryPrivateKeysDontExist(userDictionary: userDictionary, privateAttributes: privateAttributesForTest) }).to(match())

                                    expect({ user.customPrivateKeysAppearInPrivateAttrsWhenRedacted(userDictionary: userDictionary,
                                                                                                    privateAttributes: privateAttributesForTest) }).to(match())
                                    expect({ user.customPublicOrMissingKeysDontAppearInPrivateAttrs(userDictionary: userDictionary,
                                                                                                    privateAttributes: privateAttributesForTest) }).to(match())
                                }

                                //creates a dictionary without flag config
                                expect(userDictionary.flagConfig).to(beNil())
                            }
                        }
                    }
                    context("contained in the user") {
                        context("on a populated user") {
                            beforeEach {
                                privateAttributes = LDUser.privatizableAttributes + user.customAttributes!
                            }
                            it("creates a matching dictionary") {
                                privateAttributes.forEach { attribute in
                                    let privateAttributesForTest = [attribute]
                                    user.privateAttributes = privateAttributesForTest
                                    userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)

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
                                    if attribute == LDUser.CodingKeys.custom.rawValue {
                                        expect({ user.customDictionaryContainsOnlySdkSetAttributes(userDictionary: userDictionary) }).to(match())
                                        expect(user.customWithoutSdkSetAttributes.allSatisfy { k, _ in userDictionary.redactedAttributes!.contains(k) }).to(beTrue())
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

                                    //creates a dictionary without flag config
                                    expect(userDictionary.flagConfig).to(beNil())
                                }
                            }
                        }
                        context("on an empty user") {
                            beforeEach {
                                user = LDUser()
                                privateAttributes = LDUser.privatizableAttributes
                            }
                            it("creates a matching dictionary") {
                                privateAttributes.forEach { attribute in
                                    let privateAttributesForTest = [attribute]
                                    user.privateAttributes = privateAttributesForTest
                                    userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)

                                    //creates a dictionary with matching key value pairs
                                    expect({ user.requiredAttributeKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                    expect({ user.optionalAttributeMissingValueKeysDontExist(userDictionary: userDictionary) }).to(match())
                                    expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())

                                    //creates a dictionary without private keys
                                    expect({ user.customDictionaryContainsOnlySdkSetAttributes(userDictionary: userDictionary) }).to(match())

                                    //creates a dictionary without redacted attributes
                                    expect(userDictionary.redactedAttributes).to(beNil())

                                    //creates a dictionary without flag config
                                    expect(userDictionary.flagConfig).to(beNil())
                                }
                            }
                        }
                    }
                }
                context("with all private attributes") {
                    let allPrivateAssertions = {
                        it("creates a dictionary with matching key value pairs") {
                            expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                        }
                        it("creates a dictionary without private keys") {
                            expect({ user.optionalAttributePrivateKeysDontExist(userDictionary: userDictionary, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            expect({ user.customDictionaryContainsOnlySdkSetAttributes(userDictionary: userDictionary) }).to(match())
                        }
                        it("creates a dictionary with redacted attributes") {
                            expect({ user.optionalAttributePrivateKeysAppearInPrivateAttrsWhenRedacted(userDictionary: userDictionary,
                                                                                                       privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            expect({ user.optionalAttributePublicOrMissingKeysDontAppearInPrivateAttrs(userDictionary: userDictionary,
                                                                                                       privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            expect(user.customWithoutSdkSetAttributes.allSatisfy { k, _ in userDictionary.redactedAttributes!.contains(k) }).to(beTrue())
                        }
                        it("maintains invariants") {
                            self.dictionaryValueInvariants(user: user, userDictionary: userDictionary)
                        }
                    }
                    context("using the config flag") {
                        beforeEach {
                            config.allUserAttributesPrivate = true
                            userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)
                        }
                        allPrivateAssertions()
                    }
                    context("contained in the config") {
                        beforeEach {
                            config.privateUserAttributes = LDUser.privatizableAttributes
                            userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)
                        }
                        allPrivateAssertions()
                    }
                    context("contained in the user") {
                        beforeEach {
                            user.privateAttributes = LDUser.privatizableAttributes
                            userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)
                        }
                        allPrivateAssertions()
                    }
                }
                context("with no private attributes") {
                    let noPrivateAssertions = {
                        it("creates a dictionary with matching key value pairs") {
                            expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                            expect({ user.customDictionaryPublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                        }
                        it("creates a dictionary without redacted attributes") {
                            expect(userDictionary.redactedAttributes).to(beNil())
                        }
                        it("maintains invariants") {
                            self.dictionaryValueInvariants(user: user, userDictionary: userDictionary)
                        }
                    }
                    context("by setting private attributes to nil") {
                        beforeEach {
                            userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)
                        }
                        noPrivateAssertions()
                    }
                    context("by setting config private attributes to empty") {
                        beforeEach {
                            config.privateUserAttributes = []
                            userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)
                        }
                        noPrivateAssertions()
                    }
                    context("by setting user private attributes to empty") {
                        beforeEach {
                            user.privateAttributes = []
                            userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)
                        }
                        noPrivateAssertions()
                    }
                }
                context("with custom as the private attribute") {
                    context("on a user with no custom dictionary") {
                        context("with a device and os") {
                            beforeEach {
                                user.custom = nil
                                user.privateAttributes = [LDUser.CodingKeys.custom.rawValue]
                                userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)
                            }
                            it("creates a dictionary with matching key value pairs") {
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                expect({ user.sdkSetAttributesKeyValuePairsMatch(userDictionary: userDictionary) }).to(match())
                                expect({ user.customDictionaryContainsOnlySdkSetAttributes(userDictionary: userDictionary) }).to(match())
                            }
                            it("creates a dictionary without redacted attributes") {
                                expect(userDictionary.redactedAttributes).to(beNil())
                            }
                            it("maintains invariants") {
                                self.dictionaryValueInvariants(user: user, userDictionary: userDictionary)
                            }
                        }
                        context("without a device and os") {
                            beforeEach {
                                user.custom = nil
                                user.operatingSystem = nil
                                user.device = nil
                                user.privateAttributes = [LDUser.CodingKeys.custom.rawValue]
                                userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)
                            }
                            it("creates a dictionary with matching key value pairs") {
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                            }
                            it("creates a dictionary without redacted attributes") {
                                expect(userDictionary.redactedAttributes).to(beNil())
                            }
                            it("creates a dictionary without a custom dictionary") {
                                expect(userDictionary.customDictionary(includeSdkSetAttributes: true)).to(beNil())
                            }
                            it("maintains invariants") {
                                self.dictionaryValueInvariants(user: user, userDictionary: userDictionary)
                            }
                        }
                    }
                    context("on a user with a custom dictionary") {
                        context("without a device and os") {
                            beforeEach {
                                user.custom = user.customWithoutSdkSetAttributes
                                user.device = nil
                                user.operatingSystem = nil
                                user.privateAttributes = [LDUser.CodingKeys.custom.rawValue]
                                userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)
                            }
                            it("creates a dictionary with matching key value pairs") {
                                expect({ user.optionalAttributePublicKeyValuePairsMatch(userDictionary: userDictionary, privateAttributes: []) }).to(match())
                                expect({ user.sdkSetAttributesDontExist(userDictionary: userDictionary) }).to(match())
                            }
                            it("creates a dictionary private attrs include custom attributes") {
                                expect(userDictionary.redactedAttributes?.count) == user.custom?.count
                                expect(userDictionary.redactedAttributes?.contains { user.custom?[$0] != nil }).to(beTrue())
                            }
                            it("creates a dictionary without a custom dictionary") {
                                expect(userDictionary.customDictionary(includeSdkSetAttributes: true)).to(beNil())
                            }
                            it("maintains invariants") {
                                self.dictionaryValueInvariants(user: user, userDictionary: userDictionary)
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
                    it("returns true") {
                        user = LDUser.stub()
                        otherUser = user
                        expect(user.isEqual(to: otherUser)) == true
                    }
                }
                context("with no properties set") {
                    it("returns true") {
                        user = LDUser()
                        otherUser = user
                        expect(user.isEqual(to: otherUser)) == true
                    }
                }
            }
            context("when users are not equal") {
                let testFields: [(String, Bool, Any, (inout LDUser, Any?) -> Void)] =
                    [("key", false, "dummy", { u, v in u.key = v as! String }),
                     ("secondary", true, "dummy", { u, v in u.secondary = v as! String? }),
                     ("name", true, "dummy", { u, v in u.name = v as! String? }),
                     ("firstName", true, "dummy", { u, v in u.firstName = v as! String? }),
                     ("lastName", true, "dummy", { u, v in u.lastName = v as! String? }),
                     ("country", true, "dummy", { u, v in u.country = v as! String? }),
                     ("ipAddress", true, "dummy", { u, v in u.ipAddress = v as! String? }),
                     ("email address", true, "dummy", { u, v in u.email = v as! String? }),
                     ("avatar", true, "dummy", { u, v in u.avatar = v as! String? }),
                     ("custom", true, ["dummy": true], { u, v in u.custom = v as! [String: Any]? }),
                     ("isAnonymous", false, true, { u, v in u.isAnonymous = v as! Bool }),
                     ("device", true, "dummy", { u, v in u.device = v as! String? }),
                     ("operatingSystem", true, "dummy", { u, v in u.operatingSystem = v as! String? }),
                     ("privateAttributes", false, ["dummy"], { u, v in u.privateAttributes = v as! [String]? })]
                testFields.forEach { name, isOptional, otherVal, setter in
                    context("\(name) differs") {
                        beforeEach {
                            user = LDUser.stub()
                            otherUser = user
                        }
                        context("and both exist") {
                            it("returns false") {
                                setter(&otherUser, otherVal)
                                expect(user.isEqual(to: otherUser)) == false
                                expect(otherUser.isEqual(to: user)) == false
                            }
                        }
                        if isOptional {
                            context("self \(name) nil") {
                                it("returns false") {
                                    setter(&user, nil)
                                    expect(user.isEqual(to: otherUser)) == false
                                }
                            }
                            context("other \(name) nil") {
                                it("returns false") {
                                    setter(&otherUser, nil)
                                    expect(user.isEqual(to: otherUser)) == false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

extension LDUser {
    static var requiredAttributes: [String] {
        [CodingKeys.key.rawValue, CodingKeys.isAnonymous.rawValue]
    }
    var customAttributes: [String]? {
        custom?.keys.filter { key in !LDUser.sdkSetAttributes.contains(key) }
    }

    struct MatcherMessages {
        static let valuesDontMatch = "dictionary does not match attribute "
        static let dictionaryShouldNotContain = "dictionary contains attribute "
        static let dictionaryShouldContain = "dictionary does not contain attribute "
        static let attributeListShouldNotContain = "private attributes list contains attribute "
        static let attributeListShouldContain = "private attributes list does not contain attribute "
    }

    private func failsToMatch(fails: [String]) -> ToMatchResult {
        fails.isEmpty ? .matched : .failed(reason: fails.joined(separator: ", "))
    }

    fileprivate func requiredAttributeKeyValuePairsMatch(userDictionary: [String: Any]) -> ToMatchResult {
        failsToMatch(fails: LDUser.requiredAttributes.compactMap { attribute in
            messageIfMissingValue(in: userDictionary, for: attribute)
        })
    }

    fileprivate func optionalAttributePublicKeyValuePairsMatch(userDictionary: [String: Any], privateAttributes: [String]) -> ToMatchResult {
        failsToMatch(fails: LDUser.optionalAttributes.compactMap { attribute in
            privateAttributes.contains(attribute) ? nil : messageIfValueDoesntMatch(value: value(forAttribute: attribute), in: userDictionary, for: attribute)
        })
    }

    fileprivate func optionalAttributePrivateKeysDontExist(userDictionary: [String: Any], privateAttributes: [String]) -> ToMatchResult {
        failsToMatch(fails: LDUser.optionalAttributes.compactMap { attribute in
            !privateAttributes.contains(attribute) ? nil : messageIfAttributeExists(in: userDictionary, for: attribute)
        })
    }

    fileprivate func optionalAttributeMissingValueKeysDontExist(userDictionary: [String: Any]) -> ToMatchResult {
        failsToMatch(fails: LDUser.optionalAttributes.compactMap { attribute in
            value(forAttribute: attribute) != nil ? nil : messageIfAttributeExists(in: userDictionary, for: attribute)
        })
    }

    fileprivate func optionalAttributePrivateKeysAppearInPrivateAttrsWhenRedacted(userDictionary: [String: Any], privateAttributes: [String]) -> ToMatchResult {
        let redactedAttributes = userDictionary.redactedAttributes
        let messages: [String] = LDUser.optionalAttributes.compactMap { attribute in
            if value(forAttribute: attribute) != nil && privateAttributes.contains(attribute) {
                return messageIfRedactedAttributeDoesNotExist(in: redactedAttributes, for: attribute)
            }
            return nil
        }
        return failsToMatch(fails: messages)
    }

    fileprivate func optionalAttributeKeysDontAppearInPrivateAttrs(userDictionary: [String: Any]) -> ToMatchResult {
        let redactedAttributes = userDictionary.redactedAttributes
        return failsToMatch(fails: LDUser.optionalAttributes.compactMap { attribute in
            messageIfAttributeExists(in: redactedAttributes, for: attribute)
        })
    }

    fileprivate func optionalAttributePublicOrMissingKeysDontAppearInPrivateAttrs(userDictionary: [String: Any], privateAttributes: [String]) -> ToMatchResult {
        let redactedAttributes = userDictionary.redactedAttributes
        let messages: [String] = LDUser.optionalAttributes.compactMap { attribute in
            if value(forAttribute: attribute) == nil || !privateAttributes.contains(attribute) {
                return messageIfPublicOrMissingAttributeIsRedacted(in: redactedAttributes, for: attribute)
            }
            return nil
        }
        return failsToMatch(fails: messages)
    }

    fileprivate func sdkSetAttributesKeyValuePairsMatch(userDictionary: [String: Any]) -> ToMatchResult {
        guard let customDictionary = userDictionary.customDictionary(includeSdkSetAttributes: true)
        else {
            return .failed(reason: MatcherMessages.dictionaryShouldContain + CodingKeys.custom.rawValue)
        }

        var messages = [String]()

        LDUser.sdkSetAttributes.forEach { attribute in
            if let message = messageIfMissingValue(in: customDictionary, for: attribute) {
                messages.append(message)
            }
            if let message = messageIfValueDoesntMatch(value: value(forAttribute: attribute), in: customDictionary, for: attribute) {
                messages.append(message)
            }
        }

        return failsToMatch(fails: messages)
    }

    fileprivate func sdkSetAttributesDontExist(userDictionary: [String: Any]) -> ToMatchResult {
        guard let customDictionary = userDictionary.customDictionary(includeSdkSetAttributes: true) else {
            return .matched
        }

        let messages = LDUser.sdkSetAttributes.compactMap { attribute in
            messageIfAttributeExists(in: customDictionary, for: attribute)
        }

        return failsToMatch(fails: messages)
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

        customAttributes?.forEach { customAttribute in
            if !privateAttributes.contains(customAttribute) {
                if let message = messageIfMissingValue(in: customDictionary, for: customAttribute) {
                    messages.append(message)
                }
                if let message = messageIfValueDoesntMatch(value: custom[customAttribute], in: customDictionary, for: customAttribute) {
                    messages.append(message)
                }
            }
        }

        return failsToMatch(fails: messages)
    }

    fileprivate func customDictionaryPrivateKeysDontExist(userDictionary: [String: Any], privateAttributes: [String]) -> ToMatchResult {
        guard let customDictionary = userDictionary.customDictionary(includeSdkSetAttributes: false)
        else {
            return .failed(reason: MatcherMessages.dictionaryShouldContain + CodingKeys.custom.rawValue)
        }

        let messages = customAttributes?.compactMap { customAttribute in
            if privateAttributes.contains(customAttribute) {
                return messageIfAttributeExists(in: customDictionary, for: customAttribute)
            }
            return nil
            } ?? [String]()

        return failsToMatch(fails: messages)
    }

    fileprivate func customPrivateKeysAppearInPrivateAttrsWhenRedacted(userDictionary: [String: Any], privateAttributes: [String]) -> ToMatchResult {
        guard let custom = custom
        else {
            return userDictionary.customDictionary(includeSdkSetAttributes: false).isNilOrEmpty ? .matched
                : .failed(reason: MatcherMessages.dictionaryShouldNotContain + CodingKeys.custom.rawValue)
        }

        return failsToMatch(fails: customAttributes?.compactMap { customAttribute in
            if privateAttributes.contains(customAttribute) && custom[customAttribute] != nil {
                return messageIfRedactedAttributeDoesNotExist(in: userDictionary.redactedAttributes, for: customAttribute)
            }
            return nil
            } ?? [String]())
    }

    fileprivate func customPublicOrMissingKeysDontAppearInPrivateAttrs(userDictionary: [String: Any], privateAttributes: [String]) -> ToMatchResult {
        guard let custom = custom
        else {
        return userDictionary.customDictionary(includeSdkSetAttributes: false).isNilOrEmpty ? .matched
            : .failed(reason: MatcherMessages.dictionaryShouldNotContain + CodingKeys.custom.rawValue)
        }

        return failsToMatch(fails: customAttributes?.compactMap { customAttribute in
            if !privateAttributes.contains(customAttribute) || custom[customAttribute] == nil {
                return messageIfPublicOrMissingAttributeIsRedacted(in: userDictionary.redactedAttributes, for: customAttribute)
            }
            return nil
            } ?? [String]())
    }

    private func messageIfMissingValue(in dictionary: [String: Any], for attribute: String) -> String? {
        dictionary[attribute] != nil ? nil : MatcherMessages.dictionaryShouldContain + attribute
    }

    private func messageIfValueDoesntMatch(value: Any?, in dictionary: [String: Any], for attribute: String) -> String? {
        AnyComparer.isEqual(value, to: dictionary[attribute]) ? nil : MatcherMessages.valuesDontMatch + attribute
    }

    private func messageIfAttributeExists(in dictionary: [String: Any], for attribute: String) -> String? {
        dictionary[attribute] == nil ? nil : MatcherMessages.dictionaryShouldNotContain + attribute
    }

    private func messageIfRedactedAttributeDoesNotExist(in redactedAttributes: [String]?, for attribute: String) -> String? {
        guard let redactedAttributes = redactedAttributes
        else {
            return MatcherMessages.dictionaryShouldContain + CodingKeys.privateAttributes.rawValue
        }
        return redactedAttributes.contains(attribute) ? nil : MatcherMessages.attributeListShouldContain + attribute
    }

    private func messageIfAttributeExists(in redactedAttributes: [String]?, for attribute: String) -> String? {
        redactedAttributes?.contains(attribute) != true ? nil : MatcherMessages.attributeListShouldNotContain + attribute
    }

    private func messageIfPublicOrMissingAttributeIsRedacted(in redactedAttributes: [String]?, for attribute: String) -> String? {
        redactedAttributes?.contains(attribute) != true ? nil : MatcherMessages.attributeListShouldNotContain + attribute
    }

    public func dictionaryValueWithAllAttributes() -> [String: Any] {
        var dictionary = dictionaryValue(includePrivateAttributes: true, config: LDConfig.stub)
        dictionary[CodingKeys.privateAttributes.rawValue] = privateAttributes
        return dictionary
    }
}

extension Optional where Wrapped: Collection {
    var isNilOrEmpty: Bool { self?.isEmpty ?? true }
}

extension Dictionary where Key == String, Value == Any {
    fileprivate var redactedAttributes: [String]? {
        self[LDUser.CodingKeys.privateAttributes.rawValue] as? [String]
    }
    fileprivate func customDictionary(includeSdkSetAttributes: Bool) -> [String: Any]? {
        var customDictionary = self[LDUser.CodingKeys.custom.rawValue] as? [String: Any]
        if !includeSdkSetAttributes {
            customDictionary = customDictionary?.filter { key, _ in
                !LDUser.sdkSetAttributes.contains(key)
            }
        }
        return customDictionary
    }
    fileprivate var flagConfig: [String: Any]? {
        self[LDUser.CodingKeys.config.rawValue] as? [LDFlagKey: Any]
    }
}
