import Foundation
import XCTest

@testable import LaunchDarkly

final class ReferenceSpec: XCTestCase {
    func testVerifyEquality() {
        let tests: [(Reference, Reference, Bool)] = [
            (Reference("name"), Reference("name"), true),
            (Reference("name"), Reference("/name"), true),
            (Reference("/first/name"), Reference("/first/name"), true),
            (Reference(literal: "/name"), Reference(literal: "/name"), true),
            (Reference(literal: "/name"), Reference("/~1name"), true),
            (Reference(literal: "~name"), Reference("/~0name"), true),

            (Reference("different"), Reference("values"), false),
            (Reference("name/"), Reference("/name"), false),
            (Reference("/first/name"), Reference("/first//name"), false)
        ]

        for (lhs, rhs, expected) in tests {
            XCTAssertEqual(lhs == rhs, expected)
        }
    }
    func testFailsWithCorrectError() {
        let tests: [(String, ReferenceError)] = [
            ("", .empty),
            ("/", .empty),
            ("//", .doubleSlash),
            ("/a//b", .doubleSlash),
            ("/a/b/", .doubleSlash),
            ("/~3", .invalidEscapeSequence),
            ("/testing~something", .invalidEscapeSequence),
            ("/m~~0", .invalidEscapeSequence),
            ("/a~", .invalidEscapeSequence)
        ]

        for (path, error) in tests {
            let reference = Reference(path)
            XCTAssertTrue(!reference.isValid())
            XCTAssertEqual(reference.getError(), error)
        }
    }

    func testWithoutLeadingSlashes() {
        let tests = ["key", "kind", "name", "name/with/slashes", "name~0~1with-what-looks-like-escape-sequences"]

        for test in tests {
            let ref = Reference(test)
            XCTAssertTrue(ref.isValid())
            XCTAssertEqual(1, ref.depth())
            XCTAssertEqual(test, ref.component(0))
        }
    }

    func testWithLeadingSlashes() {
        let tests = [
            ("/key", "key"),
            ("/kind", "kind"),
            ("/name", "name"),
            ("/custom", "custom")
        ]

        for (ref, expected) in tests {
            let ref = Reference(ref)
            XCTAssertTrue(ref.isValid())
            XCTAssertEqual(1, ref.depth())
            XCTAssertEqual(expected, ref.component(0))
        }
    }

    func testHandlesSubcomponents() {
        let tests: [(String, Int, Int, String)] = [
            ("/a/b", 2, 0, "a"),
            ("/a/b", 2, 1, "b"),
            ("/a~1b/c", 2, 0, "a/b"),
            ("/a~1b/c", 2, 1, "c"),
            ("/a/10/20/30x", 4, 1, "10"),
            ("/a/10/20/30x", 4, 2, "20"),
            ("/a/10/20/30x", 4, 3, "30x")
        ]

        for (input, expectedLength, index, expectedName) in tests {
            let reference = Reference(input)

            XCTAssertEqual(expectedLength, reference.depth())
            XCTAssertEqual(expectedName, reference.component(index))
        }
    }

    func testCanHandleInvalidIndexRequests() {
        let reference = Reference("/a/b/c")

        XCTAssertTrue(reference.isValid())
        XCTAssertNotNil(reference.component(0))
        XCTAssertNotNil(reference.component(1))
        XCTAssertNotNil(reference.component(2))

        XCTAssertNil(reference.component(3))
    }
}
