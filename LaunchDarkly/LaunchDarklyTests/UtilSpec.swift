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

    func testHashedStorageNameHoldsNeitherTheKeyNorTheBundle() {
        let name = Util.hashedStorageName(mobileKey: "mob-12345", bundleId: "com.example.app")
        XCTAssertEqual(name, "ikZOBb8DevJDIgDIaHRV_NHgqATWnIow0p2ln1hKx38=.Ok8Us_66OLNirYC1BCOPqkKiYvc6EGiBRMypMw5GdTQ=")
        XCTAssertFalse(name.contains("mob-12345"))
        XCTAssertFalse(name.contains("com.example.app"))
        XCTAssertFalse(name.contains("/"))
    }

    func testHashedStorageNameWithoutABundle() {
        XCTAssertEqual(Util.hashedStorageName(mobileKey: "mob-12345", bundleId: nil), "Ok8Us_66OLNirYC1BCOPqkKiYvc6EGiBRMypMw5GdTQ=")
    }
}
