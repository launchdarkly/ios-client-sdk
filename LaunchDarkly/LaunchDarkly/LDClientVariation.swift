import Foundation

extension LDClient {
    // MARK: Flag variation methods

    /**
     Returns the boolean value of a feature flag for a given flag key.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: the variation for the selected user, or `defaultValue` if the flag is not available.
     */
    public func boolVariation(forKey flagKey: LDFlagKey, defaultValue: Bool) -> Bool {
        variationDetailInternal(flagKey, defaultValue, needsReason: false).value
    }

    /**
     Returns the boolean value of a feature flag for a given flag key, in an object that also describes the way the
     value was determined.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: an `LDEvaluationDetail` object
     */
    public func boolVariationDetail(forKey flagKey: LDFlagKey, defaultValue: Bool) -> LDEvaluationDetail<Bool> {
        variationDetailInternal(flagKey, defaultValue, needsReason: true)
    }

    /**
     Returns the integer value of a feature flag for a given flag key.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: the variation for the selected user, or `defaultValue` if the flag is not available.
     */
    public func intVariation(forKey flagKey: LDFlagKey, defaultValue: Int) -> Int {
        variationDetailInternal(flagKey, defaultValue, needsReason: false).value
    }

    /**
     Returns the integer value of a feature flag for a given flag key, in an object that also describes the way the
     value was determined.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: an `LDEvaluationDetail` object
     */
    public func intVariationDetail(forKey flagKey: LDFlagKey, defaultValue: Int) -> LDEvaluationDetail<Int> {
        variationDetailInternal(flagKey, defaultValue, needsReason: true)
    }

    /**
     Returns the double-precision floating-point value of a feature flag for a given flag key.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: the variation for the selected user, or `defaultValue` if the flag is not available.
     */
    public func doubleVariation(forKey flagKey: LDFlagKey, defaultValue: Double) -> Double {
        variationDetailInternal(flagKey, defaultValue, needsReason: false).value
    }

    /**
     Returns the double-precision floating-point value of a feature flag for a given flag key, in an object that also
     describes the way the value was determined.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: an `LDEvaluationDetail` object
     */
    public func doubleVariationDetail(forKey flagKey: LDFlagKey, defaultValue: Double) -> LDEvaluationDetail<Double> {
        variationDetailInternal(flagKey, defaultValue, needsReason: true)
    }

    /**
     Returns the string value of a feature flag for a given flag key.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: the variation for the selected user, or `defaultValue` if the flag is not available.
     */
    public func stringVariation(forKey flagKey: LDFlagKey, defaultValue: String) -> String {
        variationDetailInternal(flagKey, defaultValue, needsReason: false).value
    }

    /**
     Returns the string value of a feature flag for a given flag key, in an object that also describes the way the
     value was determined.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: an `LDEvaluationDetail` object
     */
    public func stringVariationDetail(forKey flagKey: LDFlagKey, defaultValue: String) -> LDEvaluationDetail<String> {
        variationDetailInternal(flagKey, defaultValue, needsReason: true)
    }

    /**
     Returns the JSON value of a feature flag for a given flag key.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: the variation for the selected user, or `defaultValue` if the flag is not available.
     */
    public func jsonVariation(forKey flagKey: LDFlagKey, defaultValue: LDValue) -> LDValue {
        variationDetailInternal(flagKey, defaultValue, needsReason: false).value
    }

    /**
     Returns the JSON value of a feature flag for a given flag key, in an object that also describes the way the
     value was determined.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: an `LDEvaluationDetail` object
     */
    public func jsonVariationDetail(forKey flagKey: LDFlagKey, defaultValue: LDValue) -> LDEvaluationDetail<LDValue> {
        variationDetailInternal(flagKey, defaultValue, needsReason: true)
    }

    private func variationDetailInternal<T: LDValueConvertible>(_ flagKey: LDFlagKey, _ defaultValue: T, needsReason: Bool) -> LDEvaluationDetail<T> {
        var result: LDEvaluationDetail<T>
        let featureFlag = flagStore.featureFlag(for: flagKey)
        if let featureFlag = featureFlag {
            if featureFlag.value == .null {
                result = LDEvaluationDetail(value: defaultValue, variationIndex: featureFlag.variation, reason: featureFlag.reason)
            } else if let convertedValue = T(fromLDValue: featureFlag.value) {
                result = LDEvaluationDetail(value: convertedValue, variationIndex: featureFlag.variation, reason: featureFlag.reason)
            } else {
                result = LDEvaluationDetail(value: defaultValue, variationIndex: nil, reason: ["kind": "ERROR", "errorKind": "WRONG_TYPE"])
            }
        } else {
            Log.debug(typeName(and: #function) + " Unknown feature flag \(flagKey); returning default value")
            result = LDEvaluationDetail(value: defaultValue, variationIndex: nil, reason: ["kind": "ERROR", "errorKind": "FLAG_NOT_FOUND"])
        }
        eventReporter.recordFlagEvaluationEvents(flagKey: flagKey,
                                                 value: result.value.toLDValue(),
                                                 defaultValue: defaultValue.toLDValue(),
                                                 featureFlag: featureFlag,
                                                 user: user,
                                                 includeReason: needsReason)
        return result
    }
}

private protocol LDValueConvertible {
    init?(fromLDValue: LDValue)
    func toLDValue() -> LDValue
}

extension Bool: LDValueConvertible {
    init?(fromLDValue value: LDValue) {
        guard case .bool(let value) = value
        else { return nil }
        self = value
    }

    func toLDValue() -> LDValue {
        return .bool(self)
    }
}

extension Int: LDValueConvertible {
    init?(fromLDValue value: LDValue) {
        guard case .number(let value) = value, let intValue = Int(exactly: value.rounded())
        else { return nil }
        self = intValue
    }

    func toLDValue() -> LDValue {
        return .number(Double(self))
    }
}

extension Double: LDValueConvertible {
    init?(fromLDValue value: LDValue) {
        guard case .number(let value) = value
        else { return nil }
        self = value
    }

    func toLDValue() -> LDValue {
        return .number(self)
    }
}

extension String: LDValueConvertible {
    init?(fromLDValue value: LDValue) {
        guard case .string(let value) = value
        else { return nil }
        self = value
    }

    func toLDValue() -> LDValue {
        return .string(self)
    }
}

extension LDValue: LDValueConvertible {
    init?(fromLDValue value: LDValue) {
        self = value
    }

    func toLDValue() -> LDValue {
        return self
    }
}
