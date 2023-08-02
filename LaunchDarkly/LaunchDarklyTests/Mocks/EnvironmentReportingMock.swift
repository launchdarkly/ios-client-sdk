import Foundation

@testable import LaunchDarkly

extension EnvironmentReportingMock {
    struct Constants {
        static let applicationInfo = LaunchDarkly.ApplicationInfo()
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
