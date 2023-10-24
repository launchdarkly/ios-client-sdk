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

    func testSha256base64UrlEncoding() throws {
        let input = "OhYeah?HashThis!!!" // hash is KzDwVRpvTuf//jfMK27M4OMpIRTecNcJoaffvAEi+as= and it has a + and a /
        let expectedOutput = "KzDwVRpvTuf__jfMK27M4OMpIRTecNcJoaffvAEi-as="
        let output = Util.sha256(input).base64UrlEncodedString
        XCTAssertEqual(output, expectedOutput)
    }
}
