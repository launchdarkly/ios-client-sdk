import Foundation
@testable import LaunchDarkly

extension LDContext {
    struct StubConstants {
        static let key: LDValue = "stub.user.key"

        static let name = "stub.user.name"
        static let secondary = "stub.user.secondary"
        static let isAnonymous = false

        static let firstName: LDValue = "stub.user.firstName"
        static let lastName: LDValue = "stub.user.lastName"
        static let country: LDValue = "stub.user.country"
        static let ipAddress: LDValue = "stub.user.ipAddress"
        static let email: LDValue = "stub.user@email.com"
        static let avatar: LDValue = "stub.user.avatar"
        static let custom: [String: LDValue] = ["stub.user.custom.keyA": "stub.user.custom.valueA",
                                            "stub.user.custom.keyB": true,
                                            "stub.user.custom.keyC": 1027,
                                            "stub.user.custom.keyD": 2.71828,
                                            "stub.user.custom.keyE": [0, 1, 2],
                                            "stub.user.custom.keyF": ["1": 1, "2": 2, "3": 3]]
    }

    static func stub(key: String? = nil,
                     environmentReporter: EnvironmentReportingMock? = nil) -> LDContext {
        var builder = LDContextBuilder(key: key ?? UUID().uuidString)

        builder.name(StubConstants.name)
        builder.secondary(StubConstants.secondary)
        builder.anonymous(StubConstants.isAnonymous)

        builder.trySetValue("firstName", StubConstants.firstName)
        builder.trySetValue("lastName", StubConstants.lastName)
        builder.trySetValue("country", StubConstants.country)
        builder.trySetValue("ip", StubConstants.ipAddress)
        builder.trySetValue("email", StubConstants.email)
        builder.trySetValue("avatar", StubConstants.avatar)

        for (key, value) in StubConstants.custom {
            builder.trySetValue(key, value)
        }

        var context: LDContext? = nil
        if case .success(let ctx) = builder.build() {
            context = ctx
        }

        return context!
    }
}
