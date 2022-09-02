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
    case iOS, watchOS, macOS, tvOS

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
    // sourcery: defaultMockValue = true
    var isDebugBuild: Bool { get }
    // sourcery: defaultMockValue = Constants.deviceType
    var deviceType: String { get }
    // sourcery: defaultMockValue = Constants.deviceModel
    var deviceModel: String { get }
    // sourcery: defaultMockValue = Constants.systemVersion
    var systemVersion: String { get }
    // sourcery: defaultMockValue = Constants.systemName
    var systemName: String { get }
    // sourcery: defaultMockValue = .iOS
    var operatingSystem: OperatingSystem { get }
    // sourcery: defaultMockValue = EnvironmentReporter().backgroundNotification
    var backgroundNotification: Notification.Name? { get }
    // sourcery: defaultMockValue = EnvironmentReporter().foregroundNotification
    var foregroundNotification: Notification.Name? { get }
    // sourcery: defaultMockValue = Constants.vendorUUID
    var vendorUUID: String? { get }
    // sourcery: defaultMockValue = Constants.sdkVersion
    var sdkVersion: String { get }
    // sourcery: defaultMockValue = true
    var shouldThrottleOnlineCalls: Bool { get }
}

struct EnvironmentReporter: EnvironmentReporting {
    #if DEBUG
    var isDebugBuild: Bool { true }
    #else
    var isDebugBuild: Bool { false }
    #endif

    struct Constants {
        fileprivate static let simulatorModelIdentifier = "SIMULATOR_MODEL_IDENTIFIER"
    }

    var deviceModel: String {
        #if os(OSX)
        return Sysctl.model
        #else
        // Obtaining the device model from https://stackoverflow.com/questions/26028918/how-to-determine-the-current-iphone-device-model answer by Jens Schwarzer
        if let simulatorModelIdentifier = ProcessInfo().environment[Constants.simulatorModelIdentifier] {
            return simulatorModelIdentifier
        }
        // the physical device code here is not automatically testable. Manual testing on physical devices is required.
        var systemInfo = utsname()
        _ = uname(&systemInfo)
        guard let deviceModel = String(bytes: Data(bytes: &systemInfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)
        else {
            return deviceType
        }
        return deviceModel.trimmingCharacters(in: .controlCharacters)
        #endif
    }

    #if os(iOS)
    var deviceType: String { UIDevice.current.model }
    var systemVersion: String { UIDevice.current.systemVersion }
    var systemName: String { UIDevice.current.systemName }
    var operatingSystem: OperatingSystem { .iOS }
    var backgroundNotification: Notification.Name? { UIApplication.didEnterBackgroundNotification }
    var foregroundNotification: Notification.Name? { UIApplication.willEnterForegroundNotification }
    var vendorUUID: String? { UIDevice.current.identifierForVendor?.uuidString }
    #elseif os(watchOS)
    var deviceType: String { WKInterfaceDevice.current().model }
    var systemVersion: String { WKInterfaceDevice.current().systemVersion }
    var systemName: String { WKInterfaceDevice.current().systemName }
    var operatingSystem: OperatingSystem { .watchOS }
    var backgroundNotification: Notification.Name? { nil }
    var foregroundNotification: Notification.Name? { nil }
    var vendorUUID: String? { nil }
    #elseif os(OSX)
    var deviceType: String { Sysctl.modelWithoutVersion }
    var systemVersion: String { ProcessInfo.processInfo.operatingSystemVersion.compactVersionString }
    var systemName: String { "macOS" }
    var operatingSystem: OperatingSystem { .macOS }
    var backgroundNotification: Notification.Name? { NSApplication.willResignActiveNotification }
    var foregroundNotification: Notification.Name? { NSApplication.didBecomeActiveNotification }
    var vendorUUID: String? { nil }
    #elseif os(tvOS)
    var deviceType: String { UIDevice.current.model }
    var systemVersion: String { UIDevice.current.systemVersion }
    var systemName: String { UIDevice.current.systemName }
    var operatingSystem: OperatingSystem { .tvOS }
    var backgroundNotification: Notification.Name? { UIApplication.didEnterBackgroundNotification }
    var foregroundNotification: Notification.Name? { UIApplication.willEnterForegroundNotification }
    var vendorUUID: String? { UIDevice.current.identifierForVendor?.uuidString }
    #endif

    var shouldThrottleOnlineCalls: Bool { !isDebugBuild }
    let sdkVersion = "6.2.0"
    // Unfortunately, the following does not function in certain configurations, such as when included through SPM
//    var sdkVersion: String {
//        Bundle(for: LDClient.self).infoDictionary?["CFBundleShortVersionString"] as? String ?? "5.x"
//    }
}

#if os(OSX)
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
