import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class LDUserSpec: QuickSpec {

    override func spec() {
        initSpec()
        dictionaryValueSpec()
        isEqualSpec()
    }

    private func initSpec() {
        initSubSpec()
        initWithEnvironmentReporterSpec()
    }

    private func initSubSpec() {
        var user: LDUser!
        describe("init") {
            it("with all fields and custom overriding system values") {
                user = LDUser(key: LDUser.StubConstants.key,
                              name: LDUser.StubConstants.name,
                              firstName: LDUser.StubConstants.firstName,
                              lastName: LDUser.StubConstants.lastName,
                              country: LDUser.StubConstants.country,
                              ipAddress: LDUser.StubConstants.ipAddress,
                              email: LDUser.StubConstants.email,
                              avatar: LDUser.StubConstants.avatar,
                              custom: LDUser.StubConstants.custom(includeSystemValues: true),
                              isAnonymous: LDUser.StubConstants.isAnonymous,
                              privateAttributes: LDUser.optionalAttributes,
                              secondary: LDUser.StubConstants.secondary)
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
                expect(user.custom == LDUser.StubConstants.custom(includeSystemValues: true)).to(beTrue())
                expect(user.privateAttributes) == LDUser.optionalAttributes
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
                    expect(user.custom.count) == 2
                    expect(user.custom[LDUser.CodingKeys.device.rawValue]) == .string(environmentReporter.deviceModel)
                    expect(user.custom[LDUser.CodingKeys.operatingSystem.rawValue]) == .string(environmentReporter.systemVersion)
                    expect(user.privateAttributes).to(beEmpty())
                    expect(user.secondary).to(beNil())
                }
            }
            context("called without a key multiple times") {
                var users = [LDUser]()
                beforeEach {
                    while users.count < 3 {
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
                expect(user.custom.count) == 2
                expect(user.custom[LDUser.CodingKeys.device.rawValue]) == .string(environmentReporter.deviceModel)
                expect(user.custom[LDUser.CodingKeys.operatingSystem.rawValue]) == .string(environmentReporter.systemVersion)

                expect(user.privateAttributes).to(beEmpty())
            }
        }
    }

    private func dictionaryValueSpec() {
        let optionalNames = LDUser.optionalAttributes.map { $0.name }
        let allCustomPrivitizable = Array(LDUser.StubConstants.custom(includeSystemValues: true).keys)

        describe("dictionaryValue") {
            var user: LDUser!
            var config: LDConfig!
            var userDictionary: [String: Any]!

            beforeEach {
                config = LDConfig.stub
                user = LDUser.stub()
            }

            context("with an empty user") {
                beforeEach {
                    user = LDUser()
                    // Remove SDK set attributes
                    user.custom = [:]
                }
                // Should be the same regardless of including/privitizing attributes
                let testCase = {
                    it("creates expected user dictionary") {
                        expect(userDictionary.count) == 2
                        // Required attributes
                        expect(userDictionary[LDUser.CodingKeys.key.rawValue] as? String) == user.key
                        expect(userDictionary[LDUser.CodingKeys.isAnonymous.rawValue] as? Bool) == user.isAnonymous
                    }
                }
                context("including private attributes") {
                    beforeEach {
                        userDictionary = user.dictionaryValue(includePrivateAttributes: true, config: config)
                    }
                    testCase()
                }
                context("privatizing all globally") {
                    beforeEach {
                        config.allUserAttributesPrivate = true
                        userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)
                    }
                    testCase()
                }
                context("privatizing all individually in config") {
                    beforeEach {
                        config.privateUserAttributes = LDUser.optionalAttributes + [UserAttribute.forName("customAttr")]
                        userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)
                    }
                    testCase()
                }
                context("privatizing all individually on user") {
                    beforeEach {
                        user.privateAttributes = LDUser.optionalAttributes + [UserAttribute.forName("customAttr")]
                        userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)
                    }
                    testCase()
                }
            }

            it("includePrivateAttributes always includes attributes") {
                config.allUserAttributesPrivate = true
                config.privateUserAttributes = LDUser.optionalAttributes + allCustomPrivitizable.map { UserAttribute.forName($0) }
                user.privateAttributes = LDUser.optionalAttributes + allCustomPrivitizable.map { UserAttribute.forName($0) }
                let userDictionary = user.dictionaryValue(includePrivateAttributes: true, config: config)

                expect(userDictionary.count) == 11

                // Required attributes
                expect(userDictionary[LDUser.CodingKeys.key.rawValue] as? String) == user.key
                expect(userDictionary[LDUser.CodingKeys.isAnonymous.rawValue] as? Bool) == user.isAnonymous

                // Built-in optional attributes
                expect(userDictionary[LDUser.CodingKeys.name.rawValue] as? String) == user.name
                expect(userDictionary[LDUser.CodingKeys.firstName.rawValue] as? String) == user.firstName
                expect(userDictionary[LDUser.CodingKeys.lastName.rawValue] as? String) == user.lastName
                expect(userDictionary[LDUser.CodingKeys.email.rawValue] as? String) == user.email
                expect(userDictionary[LDUser.CodingKeys.ipAddress.rawValue] as? String) == user.ipAddress
                expect(userDictionary[LDUser.CodingKeys.avatar.rawValue] as? String) == user.avatar
                expect(userDictionary[LDUser.CodingKeys.secondary.rawValue] as? String) == user.secondary
                expect(userDictionary[LDUser.CodingKeys.country.rawValue] as? String) == user.country

                let customDictionary = userDictionary.customDictionary()!
                expect(customDictionary.count) == allCustomPrivitizable.count

                // Custom attributes
                allCustomPrivitizable.forEach { attr in
                    expect(LDValue.fromAny(customDictionary[attr])) == user.custom[attr]
                }

                // Redacted attributes is empty
                expect(userDictionary[LDUser.CodingKeys.privateAttributes.rawValue]).to(beNil())
            }

            [false, true].forEach { isCustomAttr in
                (isCustomAttr ? LDUser.StubConstants.custom(includeSystemValues: true).keys.map { UserAttribute.forName($0) }
                              : LDUser.optionalAttributes).forEach { privateAttr in
                    [false, true].forEach { inConfig in
                        it("with \(privateAttr) private in \(inConfig ? "config" : "user")") {
                            if inConfig {
                                config.privateUserAttributes = [privateAttr]
                            } else {
                                user.privateAttributes = [privateAttr]
                            }

                            userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)

                            expect(userDictionary.redactedAttributes) == [privateAttr.name]

                            let includingDictionary = user.dictionaryValue(includePrivateAttributes: true, config: config)
                            if !isCustomAttr {
                                let userDictionaryWithoutRedacted = userDictionary.filter { $0.key != "privateAttrs" }
                                let includingDictionaryWithoutRedacted = includingDictionary.filter { $0.key != privateAttr.name && $0.key != "privateAttrs" }
                                expect(AnyComparer.isEqual(userDictionaryWithoutRedacted, to: includingDictionaryWithoutRedacted)) == true
                            } else {
                                let userDictionaryWithoutRedacted = userDictionary.filter { $0.key != "custom" && $0.key != "privateAttrs" }
                                let includingDictionaryWithoutRedacted = includingDictionary.filter { $0.key != "custom" && $0.key != "privateAttrs" }
                                expect(AnyComparer.isEqual(userDictionaryWithoutRedacted, to: includingDictionaryWithoutRedacted)) == true
                                let expectedCustom = (includingDictionary["custom"] as! [String: Any]).filter { $0.key != privateAttr.name }
                                expect(AnyComparer.isEqual(userDictionary["custom"], to: expectedCustom)) == true
                            }
                        }
                    }
                }
            }

            context("with allUserAttributesPrivate") {
                beforeEach {
                    config.allUserAttributesPrivate = true
                    userDictionary = user.dictionaryValue(includePrivateAttributes: false, config: config)
                }
                it("creates expected dictionary") {
                    expect(userDictionary.count) == 3
                    // Required attributes
                    expect(userDictionary[LDUser.CodingKeys.key.rawValue] as? String) == user.key
                    expect(userDictionary[LDUser.CodingKeys.isAnonymous.rawValue] as? Bool) == user.isAnonymous

                    expect(Set(userDictionary.redactedAttributes!)) == Set(optionalNames + allCustomPrivitizable)
                }
            }

            context("with no private attributes") {
                let noPrivateAssertions = {
                    it("matches dictionary including private") {
                        expect(AnyComparer.isEqual(userDictionary, to: user.dictionaryValue(includePrivateAttributes: true, config: config))) == true
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
        }
    }

    private func isEqualSpec() {
        var user: LDUser!
        var otherUser: LDUser!

        describe("isEqual") {
            context("when users are equal") {
                it("returns true with all properties set") {
                    user = LDUser.stub()
                    otherUser = user
                    expect(user.isEqual(to: otherUser)) == true
                }
                it("returns true with no properties set") {
                    user = LDUser()
                    otherUser = user
                    expect(user.isEqual(to: otherUser)) == true
                }
            }
            context("when users are not equal") {
                let testFields: [(String, Bool, LDValue, (inout LDUser, LDValue?) -> Void)] =
                    [("key", false, "dummy", { u, v in u.key = v!.stringValue() }),
                     ("secondary", true, "dummy", { u, v in u.secondary = v?.stringValue() }),
                     ("name", true, "dummy", { u, v in u.name = v?.stringValue() }),
                     ("firstName", true, "dummy", { u, v in u.firstName = v?.stringValue() }),
                     ("lastName", true, "dummy", { u, v in u.lastName = v?.stringValue() }),
                     ("country", true, "dummy", { u, v in u.country = v?.stringValue() }),
                     ("ipAddress", true, "dummy", { u, v in u.ipAddress = v?.stringValue() }),
                     ("email address", true, "dummy", { u, v in u.email = v?.stringValue() }),
                     ("avatar", true, "dummy", { u, v in u.avatar = v?.stringValue() }),
                     ("custom", false, ["dummy": true], { u, v in u.custom = (v!.toAny() as! [String: Any]).mapValues { LDValue.fromAny($0) } }),
                     ("isAnonymous", false, true, { u, v in u.isAnonymous = v!.booleanValue() }),
                     ("privateAttributes", false, "dummy", { u, v in u.privateAttributes = [UserAttribute.forName(v!.stringValue())] })]
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
    public func dictionaryValueWithAllAttributes() -> [String: Any] {
        var dictionary = dictionaryValue(includePrivateAttributes: true, config: LDConfig.stub)
        dictionary[CodingKeys.privateAttributes.rawValue] = privateAttributes
        return dictionary
    }
}

extension Dictionary where Key == String, Value == Any {
    fileprivate var redactedAttributes: [String]? {
        self[LDUser.CodingKeys.privateAttributes.rawValue] as? [String]
    }
    fileprivate func customDictionary() -> [String: Any]? {
        self[LDUser.CodingKeys.custom.rawValue] as? [String: Any]
    }
}
