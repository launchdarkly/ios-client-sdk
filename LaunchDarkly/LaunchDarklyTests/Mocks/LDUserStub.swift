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
        static let device: LDValue = "stub.user.custom.device"
        static let operatingSystem: LDValue = "stub.user.custom.operatingSystem"
        static let custom: [String: LDValue] = ["stub.user.custom.keyA": "stub.user.custom.valueA",
                                            "stub.user.custom.keyB": true,
                                            "stub.user.custom.keyC": 1027,
                                            "stub.user.custom.keyD": 2.71828,
                                            "stub.user.custom.keyE": [0, 1, 2],
                                            "stub.user.custom.keyF": ["1": 1, "2": 2, "3": 3]]

        static func custom(includeSystemValues: Bool) -> [String: LDValue] {
            var custom = StubConstants.custom
            if includeSystemValues {
                custom[CodingKeys.device.rawValue] = StubConstants.device
                custom[CodingKeys.operatingSystem.rawValue] = StubConstants.operatingSystem
            }
            return custom
        }
    }

    static func stub(key: String? = nil,
                     environmentReporter: EnvironmentReportingMock? = nil) -> LDUser {
        let user = LDUser(key: key ?? UUID().uuidString,
                          name: StubConstants.name,
                          firstName: StubConstants.firstName,
                          lastName: StubConstants.lastName,
                          country: StubConstants.country,
                          ipAddress: StubConstants.ipAddress,
                          email: StubConstants.email,
                          avatar: StubConstants.avatar,
                          custom: StubConstants.custom(includeSystemValues: true),
                          isAnonymous: StubConstants.isAnonymous,
                          secondary: StubConstants.secondary)
        return user
    }
}
