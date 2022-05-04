import Foundation

/**
 Collects the elements of a feature flag that changed as a result of the SDK receiving an update.

 The SDK will pass a LDChangedFlag or a collection of LDChangedFlags into feature flag observer closures. See
 `LDClient.observe(key:owner:handler:)`, `LDClient.observe(keys:owner:handler:)`, and
 `LDClient.observeAll(owner:handler:)` for more details.
 */
public struct LDChangedFlag {
    /// The key of the changed feature flag
    public let key: LDFlagKey
    /// The feature flag's value before the change.
    public let oldValue: LDValue
    /// The feature flag's value after the change.
    public let newValue: LDValue

    init(key: LDFlagKey, oldValue: LDValue, newValue: LDValue) {
        self.key = key
        self.oldValue = oldValue
        self.newValue = newValue
    }
}
