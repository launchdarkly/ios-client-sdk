import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class ThrottlerSpec: QuickSpec {

    struct Constants {
        static let maxDelay: TimeInterval = 10.0
    }

    let dispatchQueue = DispatchQueue(label: "ThrottlerSpecQueue")

    func testThrottler(throttlingDisabled: Bool = false) -> Throttler {
        return Throttler(maxDelay: Constants.maxDelay,
                         isDebugBuild: throttlingDisabled,
                         dispatcher: { self.dispatchQueue.sync(execute: $0) })
    }

    override func spec() {
        initSpec()
        runSpec()
        cancelSpec()
    }

    func initSpec() {
        describe("init") {
            it("with a maxDelay parameter") {
                let throttler = Throttler(maxDelay: Constants.maxDelay)
                expect(throttler.maxDelay) == Constants.maxDelay
                expect(throttler.runAttempts) == -1
                expect(throttler.workItem).to(beNil())
            }
            it("without a maxDelay parameter") {
                let throttler = Throttler()
                expect(throttler.maxDelay) == Throttler.Constants.defaultDelay
                expect(throttler.runAttempts) == -1
                expect(throttler.workItem).to(beNil())
            }
            it("throttling controlled by environment reporter") {
                expect(self.testThrottler(throttlingDisabled: false).throttlingEnabled) == true
                expect(self.testThrottler(throttlingDisabled: true).throttlingEnabled) == false
            }
        }
    }

    func runSpec() {
        describe("runThrottled") {
            context("throttling enabled") {
                firstRunsSpec()
                immediateAfterDelaySpec()
                throttledRunSpec()
                maxDelaySpec()
            }
            context("throttling disabled") {
                throttlingDisabledRunSpec()
            }
        }
    }

    func firstRunsSpec() {
        it("first runs immediate") {
            var hasRun = false
            let throttler = self.testThrottler()
            throttler.runThrottled {
                hasRun = true
            }
            expect(hasRun) == true
            expect(throttler.safeRunAttempts) == 0
            expect(throttler.workItem).to(beNil())
            hasRun = false
            throttler.runThrottled {
                hasRun = true
            }
            expect(hasRun) == true
            expect(throttler.safeRunAttempts) == 1
            expect(throttler.workItem).to(beNil())
        }
    }

    func immediateAfterDelaySpec() {
        it("delay resets throttling") {
            let throttler = self.testThrottler()
            // First two run immediate
            throttler.runThrottled { }
            throttler.runThrottled { }
            // Keep tsan happy by accessing runAttempts on the appropriate thread
            expect(throttler.safeRunAttempts) == 1
            Thread.sleep(forTimeInterval: 1.5)
            expect(throttler.safeRunAttempts) == 0
            var hasRun = false
            throttler.runThrottled {
                hasRun = true
            }
            expect(hasRun) == true
            expect(throttler.safeRunAttempts) == 1
        }
    }

    func throttledRunSpec() {
        it("sequential calls are throttled") {
            let throttler = self.testThrottler()
            // First two run immediate
            throttler.runThrottled { }
            throttler.runThrottled { }
            expect(throttler.safeRunAttempts) == 1
            let callDate = Date()
            var runDate: Date?
            waitUntil(timeout: .seconds(3)) { done in
                throttler.runThrottled {
                    runDate = Date()
                    done()
                }
                expect(runDate).to(beNil())
            }
            expect(runDate) >= callDate + 1
            expect(runDate) <= callDate + 2.5
        }
    }

    func maxDelaySpec() {
        it("limits delay to maxDelay") {
            let throttler = Throttler(maxDelay: 1.0, isDebugBuild: false)
            (0..<10).forEach { _ in throttler.runThrottled { } }
            let callDate = Date()
            var runDate: Date?
            waitUntil(timeout: .seconds(2)) { done in
                throttler.runThrottled {
                    runDate = Date()
                    done()
                }
                expect(runDate).to(beNil())
            }
            expect(runDate) >= callDate + 0.5
            expect(runDate) <= callDate + 1.5
            throttler.cancelThrottledRun()
        }
    }

    func throttlingDisabledRunSpec() {
        it("never throttles") {
            let throttler = self.testThrottler(throttlingDisabled: true)
            for _ in 0..<5 {
                var hasRun = false
                throttler.runThrottled {
                    hasRun = true
                }
                expect(hasRun).to(beTrue())
                hasRun = false
            }
        }
    }

    func cancelSpec() {
        it("can be cancelled") {
            let throttler = self.testThrottler()
            // Two immediate runs
            throttler.runThrottled { }
            throttler.runThrottled { }
            // Should be throttled
            var hasRun = false
            throttler.runThrottled {
                hasRun = true
            }
            throttler.cancelThrottledRun()
            expect(throttler.safeRunAttempts) == 2
            expect(throttler.workItem).to(beNil())
            // Wait until run would have occured
            Thread.sleep(forTimeInterval: 1.0)
            expect(hasRun).to(beFalse())
        }
    }
}

// Used to keep tsan happy by accessing runAttempts on the appropriate thread
fileprivate extension Throttler {
    var safeRunAttempts: Int {
        runQueue.sync { runAttempts }
    }
}
