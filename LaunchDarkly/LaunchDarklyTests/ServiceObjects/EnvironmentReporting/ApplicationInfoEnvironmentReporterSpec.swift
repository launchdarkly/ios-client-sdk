import Foundation
import XCTest

@testable import LaunchDarkly

final class ApplicationInfoEnvironmentReporterSpec: XCTest {

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
}
