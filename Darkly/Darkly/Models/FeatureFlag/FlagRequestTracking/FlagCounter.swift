//
//  FlagCounter.swift
//  Darkly
//
//  Created by Mark Pokorny on 6/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation

struct FlagCounter {
    let flagKey: String
    var defaultValue: Any?
    var flagValueCounters = [FlagValueCounter]()

    init(flagKey: String, defaultValue: Any?) {
        self.flagKey = flagKey
        self.defaultValue = defaultValue
    }
}
