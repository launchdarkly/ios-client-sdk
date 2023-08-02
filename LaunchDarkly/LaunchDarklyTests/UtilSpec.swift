import Foundation
import XCTest

@testable import LaunchDarkly

final class UtilSpec: XCTestCase {

    func testSha256base64() throws {
        let input = "hashThis!"
        let expectedOutput = "sfXg3HewbCAVNQLJzPZhnFKntWYvN0nAYyUWFGy24dQ="
        let output = Util.sha256base64(input)
        XCTAssertEqual(output, expectedOutput)
    }
}
