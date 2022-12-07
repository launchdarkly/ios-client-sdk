import Foundation
@testable import LaunchDarkly

extension LDContext {
    struct StubConstants {
        static let key: LDValue = "stub.context.key"

        static let name = "stub.context.name"
        static let isAnonymous = false

        static let firstName: LDValue = "stub.context.firstName"
        static let lastName: LDValue = "stub.context.lastName"
        static let country: LDValue = "stub.context.country"
        static let ipAddress: LDValue = "stub.context.ipAddress"
        static let email: LDValue = "stub.context@email.com"
        static let avatar: LDValue = "stub.context.avatar"
        static let custom: [String: LDValue] = ["stub.context.custom.keyA": "stub.context.custom.valueA",
                                            "stub.context.custom.keyB": true,
                                            "stub.context.custom.keyC": 1027,
                                            "stub.context.custom.keyD": 2.71828,
                                            "stub.context.custom.keyE": [0, 1, 2],
                                            "stub.context.custom.keyF": ["1": 1, "2": 2, "3": 3]]
    }

    static func stub(key: String? = nil,
                     environmentReporter: EnvironmentReportingMock? = nil) -> LDContext {
        var builder = LDContextBuilder(key: key ?? UUID().uuidString)

        builder.name(StubConstants.name)
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
