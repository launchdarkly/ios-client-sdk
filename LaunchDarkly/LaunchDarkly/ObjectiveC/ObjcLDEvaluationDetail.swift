//
//  ObjcLDEvaluationDetail.swift
//  LaunchDarkly_iOS
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

@objc(LDBoolEvaluationDetail)
public final class ObjcLDBoolEvaluationDetail: NSObject {
    @objc public let value: Bool
    @objc public let variationIndex: Int
    @objc public let reason: [String: Any]?
    
    internal init(value: Bool, variationIndex: Int?, reason: [String: Any]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}

@objc(LDDoubleEvaluationDetail)
public final class ObjcLDDoubleEvaluationDetail: NSObject {
    @objc public let value: Double
    @objc public let variationIndex: Int
    @objc public let reason: [String: Any]?
    
    internal init(value: Double, variationIndex: Int?, reason: [String: Any]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}

@objc(LDIntegerEvaluationDetail)
public final class ObjcLDIntegerEvaluationDetail: NSObject {
    @objc public let value: Int
    @objc public let variationIndex: Int
    @objc public let reason: [String: Any]?
    
    internal init(value: Int, variationIndex: Int?, reason: [String: Any]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}

@objc(LDStringEvaluationDetail)
public final class ObjcLDStringEvaluationDetail: NSObject {
    @objc public let value: String?
    @objc public let variationIndex: Int
    @objc public let reason: [String: Any]?
    
    internal init(value: String?, variationIndex: Int?, reason: [String: Any]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}

@objc(ArrayEvaluationDetail)
public final class ObjcLDArrayEvaluationDetail: NSObject {
    @objc public let value: [Any]?
    @objc public let variationIndex: Int
    @objc public let reason: [String: Any]?
    
    internal init(value: [Any]?, variationIndex: Int?, reason: [String: Any]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}

@objc(DictionaryEvaluationDetail)
public final class ObjcLDDictionaryEvaluationDetail: NSObject {
    @objc public let value: [String: Any]?
    @objc public let variationIndex: Int
    @objc public let reason: [String: Any]?
    
    internal init(value: [String: Any]?, variationIndex: Int?, reason: [String: Any]?) {
        self.value = value
        self.variationIndex = variationIndex ?? -1
        self.reason = reason
    }
}
