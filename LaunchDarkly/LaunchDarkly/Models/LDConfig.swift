import Foundation
import OSLog

/// Defines the connection modes the SDK may be configured to use to retrieve feature flag data from LaunchDarkly.
public enum LDStreamingMode {
    /**
     In streaming mode, the SDK uses a streaming connection to receive feature flag data from LaunchDarkly. When a flag
     is updated in the dashboard, the stream notifies the SDK of changes to the evaluation result for the current context.

     Streaming mode is not available on watchOS. On iOS and tvOS, the client app must be running in the foreground to
     use a streaming connection. If streaming mode is not available, the SDK reverts to polling mode.
     */
    case streaming
    /**
     In polling mode, the SDK requests feature flag data from the LaunchDarkly service at regular intervals defined in
     the `LDConfig`. When a flag is updated in the dashboard, the SDK will not show the change until the next time the
     it requests the feature flag data.
     */
    case polling
}

/**
 Enable / disable options for Auto Environment Attributes functionality. When enabled, the SDK will automatically
 provide data about the mobile environment where the application is running. This data makes it simpler to target
 your mobile customers based on application name or version, or on device characteristics including manufacturer,
 model, operating system, locale, and so on. We recommend enabling this when you configure the SDK. To learn more,
 read [Automatic environment attributes](https://docs.launchdarkly.com/sdk/features/environment-attributes).

 For example, consider a “dark mode” feature being added to an app. Versions 10 through 14 contain early,
 incomplete versions of the feature. These versions are available to all customers, but the “dark mode” feature is only
 enabled for testers.  With version 15, the feature is considered complete. With Auto Environment Attributes enabled,
 you can use targeting rules to enable "dark mode" for all customers who are using version 15 or greater, and ensure
 that customers on previous versions don't use the earlier, unfinished version of the feature.
 */
@objc public enum AutoEnvAttributes: Int {
    /// Enables the Auto EnvironmentAttributes functionality.
    case enabled
    /// Disables the Auto EnvironmentAttributes functionality.
    case disabled
}

typealias MobileKey = String

/**
 A callback for dynamically setting http headers when connection & reconnecting to a stream
 or on every poll request. This function should return a copy of the headers received with
 any modifications or additions needed. Removing headers is discouraged as it may cause
 requests to fail.

 - parameter url: The endpoint that is being connected to
 - parameter headers: The default headers that would be used
 - returns: The headers that will be used in the request
 */
public typealias RequestHeaderTransform = (_ url: URL, _ headers: [String: String]) -> [String: String]

/// Defines application metadata.
///
/// These properties are optional and informational. They may be used in LaunchDarkly
/// analytics or other product features.
public struct ApplicationInfo: Equatable {
    internal var applicationId: String?
    internal var applicationName: String?
    internal var applicationVersion: String?
    internal var applicationVersionName: String?

    public init() {}

    /// A unique identifier representing the application where the LaunchDarkly SDK is running.
    ///
    /// This can be specified as any string value as long as it only uses the following characters:
    /// ASCII letters, ASCII digits, period, hyphen, underscore. A string containing any other
    /// characters will be ignored.
    public mutating func applicationIdentifier(_ applicationId: String?) {
        validateThenCall(inputName: "applicationId", input: applicationId) {
            self.applicationId = $0
        }
    }

    /// A human-friendly application name representing the application where the LaunchDarkly SDK is running.
    ///
    /// This can be specified as any string value as long as it only uses the following characters:
    /// ASCII letters, ASCII digits, period, hyphen, underscore. A string containing any other
    /// characters will be ignored.
    public mutating func applicationName(_ applicationName: String?) {
        validateThenCall(inputName: "applicationName", input: applicationName) {
            self.applicationName = $0
        }
    }

    /// A unique identifier representing the version of the application where the LaunchDarkly SDK
    /// is running.
    ///
    /// This can be specified as any string value as long as it only uses the following characters:
    /// ASCII letters, ASCII digits, period, hyphen, underscore. A string containing any other
    /// characters will be ignored.
    public mutating func applicationVersion(_ applicationVersion: String?) {
        validateThenCall(inputName: "applicationVersion", input: applicationVersion) {
            self.applicationVersion = $0
        }
    }

    /// A human-friendly name representing the version of the application where the LaunchDarkly SDK
    /// is running.
    ///
    /// This can be specified as any string value as long as it only uses the following characters:
    /// ASCII letters, ASCII digits, period, hyphen, underscore. A string containing any other
    /// characters will be ignored.
    public mutating func applicationVersionName(_ applicationVersionName: String?) {
        validateThenCall(inputName: "applicationVersionName", input: applicationVersionName) {
            self.applicationVersionName = $0
        }
    }

    func buildTag() -> String {
        var tags: [String] = []

        if let applicationId = applicationId {
            tags.append("application-id/\(applicationId)")
        }

        if let applicationName = applicationName {
            tags.append("application-name/\(applicationName)")
        }

        if let applicationVersion = applicationVersion {
            tags.append("application-version/\(applicationVersion)")
        }

        if let applicationVersionName = applicationVersionName {
            tags.append("application-version-name/\(applicationVersionName)")
        }

        return tags.lazy.joined(separator: " ")
    }

    /**
     If after sanitization the input is valid, invokes the closure with the sanitized input.  A null input is valid to permit nilling
     out a property.  Otherwise does not invoke the closure.
     */
    private func validateThenCall(inputName: String, input: String?, onSuccess: (String?) -> Void) {
        // nil input is permitted to clear the property
        guard let unwrapped = input else {
            onSuccess(input)
            return
        }

        let sanitized = unwrapped.replacingOccurrences(of: " ", with: "-")
        if validate(sanitized) != nil {
            return
        }

        onSuccess(sanitized)
    }

    /**
     Validates the provided string.
     - returns: nil if valid, otherwise string describing issue
     */
    private func validate(_ input: String) -> String? {
        if input.isEmpty {
            return "empty string and was discarded"
        }

        if input.count > 64 {
            return "longer than 64 characters and was discarded"
        }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        if input.rangeOfCharacter(from: allowed.inverted) != nil {
            return "contained invalid characters"
        }

        return nil
    }
}

/**
 Use LDConfig to configure the LDClient. When initialized, a LDConfig contains the default values which can be changed as needed.
 */
public struct LDConfig {

    /// The default values set when a LDConfig is initialized
    struct Defaults {
        /// The default base url for making feature flag requests
        static let baseUrl = URL(string: "https://app.launchdarkly.com")!
        /// The default base url for making event reports
        static let eventsUrl = URL(string: "https://mobile.launchdarkly.com")!
        /// The default base url for connecting to streaming service
        static let streamUrl = URL(string: "https://clientstream.launchdarkly.com")!

        /// The default behavior for the SDK is to send events.
        static let sendEvents = true

        /// The default maximum number of events the LDClient can store
        static let eventCapacity = 100

        /// The default timeout interval for flag requests and event reports. (10 seconds)
        static let connectionTimeout: TimeInterval = 10.0
        /// The default time interval between event reports. (30 seconds)
        static let eventFlushInterval: TimeInterval = 30.0
        /// The default time interval between feature flag requests. Used only for polling mode. (5 minutes)
        static let flagPollingInterval: TimeInterval = 300.0
        /// The default interval between feature flag requests while running in the background. Used only for polling mode. (60 minutes)
        static let backgroundFlagPollingInterval: TimeInterval = 3600.0

        /// The default streaming mode (.streaming)
        static let streamingMode = LDStreamingMode.streaming
        /// The default mode for enabling background flag requests. (false)
        static let enableBackgroundUpdates = false
        /// The default mode to set LDClient online on a start call. (true)
        static let startOnline = true

        /// The default setting for private context attributes. (false)
        static let allContextAttributesPrivate = false
        /// The default private context attribute list (nil)
        static let privateContextAttributes: [Reference] = []

        /// The default HTTP request method for stream connections and feature flag requests. When true, these requests will use the non-standard verb `REPORT`. When false, these requests will use the standard verb `GET`. (false)
        static let useReport = false

        /// The default setting controlling information logged to the console, and modifying some setting ranges to facilitate debugging. (false)
        static let debugMode = false

        /// The default setting for whether we request evaluation reasons for all flags. (false)
        static let evaluationReasons = false

        /// The default setting for the maximum number of locally cached contexts. (5)
        static let maxCachedContexts = 5

        /// The default setting for whether sending diagnostic data is disabled. (false)
        static let diagnosticOptOut = false

        /// The default time interval between sending periodic diagnostic data. (15 minutes)
        static let diagnosticRecordingInterval: TimeInterval = 900.0

        /// The default wrapper name. (nil)
        static let wrapperName: String? = nil

        /// The default wrapper version. (nil)
        static let wrapperVersion: String? = nil

        /// The default secondary mobile keys. ([:])
        static let secondaryMobileKeys: [String: String] = [:]

        /// The default additional headers that should be added to all HTTP requests from SDK components to LaunchDarkly services
        static let additionalHeaders: [String: String] = [:]

        /// a closure to allow dynamic changes of headers on connect & reconnect
        static let headerDelegate: RequestHeaderTransform? = nil

        /// The default behavior for environment attributes is to not modify any provided context UNLESS the developer specifically opts-in.
        static let autoEnvAttributes: Bool = false

        static let hooks: [Hook] = []

        /// The default logger for the SDK. Can be overridden to provide customization.
        static let logger: OSLog = OSLog(subsystem: "com.launchdarkly", category: "ios-client-sdk")

        /// The default behavior for event payload compression.
        static let enableCompression: Bool = false
    }

    /// Constants relevant to setting up an `LDConfig`
    public struct Constants {
        /// The default environment name that must be present in a single or multiple environment configuration
        public static let primaryEnvironmentName = "default"
    }

    /// The minimum values allowed to be set into LDConfig.
    public struct Minima {

        // swiftlint:disable:next nesting
        struct Production {
            static let flagPollingInterval: TimeInterval = 300.0
            static let backgroundFlagPollingInterval: TimeInterval = 900.0
            static let diagnosticRecordingInterval: TimeInterval = 300.0
        }

        // swiftlint:disable:next nesting
        struct Debug {
            static let flagPollingInterval: TimeInterval = 30.0
            static let backgroundFlagPollingInterval: TimeInterval = 60.0
            static let diagnosticRecordingInterval: TimeInterval = 60.0
        }

        /// The minimum time interval between feature flag requests. Used only for polling mode. (5 minutes)
        public let flagPollingInterval: TimeInterval
        /// The minimum time interval between feature flag requests while running in the background. Used only for polling mode. (15 minutes)
        public let backgroundFlagPollingInterval: TimeInterval
        /// The minimum time interval between sending periodic diagnostic data. (5 minutes)
        public let diagnosticRecordingInterval: TimeInterval

        init(isDebugBuild: Bool = false) {
            let isDebug = isDebugBuild
            self.flagPollingInterval = isDebug ? Debug.flagPollingInterval : Production.flagPollingInterval
            self.backgroundFlagPollingInterval = isDebug ? Debug.backgroundFlagPollingInterval : Production.backgroundFlagPollingInterval
            self.diagnosticRecordingInterval = isDebug ? Debug.diagnosticRecordingInterval : Production.diagnosticRecordingInterval
        }
    }

    /// The Mobile key from your [LaunchDarkly Account](app.launchdarkly.com) settings (on the left at the bottom). If you have multiple projects be sure to choose the correct Mobile key.
    public var mobileKey: String

    /// The base url for making feature flag requests. Do not change unless instructed by LaunchDarkly.
    public var baseUrl: URL = Defaults.baseUrl
    /// The base url for making event reports. Do not change unless instructed by LaunchDarkly.
    public var eventsUrl: URL = Defaults.eventsUrl
    /// The base url for connecting to the streaming service. Do not change unless instructed by LaunchDarkly.
    public var streamUrl: URL = Defaults.streamUrl

    /// Whether to send events back to LaunchDarkly. This differs from {#offline?} in that it affects
    /// only the sending of client-side events, not streaming or polling for events from the server.
    public var sendEvents: Bool = Defaults.sendEvents

    /// The maximum number of analytics events the LDClient can store. When the LDClient event store reaches the eventCapacity, the SDK discards events until it successfully reports them to LaunchDarkly. (Default: 100)
    public var eventCapacity: Int = Defaults.eventCapacity

    /// The timeout interval for flag requests and event reports. (Default: 10 seconds)
    public var connectionTimeout: TimeInterval = Defaults.connectionTimeout
    /// The time interval between event reports (Default: 30 seconds)
    public var eventFlushInterval: TimeInterval = Defaults.eventFlushInterval
    /// The time interval between feature flag requests. Used only for polling mode. (Default: 5 minutes)
    public var flagPollingInterval: TimeInterval = Defaults.flagPollingInterval
    /// The time interval between feature flag requests while running in the background. Used only for polling mode. (Default: 60 minutes)
    public var backgroundFlagPollingInterval: TimeInterval = Defaults.backgroundFlagPollingInterval
    /// The configuration for application metadata.
    public var applicationInfo: ApplicationInfo?

    /**
     Controls the method the SDK uses to keep feature flags updated. (Default: `.streaming`)

     See `LDStreamingMode` for more details.
     */
    public var streamingMode: LDStreamingMode = Defaults.streamingMode
    /// Indicates whether streaming mode is allowed for the operating system
    private(set) var allowStreamingMode: Bool

    private var enableBgUpdates: Bool = Defaults.enableBackgroundUpdates
    /// Enables feature flag updates when your app is in the background. Allowed on macOS only. (Default: false)
    public var enableBackgroundUpdates: Bool {
        get {
            enableBgUpdates
        }
        set {
            enableBgUpdates = newValue && allowBackgroundUpdates
        }
    }
    private var allowBackgroundUpdates: Bool

    /// Controls LDClient start behavior. When true, calling start causes LDClient to go online. When false, calling start causes LDClient to remain offline. If offline at start, set the client online to receive flag updates. (Default: true)
    public var startOnline: Bool = Defaults.startOnline

    /**
     Treat all context attributes as private for event reporting for all contexts.

     The SDK will not include private attribute values in analytics events, but private attribute names will be sent.

     When true, ignores values in either LDConfig.privateContextAttributes or LDContext.privateAttributes. (Default: false)

     See Also: `privateContextAttributes` and `LDContext.privateAttributes`
    */
    public var allContextAttributesPrivate: Bool = Defaults.allContextAttributesPrivate
    /**
     Context attributes and top level custom dictionary keys to treat as private for event reporting for all contexts.

     The SDK will not include private attribute values in analytics events, but private attribute names will be sent.

     To set private context attributes for a specific context, see `LDContext.privateAttributes`. (Default: nil)

     See Also: `allContextAttributesPrivate` and `LDContext.privateAttributes`.
    */
    public var privateContextAttributes: [Reference] = Defaults.privateContextAttributes

    /**
     Directs the SDK to use REPORT for HTTP requests for feature flag data. (Default: `false`)

     This setting applies both to requests to the streaming service, as well as flag requests when the SDK is in polling
     mode. When false the SDK uses GET for these requests. Do not use unless advised by LaunchDarkly.
    */
    public var useReport: Bool = Defaults.useReport
    private static let flagRetryStatusCodes = [HTTPURLResponse.StatusCodes.methodNotAllowed, HTTPURLResponse.StatusCodes.badRequest, HTTPURLResponse.StatusCodes.notImplemented]

    /// Enables logging for debugging. (Default: false)
    public var isDebugMode: Bool = Defaults.debugMode

    /// Used by the contract tests to override the default 5 minute polling interval. This should never be used outside
    /// of the contract tests.
    internal var ignorePollingMinimum: Bool = false

    /// Enables requesting evaluation reasons for all flags. (Default: false)
    public var evaluationReasons: Bool = Defaults.evaluationReasons

    /// An Integer that tells ContextEnvironmentFlagCache the maximum number of contexts to locally cache. Can be set to -1 for unlimited cached contexts.
    public var maxCachedContexts: Int = Defaults.maxCachedContexts

    /**
     Set to true to opt out of sending diagnostic data. (Default: false)

     Unless the diagnosticOptOut field is set to true, the client will send some diagnostics data to the LaunchDarkly servers in order to assist in the development of future SDK improvements. These diagnostics consist of an initial payload containing some details of the SDK in use, the SDK's configuration, and the platform the SDK is being run on; as well as payloads sent periodically with information on irregular occurrences such as dropped events.
     */
    public var diagnosticOptOut: Bool = Defaults.diagnosticOptOut

    private var _diagnosticRecordingInterval: TimeInterval = Defaults.diagnosticRecordingInterval
    /// The interval between sending periodic diagnostic data. (Default: 15 minutes)
    public var diagnosticRecordingInterval: TimeInterval {
        get { _diagnosticRecordingInterval }
        set {
            _diagnosticRecordingInterval = max(minima.diagnosticRecordingInterval, newValue)
        }
    }

    /// For use by wrapper libraries to set an identifying name for the wrapper being used. This will be sent in the "X-LaunchDarkly-Wrapper" header on requests to the LaunchDarkly servers to allow recording metrics on the usage of wrapper libraries. (Default: nil)
    public var wrapperName: String? = Defaults.wrapperName

    /// For use by wrapper libraries to report the version of the library in use. If the `wrapperName` has not been set this field will be ignored. Otherwise the version string will be included with the `wrapperName` in the "X-LaunchDarkly-Wrapper" header on requests to the LaunchDarkly servers. (Default: nil)
    public var wrapperVersion: String? = Defaults.wrapperVersion

    /// Additional headers that should be added to all HTTP requests from SDK components to LaunchDarkly services
    public var additionalHeaders: [String: String] = [:]

    /// Should the event payload sent to LaunchDarkly use gzip compression. By default this is false to prevent backward breaking compatibility issues with older versions of the relay proxy.
    ///
    /// Customers not using the relay proxy are strongly encouraged to enable this feature to reduce egress bandwidth cost.
    public var enableCompression: Bool = Defaults.enableCompression

    /* TODO: find a way to make delegates equatable */
    /// a closure to allow dynamic changes of headers on connect & reconnect
    public var headerDelegate: RequestHeaderTransform?

    /// Set to true to opt in to automatically sending mobile environment attributes.  This data makes it simpler to target mobile customers
    /// based on application name or version, or on device characteristics including manufacturer, model, operating system, locale, and so on.
    public var autoEnvAttributes: Bool = Defaults.autoEnvAttributes

    /// Configure the logger that will be used by the rest of the SDK.
    public var logger: OSLog = Defaults.logger

    /// LaunchDarkly defined minima for selected configurable items
    public let minima: Minima

    /// An NSObject wrapper for the Swift LDConfig struct. Intended for use in mixed apps when Swift code needs to pass a config into an Objective-C method.
    public var objcLdConfig: ObjcLDConfig { ObjcLDConfig(self) }

    /// Initial set of hooks for the client.
    ///
    /// Hooks provide entry points which allow for observation of SDK functions.
    public var hooks: [Hook] = Defaults.hooks

    /// A Dictionary of identifying names to unique mobile keys for all environments
    private var mobileKeys: [String: String] {
        var internalMobileKeys = getSecondaryMobileKeys()
        internalMobileKeys[LDConfig.Constants.primaryEnvironmentName] = mobileKey
        return internalMobileKeys
    }

    /**
     Sets a Dictionary of identifying names to unique mobile keys to access secondary environments in the LDConfig. Throws `LDInvalidArgumentError` if you try to add duplicate keys or put the primary key or name in secondaryMobileKeys.

     - parameter newSecondaryMobileKeys: A Dictionary of String to String.
     */
    public mutating func setSecondaryMobileKeys(_ newSecondaryMobileKeys: [String: String]) throws {
        let mobileKeyPresentInSecondaryMobileKeys = newSecondaryMobileKeys.values.contains(mobileKey)
        let primaryEnvironmentNamePresentInSecondaryMobileKeys = newSecondaryMobileKeys.keys.contains(LDConfig.Constants.primaryEnvironmentName)
        let mobileKeysUsedOnlyOnce = Set(newSecondaryMobileKeys.values)
        if mobileKeyPresentInSecondaryMobileKeys {
            throw(LDInvalidArgumentError("The primary environment key cannot be in the secondary mobile keys."))
        }
        if primaryEnvironmentNamePresentInSecondaryMobileKeys {
            throw(LDInvalidArgumentError("The primary environment name is not a valid key."))
        }
        if mobileKeysUsedOnlyOnce.count != newSecondaryMobileKeys.count {
            throw(LDInvalidArgumentError("A key can only be used once."))
        }

        _secondaryMobileKeys = newSecondaryMobileKeys
    }

    /**
     Returns a Dictionary of identifying names to unique mobile keys to access secondary environments.

     - returns: A Dictionary of String to String.
     */
    public func getSecondaryMobileKeys() -> [String: String] {
        return _secondaryMobileKeys
    }

    /// Internal variable for secondaryMobileKeys computed property
    private var _secondaryMobileKeys: [String: String]

    // Internal constructor to enable automated testing
    init(mobileKey: String, autoEnvAttributes: AutoEnvAttributes, isDebugBuild: Bool) {
        self.mobileKey = mobileKey
        self.autoEnvAttributes = (autoEnvAttributes == .enabled) // mapping API enum to bool
        minima = Minima(isDebugBuild: isDebugBuild)
        allowStreamingMode = SystemCapabilities.operatingSystem.isStreamingEnabled
        allowBackgroundUpdates = SystemCapabilities.operatingSystem.isBackgroundEnabled
        _secondaryMobileKeys = Defaults.secondaryMobileKeys
        if mobileKey.isEmpty {
            os_log("%s mobileKey is empty. The SDK will not operate correctly without a valid mobile key.", log: logger, type: .debug, typeName(and: #function))
        }
    }

    /**
     LDConfig constructor. Configurable values are all set to their default values. The client app can modify these values as desired.
     Note that client app developers may prefer to get the LDConfig from `LDClient.config` in order to retain previously set values.

     - Parameters:
     - mobileKey: The mobile key for the LaunchDarkly environment. This can be found on the LaunchDarkly dashboard once logged in.
     - autoEnvAttributes: Enable / disable Auto Environment Attributes functionality. When enabled, the SDK will automatically
     provide data about the mobile environment where the application is running. This data makes it simpler to target
     your mobile customers based on application name or version, or on device characteristics including manufacturer,
     model, operating system, locale, and so on. We recommend enabling this when you configure the SDK. To learn more,
     read [Automatic environment attributes](https://docs.launchdarkly.com/sdk/features/environment-attributes).
     for more documentation.
     */
    public init(mobileKey: String, autoEnvAttributes: AutoEnvAttributes) {
        self.init(mobileKey: mobileKey, autoEnvAttributes: autoEnvAttributes, isDebugBuild: false)
    }

    // Determine the effective flag polling interval based on runMode, configured foreground & background polling interval, and minimum foreground & background polling interval.
    func flagPollingInterval(runMode: LDClientRunMode) -> TimeInterval {
        if ignorePollingMinimum {
            return runMode == .foreground ? flagPollingInterval : backgroundFlagPollingInterval
        }

        return runMode == .foreground ? max(flagPollingInterval, minima.flagPollingInterval) : max(backgroundFlagPollingInterval, minima.backgroundFlagPollingInterval)
    }

    // Determines if the status code is a code that should cause the SDK to retry a failed HTTP Request that used the REPORT method. Retried requests will use the GET method.
    static func isReportRetryStatusCode(_ statusCode: Int) -> Bool {
        return LDConfig.flagRetryStatusCodes.contains(statusCode)
    }
}

extension LDConfig: Equatable {
    /// Compares the settable properties in 2 LDConfig structs
    public static func == (lhs: LDConfig, rhs: LDConfig) -> Bool {
        return lhs.mobileKey == rhs.mobileKey
            && lhs.baseUrl == rhs.baseUrl
            && lhs.eventsUrl == rhs.eventsUrl
            && lhs.streamUrl == rhs.streamUrl
            && lhs.eventCapacity == rhs.eventCapacity
            && lhs.sendEvents == rhs.sendEvents
            && lhs.connectionTimeout == rhs.connectionTimeout
            && lhs.eventFlushInterval == rhs.eventFlushInterval
            && lhs.flagPollingInterval == rhs.flagPollingInterval
            && lhs.backgroundFlagPollingInterval == rhs.backgroundFlagPollingInterval
            && lhs.applicationInfo == rhs.applicationInfo
            && lhs.streamingMode == rhs.streamingMode
            && lhs.enableBackgroundUpdates == rhs.enableBackgroundUpdates
            && lhs.startOnline == rhs.startOnline
            && lhs.allContextAttributesPrivate == rhs.allContextAttributesPrivate
            && Set(lhs.privateContextAttributes) == Set(rhs.privateContextAttributes)
            && lhs.useReport == rhs.useReport
            && lhs.isDebugMode == rhs.isDebugMode
            && lhs.evaluationReasons == rhs.evaluationReasons
            && lhs.maxCachedContexts == rhs.maxCachedContexts
            && lhs.diagnosticOptOut == rhs.diagnosticOptOut
            && lhs.diagnosticRecordingInterval == rhs.diagnosticRecordingInterval
            && lhs.wrapperName == rhs.wrapperName
            && lhs.wrapperVersion == rhs.wrapperVersion
            && lhs.additionalHeaders == rhs.additionalHeaders
            && lhs.autoEnvAttributes == rhs.autoEnvAttributes
    }
}

extension LDConfig: TypeIdentifying { }

#if DEBUG
    extension LDConfig {
        static let reportRetryStatusCodes = LDConfig.flagRetryStatusCodes
    }
#endif
