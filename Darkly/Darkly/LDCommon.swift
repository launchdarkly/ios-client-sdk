//
//  LDCommon.swift
//  Darkly
//
//  Created by Mark Pokorny on 8/23/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation
import WatchKit

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

#if os(iOS)
var deviceModel: String { return UIDevice.current.model }
var systemVersion: String { return UIDevice.current.systemVersion }
var agentOS: String { return "iOS" }
#elseif os(watchOS)
var deviceModel: String { return WKInterfaceDevice.current().model }
var systemVersion: String { return WKInterfaceDevice.current().systemVersion }
var agentOS: String { return "watchOS" }
#endif
