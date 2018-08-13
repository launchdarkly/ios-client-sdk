//
//  LDChangedFlag.swift
//  Darkly
//
//  Created by Mark Pokorny on 8/18/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

public struct LDChangedFlag {
    public let key: LDFlagKey
    public let oldValue: Any?
    public let oldValueSource: LDFlagValueSource?
    public let newValue: Any?
    public let newValueSource: LDFlagValueSource?
    
    init(key: LDFlagKey, oldValue: Any?, oldValueSource: LDFlagValueSource?, newValue: Any?, newValueSource: LDFlagValueSource?) {
        self.key = key
        self.oldValue = oldValue
        self.oldValueSource = oldValueSource
        self.newValue = newValue
        self.newValueSource = newValueSource
    }
}
