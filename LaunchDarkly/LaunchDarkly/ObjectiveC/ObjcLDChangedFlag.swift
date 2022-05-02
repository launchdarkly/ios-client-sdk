import Foundation

/**
 Collects the elements of a feature flag that changed as a result of a `clientstream` update or feature flag request. The SDK will pass a typed ObjcLDChangedFlag or a collection of ObjcLDChangedFlags into feature flag observer blocks. This is the base type for the typed ObjcLDChangedFlags passed into observer blocks. The client app will have to convert the ObjcLDChangedFlag into the expected typed ObjcLDChangedFlag type.

 See the typed `ObjcLDClient` observeWithKey:owner:handler:, observeWithKeys:owner:handler:, and observeAllWithOwner:handler: for more details.
 */
@objc(LDChangedFlag)
public class ObjcLDChangedFlag: NSObject {
    /// The changed feature flag's key
    @objc public let key: String
    /// The value from before the flag change occurred.
    @objc public let oldValue: ObjcLDValue
    /// The value after the flag change occurred.
    @objc public let newValue: ObjcLDValue

    init(_ changedFlag: LDChangedFlag) {
        self.key = changedFlag.key
        self.oldValue = ObjcLDValue(wrappedValue: changedFlag.oldValue)
        self.newValue = ObjcLDValue(wrappedValue: changedFlag.newValue)
    }
}
