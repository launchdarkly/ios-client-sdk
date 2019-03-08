//
//  LDClient.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 7/11/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

enum LDClientRunMode {
    case foreground, background
}

/**
 The LDClient is the heart of the SDK, providing client apps running iOS, watchOS, macOS, or tvOS access to LaunchDarkly services. This singleton provides the ability to set a configuration (LDConfig) that controls how the LDClient talks to LaunchDarkly servers, and a user (LDUser) that provides finer control on the feature flag values delivered to LDClient. Once the LDClient has started, it connects to LaunchDarkly's servers to get the feature flag values you set in the Dashboard.
## Usage
### Startup
 1. To customize, configure a `LDConfig` and `LDUser`. The `config` is required, the `user` is optional. Both give you additional control over the feature flags delivered to the LDClient. See `LDConfig` & `LDUser` for more details.
    - The mobileKey set into the `LDConfig` comes from your LaunchDarkly Account settings (on the left, at the bottom). If you have multiple projects be sure to choose the correct Mobile key.
 2. Call `LDClient.shared.start(config: user: completion:)`
    - If you do not pass in a LDUser, LDCLient will create a default for you.
    - The optional completion closure allows the LDClient to notify your app when it has gone online.
 3. Because the LDClient is a singleton, you do not have to keep a reference to it in your code.

### Getting Feature Flags
 Once the LDClient has started, it makes your feature flags available using the `variation` and `variationAndSource` methods. A `variation` is a specific flag value. For example a boolean feature flag has 2 variations, `true` and `false`. You can create feature flags with more than 2 variations using other feature flag types. See `LDFlagValue` for the available types.
 ````
 let boolFlag = LDClient.shared.variation(forKey: "my-bool-flag", fallback: false)
 ````
 If you need to know the source of the variation provided to you for a specific feature flag, the `variationAndSource` method returns a tuple with the (value, source) in a single call.

 See `variation(forKey: fallback:)` or `variationAndSource(forKey: fallback:)` for details

### Observing Feature Flags
 You might need to know when a feature flag value changes. This is not required, you can check the flag's value when you need it.

 If you want to know when a feature flag value changes, you can check the flag's value. You can also use one of several `observe` methods to have the LDClient notify you when a change occurs. There are several options--you can set up notificiations based on when a specific flag changes, when any flag in a collection changes, or when a flag doesn't change.
 ````
 LDClient.shared.observe("flag-key", owner: self, observer: { [weak self] (changedFlag) in
    self?.updateFlag(key: "flag-key", changedFlag: changedFlag)
 }
 ````
 The `changedFlag` passed in to the closure contains the old and new value, and the old and new valueSource.
 */
public class LDClient {

    // MARK: - State Controls and Indicators

    /// Access to the LDClient singleton. For iOS apps with watchOS companion apps, there will be a singleton on each platform. These singletons do not communicate with each other. If you try to share feature flags between apps, the latest flag values may be overwritten by old feature flags from the other platform. LaunchDarkly recommends not sharing feature flags between apps and allowing each LDClient to manage feature flags on its own platform. If you share feature flag data between apps, provide a way to prevent the LDClients from overwriting new feature flags with old feature flags in the shared data.
    public static let shared = LDClient()

    /**
     Reports the online/offline state of the LDClient.

     When online, the SDK communicates with LaunchDarkly servers for feature flag values and event reporting.

     When offline, the SDK does not attempt to communicate with LaunchDarkly servers. Client apps can request feature flag values and set/change feature flag observers while offline. The SDK will collect events while offline.

     Use `setOnline(_: completion:)` to change the online/offline state.
    */
    public private (set) var isOnline: Bool = false {
        didSet {
            flagSynchronizer.isOnline = isOnline
            eventReporter.isOnline = isOnline
        }
    }

    //Keeps the state of the last setOnline goOnline parameter, used for throttling calls to set the SDK online
    private var lastSetOnlineCallValue = false

    /**
     Set the LDClient online/offline.

     When online, the SDK communicates with LaunchDarkly servers for feature flag values and event reporting.

     When offline, the SDK does not attempt to communicate with LaunchDarkly servers. Client apps can request feature flag values and set/change feature flag observers while offline. The SDK will collect events while offline.

     The SDK protects itself from multiple rapid calls to setOnline(true) by enforcing an increasing delay (called *throttling*) each time setOnline(true) is called within a short time. The first time, the call proceeds normally. For each subsequent call the delay is enforced, and if waiting, increased to a maximum delay. When the delay has elapsed, the `setOnline(true)` will proceed, assuming that the client app has not called `setOnline(false)` during the delay. Therefore a call to setOnline(true) may not immediately result in the LDClient going online. Client app developers should consider this situation abnormal, and take steps to prevent the client app from making multiple rapid setOnline(true) calls. Calls to setOnline(false) are not throttled. Note that calls to `start(config: user: completion:)`, and setting the `config` or `user` can also call `setOnline(true)` under certain conditions. After the delay, the SDK resets and the client app can make a susequent call to setOnline(true) without being throttled.

     Client apps can set a completion closure called when the setOnline call completes. For unthrottled `setOnline(true)` and all `setOnline(false)` calls, the SDK will call the closure immediately on completion of this method. For throttled `setOnline(true)` calls, the SDK will call the closure after the throttling delay at the completion of the setOnline method.

     The SDK will not go online if the client has not been started, or the `mobileKey` is empty. For macOS, the SDK will not go online in the background unless `enableBackgroundUpdates` is true.

     Use `isOnline` to get the online/offline state.

     - parameter goOnline:    Desired online/offline mode for the LDClient
     - parameter completion:  Completion closure called when setOnline completes (Optional)
     */
    public func setOnline(_ goOnline: Bool, completion: (() -> Void)? = nil) {
        lastSetOnlineCallValue = goOnline
        guard goOnline, canGoOnline
        else {
            //go offline, which is not throttled
            go(online: false, reasonOnlineUnavailable: reasonOnlineUnavailable(goOnline: goOnline), completion: completion)
            return
        }

        throttler.runThrottled {
            //since going online was throttled, check the last called setOnline value and whether we can go online
            self.go(online: self.lastSetOnlineCallValue && self.canGoOnline, reasonOnlineUnavailable: self.reasonOnlineUnavailable(goOnline: self.lastSetOnlineCallValue), completion: completion)
        }
    }

    private var canGoOnline: Bool {
        return hasStarted && isInSupportedRunMode && !config.mobileKey.isEmpty
    }

    private var isInSupportedRunMode: Bool {
        return runMode == .foreground || allowBackgroundFlagUpdates
    }

    private func go(online goOnline: Bool, reasonOnlineUnavailable: String, completion:(() -> Void)?) {
        isOnline = goOnline
        Log.debug(typeName(and: "setOnline", appending: ": ") + (reasonOnlineUnavailable.isEmpty ? "\(self.isOnline)." : "true aborted.") + reasonOnlineUnavailable)
        completion?()
    }

    private func reasonOnlineUnavailable(goOnline: Bool) -> String {
        if !goOnline {
            return ""
        }
        if !hasStarted {
            return " LDClient not started."
        }
        if !isInSupportedRunMode {
            return " LDConfig background updates not enabled."
        }
        if config.mobileKey.isEmpty {
            return " Mobile Key is empty."
        }
        return ""
    }

    /**
     The LDConfig that configures the LDClient. See `LDConfig` for details about what can be configured.

     Normally, the client app should set desired values into a LDConfig and pass that into `start(config: user: completion:)`. If the client does not pass a LDConfig to the LDClient, the LDClient creates a LDConfig using all default values.

     The client app can change the LDConfig by getting the `config`, adjusting the values, and setting it into the LDClient.

     When a new config is set, the LDClient goes offline and reconfigures using the new config. If the client was online when the new config was set, it goes online again, subject to a throttling delay if in force (see `setOnline(_: completion:)` for details). To change both the `config` and `user`, set the LDClient offline, set both properties, then set the LDClient online.
    */
    public var config: LDConfig {
        didSet {
            guard config != oldValue
            else {
                Log.debug(typeName(and: #function) + "aborted. New config matches old config")
                return
            }

            Log.level = environmentReporter.isDebugBuild && config.isDebugMode ? .debug : .noLogging
            Log.debug(typeName(and: #function) + "new config set")
            let wasOnline = isOnline
            setOnline(false)

            service = serviceFactory.makeDarklyServiceProvider(config: config, user: user)
            eventReporter.config = config

            setOnline(wasOnline)
        }
    }
    
    /**
     The LDUser set into the LDClient may affect the set of feature flags returned by the LaunchDarkly server, and ties event tracking to the user. See `LDUser` for details about what information can be retained.

     Normally, the client app should create and set the LDUser and pass that into `start(config: user: completion:)`.

     The client app can change the LDUser by getting the `user`, adjusting the values, and setting it into the LDClient. This allows client apps to collect information over time from the user and update as information is collected. Client apps should follow [Apple's Privacy Policy](apple.com/legal/privacy) when collecting user information. If the client app does not create a LDUser, LDClient creates an anonymous default user, which can affect the feature flags delivered to the LDClient.

     When a new user is set, the LDClient goes offline and sets the new user. If the client was online when the new user was set, it goes online again, subject to a throttling delay if in force (see `setOnline(_: completion:)` for details). To change both the `config` and `user`, set the LDClient offline, set both properties, then set the LDClient online.
    */
    public var user: LDUser {
        didSet {
            Log.debug(typeName(and: #function) + "new user set with key: " + user.key )
            let wasOnline = isOnline
            setOnline(false)

            if hasStarted {
                eventReporter.recordSummaryEvent()
            }

            if let cachedFlags = flagCache.retrieveFlags(for: user), !cachedFlags.flags.isEmpty {
                user.flagStore.replaceStore(newFlags: cachedFlags.flags, source: .cache, completion: nil)
            }
            service = serviceFactory.makeDarklyServiceProvider(config: config, user: user)

            if hasStarted {
                eventReporter.record(Event.identifyEvent(user: user))
            }

            setOnline(wasOnline)
        }
    }

    private(set) var service: DarklyServiceProvider {
        didSet {
            Log.debug(typeName(and: #function) + "new service set")
            eventReporter.service = service
            flagSynchronizer = serviceFactory.makeFlagSynchronizer(streamingMode: effectiveStreamingMode(runMode: runMode, config: config),
                                                                   pollingInterval: config.flagPollingInterval(runMode: runMode),
                                                                   useReport: config.useReport,
                                                                   service: service,
                                                                   onSyncComplete: onFlagSyncComplete)
        }
    }

    private(set) var hasStarted = false

    /**
     Starts the LDClient using the passed in `config` & `user`. Call this before requesting feature flag values. The LDClient will not go online until you call this method.

     Starting the LDClient means setting the `config` & `user`, setting the client online if `config.startOnline` is true (the default setting), and starting event recording. The client app must start the LDClient before it will report feature flag values. If a client does not call start, the LDClient will only report fallback values, and no events will be recorded.

     If the start call omits the `user`, the LDClient uses the previously set `user`, or the default `user` if it was never set.

     If the start call includes the optional `completion` closure, LDClient calls the `completion` closure when `setOnline(_: completion:)` embedded in the start method completes. The start call is subject to throttling delays, therefore the `completion` closure call may be delayed.

     Subsequent calls to this method cause the LDClient to go offline, reconfigure using the new `config` & `user` (if supplied), and then go online if it was online when start was called. Normally there should only be one call to start. To change `config` or `user`, set them directly on LDClient.

     - parameter config: The LDConfig that contains the desired configuration. (Required)
     - parameter user: The LDUser set with the desired user. If omitted, LDClient retains the previously set user, or default if one was never set. (Optional)
     - parameter completion: Closure called when the embedded `setOnline` call completes, subject to throttling delays. (Optional)
    */
    public func start(config: LDConfig, user: LDUser? = nil, completion: (() -> Void)? = nil) {
        Log.debug(typeName(and: #function, appending: ": ") + "starting")
        let wasStarted = hasStarted
        let wasOnline = isOnline
        hasStarted = true

        setOnline(false)

        self.config = config
        self.user = user ?? self.user

        setOnline((wasStarted && wasOnline) || (!wasStarted && self.config.startOnline)) {
            Log.debug(self.typeName(and: #function, appending: ": ") + "started")
            completion?()
        }
    }

    private func effectiveStreamingMode(runMode: LDClientRunMode, config: LDConfig) -> LDStreamingMode {
        var reason = ""
        let streamingMode: LDStreamingMode = (runMode == .foreground || allowBackgroundFlagUpdates) && config.streamingMode == .streaming && config.allowStreamingMode ? .streaming : .polling
        if config.streamingMode == .streaming && runMode != .foreground && !allowBackgroundFlagUpdates {
            reason = " LDClient is in background mode with background updates disabled."
        }
        if reason.isEmpty && config.streamingMode == .streaming && !config.allowStreamingMode {
            reason = " LDConfig disallowed streaming mode. "
            reason += !environmentReporter.operatingSystem.isStreamingEnabled ? "Streaming is not allowed on \(environmentReporter.operatingSystem)." : "Unknown reason."
        }
        Log.debug(typeName(and: #function, appending: ": ") + "\(streamingMode)\(reason)")
        return streamingMode
    }

    /**
     Stops the LDClient. Stopping the client means the LDClient goes offline and stops recording events. LDClient will no longer provide feature flag values, only returning fallback values.

     There is almost no reason to stop the LDClient. Normally, set the LDClient offline to stop communication with the LaunchDarkly servers. Stop the LDClient to stop recording events. There is no need to stop the LDClient prior to suspending, moving to the background, or terminating the app. The SDK will respond to these events as the system requires and as configured in LDConfig.
    */
    public func stop() {
        Log.debug(typeName(and: #function, appending: "- ") + "stopping")
        setOnline(false)
        hasStarted = false
        Log.debug(typeName(and: #function, appending: "- ") + "stopped")
    }
    
    // MARK: Feature Flag values
    
    /* FF Value Requests
     Conceptual Model
     The LDClient is the focal point for flag value requests. It should appear to the app that the client contains a store of [key: value] pairs where the keys are all strings and the values any of the supported LD flag types (Bool, Int, Double, String, Array, Dictionary).
     When asked for a variation value, the LDClient provides either the value, or the value and LDVariationSource as a tuple.
    */
    
    /**
     Returns the variation for the given feature flag. If the flag does not exist, cannot be cast to the correct return type, or the LDClient is not started, returns the fallback value. Use this method when the fallback value is a non-Optional type. See `variation` with the Optional return value when the fallback value can be nil.

     A *variation* is a specific flag value. For example a boolean feature flag has 2 variations, *true* and *false*. You can create feature flags with more than 2 variations using other feature flag types. See `LDFlagValue` for the available types.

     The LDClient must be started in order to return feature flag values. If the LDClient is not started, it will always return the fallback value. The LDClient must be online to keep the feature flag values up-to-date.

     When online, the LDClient has two modes for maintaining feature flag values: *streaming* and *polling*. The client app requests the mode by setting the `config.streamingMode`, see `LDConfig` for details.
     - In streaming mode, the LDClient opens a long-running connection to LaunchDarkly's streaming server (called *clientstream*). When a flag value changes on the server, the clientstream notifies the SDK to update the value. Streaming mode is not available on watchOS. On iOS and tvOS, the client app must be running in the foreground to connect to clientstream. On macOS the client app may run in either foreground or background to connect to clientstream. If streaming mode is not available, the SDK reverts to polling mode.
     - In polling mode, the LDClient requests feature flags from LaunchDarkly's app server at regular intervals defined in the LDConfig. When a flag value changes on the server, the LDClient will learn of the change the next time the SDK requests feature flags.

     When offline, LDClient closes the clientstream connection and no longer requests feature flags. The LDClient will return feature flag values (assuming the LDClient was started), which may not match the values set on the LaunchDarkly server.

     A call to `variation` records events reported later. Recorded events allow clients to analyze usage and assist in debugging issues.

     ### Usage
     ````
     let boolFeatureFlagValue = LDClient.shared.variation(forKey: "bool-flag-key", fallback: false) //boolFeatureFlagValue is a Bool
     ````
     **Important** The fallback value tells the SDK the type of the feature flag. In several cases, the feature flag type cannot be determined by the values sent from the server. It is possible to provide a fallback value with a type that does not match the feature flag value's type. The SDK will attempt to convert the feature flag's value into the type of the fallback value in the variation request. If that cast fails, the SDK will not be able to determine the correct return type, and will always return the fallback value.

     Pay close attention to the type of the fallback value for collections. If the fallback collection type is more restrictive than the feature flag, the sdk will return the fallback even though the feature flag is present because it cannot convert the feature flag into the type requested via the fallback value. For example, if the feature flag has the type `[LDFlagKey: Any]`, but the fallback has the type `[LDFlagKey: Int]`, the sdk will not be able to convert the flags into the requested type, and will return the fallback value.

     To avoid this, make sure the fallback type matches the expected feature flag type. Either specify the fallback value type to be the feature flag type, or cast the fallback value to the feature flag type prior to making the variation request. In the above example, either specify that the fallback value's type is [LDFlagKey: Any]:
     ````
     let fallbackValue: [LDFlagKey: Any] = ["a": 1, "b": 2]     //dictionary type would be [String: Int] without the type specifier
     ````
     or cast the fallback value into the feature flag type prior to calling variation:
     ````
     let dictionaryFlagValue = LDClient.shared.variation(forKey: "dictionary-key", fallback: ["a": 1, "b": 2] as [LDFlagKey: Any])  //cast always succeeds since the destination type is less restrictive
     ````

     - parameter forKey: The LDFlagKey for the requested feature flag.
     - parameter fallback: The fallback value to return if the feature flag key does not exist.

     - returns: The requested feature flag value, or the fallback if the flag is missing or cannot be cast to the fallback type, or the client is not started
    */
    public func variation<T: LDFlagValueConvertible>(forKey flagKey: LDFlagKey, fallback: T) -> T {
        return variation(forKey: flagKey, fallback: fallback as T?) ?? fallback     //the fallback cast to 'as T?' directs the call to the Optional-returning variation method
    }

    /**
     Returns the variation for the given feature flag. If the flag does not exist, cannot be cast to the correct return type, or the LDClient is not started, returns the fallback value, which may be `nil`. Use this method when the fallback value is an Optional type. See `variation` with the non-Optional return value when the fallback value cannot be nil.

     A *variation* is a specific flag value. For example a boolean feature flag has 2 variations, *true* and *false*. You can create feature flags with more than 2 variations using other feature flag types. See `LDFlagValue` for the available types.

     The LDClient must be started in order to return feature flag values. If the LDClient is not started, it will always return the fallback value. The LDClient must be online to keep the feature flag values up-to-date.

     When online, the LDClient has two modes for maintaining feature flag values: *streaming* and *polling*. The client app requests the mode by setting the `config.streamingMode`, see `LDConfig` for details.
     - In streaming mode, the LDClient opens a long-running connection to LaunchDarkly's streaming server (called *clientstream*). When a flag value changes on the server, the clientstream notifies the SDK to update the value. Streaming mode is not available on watchOS. On iOS and tvOS, the client app must be running in the foreground to connect to clientstream. On macOS the client app may run in either foreground or background to connect to clientstream. If streaming mode is not available, the SDK reverts to polling mode.
     - In polling mode, the LDClient requests feature flags from LaunchDarkly's app server at regular intervals defined in the LDConfig. When a flag value changes on the server, the LDClient will learn of the change the next time the SDK requests feature flags.

     When offline, LDClient closes the clientstream connection and no longer requests feature flags. The LDClient will return feature flag values (assuming the LDClient was started), which may not match the values set on the LaunchDarkly server.

     A call to `variation` records events reported later. Recorded events allow clients to analyze usage and assist in debugging issues.

     ### Usage
     ````
     let boolFeatureFlagValue: Bool? = LDClient.shared.variation(forKey: "bool-flag-key", fallback: nil) //boolFeatureFlagValue is a Bool?
     ````
     **Important** The fallback value tells the SDK the type of the feature flag. In several cases, the feature flag type cannot be determined by the values sent from the server. It is possible to provide a fallback value with a type that does not match the feature flag value's type. The SDK will attempt to convert the feature flag's value into the type of the fallback value in the variation request. If that cast fails, the SDK will not be able to determine the correct return type, and will always return the fallback value.

     When specifying `nil` as the fallback value, the compiler must also know the type of the optional. Without this information, the compiler will give the error "'nil' requires a contextual type". There are several ways to provide this information, by setting the type on the item holding the return value, by casting the return value to the desired type, or by casting `nil` to the desired type. We recommend following the above example and setting the type on the return value item.

     For this method, the fallback value is defaulted to `nil`, allowing the call site to omit the fallback value.

     Pay close attention to the type of the fallback value for collections. If the fallback collection type is more restrictive than the feature flag, the sdk will return the fallback even though the feature flag is present because it cannot convert the feature flag into the type requested via the fallback value. For example, if the feature flag has the type `[LDFlagKey: Any]`, but the fallback has the type `[LDFlagKey: Int]`, the sdk will not be able to convert the flags into the requested type, and will return the fallback value.

     To avoid this, make sure the fallback type matches the expected feature flag type. Either specify the fallback value type to be the feature flag type, or cast the fallback value to the feature flag type prior to making the variation request. In the above example, either specify that the fallback value's type is [LDFlagKey: Any]:
     ````
     let fallbackValue: [LDFlagKey: Any]? = ["a": 1, "b": 2]     //dictionary type would be [String: Int] without the type specifier
     ````
     or cast the fallback value into the feature flag type prior to calling variation:
     ````
     let dictionaryFlagValue = LDClient.shared.variation(forKey: "dictionary-key", fallback: ["a": 1, "b": 2] as [LDFlagKey: Any]?)  //cast always succeeds since the destination type is less restrictive
     ````

     - parameter forKey: The LDFlagKey for the requested feature flag.
     - parameter fallback: The fallback value to return if the feature flag key does not exist. If omitted, the fallback value is `nil`. (Optional)

     - returns: The requested feature flag value, or the fallback if the flag is missing or cannot be cast to the fallback type, or the client is not started
     */
    public func variation<T: LDFlagValueConvertible>(forKey flagKey: LDFlagKey, fallback: T? = nil) -> T? {
        let (value, _) = variationAndSource(forKey: flagKey, fallback: fallback)
        return value
    }

    /**
     Returns the variation and source for the given feature flag as a tuple. If the flag does not exist, cannot be cast to the correct return type, or the LDClient is not started, returns the fallback value and `.fallback` for the source. Use this method when the fallback value is a non-Optional type. See `variationAndSource` with the Optional return value when the fallback value can be nil.

     A *variation* is a specific flag value. For example a boolean feature flag has 2 variations, *true* and *false*. You can create feature flags with more than 2 variations using other feature flag types. See `LDFlagValue` for the available types.

     The LDClient must be started in order to return feature flag values. If the LDClient is not started, it will always return the fallback value. The LDClient must be online to keep the feature flag values up-to-date.

     When online, the LDClient has two modes for maintaining feature flag values: *streaming* and *polling*. The client app requests the mode by setting the `config.streamingMode`, see `LDConfig` for details.
     - In streaming mode, the LDClient opens a long-running connection to LaunchDarkly's streaming server (called *clientstream*). When a flag value changes on the server, the clientstream notifies the SDK to update the value. Streaming mode is not available on watchOS. On iOS and tvOS, the client app must be running in the foreground to connect to clientstream. On macOS the client app may run in either foreground or background to connect to clientstream. If streaming mode is not available, the SDK reverts to polling mode.
     - In polling mode, the LDClient requests feature flags from LaunchDarkly's app server at regular intervals defined in the LDConfig. When a flag value changes on the server, the LDClient will learn of the change the next time the SDK requests feature flags.

     When offline, LDClient closes the clientstream connection and no longer requests feature flags. The LDClient will return feature flag values (assuming the LDClient was started), which may not match the values set on the LaunchDarkly server.

     A call to `variationAndSource` records events reported later. Recorded events allow clients to analyze usage and assist in debugging issues.

     ### Usage
     ````
     let (boolFeatureFlagValue, boolFeatureFlagSource) = LDClient.shared.variationAndSource(forKey: "bool-flag-key", fallback: false)    //boolFeatureFlagValue is a Bool
     ````
     **Important** The fallback value tells the SDK the type of the feature flag. In several cases, the feature flag type cannot be determined by the values sent from the server. It is possible to provide a fallback value with a type that does not match the feature flag value's type. The SDK will attempt to convert the feature flag's value into the type of the fallback value in the variation request. If that cast fails, the SDK will not be able to determine the correct return type, and will always return the fallback value.

     Pay close attention to the type of the fallback value for collections. If the fallback collection type is more restrictive than the feature flag, the sdk will return the fallback even though the feature flag is present because it cannot convert the feature flag into the type requested via the fallback value. For example, if the feature flag has the type `[LDFlagKey: Any]`, but the fallback has the type `[LDFlagKey: Int]`, the sdk will not be able to convert the flags into the requested type, and will return the fallback value.

     To avoid this, make sure the fallback type matches the expected feature flag type. Either specify the fallback value type to be the feature flag type, or cast the fallback value to the feature flag type prior to making the variation request. In the above example, either specify that the fallback value's type is [LDFlagKey: Any]:
     ````
     let fallbackValue: [LDFlagKey: Any] = ["a": 1, "b": 2]     //dictionary type would be [String: Int] without the type specifier
     ````
     or cast the fallback value into the feature flag type prior to calling variation:
     ````
     let (dictionaryFlagValue, dictionaryFeatureFlagSource) = LDClient.shared.variationAndSource(forKey: "dictionary-key", fallback: ["a": 1, "b": 2] as [LDFlagKey: Any])  //cast always succeeds since the destination type is less restrictive
     ````

     - parameter forKey: The LDFlagKey for the requested feature flag.
     - parameter fallback: The fallback value to return if the feature flag key does not exist.

     - returns: A tuple containing the requested feature flag value and source, or the fallback if the flag is missing or cannot be cast to the fallback type, or the client is not started. If the fallback value is returned, the source is `.fallback`
     */
    public func variationAndSource<T: LDFlagValueConvertible>(forKey flagKey: LDFlagKey, fallback: T) -> (T, LDFlagValueSource) {
        let (value, source) = variationAndSource(forKey: flagKey, fallback: fallback as T?)
        return (value ?? fallback, source)  //Because the fallback is wrapped into an Optional, the nil coalescing right side should never be called
    }

    /**
     Returns the variation and source for the given feature flag as a tuple. If the flag does not exist, cannot be cast to the correct return type, or the LDClient is not started, returns the fallback value and `.fallback` for the source. Use this method when the fallback value is an Optional type. See `variationAndSource` with the non-Optional return value when the fallback value cannot be nil.

     A *variation* is a specific flag value. For example a boolean feature flag has 2 variations, *true* and *false*. You can create feature flags with more than 2 variations using other feature flag types. See `LDFlagValue` for the available types.

     The LDClient must be started in order to return feature flag values. If the LDClient is not started, it will always return the fallback value. The LDClient must be online to keep the feature flag values up-to-date.

     When online, the LDClient has two modes for maintaining feature flag values: *streaming* and *polling*. The client app requests the mode by setting the `config.streamingMode`, see `LDConfig` for details.
     - In streaming mode, the LDClient opens a long-running connection to LaunchDarkly's streaming server (called *clientstream*). When a flag value changes on the server, the clientstream notifies the SDK to update the value. Streaming mode is not available on watchOS. On iOS and tvOS, the client app must be running in the foreground to connect to clientstream. On macOS the client app may run in either foreground or background to connect to clientstream. If streaming mode is not available, the SDK reverts to polling mode.
     - In polling mode, the LDClient requests feature flags from LaunchDarkly's app server at regular intervals defined in the LDConfig. When a flag value changes on the server, the LDClient will learn of the change the next time the SDK requests feature flags.

     When offline, LDClient closes the clientstream connection and no longer requests feature flags. The LDClient will return feature flag values (assuming the LDClient was started), which may not match the values set on the LaunchDarkly server.

     A call to `variationAndSource` records events reported later. Recorded events allow clients to analyze usage and assist in debugging issues.

     ### Usage
     ````
     let (boolFeatureFlagValue, boolFeatureFlagSource): (Bool?, LDFlagValueSource) = LDClient.shared.variationAndSource(forKey: "bool-flag-key", fallback: nil) //boolFeatureFlagValue is a Bool?
     ````
     **Important** The fallback value tells the SDK the type of the feature flag. In several cases, the feature flag type cannot be determined by the values sent from the server. It is possible to provide a fallback value with a type that does not match the feature flag value's type. The SDK will attempt to convert the feature flag's value into the type of the fallback value in the variation request. If that cast fails, the SDK will not be able to determine the correct return type, and will always return the fallback value.

     When specifying `nil` as the fallback value, the compiler must also know the type of the optional. Without this information, the compiler will give the error "'nil' requires a contextual type". There are several ways to provide this information, by setting the type on the item holding the return value, by casting the return value to the desired type, or by casting `nil` to the desired type. We recommend following the above example and setting the type on the return value item.

     For this method, the fallback value is defaulted to `nil`, allowing the call site to omit the fallback value.

     Pay close attention to the type of the fallback value for collections. If the fallback collection type is more restrictive than the feature flag, the sdk will return the fallback even though the feature flag is present because it cannot convert the feature flag into the type requested via the fallback value. For example, if the feature flag has the type `[LDFlagKey: Any]`, but the fallback has the type `[LDFlagKey: Int]`, the sdk will not be able to convert the flags into the requested type, and will return the fallback value.

     To avoid this, make sure the fallback type matches the expected feature flag type. Either specify the fallback value type to be the feature flag type, or cast the fallback value to the feature flag type prior to making the variation request. In the above example, either specify that the fallback value's type is [LDFlagKey: Any]:
     ````
     let fallbackValue: [LDFlagKey: Any] = ["a": 1, "b": 2]     //dictionary type would be [String: Int] without the type specifier
     ````
     or cast the fallback value into the feature flag type prior to calling variation:
     ````
     let (dictionaryFlagValue, dictionaryFeatureFlagSource) = LDClient.shared.variationAndSource(forKey: "dictionary-key", fallback: ["a": 1, "b": 2] as [LDFlagKey: Any])  //cast always succeeds since the destination type is less restrictive
     ````

     - parameter forKey: The LDFlagKey for the requested feature flag.
     - parameter fallback: The fallback value to return if the feature flag key does not exist. If omitted, the fallback value is `nil`. (Optional)

     - returns: A tuple containing the requested feature flag value and source, or the fallback if the flag is missing or cannot be cast to the fallback type, or the client is not started. If the fallback value is returned, the source is `.fallback`
     */
    public func variationAndSource<T: LDFlagValueConvertible>(forKey flagKey: LDFlagKey, fallback: T? = nil) -> (T?, LDFlagValueSource) {
        guard hasStarted
        else {
            Log.debug(typeName(and: #function) + "returning fallback: \(fallback.stringValue), source: \(LDFlagValueSource.fallback)." + " LDClient not started.")
            return (fallback, .fallback)
        }
        let (featureFlag, flagStoreSource) = user.flagStore.featureFlagAndSource(for: flagKey)
        let (value, source): (T?, LDFlagValueSource) = valueAndSource(from: featureFlag, fallback: fallback, source: flagStoreSource)
        let failedConversionMessage = self.failedConversionMessage(featureFlag: featureFlag, source: source, fallback: fallback)
        Log.debug(typeName(and: #function) + "flagKey: \(flagKey), value: \(value.stringValue), fallback: \(fallback.stringValue), featureFlag: \(featureFlag.stringValue), source: \(source)."
            + "\(failedConversionMessage)")
        eventReporter.recordFlagEvaluationEvents(flagKey: flagKey, value: value, defaultValue: fallback, featureFlag: featureFlag, user: user)
        return (value, source)
    }

    private func failedConversionMessage<T>(featureFlag: FeatureFlag?, source: LDFlagValueSource, fallback: T?) -> String {
        if featureFlag == nil {
            return " Feature flag not found."
        }
        guard source == .fallback
        else {
            return ""
        }
        return " LDClient was unable to convert the feature flag to the requested type (\(T.self))."
            + (fallback is Collection ? " The fallback value type is a collection. Make sure the element of the fallback value's type is not too restrictive for the actual feature flag type." : "")
    }

    /**
     Returns a dictionary with the flag keys and their values. If the LDClient is not started, returns nil.

     The dictionary will not contain feature flags from the server with null values.

     LDClient will not provide any source or change information, only flag keys and flag values. The client app should convert the feature flag value into the desired type.
    */
    public var allFlagValues: [LDFlagKey: Any]? {
        guard hasStarted
        else {
            return nil
        }
        return user.flagStore.featureFlags.compactMapValues { (featureFlag) -> Any? in
            featureFlag.value
        }
    }

    private func valueAndSource<T>(from featureFlag: FeatureFlag?, fallback: T?, source: LDFlagValueSource?) -> (T?, LDFlagValueSource) {
        guard let value = featureFlag?.value as? T
        else {
            return (fallback, .fallback)
        }
        return (value, source ?? .fallback)
    }

    // MARK: Feature Flag Updates
    
    /* FF Change Notification
     Conceptual Model
     LDClient keeps a list of two types of closure observers, either Flag Change Observers or Flags Unchanged Observers.
     There are 3 types of Flag Change Observers, Individual Flag Change Observers, Flag Collection Change Observers, and All Flags Change Observers. LDClient executes Individual Flag observers when it detects a change to a single flag being observed. LDClient executes Flag Collection Change Observers one time when it detects a change to any flag in the observed flag collection. LDClient executes All Flags observers one time when it detects a change to any flag. The Individual Flag Change Observer has closure that takes a LDChangedFlag input parameter which communicates the flag's old & new value. Flag Collection and All Flags Observers will have a closure that takes a dictionary of [LDFlagKey: LDChangeFlag] that communicates all of the changed flags.
     An app registers an Individual Flag observer using observe(key:, owner:, handler:). An app registers a Flag Collection Observer using observe(keys: owner: handler), An app registers an All Flags observer using observeAll(owner:, handler:). An app can register multiple closures for each type by calling these methods multiple times. When the value of a flag changes, LDClient calls each registered closure 1 time.
     Flags Unchanged Observers allow the LDClient to communicate to the app when it receives flags from the LD server that doesn't change any values from what the LDClient had already. For example, at launch the LDClient restores cached flag values before requesting flags from the LD server. If there has been no change to the flag values, the LDClient will execute the Flags Unchanged Observers that the app has registered. An app registers a Flags Unchanged Observer using observeFlagsUnchanged(owner: handler:).
     LDClient will automatically remove observers when the owner is nil. This means an app does not need to stop observing flags, the LDClient will remove the observer after it has gone out of scope. An app can stop observers explicitly using stopObserver(owner:).
     LDClient executes observers on the main thread.
    */
    
    /**
     Sets a handler for the specified flag key executed on the specified owner. If the flag's value changes, executes the handler, passing in the `changedFlag` containing the old and new flag values, and old and new flag value source. See `LDChangedFlag` for details.

     The SDK retains only weak references to the owner, which allows the client app to freely destroy owners without issues. Client apps should use a capture list specifying `[weak self]` inside handlers to avoid retain cycles causing a memory leak.

     The SDK executes handlers on the main thread.

     LDChangedFlag does not know the type of oldValue or newValue. The client app should cast the value into the type needed. See `variation(forKey: fallback:)` for details about the SDK and feature flag types.

     SeeAlso: `LDChangedFlag` and `stopObserving(owner:)`

     ### Usage
     ````
     LDClient.shared.observe("flag-key", owner: self) { [weak self] (changedFlag) in
        if let newValue = changedFlag.newValue as? Bool {
            //do something with the newValue
        }
    ///The LDClient will report events on the LDConfig.eventFlushInterval and when the client app moves to the background. There should normally not be a need to call reportEvents.
    public func reportEvents() {
        eventReporter.reportEvents()
     }
     ````

     - parameter key: The LDFlagKey for the flag to observe.
     - parameter owner: The LDFlagChangeOwner which will execute the handler. The SDK retains a weak reference to the owner.
     - parameter handler: The closure the SDK will execute when the feature flag changes.
    */
    public func observe(key: LDFlagKey, owner: LDObserverOwner, handler: @escaping LDFlagChangeHandler) {
        Log.debug(typeName(and: #function) + "flagKey: \(key), owner: \(String(describing: owner))")
        flagChangeNotifier.addFlagChangeObserver(FlagChangeObserver(key: key, owner: owner, flagChangeHandler: handler))
    }
    
    /**
     Sets a handler for the specified flag keys executed on the specified owner. If any observed flag's value changes, executes the handler 1 time, passing in a dictionary of [LDFlagKey: LDChangedFlag] containing the old and new flag values, and old and new flag value source. See `LDChangedFlag` for details.

     The SDK retains only weak references to owner, which allows the client app to freely destroy change owners without issues. Client apps should use a capture list specifying `[weak self]` inside handlers to avoid retain cycles causing a memory leak.

     The SDK executes handlers on the main thread.

     LDChangedFlag does not know the type of oldValue or newValue. The client app should cast the value into the type needed. See `variation(forKey: fallback:)` for details about the SDK and feature flag types.

     SeeAlso: `LDChangedFlag` and `stopObserving(owner:)`

     ### Usage
     ````
     LDClient.shared.observe(flagKeys, owner: self) { [weak self] (changedFlags) in     // changedFlags is a [LDFlagKey: LDChangedFlag]
        //There will be an LDChangedFlag entry in changedFlags for each changed flag. The closure will only be called once regardless of how many flags changed.
        if let someChangedFlag = changedFlags["some-flag-key"] {    // someChangedFlag is a LDChangedFlag
            //do something with someChangedFlag
         }
     }
     ````

     - parameter keys: An array of LDFlagKeys for the flags to observe.
     - parameter owner: The LDFlagChangeOwner which will execute the handler. The SDK retains a weak reference to the owner.
     - parameter handler: The LDFlagCollectionChangeHandler the SDK will execute 1 time when any of the observed feature flags change.
     */
    public func observe(keys: [LDFlagKey], owner: LDObserverOwner, handler: @escaping LDFlagCollectionChangeHandler) {
        Log.debug(typeName(and: #function) + "flagKeys: \(keys), owner: \(String(describing: owner))")
        flagChangeNotifier.addFlagChangeObserver(FlagChangeObserver(keys: keys, owner: owner, flagCollectionChangeHandler: handler))
    }

    /**
     Sets a handler for all flag keys executed on the specified owner. If any flag's value changes, executes the handler 1 time, passing in a dictionary of [LDFlagKey: LDChangedFlag] containing the old and new flag values, and old and new flag value source. See `LDChangedFlag` for details.

     The SDK retains only weak references to owner, which allows the client app to freely destroy change owners without issues. Client apps should use a capture list specifying `[weak self]` inside handlers to avoid retain cycles causing a memory leak.

     The SDK executes handlers on the main thread.

     LDChangedFlag does not know the type of oldValue or newValue. The client app should cast the value into the type needed. See `variation(forKey: fallback:)` for details about the SDK and feature flag types.

     SeeAlso: `LDChangedFlag` and `stopObserving(owner:)`

     ### Usage
     ````
     LDClient.shared.observeAll(owner: self) { [weak self] (changedFlags) in     // changedFlags is a [LDFlagKey: LDChangedFlag]
        //There will be an LDChangedFlag entry in changedFlags for each changed flag. The closure will only be called once regardless of how many flags changed.
        if let someChangedFlag = changedFlags["some-flag-key"] {    // someChangedFlag is a LDChangedFlag
            //do something with someChangedFlag
        }
     }
     ````

     - parameter owner: The LDFlagChangeOwner which will execute the handler. The SDK retains a weak reference to the owner.
     - parameter handler: The LDFlagCollectionChangeHandler the SDK will execute 1 time when any of the observed feature flags change.
     */
    public func observeAll(owner: LDObserverOwner, handler: @escaping LDFlagCollectionChangeHandler) {
        Log.debug(typeName(and: #function) + " owner: \(String(describing: owner))")
        flagChangeNotifier.addFlagChangeObserver(FlagChangeObserver(keys: LDFlagKey.anyKey, owner: owner, flagCollectionChangeHandler: handler))
    }
    
    /**
     Sets a handler executed when a flag update leaves the flags unchanged from their previous values.

     This handler can only ever be called when the LDClient is polling.

     The SDK retains only weak references to owner, which allows the client app to freely destroy change owners without issues. Client apps should use a capture list specifying `[weak self]` inside handlers to avoid retain cycles causing a memory leak.

     The SDK executes handlers on the main thread.

     SeeAlso: `stopObserving(owner:)`

     ### Usage
     ````
     LDClient.shared.observeFlagsUnchanged(owner: self) { [weak self] in
        //do something after the flags were not updated. The closure will be called once on the main thread if the client is polling and the poll did not change any flag values.
     }
     ````

     - parameter owner: The LDFlagChangeOwner which will execute the handler. The SDK retains a weak reference to the owner.
     - parameter handler: The LDFlagsUnchangedHandler the SDK will execute 1 time when a flag request completes with no flags changed.
     */
    public func observeFlagsUnchanged(owner: LDObserverOwner, handler: @escaping LDFlagsUnchangedHandler) {
        Log.debug(typeName(and: #function) + " owner: \(String(describing: owner))")
        flagChangeNotifier.addFlagsUnchangedObserver(FlagsUnchangedObserver(owner: owner, flagsUnchangedHandler: handler))
    }

    /**
     Removes all observers for the given owner, including the flagsUnchangedObserver

     The client app does not have to call this method. If the client app deinits a LDFlagChangeOwner, the SDK will automatically remove its handlers without ever calling them again.

     - parameter owner: The LDFlagChangeOwner owning the handlers to remove, whether a flag change handler or flags unchanged handler.
    */
    public func stopObserving(owner: LDObserverOwner) {
        Log.debug(typeName(and: #function) + " owner: \(String(describing: owner))")
        flagChangeNotifier.removeObserver(owner: owner)
        errorNotifier.removeObservers(for: owner)
    }

    private(set) var errorNotifier: ErrorNotifying

    public func observeError(owner: LDObserverOwner, handler: @escaping LDErrorHandler) {
        Log.debug(typeName(and: #function) + " owner: \(String(describing: owner))")
        errorNotifier.addErrorObserver(ErrorObserver(owner: owner, errorHandler: handler))
    }

    private func onFlagSyncComplete(result: FlagSyncResult) {
        Log.debug(typeName(and: #function) + "result: \(result)")
        switch result {
        case let .success(flagDictionary, streamingEvent):
            let oldFlags = user.flagStore.featureFlags
            let oldFlagSource = user.flagStore.flagValueSource
            switch streamingEvent {
            case nil, .ping?, .put?:
                user.flagStore.replaceStore(newFlags: flagDictionary, source: .server) {
                    self.updateCacheAndReportChanges(flagCache: self.flagCache, changeNotifier: self.flagChangeNotifier, user: self.user, oldFlags: oldFlags, oldFlagSource: oldFlagSource)
                }
            case .patch?:
                user.flagStore.updateStore(updateDictionary: flagDictionary, source: .server) {
                    self.updateCacheAndReportChanges(flagCache: self.flagCache, changeNotifier: self.flagChangeNotifier, user: self.user, oldFlags: oldFlags, oldFlagSource: oldFlagSource)
                }
            case .delete?:
                user.flagStore.deleteFlag(deleteDictionary: flagDictionary) {
                    self.updateCacheAndReportChanges(flagCache: self.flagCache, changeNotifier: self.flagChangeNotifier, user: self.user, oldFlags: oldFlags, oldFlagSource: oldFlagSource)
                }
            default: break
            }
        case .error(let synchronizingError):
            process(synchronizingError, logPrefix: typeName(and: #function, appending: ": "))
        }
    }

    private func process(_ synchronizingError: SynchronizingError, logPrefix: String) {
        if synchronizingError.isClientUnauthorized {
            Log.debug(logPrefix + "LDClient is unauthorized")
            setOnline(false)
        }
        DispatchQueue.main.async {
            self.errorNotifier.notifyObservers(of: synchronizingError)
        }
    }

    private func updateCacheAndReportChanges(flagCache: UserFlagCaching,
                                             changeNotifier: FlagChangeNotifying,
                                             user: LDUser,
                                             oldFlags: [LDFlagKey: FeatureFlag],
                                             oldFlagSource: LDFlagValueSource) {

        flagCache.cacheFlags(for: user)
        changeNotifier.notifyObservers(user: user, oldFlags: oldFlags, oldFlagSource: oldFlagSource)
    }

    // MARK: - Events

    /* Event tracking
     Conceptual model
     The LDClient appears to keep an event store that it transmits periodically to LD. An app sends an event and optional data by calling trackEvent(key:, data:) supplying at least the key.
     */

    /**
     Adds a custom event to the LDClient event store. A client app can set a tracking event to allow client customized data analysis. Once an app has called `trackEvent`, the app cannot remove the event from the event store.

     LDClient periodically transmits events to LaunchDarkly based on the frequency set in LDConfig.eventFlushInterval. The LDClient must be started and online. Ths SDK stores events tracked while the LDClient is offline, but started.

     Once the SDK's event store is full, the SDK discards events until they can be reported to LaunchDarkly. Configure the size of the event store using `eventCapacity` on the `config`. See `LDConfig` for details.

     ### Usage
     ````
     let appEventData = ["some-custom-key: "some-custom-value", "another-custom-key": 7]
     LDClient.shared.trackEvent(key: "app-event-key", data: appEventData)
     ````

     - parameter key: The key for the event. The SDK does nothing with the key, which can be any string the client app sends
     - parameter data: The data for the event. The SDK does nothing with the data, which can be any valid JSON item the client app sends. (Optional)

     - throws: JSONSerialization.JSONError.invalidJsonObject if the data is not a valid JSON item
    */
    public func trackEvent(key: String, data: Any? = nil) throws {
        guard hasStarted
        else {
            Log.debug(typeName(and: #function) + "aborted. LDClient not started")
            return
        }
        let event = try Event.customEvent(key: key, user: user, data: data)
        Log.debug(typeName(and: #function) + "event: \(event), data: \(String(describing: data))")
        eventReporter.record(event)
    }

    /**
    Report events to LaunchDarkly servers. While online, the LDClient automatically reports events on the `LDConfig.eventFlushInterval`, and whenever the client app moves to the background. There should normally not be a need to call reportEvents.
    */
    public func reportEvents() {
        eventReporter.reportEvents()
    }

    private func onEventSyncComplete(result: EventSyncResult) {
        Log.debug(typeName(and: #function) + "result: \(result)")
        switch result {
        case .success:
            break   //EventReporter handles removing events from the event store, so there's nothing to do here. It's here in case we want to do something in the future.
        case .error(let synchronizingError):
            process(synchronizingError, logPrefix: typeName(and: #function, appending: ": "))
        }
    }

    // MARK: - Foreground / Background notification

    @objc private func didEnterBackground() {
        Log.debug(typeName(and: #function))
        Thread.performOnMain {
            runMode = .background
        }
    }

    @objc private func willEnterForeground() {
        Log.debug(typeName(and: #function))
        Thread.performOnMain {
            runMode = .foreground
        }
    }

    // MARK: - Private
    private(set) var serviceFactory: ClientServiceCreating = ClientServiceFactory()

    private(set) var runMode: LDClientRunMode = .foreground {
        didSet {
            guard runMode != oldValue
            else {
                Log.debug(typeName(and: #function) + " aborted. Old runMode equals new runMode.")
                return
            }
            Log.debug(typeName(and: #function, appending: ": ") + "\(runMode)")
            if runMode == .background {
                eventReporter.reportEvents()
            }
            eventReporter.isOnline = isOnline && runMode == .foreground

            let willSetSynchronizerOnline = isOnline && isInSupportedRunMode
            //The only time the flag synchronizer configuration WILL match is if the client sets flag polling with the polling interval set to the background polling interval.
            //if it does match, keeping the synchronizer precludes an extra flag request
            if !flagSynchronizerConfigMatchesConfigAndRunMode {
                flagSynchronizer.isOnline = false
                flagSynchronizer = serviceFactory.makeFlagSynchronizer(streamingMode: effectiveStreamingMode(runMode: runMode, config: config),
                                                                       pollingInterval: config.flagPollingInterval(runMode: runMode),
                                                                       useReport: config.useReport,
                                                                       service: service,
                                                                       onSyncComplete: onFlagSyncComplete)
            }
            flagSynchronizer.isOnline = willSetSynchronizerOnline
        }
    }
    private var flagSynchronizerConfigMatchesConfigAndRunMode: Bool {
        return flagSynchronizer.streamingMode == effectiveStreamingMode(runMode: runMode, config: config)
            && (flagSynchronizer.streamingMode == .streaming
                || flagSynchronizer.streamingMode == .polling && flagSynchronizer.pollingInterval == config.flagPollingInterval(runMode: runMode))
    }
    private var allowBackgroundFlagUpdates: Bool {
        return config.enableBackgroundUpdates && environmentReporter.operatingSystem.isBackgroundEnabled
    }

    private(set) var flagCache: UserFlagCaching
    private(set) var flagSynchronizer: LDFlagSynchronizing
    private(set) var flagChangeNotifier: FlagChangeNotifying
    private(set) var eventReporter: EventReporting
    private(set) var environmentReporter: EnvironmentReporting
    private(set) var throttler: Throttling

    private init(serviceFactory: ClientServiceCreating? = nil) {
        if let serviceFactory = serviceFactory {
            self.serviceFactory = serviceFactory
        }
        environmentReporter = self.serviceFactory.makeEnvironmentReporter()
        flagCache = self.serviceFactory.makeUserFlagCache()
        LDUserWrapper.configureKeyedArchiversToHandleVersion2_3_0AndOlderUserCacheFormat()
        self.serviceFactory.makeCacheConverter().convertUserCacheToFlagCache()
        flagChangeNotifier = self.serviceFactory.makeFlagChangeNotifier()
        throttler = self.serviceFactory.makeThrottler(maxDelay: Throttler.Constants.defaultDelay, environmentReporter: environmentReporter)

        //dummy objects replaced by client at start
        config = LDConfig(mobileKey: "", environmentReporter: environmentReporter)
        user = LDUser(environmentReporter: environmentReporter)
        service = self.serviceFactory.makeDarklyServiceProvider(config: config, user: user)
        flagSynchronizer = self.serviceFactory.makeFlagSynchronizer(streamingMode: .polling,
                                                                    pollingInterval: config.flagPollingInterval,
                                                                    useReport: config.useReport,
                                                                    service: service)
        eventReporter = self.serviceFactory.makeEventReporter(config: config, service: service)
        errorNotifier = self.serviceFactory.makeErrorNotifier()

        if let backgroundNotification = environmentReporter.backgroundNotification {
            NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: backgroundNotification, object: nil)
        }
        if let foregroundNotification = environmentReporter.foregroundNotification {
            NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: foregroundNotification, object: nil)
        }

        //Since eventReporter lasts the life of the singleton, we can configure it here...swift requires the client to be instantiated before we can pass the onSyncComplete method 
        eventReporter = self.serviceFactory.makeEventReporter(config: config, service: service, onSyncComplete: onEventSyncComplete)
    }

    private convenience init(serviceFactory: ClientServiceCreating, config: LDConfig, user: LDUser, runMode: LDClientRunMode) {
        self.init(serviceFactory: serviceFactory)
        //Setting these inside the init do not trigger the didSet closures
        self.runMode = runMode
        self.config = config
        self.user = user

        //dummy objects replaced by client at start
        service = self.serviceFactory.makeDarklyServiceProvider(config: config, user: user)  //didSet not triggered here
        flagSynchronizer = self.serviceFactory.makeFlagSynchronizer(streamingMode: effectiveStreamingMode(runMode: runMode, config: config),
                                                                    pollingInterval: config.flagPollingInterval(runMode: runMode),
                                                                    useReport: config.useReport,
                                                                    service: service,
                                                                    onSyncComplete: onFlagSyncComplete)
        eventReporter = self.serviceFactory.makeEventReporter(config: config, service: service, onSyncComplete: onEventSyncComplete)
    }
}

extension LDClient: TypeIdentifying { }

private extension Optional {
    var stringValue: String {
        guard let value = self
        else {
            return "<nil>"
        }
        return "\(value)"
    }
}

#if DEBUG
    extension LDClient {
        class func makeClient(with serviceFactory: ClientServiceCreating, config: LDConfig, user: LDUser, runMode: LDClientRunMode = .foreground) -> LDClient {
            return LDClient(serviceFactory: serviceFactory, config: config, user: user, runMode: runMode)
        }

        func setRunMode(_ runMode: LDClientRunMode) {
            self.runMode = runMode
        }

    }
#endif
