//
//  LDUserSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 10/23/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
@testable import Darkly

final class LDUserSpec: QuickSpec {

    struct Constants {
        fileprivate static let userCount = 3
    }

    override func spec() {

        var subject: LDUser!
        describe("init") {
            context("called with optional elements") {
                beforeEach {
                    subject = LDUser(key: LDUser.StubConstants.key, name: LDUser.StubConstants.name, firstName: LDUser.StubConstants.firstName, lastName: LDUser.StubConstants.lastName, country: LDUser.StubConstants.country, ipAddress: LDUser.StubConstants.ipAddress, email: LDUser.StubConstants.email, avatar: LDUser.StubConstants.avatar, custom: LDUser.StubConstants.custom, isAnonymous: LDUser.StubConstants.isAnonymous, privateAttributes: LDUser.privatizableAttributes)
                }
                it("creates a LDUser with optional elements") {
                    expect(subject.key) == LDUser.StubConstants.key
                    expect(subject.name) == LDUser.StubConstants.name
                    expect(subject.firstName) == LDUser.StubConstants.firstName
                    expect(subject.lastName) == LDUser.StubConstants.lastName
                    expect(subject.isAnonymous) == LDUser.StubConstants.isAnonymous
                    expect(subject.country) == LDUser.StubConstants.country
                    expect(subject.ipAddress) == LDUser.StubConstants.ipAddress
                    expect(subject.email) == LDUser.StubConstants.email
                    expect(subject.avatar) == LDUser.StubConstants.avatar
                    expect(subject.device) == LDUser.StubConstants.device
                    expect(subject.operatingSystem) == LDUser.StubConstants.operatingSystem
                    expect(subject.custom).toNot(beNil())
                    if let subjectCustom = subject.custom {
                        expect(subjectCustom == LDUser.StubConstants.custom).to(beTrue())
                    }
                    expect(subject.lastUpdated).toNot(beNil())
                    expect(subject.privateAttributes).toNot(beNil())
                    if let privateAttributes = subject.privateAttributes {
                        expect(privateAttributes) == LDUser.privatizableAttributes
                    }
                }
            }
            context("called without optional elements") {
                beforeEach {
                    subject = LDUser(isAnonymous: true)
                }
                it("creates a LDUser without optional elements") {
                    expect(subject.key).toNot(beNil())
                    expect(subject.isAnonymous) == true
                    expect(subject.lastUpdated).toNot(beNil())

                    expect(subject.name).to(beNil())
                    expect(subject.firstName).to(beNil())
                    expect(subject.lastName).to(beNil())
                    expect(subject.country).to(beNil())
                    expect(subject.ipAddress).to(beNil())
                    expect(subject.email).to(beNil())
                    expect(subject.avatar).to(beNil())
                    expect(subject.device).to(beNil())
                    expect(subject.operatingSystem).to(beNil())
                    expect(subject.custom).to(beNil())
                    expect(subject.privateAttributes).to(beNil())
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
                    users.forEach { (user) in
                        expect(user.key) == LDUser.defaultKey
                        expect(user.isAnonymous) == true
                    }
                }
            }
        }

        describe("init from dictionary") {
            var originalUser: LDUser!
            let mockLastUpdated = "2017-10-24T17:51:49.142Z"
            context("called with config") {
                context("and optional elements") {
                    beforeEach {
                        originalUser = LDUser.stub()
                        var userDictionary = originalUser.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: true, config: LDConfig())
                        userDictionary[LDUser.CodingKeys.lastUpdated.rawValue] = mockLastUpdated
                        userDictionary[LDUser.CodingKeys.privateAttributes.rawValue] = LDUser.privatizableAttributes
                        subject = LDUser(userDictionary: userDictionary)
                    }
                    it("creates a user with optional elements and feature flags") {
                        expect(subject.key) == originalUser.key
                        expect(subject.name) == originalUser.name
                        expect(subject.firstName) == originalUser.firstName
                        expect(subject.lastName) == originalUser.lastName
                        expect(subject.isAnonymous) == originalUser.isAnonymous
                        expect(subject.country) == originalUser.country
                        expect(subject.ipAddress) == originalUser.ipAddress
                        expect(subject.email) == originalUser.email
                        expect(subject.avatar) == originalUser.avatar

                        expect(originalUser.custom).toNot(beNil())
                        expect(subject.custom).toNot(beNil())
                        if let originalCustom = originalUser.custom,
                            let subjectCustom = subject.custom {
                            expect(subjectCustom == originalCustom).to(beTrue())
                        }

                        expect(subject.device) == originalUser.device
                        expect(subject.operatingSystem) == originalUser.operatingSystem
                        expect(subject.lastUpdated) == DateFormatter.ldDateFormatter.date(from: mockLastUpdated)

                        expect(subject.privateAttributes).toNot(beNil())
                        if let privateAttributes = subject.privateAttributes {
                            expect(privateAttributes) == LDUser.privatizableAttributes
                        }

                        expect(subject.flagStore.featureFlags == originalUser.flagStore.featureFlags).to(beTrue())
                    }
                }
                context("but without optional elements") {
                    beforeEach {
                        originalUser = LDUser(isAnonymous: true)
                        var userDictionary = originalUser.dictionaryValueWithAllAttributes(includeFlagConfig: true)
                        userDictionary[LDUser.CodingKeys.lastUpdated.rawValue] = mockLastUpdated
                        subject = LDUser(userDictionary: userDictionary)

                    }
                    it("creates a user without optional elements and with feature flags") {
                        expect(subject.key) == originalUser.key
                        expect(subject.isAnonymous) == originalUser.isAnonymous
                        expect(subject.lastUpdated) == DateFormatter.ldDateFormatter.date(from: mockLastUpdated)

                        expect(subject.name).to(beNil())
                        expect(subject.firstName).to(beNil())
                        expect(subject.lastName).to(beNil())
                        expect(subject.country).to(beNil())
                        expect(subject.ipAddress).to(beNil())
                        expect(subject.email).to(beNil())
                        expect(subject.avatar).to(beNil())
                        expect(subject.device).to(beNil())
                        expect(subject.operatingSystem).to(beNil())
                        expect(subject.custom).to(beNil())
                        expect(subject.privateAttributes).to(beNil())

                        expect(subject.flagStore.featureFlags == originalUser.flagStore.featureFlags).to(beTrue())
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
                        subject = LDUser(userDictionary: userDictionary)
                    }
                    it("creates a user with optional elements") {
                        expect(subject.key) == originalUser.key
                        expect(subject.name) == originalUser.name
                        expect(subject.firstName) == originalUser.firstName
                        expect(subject.lastName) == originalUser.lastName
                        expect(subject.isAnonymous) == originalUser.isAnonymous
                        expect(subject.country) == originalUser.country
                        expect(subject.ipAddress) == originalUser.ipAddress
                        expect(subject.email) == originalUser.email
                        expect(subject.avatar) == originalUser.avatar

                        expect(originalUser.custom).toNot(beNil())
                        expect(subject.custom).toNot(beNil())
                        if let originalCustom = originalUser.custom,
                            let subjectCustom = subject.custom {
                            expect(subjectCustom == originalCustom).to(beTrue())
                        }

                        expect(subject.device) == originalUser.device
                        expect(subject.operatingSystem) == originalUser.operatingSystem
                        expect(subject.lastUpdated) == DateFormatter.ldDateFormatter.date(from: mockLastUpdated)

                        expect(subject.privateAttributes).toNot(beNil())
                        if let privateAttributes = subject.privateAttributes {
                            expect(privateAttributes) == LDUser.privatizableAttributes
                        }

                        expect(subject.flagStore.featureFlags.isEmpty).to(beTrue())
                    }
                }
                context("or optional elements") {
                    beforeEach {
                        originalUser = LDUser(isAnonymous: true)
                        var userDictionary = originalUser.dictionaryValueWithAllAttributes(includeFlagConfig: false)
                        userDictionary[LDUser.CodingKeys.lastUpdated.rawValue] = mockLastUpdated
                        subject = LDUser(userDictionary: userDictionary)
                    }
                    it("creates a user without optional elements or feature flags") {
                        expect(subject.key) == originalUser.key
                        expect(subject.isAnonymous) == originalUser.isAnonymous
                        expect(subject.lastUpdated) == DateFormatter.ldDateFormatter.date(from: mockLastUpdated)

                        expect(subject.name).to(beNil())
                        expect(subject.firstName).to(beNil())
                        expect(subject.lastName).to(beNil())
                        expect(subject.country).to(beNil())
                        expect(subject.ipAddress).to(beNil())
                        expect(subject.email).to(beNil())
                        expect(subject.avatar).to(beNil())
                        expect(subject.device).to(beNil())
                        expect(subject.operatingSystem).to(beNil())
                        expect(subject.custom).to(beNil())
                        expect(subject.privateAttributes).to(beNil())

                        expect(subject.flagStore.featureFlags.isEmpty).to(beTrue())
                    }
                }
                context("and with an empty dictionary") {
                    beforeEach {
                        subject = LDUser(userDictionary: [:])
                    }
                    it("creates a user without optional elements or feature flags") {
                        expect(subject.key).toNot(beNil())
                        expect(subject.key.isEmpty).to(beFalse())
                        expect(subject.isAnonymous) == false
                        expect(subject.lastUpdated).toNot(beNil())

                        expect(subject.name).to(beNil())
                        expect(subject.firstName).to(beNil())
                        expect(subject.lastName).to(beNil())
                        expect(subject.country).to(beNil())
                        expect(subject.ipAddress).to(beNil())
                        expect(subject.email).to(beNil())
                        expect(subject.avatar).to(beNil())
                        expect(subject.device).to(beNil())
                        expect(subject.operatingSystem).to(beNil())
                        expect(subject.custom).to(beNil())
                        expect(subject.privateAttributes).to(beNil())

                        expect(subject.flagStore.featureFlags.isEmpty).to(beTrue())
                    }
                }
                context("but with an incorrect last updated format") {
                    let invalidLastUpdated = "2017-10-24T17:51:49Z"
                    beforeEach {
                        subject = LDUser(userDictionary: [LDUser.CodingKeys.lastUpdated.rawValue: invalidLastUpdated])
                    }
                    it("creates a user without optional elements or feature flags") {
                        expect(subject.key).toNot(beNil())
                        expect(subject.key.isEmpty).to(beFalse())
                        expect(subject.isAnonymous) == false
                        expect(subject.lastUpdated).toNot(beNil())
                        expect(DateFormatter.ldDateFormatter.string(from: subject.lastUpdated)) != invalidLastUpdated

                        expect(subject.name).to(beNil())
                        expect(subject.firstName).to(beNil())
                        expect(subject.lastName).to(beNil())
                        expect(subject.country).to(beNil())
                        expect(subject.ipAddress).to(beNil())
                        expect(subject.email).to(beNil())
                        expect(subject.avatar).to(beNil())
                        expect(subject.device).to(beNil())
                        expect(subject.operatingSystem).to(beNil())
                        expect(subject.custom).to(beNil())
                        expect(subject.privateAttributes).to(beNil())

                        expect(subject.flagStore.featureFlags.isEmpty).to(beTrue())
                    }
                }
            }
        }

        describe("dictionaryValue") {
            var config: LDConfig!
            var userDictionary: [String: Any]!
            var privateAttributes: [String]!
            context("called with flag config") {
                context("including private attributes") {
                    context("with individual private attributes") {
                        context("contained in the config") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()
                                privateAttributes = LDUser.privatizableAttributes + subject.custom!.keys.filter { (customAttribute) in
                                    //User stub includes a custom dictionary with device & operating system, which are not privatizable
                                    customAttribute != LDUser.CodingKeys.device.rawValue && customAttribute != LDUser.CodingKeys.operatingSystem.rawValue
                                }
                            }
                            it("creates a matching dictionary") {
                                privateAttributes.forEach { (attribute) in
                                    config.privateUserAttributes = [attribute]
                                    userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: true, config: config)
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: true, privateAttributes: [attribute]) }).to(match())
                                }
                            }
                        }
                        context("contained in the user") {
                            context("on a populated user") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub()
                                    privateAttributes = LDUser.privatizableAttributes + subject.custom!.keys.filter { (customAttribute) in
                                        //User stub includes a custom dictionary with device & operating system, which are not privatizable
                                        customAttribute != LDUser.CodingKeys.device.rawValue && customAttribute != LDUser.CodingKeys.operatingSystem.rawValue
                                    }
                                }
                                it("creates a matching dictionary") {
                                    privateAttributes.forEach { (attribute) in
                                        subject.privateAttributes = [attribute]
                                        userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: true, config: config)
                                        expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: true, privateAttributes: [attribute]) }).to(match())
                                    }
                                }
                            }
                            context("on an empty user") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser()
                                    privateAttributes = LDUser.privatizableAttributes
                                }
                                it("creates a matching dictionary") {
                                    privateAttributes.forEach { (attribute) in
                                        subject.privateAttributes = [attribute]
                                        userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: true, config: config)
                                        expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: true, privateAttributes: [attribute]) }).to(match())
                                    }
                                }
                            }
                        }
                    }
                    context("with all private attributes") {
                        context("using the config flag") {
                            beforeEach {
                                config = LDConfig()
                                config.allUserAttributesPrivate = true
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: true, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: true, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            }
                        }
                        context("contained in the config") {
                            beforeEach {
                                config = LDConfig()
                                config.privateUserAttributes = LDUser.privatizableAttributes
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: true, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: true, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            }
                        }
                        context("contained in the user") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()
                                subject.privateAttributes = LDUser.privatizableAttributes

                                userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: true, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: true, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            }
                        }
                    }
                    context("with no private attributes") {
                        context("by setting private attributes to nil") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: true, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: true, privateAttributes: []) }).to(match())
                            }
                        }
                        context("by setting config private attributes to empty") {
                            beforeEach {
                                config = LDConfig()
                                config.privateUserAttributes = []
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: true, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: true, privateAttributes: []) }).to(match())
                            }
                        }
                        context("by setting user private attributes to empty") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()
                                subject.privateAttributes = []

                                userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: true, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: true, privateAttributes: []) }).to(match())
                            }
                        }
                    }
                    context("with only custom as the private attribute") {
                        context("on a user with no custom dictionary") {
                            context("with a device and os") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub()
                                    subject.custom = nil
                                    subject.privateAttributes = [LDUser.CodingKeys.custom.rawValue]

                                    userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: true, config: config)
                                }
                                it("creates a matching dictionary") {
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: true, privateAttributes: [LDUser.CodingKeys.custom.rawValue]) }).to(match())
                                }
                            }
                            context("without a device and os") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub()
                                    subject.custom = nil
                                    subject.operatingSystem = nil
                                    subject.device = nil
                                    subject.privateAttributes = [LDUser.CodingKeys.custom.rawValue]

                                    userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: true, config: config)
                                }
                                it("creates a matching dictionary") {
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: true, privateAttributes: [LDUser.CodingKeys.custom.rawValue]) }).to(match())
                                }
                            }
                        }
                        context("on a user with a custom dictionary") {
                            context("without a device and os") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub() //The user stub puts device & operating system in both the user attributes and the custom dictionary
                                    var custom = subject.custom
                                    custom?.removeValue(forKey: LDUser.CodingKeys.device.rawValue)
                                    custom?.removeValue(forKey: LDUser.CodingKeys.operatingSystem.rawValue)
                                    subject.custom = custom
                                    subject.device = nil
                                    subject.operatingSystem = nil
                                    subject.privateAttributes = [LDUser.CodingKeys.custom.rawValue]

                                    userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: true, config: config)
                                }
                                it("creates a matching dictionary") {
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: true, privateAttributes: [LDUser.CodingKeys.custom.rawValue]) }).to(match())
                                }
                            }
                        }
                    }
                }
                context("excluding private attributes") {
                    context("with individual private attributes") {
                        context("contained in the config") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()
                                privateAttributes = LDUser.privatizableAttributes + subject.custom!.keys.filter { (customAttribute) in
                                    //User stub includes a custom dictionary with device & operating system, which are not privatizable
                                    customAttribute != LDUser.CodingKeys.device.rawValue && customAttribute != LDUser.CodingKeys.operatingSystem.rawValue
                                }
                            }
                            it("creates a matching dictionary") {
                                privateAttributes.forEach { (attribute) in
                                    config.privateUserAttributes = [attribute]
                                    userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: false, config: config)
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: false, privateAttributes: [attribute]) }).to(match())
                                }
                            }
                        }
                        context("contained in the user") {
                            context("on a populated user") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub()
                                    privateAttributes = LDUser.privatizableAttributes + subject.custom!.keys.filter { (customAttribute) in
                                        //User stub includes a custom dictionary with device & operating system, which are not privatizable
                                        customAttribute != LDUser.CodingKeys.device.rawValue && customAttribute != LDUser.CodingKeys.operatingSystem.rawValue
                                    }
                                }
                                it("creates a matching dictionary") {
                                    privateAttributes.forEach { (attribute) in
                                        config.privateUserAttributes = [attribute]
                                        userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: false, config: config)
                                        expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: false, privateAttributes: [attribute]) }).to(match())
                                    }
                                }
                            }
                            context("on an empty user") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser()
                                    privateAttributes = LDUser.privatizableAttributes
                                }
                                it("creates a matching dictionary") {
                                    privateAttributes.forEach { (attribute) in
                                        subject.privateAttributes = [attribute]
                                        userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: false, config: config)
                                        expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: false, privateAttributes: [attribute]) }).to(match())
                                    }
                                }
                            }
                        }
                    }
                    context("with all private attributes") {
                        context("using the config flag") {
                            beforeEach {
                                config = LDConfig()
                                config.allUserAttributesPrivate = true
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: false, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: false, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            }
                        }
                        context("contained in the config") {
                            beforeEach {
                                config = LDConfig()
                                config.privateUserAttributes = LDUser.privatizableAttributes
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: false, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: false, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            }
                        }
                        context("contained in the user") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()
                                subject.privateAttributes = LDUser.privatizableAttributes

                                userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: false, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: false, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            }
                        }
                    }
                    context("with no private attributes") {
                        context("by setting private attributes to nil") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: false, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: false, privateAttributes: []) }).to(match())
                            }
                        }
                        context("by setting config private attributes to empty") {
                            beforeEach {
                                config = LDConfig()
                                config.privateUserAttributes = []
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: false, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: false, privateAttributes: []) }).to(match())
                            }
                        }
                        context("by setting user private attributes to empty") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()
                                subject.privateAttributes = []

                                userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: false, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: false, privateAttributes: []) }).to(match())
                            }
                        }
                    }
                    context("with only custom as the private attribute") {
                        context("on a user with no custom dictionary") {
                            context("with a device and os") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub()
                                    subject.custom = nil
                                    subject.privateAttributes = [LDUser.CodingKeys.custom.rawValue]

                                    userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: false, config: config)
                                }
                                it("creates a matching dictionary") {
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: false, privateAttributes: [LDUser.CodingKeys.custom.rawValue]) }).to(match())
                                }
                            }
                            context("without a device and os") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub()
                                    subject.custom = nil
                                    subject.operatingSystem = nil
                                    subject.device = nil
                                    subject.privateAttributes = [LDUser.CodingKeys.custom.rawValue]

                                    userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: false, config: config)
                                }
                                it("creates a matching dictionary") {
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: false, privateAttributes: [LDUser.CodingKeys.custom.rawValue]) }).to(match())
                                }
                            }
                        }
                        context("on a user with a custom dictionary") {
                            context("without a device and os") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub() //The user stub puts device & operating system in both the user attributes and the custom dictionary
                                    var custom = subject.custom
                                    custom?.removeValue(forKey: LDUser.CodingKeys.device.rawValue)
                                    custom?.removeValue(forKey: LDUser.CodingKeys.operatingSystem.rawValue)
                                    subject.custom = custom
                                    subject.device = nil
                                    subject.operatingSystem = nil
                                    subject.privateAttributes = [LDUser.CodingKeys.custom.rawValue]

                                    userDictionary = subject.dictionaryValue(includeFlagConfig: true, includePrivateAttributes: false, config: config)
                                }
                                it("creates a matching dictionary") {
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: true, includePrivateAttributes: false, privateAttributes: [LDUser.CodingKeys.custom.rawValue]) }).to(match())
                                }
                            }
                        }
                    }
                }
            }
            context("called without flag config") {
                context("including private attributes") {
                    context("with individual private attributes") {
                        context("contained in the config") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()
                                privateAttributes = LDUser.privatizableAttributes + subject.custom!.keys.filter { (customAttribute) in
                                    //User stub includes a custom dictionary with device & operating system, which are not privatizable
                                    customAttribute != LDUser.CodingKeys.device.rawValue && customAttribute != LDUser.CodingKeys.operatingSystem.rawValue
                                }
                            }
                            it("creates a matching dictionary") {
                                privateAttributes.forEach { (attribute) in
                                    config.privateUserAttributes = [attribute]
                                    userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: true, privateAttributes: [attribute]) }).to(match())
                                }
                            }
                        }
                        context("contained in the user") {
                            context("on a populated user") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub()
                                    privateAttributes = LDUser.privatizableAttributes + subject.custom!.keys.filter { (customAttribute) in
                                        //User stub includes a custom dictionary with device & operating system, which are not privatizable
                                        customAttribute != LDUser.CodingKeys.device.rawValue && customAttribute != LDUser.CodingKeys.operatingSystem.rawValue
                                    }
                                }
                                it("creates a matching dictionary") {
                                    privateAttributes.forEach { (attribute) in
                                        subject.privateAttributes = [attribute]
                                        userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                                        expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: true, privateAttributes: [attribute]) }).to(match())
                                    }
                                }
                            }
                            context("on an empty user") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser()
                                    privateAttributes = LDUser.privatizableAttributes
                                }
                                it("creates a matching dictionary") {
                                    privateAttributes.forEach { (attribute) in
                                        subject.privateAttributes = [attribute]
                                        userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                                        expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: true, privateAttributes: [attribute]) }).to(match())
                                    }
                                }
                            }
                        }
                    }
                    context("with all private attributes") {
                        context("using the config flag") {
                            beforeEach {
                                config = LDConfig()
                                config.allUserAttributesPrivate = true
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: true, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            }
                        }
                        context("contained in the config") {
                            beforeEach {
                                config = LDConfig()
                                config.privateUserAttributes = LDUser.privatizableAttributes
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: true, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            }
                        }
                        context("contained in the user") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()
                                subject.privateAttributes = LDUser.privatizableAttributes

                                userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: true, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            }
                        }
                    }
                    context("with no private attributes") {
                        context("by setting private attributes to nil") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: true, privateAttributes: []) }).to(match())
                            }
                        }
                        context("by setting config private attributes to empty") {
                            beforeEach {
                                config = LDConfig()
                                config.privateUserAttributes = []
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: true, privateAttributes: []) }).to(match())
                            }
                        }
                        context("by setting user private attributes to empty") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()
                                subject.privateAttributes = []

                                userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: true, privateAttributes: []) }).to(match())
                            }
                        }
                    }
                    context("with only custom as the private attribute") {
                        context("on a user with no custom dictionary") {
                            context("with a device and os") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub()
                                    subject.custom = nil
                                    subject.privateAttributes = [LDUser.CodingKeys.custom.rawValue]

                                    userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                                }
                                it("creates a matching dictionary") {
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: true, privateAttributes: [LDUser.CodingKeys.custom.rawValue]) }).to(match())
                                }
                            }
                            context("without a device and os") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub()
                                    subject.custom = nil
                                    subject.operatingSystem = nil
                                    subject.device = nil
                                    subject.privateAttributes = [LDUser.CodingKeys.custom.rawValue]

                                    userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                                }
                                it("creates a matching dictionary") {
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: true, privateAttributes: [LDUser.CodingKeys.custom.rawValue]) }).to(match())
                                }
                            }
                        }
                        context("on a user with a custom dictionary") {
                            context("without a device and os") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub() //The user stub puts device & operating system in both the user attributes and the custom dictionary
                                    var custom = subject.custom
                                    custom?.removeValue(forKey: LDUser.CodingKeys.device.rawValue)
                                    custom?.removeValue(forKey: LDUser.CodingKeys.operatingSystem.rawValue)
                                    subject.custom = custom
                                    subject.device = nil
                                    subject.operatingSystem = nil
                                    subject.privateAttributes = [LDUser.CodingKeys.custom.rawValue]

                                    userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                                }
                                it("creates a matching dictionary") {
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: true, privateAttributes: [LDUser.CodingKeys.custom.rawValue]) }).to(match())
                                }
                            }
                        }
                    }
                }
                context("excluding private attributes") {
                    context("with individual private attributes") {
                        context("contained in the config") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()
                                privateAttributes = LDUser.privatizableAttributes + subject.custom!.keys.filter { (customAttribute) in
                                    //User stub includes a custom dictionary with device & operating system, which are not privatizable
                                    customAttribute != LDUser.CodingKeys.device.rawValue && customAttribute != LDUser.CodingKeys.operatingSystem.rawValue
                                }
                            }
                            it("creates a matching dictionary") {
                                privateAttributes.forEach { (attribute) in
                                    config.privateUserAttributes = [attribute]
                                    userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: false, config: config)
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: false, privateAttributes: [attribute]) }).to(match())
                                }
                            }
                        }
                        context("contained in the user") {
                            context("on a populated user") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub()
                                    privateAttributes = LDUser.privatizableAttributes + subject.custom!.keys.filter { (customAttribute) in
                                        //User stub includes a custom dictionary with device & operating system, which are not privatizable
                                        customAttribute != LDUser.CodingKeys.device.rawValue && customAttribute != LDUser.CodingKeys.operatingSystem.rawValue
                                    }
                                }
                                it("creates a matching dictionary") {
                                    privateAttributes.forEach { (attribute) in
                                        config.privateUserAttributes = [attribute]
                                        userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: false, config: config)
                                        expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: false, privateAttributes: [attribute]) }).to(match())
                                    }
                                }
                            }
                            context("on an empty user") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser()
                                    privateAttributes = LDUser.privatizableAttributes
                                }
                                it("creates a matching dictionary") {
                                    privateAttributes.forEach { (attribute) in
                                        subject.privateAttributes = [attribute]
                                        userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: false, config: config)
                                        expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: false, privateAttributes: [attribute]) }).to(match())
                                    }
                                }
                            }
                        }
                    }
                    context("with all private attributes") {
                        context("using the config flag") {
                            beforeEach {
                                config = LDConfig()
                                config.allUserAttributesPrivate = true
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: false, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: false, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            }
                        }
                        context("contained in the config") {
                            beforeEach {
                                config = LDConfig()
                                config.privateUserAttributes = LDUser.privatizableAttributes
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: false, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: false, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            }
                        }
                        context("contained in the user") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()
                                subject.privateAttributes = LDUser.privatizableAttributes

                                userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: false, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: false, privateAttributes: LDUser.privatizableAttributes) }).to(match())
                            }
                        }
                    }
                    context("with no private attributes") {
                        context("by setting private attributes to nil") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: false, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: false, privateAttributes: []) }).to(match())
                            }
                        }
                        context("by setting config private attributes to empty") {
                            beforeEach {
                                config = LDConfig()
                                config.privateUserAttributes = []
                                subject = LDUser.stub()

                                userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: false, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: false, privateAttributes: []) }).to(match())
                            }
                        }
                        context("by setting user private attributes to empty") {
                            beforeEach {
                                config = LDConfig()
                                subject = LDUser.stub()
                                subject.privateAttributes = []

                                userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: false, config: config)
                            }
                            it("creates a matching dictionary") {
                                expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: false, privateAttributes: []) }).to(match())
                            }
                        }
                    }
                    context("with only custom as the private attribute") {
                        context("on a user with no custom dictionary") {
                            context("with a device and os") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub()
                                    subject.custom = nil
                                    subject.privateAttributes = [LDUser.CodingKeys.custom.rawValue]

                                    userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: false, config: config)
                                }
                                it("creates a matching dictionary") {
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: false, privateAttributes: [LDUser.CodingKeys.custom.rawValue]) }).to(match())
                                }
                            }
                            context("without a device and os") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub()
                                    subject.custom = nil
                                    subject.operatingSystem = nil
                                    subject.device = nil
                                    subject.privateAttributes = [LDUser.CodingKeys.custom.rawValue]

                                    userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: false, config: config)
                                }
                                it("creates a matching dictionary") {
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: false, privateAttributes: [LDUser.CodingKeys.custom.rawValue]) }).to(match())
                                }
                            }
                        }
                        context("on a user with a custom dictionary") {
                            context("without a device and os") {
                                beforeEach {
                                    config = LDConfig()
                                    subject = LDUser.stub() //The user stub puts device & operating system in both the user attributes and the custom dictionary
                                    var custom = subject.custom
                                    custom?.removeValue(forKey: LDUser.CodingKeys.device.rawValue)
                                    custom?.removeValue(forKey: LDUser.CodingKeys.operatingSystem.rawValue)
                                    subject.custom = custom
                                    subject.device = nil
                                    subject.operatingSystem = nil
                                    subject.privateAttributes = [LDUser.CodingKeys.custom.rawValue]

                                    userDictionary = subject.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: false, config: config)
                                }
                                it("creates a matching dictionary") {
                                    expect({ subject.matches(userDictionary: userDictionary, includeFlagConfig: false, includePrivateAttributes: false, privateAttributes: [LDUser.CodingKeys.custom.rawValue]) }).to(match())
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
    struct MatcherMessages {
        static let valuesDontMatch = "dictionary does not match attribute "
        static let dictionaryShouldNotContain = "dictionary contains attribute "
        static let dictionaryShouldContain = "dictionary does not contain attribute "
        static let attributeListShouldNotContain = "private attributes list contains attribute "
        static let attributeListShouldContain = "private attributes list does not contain attribute "
    }

    fileprivate func matches(userDictionary: [String: Any], includeFlagConfig: Bool, includePrivateAttributes includePrivate: Bool, privateAttributes: [String]) -> ToMatchResult {
        var messages = [String]()

        //required attributes
        if let message = matchMessage(value: key, dictionary: userDictionary, attribute: CodingKeys.key.rawValue, includePrivate: true, privateAttributes: []) {
            messages.append(message)
        }
        let lastUpdatedString = DateFormatter.ldDateFormatter.string(from: lastUpdated)
        if let message = matchMessage(value: lastUpdatedString, dictionary: userDictionary, attribute: CodingKeys.lastUpdated.rawValue, includePrivate: includePrivate, privateAttributes: privateAttributes) {
            messages.append(message)
        }
        if let message = matchMessage(value: isAnonymous, dictionary: userDictionary, attribute: CodingKeys.isAnonymous.rawValue, includePrivate: includePrivate, privateAttributes: privateAttributes) {
            messages.append(message)
        }

        //optional attributes
        if let message = matchMessage(value: name, dictionary: userDictionary, attribute: CodingKeys.name.rawValue, includePrivate: includePrivate, privateAttributes: privateAttributes) {
            messages.append(message)
        }
        if let message = matchMessage(value: firstName, dictionary: userDictionary, attribute: CodingKeys.firstName.rawValue, includePrivate: includePrivate, privateAttributes: privateAttributes) {
            messages.append(message)
        }
        if let message = matchMessage(value: lastName, dictionary: userDictionary, attribute: CodingKeys.lastName.rawValue, includePrivate: includePrivate, privateAttributes: privateAttributes) {
            messages.append(message)
        }
        if let message = matchMessage(value: country, dictionary: userDictionary, attribute: CodingKeys.country.rawValue, includePrivate: includePrivate, privateAttributes: privateAttributes) {
            messages.append(message)
        }
        if let message = matchMessage(value: ipAddress, dictionary: userDictionary, attribute: CodingKeys.ipAddress.rawValue, includePrivate: includePrivate, privateAttributes: privateAttributes) {
            messages.append(message)
        }
        if let message = matchMessage(value: email, dictionary: userDictionary, attribute: CodingKeys.email.rawValue, includePrivate: includePrivate, privateAttributes: privateAttributes) {
            messages.append(message)
        }
        if let message = matchMessage(value: avatar, dictionary: userDictionary, attribute: CodingKeys.avatar.rawValue, includePrivate: includePrivate, privateAttributes: privateAttributes) {
            messages.append(message)
        }

        //custom
        if let message = matchMessage(customElements: (custom, device, operatingSystem), dictionary: userDictionary, includePrivate: includePrivate, privateAttributes: privateAttributes) {
            messages.append(message)
        }

        //private attributes
        if includePrivate && userDictionary[CodingKeys.privateAttributes.rawValue] != nil {
            messages.append(MatcherMessages.dictionaryShouldNotContain + CodingKeys.privateAttributes.rawValue)
        }

        //flag config
        if let message = matchMessage(flagConfig: flagStore.featureFlags, dictionary: userDictionary, includeFlagConfig: includeFlagConfig) {
            messages.append(message)
        }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    private func matchMessage(value: Any?, dictionary: [String: Any], attribute: String, includePrivate: Bool, privateAttributes: [String]) -> String? {
        if !includePrivate {
            if privateAttributes.contains(attribute) {
                if dictionary[attribute] != nil { return MatcherMessages.dictionaryShouldNotContain + attribute }
                if let redactedAttributes = dictionary[CodingKeys.privateAttributes.rawValue] as? [String] {
                    if value == nil && redactedAttributes.contains(attribute) { return MatcherMessages.attributeListShouldNotContain + attribute }
                    if value != nil && !redactedAttributes.contains(attribute) { return MatcherMessages.attributeListShouldContain + attribute }
                }
            } else {
                if !AnyComparer.isEqualAllowNil(value, to: dictionary[attribute]) { return MatcherMessages.valuesDontMatch + attribute }
                if let redactedAttributes = dictionary[CodingKeys.privateAttributes.rawValue] as? [String] {
                    if redactedAttributes.contains(attribute) { return MatcherMessages.attributeListShouldNotContain + attribute }
                }
            }
        } else {
            if !AnyComparer.isEqualAllowNil(value, to: dictionary[attribute]) { return MatcherMessages.valuesDontMatch + attribute }
        }

        return nil
    }

    private func matchMessage(flagConfig: [LDFlagKey: Any], dictionary: [String: Any], includeFlagConfig: Bool) -> String? {
        if includeFlagConfig {
            if let dictionaryConfig = dictionary[CodingKeys.config.rawValue] as? [LDFlagKey: Any] {
                if flagConfig != dictionaryConfig { return MatcherMessages.valuesDontMatch + CodingKeys.config.rawValue }
            } else {
                return MatcherMessages.dictionaryShouldContain + CodingKeys.config.rawValue
            }
        } else {
            if dictionary[CodingKeys.config.rawValue] != nil { return MatcherMessages.dictionaryShouldNotContain + CodingKeys.config.rawValue }
        }

        return nil
    }

    private func matchMessage(customElements: (custom: [String: Any]?, device: String?, operatingSystem: String?), dictionary: [String: Any], includePrivate: Bool, privateAttributes: [String]) -> String? {
        let custom = customElements.custom
        let device = customElements.device
        let operatingSystem = customElements.operatingSystem
        let redactedAttributes = dictionary[CodingKeys.privateAttributes.rawValue] as? [String]

        if !includePrivate && privateAttributes.contains(CodingKeys.custom.rawValue) {
            if var customDictionary = dictionary[CodingKeys.custom.rawValue] as? [String: Any] {
                if let message = matchMessage(value: device, dictionary: customDictionary, attribute: CodingKeys.device.rawValue, includePrivate: true, privateAttributes: []) { return message }
                customDictionary.removeValue(forKey: CodingKeys.device.rawValue)
                if let message = matchMessage(value: operatingSystem, dictionary: customDictionary, attribute: CodingKeys.operatingSystem.rawValue, includePrivate: true, privateAttributes: []) { return message }
                customDictionary.removeValue(forKey: CodingKeys.operatingSystem.rawValue)
                if !customDictionary.isEmpty { return MatcherMessages.dictionaryShouldNotContain + CodingKeys.custom.rawValue }
            }
            if var custom = custom, let redactedAttributes = redactedAttributes {
                custom.removeValue(forKey: CodingKeys.device.rawValue)
                custom.removeValue(forKey: CodingKeys.operatingSystem.rawValue)
                if !custom.isEmpty && !redactedAttributes.contains(CodingKeys.custom.rawValue) { return MatcherMessages.attributeListShouldContain + CodingKeys.custom.rawValue }
                if custom.isEmpty && redactedAttributes.contains(CodingKeys.custom.rawValue) { return MatcherMessages.attributeListShouldNotContain + CodingKeys.custom.rawValue }
            }
        } else {
            if let custom = custom {
                guard let customDictionary = dictionary[CodingKeys.custom.rawValue] as? [String: Any] else { return MatcherMessages.dictionaryShouldContain + CodingKeys.custom.rawValue }
                for customAttribute in custom.keys {
                    if !includePrivate && privateAttributes.contains(customAttribute) {
                        guard customDictionary[customAttribute] == nil else { return MatcherMessages.dictionaryShouldNotContain + customAttribute }
                        if let redactedAttributes = redactedAttributes {
                            if custom[customAttribute] == nil && redactedAttributes.contains(customAttribute) { return MatcherMessages.attributeListShouldNotContain + customAttribute }
                            if custom[customAttribute] != nil && !redactedAttributes.contains(customAttribute) { return MatcherMessages.attributeListShouldContain + customAttribute }
                        }
                    } else {
                        if !AnyComparer.isEqualAllowNil(custom[customAttribute], to: customDictionary[customAttribute]) { return MatcherMessages.valuesDontMatch + customAttribute }
                    }
                }
                if let message = matchMessage(value: device, dictionary: customDictionary, attribute: CodingKeys.device.rawValue, includePrivate: true, privateAttributes: []) { return message }
                if let message = matchMessage(value: operatingSystem, dictionary: customDictionary, attribute: CodingKeys.operatingSystem.rawValue, includePrivate: true, privateAttributes: []) { return message }
            } else {
                if device != nil || operatingSystem != nil {
                    guard let customDictionary = dictionary[CodingKeys.custom.rawValue] as? [String: Any] else { return MatcherMessages.dictionaryShouldContain + CodingKeys.custom.rawValue }
                    if let message = matchMessage(value: device, dictionary: customDictionary, attribute: CodingKeys.device.rawValue, includePrivate: true, privateAttributes: []) { return message }
                    if let message = matchMessage(value: operatingSystem, dictionary: customDictionary, attribute: CodingKeys.operatingSystem.rawValue, includePrivate: true, privateAttributes: []) { return message }
                } else {
                    if dictionary[CodingKeys.custom.rawValue] != nil { return MatcherMessages.dictionaryShouldNotContain + CodingKeys.custom.rawValue }
                }
            }
        }

        return nil
    }

    public func dictionaryValueWithAllAttributes(includeFlagConfig: Bool) -> [String: Any] {
        var dictionary = dictionaryValue(includeFlagConfig: includeFlagConfig, includePrivateAttributes: true, config: LDConfig())
        dictionary[CodingKeys.privateAttributes.rawValue] = privateAttributes
        return dictionary
    }
}

extension AnyComparer {
    static func isEqualAllowNil(_ value: Any?, to other: Any?) -> Bool {
        if value == nil && other == nil { return true }
        return isEqual(value, to: other)
    }
}

extension Dictionary where Key == String, Value == Any {
    struct Keys {
        public static let bool = "bool"
        public static let int = "int"
        public static let double = "double"
        public static let string = "string"
        public static let array = "array"
        public static let anyArray = "anyArray"
        public static let dictionary = "dictionary"
    }
    struct Values {
        public static let bool = true
        public static let int = 8675309
        public static let double = 2.71828
        public static let string = "some string value"
        public static let array = [0, 1, 2]
        public static let anyArray: [Any] = [true, 10, 3.14159, "a string", [0, 1], ["keyA": true]]
        public static let dictionary: [String: Any] = ["boolKey": true, "intKey": 17, "doubleKey": -0.25487, "stringKey": "some embedded string", "arrayKey": [0, 1, 2, 3, 4, 5], "dictionaryKey": ["embeddedDictionaryKey": "phew, that's a pain"]]

    }
    static func stub() -> [String: Any] {
        var stub = [String: Any]()
        stub[Keys.bool] = Values.bool
        stub[Keys.int] = Values.int
        stub[Keys.double] = Values.double
        stub[Keys.string] = Values.string
        stub[Keys.array] = Values.array
        stub[Keys.anyArray] = Values.anyArray
        stub[Keys.dictionary] = Values.dictionary
        return stub
    }
}
