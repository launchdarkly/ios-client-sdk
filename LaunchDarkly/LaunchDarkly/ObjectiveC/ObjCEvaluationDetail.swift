//
//  ObjCEvaluationDetail.swift
//  LaunchDarkly_iOS
//
//  Created by Joe Cieslik on 12/1/19.
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

@objc public final class ObjCBoolEvaluationDetail: NSObject {
    public internal(set) var value: Bool
    public internal(set) var variationIndex: Int?
    public internal(set) var reason: Dictionary<String, Any>?
    
    internal init(value: Bool, variationIndex: Int?, reason: Dictionary<String, Any>?) {
        self.value = value
        self.variationIndex = variationIndex
        self.reason = reason
    }
}

@objc public final class ObjCDoubleEvaluationDetail: NSObject {
    public internal(set) var value: Double
    public internal(set) var variationIndex: Int?
    public internal(set) var reason: Dictionary<String, Any>?
    
    internal init(value: Double, variationIndex: Int?, reason: Dictionary<String, Any>?) {
        self.value = value
        self.variationIndex = variationIndex
        self.reason = reason
    }
}

@objc public final class ObjCIntegerEvaluationDetail: NSObject {
    public internal(set) var value: Int
    public internal(set) var variationIndex: Int?
    public internal(set) var reason: Dictionary<String, Any>?
    
    internal init(value: Int, variationIndex: Int?, reason: Dictionary<String, Any>?) {
        self.value = value
        self.variationIndex = variationIndex
        self.reason = reason
    }
}

@objc public final class ObjCStringEvaluationDetail: NSObject {
    public internal(set) var value: String?
    public internal(set) var variationIndex: Int?
    public internal(set) var reason: Dictionary<String, Any>?
    
    internal init(value: String?, variationIndex: Int?, reason: Dictionary<String, Any>?) {
        self.value = value
        self.variationIndex = variationIndex
        self.reason = reason
    }
}

@objc public final class ObjCArrayEvaluationDetail: NSObject {
    public internal(set) var value: [Any]?
    public internal(set) var variationIndex: Int?
    public internal(set) var reason: Dictionary<String, Any>?
    
    internal init(value: [Any]?, variationIndex: Int?, reason: Dictionary<String, Any>?) {
        self.value = value
        self.variationIndex = variationIndex
        self.reason = reason
    }
}

@objc public final class ObjCDictionaryEvaluationDetail: NSObject {
    public internal(set) var value: Dictionary<String, Any>?
    public internal(set) var variationIndex: Int?
    public internal(set) var reason: Dictionary<String, Any>?
    
    internal init(value: Dictionary<String, Any>?, variationIndex: Int?, reason: Dictionary<String, Any>?) {
        self.value = value
        self.variationIndex = variationIndex
        self.reason = reason
    }
}
