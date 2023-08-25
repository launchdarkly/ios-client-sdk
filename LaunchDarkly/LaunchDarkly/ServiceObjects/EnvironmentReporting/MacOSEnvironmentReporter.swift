#if os(OSX)
import Foundation
import AppKit

class MacOSEnvironmentReporter: EnvironmentReporterChainBase {
  override var applicationInfo: ApplicationInfo {
    var info = ApplicationInfo()
    info.applicationIdentifier(Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String)
    info.applicationVersion(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
    info.applicationName(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
    info.applicationVersionName(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)

    // defer to super if applicationId is missing.  This logic is after the setter since the setter has built in sanitization
    if info.applicationId == nil {
      info = super.applicationInfo
    }
    return info
  }

  override var deviceModel: String { Sysctl.modelWithoutVersion }
  override var systemVersion: String { ProcessInfo.processInfo.operatingSystemVersion.compactVersionString }
}

extension OperatingSystemVersion {
  var compactVersionString: String {
    "\(majorVersion).\(minorVersion).\(patchVersion)"
  }
}

extension Sysctl {
  static var modelWithoutVersion: String {
    // swiftlint:disable:next force_try
    let modelRegex = try! NSRegularExpression(pattern: "([A-Za-z]+)\\d{1,2},\\d")
    let model = Sysctl.model    // e.g. "MacPro4,1"
    return modelRegex.firstCaptureGroup(in: model, options: [], range: model.range) ?? "mac"
  }
}

private extension String {
  func substring(_ range: NSRange) -> String? {
    guard range.location >= 0 && range.location < self.count,
          range.location + range.length >= 0 && range.location + range.length < self.count
    else { return nil }
    let startIndex = index(self.startIndex, offsetBy: range.location)
    let endIndex = index(self.startIndex, offsetBy: range.length)
    return String(self[startIndex..<endIndex])
  }

  var range: NSRange {
    NSRange(location: 0, length: self.count)
  }
}

private extension NSRegularExpression {
  func firstCaptureGroup(in string: String, options: NSRegularExpression.MatchingOptions = [], range: NSRange) -> String? {
    guard let match = self.firstMatch(in: string, options: [], range: string.range),
          let group = string.substring(match.range(at: 1))
    else { return nil }
    return group
  }
}
#endif
