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
        let mockKey = UUID().uuidString
        let mockName = "mock.LDUser.name"
        let mockFirstName = "mock.LDUser.firstName"
        let mockLastName = "mock.LDUser.lastName"
        let mockCountry = "mock.LDUser.country"
        let mockIPAddress = "mock.LDUser.ipAddress"
        let mockEmail = "mock.LDUser.email@dummy.com"
        let mockAvatar = "mock.LDUser.avatar"
        let mockCustom = LDUser.stubCustomData()
        let mockDevice = LDUser.Values.device
        let mockOS = LDUser.Values.operatingSystem
        let mockIsAnonymous = false

        var subject: LDUser!
        describe("init") {
            context("called with optional elements") {
                beforeEach {
                    subject = LDUser(key: mockKey, name: mockName, firstName: mockFirstName, lastName: mockLastName, country: mockCountry, ipAddress: mockIPAddress, email: mockEmail, avatar: mockAvatar, custom: mockCustom, isAnonymous: mockIsAnonymous)
                }
                it("creates a LDUser with optional elements") {
                    expect(subject.key) == mockKey
                    expect(subject.name) == mockName
                    expect(subject.firstName) == mockFirstName
                    expect(subject.lastName) == mockLastName
                    expect(subject.isAnonymous) == mockIsAnonymous
                    expect(subject.country) == mockCountry
                    expect(subject.ipAddress) == mockIPAddress
                    expect(subject.email) == mockEmail
                    expect(subject.avatar) == mockAvatar
                    expect(subject.device) == mockDevice
                    expect(subject.operatingSystem) == mockOS
                    expect(subject.custom).toNot(beNil())
                    if let subjectCustom = subject.custom {
                        expect(subjectCustom == mockCustom).to(beTrue())
                    }
                    expect(subject.lastUpdated).toNot(beNil())
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

        describe("init from jsonDictionary") {
            var originalUser: LDUser!
            let mockLastUpdated = "2017-10-24T17:51:49.142Z"
            context("called with config") {
                context("and optional elements") {
                    beforeEach {
                        originalUser = LDUser(key: mockKey, name: mockName, firstName: mockFirstName, lastName: mockLastName, country: mockCountry, ipAddress: mockIPAddress, email: mockEmail, avatar: mockAvatar, custom: mockCustom, isAnonymous: mockIsAnonymous)
                        var jsonDictionary = originalUser.jsonDictionaryWithConfig
                        jsonDictionary[LDUser.CodingKeys.lastUpdated.rawValue] = mockLastUpdated
                        subject = LDUser(jsonDictionary: jsonDictionary)
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
                        expect(subject.lastUpdated) == DateFormatter.ldUserFormatter.date(from: mockLastUpdated)

                        expect(subject.flagStore.featureFlags == originalUser.flagStore.featureFlags).to(beTrue())
                    }
                }
                context("but without optional elements") {
                    beforeEach {
                        originalUser = LDUser(isAnonymous: true)
                        var jsonDictionary = originalUser.jsonDictionaryWithConfig
                        jsonDictionary[LDUser.CodingKeys.lastUpdated.rawValue] = mockLastUpdated
                        subject = LDUser(jsonDictionary: jsonDictionary)

                    }
                    it("creates a user without optional elements and with feature flags") {
                        expect(subject.key) == originalUser.key
                        expect(subject.isAnonymous) == originalUser.isAnonymous
                        expect(subject.lastUpdated) == DateFormatter.ldUserFormatter.date(from: mockLastUpdated)

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

                        expect(subject.flagStore.featureFlags == originalUser.flagStore.featureFlags).to(beTrue())
                    }
                }
            }
            context("called without config") {
                context("but with optional elements") {
                    beforeEach {
                        originalUser = LDUser(key: mockKey, name: mockName, firstName: mockFirstName, lastName: mockLastName, country: mockCountry, ipAddress: mockIPAddress, email: mockEmail, avatar: mockAvatar, custom: mockCustom, isAnonymous: mockIsAnonymous)
                        var jsonDictionary = originalUser.jsonDictionaryWithoutConfig
                        jsonDictionary[LDUser.CodingKeys.lastUpdated.rawValue] = mockLastUpdated
                        subject = LDUser(jsonDictionary: jsonDictionary)
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
                        expect(subject.lastUpdated) == DateFormatter.ldUserFormatter.date(from: mockLastUpdated)

                        expect(subject.flagStore.featureFlags.isEmpty).to(beTrue())
                    }
                }
                context("or optional elements") {
                    beforeEach {
                        originalUser = LDUser(isAnonymous: true)
                        var jsonDictionary = originalUser.jsonDictionaryWithoutConfig
                        jsonDictionary[LDUser.CodingKeys.lastUpdated.rawValue] = mockLastUpdated
                        subject = LDUser(jsonDictionary: jsonDictionary)
                    }
                    it("creates a user without optional elements or feature flags") {
                        expect(subject.key) == originalUser.key
                        expect(subject.isAnonymous) == originalUser.isAnonymous
                        expect(subject.lastUpdated) == DateFormatter.ldUserFormatter.date(from: mockLastUpdated)

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

                        expect(subject.flagStore.featureFlags.isEmpty).to(beTrue())
                    }
                }
                context("and with an empty dictionary") {
                    beforeEach {
                        subject = LDUser(jsonDictionary: [:])
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

                        expect(subject.flagStore.featureFlags.isEmpty).to(beTrue())
                    }
                }
                context("but with an incorrect last updated format") {
                    let invalidLastUpdated = "2017-10-24T17:51:49Z"
                    beforeEach {
                        subject = LDUser(jsonDictionary: [LDUser.CodingKeys.lastUpdated.rawValue: invalidLastUpdated])
                    }
                    it("creates a user without optional elements or feature flags") {
                        expect(subject.key).toNot(beNil())
                        expect(subject.key.isEmpty).to(beFalse())
                        expect(subject.isAnonymous) == false
                        expect(subject.lastUpdated).toNot(beNil())
                        expect(DateFormatter.ldUserFormatter.string(from: subject.lastUpdated)) != invalidLastUpdated

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

                        expect(subject.flagStore.featureFlags.isEmpty).to(beTrue())
                    }
                }
            }
        }

        describe("jsonDictionary") {
            var jsonDictionary: [String: Any]!
            context("called with config") {
                context("and optional elements") {
                    beforeEach {
                        subject = LDUser(key: mockKey, name: mockName, firstName: mockFirstName, lastName: mockLastName, country: mockCountry, ipAddress: mockIPAddress, email: mockEmail, avatar: mockAvatar, custom: mockCustom, isAnonymous: mockIsAnonymous)
                        jsonDictionary = subject.jsonDictionaryWithConfig
                    }
                    it("creates a json dictionary describing the user with optional elements and feature flags") {
                        expect(jsonDictionary[LDUser.CodingKeys.key.rawValue] as? String) == subject.key
                        expect(jsonDictionary[LDUser.CodingKeys.name.rawValue] as? String) == subject.name
                        expect(jsonDictionary[LDUser.CodingKeys.firstName.rawValue] as? String) == subject.firstName
                        expect(jsonDictionary[LDUser.CodingKeys.lastName.rawValue] as? String) == subject.lastName
                        expect(jsonDictionary[LDUser.CodingKeys.isAnonymous.rawValue] as? Bool) == subject.isAnonymous
                        expect(jsonDictionary[LDUser.CodingKeys.country.rawValue] as? String) == subject.country
                        expect(jsonDictionary[LDUser.CodingKeys.ipAddress.rawValue] as? String) == subject.ipAddress
                        expect(jsonDictionary[LDUser.CodingKeys.email.rawValue] as? String) == subject.email
                        expect(jsonDictionary[LDUser.CodingKeys.avatar.rawValue] as? String) == subject.avatar
                        if let subjectCustom = subject.custom {
                            expect(jsonDictionary[LDUser.CodingKeys.custom.rawValue] as? [String: Any]).toNot(beNil())
                            if let jsonCustom = jsonDictionary[LDUser.CodingKeys.custom.rawValue] as? [String: Any] {
                                expect(jsonCustom == subjectCustom).to(beTrue())
                                if let subjectDevice = subject.device {
                                    expect(jsonCustom[LDUser.CodingKeys.device.rawValue] as? String) == subjectDevice
                                }
                                if let subjectOS = subject.operatingSystem {
                                    expect(jsonCustom[LDUser.CodingKeys.operatingSystem.rawValue] as? String) == subjectOS
                                }
                            }
                        }

                        expect(jsonDictionary[LDUser.CodingKeys.lastUpdated.rawValue] as? String).toNot(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.config.rawValue] as? [String: Any]).toNot(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.config.rawValue] as? [String: Any] == subject.flagStore.featureFlags).to(beTrue())
                    }
                }
                context("but without optional elements") {
                    beforeEach {
                        subject = LDUser(isAnonymous: true)
                        jsonDictionary = subject.jsonDictionaryWithConfig
                    }
                    it("creates a json dictionary describing the user without optional elements and feature flags") {
                        expect(jsonDictionary[LDUser.CodingKeys.key.rawValue] as? String) == subject.key
                        expect(jsonDictionary[LDUser.CodingKeys.isAnonymous.rawValue] as? Bool) == subject.isAnonymous
                        expect(jsonDictionary[LDUser.CodingKeys.lastUpdated.rawValue] as? String).toNot(beNil())

                        expect(jsonDictionary[LDUser.CodingKeys.name.rawValue]).to(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.firstName.rawValue]).to(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.lastName.rawValue]).to(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.country.rawValue]).to(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.ipAddress.rawValue]).to(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.email.rawValue]).to(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.avatar.rawValue]).to(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.custom.rawValue]).to(beNil())

                        expect(jsonDictionary[LDUser.CodingKeys.config.rawValue] as? [String: Any]).toNot(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.config.rawValue] as? [String: Any] == subject.flagStore.featureFlags).to(beTrue())
                    }
                }
            }
            context("called without config") {
                context("and with optional elements") {
                    beforeEach {
                        subject = LDUser(key: mockKey, name: mockName, firstName: mockFirstName, lastName: mockLastName, country: mockCountry, ipAddress: mockIPAddress, email: mockEmail, avatar: mockAvatar, custom: mockCustom, isAnonymous: mockIsAnonymous)
                        jsonDictionary = subject.jsonDictionaryWithoutConfig
                    }
                    it("creates a json dictionary describing the user with optional elements") {
                        expect(jsonDictionary[LDUser.CodingKeys.key.rawValue] as? String) == subject.key
                        expect(jsonDictionary[LDUser.CodingKeys.name.rawValue] as? String) == subject.name
                        expect(jsonDictionary[LDUser.CodingKeys.firstName.rawValue] as? String) == subject.firstName
                        expect(jsonDictionary[LDUser.CodingKeys.lastName.rawValue] as? String) == subject.lastName
                        expect(jsonDictionary[LDUser.CodingKeys.isAnonymous.rawValue] as? Bool) == subject.isAnonymous
                        expect(jsonDictionary[LDUser.CodingKeys.country.rawValue] as? String) == subject.country
                        expect(jsonDictionary[LDUser.CodingKeys.ipAddress.rawValue] as? String) == subject.ipAddress
                        expect(jsonDictionary[LDUser.CodingKeys.email.rawValue] as? String) == subject.email
                        expect(jsonDictionary[LDUser.CodingKeys.avatar.rawValue] as? String) == subject.avatar
                        if let subjectCustom = subject.custom {
                            expect(jsonDictionary[LDUser.CodingKeys.custom.rawValue] as? [String: Any]).toNot(beNil())
                            if let jsonCustom = jsonDictionary[LDUser.CodingKeys.custom.rawValue] as? [String: Any] {
                                expect(jsonCustom == subjectCustom).to(beTrue())
                                if let subjectDevice = subject.device {
                                    expect(jsonCustom[LDUser.CodingKeys.device.rawValue] as? String) == subjectDevice
                                }
                                if let subjectOS = subject.operatingSystem {
                                    expect(jsonCustom[LDUser.CodingKeys.operatingSystem.rawValue] as? String) == subjectOS
                                }
                            }
                        }

                        expect(jsonDictionary[LDUser.CodingKeys.lastUpdated.rawValue] as? String).toNot(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.config.rawValue]).to(beNil())
                    }
                }
                context("or optional elements") {
                    beforeEach {
                        subject = LDUser(isAnonymous: true)
                        jsonDictionary = subject.jsonDictionaryWithoutConfig
                    }
                    it("creates a json dictionary describing the user without optional elements and feature flags") {
                        expect(jsonDictionary[LDUser.CodingKeys.key.rawValue] as? String) == subject.key
                        expect(jsonDictionary[LDUser.CodingKeys.isAnonymous.rawValue] as? Bool) == subject.isAnonymous
                        expect(jsonDictionary[LDUser.CodingKeys.lastUpdated.rawValue] as? String).toNot(beNil())

                        expect(jsonDictionary[LDUser.CodingKeys.name.rawValue]).to(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.firstName.rawValue]).to(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.lastName.rawValue]).to(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.country.rawValue]).to(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.ipAddress.rawValue]).to(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.email.rawValue]).to(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.avatar.rawValue]).to(beNil())
                        expect(jsonDictionary[LDUser.CodingKeys.custom.rawValue]).to(beNil())

                        expect(jsonDictionary[LDUser.CodingKeys.config.rawValue]).to(beNil())
                    }
                }
            }
        }
    }
}

extension LDUser {
    struct Values {
        public static let device = "some user device"
        public static let operatingSystem = "some user os"
    }

    static func stubCustomData() -> [String: Any] {
        var stubData = Dictionary.stub()
        stubData[LDUser.CodingKeys.device.rawValue] = Values.device
        stubData[LDUser.CodingKeys.operatingSystem.rawValue] = Values.operatingSystem

        return stubData
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
