import Foundation
import XCTest

@testable import LaunchDarkly

final class LDUserToContextSpec: XCTestCase {
    func testSimpleUserIsConvertedToSimpleContext() throws {
        let user = LDUser(key: "user-key")
        let builder = LDContextBuilder(key: "user-key")
        let context = try builder.build().get()
        let encoder = JSONEncoder()
        let encodedContext = try encoder.encode(context)
        let encodedUserContext = try encoder.encode(user.toContext().get())

        XCTAssertEqual(encodedContext, encodedUserContext)
    }

    func testComplexUserConversion() throws {
        var user = LDUser(key: "user-key")
        user.name = "Example user"
        user.firstName = "Example"
        user.lastName = "user"
        user.country = "United States"
        user.ipAddress = "192.168.1.1"
        user.email = "example@test.com"
        user.avatar = "profile.jpg"
        user.custom = ["/nested/attribute": "here is a nested attribute"]
        user.isAnonymous = true
        user.privateAttributes = [UserAttribute("/nested/attribute")]
        user.secondary = "secondary"

        var builder = LDContextBuilder(key: "user-key")
        builder.name("Example user")
        builder.trySetValue("firstName", "Example".toLDValue())
        builder.trySetValue("lastName", "user".toLDValue())
        builder.trySetValue("country", "United States".toLDValue())
        builder.trySetValue("ipAddress", "192.168.1.1".toLDValue())
        builder.trySetValue("email", "example@test.com".toLDValue())
        builder.trySetValue("avatar", "profile.jpg".toLDValue())
        builder.trySetValue("/nested/attribute", "here is a nested attribute".toLDValue())
        builder.anonymous(true)
        builder.addPrivateAttribute(Reference(literal: "/nested/attribute"))
        builder.trySetValue("secondary", "secondary".toLDValue())

        let context = try builder.build().get()
        let userContext = try user.toContext().get()

        XCTAssertEqual(context, userContext)
    }

    func testUserAttributeRedactionWorksAsExpected() throws {
        var user = LDUser(key: "user-key")
        user.custom = [
            "a": "should be removed",
            "b": "should be retained",
            "/nested/attribute/path": "should be removed"
        ]
        user.privateAttributes = [UserAttribute("a"), UserAttribute("/nested/attribute/path")]
        let context = try user.toContext().get()
        let output = try JSONEncoder().encode(context)
        let outputJson = String(data: output, encoding: .utf8)

        XCTAssertTrue(outputJson!.contains("should be retained"))
        XCTAssertFalse(outputJson!.contains("should be removed"))
    }
}
