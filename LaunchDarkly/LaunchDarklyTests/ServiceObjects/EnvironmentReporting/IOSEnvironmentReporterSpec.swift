#if os(iOS)
import Foundation
import XCTest

@testable import LaunchDarkly

final class IOSEnvironmentReporterSpec: XCTest {

    func testIosEnvironmentReporter() {
        let chain = EnvironmentReporterChainBase()
        chain.setNext(IOSEnvironmentReporter())

        XCTAssertNotNil(chain.applicationInfo.applicationId)
        XCTAssertNotEqual(chain.deviceModel, "UNKNOWN")
        XCTAssertNotEqual(chain.systemVersion, "UNKNOWN")

        XCTAssertNil(chain.vendorUUID)
    }
}
#endif
