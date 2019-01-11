//
//  ThrottlerSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 5/14/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
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
            var throttler: Throttler!
            var lastDelay: TimeInterval!
            context("throttling enabled") {
                beforeEach {
                    throttler = Throttler(maxDelay: Constants.maxDelay)
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
        var subject: Throttler!
        var runCalled: Date!
        var runExecuted: Date?
        context("one runThrottled call") {
            beforeEach {
                subject = Throttler(maxDelay: Constants.maxDelay)

                runCalled = Date()
                waitUntil(timeout: 2.0) { done in
                    subject.timerFiredCallback = done
                    subject.runThrottled({
                        runExecuted = Date()
                    })
                }
            }
            it("calls the run closure right away") {
                expect(runExecuted).toNot(beNil())
                guard let runExecuted = runExecuted else { return }
                expect(runExecuted.timeIntervalSince(runCalled)) <= 0.1
            }
            it("resets itself for the next runThrottled call") {
                expect(subject.runAttempts) == 0
                expect(subject.delay) == 0.0
                expect(subject.timerStart).to(beNil())
                expect(subject.delayTimer).to(beNil())
            }
        }
    }

    func secondRunSpec() {
        var subject: Throttler!
        var runCalled: Date!
        var runExecuted: [Date]!
        context("two runThrottled calls") {
            beforeEach {
                runExecuted = [Date]()
                subject = Throttler(maxDelay: Constants.maxDelay)

                runCalled = Date()
                waitUntil(timeout: 4.0) { done in
                    subject.timerFiredCallback = {
                        if runExecuted.count >= 2 {
                            done()
                        }
                    }

                    for _ in 0..<2 {
                        subject.runThrottled({
                            runExecuted.append(Date())
                            if runExecuted.count >= 2 {
                                done()
                            }
                        })
                    }
                }
            }
            //Normally, this would be 3 it closures. Since this test takes ~2-4 seconds to setup, all 3 it closures are squashed into 1
            it("calls the run closure right away, calls the run closure a second time after a delay, and resets itself for the next runThrottled call") {
                //calls the run closure right away
                expect(runExecuted.first).toNot(beNil())
                guard let firstRunExecuted = runExecuted.first else { return }
                expect(firstRunExecuted.timeIntervalSince(runCalled)) <= 0.1

                //calls the run closure a second time after a delay
                expect(runExecuted.count) == 2
                guard let secondRunExecuted = runExecuted.last else { return }
                expect(secondRunExecuted.timeIntervalSince(runCalled)) > 0.1
                expect(secondRunExecuted.timeIntervalSince(runCalled)) < 4.0

                //resets itself for the next runThrottled call
                expect(subject.runAttempts) == 0
                expect(subject.delay) == 0.0
                expect(subject.timerStart).to(beNil())
                expect(subject.delayTimer).to(beNil())
            }
        }
    }

    func multipleRunSpec() {
        var subject: Throttler!
        var runCount = 0
        var delayIntervals = [TimeInterval]()
        var timerStarted: Date!
        var timersExisted = [Bool]()

        context("multiple runThrottled calls") {
            beforeEach {
                subject = Throttler(maxDelay: Constants.maxDelay)

                for runAttempt in 0..<subject.maxAttempts {
                    subject.runThrottled {
                        runCount += 1
                    }
                    delayIntervals.append(subject.delay)
                    if runAttempt == 0 {
                        timerStarted = subject.timerStart
                    }
                    timersExisted.append(subject.delayTimer != nil)
                }
            }
            it("increases the delay") {
                for runAttempt in 1..<subject.maxAttempts {
                    expect(delayIntervals[runAttempt - 1]) < delayIntervals[runAttempt]
                }
            }
            it("doesn't change the timer start date") {
                expect(subject.timerStart).toNot(beNil())
                guard subject.timerStart != nil else { return }
                expect(subject.timerStart!) == timerStarted
            }
            it("creates a timer") {
                expect(subject.delayTimer).toNot(beNil())
            }
        }
    }

    func maxDelaySpec() {
        var subject: Throttler!
        context("max delay is reached") {
            beforeEach {
                subject = Throttler(maxDelay: Constants.maxDelay)

                for _ in 0..<subject.maxAttempts + 1 {
                    subject.runThrottled { }
                }
            }
            it("limits the delay to the maximum") {
                expect(subject.delay) == subject.maxDelay
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
        var subject: Throttler!
        var runCount = 0
        context("cancel") {
            beforeEach {
                subject = Throttler(maxDelay: Constants.maxDelay)

                for _ in 0..<subject.maxAttempts {
                    subject.runThrottled {
                        runCount += 1
                    }
                }

                subject.cancelThrottledRun()
            }
            it("cancels the scheduled run") {
                expect(subject.runAttempts) == 0
                expect(subject.delay) == 0.0
                expect(subject.timerStart).to(beNil())
                expect(subject.delayTimer).to(beNil())
                expect(subject.runClosureForTesting).to(beNil())
                expect(runCount) == 1   //First run should proceed directly
            }
        }
    }
}
