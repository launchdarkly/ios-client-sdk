//
//  Throttler.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 5/14/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation

typealias RunClosure = () -> Void

//sourcery: AutoMockable
protocol Throttling {
    //sourcery: DefaultMockValue = 600.0
    var maxDelay: TimeInterval { get }

    func runThrottled(_ runClosure: @escaping RunClosure)
    func cancelThrottledRun()
}

final class Throttler: Throttling {
    struct Constants {
        static let defaultDelay: TimeInterval = 600.0
        fileprivate static let runQueueName = "LaunchDarkly.Throttler.runQueue"
    }

    class func maxAttempts(forDelay delayInterval: TimeInterval) -> Int {
        return Int(ceil(log2(delayInterval)))
    }

    let throttlingEnabled: Bool
    private (set) var maxDelay: TimeInterval
    var maxAttempts: Int {
        return Throttler.maxAttempts(forDelay: maxDelay)
    }
    private (set) var runAttempts: Int
    private (set) var delay: TimeInterval
    private (set) var timerStart: Date?
    private (set) var delayTimer: TimeResponding?
    private var runClosure: RunClosure?
    private var runPostTimer: RunClosure?
    private var runQueue = DispatchQueue(label: Constants.runQueueName, qos: .userInitiated)

    init(maxDelay: TimeInterval = Constants.defaultDelay, environmentReporter: EnvironmentReporting = EnvironmentReporter()) {
        self.maxDelay = maxDelay
        runAttempts = 0
        delay = 0.0
        throttlingEnabled = environmentReporter.shouldThrottleOnlineCalls
    }

    func runThrottled(_ runClosure: @escaping RunClosure) {
        guard delay < maxDelay
        else {
            runAttempts += 1
            self.runClosure = runClosure
            Log.debug(typeName(and: #function) + "Delay interval at max, allowing delay timer to expire. Run Attempts: \(runAttempts)")
            return
        }

        runQueue.sync { [weak self] in
            self?.delayTimer?.cancel()
            self?.delayTimer = nil
        }

        if runAttempts == 0 || !throttlingEnabled {
            Log.debug(typeName(and: #function) + "Executing run closure unthrottled. Run Attempts: \(runAttempts). throttlingEnabled: \(throttlingEnabled).")
            runClosure()
        } else {
            self.runClosure = runClosure
        }

        runAttempts += throttlingEnabled ? 1 : 0
        delay = delayForAttempt(runAttempts)
        delayTimer = delayTimer(for: delay)
        if runAttempts > 1 {
            Log.debug(typeName(and: #function) + "Throttling run closure. Run attempts: \(runAttempts), Delay: \(delay)")
        }
    }

    func cancelThrottledRun() {
        delayTimer?.cancel()
        runClosure = nil
        resetTimingData()
        runPostTimer = nil
    }

    private func resetTimingData() {
        runAttempts = 0
        delay = 0.0
        delayTimer = nil
        timerStart = nil
    }

    private func delayForAttempt(_ attempt: Int) -> TimeInterval {
        guard throttlingEnabled
        else {
            return 0.0
        }
        guard Double(attempt) <= log2(maxDelay)
        else {
            return maxDelay
        }
        let exponentialBackoff = min(maxDelay, pow(2, attempt).timeInterval)        //pow(x, y) returns x^y
        let jitterBackoff = Double(arc4random_uniform(UInt32(exponentialBackoff)))  // arc4random_uniform(upperBound) returns an Int uniformly randomized between 0..<upperBound
        return exponentialBackoff/2 + jitterBackoff/2                               //half of each should yield [2^(runAttempts-1), 2^runAttempts)
    }

    private func delayTimer(for delay: TimeInterval) -> TimeResponding? {
        guard throttlingEnabled
        else {
            return nil
        }
        timerStart = timerStart ?? Date()
        let timer = LDTimer(withTimeInterval: delay, repeats: false, fireQueue: runQueue, execute: timerFired)
        return timer
    }

    @objc func timerFired() {
        //This code should be run in the runQueue. When the LDTimer fires, it will run this code in the runQueue.
        if runAttempts > 1 {
            DispatchQueue.main.async {
                self.runClosure?()
                self.runClosure = nil
            }
        }

        resetTimingData()

        runPostTimer?()
        runPostTimer = nil
    }
}

extension Throttler: TypeIdentifying { }

extension Decimal {
    var timeInterval: TimeInterval {
        return NSDecimalNumber(decimal: self).doubleValue
    }
}

#if DEBUG
    extension Throttler {
        var runClosureForTesting: RunClosure? {
            return runClosure
        }
        var timerFiredCallback: RunClosure? {
            set {
                runPostTimer = newValue
            }
            get {
                return runPostTimer
            }
        }
        func test_delayForAttempt(_ attempt: Int) -> TimeInterval {
            return delayForAttempt(attempt)
        }
    }
#endif
