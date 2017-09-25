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
    fileprivate var sourceValue: LDFlagValue? { return changedFlag.oldValue ?? changedFlag.newValue }

    @objc public var key: String { return changedFlag.key }
    
    fileprivate init(_ changedFlag: LDChangedFlag) { self.changedFlag = changedFlag }
}

///Wraps the changed bool values of a flag-key. If the flag is not actually a Bool, old & new value default to false and old & new valueSource returns 'type mismatch'
@objc(LDBoolChangedFlag)
public final class ObjcLDBoolChangedFlag: ObjcLDChangedFlag {
    @objc public var oldValue: Bool { return Bool(changedFlag.oldValue) ?? false }
    @objc public var newValue: Bool { return Bool(changedFlag.newValue) ?? false }
    @objc public var oldValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch) }
    @objc public var newValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch) }

    override init(_ changedFlag: LDChangedFlag) { super.init(changedFlag) }
    
    private var typeMismatch: Bool {
        guard case .some(.bool) = sourceValue else { return true }
        return false
    }
}

///Wraps the changed integer values of a flag-key. If the flag is not actually an Int, old & new value default to 0 and old & new valueSource returns 'type mismatch'
@objc(LDIntegerChangedFlag)
public final class ObjcLDIntegerChangedFlag: ObjcLDChangedFlag {
    @objc public var oldValue: Int { return Int(changedFlag.oldValue) ?? 0 }
    @objc public var newValue: Int { return Int(changedFlag.newValue) ?? 0 }
    @objc public var oldValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch) }
    @objc public var newValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch) }
    
    override init(_ changedFlag: LDChangedFlag) { super.init(changedFlag) }
    
    private var typeMismatch: Bool {
        guard case .some(.int) = sourceValue else { return true }
        return false
    }
}

///Wraps the changed double values of a flag-key. If the flag is not actually a Double, old & new value default to 0.0 and old & new valueSource returns 'type mismatch'
@objc(LDDoubleChangedFlag)
public final class ObjcLDDoubleChangedFlag: ObjcLDChangedFlag {
    @objc public var oldValue: Double { return Double(changedFlag.oldValue) ?? 0.0 }
    @objc public var newValue: Double { return Double(changedFlag.newValue) ?? 0.0 }
    @objc public var oldValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch) }
    @objc public var newValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch) }
    
    override init(_ changedFlag: LDChangedFlag) { super.init(changedFlag) }
    
    private var typeMismatch: Bool {
        guard case .some(.double) = sourceValue else { return true }
        return false
    }
}

///Wraps the changed string values of a flag-key. If the flag is not actually a String, old & new value default to nil and old & new valueSource returns 'type mismatch'
@objc(LDStringChangedFlag)
public final class ObjcLDStringChangedFlag: ObjcLDChangedFlag {
    @objc public var oldValue: String? { return String(changedFlag.oldValue) }
    @objc public var newValue: String? { return String(changedFlag.newValue) }
    @objc public var oldValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch) }
    @objc public var newValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch) }
    
    override init(_ changedFlag: LDChangedFlag) { super.init(changedFlag) }
    
    private var typeMismatch: Bool {
        guard case .some(.string) = sourceValue else { return true }
        return false
    }
}

///Wraps the changed array values of a flag-key. If the flag is not actually an Array, old & new value default to nil and old & new valueSource returns 'type mismatch'
@objc(LDArrayChangedFlag)
public final class ObjcLDArrayChangedFlag: ObjcLDChangedFlag {
    @objc public var oldValue: [Any]? { return Array(changedFlag.oldValue) }
    @objc public var newValue: [Any]? { return Array(changedFlag.newValue) }
    @objc public var oldValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch) }
    @objc public var newValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch) }
    
    override init(_ changedFlag: LDChangedFlag) { super.init(changedFlag) }
    
    private var typeMismatch: Bool {
        guard case .some(.array) = sourceValue else { return true }
        return false
    }
}

///Wraps the changed dictionary values of a flag-key. If the flag is not actually a Dictionary, old & new value default to nil and old & new valueSource returns 'type mismatch'
@objc(LDDictionaryChangedFlag)
public final class ObjcLDDictionaryChangedFlag: ObjcLDChangedFlag {
    @objc public var oldValue: [String: Any]? { return Dictionary(changedFlag.oldValue) }
    @objc public var newValue: [String: Any]? { return Dictionary(changedFlag.newValue) }
    @objc public var oldValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.oldValueSource, typeMismatch: typeMismatch) }
    @objc public var newValueSource: ObjcLDFlagValueSource { return ObjcLDFlagValueSource(changedFlag.newValueSource, typeMismatch: typeMismatch) }
    
    override init(_ changedFlag: LDChangedFlag) { super.init(changedFlag) }
    
    private var typeMismatch: Bool {
        guard case .some(.dictionary) = sourceValue else { return true }
        return false
    }
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
        case .some(.bool): return ObjcLDBoolChangedFlag(self)
        case .some(.int): return ObjcLDIntegerChangedFlag(self)
        case .some(.double): return ObjcLDDoubleChangedFlag(self)
        case .some(.string): return ObjcLDStringChangedFlag(self)
        case .some(.array): return ObjcLDArrayChangedFlag(self)
        case .some(.dictionary): return ObjcLDDictionaryChangedFlag(self)
        default: return ObjcLDChangedFlag(self)
        }
    }
}
