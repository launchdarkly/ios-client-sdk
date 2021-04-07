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
        static let defaultDelay: TimeInterval = 60.0
        fileprivate static let runQueueName = "LaunchDarkly.Throttler.runQueue"
    }

    // Exposed to let tests keep tsan happy
    let runQueue = DispatchQueue(label: Constants.runQueueName, qos: .userInitiated)
    let dispatcher: ((@escaping RunClosure) -> Void)
    let throttlingEnabled: Bool
    let maxDelay: TimeInterval

    private (set) var runAttempts = -1
    private (set) var delayTimer: TimeResponding?
    private var runClosure: RunClosure?

    init(maxDelay: TimeInterval = Constants.defaultDelay,
         environmentReporter: EnvironmentReporting = EnvironmentReporter(),
         dispatcher: ((@escaping RunClosure) -> Void)? = nil) {
        self.throttlingEnabled = environmentReporter.shouldThrottleOnlineCalls
        self.maxDelay = maxDelay
        self.dispatcher = dispatcher ?? { DispatchQueue.global(qos: .userInitiated).async(execute: $0) }
    }

    func runThrottled(_ runClosure: @escaping RunClosure) {
        if let logMsg = runThrottledSync(runClosure) { Log.debug(logMsg) }
    }

    func runThrottledSync(_ runClosure: @escaping RunClosure) -> String? {
        runQueue.sync {
            if !throttlingEnabled {
                dispatcher(runClosure)
                return typeName(and: #function) + "Executing run closure unthrottled, as throttling is disabled."
            }

            runAttempts += 1

            let resetDelay = min(maxDelay, TimeInterval(pow(2.0, Double(runAttempts - 1))))
            if runAttempts > 0 {
                runQueue.asyncAfter(deadline: .now() + resetDelay) { self.decrementRunAttempts() }
            }

            if runAttempts <= 1 {
                dispatcher(runClosure)
                return typeName(and: #function) + "Executing run closure unthrottled."
            }

            let jittered = resetDelay / 2 + Double.random(in: 0.0...(resetDelay / 2))
            self.runClosure = runClosure
            self.delayTimer?.cancel()
            self.delayTimer = LDTimer(withTimeInterval: jittered, repeats: false, fireQueue: runQueue, execute: timerFired)
            return typeName(and: #function) + "Throttling run closure. Run attempts: \(runAttempts), Delay: \(jittered)"
        }
    }

    func cancelThrottledRun() {
        runQueue.sync {
            delayTimer?.cancel()
            reset()
        }
    }

    private func reset() {
        delayTimer = nil
        runClosure = nil
    }

    private func decrementRunAttempts() {
        if runAttempts > 0 {
            runAttempts -= 1
        }
    }

    @objc func timerFired() {
        if let run = runClosure {
            dispatcher(run)
        }
        reset()
    }
}

extension Throttler: TypeIdentifying { }
