import Foundation
import XCTest

@testable import LaunchDarkly

final class ApplicationInfoEnvironmentReporterSpec: XCTestCase {

    func testApplicationInfoReporterSpec() {
        var applicationInfo = ApplicationInfo()
        applicationInfo.applicationIdentifier("example-id")
        applicationInfo.applicationName("example-name")
        applicationInfo.applicationVersion("example-version")
        applicationInfo.applicationVersionName("example-version-name")

        let chain = EnvironmentReporterChainBase()
        chain.setNext(ApplicationInfoEnvironmentReporter(applicationInfo))

        XCTAssertEqual(chain.applicationInfo, applicationInfo)
    }

    func testFallbackWhenIDMissing() {
        var applicationInfo = ApplicationInfo()
        applicationInfo.applicationVersion("example-version") // setting only version triggers fallback
        let reporter = ApplicationInfoEnvironmentReporter(applicationInfo)
        let output = reporter.applicationInfo
        XCTAssertNotNil(output.applicationId)
        XCTAssertNotNil(output.applicationName)
        XCTAssertNotNil(output.applicationVersion)
        XCTAssertNotNil(output.applicationVersionName)
    }
}
