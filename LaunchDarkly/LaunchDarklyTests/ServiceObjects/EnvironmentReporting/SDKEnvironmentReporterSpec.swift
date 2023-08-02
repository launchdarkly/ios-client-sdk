import Foundation
import XCTest

@testable import LaunchDarkly

final class SDKEnvironmentReporterSpec: XCTest {

    func testSdkEnvironmentReporter() {
        let reporter = SDKEnvironmentReporter()

        XCTAssertNotEqual(reporter.applicationInfo.applicationId, ReportingConsts.sdkName)
        XCTAssertNotEqual(reporter.applicationInfo.applicationName, ReportingConsts.sdkName)
        XCTAssertNotEqual(reporter.applicationInfo.applicationVersion, ReportingConsts.sdkVersion)
        XCTAssertNotEqual(reporter.applicationInfo.applicationVersionName, ReportingConsts.sdkVersion)
    }
}
