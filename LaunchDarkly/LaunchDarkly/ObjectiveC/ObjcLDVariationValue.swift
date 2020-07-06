//
//  ObjcLDVariationValue.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

///Objective-C object that contains a BOOL feature flag's value.
@objc (LDBoolVariationValue)
public final class ObjcLDBoolVariationValue: NSObject {
    ///The feature flag's BOOL value
    @objc public let value: Bool

    init(_ value: Bool) {
        self.value = value
    }
}

///Objective-C object that contains an NSInteger feature flag's value.
@objc (LDIntegerVariationValue)
public final class ObjcLDIntegerVariationValue: NSObject {
    ///The feature flag's NSInteger value
    @objc public let value: Int

    init(_ value: Int) {
        self.value = value
    }
}

///Objective-C object that contains a double feature flag's value.
@objc (LDDoubleVariationValue)
public final class ObjcLDDoubleVariationValue: NSObject {
    ///The feature flag's double value
    @objc public let value: Double

    init(_ value: Double) {
        self.value = value
    }
}

///Objective-C object that contains an NSString feature flag's value.
@objc (LDStringVariationValue)
public final class ObjcLDStringVariationValue: NSObject {
    ///The feature flag's NSString value
    @objc public let value: String?

    init(_ value: String?) {
        self.value = value
    }
}

///Objective-C object that contains an NSArray feature flag's value.
@objc (LDArrayVariationValue)
public final class ObjcLDArrayVariationValue: NSObject {
    ///The feature flag's NSArray value
    @objc public let value: [Any]?

    init(_ value: [Any]?) {
        self.value = value
    }
}

///Objective-C object that contains an NSDictionary feature flag's value.
@objc (LDDictionaryVariationValue)
public final class ObjcLDDictionaryVariationValue: NSObject {
    ///The feature flag's NSDictionary value
    @objc public let value: [String: Any]?

    init(_ value: [String: Any]?) {
        self.value = value
    }
}
