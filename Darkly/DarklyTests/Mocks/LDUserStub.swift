//
//  LDUserStub.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 10/19/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation
@testable import Darkly

extension LDUser {
    struct StubConstants {
        static let key = "stub.user.key"
        static let name = "stub.user.name"
        static let firstName = "stub.user.firstName"
        static let lastName = "stub.user.lastName"
        static let isAnonymous = false
        static let country = "stub.user.country"
        static let ipAddress = "stub.user.ipAddress"
        static let email = "stub.user@email.com"
        static let avatar = "stub.user.avatar"
        static let device = "stub.user.custom.device"
        static let operatingSystem = "stub.user.custom.operatingSystem"
        static let custom: [String: Any] = ["stub.user.custom.keyA": "stub.user.custom.valueA", "stub.user.custom.keyB": true, "stub.user.custom.keyC": 1027, "stub.user.custom.keyD": 2.71828, "stub.user.custom.keyE": [0, 1, 2], "stub.user.custom.keyF": ["1": 1, "2": 2, "3": 3], CodingKeys.device.rawValue: StubConstants.device, CodingKeys.operatingSystem.rawValue: StubConstants.operatingSystem]
    }

    static func stub(key: String? = nil, includeNullValue: Bool = false, includeVersions: Bool = true) -> LDUser {
        var user = LDUser(key: key ?? UUID().uuidString,
                          name: StubConstants.name,
                          firstName: StubConstants.firstName,
                          lastName: StubConstants.lastName,
                          country: StubConstants.country,
                          ipAddress: StubConstants.ipAddress,
                          email: StubConstants.email,
                          avatar: StubConstants.avatar,
                          custom: StubConstants.custom,
                          isAnonymous: StubConstants.isAnonymous)
        user.flagStore = FlagMaintainingMock(flags: user.stubFlags(includeNullValue: includeNullValue, includeVersions: includeVersions))
        return user
    }

    private func stubFlags(includeNullValue: Bool, includeVersions: Bool) -> [String: FeatureFlag] {
        var flags = DarklyServiceMock.Constants.featureFlags(includeNullValue: includeNullValue, includeVersions: includeVersions)
        flags["userKey"] = FeatureFlag(value: key, version: 2)
        return flags
    }

    static func stubUsers(_ count: Int) -> [LDUser] {
        var userStubs = [LDUser]()
        while userStubs.count < count { userStubs.append(LDUser.stub()) }
        return userStubs
    }
}

extension Array where Element == LDUser {
    var userFlags: [UserKey: CacheableUserFlags] {
        var flags = [UserKey: CacheableUserFlags]()
        self.forEach { (user) in flags[user.key] = CacheableUserFlags(user: user) }
        return flags
    }

    var userFlagDictionaries: [UserKey: Any] {
        let flags = userFlags
        return flags.mapValues { (cacheableUserFlags) in cacheableUserFlags.dictionaryValue }
    }
}
