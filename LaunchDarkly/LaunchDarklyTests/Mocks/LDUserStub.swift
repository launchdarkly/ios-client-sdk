//
//  LDUserStub.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
@testable import LaunchDarkly

extension LDUser {
    struct StubConstants {
        static let key = "stub.user.key"
        static let secondary = "stub.user.secondary"
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
        static let custom: [String: Any] = ["stub.user.custom.keyA": "stub.user.custom.valueA",
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
                     includeVersions: Bool = true,
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
                          isAnonymous: StubConstants.isAnonymous,
                          device: environmentReporter?.deviceModel,
                          operatingSystem: environmentReporter?.systemVersion,
                          secondary: StubConstants.secondary)
        user.flagStore = FlagMaintainingMock(flags: user.stubFlags(includeNullValue: includeNullValue, includeVersions: includeVersions))
        return user
    }

    func stubFlags(includeNullValue: Bool, includeVersions: Bool = true) -> [String: FeatureFlag] {
        var flags = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: includeNullValue, includeVersions: includeVersions)
        flags[StubConstants.userKey] = FeatureFlag(flagKey: StubConstants.userKey,
                                                   value: key,
                                                   variation: DarklyServiceMock.Constants.variation,
                                                   version: includeVersions ? DarklyServiceMock.Constants.version : nil,
                                                   flagVersion: DarklyServiceMock.Constants.flagVersion,
                                                   trackEvents: true,
                                                   debugEventsUntilDate: Date().addingTimeInterval(30.0),
                                                   reason: DarklyServiceMock.Constants.reason,
                                                   trackReason: false)
        return flags
    }
}
