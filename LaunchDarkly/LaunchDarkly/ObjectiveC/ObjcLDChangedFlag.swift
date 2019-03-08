//
//  LDChangedFlagObject.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 9/12/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

/**
 Collects the elements of a feature flag that changed as a result of a `clientstream` update or feature flag request. The SDK will pass a typed ObjcLDChangedFlag or a collection of ObjcLDChangedFlags into feature flag observer blocks. This is the base type for the typed ObjcLDChangedFlags passed into observer blocks. The client app will have to convert the ObjcLDChangedFlag into the expected typed ObjcLDChangedFlag type.

 See the typed `ObjcLDClient` observeWithKey:owner:handler:, observeWithKeys:owner:handler:, and observeAllWithOwner:handler: for more details.
 */
@objc(LDChangedFlag)
public class ObjcLDChangedFlag: NSObject {
    ///String that identifies the feature flag value's source is nil
    @objc public static let nilSource = "<nil>"
    ///String that identifies the feature flag value's type does not match the requested type
    @objc public static let typeMismatch = "type mismatch"
    
    fileprivate let changedFlag: LDChangedFlag
    fileprivate var sourceValue: Any? {
        return changedFlag.oldValue ?? changedFlag.newValue
    }

    ///The changed feature flag's key
    @objc public var key: String {
        return changedFlag.key
    }
    
    fileprivate init(_ changedFlag: LDChangedFlag) {
        self.changedFlag = changedFlag
    }
    
    fileprivate func sourceString(forSource source: LDFlagValueSource?, typeMismatch: Bool) -> String {
        return typeMismatch ? ObjcLDChangedFlag.typeMismatch : LDFlagValueSource.toString(source)
    }
}

///Wraps the changed feature flag's BOOL values and sources.
///
///If the flag is not actually a BOOL the SDK sets the old and new value to false, and old and new valueSource to 'type mismatch'.
@objc(LDBoolChangedFlag)
public final class ObjcLDBoolChangedFlag: ObjcLDChangedFlag {
    ///The changed flag's value before it changed
    @objc public var oldValue: Bool {
        return (changedFlag.oldValue as? Bool) ?? false
    }
    ///The changed flag's value after it changed
    @objc public var newValue: Bool {
        return (changedFlag.newValue as? Bool) ?? false
    }
    ///The changed flag value's source before it changed
    @objc public var oldValueSource: ObjcLDFlagValueSource {
        return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch)
    }
    ///The changed flag value's source after it changed
    @objc public var newValueSource: ObjcLDFlagValueSource {
        return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch)
    }

    override init(_ changedFlag: LDChangedFlag) {
        super.init(changedFlag)
    }
    
    private var typeMismatch: Bool {
        return !(sourceValue is Bool)
    }
}

///Wraps the changed feature flag's NSInteger values and sources.
///
///If the flag is not actually an NSInteger the SDK sets the old and new value to 0, and old and new valueSource to 'type mismatch'.
@objc(LDIntegerChangedFlag)
public final class ObjcLDIntegerChangedFlag: ObjcLDChangedFlag {
    ///The changed flag's value before it changed
    @objc public var oldValue: Int {
        return (changedFlag.oldValue as? Int) ?? 0
    }
    ///The changed flag's value after it changed
    @objc public var newValue: Int {
        return (changedFlag.newValue as? Int) ?? 0
    }
    ///The changed flag value's source before it changed
    @objc public var oldValueSource: ObjcLDFlagValueSource {
        return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch)
    }
    ///The changed flag value's source after it changed
    @objc public var newValueSource: ObjcLDFlagValueSource {
        return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch)
    }
    
    override init(_ changedFlag: LDChangedFlag) {
        super.init(changedFlag)
    }
    
    private var typeMismatch: Bool {
        return !(sourceValue is Int)
    }
}

///Wraps the changed feature flag's double values and sources.
///
///If the flag is not actually a double the SDK sets the old and new value to 0.0, and old and new valueSource to 'type mismatch'.
@objc(LDDoubleChangedFlag)
public final class ObjcLDDoubleChangedFlag: ObjcLDChangedFlag {
    ///The changed flag's value before it changed
    @objc public var oldValue: Double {
        return (changedFlag.oldValue as? Double) ?? 0.0
    }
    ///The changed flag's value after it changed
    @objc public var newValue: Double {
        return (changedFlag.newValue as? Double) ?? 0.0
    }
    ///The changed flag value's source before it changed
    @objc public var oldValueSource: ObjcLDFlagValueSource {
        return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch)
    }
    ///The changed flag value's source after it changed
    @objc public var newValueSource: ObjcLDFlagValueSource {
        return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch)
    }
    
    override init(_ changedFlag: LDChangedFlag) {
        super.init(changedFlag)
    }
    
    private var typeMismatch: Bool {
        return !(sourceValue is Double)
    }
}

///Wraps the changed feature flag's NSString values and sources.
///
///If the flag is not actually an NSString the SDK sets the old and new value to nil, and old and new valueSource to 'type mismatch'.
@objc(LDStringChangedFlag)
public final class ObjcLDStringChangedFlag: ObjcLDChangedFlag {
    ///The changed flag's value before it changed
    @objc public var oldValue: String? {
        return (changedFlag.oldValue as? String)
    }
    ///The changed flag's value after it changed
    @objc public var newValue: String? {
        return (changedFlag.newValue as? String)
    }
    ///The changed flag value's source before it changed
    @objc public var oldValueSource: ObjcLDFlagValueSource {
        return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch)
    }
    ///The changed flag value's source after it changed
    @objc public var newValueSource: ObjcLDFlagValueSource {
        return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch)
    }
    
    override init(_ changedFlag: LDChangedFlag) {
        super.init(changedFlag)
    }
    
    private var typeMismatch: Bool {
        return !(sourceValue is String)
    }
}

///Wraps the changed feature flag's NSArray values and sources.
///
///If the flag is not actually a NSArray the SDK sets the old and new value to nil, and old and new valueSource to 'type mismatch'.
@objc(LDArrayChangedFlag)
public final class ObjcLDArrayChangedFlag: ObjcLDChangedFlag {
    ///The changed flag's value before it changed
    @objc public var oldValue: [Any]? {
        return changedFlag.oldValue as? [Any]
    }
    ///The changed flag's value after it changed
    @objc public var newValue: [Any]? {
        return changedFlag.newValue as? [Any]
    }
    ///The changed flag value's source before it changed
    @objc public var oldValueSource: ObjcLDFlagValueSource {
        return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch)
    }
    ///The changed flag value's source after it changed
    @objc public var newValueSource: ObjcLDFlagValueSource {
        return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch)
    }
    
    override init(_ changedFlag: LDChangedFlag) {
        super.init(changedFlag)
    }
    
    private var typeMismatch: Bool {
        return !(sourceValue is [Any])
    }
}

///Wraps the changed feature flag's NSDictionary values and sources.
///
///If the flag is not actually an NSDictionary the SDK sets the old and new value to nil, and old and new valueSource to 'type mismatch'.
@objc(LDDictionaryChangedFlag)
public final class ObjcLDDictionaryChangedFlag: ObjcLDChangedFlag {
    ///The changed flag's value before it changed
    @objc public var oldValue: [String: Any]? {
        return changedFlag.oldValue as? [String: Any]
    }
    ///The changed flag's value after it changed
    @objc public var newValue: [String: Any]? {
        return changedFlag.newValue as? [String: Any]
    }
    ///The changed flag value's source before it changed
    @objc public var oldValueSource: ObjcLDFlagValueSource {
        return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch)
    }
    ///The changed flag value's source after it changed
    @objc public var newValueSource: ObjcLDFlagValueSource {
        return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch)
    }
    
    override init(_ changedFlag: LDChangedFlag) {
        super.init(changedFlag)
    }
    
    private var typeMismatch: Bool {
        return !(sourceValue is [String: Any])
    }
}

extension LDFlagValueSource {
    static func toString(_ source: LDFlagValueSource?) -> String {
        guard let source = source
        else {
            return ObjcLDChangedFlag.nilSource
        }
        return "\(source)"
    }
}

public extension LDChangedFlag {
    ///An NSObject wrapper for the Swift LDChangeFlag enum. Intended for use in mixed apps when Swift code needs to pass a LDChangeFlag into an Objective-C method.
    public var objcChangedFlag: ObjcLDChangedFlag {
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
