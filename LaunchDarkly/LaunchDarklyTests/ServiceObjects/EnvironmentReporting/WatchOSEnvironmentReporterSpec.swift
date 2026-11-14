#if os(watchOS)
import Foundation
import WatchKit
import XCTest

@testable import LaunchDarkly

final class WatchOSEnvironmentReporterSpec: XCTestCase {
    func testDefaultReporterBehavior() {
        let chain = EnvironmentReporterChainBase()
        chain.setNext(WatchOSEnvironmentReporter())

        XCTAssertNotNil(chain.applicationInfo.applicationId)
        XCTAssertNotEqual(chain.deviceModel, "UNKNOWN")
        XCTAssertNotEqual(chain.systemVersion, "UNKNOWN")

        XCTAssertNil(chain.vendorUUID)
    }

    func testBuilderDoesNotIncludeWatchInfoWithoutExplicitOptIn() {
        let reporting = EnvironmentReporterBuilder().build()

        XCTAssertEqual(reporting.deviceModel, EnvironmentReporterChainBase().deviceModel)
    }

    func testEnsureBuilderUsesCorrectReporter() {
        let builder = EnvironmentReporterBuilder()
        builder.enableCollectionFromPlatform()

        let reporting = builder.build()

        XCTAssertEqual(reporting.deviceModel, WKInterfaceDevice.current().model)
    }
}
#endif
