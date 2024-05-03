import Foundation

/**
 The LDClient is the heart of the SDK, providing client apps running iOS, watchOS, macOS, or tvOS access to LaunchDarkly services. This singleton provides the ability to set a configuration (LDConfig) that controls how the LDClient talks to LaunchDarkly servers, and a context (LDContext) that provides finer control on the feature flag values delivered to LDClient. Once the LDClient has started, it connects to LaunchDarkly's servers to get the feature flag values you set in the Dashboard.

 ### Objc Classes
 The SDK creates an Objective-C native style API by wrapping Swift specific classes, properties, and methods into Objective-C wrapper classes prefixed by `Objc`. By defining Objective-C specific names, client apps written in Objective-C can use a native coding style, including using familiar LaunchDarkly SDK names like `LDClient`, `LDConfig`, and `LDContext`. Objective-C developers should refer to the Objc documentation by following the Objc specific links following type, property, and method names.
 ## Usage
 ### Startup
 1. To customize, configure a LDConfig (`ObjcLDConfig`) and LDContext (`ObjcLDContxt`). Both give you additional control over the feature flags delivered to the LDClient. See `ObjcLDConfig` & `ObjcLDContext` for more details.
 - The mobileKey set into the `LDConfig` comes from your LaunchDarkly Account settings (on the left, at the bottom). If you have multiple projects be sure to choose the correct Mobile key.
 2. Call `[ObjcLDClient startWithConfig: context: completion:]` (`ObjcLDClient.startWithConfig(_:config:context:completion:)`)
 - If you do not pass in a LDContext, LDCLient will create a default for you.
 - The optional completion closure allows the LDClient to notify your app when it has gone online.
 3. Because the LDClient is a singleton, you do not have to keep a reference to it in your code.

 ### Getting Feature Flags
 Once the LDClient has started, it makes your feature flags available using the `variation` and `variationDetail` methods. A `variation` is a specific flag value. For example, a boolean feature flag has 2 variations, `YES` and `NO`. You can create feature flags with more than 2 variations using other feature flag types. See `LDValue` for the available types.
 ```
 BOOL boolFlag = [ldClientInstance boolVariationForKey:@"my-bool-flag" defaultValue:NO];
 ```
 If you need to know more information about why a given value is returned, the typed `variationDetail` methods return an `LD<T>EvaluationDetail` with an detail about the evaluation.
 ```
 LDBoolEvaluationDetail *boolVariationDetail = [ldClientInstance boolVariationDetail:@"my-bool-flag" defaultValue:NO];
 BOOL boolFlagValue = boolVariationDetail.value;
 NSInteger boolFlagVariation = boolVariationDetail.variationIndex
 NSDictionary boolFlagReason = boolVariationValue.reason;
 ```

 See the typed `-[LDCLient variationForKey: defaultValue:]` or `-[LDClient variationDetailForKey: defaultValue:]` methods in the section **Feature Flag values** for details.

 ### Observing Feature Flags
 If you want to know when a feature flag value changes, you can check the flag's value. You can also use one of several `observe` methods to have the LDClient notify you when a change occurs. There are several options-- you can setup notifications based on when a specific flag changes, when any flag in a collection changes, or when a flag doesn't change. The flag change listener may be invoked multiple times per invocation of LDClient.identify as the SDK fetches up to date flag data from multiple sources (e.g. local cache, cloud services). In certain error cases, the SDK may not be able to retrieve flag data during an identify (e.g. no network connectivity). In those cases, the flag change listener may not be invoked.
 ```
 __weak typeof(self) weakSelf = self;
 [ldClientInstance observeBool:@"my-bool-flag" owner:self handler:^(LDBoolChangedFlag *changedFlag) {
    __strong typeof(weakSelf) strongSelf = weakSelf;
    [strongSelf updateFlagWithKey:@"my-bool-flag" changedFlag:changedFlag];
 }];
 ```
 The `changedFlag` passed in to the block contains the old and new value. See the typed `LDChangedFlag` classes in the **Obj-C Changed Flags**.
 */
@objc(LDClient)
public final class ObjcLDClient: NSObject {

    // MARK: - State Controls and Indicators

    private var ldClient: LDClient

    /**
     Reports the online/offline state of the LDClient.

     When online, the SDK communicates with LaunchDarkly servers for feature flag values and event reporting.

     When offline, the SDK does not attempt to communicate with LaunchDarkly servers. Client apps can request feature flag values and set/change feature flag observers while offline. The SDK will collect events while offline.

     Use `-[LDClient setOnline: completion:]` (`ObjcLDClient.setOnline(_:completion:)`) to change the online/offline state.
     */
    @objc public var isOnline: Bool { ldClient.isOnline }

    /**
     Set the LDClient online/offline.

     When online, the SDK communicates with LaunchDarkly servers for feature flag values and event reporting.
     When offline, the SDK does not attempt to communicate with LaunchDarkly servers. Client apps can request feature flag values and set/change feature flag observers while offline. The SDK will collect events while offline.
     The SDK protects itself from multiple rapid calls to `setOnline:YES` by enforcing an increasing delay (called *throttling*) each time `setOnline:YES` is called within a short time. The first time, the call proceeds normally. For each subsequent call the delay is enforced, and if waiting, increased to a maximum delay. When the delay has elapsed, the `setOnline:YES` will proceed, assuming that the client app has not called `setOnline:NO` during the delay. Therefore a call to `setOnline:YES` may not immediately result in the LDClient going online. Client app developers should consider this situation abnormal, and take steps to prevent the client app from making multiple rapid `setOnline:YES` calls. Calls to `setOnline:NO` are not throttled. After the delay, the SDK resets and the client app can make a susequent call to `setOnline:YES` without being throttled.
     Use `isOnline` to get the online/offline state.

     - parameter goOnline:    Desired online/offline mode for the LDClient
    */
    @objc public func setOnline(_ goOnline: Bool) {
        ldClient.setOnline(goOnline, completion: nil)
    }

    /**
     Set the LDClient online/offline.

     When online, the SDK communicates with LaunchDarkly servers for feature flag values and event reporting.

     When offline, the SDK does not attempt to communicate with LaunchDarkly servers. Client apps can request feature flag values and set/change feature flag observers while offline. The SDK will collect events while offline.

     The SDK protects itself from multiple rapid calls to `setOnline:YES` by enforcing an increasing delay (called *throttling*) each time `setOnline:YES` is called within a short time. The first time, the call proceeds normally. For each subsequent call the delay is enforced, and if waiting, increased to a maximum delay. When the delay has elapsed, the `setOnline:YES` will proceed, assuming that the client app has not called `setOnline:NO` during the delay. Therefore a call to `setOnline:YES` may not immediately result in the LDClient going online. Client app developers should consider this situation abnormal, and take steps to prevent the client app from making multiple rapid `setOnline:YES` calls. Calls to `setOnline:NO` are not throttled. Note that calls to `start(config: context: completion:)`, and setting the `config` or `context` can also call `setOnline:YES` under certain conditions. After the delay, the SDK resets and the client app can make a susequent call to `setOnline:YES` without being throttled.

     Client apps can set a completion block called when the setOnline call completes. For unthrottled `setOnline:YES` and all `setOnline:NO` calls, the SDK will call the block immediately on completion of this method. For throttled `setOnline:YES` calls, the SDK will call the block after the throttling delay at the completion of the setOnline method.

     Use `isOnline` (`ObjcLDClient.isOnline`)to get the online/offline state.

     - parameter goOnline:    Desired online/offline mode for the LDClient
     - parameter completion:  Completion block called when setOnline completes. (Optional)
     */
    @objc public func setOnline(_ goOnline: Bool, completion: (() -> Void)? = nil) {
        ldClient.setOnline(goOnline, completion: completion)
    }

    /**
     Reports the initialization state of the LDClient.

     When true, the SDK has either communicated with LaunchDarkly servers for feature flag values or the SDK has been set offline.

     When false, the SDK has not been able to communicate with LaunchDarkly servers. Client apps can request feature flag values and set/change feature flag observers but flags might not exist or be stale.
    */
    @objc public var isInitialized: Bool {
        ldClient.isInitialized
    }

    /**
        The LDContext set into the LDClient may affect the set of feature flags returned by the LaunchDarkly server, and ties event tracking to the context. See `LDContext` for details about what information can be retained.

        The client app can change the current LDContext by calling this method. Client apps should follow [Apple's Privacy Policy](apple.com/legal/privacy) when collecting user information. When a new context is set, the LDClient goes offline and sets the new context. If the client was online when the new context was set, it goes online again, subject to a throttling delay if in force (see `setOnline(_: completion:)` for details).

        - parameter context: The ObjcLDContext set with the desired context.
       */
    @objc public func identify(context: ObjcLDContext) {
        ldClient.identify(context: context.context, completion: nil)
    }

    /**
        The LDContext set into the LDClient may affect the set of feature flags returned by the LaunchDarkly server, and ties event tracking to the context. See `LDContext` for details about what information can be retained.

        Normally, the client app should create and set the LDContext and pass that into `start(config: context: completion:)`.

        The client app can change the active `context` by calling identify with a new or updated LDContext. Client apps should follow [Apple's Privacy Policy](apple.com/legal/privacy) when collecting user information. If the client app does not create a LDContext, LDClient creates an anonymous default context, which can affect the feature flags delivered to the LDClient.

        When a new context is set, the LDClient goes offline and sets the new context. If the client was online when the new context was set, it goes online again, subject to a throttling delay if in force (see `setOnline(_: completion:)` for details). To change both the `config` and `context`, set the LDClient offline, set both properties, then set the LDClient online. A completion may be passed to the identify method to allow a client app to know when fresh flag values for the new context are ready.

        - parameter context: The ObjcLDContext set with the desired context.
        - parameter completion: Closure called when the embedded `setOnlineIdentify` call completes, subject to throttling delays. (Optional)
       */
    @objc public func identify(context: ObjcLDContext, completion: (() -> Void)? = nil) {
        ldClient.identify(context: context.context, completion: completion)
    }

    /**
     Stops the LDClient. Stopping the client means the LDClient goes offline and stops recording events. LDClient will no longer provide feature flag values, only returning default values.

     There is almost no reason to stop the LDClient. Normally, set the LDClient offline to stop communication with the LaunchDarkly servers. Stop the LDClient to stop recording events. There is no need to stop the LDClient prior to suspending, moving to the background, or terminating the app. The SDK will respond to these events as the system requires and as configured in LDConfig.
     */
    @objc public func close() {
        ldClient.close()
    }

    /**
     Returns an ObjcLDClient wrapper that contains the primary LDClient instance.

     - returns: An ObjcLDClient.
    */
    @objc public static func get() -> ObjcLDClient? {
        guard let instance = LDClient.get() else { return nil }
        return ObjcLDClient(client: instance)
    }

    /**
     Returns an LDClient instance for a given environment.

     - parameter environment: The name of an environment provided in LDConfig.secondaryMobileKeys, defaults to `LDConfig.Constants.primaryEnvironmentName`, which is always associated with the `LDConfig.mobileKey` environment.

     - returns: The requested LDClient instance.
     */
    @objc public static func get(environment: String = LDConfig.Constants.primaryEnvironmentName) -> ObjcLDClient? {
        guard let instance = LDClient.get(environment: environment) else { return nil }
        return ObjcLDClient(client: instance)
    }

    // MARK: Feature Flag values

    /**
     Returns the BOOL variation for the given feature flag. If the flag does not exist, cannot be cast to a BOOL, or the LDClient is not started, returns the default value.

     A *variation* is a specific flag value. For example a boolean feature flag has 2 variations, *YES* and *NO*. You can create feature flags with more than 2 variations using other feature flag types. See `LDValue` for the available types.

     A call to `boolVariation` records events reported later. Recorded events allow clients to analyze usage and assist in debugging issues.

     ### Usage
     ```
     BOOL boolFeatureFlagValue = [ldClientInstance boolVariationForKey:@"my-bool-flag" defaultValue:NO];
     ```

     - parameter key: The LDFlagKey for the requested feature flag.
     - parameter defaultValue: The default value to return if the feature flag key does not exist.

     - returns: The requested BOOL feature flag value, or the default value if the flag is missing or cannot be cast to a BOOL, or the client is not started
     */
    /// - Tag: boolVariation
    @objc public func boolVariation(forKey key: LDFlagKey, defaultValue: Bool) -> Bool {
        ldClient.boolVariation(forKey: key, defaultValue: defaultValue)
    }

    /**
     See [boolVariation](x-source-tag://boolVariation) for more information on variation methods.

     - parameter key: The LDFlagKey for the requested feature flag.
     - parameter defaultValue: The default value to return if the feature flag key does not exist.

     - returns: ObjcLDBoolEvaluationDetail containing your value as well as useful information on why that value was returned.
    */
    @objc public func boolVariationDetail(forKey key: LDFlagKey, defaultValue: Bool) -> ObjcLDBoolEvaluationDetail {
        let evaluationDetail = ldClient.boolVariationDetail(forKey: key, defaultValue: defaultValue)
        return ObjcLDBoolEvaluationDetail(value: evaluationDetail.value,
                                          variationIndex: evaluationDetail.variationIndex,
                                          reason: evaluationDetail.reason?.mapValues { ObjcLDValue(wrappedValue: $0) })
    }

    /**
     Returns the NSInteger variation for the given feature flag. If the flag does not exist, cannot be cast to a NSInteger, or the LDClient is not started, returns the default value.

     A *variation* is a specific flag value. For example a boolean feature flag has 2 variations, *YES* and *NO*. You can create feature flags with more than 2 variations using other feature flag types. See `LDValue` for the available types.

     A call to `integerVariation` records events reported later. Recorded events allow clients to analyze usage and assist in debugging issues.

     ### Usage
     ````
     NSInteger integerFeatureFlagValue = [ldClientInstance integerVariationForKey:@"my-integer-flag" defaultValue:5];
     ````

     - parameter key: The LDFlagKey for the requested feature flag.
     - parameter defaultValue: The default value to return if the feature flag key does not exist.

     - returns: The requested NSInteger feature flag value, or the default value if the flag is missing or cannot be cast to a NSInteger, or the client is not started
     */
    /// - Tag: integerVariation
    @objc public func integerVariation(forKey key: LDFlagKey, defaultValue: Int) -> Int {
        ldClient.intVariation(forKey: key, defaultValue: defaultValue)
    }

    /**
     See [integerVariation](x-source-tag://integerVariation) for more information on variation methods.

     - parameter key: The LDFlagKey for the requested feature flag.
     - parameter defaultValue: The default value to return if the feature flag key does not exist.

     - returns: ObjcLDIntegerEvaluationDetail containing your value as well as useful information on why that value was returned.
     */
    @objc public func integerVariationDetail(forKey key: LDFlagKey, defaultValue: Int) -> ObjcLDIntegerEvaluationDetail {
        let evaluationDetail = ldClient.intVariationDetail(forKey: key, defaultValue: defaultValue)
        return ObjcLDIntegerEvaluationDetail(value: evaluationDetail.value,
                                             variationIndex: evaluationDetail.variationIndex,
                                             reason: evaluationDetail.reason?.mapValues { ObjcLDValue(wrappedValue: $0) })
    }

    /**
     Returns the double variation for the given feature flag. If the flag does not exist, cannot be cast to a double, or the LDClient is not started, returns the default value.

     A *variation* is a specific flag value. For example a boolean feature flag has 2 variations, *YES* and *NO*. You can create feature flags with more than 2 variations using other feature flag types. See `LDValue` for the available types.

     A call to `doubleVariation` records events reported later. Recorded events allow clients to analyze usage and assist in debugging issues.

     ### Usage
     ```
     double doubleFeatureFlagValue = [ldClientInstance doubleVariationForKey:@"my-double-flag" defaultValue:2.71828];
     ```

     - parameter key: The LDFlagKey for the requested feature flag.
     - parameter defaultValue: The default value to return if the feature flag key does not exist.

     - returns: The requested double feature flag value, or the default value if the flag is missing or cannot be cast to a double, or the client is not started
     */
    /// - Tag: doubleVariation
    @objc public func doubleVariation(forKey key: LDFlagKey, defaultValue: Double) -> Double {
        ldClient.doubleVariation(forKey: key, defaultValue: defaultValue)
    }

    /**
     See [doubleVariation](x-source-tag://doubleVariation) for more information on variation methods.

     - parameter key: The LDFlagKey for the requested feature flag.
     - parameter defaultValue: The default value to return if the feature flag key does not exist.

     - returns: ObjcLDDoubleEvaluationDetail containing your value as well as useful information on why that value was returned.
     */
    @objc public func doubleVariationDetail(forKey key: LDFlagKey, defaultValue: Double) -> ObjcLDDoubleEvaluationDetail {
        let evaluationDetail = ldClient.doubleVariationDetail(forKey: key, defaultValue: defaultValue)
        return ObjcLDDoubleEvaluationDetail(value: evaluationDetail.value,
                                            variationIndex: evaluationDetail.variationIndex,
                                            reason: evaluationDetail.reason?.mapValues { ObjcLDValue(wrappedValue: $0) })
    }

    /**
     Returns the NSString variation for the given feature flag. If the flag does not exist, cannot be cast to a NSString, or the LDClient is not started, returns the default value.

     A *variation* is a specific flag value. For example a boolean feature flag has 2 variations, *YES* and *NO*. You can create feature flags with more than 2 variations using other feature flag types. See `LDValue` for the available types.

     A call to `stringVariation` records events reported later. Recorded events allow clients to analyze usage and assist in debugging issues.

     ### Usage
     ```
     NSString *stringFeatureFlagValue = [ldClientInstance stringVariationForKey:@"my-string-flag" defaultValue:@"<defaultValue>"];
     ```

     - parameter key: The LDFlagKey for the requested feature flag.
     - parameter defaultValue: The default value to return if the feature flag key does not exist.

     - returns: The requested NSString feature flag value, or the default value if the flag is missing or cannot be cast to a NSString, or the client is not started.
     */
    /// - Tag: stringVariation
    @objc public func stringVariation(forKey key: LDFlagKey, defaultValue: String) -> String {
        ldClient.stringVariation(forKey: key, defaultValue: defaultValue)
    }

    /**
     See [stringVariation](x-source-tag://stringVariation) for more information on variation methods.

     - parameter key: The LDFlagKey for the requested feature flag.
     - parameter defaultValue: The default value to return if the feature flag key does not exist.

     - returns: ObjcLDStringEvaluationDetail containing your value as well as useful information on why that value was returned.
     */
    @objc public func stringVariationDetail(forKey key: LDFlagKey, defaultValue: String) -> ObjcLDStringEvaluationDetail {
        let evaluationDetail = ldClient.stringVariationDetail(forKey: key, defaultValue: defaultValue)
        return ObjcLDStringEvaluationDetail(value: evaluationDetail.value,
                                            variationIndex: evaluationDetail.variationIndex,
                                            reason: evaluationDetail.reason?.mapValues { ObjcLDValue(wrappedValue: $0) })
    }

    /**
     Returns the JSON variation for the given feature flag. If the flag does not exist, or the LDClient is not started, returns the default value.

     A call to `jsonVariation` records events reported later. Recorded events allow clients to analyze usage and assist in debugging issues.

     ### Usage
     ```
     ObjcLDValue *featureFlagValue = [ldClientInstance jsonVariationForKey:@"my-flag" defaultValue:[LDValue ofBool:NO]];
     ```

     - parameter key: The LDFlagKey for the requested feature flag.
     - parameter defaultValue: The default value to return if the feature flag key does not exist.

     - returns: The requested feature flag value, or the default value if the flag is missing or the client is not started
     */
    /// - Tag: arrayVariation
    @objc public func jsonVariation(forKey key: LDFlagKey, defaultValue: ObjcLDValue) -> ObjcLDValue {
        ObjcLDValue(wrappedValue: ldClient.jsonVariation(forKey: key, defaultValue: defaultValue.wrappedValue))
    }

    /**
     See [arrayVariation](x-source-tag://arrayVariation) for more information on variation methods.

     - parameter key: The LDFlagKey for the requested feature flag.
     - parameter defaultValue: The default value to return if the feature flag key does not exist.

     - returns: ObjcLDJSONEvaluationDetail containing your value as well as useful information on why that value was returned.
     */
    @objc public func jsonVariationDetail(forKey key: LDFlagKey, defaultValue: ObjcLDValue) -> ObjcLDJSONEvaluationDetail {
        let evaluationDetail = ldClient.jsonVariationDetail(forKey: key, defaultValue: defaultValue.wrappedValue)
        return ObjcLDJSONEvaluationDetail(value: ObjcLDValue(wrappedValue: evaluationDetail.value),
                                           variationIndex: evaluationDetail.variationIndex,
                                           reason: evaluationDetail.reason?.mapValues { ObjcLDValue(wrappedValue: $0) })
    }

    /**
     Returns a dictionary with the flag keys and their values. If the LDClient is not started, returns nil.

     The dictionary will not contain feature flags from the server with null values.

     LDClient will not provide any source or change information, only flag keys and flag values. The client app should convert the feature flag value into the desired type.
     */
    @objc public var allFlags: [LDFlagKey: ObjcLDValue]? { ldClient.allFlags?.mapValues { ObjcLDValue(wrappedValue: $0) } }

    // MARK: - Feature Flag Updates

    /**
     Sets a handler for the specified BOOL flag key executed on the specified owner. If the flag's value changes, executes the handler, passing in the `changedFlag` containing the old and new flag values. See `ObjcLDBoolChangedFlag` for details.

     The SDK retains only weak references to the owner, which allows the client app to freely destroy owners without issues. Client apps should capture a strong self reference from a weak reference immediately inside the handler to avoid retain cycles causing a memory leak.

     The SDK executes handlers on the main thread.

     SeeAlso: `ObjcLDBoolChangedFlag` and `stopObserving(owner:)`

     ### Usage
     ```
     __weak typeof(self) weakSelf = self;
     [ldClientInstance observeBool:"my-bool-flag" owner:self handler:^(LDBoolChangedFlag *changedFlag){
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf showBoolChangedFlag:changedFlag];
     }];
     ```

     - parameter key: The LDFlagKey for the flag to observe.
     - parameter owner: The LDFlagChangeOwner which will execute the handler. The SDK retains a weak reference to the owner.
     - parameter handler: The block the SDK will execute when the feature flag changes.
     */
    @objc public func observe(_ key: LDFlagKey, owner: LDObserverOwner, handler: @escaping ObjcLDChangedFlagHandler) {
        ldClient.observe(key: key, owner: owner) { changedFlag in handler(ObjcLDChangedFlag(changedFlag)) }
    }

    /**
     Sets a handler for the specified flag keys executed on the specified owner. If any observed flag's value changes, executes the handler 1 time, passing in a dictionary of <NSString*, LDChangedFlag*> containing the old and new flag values. See LDChangedFlag (`ObjcLDChangedFlag`) for details.

     The SDK retains only weak references to owner, which allows the client app to freely destroy change owners without issues. Client apps should capture a strong self reference from a weak reference immediately inside the handler to avoid retain cycles causing a memory leak.

     The SDK executes handlers on the main thread.

     SeeAlso: `ObjcLDChangedFlag` and `stopObserving(owner:)`

     ### Usage
     ```
     __weak typeof(self) weakSelf = self;
     [ldClientInstance observeKeys:@[@"my-bool-flag",@"my-string-flag", @"my-dictionary-flag"] owner:self handler:^(NSDictionary<NSString *,LDChangedFlag *> * _Nonnull changedFlags) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        //There will be a typed LDChangedFlag entry in changedFlags for each changed flag. The block will only be called once regardless of how many flags changed.
        [strongSelf showChangedFlags: changedFlags];
     }];
     ```

     - parameter keys: An array of NSString* flag keys for the flags to observe.
     - parameter owner: The LDFlagChangeOwner which will execute the handler. The SDK retains a weak reference to the owner.
     - parameter handler: The LDFlagCollectionChangeHandler the SDK will execute 1 time when any of the observed feature flags change.
     */
    @objc public func observeKeys(_ keys: [LDFlagKey], owner: LDObserverOwner, handler: @escaping ObjcLDChangedFlagCollectionHandler) {
        ldClient.observe(keys: keys, owner: owner) { changedFlags in
            handler(changedFlags.mapValues { ObjcLDChangedFlag($0) })
        }
    }

    /**
     Sets a handler for all flag keys executed on the specified owner. If any flag's value changes, executes the handler 1 time, passing in a dictionary of <NSString*, LDChangedFlag*> containing the old and new flag values. See LDChangedFlag (`ObjcLDChangedFlag`) for details.

     The SDK retains only weak references to owner, which allows the client app to freely destroy change owners without issues. Client apps should capture a strong self reference from a weak reference immediately inside the handler to avoid retain cycles causing a memory leak.

     The SDK executes handlers on the main thread.

     SeeAlso: `ObjcLDChangedFlag` and `stopObserving(owner:)`

     ### Usage
     ```
     __weak typeof(self) weakSelf = self;
     [ldClientInstance observeAllKeysWithOwner:self handler:^(NSDictionary<NSString *,LDChangedFlag *> * _Nonnull changedFlags) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        //There will be a typed LDChangedFlag entry in changedFlags for each changed flag. The block will only be called once regardless of how many flags changed.
        [strongSelf showChangedFlags:changedFlags];
     }];
     ```

     - parameter owner: The LDFlagChangeOwner which will execute the handler. The SDK retains a weak reference to the owner.
     - parameter handler: The LDFlagCollectionChangeHandler the SDK will execute 1 time when any of the observed feature flags change.
     */
    @objc public func observeAllKeys(owner: LDObserverOwner, handler: @escaping ObjcLDChangedFlagCollectionHandler) {
        ldClient.observeAll(owner: owner) { changedFlags in
            handler(changedFlags.mapValues { ObjcLDChangedFlag($0) })
        }
    }

    /**
     Sets a handler executed when a flag update leaves the flags unchanged from their previous values.

     This handler can only ever be called when the LDClient is polling.

     The SDK retains only weak references to owner, which allows the client app to freely destroy change owners without issues. Client apps should capture a strong self reference from a weak reference immediately inside the handler to avoid retain cycles causing a memory leak.

     The SDK executes handlers on the main thread.

     SeeAlso: `stopObserving(owner:)`

     ### Usage
     ```
     __weak typeof(self) weakSelf = self;
     [[LDClient sharedInstance] observeFlagsUnchangedWithOwner:self handler:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        //do something after the flags were not updated. The block will be called once on the main thread if the client is polling and the poll did not change any flag values.
        [self checkFeatureValues];
     }];
     ```

     - parameter owner: The LDFlagChangeOwner which will execute the handler. The SDK retains a weak reference to the owner.
     - parameter handler: The LDFlagsUnchangedHandler the SDK will execute 1 time when a flag request completes with no flags changed.
     */
    @objc public func observeFlagsUnchanged(owner: LDObserverOwner, handler: @escaping LDFlagsUnchangedHandler) {
        ldClient.observeFlagsUnchanged(owner: owner, handler: handler)
    }

    /**
     Removes all observers for the given owner, including a flagsUnchangedObserver

     The client app does not have to call this method. If the client app deinits a LDFlagChangeOwner, the SDK will automatically remove its handlers without ever calling them again.

     - parameter owner: The LDFlagChangeOwner owning the handlers to remove, whether a flag change handler or flags unchanged handler.
     */
    @objc(stopObservingForOwner:) public func stopObserving(owner: LDObserverOwner) {
        ldClient.stopObserving(owner: owner)
    }

    /**
     Handler passed to the client app when a feature flag value changes

     - parameter changedFlag: The LDChangedFlag passed into the handler containing the old & new flag value
     */
    public typealias ObjcLDChangedFlagHandler = (_ changedFlag: ObjcLDChangedFlag) -> Void

    /**
     Handler passed to the client app when a NSArray feature flag value changes

     - parameter changedFlags: A dictionary <NSString*, LDChangedFlag*> using the changed flag keys as the dictionary keys. Cast the resulting LDChangedFlag to the correct LDChangedFlagType.
     */
    public typealias ObjcLDChangedFlagCollectionHandler = (_ changedFlags: [LDFlagKey: ObjcLDChangedFlag]) -> Void

    // MARK: - Events

    /**
     Adds a custom event to the LDClient event store. A client app can set a tracking event to allow client customized data analysis. Once an app has called `track`, the app cannot remove the event from the event store.

     LDClient periodically transmits events to LaunchDarkly based on the frequency set in LDConfig.eventFlushInterval. The LDClient must be started and online. Ths SDK stores events tracked while the LDClient is offline, but started.

     Once the SDK's event store is full, the SDK discards events until they can be reported to LaunchDarkly. Configure the size of the event store using `eventCapacity` on the `config`. See `LDConfig` (`ObjcLDConfig`) for details.

     ### Usage
     ```
     [ldClientInstance trackWithKey:@"event-key" data:@{@"event-data-key":7}];
     ```

     - parameter key: The key for the event. The SDK does nothing with the key, which can be any string the client app sends
     - parameter data: The data for the event. The SDK does nothing with the data, which can be any valid JSON item the client app sends. (Optional)
     - parameter error: NSError object to hold the invalidJsonObject error if the data is not a valid JSON item. (Optional)
     */
    /// - Tag: track
    @objc public func track(key: String, data: ObjcLDValue? = nil) {
        ldClient.track(key: key, data: data?.wrappedValue, metricValue: nil)
    }

    /**
     See (track)[x-source-tag://track] for full documentation.

     - parameter key: The key for the event. The SDK does nothing with the key, which can be any string the client app sends
     - parameter data: The data for the event. The SDK does nothing with the data, which can be any valid JSON item the client app sends. (Optional)
     - parameter metricValue: A numeric value used by the LaunchDarkly experimentation feature in numeric custom metrics. Can be omitted if this event is used by only non-numeric metrics. This field will also be returned as part of the custom event for Data Export.
     - parameter error: NSError object to hold the invalidJsonObject error if the data is not a valid JSON item. (Optional)
     */
    @objc public func track(key: String, data: ObjcLDValue? = nil, metricValue: Double) {
        ldClient.track(key: key, data: data?.wrappedValue, metricValue: metricValue)
    }

    /**
     Tells the SDK to immediately send any currently queued events to LaunchDarkly.

     There should not normally be a need to call this function. While online, the LDClient automatically reports events
     on an interval defined by `LDConfig.eventFlushInterval`. Note that this function does not block until events are
     sent, it only triggers a background task to send events immediately.
     */
    @objc public func flush() {
        ldClient.flush()
    }

   /**
     Starts the LDClient using the passed in `config` & `context`. Call this before requesting feature flag values. The LDClient will not go online until you call this method.
     Starting the LDClient means setting the `config` & `context`, setting the client online if `config.startOnline` is true (the default setting), and starting event recording. The client app must start the LDClient before it will report feature flag values. If a client does not call `start`, no methods will work.
     If the `start` call omits the `context`, the LDClient uses the default `context` if it was never set.
     If the` start` call includes the optional `completion` closure, LDClient calls the `completion` closure when `setOnline(_: completion:)` embedded in the `init` method completes. This method listens for flag updates so the completion will only return once an update has occurred. The `start` call is subject to throttling delays, therefore the `completion` closure call may be delayed.
     Subsequent calls to this method cause the LDClient to return. Normally there should only be one call to start. To change `context`, use `identify`.
     - parameter configuration: The LDConfig that contains the desired configuration. (Required)
     - parameter context: The LDContext set with the desired context. If omitted, LDClient sets a default context. (Optional)
     - parameter completion: Closure called when the embedded `setOnline` call completes. (Optional)
    */
    /// - Tag: start
   @objc public static func start(configuration: ObjcLDConfig, context: ObjcLDContext, completion: (() -> Void)? = nil) {
       LDClient.start(config: configuration.config, context: context.context, completion: completion)
   }

    /**
    See [start](x-source-tag://start) for more information on starting the SDK.

    - parameter configuration: The LDConfig that contains the desired configuration. (Required)
    - parameter context: The LDContext set with the desired context. If omitted, LDClient sets a default context.. (Optional)
    - parameter startWaitSeconds: A TimeInterval that determines when the completion will return if no flags have been returned from the network.
    - parameter completion: Closure called when the embedded `setOnline` call completes. Takes a Bool that indicates whether the completion timedout as a parameter. (Optional)
    */
   @objc public static func start(configuration: ObjcLDConfig, context: ObjcLDContext, startWaitSeconds: TimeInterval, completion: ((_ timedOut: Bool) -> Void)? = nil) {
       LDClient.start(config: configuration.config, context: context.context, startWaitSeconds: startWaitSeconds, completion: completion)
   }

    private init(client: LDClient) {
        ldClient = client
    }
}
