import Foundation

/**
 Use LDConfig to configure the LDClient. When initialized, a LDConfig contains the default values which can be changed as needed.

 The client app can change the LDConfig by getting the `config` from LDClient (`ObjcLDClient`), adjusting the values, and setting it back into the LDClient (`ObjcLDClient`).
 */
@objc(LDConfig)
public final class ObjcLDConfig: NSObject {
    var config: LDConfig
    
    /// The Mobile key from your [LaunchDarkly Account](app.launchdarkly.com) settings (on the left at the bottom). If you have multiple projects be sure to choose the correct Mobile key.
    @objc public var mobileKey: String {
        get { config.mobileKey }
        set { config.mobileKey = newValue }
    }

    /// The url for making feature flag requests. Do not change unless instructed by LaunchDarkly.
    @objc public var baseUrl: URL {
        get { config.baseUrl }
        set { config.baseUrl = newValue }
    }
    /// The url for making event reports. Do not change unless instructed by LaunchDarkly.
    @objc public var eventsUrl: URL {
        get { config.eventsUrl }
        set { config.eventsUrl = newValue }
    }
    /// The url for connecting to the *clientstream*. Do not change unless instructed by LaunchDarkly.
    @objc public var streamUrl: URL {
        get { config.streamUrl }
        set { config.streamUrl = newValue }
    }

    /// The maximum number of analytics events the LDClient can store. When the LDClient event store reaches the eventCapacity, the SDK discards events until it successfully reports them to LaunchDarkly. (Default: 100)
    @objc public var eventCapacity: Int {
        get { config.eventCapacity }
        set { config.eventCapacity = newValue }
    }

    /// The timeout interval for flag requests and event reports. (Default: 10 seconds)
    @objc public var connectionTimeout: TimeInterval {
        get { config.connectionTimeout }
        set { config.connectionTimeout = newValue }
    }
    /// The time interval between event reports (Default: 30 seconds)
    @objc public var eventFlushInterval: TimeInterval {
        get { config.eventFlushInterval }
        set { config.eventFlushInterval = newValue }
    }
    /// The interval between feature flag requests. Used only for polling mode. (Default: 5 minutes)
    @objc public var flagPollingInterval: TimeInterval {
        get { config.flagPollingInterval }
        set { config.flagPollingInterval = newValue }
    }
    /// The interval between feature flag requests while running in the background. Used only for polling mode. (Default: 60 minutes)
    @objc public var backgroundFlagPollingInterval: TimeInterval {
        get { config.backgroundFlagPollingInterval }
        set { config.backgroundFlagPollingInterval = newValue }
    }

    /// The minimum interval between feature flag requests. Used only for polling mode. (5 minutes)
    @objc public var minFlagPollingInterval: TimeInterval {
        config.minima.flagPollingInterval
    }
    /// The minimum interval between feature flag requests while running in the background. Used only for polling mode. (15 minutes)
    @objc public var minBackgroundFlagPollInterval: TimeInterval {
        config.minima.backgroundFlagPollingInterval
    }

    /// Controls the method the SDK uses to keep feature flags updated. When set to .streaming, connects to `clientstream` which notifies the SDK of feature flag changes. When set to .polling, an efficient polling mechanism is used to periodically request feature flag values. Ignored for watchOS, which always uses .polling. See `LDStreamingMode` for more details. (Default: .streaming)
    @objc public var streamingMode: Bool {
        get { config.streamingMode == .streaming }
        set { config.streamingMode = newValue ? .streaming : .polling }
    }
    /// Enables feature flag updates when your app is in the background. Allowed on macOS only. (Default: NO)
    @objc public var enableBackgroundUpdates: Bool {
        get { config.enableBackgroundUpdates }
        set { config.enableBackgroundUpdates = newValue }
    }
    /// Controls LDClient start behavior. When YES, calling start causes LDClient to go online. When NO, calling start causes LDClient to remain offline. If offline at start, set the client online to receive flag updates. (Default: YES)
    @objc public var startOnline: Bool {
        get { config.startOnline }
        set { config.startOnline = newValue }
    }

    /**
     Treat all user attributes as private for event reporting for all users.

     The SDK will not include private attribute values in analytics events, but private attribute names will be sent.

     When YES, ignores values in either LDConfig.privateUserAttributes or LDUser.privateAttributes. (Default: NO)

     See Also: `privateUserAttributes` and `LDUser.privateAttributes` (`ObjcLDUser.privateAttributes`)
     */
    @objc public var allUserAttributesPrivate: Bool {
        get { config.allUserAttributesPrivate }
        set { config.allUserAttributesPrivate = newValue }
    }
    /**
     User attributes and top level custom dictionary keys to treat as private for event reporting for all users.

     The SDK will not include private attribute values in analytics events, but private attribute names will be sent.

     To set private user attributes for a specific user, see `LDUser.privateAttributes` (`ObjcLDUser.privateAttributes`). (Default: `[]`)

     See Also: `allUserAttributesPrivate` and `LDUser.privateAttributes` (`ObjcLDUser.privateAttributes`).
     */
    @objc public var privateUserAttributes: [String] {
        get { config.privateUserAttributes.map { $0.name } }
        set { config.privateUserAttributes = newValue.map { UserAttribute.forName($0) } }
    }

    /**
     Directs the SDK to use REPORT for HTTP requests to connect to `clientstream` and make feature flag requests. When NO the SDK uses GET for these requests. Do not use unless advised by LaunchDarkly. (Default: NO)
     */
    @objc public var useReport: Bool {
        get { config.useReport }
        set { config.useReport = newValue }
    }

    /**
     Controls how the SDK reports the user in analytics event reports. When set to YES, event reports will contain the user attributes, except attributes marked as private. When set to NO, event reports will contain the user's key only, reducing the size of event reports. (Default: NO)
     */
    @objc public var inlineUserInEvents: Bool {
        get { config.inlineUserInEvents }
        set { config.inlineUserInEvents = newValue }
    }

    /// Enables logging for debugging. (Default: NO)
    @objc public var debugMode: Bool {
        get { config.isDebugMode }
        set { config.isDebugMode = newValue }
    }

    /// Enables requesting evaluation reasons for all flags. (Default: NO)
    @objc public var evaluationReasons: Bool {
        get { config.evaluationReasons }
        set { config.evaluationReasons = newValue }
    }

    /// An Integer that tells UserEnvironmentFlagCache the maximum number of users to locally cache. Can be set to -1 for unlimited cached users. (Default: 5)
    @objc public var maxCachedUsers: Int {
        get { config.maxCachedUsers }
        set { config.maxCachedUsers = newValue }
    }

    /**
     Set to true to opt out of sending diagnostic data. (Default: false)

     Unless the diagnosticOptOut field is set to true, the client will send some diagnostics data to the LaunchDarkly servers in order to assist in the development of future SDK improvements. These diagnostics consist of an initial payload containing some details of the SDK in use, the SDK's configuration, and the platform the SDK is being run on; as well as payloads sent periodically with information on irregular occurrences such as dropped events.
     */
    @objc public var diagnosticOptOut: Bool {
        get { config.diagnosticOptOut }
        set { config.diagnosticOptOut = newValue }
    }

    /// The interval between sending periodic diagnostic data. (Default: 15 minutes)
    @objc public var diagnosticRecordingInterval: TimeInterval {
        get { config.diagnosticRecordingInterval }
        set { config.diagnosticRecordingInterval = newValue }
    }

    /// For use by wrapper libraries to set an identifying name for the wrapper being used. This will be sent in the "X-LaunchDarkly-Wrapper" header on requests to the LaunchDarkly servers to allow recording metrics on the usage of these wrapper libraries.
    @objc public var wrapperName: String? {
        get { config.wrapperName }
        set { config.wrapperName = newValue }
    }

    /// For use by wrapper libraries to report the version of the library in use. If the `wrapperName` has not been set this field will be ignored. Otherwise the verison strill will be included with the `wrapperName` in the "X-LaunchDarkly-Wrapper" header on requests to the LaunchDarkly servers.
    @objc public var wrapperVersion: String? {
        get { config.wrapperVersion }
        set { config.wrapperVersion = newValue }
    }

    /**
     Returns a Dictionary of identifying names to unique mobile keys to access secondary environments.

     - returns: A Dictionary of String to String.
     */
    @objc public func getSecondaryMobileKeys() -> [String: String] {
        return config.getSecondaryMobileKeys()
    }

    /**
     Sets a Dictionary of identifying names to unique mobile keys to access secondary environments in the LDConfig. Throws if you try to add duplicate keys or put the primary key or name in secondaryMobileKeys.

     - parameter keys: A Dictionary of String to String.
     */
    @objc public func setSecondaryMobileKeys(_ keys: [String: String]) throws {
        try config.setSecondaryMobileKeys(keys)
    }
    
    /// LDConfig constructor. Configurable values are all set to their default values. The client app can modify these values as desired. Note that client app developers may prefer to get the LDConfig from `LDClient.config` (`ObjcLDClient.config`) in order to retain previously set values.
    @objc public init(mobileKey: String) {
        config = LDConfig(mobileKey: mobileKey)
    }

    // Initializer to wrap the Swift LDConfig into ObjcLDConfig for use in Objective-C apps.
    init(_ config: LDConfig) {
        self.config = config
    }

    /// Compares the settable properties in 2 LDConfig structs
    @objc public func isEqual(object: Any?) -> Bool {
        guard let other = object as? ObjcLDConfig
        else { return false }
        return config == other.config
    }
}
