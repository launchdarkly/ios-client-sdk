import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class BackgroundActivitySpec: QuickSpec {
    override func spec() {
        describe("a background activity") {
            var assertions = 0
            var released = 0
            var activity: BackgroundActivity!
            beforeEach {
                assertions = 0
                released = 0
                activity = BackgroundActivity(reason: "test") { _, work in
                    assertions += 1
                    work { released += 1 }
                }
            }

            it("holds the assertion until the work finishes") {
                var finish: (() -> Void)?
                activity.run { finish = $0 }

                expect(assertions) == 1
                expect(released) == 0

                finish?()
                expect(released) == 1
            }

            it("does not start a second assertion while one is held, and runs the later work under the first") {
                var finishFirst: (() -> Void)?
                var finishSecond: (() -> Void)?
                var secondRuns = 0
                activity.run { finishFirst = $0 }
                activity.run { finished in
                    secondRuns += 1
                    finishSecond = finished
                }

                expect(assertions) == 1
                expect(secondRuns) == 0

                finishFirst?()
                expect(secondRuns) == 1
                expect(released) == 0

                finishSecond?()
                expect(released) == 1
                expect(assertions) == 1
            }

            it("runs the work once more however many requests arrived while it was held") {
                var finishFirst: (() -> Void)?
                var laterRuns = 0
                activity.run { finishFirst = $0 }
                for _ in 0..<3 {
                    activity.run { finished in
                        laterRuns += 1
                        finished()
                    }
                }

                finishFirst?()
                expect(laterRuns) == 1
                expect(assertions) == 1
                expect(released) == 1
            }

            it("starts a new assertion once the held one is released") {
                activity.run { $0() }
                activity.run { $0() }

                expect(assertions) == 2
                expect(released) == 2
            }
        }

        describe("an assertion from the process") {
            /// Stands in for `performExpiringActivity`, which answers on a system queue rather than the caller's.
            ///
            /// Signals `ended` once the block it was given returns, which is when the real system would take the
            /// assertion back.
            func system(granting: Bool, ended: DispatchSemaphore) -> BackgroundActivity.ExpiringActivity {
                { _, whileGranted in
                    DispatchQueue.global().async {
                        whileGranted(!granting)
                        ended.signal()
                    }
                }
            }

            it("runs the work, and holds the assertion no longer, when the system grants one") {
                let ended = DispatchSemaphore(value: 0)
                let assertion = BackgroundActivity.processAssertion(logger: .disabled,
                                                                    perform: system(granting: true, ended: ended),
                                                                    maximumDuration: 30)

                var ran = false
                assertion("test") { finished in
                    ran = true
                    finished()
                }

                expect(ran) == true
                // Held for as long as the work took rather than the full 30s, which this would otherwise wait out.
                expect(ended.wait(timeout: .now() + 2)) == .success
            }

            it("runs the work even where the system refuses an assertion outright") {
                // Refusing calls the block once with `expired`, and never with `granted`. Work that ran inside that
                // block would never run at all, and under resource pressure that is exactly when it is needed.
                let ended = DispatchSemaphore(value: 0)
                let assertion = BackgroundActivity.processAssertion(logger: .disabled,
                                                                    perform: system(granting: false, ended: ended),
                                                                    maximumDuration: 30)

                var ran = false
                assertion("test") { finished in
                    ran = true
                    finished()
                }

                expect(ran) == true
                expect(ended.wait(timeout: .now() + 2)) == .success
            }

            it("gives up the assertion at the maximum, where the work never finishes") {
                let ended = DispatchSemaphore(value: 0)
                let assertion = BackgroundActivity.processAssertion(logger: .disabled,
                                                                    perform: system(granting: true, ended: ended),
                                                                    maximumDuration: 0.3)

                let started = Date()
                assertion("test") { _ in }

                expect(ended.wait(timeout: .now() + 3)) == .success
                // Ended by the cap, rather than by the work or by never having been held.
                expect(Date().timeIntervalSince(started)) > 0.2
            }
        }
    }
}
