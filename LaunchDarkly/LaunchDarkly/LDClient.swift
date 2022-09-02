import Foundation

enum LDClientRunMode {
    case foreground, background
}

/**
 The LDClient is the heart of the SDK, providing client apps running iOS, watchOS, macOS, or tvOS access to LaunchDarkly services. This singleton provides the ability to set a configuration (LDConfig) that controls how the LDClient talks to LaunchDarkly servers, and a user (LDUser) that provides finer control on the feature flag values delivered to LDClient. Once the LDClient has started, it connects to LaunchDarkly's servers to get the feature flag values you set in the Dashboard.
## Usage
### Startup
 1. To customize, configure a `LDConfig` and `LDUser`. The `config` is required, the `user` is optional. Both give you additional control over the feature flags delivered to the LDClient. See `LDConfig` & `LDUser` for more details.
    - The mobileKey set into the `LDConfig` comes from your LaunchDarkly Account settings. If you have multiple projects be sure to choose the correct Mobile key.
 2. Call `LDClient.start(config: user: completion:)`
    - If you do not pass in a LDUser, LDClient will create a default for you.
    - The optional completion closure allows the LDClient to notify your app when it received flag values.
 3. Because LDClient instances are stored statically, you do not have to keep a reference to it in your code. Get the primary instances with `LDClient.get()`

### Getting Feature Flags
 Once the LDClient has started, it makes your feature flags available using the `variation` and `variationDetail` methods. A `variation` is a specific flag value. For example a boolean feature flag has 2 variations, `true` and `false`. You can create feature flags with more than 2 variations using other feature flag types.
 ```
 let boolFlag = LDClient.get()?.boolVariation(forKey: "my-bool-flag", defaultValue: false)
 ```
 If you need to know more information about why a given value is returned, use `variationDetail`.

 See `boolVariation(forKey: defaultValue:)` or `boolVariationDetail(forKey: defaultValue:)` for details

### Observing Feature Flags
 You might need to know when a feature flag value changes. This is not required, you can check the flag's value when you need it.

 If you want to know when a feature flag value changes, you can check the flag's value. You can also use one of several `observe` methods to have the LDClient notify you when a change occurs. There are several options--you can set up notificiations based on when a specific flag changes, when any flag in a collection changes, or when a flag doesn't change.
 ```
 LDClient.get()?.observe("flag-key", owner: self, observer: { [weak self] (changedFlag) in
    self?.updateFlag(key: "flag-key", changedFlag: changedFlag)
 }
 ```
 The `changedFlag` passed in to the closure contains the old and new value of the flag.
 */
public class LDClient {

    // MARK: - State Controls and Indicators

    private static var instances: [String: LDClient]?

    /**
     Reports the online/offline state of the LDClient.

     When online, the SDK communicates with LaunchDarkly servers for feature flag values and event reporting.

     When offline, the SDK does not attempt to communicate with LaunchDarkly servers. Client apps can request feature flag values and set/change feature flag observers while offline. The SDK will collect events while offline.

     Use `setOnline(_: completion:)` to change the online/offline state.
    */
    public private(set) var isOnline: Bool {
        get {
            isOnlineQueue.sync {
                _isOnline
            }
        }
        set {
            isOnlineQueue.sync {
                let oldValue = _isOnline
                _isOnline = newValue
                flagSynchronizer.isOnline = _isOnline
                eventReporter.isOnline = _isOnline
                diagnosticReporter.setMode(runMode, online: _isOnline)
                if _isOnline != oldValue {
                    connectionInformation = ConnectionInformation.onlineSetCheck(connectionInformation: connectionInformation, ldClient: self, config: config, online: _isOnline)
                }
            }
        }
    }

    private var _isOnline = false
    private var isOnlineQueue = DispatchQueue(label: "com.launchdarkly.LDClient.isOnlineQueue")

    /**
     Reports the initialization state of the LDClient.

     When true, the SDK has either communicated with LaunchDarkly servers for feature flag values or the SDK has been set offline.

     When false, the SDK has not been able to communicate with LaunchDarkly servers. Client apps can request feature flag values and set/change feature flag observers but flags might not exist or be stale.
    */
    public var isInitialized: Bool {
        hasStarted && (!isOnline || initialized)
    }

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
        let dispatch = DispatchGroup()
        LDClient.instances?.forEach { _, instance in
            dispatch.enter()
            instance.internalSetOnline(goOnline, completion: dispatch.leave)
        }
        if let completion = completion {
            dispatch.notify(queue: DispatchQueue.global(), execute: completion)
        }
    }

    private func internalSetOnline(_ goOnline: Bool, completion: (() -> Void)? = nil) {
        internalSetOnlineQueue.sync {
            guard goOnline, self.canGoOnline
            else {
                // go offline, which is not throttled
                self.go(online: false, reasonOnlineUnavailable: self.reasonOnlineUnavailable(goOnline: goOnline), completion: completion)
                return
            }

            self.throttler.runThrottled {
                // since going online was throttled, check the last called setOnline value and whether we can go online
                self.go(online: goOnline && self.canGoOnline, reasonOnlineUnavailable: self.reasonOnlineUnavailable(goOnline: goOnline), completion: completion)
            }
        }
    }

    private let internalSetOnlineQueue: DispatchQueue = DispatchQueue(label: "InternalSetOnlineQueue")

    private func go(online goOnline: Bool, reasonOnlineUnavailable: String, completion:(() -> Void)?) {
        let owner = "SetOnlineOwner" as AnyObject
        var completed = false
        let internalCompletedQueue = DispatchQueue(label: "com.launchdarkly.LDClient.goCompletedQueue")

        if !goOnline {
            initialized = true
        }
        let completionCheck = { (completion: (() -> Void)?) in
            internalCompletedQueue.sync {
                if completed == false {
                    completion?()
                    completed = true
                }
            }
        }

        if completion != nil && !goOnline {
            completion?()
        } else if completion != nil {
            observeAll(owner: owner) { _ in
                self.initialized = true
                completionCheck(completion)
                self.stopObserving(owner: owner)
            }
            observeFlagsUnchanged(owner: owner) {
                self.initialized = true
                completionCheck(completion)
                self.stopObserving(owner: owner)
            }
        }
        isOnline = goOnline
        Log.debug(typeName(and: "setOnline", appending: ": ") + (reasonOnlineUnavailable.isEmpty ? "\(self.isOnline)." : "true aborted.") + reasonOnlineUnavailable)
    }

    private var canGoOnline: Bool {
        hasStarted && isInSupportedRunMode && !config.mobileKey.isEmpty
    }

    var isInSupportedRunMode: Bool {
        runMode == .foreground || config.enableBackgroundUpdates
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

    private(set) var runMode: LDClientRunMode = .foreground {
        didSet {
            guard runMode != oldValue
            else {
                Log.debug(typeName(and: #function) + " aborted. Old runMode equals new runMode.")
                return
            }
            Log.debug(typeName(and: #function, appending: ": ") + "\(runMode)")

            let willSetSynchronizerOnline = isOnline && isInSupportedRunMode
            flagSynchronizer.isOnline = false
            let streamingModeVar = ConnectionInformation.effectiveStreamingMode(config: config, ldClient: self)
            connectionInformation = ConnectionInformation.backgroundBehavior(connectionInformation: connectionInformation, streamingMode: streamingModeVar, goOnline: willSetSynchronizerOnline)
            flagSynchronizer = serviceFactory.makeFlagSynchronizer(streamingMode: streamingModeVar,
                                                                   pollingInterval: config.flagPollingInterval(runMode: runMode),
                                                                   useReport: config.useReport,
                                                                   service: service,
                                                                   onSyncComplete: onFlagSyncComplete)
            flagSynchronizer.isOnline = willSetSynchronizerOnline
            diagnosticReporter.setMode(runMode, online: _isOnline)
        }
    }

    // Stores ConnectionInformation in UserDefaults on change
    var connectionInformation: ConnectionInformation {
        didSet {
            Log.debug(connectionInformation.description)
            ConnectionInformationStore.storeConnectionInformation(connectionInformation: connectionInformation)
            if connectionInformation.currentConnectionMode != oldValue.currentConnectionMode {
                flagChangeNotifier.notifyConnectionModeChangedObservers(connectionMode: connectionInformation.currentConnectionMode)
            }
        }
    }

    /// Returns an object containing information about successful and/or failed polling or streaming connections to LaunchDarkly
    public func getConnectionInformation() -> ConnectionInformation { connectionInformation }

    /**
     Stops the LDClient. Stopping the client means the LDClient goes offline and stops recording events. LDClient will no longer provide feature flag values, only returning default values.

     There is almost no reason to stop the LDClient. Normally, set the LDClient offline to stop communication with the LaunchDarkly servers. Stop the LDClient to stop recording events. There is no need to stop the LDClient prior to suspending, moving to the background, or terminating the app. The SDK will respond to these events as the system requires and as configured in LDConfig.
    */
    public func close() {
        LDClient.instances?.forEach { $1.internalClose() }
        LDClient.instances = nil
    }

    private func internalClose() {
        Log.debug(typeName(and: #function, appending: "- ") + "stopping")
        internalFlush()
        internalSetOnline(false)
        hasStarted = false
        Log.debug(typeName(and: #function, appending: "- ") + "stopped")
    }

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

    let config: LDConfig
    let service: DarklyServiceProvider
    private(set) var user: LDUser

    /**
     The LDUser set into the LDClient may affect the set of feature flags returned by the LaunchDarkly server, and ties event tracking to the user. See `LDUser` for details about what information can be retained.

     Normally, the client app should create and set the LDUser and pass that into `start(config: user: completion:)`.

     The client app can change the active `user` by calling identify with a new or updated LDUser. Client apps should follow [Apple's Privacy Policy](apple.com/legal/privacy) when collecting user information.

     When a new user is set, the LDClient goes offline and sets the new user. If the client was online when the new user was set, it goes online again, subject to a throttling delay if in force (see `setOnline(_: completion:)` for details). A completion may be passed to the identify method to allow a client app to know when fresh flag values for the new user are ready.

     - parameter user: The LDUser set with the desired user.
     - parameter completion: Closure called when the embedded `setOnlineIdentify` call completes, subject to throttling delays. (Optional)
    */
    public func identify(user: LDUser, completion: (() -> Void)? = nil) {
        let dispatch = DispatchGroup()
        LDClient.instances?.forEach { _, instance in
            dispatch.enter()
            instance.internalIdentify(newUser: user, completion: dispatch.leave)
        }
        if let completion = completion {
            dispatch.notify(queue: DispatchQueue.global(), execute: completion)
        }
    }

    func internalIdentify(newUser: LDUser, completion: (() -> Void)? = nil) {
        internalIdentifyQueue.sync {
            let previousUser = self.user
            self.user = newUser
            Log.debug(self.typeName(and: #function) + "new user set with key: " + self.user.key )
            let wasOnline = self.isOnline
            self.internalSetOnline(false)

            let cachedUserFlags = self.flagCache.retrieveFeatureFlags(userKey: self.user.key) ?? [:]
            flagStore.replaceStore(newStoredItems: cachedUserFlags)
            self.service.user = self.user
            self.service.clearFlagResponseCache()
            flagSynchronizer = serviceFactory.makeFlagSynchronizer(streamingMode: ConnectionInformation.effectiveStreamingMode(config: config, ldClient: self),
                                                                   pollingInterval: config.flagPollingInterval(runMode: runMode),
                                                                   useReport: config.useReport,
                                                                   service: self.service,
                                                                   onSyncComplete: self.onFlagSyncComplete)

            if self.hasStarted {
                self.eventReporter.record(IdentifyEvent(user: self.user))
            }

            self.internalSetOnline(wasOnline, completion: completion)

            if !config.autoAliasingOptOut && previousUser.isAnonymous && !newUser.isAnonymous {
                self.alias(context: newUser, previousContext: previousUser)
            }
        }
    }

    private let internalIdentifyQueue: DispatchQueue = DispatchQueue(label: "InternalIdentifyQueue")

    /// Returns a dictionary with the flag keys and their values. If the `LDClient` is not started, returns `nil`.
    public var allFlags: [LDFlagKey: LDValue]? {
        guard hasStarted
        else { return nil }
        return flagStore.storedItems.featureFlags.compactMapValues { $0.value }
    }

    // MARK: Observing Updates

    /**
     Sets a handler for the specified flag key executed on the specified owner. If the flag's value changes, executes the handler, passing in the `changedFlag` containing the old and new flag values. See `LDChangedFlag` for details.

     The SDK retains only weak references to the owner, which allows the client app to freely destroy observer owners without issues. Client apps should use a capture list specifying `[weak self]` inside handlers to avoid retain cycles causing a memory leak.

     The SDK executes handlers on the main thread.

     SeeAlso: `LDChangedFlag` and `stopObserving(owner:)`

     ### Usage
     ```
     LDClient.get()?.observe("flag-key", owner: self) { [weak self] (changedFlag) in
        if let .bool(newValue) = changedFlag.newValue {
            // do something with the newValue
        }
     ```

     - parameter key: The LDFlagKey for the flag to observe.
     - parameter owner: The LDObserverOwner which will execute the handler. The SDK retains a weak reference to the owner.
     - parameter handler: The closure the SDK will execute when the feature flag changes.
    */
    public func observe(key: LDFlagKey, owner: LDObserverOwner, handler: @escaping LDFlagChangeHandler) {
        Log.debug(typeName(and: #function) + "flagKey: \(key), owner: \(String(describing: owner))")
        flagChangeNotifier.addFlagChangeObserver(FlagChangeObserver(key: key, owner: owner, flagChangeHandler: handler))
    }

    /**
     Sets a handler for the specified flag keys executed on the specified owner. If any observed flag's value changes, executes the handler 1 time, passing in a dictionary of [LDFlagKey: LDChangedFlag] containing the old and new flag values. See `LDChangedFlag` for details.

     The SDK retains only weak references to owner, which allows the client app to freely destroy observer owners without issues. Client apps should use a capture list specifying `[weak self]` inside handlers to avoid retain cycles causing a memory leak.

     The SDK executes handlers on the main thread.

     SeeAlso: `LDChangedFlag` and `stopObserving(owner:)`

     ### Usage
     ```
     LDClient.get()?.observe(flagKeys, owner: self) { [weak self] (changedFlags) in     // changedFlags is a [LDFlagKey: LDChangedFlag]
        //There will be an LDChangedFlag entry in changedFlags for each changed flag. The closure will only be called once regardless of how many flags changed.
        if let someChangedFlag = changedFlags["some-flag-key"] {    // someChangedFlag is a LDChangedFlag
            //do something with someChangedFlag
         }
     }
     ```

     - parameter keys: An array of LDFlagKeys for the flags to observe.
     - parameter owner: The LDObserverOwner which will execute the handler. The SDK retains a weak reference to the owner.
     - parameter handler: The LDFlagCollectionChangeHandler the SDK will execute 1 time when any of the observed feature flags change.
     */
    public func observe(keys: [LDFlagKey], owner: LDObserverOwner, handler: @escaping LDFlagCollectionChangeHandler) {
        Log.debug(typeName(and: #function) + "flagKeys: \(keys), owner: \(String(describing: owner))")
        flagChangeNotifier.addFlagChangeObserver(FlagChangeObserver(keys: keys, owner: owner, flagCollectionChangeHandler: handler))
    }

    /**
     Sets a handler for all flag keys executed on the specified owner. If any flag's value changes, executes the handler 1 time, passing in a dictionary of [LDFlagKey: LDChangedFlag] containing the old and new flag values. See `LDChangedFlag` for details.

     The SDK retains only weak references to owner, which allows the client app to freely destroy observer owners without issues. Client apps should use a capture list specifying `[weak self]` inside handlers to avoid retain cycles causing a memory leak.

     The SDK executes handlers on the main thread.

     SeeAlso: `LDChangedFlag` and `stopObserving(owner:)`

     ### Usage
     ```
     LDClient.get()?.observeAll(owner: self) { [weak self] (changedFlags) in     // changedFlags is a [LDFlagKey: LDChangedFlag]
        //There will be an LDChangedFlag entry in changedFlags for each changed flag. The closure will only be called once regardless of how many flags changed.
        if let someChangedFlag = changedFlags["some-flag-key"] {    // someChangedFlag is a LDChangedFlag
            //do something with someChangedFlag
        }
     }
     ```

     - parameter owner: The LDObserverOwner which will execute the handler. The SDK retains a weak reference to the owner.
     - parameter handler: The LDFlagCollectionChangeHandler the SDK will execute 1 time when any of the observed feature flags change.
     */
    public func observeAll(owner: LDObserverOwner, handler: @escaping LDFlagCollectionChangeHandler) {
        Log.debug(typeName(and: #function) + " owner: \(String(describing: owner))")
        flagChangeNotifier.addFlagChangeObserver(FlagChangeObserver(keys: LDFlagKey.anyKey, owner: owner, flagCollectionChangeHandler: handler))
    }

    /**
     Sets a handler executed when a flag update leaves the flags unchanged from their previous values.

     This handler can only ever be called when the LDClient is polling.

     The SDK retains only weak references to owner, which allows the client app to freely destroy observer owners without issues. Client apps should use a capture list specifying `[weak self]` inside handlers to avoid retain cycles causing a memory leak.

     The SDK executes handlers on the main thread.

     SeeAlso: `stopObserving(owner:)`

     ### Usage
     ```
     LDClient.get()?.observeFlagsUnchanged(owner: self) { [weak self] in
         // Do something after an update was received that did not update any flag values.
         //The closure will be called once on the main thread after the update.
     }
     ```

     - parameter owner: The LDObserverOwner which will execute the handler. The SDK retains a weak reference to the owner.
     - parameter handler: The LDFlagsUnchangedHandler the SDK will execute 1 time when a flag request completes with no flags changed.
     */
    public func observeFlagsUnchanged(owner: LDObserverOwner, handler: @escaping LDFlagsUnchangedHandler) {
        Log.debug(typeName(and: #function) + " owner: \(String(describing: owner))")
        flagChangeNotifier.addFlagsUnchangedObserver(FlagsUnchangedObserver(owner: owner, flagsUnchangedHandler: handler))
    }

    /**
     Sets a handler executed when ConnectionInformation.currentConnectionMode changes.

     The SDK retains only weak references to owner, which allows the client app to freely destroy change owners without issues. Client apps should use a capture list specifying `[weak self]` inside handlers to avoid retain cycles causing a memory leak.

     The SDK executes handlers on the main thread.

     SeeAlso: `stopObserving(owner:)`

     ### Usage
     ```
     LDClient.get()?.observeCurrentConnectionMode(owner: self) { [weak self] in
        //do something after ConnectionMode was updated.
     }
     ```

     - parameter owner: The LDObserverOwner which will execute the handler. The SDK retains a weak reference to the owner.
     - parameter handler: The LDConnectionModeChangedHandler the SDK will execute 1 time when ConnectionInformation.currentConnectionMode is changed.
     */
    public func observeCurrentConnectionMode(owner: LDObserverOwner, handler: @escaping LDConnectionModeChangedHandler) {
        Log.debug(typeName(and: #function) + " owner: \(String(describing: owner))")
        flagChangeNotifier.addConnectionModeChangedObserver(ConnectionModeChangedObserver(owner: owner, connectionModeChangedHandler: handler))
    }

    /**
     Removes all observers for the given owner, including the flagsUnchangedObserver

     The client app does not have to call this method. If the client app deinits a LDFlagChangeOwner, the SDK will automatically remove its handlers without ever calling them again.

     - parameter owner: The LDFlagChangeOwner owning the handlers to remove, whether a flag change handler or flags unchanged handler.
    */
    public func stopObserving(owner: LDObserverOwner) {
        Log.debug(typeName(and: #function) + " owner: \(String(describing: owner))")
        flagChangeNotifier.removeObserver(owner: owner)
    }

    private func onFlagSyncComplete(result: FlagSyncResult) {
        Log.debug(typeName(and: #function) + "result: \(result)")
        switch result {
        case let .flagCollection(flagCollection):
            let oldStoredItems = flagStore.storedItems
            connectionInformation = ConnectionInformation.checkEstablishingStreaming(connectionInformation: connectionInformation)
            flagStore.replaceStore(newStoredItems: StoredItems(items: flagCollection.flags))
            self.updateCacheAndReportChanges(user: self.user, oldStoredItems: oldStoredItems)
        case let .patch(featureFlag):
            let oldStoredItems = flagStore.storedItems
            connectionInformation = ConnectionInformation.checkEstablishingStreaming(connectionInformation: connectionInformation)
            flagStore.updateStore(updatedFlag: featureFlag)
            self.updateCacheAndReportChanges(user: self.user, oldStoredItems: oldStoredItems)
        case let .delete(deleteResponse):
            let oldStoredItems = flagStore.storedItems
            connectionInformation = ConnectionInformation.checkEstablishingStreaming(connectionInformation: connectionInformation)
            flagStore.deleteFlag(deleteResponse: deleteResponse)
            self.updateCacheAndReportChanges(user: self.user, oldStoredItems: oldStoredItems)
        case .upToDate:
            connectionInformation.lastKnownFlagValidity = Date()
            flagChangeNotifier.notifyUnchanged()
        case .error(let synchronizingError):
            process(synchronizingError, logPrefix: typeName(and: #function, appending: ": "))
        }
    }

    private func process(_ synchronizingError: SynchronizingError, logPrefix: String) {
        if synchronizingError.isClientUnauthorized {
            Log.debug(logPrefix + "LDClient is unauthorized")
            internalSetOnline(false)
        }
        connectionInformation = ConnectionInformation.synchronizingErrorCheck(synchronizingError: synchronizingError, connectionInformation: connectionInformation)
    }

    private func updateCacheAndReportChanges(user: LDUser,
                                             oldStoredItems: StoredItems) {
        flagCache.storeFeatureFlags(flagStore.storedItems, userKey: user.key, lastUpdated: Date())
        flagChangeNotifier.notifyObservers(oldFlags: oldStoredItems.featureFlags, newFlags: flagStore.storedItems.featureFlags)
    }

    // MARK: Events

    /**
     Adds a custom event to the LDClient event store. A client app can set a tracking event to allow client customized data analysis. Once an app has called `track`, the app cannot remove the event from the event store.

     LDClient periodically transmits events to LaunchDarkly based on the frequency set in `LDConfig.eventFlushInterval`. The LDClient must be started and online. Ths SDK stores events tracked while the LDClient is offline, but started.

     Once the SDK's event store is full, the SDK discards events until they can be reported to LaunchDarkly. Configure the size of the event store using `eventCapacity` on the `config`. See `LDConfig` for details.

     ### Usage
     ```
     let appEventData: LDValue = ["some-custom-key: "some-custom-value", "another-custom-key": 7]
     LDClient.get()?.track(key: "app-event-key", data: appEventData)
     ```

     - parameter key: The key for the event.
     - parameter data: The data for the event. (Optional)
     - parameter metricValue: A numeric value used by the LaunchDarkly experimentation feature in numeric custom metrics. Can be omitted if this event is used by only non-numeric metrics. This field will also be returned as part of the custom event for Data Export. (Optional)
    */
    public func track(key: String, data: LDValue? = nil, metricValue: Double? = nil) {
        guard hasStarted
        else {
            Log.debug(typeName(and: #function) + "aborted. LDClient not started")
            return
        }
        let event = CustomEvent(key: key, user: user, data: data ?? .null, metricValue: metricValue)
        Log.debug(typeName(and: #function) + "key: \(key), data: \(String(describing: data)), metricValue: \(String(describing: metricValue))")
        eventReporter.record(event)
    }

    /**
     Tells the SDK to generate an alias event.

     Associates two users for analytics purposes.

     This can be helpful in the situation where a person is represented by multiple
     LaunchDarkly users. This may happen, for example, when a person initially logs into
     an application-- the person might be represented by an anonymous user prior to logging
     in and a different user after logging in, as denoted by a different user key.

     - parameter context: the user that will be aliased to
     - parameter previousContext: the user that will be bound to the new context
     */
    public func alias(context new: LDUser, previousContext old: LDUser) {
        guard hasStarted
        else {
            Log.debug(typeName(and: #function) + "aborted. LDClient not started")
            return
        }

        self.eventReporter.record(AliasEvent(key: new.key, previousKey: old.key, contextKind: new.contextKind, previousContextKind: old.contextKind))
    }

    /**
     Tells the SDK to immediately send any currently queued events to LaunchDarkly.

     There should not normally be a need to call this function. While online, the LDClient automatically reports events
     on an interval defined by `LDConfig.eventFlushInterval`. Note that this function does not block until events are
     sent, it only triggers a background task to send events immediately.
     */
    public func flush() {
        LDClient.instances?.forEach { $1.internalFlush() }
    }

    private func internalFlush() {
        eventReporter.flush(completion: nil)
    }

    private func onEventSyncComplete(result: SynchronizingError?) {
        if let synchronizingError = result {
            Log.debug(typeName(and: #function) + "result: \(synchronizingError)")
            process(synchronizingError, logPrefix: typeName(and: #function, appending: ": "))
        } else {
            Log.debug(typeName(and: #function) + "result: success")
        }
    }

    @objc private func didCloseEventSource() {
        Log.debug(typeName(and: #function))
        self.connectionInformation = ConnectionInformation.lastSuccessfulConnectionCheck(connectionInformation: self.connectionInformation)
    }

    // MARK: Initializing and Accessing

    /**
     Starts the LDClient using the passed in `config` & `user`. Call this before requesting feature flag values. The LDClient will not go online until you call this method.
     Starting the LDClient means setting the `config` & `user`, setting the client online if `config.startOnline` is true (the default setting), and starting event recording. The client app must start the LDClient before it will report feature flag values. If a client does not call `start`, no methods will work.
     If the `start` call omits the `user`, the LDClient uses a default `LDUser`.
     If the` start` call includes the optional `completion` closure, LDClient calls the `completion` closure when `setOnline(_: completion:)` embedded in the `init` method completes. This method listens for flag updates so the completion will only return once an update has occurred. The `start` call is subject to throttling delays, therefore the `completion` closure call may be delayed.
     Subsequent calls to this method cause the LDClient to return. Normally there should only be one call to start. To change `user`, use `identify`.
     - parameter configuration: The LDConfig that contains the desired configuration. (Required)
     - parameter user: The LDUser set with the desired user. If omitted, LDClient sets a default user. (Optional)
     - parameter completion: Closure called when the embedded `setOnline` call completes. (Optional)
    */
    /// - Tag: start
    public static func start(config: LDConfig, user: LDUser? = nil, completion: (() -> Void)? = nil) {
        start(serviceFactory: nil, config: config, user: user, completion: completion)
    }

    static func start(serviceFactory: ClientServiceCreating?, config: LDConfig, user: LDUser? = nil, completion: (() -> Void)? = nil) {
        Log.debug("LDClient starting")
        if serviceFactory != nil {
            get()?.close()
        }
        if instances != nil {
            Log.debug("LDClient.start() was called more than once!")
            return
        }

        let serviceFactory = serviceFactory ?? ClientServiceFactory()
        var keys = [config.mobileKey]
        keys.append(contentsOf: config.getSecondaryMobileKeys().values)
        serviceFactory.makeCacheConverter().convertCacheData(serviceFactory: serviceFactory, keysToConvert: keys, maxCachedUsers: config.maxCachedUsers)

        LDClient.instances = [:]
        var mobileKeys = config.getSecondaryMobileKeys()
        var internalCount = 0
        let completionCheck = {
            internalCount += 1
            if internalCount > mobileKeys.count {
                Log.debug("All LDClients finished starting")
                completion?()
            }
        }
        mobileKeys[LDConfig.Constants.primaryEnvironmentName] = config.mobileKey
        for (name, mobileKey) in mobileKeys {
            var internalConfig = config
            internalConfig.mobileKey = mobileKey
            let instance = LDClient(serviceFactory: serviceFactory, configuration: internalConfig, startUser: user, completion: completionCheck)
            LDClient.instances?[name] = instance
        }
        completionCheck()
    }

    /**
    See [start](x-source-tag://start) for more information on starting the SDK.

    - parameter configuration: The LDConfig that contains the desired configuration. (Required)
    - parameter user: The LDUser set with the desired user. If omitted, LDClient sets a default user. (Optional)
    - parameter startWaitSeconds: A TimeInterval that determines when the completion will return if no flags have been returned from the network.
    - parameter completion: Closure called when the embedded `setOnline` call completes. Takes a Bool that indicates whether the completion timedout as a parameter. (Optional)
    */
    public static func start(config: LDConfig, user: LDUser? = nil, startWaitSeconds: TimeInterval, completion: ((_ timedOut: Bool) -> Void)? = nil) {
        start(serviceFactory: nil, config: config, user: user, startWaitSeconds: startWaitSeconds, completion: completion)
    }

    static func start(serviceFactory: ClientServiceCreating?, config: LDConfig, user: LDUser? = nil, startWaitSeconds: TimeInterval, completion: ((_ timedOut: Bool) -> Void)? = nil) {
        var completed = true
        let internalCompletedQueue: DispatchQueue = DispatchQueue(label: "TimeOutQueue")
        if !config.startOnline {
            start(serviceFactory: serviceFactory, config: config, user: user)
            completion?(completed)
        } else {
            let startTime = Date().timeIntervalSince1970
            start(serviceFactory: serviceFactory, config: config, user: user) {
                internalCompletedQueue.async {
                    if startTime + startWaitSeconds > Date().timeIntervalSince1970 && completed {
                        completed = false
                        completion?(completed)
                    }
                }
            }
            internalCompletedQueue.asyncAfter(deadline: .now() + startWaitSeconds) {
                if completed {
                    completion?(completed)
                }
            }
        }
    }

    /**
     Returns the LDClient instance for a given environment.

     - parameter environment: The name of an environment provided in LDConfig.secondaryMobileKeys, defaults to `LDConfig.Constants.primaryEnvironmentName` which is always associated with the `LDConfig.mobileKey` environment.
     - returns: The requested LDClient instance.
     */
    public static func get(environment: String = LDConfig.Constants.primaryEnvironmentName) -> LDClient? {
        guard let internalInstances = LDClient.instances else {
            Log.debug("LDClient.get() was called before init()!")
            return nil
        }
        return internalInstances[environment]
    }

    // MARK: - Private
    let serviceFactory: ClientServiceCreating

    private(set) var flagCache: FeatureFlagCaching
    private(set) var flagSynchronizer: LDFlagSynchronizing
    var flagChangeNotifier: FlagChangeNotifying
    private(set) var eventReporter: EventReporting
    private(set) var environmentReporter: EnvironmentReporting
    private(set) var throttler: Throttling
    private(set) var diagnosticReporter: DiagnosticReporting
    let flagStore: FlagMaintaining

    private(set) var hasStarted: Bool {
        get { hasStartedQueue.sync { _hasStarted } }
        set { hasStartedQueue.sync { _hasStarted = newValue } }
    }
    private var _hasStarted = true
    private var hasStartedQueue = DispatchQueue(label: "com.launchdarkly.LDClient.hasStartedQueue")
    private(set) var initialized: Bool {
        get { initializedQueue.sync { _initialized } }
        set { initializedQueue.sync { _initialized = newValue } }
    }
    private var _initialized = false
    private var initializedQueue = DispatchQueue(label: "com.launchdarkly.LDClient.initializedQueue")

    private init(serviceFactory: ClientServiceCreating, configuration: LDConfig, startUser: LDUser?, completion: (() -> Void)? = nil) {
        self.serviceFactory = serviceFactory
        environmentReporter = self.serviceFactory.makeEnvironmentReporter()
        flagCache = self.serviceFactory.makeFeatureFlagCache(mobileKey: configuration.mobileKey, maxCachedUsers: configuration.maxCachedUsers)
        flagStore = self.serviceFactory.makeFlagStore()
        flagChangeNotifier = self.serviceFactory.makeFlagChangeNotifier()
        throttler = self.serviceFactory.makeThrottler(environmentReporter: environmentReporter)

        config = configuration
        let anonymousUser = LDUser(environmentReporter: environmentReporter)
        user = startUser ?? anonymousUser
        service = self.serviceFactory.makeDarklyServiceProvider(config: config, user: user)
        diagnosticReporter = self.serviceFactory.makeDiagnosticReporter(service: service)
        eventReporter = self.serviceFactory.makeEventReporter(service: service)
        connectionInformation = self.serviceFactory.makeConnectionInformation()
        flagSynchronizer = self.serviceFactory.makeFlagSynchronizer(streamingMode: config.allowStreamingMode ? config.streamingMode : .polling,
                                                                    pollingInterval: config.flagPollingInterval(runMode: runMode),
                                                                    useReport: config.useReport,
                                                                    service: service)

        if let backgroundNotification = environmentReporter.backgroundNotification {
            NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: backgroundNotification, object: nil)
        }
        if let foregroundNotification = environmentReporter.foregroundNotification {
            NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: foregroundNotification, object: nil)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(didCloseEventSource), name: Notification.Name(FlagSynchronizer.Constants.didCloseEventSourceName), object: nil)

        eventReporter = self.serviceFactory.makeEventReporter(service: service, onSyncComplete: onEventSyncComplete)
        flagSynchronizer = self.serviceFactory.makeFlagSynchronizer(streamingMode: config.allowStreamingMode ? config.streamingMode : .polling,
                                                                    pollingInterval: config.flagPollingInterval(runMode: runMode),
                                                                    useReport: config.useReport,
                                                                    service: service,
                                                                    onSyncComplete: onFlagSyncComplete)

        Log.level = environmentReporter.isDebugBuild && config.isDebugMode ? .debug : .noLogging
        if let cachedFlags = flagCache.retrieveFeatureFlags(userKey: user.key), !cachedFlags.isEmpty {
            flagStore.replaceStore(newStoredItems: cachedFlags)
        }

        eventReporter.record(IdentifyEvent(user: user))
        self.connectionInformation = ConnectionInformation.uncacheConnectionInformation(config: config, ldClient: self, clientServiceFactory: self.serviceFactory)

        internalSetOnline(configuration.startOnline) {
            Log.debug("LDClient started")
            completion?()
        }
    }
}

extension LDClient: TypeIdentifying { }

#if DEBUG
extension LDClient {
    func setRunMode(_ runMode: LDClientRunMode) {
        self.runMode = runMode
    }
}
#endif
