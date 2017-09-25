//
//  ObjcLDVariationValue.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 9/14/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

@objc (LDBoolVariationValue)
public final class ObjcLDBoolVariationValue: NSObject {
    @objc public let value: Bool
    @objc public let source: ObjcLDFlagValueSource
    
    init(_ variationValue: (value: Bool, source: LDFlagValueSource)) {
        self.value = variationValue.value
        self.source = ObjcLDFlagValueSource(variationValue.source)
    }
}

@objc (LDIntegerVariationValue)
public final class ObjcLDIntegerVariationValue: NSObject {
    @objc public let value: Int
    @objc public let source: ObjcLDFlagValueSource
    
    init(_ variationValue: (value: Int, source: LDFlagValueSource)) {
        self.value = variationValue.value
        self.source = ObjcLDFlagValueSource(variationValue.source)
    }
}

@objc (LDDoubleVariationValue)
public final class ObjcLDDoubleVariationValue: NSObject {
    @objc public let value: Double
    @objc public let source: ObjcLDFlagValueSource
    
    init(_ variationValue: (value: Double, source: LDFlagValueSource)) {
        self.value = variationValue.value
        self.source = ObjcLDFlagValueSource(variationValue.source)
    }
}

@objc (LDStringVariationValue)
public final class ObjcLDStringVariationValue: NSObject {
    @objc public let value: String
    @objc public let source: ObjcLDFlagValueSource
    
    init(_ variationValue: (value: String, source: LDFlagValueSource)) {
        self.value = variationValue.value
        self.source = ObjcLDFlagValueSource(variationValue.source)
    }
}

@objc (LDArrayVariationValue)
public final class ObjcLDArrayVariationValue: NSObject {
    @objc public let value: [Any]
    @objc public let source: ObjcLDFlagValueSource
    
    init(_ variationValue: (value: [Any], source: LDFlagValueSource)) {
        self.value = variationValue.value
        self.source = ObjcLDFlagValueSource(variationValue.source)
    }
}

@objc (LDDictionaryVariationValue)
public final class ObjcLDDictionaryVariationValue: NSObject {
    @objc public let value: [String: Any]
    @objc public let source: ObjcLDFlagValueSource
    
    init(_ variationValue: (value: [String: Any], source: LDFlagValueSource)) {
        self.value = variationValue.value
        self.source = ObjcLDFlagValueSource(variationValue.source)
    }
}
