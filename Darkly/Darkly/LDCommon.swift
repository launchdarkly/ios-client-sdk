//
//  LDCommon.swift
//  Darkly
//
//  Created by Mark Pokorny on 8/23/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

public typealias LDFlagChangeOwner = AnyObject
public typealias LDFlagKeyList = [String]
public typealias LDFlagChangeObserver = (LDChangedFlag) -> Void
public typealias LDFlagCollectionChangeObserver = ([String: LDChangedFlag]) -> Void
