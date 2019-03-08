//
//  LDTimerSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 1/22/19. +JMJ
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class LDTimerSpec: QuickSpec {

    struct Constants {
        static let oneMinute: TimeInterval = 60.0
        static let oneMilli: TimeInterval = 0.001
        static let fireQueueLabel = "LaunchDarkly.LDTimerSpec.TestContext.fireQueue"
        static let targetFireCount = 5
    }

    struct TestContext {
        var ldTimer: LDTimer
        let fireQueue: DispatchQueue = DispatchQueue(label: Constants.fireQueueLabel)
        let timeInterval: TimeInterval
        let repeats: Bool
        let fireDate: Date

        init(timeInterval: TimeInterval = Constants.oneMinute, repeats: Bool, execute: @escaping () -> Void) {
            self.timeInterval = timeInterval
            self.repeats = repeats
            self.fireDate = Date().addingTimeInterval(timeInterval)
            ldTimer = LDTimer(withTimeInterval: timeInterval, repeats: repeats, fireQueue: fireQueue, execute: execute)
        }
    }

    override func spec() {
        initSpec()
        timerFiredSpec()
        cancelSpec()
    }

    private func initSpec() {
        var testContext: TestContext!
        describe("init") {
            afterEach {
                testContext.ldTimer.cancel()
            }
            context("repeating timer") {
                beforeEach {
                    testContext = TestContext(repeats: true, execute: { })
                }
                it("creates a repeating timer") {
                    expect(testContext.ldTimer).toNot(beNil())
                    expect(testContext.ldTimer.timer).toNot(beNil())
                    expect(testContext.ldTimer.testFireQueue.label) == Constants.fireQueueLabel
                    expect(testContext.ldTimer.isRepeating) == testContext.repeats      //true
                    expect(testContext.ldTimer.isCancelled) == false
                    expect(testContext.ldTimer.fireDate?.isWithin(1.0, of: testContext.fireDate)).to(beTrue())  //1 second is arbitrary...just want it to be "close"
                }
            }
            context("one-time timer") {
                beforeEach {
                    testContext = TestContext(repeats: false, execute: { })
                }
                it("creates a one-time timer") {
                    expect(testContext.ldTimer).toNot(beNil())
                    expect(testContext.ldTimer.timer).toNot(beNil())
                    expect(testContext.ldTimer.testFireQueue.label) == Constants.fireQueueLabel
                    expect(testContext.ldTimer.isRepeating) == testContext.repeats      //false
                    expect(testContext.ldTimer.isCancelled) == false
                    expect(testContext.ldTimer.fireDate?.isWithin(1.0, of: testContext.fireDate)).to(beTrue())  //1 second is arbitrary...just want it to be "close"
                }
            }
        }
    }

    private func timerFiredSpec() {
        var testContext: TestContext!
        var fireQueueLabel: String?
        var fireCount = 0
        describe("timerFired") {
            context("one-time timer") {
                beforeEach {
                    waitUntil { done in
                        //timeInterval is arbitrary here. "Fast" so the test doesn't take a long time.
                        testContext = TestContext(timeInterval: Constants.oneMilli, repeats: false, execute: {
                            fireQueueLabel = DispatchQueue.currentQueueLabel
                            done()
                        })
                    }
                }
                it("calls execute on the fireQueue one time") {
                    expect(testContext.ldTimer.timer).to(beNil())
                    expect(fireQueueLabel).toNot(beNil())
                    expect(fireQueueLabel) == Constants.fireQueueLabel
                }
            }
            context("repeating timer") {
                beforeEach {
                    waitUntil { done in
                        //timeInterval is arbitrary here. "Fast" so the test doesn't take a long time.
                        testContext = TestContext(timeInterval: Constants.oneMilli, repeats: true, execute: {
                            if fireQueueLabel == nil {
                                fireQueueLabel = DispatchQueue.currentQueueLabel
                            }
                            if fireCount < Constants.targetFireCount {
                                fireCount += 1  //If the timer fires again before the test is done, that's ok. This just measures an arbitrary point in time.
                                if fireCount == Constants.targetFireCount {
                                    done()
                                }
                            }
                        })
                    }
                }
                afterEach {
                    testContext.ldTimer.cancel()
                }
                it("calls execute on the fireQueue multiple times") {
                    expect(testContext.ldTimer.timer).toNot(beNil())
                    expect(testContext.ldTimer.timer?.isValid) == true
                    expect(fireQueueLabel).toNot(beNil())
                    expect(fireQueueLabel) == Constants.fireQueueLabel
                    expect(fireCount) == Constants.targetFireCount      //targetFireCount is 5, and totally arbitrary. Want to measure that the repeating timer does in fact repeat.
                }
            }
        }
    }

    private func cancelSpec() {
        var testContext: TestContext!
        describe("cancel") {
            context("one-time timer") {
                beforeEach {
                    testContext = TestContext(repeats: false, execute: { })

                    testContext.ldTimer.cancel()
                }
                it("cancels the timer") {
                    expect(testContext.ldTimer.timer?.isValid ?? false) == false    //the timer either doesn't exist or is invalid...could be either depending on timing
                    expect(testContext.ldTimer.isCancelled) == true
                }
            }
            context("repeating timer") {
                beforeEach {
                    testContext = TestContext(repeats: true, execute: { })

                    testContext.ldTimer.cancel()
                }
                it("cancels the timer") {
                    expect(testContext.ldTimer.timer?.isValid ?? false) == false    //the timer either doesn't exist or is invalid...could be either depending on timing
                    expect(testContext.ldTimer.isCancelled) == true
                }
            }
        }
    }
}

extension DispatchQueue {
    class var currentQueueLabel: String? {
        return String(validatingUTF8: __dispatch_queue_get_label(nil))    //from https://gitlab.com/theswiftdev/swift/snippets/1741827/raw
    }
}
