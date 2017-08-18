//
//  LDChangedFlag.swift
//  Darkly
//
//  Created by Mark Pokorny on 8/18/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

public struct LDChangedFlag<T> where T: LDFlaggable {
    public let key: String
    public let oldValue: T?
    public let newValue: T?
}
