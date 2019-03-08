//
//  ThrottlerSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 5/14/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
@testable import LaunchDarkly

final class ThrottlerSpec: QuickSpec {

    struct Constants {
        static let maxDelay: TimeInterval = 10.0
    }

    override func spec() {
        initSpec()
        delaySpec()
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
                    expect(throttler.timerStart).to(beNil())
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
                    expect(throttler.timerStart).to(beNil())
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

    //Normally we don't test private methods, but this one had a bug and so this test was added...figured might as well keep it
    func delaySpec() {
        describe("delayForAttempt") {
            var environmentReporterMock: EnvironmentReportingMock!
            var throttler: Throttler!
            var lastDelay: TimeInterval!
            context("throttling enabled") {
                beforeEach {
                    environmentReporterMock = EnvironmentReportingMock()
                    throttler = Throttler(maxDelay: Constants.maxDelay, environmentReporter: environmentReporterMock)
                }
                it("increases delay with each attempt") {
                    for _ in 0..<100 {
                        for attempt in 1...throttler.maxAttempts {
                            let delay = throttler.test_delayForAttempt(attempt)
                            if attempt > 1 {
                                expect(delay) > lastDelay
                            }
                            lastDelay = delay
                        }
                    }
                }
            }
            context("throttling disabled") {
                var environmentReportingMock: EnvironmentReportingMock!
                beforeEach {
                    environmentReportingMock = EnvironmentReportingMock()
                    environmentReportingMock.shouldThrottleOnlineCalls = false

                    throttler = Throttler(environmentReporter: environmentReportingMock)
                }
                it("always returns no delay") {
                    for attempt in 1...throttler.maxAttempts {
                        expect(throttler.test_delayForAttempt(attempt)) == 0.0
                    }
                }
            }
        }
    }

    //The upper bound on the max delay is always 2^runAttempt, exclusive.
    func maxDelay(runAttempt: Int) -> TimeInterval {
        return pow(2, runAttempt).timeInterval
    }

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
        var environmentReporterMock: EnvironmentReportingMock!
        var throttler: Throttler!
        var runCalled: Date!
        var runExecuted: Date?
        context("one runThrottled call") {
            beforeEach {
                environmentReporterMock = EnvironmentReportingMock()
                throttler = Throttler(maxDelay: Constants.maxDelay, environmentReporter: environmentReporterMock)

                runCalled = Date()
                waitUntil(timeout: self.maxDelay(runAttempt: 1)) { done in
                    throttler.timerFiredCallback = done
                    throttler.runThrottled({
                        runExecuted = Date()
                    })
                }
            }
            it("calls the run closure right away") {
                expect(runExecuted).toNot(beNil())
                guard let runExecuted = runExecuted
                else {
                    return
                }
                expect(runExecuted.timeIntervalSince(runCalled)) <= 0.1
            }
            it("resets itself for the next runThrottled call when the timer fires") {
                expect(throttler.runAttempts) == 0
                expect(throttler.delay) == 0.0
                expect(throttler.timerStart).to(beNil())
                expect(throttler.delayTimer).to(beNil())
            }
        }
    }

    func secondRunSpec() {
        var environmentReporterMock: EnvironmentReportingMock!
        var throttler: Throttler!
        var runCalled: Date!
        var runExecuted: [Date]!
        context("two runThrottled calls") {
            beforeEach {
                runExecuted = [Date]()
                environmentReporterMock = EnvironmentReportingMock()
                throttler = Throttler(maxDelay: Constants.maxDelay, environmentReporter: environmentReporterMock)

                runCalled = Date()
                waitUntil(timeout: self.maxDelay(runAttempt: 2)) { done in
                    throttler.timerFiredCallback = {
                        if runExecuted.count >= 2 {
                            done()
                        }
                    }

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
                else {
                    return
                }
                expect(firstRunExecuted.timeIntervalSince(runCalled)) <= 0.1    //0.1s is arbitrary, the min throttling delay is 1.0s. Anything less verifies unthrottled execution.

                //calls the run closure a second time after a delay
                expect(runExecuted.count) == 2
                guard let secondRunExecuted = runExecuted.last
                else {
                    return
                }
                expect(secondRunExecuted.timeIntervalSince(runCalled)) >= 2.0   //The delay is a random interval in the range [2.0, 4.0) seconds
                expect(secondRunExecuted.timeIntervalSince(runCalled)) < self.maxDelay(runAttempt: 2)   //as above, this must be < 4.0 seconds

                //resets itself for the next runThrottled call
                expect(throttler.runAttempts) == 0
                expect(throttler.delay) == 0.0
                expect(throttler.timerStart).to(beNil())
                expect(throttler.delayTimer).to(beNil())
            }
        }
    }

    func multipleRunSpec() {
        //This spec just tests that the delay is increased appropriately, without changing the original timer start time
        var environmentReporterMock: EnvironmentReportingMock!
        var throttler: Throttler!
        var runCount = 0
        var delayIntervals = [TimeInterval]()
        var timerStarted: Date!
        var timersExisted = [Bool]()

        context("multiple runThrottled calls") {
            beforeEach {
                environmentReporterMock = EnvironmentReportingMock()
                throttler = Throttler(maxDelay: Constants.maxDelay, environmentReporter: environmentReporterMock)

                for runAttempt in 0..<throttler.maxAttempts {
                    throttler.runThrottled {
                        runCount += 1
                    }
                    delayIntervals.append(throttler.delay)
                    if runAttempt == 0 {
                        timerStarted = throttler.timerStart
                    }
                    timersExisted.append(throttler.delayTimer != nil)
                }
            }
            it("increases the delay") {
                for runAttempt in 1..<throttler.maxAttempts {
                    //Because maxDelay for a runAttempt is in the range [2^(runAttempt -1), 2^runAttempt), the sequence of delay times for run attempts must be increasing
                    expect(delayIntervals[runAttempt - 1]) < delayIntervals[runAttempt]
                }
            }
            it("doesn't change the timer start date") {
                expect(throttler.timerStart).toNot(beNil())
                guard throttler.timerStart != nil
                else {
                    return
                }
                expect(throttler.timerStart!) == timerStarted
            }
            it("creates a timer") {
                expect(throttler.delayTimer).toNot(beNil())
            }
        }
    }

    func maxDelaySpec() {
        var environmentReporterMock: EnvironmentReportingMock!
        var throttler: Throttler!
        context("max delay is reached") {
            beforeEach {
                environmentReporterMock = EnvironmentReportingMock()
                throttler = Throttler(maxDelay: Constants.maxDelay, environmentReporter: environmentReporterMock)

                for _ in 0..<throttler.maxAttempts + 1 {
                    throttler.runThrottled { }
                }
            }
            it("limits the delay to the maximum") {
                expect(throttler.delay) == throttler.maxDelay
            }
        }
    }

    func throttlingDisabledRunSpec() {
        var throttler: Throttler!
        var environmentReportingMock: EnvironmentReportingMock!
        var runExecuted: Date?
        beforeEach {
            environmentReportingMock = EnvironmentReportingMock()
            environmentReportingMock.shouldThrottleOnlineCalls = false
            throttler = Throttler(maxDelay: Constants.maxDelay, environmentReporter: environmentReportingMock)
        }
        for _ in 0..<Throttler.maxAttempts(forDelay: Constants.maxDelay) {
            context("max runThrottled calls") {
                beforeEach {
                    throttler.runThrottled {
                        runExecuted = Date()
                    }
                }
                it("calls the run closure right away and does not prep for a throttled run") {
                    expect(runExecuted?.timeIntervalSinceNow) <= 0.001
                    expect(throttler.runAttempts) == 0
                    expect(throttler.delay) == 0.0
                    expect(throttler.timerStart).to(beNil())
                    expect(throttler.delayTimer).to(beNil())
                }
            }
        }
    }

    func cancelSpec() {
        var environmentReporterMock: EnvironmentReportingMock!
        var throttler: Throttler!
        var runCount = 0
        context("cancel") {
            beforeEach {
                environmentReporterMock = EnvironmentReportingMock()
                throttler = Throttler(maxDelay: Constants.maxDelay, environmentReporter: environmentReporterMock)

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
                expect(throttler.timerStart).to(beNil())
                expect(throttler.delayTimer).to(beNil())
                expect(throttler.runClosureForTesting).to(beNil())
                expect(runCount) == 1   //First run should proceed directly
            }
        }
    }
}
