import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(OSX)
import AppKit
#elseif os(watchOS)
import WatchKit
#endif

/// What differs between the platforms the SDK runs on, in one place, so that the code using it carries no platform
/// conditions of its own.
class SystemCapabilities {
    #if os(iOS)
    static var backgroundNotification: Notification.Name? { UIApplication.didEnterBackgroundNotification }
    static var foregroundNotification: Notification.Name? { UIApplication.willEnterForegroundNotification }
    static var suspendsWhenBackgrounded: Bool { true }
    static var expiringActivity: BackgroundActivity.ExpiringActivity? { performExpiringActivity }
    static var systemName: String { UIDevice.current.systemName }
    static var operatingSystem: OperatingSystem { .iOS }
    #elseif os(watchOS)
    /// None the SDK observes, so a watchOS client neither changes run mode nor does anything with its events on its way
    /// to the background, although the platform suspends it and has the assertions to deliver under.
    static var backgroundNotification: Notification.Name? { nil }
    static var foregroundNotification: Notification.Name? { nil }
    static var suspendsWhenBackgrounded: Bool { true }
    static var expiringActivity: BackgroundActivity.ExpiringActivity? { performExpiringActivity }
    static var systemName: String { WKInterfaceDevice.current().systemName }
    static var operatingSystem: OperatingSystem { .watchOS }
    #elseif os(OSX)
    /// Posted on every loss of focus, which suspends nothing.
    static var backgroundNotification: Notification.Name? { NSApplication.willResignActiveNotification }
    static var foregroundNotification: Notification.Name? { NSApplication.didBecomeActiveNotification }
    static var suspendsWhenBackgrounded: Bool { false }
    static var expiringActivity: BackgroundActivity.ExpiringActivity? { nil }
    static var systemName: String { "macOS" }
    static var operatingSystem: OperatingSystem { .macOS }
    #elseif os(tvOS)
    static var backgroundNotification: Notification.Name? { UIApplication.didEnterBackgroundNotification }
    static var foregroundNotification: Notification.Name? { UIApplication.willEnterForegroundNotification }
    static var suspendsWhenBackgrounded: Bool { true }
    static var expiringActivity: BackgroundActivity.ExpiringActivity? { performExpiringActivity }
    static var systemName: String { UIDevice.current.systemName }
    static var operatingSystem: OperatingSystem { .tvOS }
    #endif

    #if os(iOS) || os(tvOS) || os(watchOS)
    private static func performExpiringActivity(_ reason: String, _ whileGranted: @escaping (Bool) -> Void) {
        ProcessInfo.processInfo.performExpiringActivity(withReason: reason, using: whileGranted)
    }
    #endif
}
