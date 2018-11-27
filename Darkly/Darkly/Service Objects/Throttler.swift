//
//  Throttler.swift
//  Darkly
//
//  Created by Mark Pokorny on 5/14/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
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

    private (set) var maxDelay: TimeInterval
    var maxAttempts: Int { return Int(ceil(log2(maxDelay))) }
    private (set) var runAttempts: Int
    private (set) var delay: TimeInterval
    private (set) var timerStart: Date?
    private (set) weak var delayTimer: Timer?
    private var runClosure: RunClosure?
    private var runPostTimer: RunClosure?
    private var runQueue = DispatchQueue(label: Constants.runQueueName, qos: .userInitiated)

    init(maxDelay: TimeInterval = Constants.defaultDelay) {
        self.maxDelay = maxDelay
        runAttempts = 0
        delay = 0.0
    }

    func runThrottled(_ runClosure: @escaping RunClosure) {
        guard delay < maxDelay else {
            runAttempts += 1
            self.runClosure = runClosure
            Log.debug(typeName(and: #function) + "Delay interval at max, allowing delay timer to expire. Run Attempts: \(runAttempts)")
            return
        }

        runQueue.sync { [weak self] in
            self?.delayTimer?.invalidate()
            self?.delayTimer = nil
        }

        if runAttempts == 0 {
            Log.debug(typeName(and: #function) + "Executing run closure on first attempt.")
            runClosure()
        } else {
            self.runClosure = runClosure
        }

        runAttempts += 1
        delay =  delayForAttempt(runAttempts)
        delayTimer = delayTimer(for: delay)
        if runAttempts > 1 {
            Log.debug(typeName(and: #function) + "Throttling run closure. Run attempts: \(runAttempts), Delay: \(delay)")
        }
    }

    func cancelThrottledRun() {
        delayTimer?.invalidate()
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
        guard Double(attempt) <= log2(maxDelay) else { return maxDelay }
        let exponentialBackoff = min(maxDelay, pow(2, attempt).timeInterval)        //pow(x, y) returns x^y
        let jitterBackoff = Double(arc4random_uniform(UInt32(exponentialBackoff)))  // arc4random_uniform(upperBound) returns an Int uniformly randomized between 0..<upperBound
        return exponentialBackoff/2 + jitterBackoff/2                               //half of each should yield [2^(runAttempts-1), 2^runAttempts)
    }

    private func delayTimer(for delay: TimeInterval) -> Timer {
        timerStart = timerStart ?? Date()
        let fire = timerStart!.addingTimeInterval(delay)
        let timer = Timer(fireAt: fire, interval: 0.0, target: self, selector: #selector(timerFired), userInfo: nil, repeats: false)
        RunLoop.current.add(timer, forMode: RunLoop.Mode.default)
        return timer
    }

    @objc func timerFired() {
        runQueue.async { [weak self] in
            if self?.runAttempts ?? 0 > 1 {
                DispatchQueue.main.async {
                    self?.runClosure?()
                    self?.runClosure = nil
                }
            }

            self?.resetTimingData()

            self?.runPostTimer?()
            self?.runPostTimer = nil
        }
    }
}

extension Throttler: TypeIdentifying { }

extension Decimal {
    var timeInterval: TimeInterval { return NSDecimalNumber(decimal: self).doubleValue }
}

#if DEBUG
    extension Throttler {
        var runClosureForTesting: RunClosure? { return runClosure }
        var timerFiredCallback: RunClosure? {
            set { runPostTimer = newValue }
            get { return runPostTimer }
        }
        func test_delayForAttempt(_ attempt: Int) -> TimeInterval { return delayForAttempt(attempt) }
    }
#endif
