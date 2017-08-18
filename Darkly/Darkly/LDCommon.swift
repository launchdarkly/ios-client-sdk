//
//  LDCommon.swift
//  Darkly
//
//  Created by Mark Pokorny on 8/23/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

public protocol LDFlaggable { }
extension Bool: LDFlaggable { }
extension Int: LDFlaggable { }
extension Float: LDFlaggable { }
extension String: LDFlaggable { }
extension Array: LDFlaggable { }
extension Dictionary: LDFlaggable { }
public class LDFlagType: LDFlaggable { }

public typealias LDFlagChangeOwner = AnyObject
public typealias LDFlagKeyList = [String]
public typealias LDFlagChangeObserver = (LDChangedFlag<LDFlagType>) -> ()
public typealias LDFlagCollectionChangeObserver = ([String:LDChangedFlag<LDFlagType>]) -> ()
public typealias LDFlagObserverToken = String

public enum LDVariationSource {
    case cache, server, fallback
}
