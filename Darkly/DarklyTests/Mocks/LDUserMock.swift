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
        static let custom: [String: Encodable] = ["customKeyA": "stubUserCustomValueA", "customKeyB": true, "customKeyC": 1027, "customKeyD": 2.71828, "customKeyE": [0, 1, 2], "customKeyF": ["1": 1, "2": 2, "3": 3], "device": "stubUserDevice", "os": "stubUserOs"]
    }

    static func stub(key: String? = nil) -> LDUser {
        return LDUser(key: key ?? Constants.key,
                      name: Constants.name,
                      firstName: Constants.firstName,
                      lastName: Constants.lastName,
                      isAnonymous: Constants.isAnonymous,
                      country: Constants.country,
                      ipAddress: Constants.ipAddress,
                      email: Constants.email,
                      avatar: Constants.avatar,
                      custom: Constants.custom)
    }
}
