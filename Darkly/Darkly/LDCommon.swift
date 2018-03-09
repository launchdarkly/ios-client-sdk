//
//  LDCommon.swift
//  Darkly
//
//  Created by Mark Pokorny on 8/23/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

public typealias LDFlagChangeOwner = AnyObject
public typealias LDFlagKey = String
typealias UserKey = String
public typealias LDFlagChangeHandler = (LDChangedFlag) -> Void
public typealias LDFlagCollectionChangeHandler = ([LDFlagKey: LDChangedFlag]) -> Void
public typealias LDFlagsUnchangedHandler = () -> Void

extension LDFlagKey {
    private static var anyKeyIdentifier: LDFlagKey { return "Darkly.FlagKeyList.Any" }
    static var anyKey: [LDFlagKey] { return [anyKeyIdentifier] }
}

#if DEBUG
var isDebug: Bool { return true }
#else
var isDebug: Bool { return false }
#endif
