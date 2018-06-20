//
//  LDUserStub.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 10/19/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation
@testable import LaunchDarkly

extension LDUser {
    struct StubConstants {
        static let key = "stub.user.key"
        static let userKey = "userKey"
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
        private static let custom: [String: Any] = ["stub.user.custom.keyA": "stub.user.custom.valueA",
                                                    "stub.user.custom.keyB": true,
                                                    "stub.user.custom.keyC": 1027,
                                                    "stub.user.custom.keyD": 2.71828,
                                                    "stub.user.custom.keyE": [0, 1, 2],
                                                    "stub.user.custom.keyF": ["1": 1, "2": 2, "3": 3]]

        static func custom(includeSystemValues: Bool) -> [String: Any] {
            var custom = StubConstants.custom
            if includeSystemValues {
                custom[CodingKeys.device.rawValue] = StubConstants.device
                custom[CodingKeys.operatingSystem.rawValue] = StubConstants.operatingSystem
            }
            return custom
        }
    }

    static func stub(key: String? = nil,
                     includeNullValue: Bool = true,
                     environmentReporter: EnvironmentReportingMock? = nil) -> LDUser {
        var user = LDUser(key: key ?? UUID().uuidString,
                          name: StubConstants.name,
                          firstName: StubConstants.firstName,
                          lastName: StubConstants.lastName,
                          country: StubConstants.country,
                          ipAddress: StubConstants.ipAddress,
                          email: StubConstants.email,
                          avatar: StubConstants.avatar,
                          custom: StubConstants.custom(includeSystemValues: true),
                          device: environmentReporter?.deviceModel,
                          operatingSystem: environmentReporter?.systemVersion,
                          isAnonymous: StubConstants.isAnonymous)
        user.flagStore = FlagMaintainingMock(flags: user.stubFlags(includeNullValue: includeNullValue))
        return user
    }

    private func stubFlags(includeNullValue: Bool) -> [String: FeatureFlag] {
        var flags = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: includeNullValue)
        flags[StubConstants.userKey] = FeatureFlag(value: key,
                                                   variation: DarklyServiceMock.Constants.variation,
                                                   version: DarklyServiceMock.Constants.version,
                                                   flagVersion: DarklyServiceMock.Constants.flagVersion,
                                                   eventTrackingContext: EventTrackingContext.stub())
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
