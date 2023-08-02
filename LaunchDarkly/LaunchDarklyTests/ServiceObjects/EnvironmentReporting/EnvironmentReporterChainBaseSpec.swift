import Foundation
import XCTest

@testable import LaunchDarkly

final class EnvironmentReporterChainBaseSpec: XCTest {

    func testEmptyChainBase() {
        let chain = EnvironmentReporterChainBase()
        let appInfo = chain.applicationInfo

        XCTAssertEqual(appInfo.applicationId, "UNKNOWN")
        XCTAssertEqual(appInfo.applicationName, "UNKNOWN")
        XCTAssertEqual(appInfo.applicationVersion, "UNKNOWN")
        XCTAssertEqual(appInfo.applicationVersionName, "UNKNOWN")

        XCTAssertFalse(chain.isDebugBuild)

        XCTAssertEqual(chain.deviceModel, "UNKNOWN")
        XCTAssertEqual(chain.systemVersion, "UNKNOWN")
        XCTAssertNil(chain.vendorUUID)

        XCTAssertEqual(chain.manufacturer, "Apple")
        XCTAssertEqual(chain.osFamily, "Apple")
    }
}
