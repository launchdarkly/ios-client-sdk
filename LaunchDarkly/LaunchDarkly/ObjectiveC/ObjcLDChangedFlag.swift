//
//  LDChangedFlagObject.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

/**
 Collects the elements of a feature flag that changed as a result of a `clientstream` update or feature flag request. The SDK will pass a typed ObjcLDChangedFlag or a collection of ObjcLDChangedFlags into feature flag observer blocks. This is the base type for the typed ObjcLDChangedFlags passed into observer blocks. The client app will have to convert the ObjcLDChangedFlag into the expected typed ObjcLDChangedFlag type.

 See the typed `ObjcLDClient` observeWithKey:owner:handler:, observeWithKeys:owner:handler:, and observeAllWithOwner:handler: for more details.
 */
@objc(LDChangedFlag)
public class ObjcLDChangedFlag: NSObject {
    fileprivate let changedFlag: LDChangedFlag
    fileprivate var sourceValue: Any? {
        changedFlag.oldValue ?? changedFlag.newValue
    }

    /// The changed feature flag's key
    @objc public var key: String {
        changedFlag.key
    }

    fileprivate init(_ changedFlag: LDChangedFlag) {
        self.changedFlag = changedFlag
    }
}

/// Wraps the changed feature flag's BOOL values.
///
/// If the flag is not actually a BOOL the SDK sets the old and new value to false, and `typeMismatch` will be `YES`.
@objc(LDBoolChangedFlag)
public final class ObjcLDBoolChangedFlag: ObjcLDChangedFlag {
    /// The changed flag's value before it changed
    @objc public var oldValue: Bool {
        (changedFlag.oldValue as? Bool) ?? false
    }
    /// The changed flag's value after it changed
    @objc public var newValue: Bool {
        (changedFlag.newValue as? Bool) ?? false
    }

    override init(_ changedFlag: LDChangedFlag) {
        super.init(changedFlag)
    }

    @objc public var typeMismatch: Bool {
        !(sourceValue is Bool)
    }
}

/// Wraps the changed feature flag's NSInteger values.
///
/// If the flag is not actually an NSInteger the SDK sets the old and new value to 0, and `typeMismatch` will be `YES`.
@objc(LDIntegerChangedFlag)
public final class ObjcLDIntegerChangedFlag: ObjcLDChangedFlag {
    /// The changed flag's value before it changed
    @objc public var oldValue: Int {
        (changedFlag.oldValue as? Int) ?? 0
    }
    /// The changed flag's value after it changed
    @objc public var newValue: Int {
        (changedFlag.newValue as? Int) ?? 0
    }

    override init(_ changedFlag: LDChangedFlag) {
        super.init(changedFlag)
    }

    @objc public var typeMismatch: Bool {
        !(sourceValue is Int)
    }
}

/// Wraps the changed feature flag's double values.
///
/// If the flag is not actually a double the SDK sets the old and new value to 0.0, and `typeMismatch` will be `YES`.
@objc(LDDoubleChangedFlag)
public final class ObjcLDDoubleChangedFlag: ObjcLDChangedFlag {
    /// The changed flag's value before it changed
    @objc public var oldValue: Double {
        (changedFlag.oldValue as? Double) ?? 0.0
    }
    /// The changed flag's value after it changed
    @objc public var newValue: Double {
        (changedFlag.newValue as? Double) ?? 0.0
    }

    override init(_ changedFlag: LDChangedFlag) {
        super.init(changedFlag)
    }

    @objc public var typeMismatch: Bool {
        !(sourceValue is Double)
    }
}

/// Wraps the changed feature flag's NSString values.
///
/// If the flag is not actually an NSString the SDK sets the old and new value to nil, and `typeMismatch` will be `YES`.
@objc(LDStringChangedFlag)
public final class ObjcLDStringChangedFlag: ObjcLDChangedFlag {
    /// The changed flag's value before it changed
    @objc public var oldValue: String? {
        (changedFlag.oldValue as? String)
    }
    /// The changed flag's value after it changed
    @objc public var newValue: String? {
        (changedFlag.newValue as? String)
    }
    
    override init(_ changedFlag: LDChangedFlag) {
        super.init(changedFlag)
    }

    @objc public var typeMismatch: Bool {
        !(sourceValue is String)
    }
}

/// Wraps the changed feature flag's NSArray values.
///
/// If the flag is not actually a NSArray the SDK sets the old and new value to nil, and `typeMismatch` will be `YES`.
@objc(LDArrayChangedFlag)
public final class ObjcLDArrayChangedFlag: ObjcLDChangedFlag {
    /// The changed flag's value before it changed
    @objc public var oldValue: [Any]? {
        changedFlag.oldValue as? [Any]
    }
    /// The changed flag's value after it changed
    @objc public var newValue: [Any]? {
        changedFlag.newValue as? [Any]
    }

    override init(_ changedFlag: LDChangedFlag) {
        super.init(changedFlag)
    }

    @objc public var typeMismatch: Bool {
        !(sourceValue is [Any])
    }
}

/// Wraps the changed feature flag's NSDictionary values.
///
/// If the flag is not actually an NSDictionary the SDK sets the old and new value to nil, and `typeMismatch` will be `YES`.
@objc(LDDictionaryChangedFlag)
public final class ObjcLDDictionaryChangedFlag: ObjcLDChangedFlag {
    /// The changed flag's value before it changed
    @objc public var oldValue: [String: Any]? {
        changedFlag.oldValue as? [String: Any]
    }
    /// The changed flag's value after it changed
    @objc public var newValue: [String: Any]? {
        changedFlag.newValue as? [String: Any]
    }

    override init(_ changedFlag: LDChangedFlag) {
        super.init(changedFlag)
    }

    @objc public var typeMismatch: Bool {
        !(sourceValue is [String: Any])
    }
}

public extension LDChangedFlag {
    /// An NSObject wrapper for the Swift LDChangeFlag enum. Intended for use in mixed apps when Swift code needs to pass a LDChangeFlag into an Objective-C method.
    var objcChangedFlag: ObjcLDChangedFlag {
        let extantValue = oldValue ?? newValue
        switch extantValue {
        case _ as Bool: return ObjcLDBoolChangedFlag(self)
        case _ as Int: return ObjcLDIntegerChangedFlag(self)
        case _ as Double: return ObjcLDDoubleChangedFlag(self)
        case _ as String: return ObjcLDStringChangedFlag(self)
        case _ as [Any]: return ObjcLDArrayChangedFlag(self)
        case _ as [String: Any]: return ObjcLDDictionaryChangedFlag(self)
        default: return ObjcLDChangedFlag(self)
        }
    }
}
