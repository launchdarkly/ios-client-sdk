import Foundation

class EnvironmentReporterChainBase: EnvironmentReporting {

    private static let UNKNOWN: String = "unknown"

    // the next reporter in the chain if there is one
    private var next: EnvironmentReporterChainBase?

    public func setNext(_ next: EnvironmentReporterChainBase) {
        self.next = next
    }

    var applicationInfo: ApplicationInfo {
        if let n = next {
            return n.applicationInfo
        }

        var info = ApplicationInfo()
        info.applicationIdentifier(EnvironmentReporterChainBase.UNKNOWN)
        info.applicationVersion(EnvironmentReporterChainBase.UNKNOWN)
        info.applicationName(EnvironmentReporterChainBase.UNKNOWN)
        info.applicationVersionName(EnvironmentReporterChainBase.UNKNOWN)

        return info
    }

    var isDebugBuild: Bool { next?.isDebugBuild ?? false }
    var deviceModel: String { next?.deviceModel ?? EnvironmentReporterChainBase.UNKNOWN }
    var systemVersion: String { next?.systemVersion ?? EnvironmentReporterChainBase.UNKNOWN }

    var vendorUUID: String? { next?.vendorUUID }

    var manufacturer: String { next?.manufacturer ?? "Apple"  }
    var locale: String { next?.locale ?? Locale.autoupdatingCurrent.identifier }
    var osFamily: String { next?.osFamily ?? "Apple"  }
}
