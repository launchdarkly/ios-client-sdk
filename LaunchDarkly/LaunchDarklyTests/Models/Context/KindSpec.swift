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
}
