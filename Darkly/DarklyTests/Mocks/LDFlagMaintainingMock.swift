//
//  LDFlagMaintainingMock.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 11/20/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation
@testable import Darkly

extension LDFlagMaintainingMock {
    convenience init(flags: [String: Any]) {
        self.init()
        featureFlags = flags
        featureFlagsSetCount = 0
    }

    func variation<T: LDFlagValueConvertible>(forKey key: String, fallback: T) -> T {
        return featureFlags[key] as? T ?? fallback
    }

    func variationAndSource<T: LDFlagValueConvertible>(forKey key: String, fallback: T) -> (T, LDFlagValueSource) {
        guard let value = featureFlags[key] as? T else { return (fallback, .fallback) }
        return (value, .server)
    }
}
