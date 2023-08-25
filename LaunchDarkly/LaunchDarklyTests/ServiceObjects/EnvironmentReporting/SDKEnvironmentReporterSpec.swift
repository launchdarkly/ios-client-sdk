import Foundation
import XCTest

@testable import LaunchDarkly

final class SDKEnvironmentReporterSpec: XCTestCase {

    func testSdkEnvironmentReporter() {
        let reporter = SDKEnvironmentReporter()
        XCTAssertEqual(reporter.applicationInfo.applicationId, ReportingConsts.sdkName)
        XCTAssertEqual(reporter.applicationInfo.applicationName, ReportingConsts.sdkName)
        XCTAssertEqual(reporter.applicationInfo.applicationVersion, ReportingConsts.sdkVersion)
        XCTAssertEqual(reporter.applicationInfo.applicationVersionName, ReportingConsts.sdkVersion)
    }
}
