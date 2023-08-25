import Foundation

class ApplicationInfoEnvironmentReporter: EnvironmentReporterChainBase {
    private var info: ApplicationInfo

    public init(_ applicationInfo: ApplicationInfo) {
        self.info = applicationInfo
    }

    override var applicationInfo: ApplicationInfo {
        // defer to super if applicationId is missing.
        if info.applicationId == nil {
            info = super.applicationInfo
        }
        return info
    }
}
