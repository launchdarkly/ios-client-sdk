import Foundation

extension LDClient {
    // MARK: Retrieving Flag Values
    /**
     Returns the variation for the given feature flag. If the flag does not exist, cannot be cast to the correct return
     type, or the LDClient is not started, returns the default value.

     A *variation* is a specific flag value. For example a boolean feature flag has 2 variations, *true* and *false*.
     You can create feature flags with more than 2 variations using other feature flag types. See `LDFlagValue` for the
     available types.

     When online, the LDClient has two modes for maintaining feature flag values: *streaming* and *polling*. The client
     app requests the mode by setting the `config.streamingMode`, see `LDConfig` for details.

     A call to `variation` records events reported later. Recorded events allow clients to analyze usage and assist in
     debugging issues.

     ### Usage
     ````
     let boolFeatureFlagValue = LDClient.get()!.variation(forKey: "bool-flag-key", defaultValue: false) //boolFeatureFlagValue is a Bool
     ````
     **Important** The default value tells the SDK the type of the feature flag. In several cases, the feature flag type
     cannot be determined by the values sent from the server. It is possible to provide a default value with a type that
     does not match the feature flag value's type. The SDK will attempt to convert the feature flag's value into the
     type of the default value in the variation request. If that cast fails, the SDK will not be able to determine the
     correct return type, and will always return the default value.

     Pay close attention to the type of the default value for collections. If the default value collection type is more
     restrictive than the feature flag, the sdk will return the default value even though the feature flag is present
     because it cannot convert the feature flag into the type requested via the default value. For example, if the
     feature flag has the type `[String: Any]`, but the default value has the type `[String: Int]`, the sdk will not be
     able to convert the flags into the requested type, and will return the default value.

     To avoid this, make sure the default value type matches the expected feature flag type. Either specify the default
     value type to be the feature flag type, or cast the default value to the feature flag type prior to making the
     variation request. In the above example, either specify that the default value's type is `[String: Any]`:
     ````
     let defaultValue: [String: Any] = ["a": 1, "b": 2]     //dictionary type would be [String: Int] without the type specifier
     ````
     or cast the default value into the feature flag type prior to calling variation:
     ````
     let dictionaryFlagValue = LDClient.get()!.variation(forKey: "dictionary-key", defaultValue: ["a": 1, "b": 2] as [String: Any])
     ````

     - parameter forKey: The LDFlagKey for the requested feature flag.
     - parameter defaultValue: The default value to return if the feature flag key does not exist.

     - returns: The requested feature flag value, or the default value if the flag is missing or cannot be cast to the default value type, or the client is not started
    */
    /// - Tag: variation
    public func variation<T: LDFlagValueConvertible>(forKey flagKey: LDFlagKey, defaultValue: T) -> T {
        variationInternal(forKey: flagKey, defaultValue: defaultValue, includeReason: false)
    }

    /**
     Returns the LDEvaluationDetail for the given feature flag. LDEvaluationDetail gives you more insight into why your
     variation contains the specified value. If the flag does not exist, cannot be cast to the correct return type, or
     the LDClient is not started, returns an LDEvaluationDetail with the default value.
     See [variation](x-source-tag://variation)

     - parameter forKey: The LDFlagKey for the requested feature flag.
     - parameter defaultValue: The default value value to return if the feature flag key does not exist.

     - returns: LDEvaluationDetail which wraps the requested feature flag value, or the default value, which variation was served, and the evaluation reason.
     */
    public func variationDetail<T: LDFlagValueConvertible>(forKey flagKey: LDFlagKey, defaultValue: T) -> LDEvaluationDetail<T> {
        let featureFlag = flagStore.featureFlag(for: flagKey)
        let reason = checkErrorKinds(featureFlag: featureFlag) ?? featureFlag?.reason
        let value = variationInternal(forKey: flagKey, defaultValue: defaultValue, includeReason: true)
        return LDEvaluationDetail(value: value, variationIndex: featureFlag?.variation, reason: reason)
    }

    private func checkErrorKinds(featureFlag: FeatureFlag?) -> [String: Any]? {
        if !hasStarted {
            return ["kind": "ERROR", "errorKind": "CLIENT_NOT_READY"]
        } else if featureFlag == nil {
            return ["kind": "ERROR", "errorKind": "FLAG_NOT_FOUND"]
        } else {
            return nil
        }
    }

    private func variationInternal<T: LDFlagValueConvertible>(forKey flagKey: LDFlagKey, defaultValue: T, includeReason: Bool) -> T {
        guard hasStarted
        else {
            Log.debug(typeName(and: #function) + "returning defaultValue: \(defaultValue)." + " LDClient not started.")
            return defaultValue
        }
        let featureFlag = flagStore.featureFlag(for: flagKey)
        let value = (featureFlag?.value as? T) ?? defaultValue
        let failedConversionMessage = self.failedConversionMessage(featureFlag: featureFlag, defaultValue: defaultValue)
        Log.debug(typeName(and: #function) + "flagKey: \(flagKey), value: \(value), defaultValue: \(defaultValue), " +
                  "featureFlag: \(String(describing: featureFlag)), reason: \(featureFlag?.reason?.description ?? "nil"). \(failedConversionMessage)")
        eventReporter.recordFlagEvaluationEvents(flagKey: flagKey, value: LDValue.fromAny(value), defaultValue: LDValue.fromAny(defaultValue), featureFlag: featureFlag, user: user, includeReason: includeReason)
        return value
    }

    private func failedConversionMessage<T>(featureFlag: FeatureFlag?, defaultValue: T) -> String {
        if featureFlag == nil {
            return " Feature flag not found."
        }
        if featureFlag?.value is T {
            return ""
        }
        return " LDClient was unable to convert the feature flag to the requested type (\(T.self))."
            + (isCollection(defaultValue) ? " The defaultValue type is a collection. Make sure the element of the defaultValue's type is not too restrictive for the actual feature flag type." : "")
    }

    private func isCollection<T>(_ object: T) -> Bool {
        let collectionsTypes = ["Set", "Array", "Dictionary"]
        let typeString = String(describing: type(of: object))

        for type in collectionsTypes {
            if typeString.contains(type) { return true }
        }
        return false
    }
}

private extension Optional {
    var stringValue: String {
        guard let value = self
        else {
            return "<nil>"
        }
        return "\(value)"
    }
}
