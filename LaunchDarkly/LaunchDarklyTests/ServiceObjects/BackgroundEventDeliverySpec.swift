import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class BackgroundEventDeliverySpec: QuickSpec {
    override func spec() {
        describe("going to the background") {
            var primary: EventProcessorMock!
            var secondary: EventProcessorMock!
            var environments: [BackgroundEventDelivery.Environment] = []
            var assertions = 0
            var released = 0
            var activity: BackgroundActivity!
            beforeEach {
                primary = EventProcessorMock()
                secondary = EventProcessorMock()
                environments = [BackgroundEventDelivery.Environment(name: "primary", eventProcessor: primary, logger: .disabled),
                                BackgroundEventDelivery.Environment(name: "secondary", eventProcessor: secondary, logger: .disabled)]
                assertions = 0
                released = 0
                activity = BackgroundActivity(reason: "test") { _, work in
                    assertions += 1
                    work { released += 1 }
                }
            }

            func delivery(suspendsWhenBackgrounded: Bool) -> BackgroundEventDelivery {
                BackgroundEventDelivery(environments: { environments },
                                        suspendsWhenBackgrounded: suspendsWhenBackgrounded,
                                        activity: activity)
            }

            it("commits every environment, and delivers nothing, where the platform does not suspend") {
                delivery(suspendsWhenBackgrounded: false).applicationDidEnterBackground()

                expect(primary.commitWherePersistingCallCount) == 1
                expect(secondary.commitWherePersistingCallCount) == 1
                expect(primary.flushReportingOutcomeCallCount) == 0
                expect(secondary.flushReportingOutcomeCallCount) == 0
                expect(assertions) == 0
            }

            it("commits every environment before it delivers any, where the platform suspends") {
                var committedBeforeDelivering = false
                primary.flushReportingOutcomeCallback = {
                    committedBeforeDelivering = primary.commitWherePersistingCallCount == 1
                        && secondary.commitWherePersistingCallCount == 1
                }

                delivery(suspendsWhenBackgrounded: true).applicationDidEnterBackground()

                expect(primary.flushReportingOutcomeCallCount) == 1
                expect(secondary.flushReportingOutcomeCallCount) == 1
                expect(committedBeforeDelivering) == true
            }

            it("takes one assertion for every environment, and holds it until all of them answer") {
                let subject = delivery(suspendsWhenBackgrounded: true)
                subject.applicationDidEnterBackground()

                expect(assertions) == 1
                expect(released) == 0

                primary.flushReportingOutcomeReceivedCompletion?(true)
                expect(released) == 0

                secondary.flushReportingOutcomeReceivedCompletion?(true)
                expect(released) == 1
            }

            it("releases the assertion where deliveries fail too") {
                let subject = delivery(suspendsWhenBackgrounded: true)
                subject.applicationDidEnterBackground()

                primary.flushReportingOutcomeReceivedCompletion?(false)
                secondary.flushReportingOutcomeReceivedCompletion?(true)
                expect(released) == 1
            }

            it("waits for every environment where one answers twice") {
                let subject = delivery(suspendsWhenBackgrounded: true)
                subject.applicationDidEnterBackground()

                primary.flushReportingOutcomeReceivedCompletion?(true)
                primary.flushReportingOutcomeReceivedCompletion?(true)
                expect(released) == 0

                secondary.flushReportingOutcomeReceivedCompletion?(true)
                secondary.flushReportingOutcomeReceivedCompletion?(true)
                expect(released) == 1
            }

            it("releases the assertion where an environment never answers, so a later backgrounding still delivers") {
                var releases = 0
                let lock = UnfairLock()
                let counted = BackgroundActivity(reason: "test") { _, work in
                    work { lock.withLock { releases += 1 } }
                }
                let subject = BackgroundEventDelivery(environments: { environments },
                                                      suspendsWhenBackgrounded: true,
                                                      activity: counted,
                                                      answerTimeout: 0.1)
                subject.applicationDidEnterBackground()
                primary.flushReportingOutcomeReceivedCompletion?(true)
                expect(lock.withLock { releases }).toEventually(equal(1))

                subject.applicationDidEnterBackground()
                expect(primary.flushReportingOutcomeCallCount) == 2
            }

            it("takes no assertion where no client is started") {
                environments = []
                delivery(suspendsWhenBackgrounded: true).applicationDidEnterBackground()

                expect(assertions) == 0
            }

            it("reads the environments at each backgrounding") {
                let subject = delivery(suspendsWhenBackgrounded: false)
                environments.removeLast()
                subject.applicationDidEnterBackground()

                expect(primary.commitWherePersistingCallCount) == 1
                expect(secondary.commitWherePersistingCallCount) == 0
            }
        }
    }
}
