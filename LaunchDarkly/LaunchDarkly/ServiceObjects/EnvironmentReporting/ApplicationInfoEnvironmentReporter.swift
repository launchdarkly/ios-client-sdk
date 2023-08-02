import Foundation

class ApplicationInfoEnvironmentReporter: EnvironmentReporterChainBase {
    private var info: ApplicationInfo

    public init(_ applicationInfo: ApplicationInfo) {
        self.info = applicationInfo
    }

    override var applicationInfo: ApplicationInfo { return info }
}
