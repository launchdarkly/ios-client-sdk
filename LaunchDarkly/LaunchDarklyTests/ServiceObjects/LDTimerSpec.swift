import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class LDTimerSpec: QuickSpec {

    struct TestContext {
        var ldTimer: LDTimer
        let fireQueue: DispatchQueue = DispatchQueue(label: "LaunchDarkly.LDTimerSpec.TestContext.fireQueue")
        let timeInterval: TimeInterval
        let fireDate: Date

        init(timeInterval: TimeInterval = 60.0, execute: @escaping () -> Void) {
            self.timeInterval = timeInterval
            self.fireDate = Date().addingTimeInterval(timeInterval)
            ldTimer = LDTimer(withTimeInterval: timeInterval, fireQueue: fireQueue, execute: execute)
        }
    }

    override func spec() {
        initSpec()
        timerFiredSpec()
        cancelSpec()
    }

    private func initSpec() {
        describe("init") {
            it("creates a repeating timer") {
                let testContext = TestContext(execute: { })

                expect(testContext.ldTimer.timer).toNot(beNil())
                expect(testContext.ldTimer.isCancelled) == false
                expect(testContext.ldTimer.fireDate).to(beCloseTo(testContext.fireDate, within: 1.0)) // 1 second is arbitrary...just want it to be "close"

                testContext.ldTimer.cancel()
            }
        }
    }

    private func timerFiredSpec() {
        describe("timerFired") {
            it("calls execute on the fireQueue multiple times") {
                var fireCount = 0
                var testContext: TestContext!
                waitUntil { done in
                    // timeInterval is arbitrary here. "Fast" so the test doesn't take a long time.
                    testContext = TestContext(timeInterval: 0.01, execute: {
                        dispatchPrecondition(condition: .onQueue(testContext.fireQueue))
                        if fireCount < 2 {
                            fireCount += 1  // If the timer fires again before the test is done, that's ok. This just measures an arbitrary point in time.
                        } else {
                            done()
                        }
                    })
                }

                expect(testContext.ldTimer.timer?.isValid) == true
                expect(testContext.ldTimer.isCancelled) == false
                expect(fireCount) == 2

                testContext.ldTimer.cancel()
            }
        }
    }

    private func cancelSpec() {
        describe("cancel") {
            it("cancels the timer") {
                let testContext = TestContext(execute: { })
                testContext.ldTimer.cancel()
                expect(testContext.ldTimer.timer?.isValid ?? false) == false    // the timer either doesn't exist or is invalid...could be either depending on timing
                expect(testContext.ldTimer.isCancelled) == true
            }
        }
    }
}
