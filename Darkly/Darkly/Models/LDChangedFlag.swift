//
//  LDChangedFlag.swift
//  Darkly
//
//  Created by Mark Pokorny on 8/18/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

public struct LDChangedFlag {
    public let key: String
    public let oldValue: LDFlagValue?
    public let oldValueSource: LDFlagValueSource?
    public let newValue: LDFlagValue?
    public let newValueSource: LDFlagValueSource?
    
    init(key: String, oldValue: LDFlagValueConvertible?, oldValueSource: LDFlagValueSource?, newValue: LDFlagValueConvertible?, newValueSource: LDFlagValueSource?) {
        self.key = key
        self.oldValue = oldValue?.toLDFlagValue()
        self.oldValueSource = oldValueSource
        self.newValue = newValue?.toLDFlagValue()
        self.newValueSource = newValueSource
    }
}
