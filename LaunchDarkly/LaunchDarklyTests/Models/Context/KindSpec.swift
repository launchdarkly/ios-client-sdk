import Foundation
import XCTest

@testable import LaunchDarkly

final class KindSpec: XCTestCase {
    func testKindCorrectlyIdentifiesAsMulti() {
        let options: [(Kind, Bool)] = [
            (.user, false),
            (.multi, true),
            (.custom("multi"), true),
            (.custom("org"), false)
        ]

        for (kind, isMulti) in options {
            XCTAssertEqual(kind.isMulti(), isMulti)
        }
    }

    func testKindCorrectlyIdentifiesAsUser() {
        let options: [(Kind, Bool)] = [
            (.user, true),
            (.multi, false),
            (.custom(""), true),
            (.custom("user"), true),
            (.custom("org"), false)
        ]

        for (kind, isUser) in options {
            XCTAssertEqual(kind.isUser(), isUser)
        }
    }

    func testKindBuildsFromStringCorrectly() {
        XCTAssertNil(Kind("kind"))
        XCTAssertNil(Kind("no spaces allowed"))
        XCTAssertNil(Kind("#invalidcharactersarefun"))

        XCTAssertEqual(Kind(""), .user)
        XCTAssertEqual(Kind("user"), .user)
        XCTAssertEqual(Kind("User"), .custom("User"))

        XCTAssertEqual(Kind("multi"), .multi)
        XCTAssertEqual(Kind("org"), .custom("org"))
    }

    func testKindCanEncodeAndDecodeAppropriately() throws {
        // I know it seems silly to have these test cases be arrays instead of
        // simple strings. However, if I can please kindly direct your
        // attention to https://github.com/apple/swift-corelibs-foundation/issues/4402
        // you will see that older versions had an issue encoding and decoding JSON
        // fragments like simple strings.
        //
        // Using an array like this is a simple but effective workaround.
        let testCases = [
            ("[\"user\"]", Kind("user"), true, false),
            ("[\"multi\"]", Kind("multi"), false, true),
            ("[\"org\"]", Kind("org"), false, false)
        ]

        for (json, expectedKind, isUser, isMulti) in testCases {
            let kindJson = Data(json.utf8)
            let kinds = try JSONDecoder().decode([Kind].self, from: kindJson)

            XCTAssertEqual(expectedKind, kinds[0])
            XCTAssertEqual(isUser, kinds[0].isUser())
            XCTAssertEqual(isMulti, kinds[0].isMulti())

            try XCTAssertEqual(kindJson, JSONEncoder().encode(kinds))
        }
    }
}
