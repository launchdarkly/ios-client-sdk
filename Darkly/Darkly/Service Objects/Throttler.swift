//
//  Throttler.swift
//  Darkly
//
//  Created by Mark Pokorny on 5/14/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation

final class Throttler {
    struct Constants {
        static let maxDelay: TimeInterval = 600.0
    }

    internal (set) var maxDelay: TimeInterval
    internal (set) var runAttempts: Int
    internal (set) var delay: TimeInterval
    internal (set) var timerStart: Date?
    internal (set) var delayTimer: Timer?
    private var run: (() -> Void)?

    init(maxDelay: TimeInterval = Constants.maxDelay) {
        self.maxDelay = maxDelay
        runAttempts = 0
        delay = 0.0
    }
}
