#if os(watchOS)
import Foundation
import XCTest

@testable import LaunchDarkly

final class WatchOSEnvironmentReporterSpec: XCTest {
    func testDefaultReporterBehavior() {
        let chain = EnvironmentReporterChainBase()
        chain.setNext(WatchOSEnvironmentReporter())

        XCTAssert(!chain.applicationInfo.isEmpty())
        XCTAssertNotEqual(chain.deviceModel, "UNKNOWN")
        XCTAssertNotEqual(chain.systemVersion, "UNKNOWN")
        XCTAssertNotEqual(chain.systemName, "UNKNOWN")

        XCTAssertEqual(chain.operatingSystem, .watchOS)

        XCTAssertNil(chain.vendorUUID)
    }

    func testBuilderDoesNotIncludeWatchInfoWithoutExplicitOptIn() {
        let builder = EnvironmentReporterBuilder()
        let reporting = builder.build()

        XCTAssertEqual(reporting.operatingSystem, .watchOS)
    }

    func testEnsureBuilderUsesCorrectReporter() {
        let builder = EnvironmentReporterBuilder()
        builder.enableCollectionFromPlatform()

        let reporting = builder.build()

        XCTAssertEqual(reporting.operatingSystem, .watchOS)
    }
}
#endif
