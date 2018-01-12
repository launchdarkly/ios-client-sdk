//
//  LDUserMock.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 10/19/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation
@testable import Darkly

extension LDUser {
    struct Constants {
        static let key = "stubUserKey"
        static let name = "stubUserName"
        static let firstName = "stubUserFirstName"
        static let lastName = "stubUserLastName"
        static let isAnonymous = false
        static let country = "stubUserCountry"
        static let ipAddress = "stubUserIPAddress"
        static let email = "stubUser@email.com"
        static let avatar = "stubUserAvatar"
        static let custom: [String: Any] = ["customKeyA": "stubUserCustomValueA", "customKeyB": true, "customKeyC": 1027, "customKeyD": 2.71828, "customKeyE": [0, 1, 2], "customKeyF": ["1": 1, "2": 2, "3": 3], "device": "stubUserDevice", "os": "stubUserOs"]
    }

    static func stub(key: String? = nil) -> LDUser {
        var user = LDUser(key: key ?? UUID().uuidString,
                          name: Constants.name,
                          firstName: Constants.firstName,
                          lastName: Constants.lastName,
                          country: Constants.country,
                          ipAddress: Constants.ipAddress,
                          email: Constants.email,
                          avatar: Constants.avatar,
                          custom: Constants.custom,
                          isAnonymous: Constants.isAnonymous)
        user.flagStore = LDFlagMaintainingMock(flags: user.stubFlags())
        return user
    }

    private func stubFlags() -> [String: Any] {
        var flags = DarklyServiceMock.Constants.featureFlags
        flags["userKey"] = key
        return flags
    }

    static func stubUsers(_ count: Int) -> [LDUser] {
        var userStubs = [LDUser]()
        while userStubs.count < count { userStubs.append(LDUser.stub()) }
        return userStubs
    }
}

extension Array where Element == LDUser {
    var userFlags: [String: UserFlags] {
        var flags = [String: UserFlags]()
        self.forEach { (user) in flags[user.key] = UserFlags(user: user) }
        return flags
    }

    var userFlagDictionaries: [String: Any] {
        let flags = userFlags
        return flags.mapValues { (userFlags) in userFlags.dictionaryValue }
    }
}
