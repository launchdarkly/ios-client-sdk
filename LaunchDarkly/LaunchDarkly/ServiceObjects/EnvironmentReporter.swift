import Foundation

#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#elseif os(OSX)
import AppKit
#elseif os(tvOS)
import UIKit
#endif

enum OperatingSystem: String {
  case iOS, watchOS, macOS, tvOS, unknown

  static var allOperatingSystems: [OperatingSystem] {
    [.iOS, .watchOS, .macOS, .tvOS]
  }

  var isBackgroundEnabled: Bool {
    OperatingSystem.backgroundEnabledOperatingSystems.contains(self)
  }
  static var backgroundEnabledOperatingSystems: [OperatingSystem] {
    [.macOS]
  }

  var isStreamingEnabled: Bool {
    OperatingSystem.streamingEnabledOperatingSystems.contains(self)
  }
  static var streamingEnabledOperatingSystems: [OperatingSystem] {
    [.iOS, .macOS, .tvOS]
  }
}

// sourcery: autoMockable
protocol EnvironmentReporting {
    // sourcery: defaultMockValue = Constants.applicationInfo
    var applicationInfo: ApplicationInfo { get }
    // sourcery: defaultMockValue = true
    var isDebugBuild: Bool { get }
    // sourcery: defaultMockValue = Constants.deviceModel
    var deviceModel: String { get }
    // sourcery: defaultMockValue = Constants.systemVersion
    var systemVersion: String { get }
    // sourcery: defaultMockValue = Constants.vendorUUID
    var vendorUUID: String? { get }
    // sourcery: defaultMockValue = Constants.manufacturer
    var manufacturer: String { get }
    // sourcery: defaultMockValue = Constants.locale
    var locale: String { get }
    // sourcery: defaultMockValue = Constants.osFamily
    var osFamily: String { get }
}
