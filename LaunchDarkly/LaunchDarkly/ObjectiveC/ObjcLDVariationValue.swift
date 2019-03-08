//
//  ObjcLDVariationValue.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 9/14/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

///Objective-C object that contains a BOOL feature flag's value and source.
@objc (LDBoolVariationValue)
public final class ObjcLDBoolVariationValue: NSObject {
    ///The feature flag's BOOL value
    @objc public let value: Bool
    ///The feature flag value's source
    @objc public let source: ObjcLDFlagValueSource
    
    init(_ variationValue: (value: Bool, source: LDFlagValueSource)) {
        self.value = variationValue.value
        self.source = ObjcLDFlagValueSource(variationValue.source)
    }
    ///A string representation of the feature flag value's source
    @objc public var sourceString: String {
        return source.stringValue
    }
}

///Objective-C object that contains an NSInteger feature flag's value and source.
@objc (LDIntegerVariationValue)
public final class ObjcLDIntegerVariationValue: NSObject {
    ///The feature flag's NSInteger value
    @objc public let value: Int
    ///The feature flag value's source
    @objc public let source: ObjcLDFlagValueSource
    
    init(_ variationValue: (value: Int, source: LDFlagValueSource)) {
        self.value = variationValue.value
        self.source = ObjcLDFlagValueSource(variationValue.source)
    }

    ///A string representation of the feature flag value's source
    @objc public var sourceString: String {
        return source.stringValue
    }
}

///Objective-C object that contains a double feature flag's value and source.
@objc (LDDoubleVariationValue)
public final class ObjcLDDoubleVariationValue: NSObject {
    ///The feature flag's double value
    @objc public let value: Double
    ///The feature flag value's source
    @objc public let source: ObjcLDFlagValueSource
    
    init(_ variationValue: (value: Double, source: LDFlagValueSource)) {
        self.value = variationValue.value
        self.source = ObjcLDFlagValueSource(variationValue.source)
    }

    ///A string representation of the feature flag value's source
    @objc public var sourceString: String {
        return source.stringValue
    }
}

///Objective-C object that contains an NSString feature flag's value and source.
@objc (LDStringVariationValue)
public final class ObjcLDStringVariationValue: NSObject {
    ///The feature flag's NSString value
    @objc public let value: String?
    ///The feature flag value's source
    @objc public let source: ObjcLDFlagValueSource
    
    init(_ variationValue: (value: String?, source: LDFlagValueSource)) {
        self.value = variationValue.value
        self.source = ObjcLDFlagValueSource(variationValue.source)
    }

    ///A string representation of the feature flag value's source
    @objc public var sourceString: String {
        return source.stringValue
    }
}

///Objective-C object that contains an NSArray feature flag's value and source.
@objc (LDArrayVariationValue)
public final class ObjcLDArrayVariationValue: NSObject {
    ///The feature flag's NSArray value
    @objc public let value: [Any]?
    ///The feature flag value's source
    @objc public let source: ObjcLDFlagValueSource
    
    init(_ variationValue: (value: [Any]?, source: LDFlagValueSource)) {
        self.value = variationValue.value
        self.source = ObjcLDFlagValueSource(variationValue.source)
    }

    ///A string representation of the feature flag value's source
    @objc public var sourceString: String {
        return source.stringValue
    }
}

///Objective-C object that contains an NSDictionary feature flag's value and source.
@objc (LDDictionaryVariationValue)
public final class ObjcLDDictionaryVariationValue: NSObject {
    ///The feature flag's NSDictionary value
    @objc public let value: [String: Any]?
    ///The feature flag value's source
    @objc public let source: ObjcLDFlagValueSource
    
    init(_ variationValue: (value: [String: Any]?, source: LDFlagValueSource)) {
        self.value = variationValue.value
        self.source = ObjcLDFlagValueSource(variationValue.source)
    }

    ///A string representation of the feature flag value's source
    @objc public var sourceString: String {
        return source.stringValue
    }
}
