import Foundation
import OSLog

extension LDClient {
    // MARK: Flag variation methods

    /**
     Returns the boolean value of a feature flag for a given flag key.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: the variation for the selected context, or `defaultValue` if the flag is not available.
     */
    public func boolVariation(forKey flagKey: LDFlagKey, defaultValue: Bool) -> Bool {
        variationDetailInternal(flagKey, defaultValue, needsReason: false, methodName: "boolVariation").value
    }

    /**
     Returns the boolean value of a feature flag for a given flag key, in an object that also describes the way the
     value was determined.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: an `LDEvaluationDetail` object
     */
    public func boolVariationDetail(forKey flagKey: LDFlagKey, defaultValue: Bool) -> LDEvaluationDetail<Bool> {
        variationDetailInternal(flagKey, defaultValue, needsReason: true, methodName: "boolVariationDetail")
    }

    /**
     Returns the integer value of a feature flag for a given flag key.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: the variation for the selected context, or `defaultValue` if the flag is not available.
     */
    public func intVariation(forKey flagKey: LDFlagKey, defaultValue: Int) -> Int {
        variationDetailInternal(flagKey, defaultValue, needsReason: false, methodName: "intVariation").value
    }

    /**
     Returns the integer value of a feature flag for a given flag key, in an object that also describes the way the
     value was determined.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: an `LDEvaluationDetail` object
     */
    public func intVariationDetail(forKey flagKey: LDFlagKey, defaultValue: Int) -> LDEvaluationDetail<Int> {
        variationDetailInternal(flagKey, defaultValue, needsReason: true, methodName: "intVariationDetail")
    }

    /**
     Returns the double-precision floating-point value of a feature flag for a given flag key.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: the variation for the selected context, or `defaultValue` if the flag is not available.
     */
    public func doubleVariation(forKey flagKey: LDFlagKey, defaultValue: Double) -> Double {
        variationDetailInternal(flagKey, defaultValue, needsReason: false, methodName: "doubleVariation").value
    }

    /**
     Returns the double-precision floating-point value of a feature flag for a given flag key, in an object that also
     describes the way the value was determined.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: an `LDEvaluationDetail` object
     */
    public func doubleVariationDetail(forKey flagKey: LDFlagKey, defaultValue: Double) -> LDEvaluationDetail<Double> {
        variationDetailInternal(flagKey, defaultValue, needsReason: true, methodName: "doubleVariationDetail")
    }

    /**
     Returns the string value of a feature flag for a given flag key.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: the variation for the selected context, or `defaultValue` if the flag is not available.
     */
    public func stringVariation(forKey flagKey: LDFlagKey, defaultValue: String) -> String {
        variationDetailInternal(flagKey, defaultValue, needsReason: false, methodName: "stringVariation").value
    }

    /**
     Returns the string value of a feature flag for a given flag key, in an object that also describes the way the
     value was determined.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: an `LDEvaluationDetail` object
     */
    public func stringVariationDetail(forKey flagKey: LDFlagKey, defaultValue: String) -> LDEvaluationDetail<String> {
        variationDetailInternal(flagKey, defaultValue, needsReason: true, methodName: "stringVariationDetail")
    }

    /**
     Returns the JSON value of a feature flag for a given flag key.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: the variation for the selected context, or `defaultValue` if the flag is not available.
     */
    public func jsonVariation(forKey flagKey: LDFlagKey, defaultValue: LDValue) -> LDValue {
        variationDetailInternal(flagKey, defaultValue, needsReason: false, methodName: "jsonVariation").value
    }

    /**
     Returns the JSON value of a feature flag for a given flag key, in an object that also describes the way the
     value was determined.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: an `LDEvaluationDetail` object
     */
    public func jsonVariationDetail(forKey flagKey: LDFlagKey, defaultValue: LDValue) -> LDEvaluationDetail<LDValue> {
        variationDetailInternal(flagKey, defaultValue, needsReason: true, methodName: "jsonVariationDetail")
    }

    /**
     Returns the value of a feature flag for a given flag key, converting the raw JSON value into a type of your specification.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: the variation for the selected context, or `defaultValue` if the flag is not available.
     */
    public func variation<T>(forKey flagKey: LDFlagKey, defaultValue: T) -> T where T: LDValueConvertible, T: Decodable {
        return variationDetailInternal(flagKey, defaultValue, needsReason: false, methodName: "variation").value
    }

    /**
     Returns the value of a feature flag for a given flag key, converting the raw JSON value into a type
     of your specifification, and including it in an object that also describes the way the value was
     determined.

     - parameter forKey: the unique feature key for the feature flag.
     - parameter defaultValue: the default value for if the flag value is unavailable.
     - returns: an `LDEvaluationDetail` object
     */
    public func variationDetail<T>(forKey flagKey: LDFlagKey, defaultValue: T) -> LDEvaluationDetail<T> where T: LDValueConvertible, T: Decodable {
        return variationDetailInternal(flagKey, defaultValue, needsReason: true, methodName: "variationDetail")
    }

    private func evaluateWithHooks<D>(flagKey: LDFlagKey, defaultValue: D, methodName: String, evaluation: () -> LDEvaluationDetail<D>) -> LDEvaluationDetail<D> where D: LDValueConvertible, D: Decodable {
        if self.hooks.isEmpty {
            return evaluation()
        }

        let seriesContext = EvaluationSeriesContext(flagKey: flagKey, context: self.context, defaultValue: defaultValue.toLDValue(), methodName: methodName)
        let hookData = self.execute_before_evaluation(seriesContext: seriesContext)
        let evaluationResult = evaluation()
        _ = self.execute_after_evaluation(seriesContext: seriesContext, hookData: hookData, evaluationDetail: evaluationResult.map { value in return value.toLDValue()})

        return evaluationResult
    }

    private func execute_before_evaluation(seriesContext: EvaluationSeriesContext) -> [EvaluationSeriesData] {
        return self.hooks.map { hook in
            hook.beforeEvaluation(seriesContext: seriesContext, seriesData: EvaluationSeriesData())
        }
    }

    private func execute_after_evaluation(seriesContext: EvaluationSeriesContext, hookData: [EvaluationSeriesData], evaluationDetail: LDEvaluationDetail<LDValue>) -> [EvaluationSeriesData] {
        return zip(self.hooks, hookData).reversed().map { (hook, data) in
            return hook.afterEvaluation(seriesContext: seriesContext, seriesData: data, evaluationDetail: evaluationDetail)
        }
    }

    private func variationDetailInternal<T>(_ flagKey: LDFlagKey, _ defaultValue: T, needsReason: Bool, methodName: String) -> LDEvaluationDetail<T> where T: Decodable, T: LDValueConvertible {
        return evaluateWithHooks(flagKey: flagKey, defaultValue: defaultValue, methodName: methodName) {
            var result: LDEvaluationDetail<T>
            let featureFlag = flagStore.featureFlag(for: flagKey)
            if let featureFlag = featureFlag {
                featureFlag.prerequisites?.forEach { prereqFlagKey in
                    // recurse on prerequisites to emulate prereq evaluations occurring with desirable side effects such as events for prereqs
                    _ = variationDetailInternal(prereqFlagKey, LDValue.null, needsReason: needsReason, methodName: methodName)
                }

                if featureFlag.value == .null {
                    result = LDEvaluationDetail(value: defaultValue, variationIndex: featureFlag.variation, reason: featureFlag.reason)
                } else {
                    do {
                        let convertedValue = try LDValueDecoder().decode(T.self, from: featureFlag.value)
                        result = LDEvaluationDetail(value: convertedValue, variationIndex: featureFlag.variation, reason: featureFlag.reason)
                    } catch let error {
                        os_log("%s type conversion error %s: failed converting %s to type %s", log: config.logger, type: .debug, typeName(and: #function), String(describing: error), String(describing: featureFlag.value), String(describing: T.self))
                        result = LDEvaluationDetail(value: defaultValue, variationIndex: nil, reason: ["kind": "ERROR", "errorKind": "WRONG_TYPE"])
                    }
                }
            } else {
                os_log("%s Unknown feature flag %s; returning default value", log: config.logger, type: .debug, typeName(and: #function), flagKey.description)
                result = LDEvaluationDetail(value: defaultValue, variationIndex: nil, reason: ["kind": "ERROR", "errorKind": "FLAG_NOT_FOUND"])
            }

            eventReporter.recordFlagEvaluationEvents(flagKey: flagKey,
                                                     value: result.value.toLDValue(),
                                                     defaultValue: defaultValue.toLDValue(),
                                                     featureFlag: featureFlag,
                                                     context: context,
                                                     includeReason: needsReason)
            return result
        }
    }
}

/**
 Protocol indicting a type can be converted into an LDValue.

 Types used with the `LDClient.variation(forKey: defaultValue:)` or `LDClient.variationDetail(forKey: detailValue:)`
 methods are required to implement this protocol. This protocol has already been implemented for Bool, Int, Double, String,
 and LDValue types.

 This allows custom types as evaluation result types while retaining the LDValue type throughout the event processing system.
 */
public protocol LDValueConvertible {
    /**
     Return an LDValue representation of this instance.
     */
    func toLDValue() -> LDValue
}

extension Bool: LDValueConvertible {
    public func toLDValue() -> LDValue {
        return .bool(self)
    }
}

extension Int: LDValueConvertible {
    public func toLDValue() -> LDValue {
        return .number(Double(self))
    }
}

extension Double: LDValueConvertible {
    public func toLDValue() -> LDValue {
        return .number(self)
    }
}

extension String: LDValueConvertible {
    public func toLDValue() -> LDValue {
        return .string(self)
    }
}

extension LDValue: LDValueConvertible {
    public func toLDValue() -> LDValue {
        return self
    }
}
