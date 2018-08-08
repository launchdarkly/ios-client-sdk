//
//  LDCommon.swift
//  Darkly
//
//  Created by Mark Pokorny on 8/23/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

//TODO: Jazzy appears to skip type aliases
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
