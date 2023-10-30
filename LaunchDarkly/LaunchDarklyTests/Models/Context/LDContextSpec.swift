import Foundation
import XCTest

@testable import LaunchDarkly

final class LDContextSpec: XCTestCase {
    func testContextsAreEquatable() throws {
        var originalBuilder = LDContextBuilder(key: "context-key")
        originalBuilder.kind("user")
        originalBuilder.name("Example name")
        originalBuilder.trySetValue("groups", LDValue.array(["test", "it", "here"]))
        originalBuilder.trySetValue("address", LDValue.object(["address": "123 Easy St", "city": "Every Town"]))
        originalBuilder.addPrivateAttribute(Reference(literal: "name"))

        var duplicateBuilder = LDContextBuilder(key: "context-key")
        duplicateBuilder.kind("user")
        duplicateBuilder.name("Example name")
        duplicateBuilder.trySetValue("groups", LDValue.array(["test", "it", "here"]))
        duplicateBuilder.trySetValue("address", LDValue.object(["address": "123 Easy St", "city": "Every Town"]))
        duplicateBuilder.addPrivateAttribute(Reference("/name"))

        let original = try originalBuilder.build().get()
        let duplicate = try duplicateBuilder.build().get()

        XCTAssertEqual(original, duplicate)
    }

    func testContextsAreNotTheSame() throws {
        let values: [String: LDValue] = [
            "kind": "org",
            "name": "Example name",
            "groups": "This is a string",
            "address": LDValue.array(["wrong type again"])
        ]

        for (name, value) in values {
            var originalBuilder = LDContextBuilder(key: "context-key")
            var slightlyDifferent = LDContextBuilder(key: "context-key")
            slightlyDifferent.trySetValue(name, value)

            let original = try originalBuilder.build().get()
            let duplicate = try slightlyDifferent.build().get()

            XCTAssertNotEqual(original, duplicate)
        }
    }

    func testBuildCanCreateSimpleContext() throws {
        var builder = LDContextBuilder(key: "context-key")
        builder.name("Name")

        let context = try builder.build().get()
        XCTAssertFalse(context.isMulti())
    }

    func testBuilderWillNotAcceptKindOfTypeKind() {
        var builder = LDContextBuilder(key: "context-key")
        builder.kind("kind")

        guard case .failure(let error) = builder.build()
        else {
            XCTFail("Builder should not create context with kind 'kind'")
            return
        }

        XCTAssertEqual(error, ContextBuilderError.invalidKind)
    }

    func testBuilderCanHandleMissingKind() throws {
        var builder = LDContextBuilder(key: "key")

        var context = try builder.build().get()
        XCTAssertTrue(context.kind.isUser())

        builder.kind("")
        context = try builder.build().get()
        XCTAssertTrue(context.kind.isUser())
    }

    func testBuilderWillForceAnonymousToTrueForGeneratedKeys() throws {
        var builder = LDContextBuilder()
        builder.anonymous(false)

        let context = try builder.build().get()
        XCTAssertFalse(context.fullyQualifiedKey().isEmpty)

        guard case let .bool(anonymous) = context.getValue(Reference("anonymous"))
        else {
            XCTFail("Anonymous could not be retrieved")
            return
        }

        XCTAssertTrue(anonymous)
    }

    func testBuilderWillGenerateSameKeyForSameContextKind() throws {
        var builder = LDContextBuilder()
        let userContext1 = try builder.build().get()
        let userContext2 = try builder.build().get()

        builder.kind("org")

        let orgContext1 = try builder.build().get()
        let orgContext2 = try builder.build().get()

        builder.kind("user")
        let userContext3 = try builder.build().get()

        // All user keys are the same
        XCTAssertEqual(userContext1.fullyQualifiedKey(), userContext2.fullyQualifiedKey())
        XCTAssertEqual(userContext1.fullyQualifiedKey(), userContext3.fullyQualifiedKey())

        // All org keys are the same
        XCTAssertEqual(orgContext1.fullyQualifiedKey(), orgContext2.fullyQualifiedKey())

        // But they aren't equal to each other
        XCTAssertNotEqual(userContext1.fullyQualifiedKey(), orgContext1.fullyQualifiedKey())
    }

    func testSingleContextHasCorrectCanonicalKey() throws {
        let tests: [(String, String, String)] = [
            ("key", "user", "key"),
            ("key", "org", "org:key"),
            ("hi:there", "user", "hi:there"),
            ("hi:there", "org", "org:hi%3Athere")
        ]

        for (key, kind, expectedKey) in tests {
            var builder = LDContextBuilder(key: key)
            builder.kind(kind)

            let context = try builder.build().get()
            XCTAssertEqual(context.fullyQualifiedKey(), expectedKey)
        }
    }

    func testMultiContextHasCorrectCanonicalKey() throws {
        let tests: [([(String, String)], String)] = [
            ([("key", "user")], "key"),
            ([("userKey", "user"), ("orgKey", "org")], "org:orgKey:user:userKey"),
            ([("some user", "user"), ("org:key", "org")], "org:org%3Akey:user:some%20user")
        ]

        for (contextOptions, qualifiedKey) in tests {
            var multibuilder = LDMultiContextBuilder()

            for (key, kind) in contextOptions {
                var builder = LDContextBuilder(key: key)
                builder.kind(kind)

                switch builder.build() {
                case .success(let context):
                    multibuilder.addContext(context)
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                }
            }

            let context = try multibuilder.build().get()
            XCTAssertEqual(context.fullyQualifiedKey(), qualifiedKey)
        }
    }

    func testMultikindBuilderRequiresContext() throws {
        let multiBuilder = LDMultiContextBuilder()
        switch multiBuilder.build() {
        case .success:
            XCTFail("Multibuilder should have failed to build.")
        case .failure(let error):
            XCTAssertEqual(error, .emptyMultiKind)
        }
    }

    func testMultiBuilderFlattensMulticontext() throws {
        var multiBuilder = LDMultiContextBuilder()
        var builder = LDContextBuilder(key: "key")
        multiBuilder.addContext(try builder.build().get())

        builder.key("orgKey")
        builder.kind("org")
        multiBuilder.addContext(try builder.build().get())

        let multiContext = try multiBuilder.build().get()

        // Reset to a new builder
        multiBuilder = LDMultiContextBuilder()
        multiBuilder.addContext(multiContext)

        switch multiBuilder.build() {
        case .success(let context):
            // Ensure we didn't remove them from the existing context.
            XCTAssertEqual(2, multiContext.contextKeys().count)

            XCTAssertTrue(context.isMulti())
            let contextKeys = context.contextKeys()
            XCTAssertEqual(contextKeys["user"], "key")
            XCTAssertEqual(contextKeys["org"], "orgKey")
        case .failure:
            XCTFail("Multi-kind builder should not have failed.")
        }
    }

    func testMultikindBuilderFailsWithDuplicateContexts() throws {
        var multiBuilder = LDMultiContextBuilder()

        multiBuilder.addContext(try LDContextBuilder(key: "key").build().get())
        multiBuilder.addContext(try LDContextBuilder(key: "second").build().get())

        switch multiBuilder.build() {
        case .success:
            XCTFail("Multibuilder should have failed to build.")
        case .failure(let error):
            XCTAssertEqual(error, .duplicateKinds)
        }
    }

    func testCanSetCustomPropertiesByType() throws {
        var builder = LDContextBuilder(key: "key")
        builder.kind("user")
        builder.trySetValue("loves-swift", true)
        builder.trySetValue("pi", 3.1459)
        builder.trySetValue("answer-to-life", 42)
        builder.trySetValue("company", "LaunchDarkly")

        let context = try builder.build().get()
        XCTAssertEqual(.bool(true), context.attributes["loves-swift"])
        XCTAssertEqual(.number(3.1459), context.attributes["pi"])
        XCTAssertEqual(.number(42), context.attributes["answer-to-life"])
        XCTAssertEqual(.string("LaunchDarkly"), context.attributes["company"])
    }

    func testCanSetAndRemovePrivateAttributes() throws {
        var builder = LDContextBuilder(key: "key")

        XCTAssertTrue(try builder.build().get().privateAttributes.isEmpty)

        builder.addPrivateAttribute(Reference("name"))
        XCTAssertTrue(try builder.build().get().privateAttributes.first == Reference("name"))

        builder.removePrivateAttribute(Reference("name"))
        XCTAssertTrue(try builder.build().get().privateAttributes.isEmpty)

        // Removing one should remove them all
        builder.addPrivateAttribute(Reference("name"))
        builder.addPrivateAttribute(Reference("name"))
        builder.removePrivateAttribute(Reference("name"))
        XCTAssertTrue(try builder.build().get().privateAttributes.isEmpty)
    }

    func testTrySetValueHandlesInvalidValues() {
        let tests: [(String, LDValue, Bool)] = [
            ("", .bool(true), false),
            ("kind", .bool(true), false),
            ("kind", .string("user"), true)
        ]

        for (attribute, value, expected) in tests {
            var builder = LDContextBuilder(key: "key")
            let result = builder.trySetValue(attribute, value)
            XCTAssertEqual(result, expected)
        }
    }

    func testContextCanGetValue() throws {
        let tests: [(String, LDValue?)] = [
            // Basic simple attribute retrievals
            ("kind", .string("org")),
            ("key", .string("my-key")),
            ("name", .string("my-name")),
            ("anonymous", .bool(true)),
            ("attr", .string("my-attr")),
            ("/starts-with-slash", .string("love that prefix")),
            ("/crazy~0name", .string("still works")),
            ("/other", nil),
            // Invalid reference retrieval
            ("/", nil),
            ("", nil),
            ("/a//b", nil),
            // Hidden meta attributes
            ("privateAttributes", nil),
            // Can index arrays and objects
            ("/my-map/array", .array([.string("first"), .string("second")])),
            ("/my-map/1", .bool(true)),
            ("my-map/missing", nil),
            ("/starts-with-slash/1", nil)
        ]

        let array: [LDValue] = [.string("first"), .string("second")]
        let map: [String: LDValue] = ["array": .array(array), "1": .bool(true)]

        for (input, expectedValue) in tests {
            var builder = LDContextBuilder(key: "my-key")
            builder.kind("org")
            builder.name("my-name")
            builder.anonymous(true)
            builder.trySetValue("attr", .string("my-attr"))
            builder.trySetValue("starts-with-slash", .string("love that prefix"))
            builder.trySetValue("crazy~name", .string("still works"))
            builder.trySetValue("my-map", .object(map))

            let context = try builder.build().get()

            let reference = Reference(input)

            XCTAssertEqual(expectedValue, context.getValue(reference))
        }
    }

    func testMultiContextCanGetValue() throws {
        var multibuilder = LDMultiContextBuilder()
        var builder = LDContextBuilder(key: "user")

        multibuilder.addContext(try builder.build().get())

        builder.key("org")
        builder.kind("org")
        builder.name("my-name")
        builder.anonymous(true)
        builder.trySetValue("attr", .string("my-attr"))

        multibuilder.addContext(try builder.build().get())

        let context = try multibuilder.build().get()

        let tests: [(String, LDValue?)] = [
            ("kind", LDValue.string("multi")),
            ("key", nil),
            ("name", nil),
            ("anonymous", nil),
            ("attr", nil)
        ]

        for (input, expectedValue) in tests {
            let reference = Reference(input)
            XCTAssertEqual(context.getValue(reference), expectedValue)
        }
    }
}
