import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#endif

class SDKEnvironmentReporter: EnvironmentReporterChainBase {
    override var applicationInfo: ApplicationInfo {
        var info = ApplicationInfo()
        info.applicationIdentifier(ReportingConsts.sdkName)
        info.applicationVersion(ReportingConsts.sdkVersion)
        info.applicationName(ReportingConsts.sdkName)
        info.applicationVersionName(ReportingConsts.sdkVersion)
        return info
    }

    override var isDebugBuild: Bool {
      #if DEBUG
      return true
      #else
      return false
      #endif
    }

    #if os(iOS)
    override var vendorUUID: String? { UIDevice.current.identifierForVendor?.uuidString }
    #elseif os(watchOS)
    override var vendorUUID: String? { nil }
    #elseif os(OSX)
    override var vendorUUID: String? { nil }
    #elseif os(tvOS)
    override var vendorUUID: String? { UIDevice.current.identifierForVendor?.uuidString }
    #endif
}
