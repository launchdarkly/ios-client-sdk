import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class EventProcessorOutcomesSpec: QuickSpec {
    override func spec() {
        describe("flushing several processors") {
            var first: EventProcessorMock!
            var second: EventProcessorMock!
            var answers: [[Bool]] = []
            var processors: [EventProcessor] { [first!, second!] }
            beforeEach {
                first = EventProcessorMock()
                second = EventProcessorMock()
                answers = []
            }

            it("answers with each processor's outcome, in order, once all of them have answered") {
                processors.flushReportingOutcomes { answers.append($0) }
                second.flushReportingOutcomeReceivedCompletion?(false)
                expect(answers) == []

                first.flushReportingOutcomeReceivedCompletion?(true)
                expect(answers) == [[true, false]]
            }

            it("answers at once where there are no processors") {
                [EventProcessor]().flushReportingOutcomes { answers.append($0) }
                expect(answers) == [[]]
            }

            it("waits for every processor where one answers twice, and answers once") {
                processors.flushReportingOutcomes { answers.append($0) }
                first.flushReportingOutcomeReceivedCompletion?(true)
                first.flushReportingOutcomeReceivedCompletion?(false)
                expect(answers) == []

                second.flushReportingOutcomeReceivedCompletion?(true)
                second.flushReportingOutcomeReceivedCompletion?(true)
                expect(answers) == [[true, true]]
            }

            it("waits for a processor that never answers, where there is no deadline") {
                processors.flushReportingOutcomes { answers.append($0) }
                first.flushReportingOutcomeReceivedCompletion?(true)
                Thread.sleep(forTimeInterval: 0.1)
                expect(answers) == []
            }

            it("counts a processor that has not answered by the deadline as undelivered, and ignores its late answer") {
                var answered: [[Bool]] = []
                let lock = UnfairLock()
                processors.flushReportingOutcomes(deadline: .now() + 0.1) { outcome in
                    lock.withLock { answered.append(outcome) }
                }
                first.flushReportingOutcomeReceivedCompletion?(true)

                expect(lock.withLock { answered }).toEventually(equal([[true, false]]))
                second.flushReportingOutcomeReceivedCompletion?(true)
                expect(lock.withLock { answered }) == [[true, false]]
            }

            it("answers once where every processor answers before the deadline") {
                var answered: [[Bool]] = []
                let lock = UnfairLock()
                processors.flushReportingOutcomes(deadline: .now() + 0.1) { outcome in
                    lock.withLock { answered.append(outcome) }
                }
                first.flushReportingOutcomeReceivedCompletion?(true)
                second.flushReportingOutcomeReceivedCompletion?(true)

                Thread.sleep(forTimeInterval: 0.2)
                expect(lock.withLock { answered }) == [[true, true]]
            }

            it("posts through the backoff only where asked to") {
                processors.flushReportingOutcomes(bypassingBackoff: true) { answers.append($0) }
                expect(first.flushBypassingBackoffCallCount) == 1
                expect(second.flushBypassingBackoffCallCount) == 1
                expect(first.flushReportingOutcomeCallCount) == 0

                first.flushBypassingBackoffReceivedCompletion?(true)
                second.flushBypassingBackoffReceivedCompletion?(true)
                expect(answers) == [[true, true]]
            }
        }
    }
}
