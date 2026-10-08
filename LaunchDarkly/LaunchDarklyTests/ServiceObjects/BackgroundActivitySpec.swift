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
    }
}
