//
//  LDCommon.swift
//  Darkly
//
//  Created by Mark Pokorny on 8/23/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

///The feature flag key is a String. This typealias helps define where the SDK expects the string to be a feature flag key.
public typealias LDFlagKey = String

///An object can own the change observer for as long as the object exists. Swift structs and enums cannot be change observer owners.
public typealias LDFlagChangeOwner = AnyObject
///A closure used to notify a flag change owner of a change to a single feature flag's value.
public typealias LDFlagChangeHandler = (LDChangedFlag) -> Void
///A closure used to notify a flag change owner of a change to the feature flags in a collection of `LDChangedFlag`.
public typealias LDFlagCollectionChangeHandler = ([LDFlagKey: LDChangedFlag]) -> Void
///A closure used to notify a flag change owner that a feature flag request resulted in no changes to any feature flag.
public typealias LDFlagsUnchangedHandler = () -> Void

extension LDFlagKey {
    private static var anyKeyIdentifier: LDFlagKey { return "Darkly.FlagKeyList.Any" }
    static var anyKey: [LDFlagKey] { return [anyKeyIdentifier] }
}

typealias UserKey = String
