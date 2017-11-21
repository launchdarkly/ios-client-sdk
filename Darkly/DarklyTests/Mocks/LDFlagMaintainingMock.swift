//
//  LDFlagMaintainingMock.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 11/20/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

extension LDFlagMaintainingMock {
    convenience init(flags: [String: Any]) {
        self.init()
        featureFlags = flags
        featureFlagsSetCount = 0
    }
}
