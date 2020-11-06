//
//  Throttler.swift
//  LaunchDarkly
//
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation

typealias RunClosure = () -> Void

//sourcery: autoMockable
protocol Throttling {
    func runThrottled(_ runClosure: @escaping RunClosure)
    func cancelThrottledRun()
}

final class Throttler: Throttling {
    struct Constants {
        static let defaultDelay: TimeInterval = 600.0
        fileprivate static let runQueueName = "LaunchDarkly.Throttler.runQueue"
    }

    private let runQueue = DispatchQueue(label: Constants.runQueueName, qos: .userInitiated)

    let throttlingEnabled: Bool
    let maxDelay: TimeInterval

    private (set) var runAttempts: Int = 0
    private (set) var delay: TimeInterval = 0.0
    private (set) var delayTimer: TimeResponding?

    private var maxAttemptsReached: Bool = false
    private var runClosure: RunClosure?

    init(maxDelay: TimeInterval = Constants.defaultDelay, environmentReporter: EnvironmentReporting = EnvironmentReporter()) {
        self.throttlingEnabled = environmentReporter.shouldThrottleOnlineCalls
        self.maxDelay = maxDelay
    }

    func runThrottled(_ runClosure: @escaping RunClosure) {
        if let logMsg = runThrottledSync(runClosure) { Log.debug(logMsg) }
    }

    func runThrottledSync(_ runClosure: @escaping RunClosure) -> String? {
        runQueue.sync {
            if !throttlingEnabled || runAttempts == 0 {
                runAttempts = 1
                DispatchQueue.global(qos: .userInitiated).async(execute: runClosure)
                return typeName(and: #function) + "Executing run closure unthrottled. Run Attempts: \(runAttempts). throttlingEnabled: \(throttlingEnabled)."
            }

            self.runClosure = runClosure

            if maxAttemptsReached {
                return typeName(and: #function) + "Delay interval at max, allowing delay timer to expire. Run Attempts: \(runAttempts)"
            }

            self.delay = delayForAttempt(runAttempts)
            self.runAttempts += 1
            self.delayTimer?.cancel()
            self.delayTimer = LDTimer(withTimeInterval: delay, repeats: false, fireQueue: runQueue, execute: timerFired)

            return typeName(and: #function) + "Throttling run closure. Run attempts: \(runAttempts), Delay: \(delay)"
        }
    }

    func cancelThrottledRun() {
        runQueue.sync {
            delayTimer?.cancel()
            reset()
        }
    }

    private func reset() {
        runAttempts = 0
        delay = 0.0
        maxAttemptsReached = false
        delayTimer = nil
        runClosure = nil
    }

    private func delayForAttempt(_ attempt: Int) -> TimeInterval {
        let exponential = pow(2.0, Double(attempt))
        if exponential >= maxDelay { self.maxAttemptsReached = true }
        let exponentialBackoff = min(maxDelay, exponential) / 2
        let jitterBackoff = Double.random(in: 0.0...exponentialBackoff)
        return exponentialBackoff + jitterBackoff
    }

    @objc func timerFired() {
        if let run = runClosure {
            DispatchQueue.global(qos: .userInitiated).async(execute: run)
        }
        reset()
    }
}

extension Throttler: TypeIdentifying { }
