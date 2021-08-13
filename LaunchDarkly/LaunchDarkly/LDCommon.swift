//
//  LDCommon.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

/// The feature flag key is a String. This typealias helps define where the SDK expects the string to be a feature flag key.
public typealias LDFlagKey = String

/// An object can own an observer for as long as the object exists. Swift structs and enums cannot be observer owners.
public typealias LDObserverOwner = AnyObject
/// A closure used to notify an observer owner of a change to a single feature flag's value.
public typealias LDFlagChangeHandler = (LDChangedFlag) -> Void
/// A closure used to notify an observer owner of a change to the feature flags in a collection of `LDChangedFlag`.
public typealias LDFlagCollectionChangeHandler = ([LDFlagKey: LDChangedFlag]) -> Void
/// A closure used to notify an observer owner that a feature flag request resulted in no changes to any feature flag.
public typealias LDFlagsUnchangedHandler = () -> Void
/// A closure used to notify an observer owner that the current connection mode has changed.
public typealias LDConnectionModeChangedHandler = (ConnectionInformation.ConnectionMode) -> Void
/// A closure used to notify an observer owner that an error occurred during feature flag processing.
public typealias LDErrorHandler = (Error) -> Void

extension LDFlagKey {
    private static var anyKeyIdentifier: LDFlagKey { "Darkly.FlagKeyList.Any" }
    static var anyKey: [LDFlagKey] { [anyKeyIdentifier] }
}

@objc public class LDInvalidArgumentError: NSObject, Error {
    public let localizedDescription: String

    init(_ description: String) {
        self.localizedDescription = description
    }
}
