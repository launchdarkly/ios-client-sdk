//
//  ThrottlerSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class ThrottlerSpec: QuickSpec {

    struct Constants {
        static let maxDelay: TimeInterval = 10.0
        static let testThreshold: TimeInterval = 0.15
    }

    override func spec() {
        initSpec()
        runSpec()
        cancelSpec()
    }

    func initSpec() {
        describe("init") {
            var throttler: Throttler!
            context("with a maxDelay parameter") {
                beforeEach {
                    throttler = Throttler(maxDelay: Constants.maxDelay)
                }
                it("sets the maxDelay") {
                    expect(throttler.maxDelay) == Constants.maxDelay
                }
                it("is ready for the first run") {
                    expect(throttler.runAttempts) == 0
                    expect(throttler.delay) == 0.0
                    expect(throttler.delayTimer).to(beNil())
                }
            }
            context("without a maxDelay parameter") {
                beforeEach {
                    throttler = Throttler()
                }
                it("sets the maxDelay constant") {
                    expect(throttler.maxDelay) == Throttler.Constants.defaultDelay
                }
                it("is ready for the first run") {
                    expect(throttler.runAttempts) == 0
                    expect(throttler.delay) == 0.0
                    expect(throttler.delayTimer).to(beNil())
                }
            }
            context("with an environment reporter") {
                var environmentReportingMock: EnvironmentReportingMock!
                beforeEach {
                    environmentReportingMock = EnvironmentReportingMock()
                }
                context("throttling enabled") {
                    beforeEach {
                        throttler = Throttler(environmentReporter: environmentReportingMock)
                    }
                    it("should throttle") {
                        expect(throttler.throttlingEnabled) == true
                    }
                }
                context("throttling disabled") {
                    beforeEach {
                        environmentReportingMock.shouldThrottleOnlineCalls = false

                        throttler = Throttler(environmentReporter: environmentReportingMock)
                    }
                    it("should not throttle") {
                        expect(throttler.throttlingEnabled) == false
                    }
                }
            }
        }
    }

    //The upper bound on the max delay is always 2^runAttempt, exclusive.
    func maxDelay(runAttempt: Int) -> DispatchTimeInterval { .seconds(Int(pow(2.0, Double(runAttempt)))) }

    func runSpec() {
        describe("runThrottled") {
            context("throttling enabled") {
                firstRunSpec()
                secondRunSpec()
                multipleRunSpec()
                maxDelaySpec()
            }
            context("throttling disabled") {
                throttlingDisabledRunSpec()
            }
        }
    }

    func firstRunSpec() {
        var throttler: Throttler!
        var runCalled: Date!
        var runExecuted: Date?
        context("one runThrottled call") {
            beforeEach {
                throttler = Throttler(maxDelay: Constants.maxDelay, environmentReporter: EnvironmentReportingMock())

                runCalled = Date()
                waitUntil(timeout: self.maxDelay(runAttempt: 1)) { done in
                    throttler.runThrottled({
                        runExecuted = Date()
                        done()
                    })
                }
            }
            it("calls the run closure right away") {
                expect(runExecuted).toNot(beNil())
                guard let runExecuted = runExecuted
                else { return }
                expect(runExecuted.timeIntervalSince(runCalled)) <= Constants.testThreshold
            }
            it("resets itself for the next runThrottled call when the timer fires") {
                expect(throttler.runAttempts) == 1
                expect(throttler.delay) == 0.0
                expect(throttler.delayTimer).to(beNil())
            }
        }
    }

    func secondRunSpec() {
        var throttler: Throttler!
        var runCalled: Date!
        var runExecuted: [Date]!
        context("two runThrottled calls") {
            beforeEach {
                runExecuted = [Date]()
                throttler = Throttler(maxDelay: Constants.maxDelay, environmentReporter: EnvironmentReportingMock())

                runCalled = Date()
                waitUntil(timeout: .seconds(5)) { done in
                    for _ in 0..<2 {
                        throttler.runThrottled({
                            runExecuted.append(Date())
                            if runExecuted.count >= 2 {
                                done()
                            }
                        })
                    }
                }
            }
            //Normally, this would be 3 "it" closures. Since this test takes ~2-4 seconds to setup, all 3 it closures are squashed into 1
            it("calls the run closure right away, calls the run closure a second time after a delay, and resets itself for the next runThrottled call") {
                //calls the run closure right away
                expect(runExecuted.first).toNot(beNil())
                guard let firstRunExecuted = runExecuted.first
                else { return }
                expect(firstRunExecuted.timeIntervalSince(runCalled)) <= Constants.testThreshold

                //calls the run closure a second time after a delay
                expect(runExecuted.count) == 2
                guard let secondRunExecuted = runExecuted.last
                else { return }
                //The delay is a random interval in the range [1.0, 2.0) seconds, with a test threshold on the upper limit to account for delay in executing the task.
                expect(secondRunExecuted.timeIntervalSince(runCalled)) >= 1.0
                expect(secondRunExecuted.timeIntervalSince(runCalled)) <= 2.0 + Constants.testThreshold

                //resets itself for the next runThrottled call
                expect(throttler.runAttempts) == 0
                expect(throttler.delay) == 0.0
                expect(throttler.delayTimer).to(beNil())
            }
        }
    }

    func multipleRunSpec() {
        //This spec just tests that the delay is increased appropriately
        var throttler: Throttler!
        var delayIntervals = [TimeInterval]()
        var timersExisted = [Bool]()

        context("multiple runThrottled calls") {
            beforeEach {
                throttler = Throttler(maxDelay: Constants.maxDelay, environmentReporter: EnvironmentReportingMock())

                for _ in 0..<throttler.maxAttempts {
                    throttler.runThrottled { }
                    delayIntervals.append(throttler.delay)
                    timersExisted.append(throttler.delayTimer != nil)
                }
            }
            it("increases the delay") {
                for runAttempt in 1..<throttler.maxAttempts {
                    //Because maxDelay for a runAttempt is in the range [2^(runAttempt -1), 2^runAttempt), the sequence of delay times for run attempts must be increasing
                    expect(delayIntervals[runAttempt - 1]) < delayIntervals[runAttempt]
                }
            }
            it("creates a timer") {
                expect(throttler.delayTimer).toNot(beNil())
            }
        }
    }

    func maxDelaySpec() {
        var throttler: Throttler!
        context("max delay is reached") {
            beforeEach {
                throttler = Throttler(maxDelay: Constants.maxDelay, environmentReporter: EnvironmentReportingMock())
                (0..<10).forEach { _ in throttler.runThrottled { } }
            }
            afterEach { throttler?.cancelThrottledRun() }
            for _ in 0..<10 {
                it("limits the delay to the maximum") {
                    expect(throttler.delay) <= throttler.maxDelay
                }
            }
        }
    }

    func throttlingDisabledRunSpec() {
        var throttler: Throttler!
        beforeEach {
            let environmentReportingMock = EnvironmentReportingMock()
            environmentReportingMock.shouldThrottleOnlineCalls = false
            throttler = Throttler(maxDelay: Constants.maxDelay, environmentReporter: environmentReportingMock)
        }
        for _ in 0..<5 {
            context("max runThrottled calls") {
                beforeEach {
                    waitUntil(timeout: .milliseconds(100)) { done in
                        throttler.runThrottled(done)
                    }
                }
                it("calls the run closure right away and does not prep for a throttled run") {
                    expect(throttler.runAttempts) == 1
                    expect(throttler.delay) == 0.0
                    expect(throttler.delayTimer).to(beNil())
                }
            }
        }
    }

    func cancelSpec() {
        var throttler: Throttler!
        var runCount = 0
        context("cancel") {
            beforeEach {
                throttler = Throttler(maxDelay: Constants.maxDelay, environmentReporter: EnvironmentReportingMock())

                for _ in 0..<throttler.maxAttempts {
                    throttler.runThrottled {
                        runCount += 1
                        if runCount > 1 {
                            fail("run closure called more than once.")
                        }
                    }
                }

                throttler.cancelThrottledRun()
            }
            it("cancels the scheduled run") {
                expect(throttler.runAttempts) == 0
                expect(throttler.delay) == 0.0
                expect(throttler.delayTimer).to(beNil())
                expect(runCount) == 1   //First run should proceed directly
            }
        }
    }
}

fileprivate extension Throttler {
    var maxAttempts: Int { Int(log2(maxDelay)) }
}
