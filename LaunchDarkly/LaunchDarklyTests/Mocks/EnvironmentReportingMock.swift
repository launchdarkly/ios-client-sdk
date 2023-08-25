import Foundation

@testable import LaunchDarkly

extension EnvironmentReportingMock {
    struct Constants {
        static let applicationInfo: ApplicationInfo = {
            var applicationInfo = LaunchDarkly.ApplicationInfo()
            applicationInfo.applicationIdentifier("idStub")
            applicationInfo.applicationVersion("versionStub")
            applicationInfo.applicationName("nameStub")
            applicationInfo.applicationVersionName("versionNameStub")
            return applicationInfo
        }()
        static let deviceModel = "deviceModelStub"
        static let systemVersion = "systemVersionStub"
        static let systemName = "systemNameStub"
        static let vendorUUID = "vendorUUIDStub"
        static let sdkVersion = "sdkVersionStub"
        static let manufacturer = "manufacturerStub"
        static let locale = "localeStub"
        static let osFamily = "osFamilyStub"
    }
}
