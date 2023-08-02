import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(OSX)
import AppKit
#elseif os(watchOS)
import WatchKit
#endif

class SystemCapabilities {
    #if os(iOS)
    static var backgroundNotification: Notification.Name? { UIApplication.didEnterBackgroundNotification }
    static var foregroundNotification: Notification.Name? { UIApplication.willEnterForegroundNotification }
    static var systemName: String { UIDevice.current.systemName }
    static var operatingSystem: OperatingSystem { .iOS }
    #elseif os(watchOS)
    static var backgroundNotification: Notification.Name? { nil }
    static var foregroundNotification: Notification.Name? { nil }
    static var systemName: String { WKInterfaceDevice.current().systemName }
    static var operatingSystem: OperatingSystem { .watchOS }
    #elseif os(OSX)
    static var backgroundNotification: Notification.Name? { NSApplication.willResignActiveNotification }
    static var foregroundNotification: Notification.Name? { NSApplication.didBecomeActiveNotification }
    static var systemName: String { "macOS" }
    static var operatingSystem: OperatingSystem { .macOS }
    #elseif os(tvOS)
    static var backgroundNotification: Notification.Name? { UIApplication.didEnterBackgroundNotification }
    static var foregroundNotification: Notification.Name? { UIApplication.willEnterForegroundNotification }
    static var systemName: String { UIDevice.current.systemName }
    static var operatingSystem: OperatingSystem { .tvOS }
    #endif
}
