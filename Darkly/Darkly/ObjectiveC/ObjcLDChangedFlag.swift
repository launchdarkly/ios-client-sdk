//
//  LDChangedFlagObject.swift
//  Darkly
//
//  Created by Mark Pokorny on 9/12/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

@objc(LDChangedFlag)
public class ObjcLDChangedFlag: NSObject {
    @objc public static let nilSource = "<nil>"
    @objc public static let typeMismatch = "type mismatch"
    
    fileprivate let changedFlag: LDChangedFlag
    fileprivate var sourceValue: Any? { return changedFlag.oldValue ?? changedFlag.newValue }

    @objc public var key: String { return changedFlag.key }
    
    fileprivate init(_ changedFlag: LDChangedFlag) { self.changedFlag = changedFlag }
    
    fileprivate func sourceString(forSource source: LDFlagValueSource?, typeMismatch: Bool) -> String {
        return typeMismatch ? ObjcLDChangedFlag.typeMismatch : LDFlagValueSource.toString(source)
    }
}

///Wraps the changed bool values of a flag-key. If the flag is not actually a Bool, old & new value default to false and old & new valueSource returns 'type mismatch'
@objc(LDBoolChangedFlag)
public final class ObjcLDBoolChangedFlag: ObjcLDChangedFlag {
    @objc public var oldValue: Bool { return (changedFlag.oldValue as? Bool) ?? false }
    @objc public var newValue: Bool { return (changedFlag.newValue as? Bool) ?? false }
    @objc public var oldValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch) }
    @objc public var newValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch) }

    override init(_ changedFlag: LDChangedFlag) { super.init(changedFlag) }
    
    private var typeMismatch: Bool { return !(sourceValue is Bool) }
}

///Wraps the changed integer values of a flag-key. If the flag is not actually an Int, old & new value default to 0 and old & new valueSource returns 'type mismatch'
@objc(LDIntegerChangedFlag)
public final class ObjcLDIntegerChangedFlag: ObjcLDChangedFlag {
    @objc public var oldValue: Int { return (changedFlag.oldValue as? Int) ?? 0 }
    @objc public var newValue: Int { return (changedFlag.newValue as? Int) ?? 0 }
    @objc public var oldValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch) }
    @objc public var newValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch) }
    
    override init(_ changedFlag: LDChangedFlag) { super.init(changedFlag) }
    
    private var typeMismatch: Bool { return !(sourceValue is Int) }
}

///Wraps the changed double values of a flag-key. If the flag is not actually a Double, old & new value default to 0.0 and old & new valueSource returns 'type mismatch'
@objc(LDDoubleChangedFlag)
public final class ObjcLDDoubleChangedFlag: ObjcLDChangedFlag {
    @objc public var oldValue: Double { return (changedFlag.oldValue as? Double) ?? 0.0 }
    @objc public var newValue: Double { return (changedFlag.newValue as? Double) ?? 0.0 }
    @objc public var oldValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch) }
    @objc public var newValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch) }
    
    override init(_ changedFlag: LDChangedFlag) { super.init(changedFlag) }
    
    private var typeMismatch: Bool { return !(sourceValue is Double) }
}

///Wraps the changed string values of a flag-key. If the flag is not actually a String, old & new value default to nil and old & new valueSource returns 'type mismatch'
@objc(LDStringChangedFlag)
public final class ObjcLDStringChangedFlag: ObjcLDChangedFlag {
    @objc public var oldValue: String? { return (changedFlag.oldValue as? String) }
    @objc public var newValue: String? { return (changedFlag.newValue as? String) }
    @objc public var oldValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch) }
    @objc public var newValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch) }
    
    override init(_ changedFlag: LDChangedFlag) { super.init(changedFlag) }
    
    private var typeMismatch: Bool { return !(sourceValue is String) }
}

///Wraps the changed array values of a flag-key. If the flag is not actually an Array, old & new value default to nil and old & new valueSource returns 'type mismatch'
@objc(LDArrayChangedFlag)
public final class ObjcLDArrayChangedFlag: ObjcLDChangedFlag {
    @objc public var oldValue: [Any]? { return changedFlag.oldValue as? [Any] }
    @objc public var newValue: [Any]? { return changedFlag.newValue as? [Any] }
    @objc public var oldValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch) }
    @objc public var newValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch) }
    
    override init(_ changedFlag: LDChangedFlag) { super.init(changedFlag) }
    
    private var typeMismatch: Bool { return !(sourceValue is [Any]) }
}

///Wraps the changed dictionary values of a flag-key. If the flag is not actually a Dictionary, old & new value default to nil and old & new valueSource returns 'type mismatch'
@objc(LDDictionaryChangedFlag)
public final class ObjcLDDictionaryChangedFlag: ObjcLDChangedFlag {
    @objc public var oldValue: [String: Any]? { return changedFlag.oldValue as? [String: Any] }
    @objc public var newValue: [String: Any]? { return changedFlag.newValue as? [String: Any] }
    @objc public var oldValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch) }
    @objc public var newValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch) }
    
    override init(_ changedFlag: LDChangedFlag) { super.init(changedFlag) }
    
    private var typeMismatch: Bool { return !(sourceValue is [String: Any]) }
}

extension LDFlagValueSource {
    static func toString(_ source: LDFlagValueSource?) -> String {
        guard let source = source else { return ObjcLDChangedFlag.nilSource }
        return "\(source)"
    }
}

extension LDChangedFlag {
    var objcChangedFlag: ObjcLDChangedFlag {
        let sourceValue = oldValue ?? newValue
        switch sourceValue {
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
