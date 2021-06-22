//
//  LDChangedFlag.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

/**
 Collects the elements of a feature flag that changed as a result of a `clientstream` update or feature flag request. The SDK will pass a LDChangedFlag or a collection of LDChangedFlags into feature flag observer closures. The client app will have to convert the old/newValue into the expected type. See `LDClient.observe(key:owner:handler:)`, `LDClient.observe(keys:owner:handler:)`, and `LDClient.observeAll(owner:handler:)` for more details.
 */
public struct LDChangedFlag {
    /// The key of the changed feature flag
    public let key: LDFlagKey
    /// The feature flag's value before the change. The client app will have to convert the oldValue into the expected type.
    public let oldValue: Any?
    /// The feature flag's value after the change. The client app will have to convert the newValue into the expected type.
    public let newValue: Any?

    init(key: LDFlagKey, oldValue: Any?, newValue: Any?) {
        self.key = key
        self.oldValue = oldValue
        self.newValue = newValue
    }
}
