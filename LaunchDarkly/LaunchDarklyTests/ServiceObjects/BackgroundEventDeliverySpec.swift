import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class BackgroundEventDeliverySpec: QuickSpec {
    override func spec() {
        describe("going to the background") {
            var eventProcessor: EventProcessorMock!
            var assertions = 0
            var released = 0
            var activity: BackgroundActivity!
            beforeEach {
                eventProcessor = EventProcessorMock()
                assertions = 0
                released = 0
                activity = BackgroundActivity(reason: "test") { _, work in
                    assertions += 1
                    work { released += 1 }
                }
            }

            func delivery(suspendsWhenBackgrounded: Bool) -> BackgroundEventDelivery {
                BackgroundEventDelivery(eventProcessor: eventProcessor,
                                        suspendsWhenBackgrounded: suspendsWhenBackgrounded,
                                        activity: activity,
                                        logger: .disabled)
            }

            it("commits, and delivers nothing, where the platform does not suspend") {
                delivery(suspendsWhenBackgrounded: false).applicationDidEnterBackground()

                expect(eventProcessor.commitWherePersistingCallCount) == 1
                expect(eventProcessor.flushReportingOutcomeCallCount) == 0
                expect(assertions) == 0
            }

            it("commits before it delivers, where the platform suspends") {
                var committedBeforeDelivering = false
                eventProcessor.flushReportingOutcomeCallback = {
                    committedBeforeDelivering = eventProcessor.commitWherePersistingCallCount == 1
                }

                delivery(suspendsWhenBackgrounded: true).applicationDidEnterBackground()

                expect(eventProcessor.flushReportingOutcomeCallCount) == 1
                expect(committedBeforeDelivering) == true
            }

            it("holds the assertion until the delivery answers") {
                let subject = delivery(suspendsWhenBackgrounded: true)
                subject.applicationDidEnterBackground()

                expect(assertions) == 1
                expect(released) == 0

                eventProcessor.flushReportingOutcomeReceivedCompletion?(true)
                expect(released) == 1
            }

            it("releases the assertion where the delivery fails too") {
                let subject = delivery(suspendsWhenBackgrounded: true)
                subject.applicationDidEnterBackground()

                eventProcessor.flushReportingOutcomeReceivedCompletion?(false)
                expect(released) == 1
            }
        }
    }
}
