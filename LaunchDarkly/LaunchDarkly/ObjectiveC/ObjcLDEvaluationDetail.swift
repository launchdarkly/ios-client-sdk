//
//  ObjCEvaluationDetail.swift
//  LaunchDarkly_iOS
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

@objc(LDBoolVariationDetail)
public final class ObjCBoolEvaluationDetail: NSObject {
    @objc public let value: Bool
    @objc public let variationIndex: Int
    @objc public let reason: [String: Any]?
    
    internal init(value: Bool, variationIndex: Int?, reason: [String: Any]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}

@objc(LDDoubleVariationDetail)
public final class ObjCDoubleEvaluationDetail: NSObject {
    @objc public let value: Double
    @objc public let variationIndex: Int
    @objc public let reason: [String: Any]?
    
    internal init(value: Double, variationIndex: Int?, reason: [String: Any]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}

@objc(LDIntegerVariationDetail)
public final class ObjCIntegerEvaluationDetail: NSObject {
    @objc public let value: Int
    @objc public let variationIndex: Int
    @objc public let reason: [String: Any]?
    
    internal init(value: Int, variationIndex: Int?, reason: [String: Any]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}

@objc(LDStringVariationDetail)
public final class ObjCStringEvaluationDetail: NSObject {
    @objc public let value: String?
    @objc public let variationIndex: Int
    @objc public let reason: [String: Any]?
    
    internal init(value: String?, variationIndex: Int?, reason: [String: Any]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}

@objc(LDArrayVariationDetail)
public final class ObjCArrayEvaluationDetail: NSObject {
    @objc public let value: [Any]?
    @objc public let variationIndex: Int
    @objc public let reason: [String: Any]?
    
    internal init(value: [Any]?, variationIndex: Int?, reason: [String: Any]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}

@objc(LDDictionaryVariationDetail)
public final class ObjCDictionaryEvaluationDetail: NSObject {
    @objc public let value: [String: Any]?
    @objc public let variationIndex: Int
    @objc public let reason: [String: Any]?
    
    internal init(value: Dictionary<String, Any>?, variationIndex: Int?, reason: [String: Any]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}
