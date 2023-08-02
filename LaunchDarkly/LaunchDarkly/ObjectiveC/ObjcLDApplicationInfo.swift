import Foundation

/**
 Use LDApplicationInfo to define application metadata.

 These properties are optional and informational. They may be used in LaunchDarkly analytics or other product features.
 */
@objc(LDApplicationInfo)
public final class ObjcLDApplicationInfo: NSObject {
    internal var applicationInfo: ApplicationInfo

    @objc override public init() {
        applicationInfo = ApplicationInfo()
    }

    internal init(_ applicationInfo: ApplicationInfo?) {
        if let appInfo = applicationInfo {
            self.applicationInfo = appInfo
        } else {
            self.applicationInfo = ApplicationInfo()
        }
    }

    /// A unique identifier representing the application where the LaunchDarkly SDK is running.
    ///
    /// This can be specified as any string value as long as it only uses the following characters:
    /// ASCII letters, ASCII digits, period, hyphen, underscore. A string containing any other
    /// characters will be ignored.
    @objc public func applicationIdentifier(_ applicationId: String) {
        applicationInfo.applicationIdentifier(applicationId)
    }

    /// A human-friendly application name representing the application where the LaunchDarkly SDK is running.
    ///
    /// This can be specified as any string value as long as it only uses the following characters:
    /// ASCII letters, ASCII digits, period, hyphen, underscore. A string containing any other
    /// characters will be ignored.
    @objc public func applicationName(_ applicationName: String) {
        applicationInfo.applicationName(applicationName)
    }

    /// A unique identifier representing the version of the application where the LaunchDarkly SDK
    /// is running.
    ///
    /// This can be specified as any string value as long as it only uses the following characters:
    /// ASCII letters, ASCII digits, period, hyphen, underscore. A string containing any other
    /// characters will be ignored.
    @objc public func applicationVersion(_ applicationVersion: String) {
        applicationInfo.applicationVersion(applicationVersion)
    }

    /// A human-friendly name representing the version of the application where the LaunchDarkly SDK
    /// is running.
    ///
    /// This can be specified as any string value as long as it only uses the following characters:
    /// ASCII letters, ASCII digits, period, hyphen, underscore. A string containing any other
    /// characters will be ignored.
    @objc public func applicationVersionName(_ applicationVersionName: String) {
        applicationInfo.applicationVersionName(applicationVersionName)
    }
}
