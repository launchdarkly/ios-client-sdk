import Foundation
import XCTest

@testable import LaunchDarkly

final class RetryStateSpec: XCTestCase {
    // nextDelay applies random jitter.
    // Each result is asserted to fall within a range over many samples rather than against a fixed value.
    private func assertDelay(_ retry: StreamingRetryState,
                             inClosedRange range: ClosedRange<TimeInterval>,
                             file: StaticString = #filePath,
                             line: UInt = #line) {
        for _ in 0..<50 {
            let delay = retry.nextDelay()
            XCTAssertTrue(range.contains(delay), "\(delay) is outside \(range)", file: file, line: line)
        }
    }

    private func assertDelay(_ retry: PollingRetryState,
                             inClosedRange range: ClosedRange<TimeInterval>,
                             file: StaticString = #filePath,
                             line: UInt = #line) {
        for _ in 0..<50 {
            let delay = retry.nextDelay()
            XCTAssertTrue(range.contains(delay), "\(delay) is outside \(range)", file: file, line: line)
        }
    }

    func testStreamingRetryLifecycle() {
        let retry = StreamingRetryState()

        // Normal failures back off from the initial delay and double to the 30s ceiling.
        for range in [0.5...1, 1...2, 2...4, 4...8, 8...16, 15...30, 15...30] as [ClosedRange<TimeInterval>] {
            retry.recordFailure(unexpected: false)
            assertDelay(retry, inClosedRange: range)
        }

        // An unexpected failure switches to the extended regime, restarting from 5 minutes.
        retry.recordFailure(unexpected: true)
        assertDelay(retry, inClosedRange: 150...300)

        // Further normal failures remain in the extended regime and double to the 1h ceiling.
        for range in [300...600, 600...1200, 1200...2400, 1800...3600, 1800...3600] as [ClosedRange<TimeInterval>] {
            retry.recordFailure(unexpected: false)
            assertDelay(retry, inClosedRange: range)
        }

        // A reset returns to the normal regime, so the next failure backs off from the initial delay again.
        retry.reset()
        retry.recordFailure(unexpected: false)
        assertDelay(retry, inClosedRange: 0.5...1)
    }

    func testPollingRetryLifecycle() {
        let retry = PollingRetryState(pollInterval: 30)

        // Normal failures hold the poll interval with no escalation.
        for _ in 0..<3 {
            retry.recordFailure(unexpected: false)
            assertDelay(retry, inClosedRange: 30...30)
        }

        // An unexpected failure switches to the extended regime, restarting from 5 minutes.
        retry.recordFailure(unexpected: true)
        assertDelay(retry, inClosedRange: 150...300)

        // Further normal failures remain in the extended regime and double to the 1h ceiling.
        for range in [300...600, 600...1200, 1200...2400, 1800...3600, 1800...3600] as [ClosedRange<TimeInterval>] {
            retry.recordFailure(unexpected: false)
            assertDelay(retry, inClosedRange: range)
        }

        // Two successful polls clear the backoff, so the next failure holds the poll interval again.
        retry.recordSuccess()
        retry.recordSuccess()
        retry.recordFailure(unexpected: false)
        assertDelay(retry, inClosedRange: 30...30)
    }

    func testPollingSuccessUsesPollIntervalBeforeBackoffClears() {
        let retry = PollingRetryState(pollInterval: 30)

        // An unexpected failure switches to the extended regime.
        retry.recordFailure(unexpected: true)
        assertDelay(retry, inClosedRange: 150...300)

        // One success is short of the reset threshold, but the next poll still waits only the poll interval.
        retry.recordSuccess()
        assertDelay(retry, inClosedRange: 30...30)

        // The backoff has not cleared, so a failure returns to the extended regime.
        retry.recordFailure(unexpected: false)
        assertDelay(retry, inClosedRange: 300...600)
    }

    func testPollingWaitFloorRaisesToPollInterval() {
        // A poll interval above the 5 minute extended base floors every delay at the interval.
        let retry = PollingRetryState(pollInterval: 600)
        retry.recordFailure(unexpected: false)
        assertDelay(retry, inClosedRange: 600...600)
        retry.recordFailure(unexpected: true)
        assertDelay(retry, inClosedRange: 600...600)
    }

    func testDeliveryNothingWaitsBeforeTheFirstFailure() {
        XCTAssertEqual(DeliveryRetryState(flushInterval: 30).remainingWait, 0)
    }

    func testDeliveryOrdinaryFailuresDoubleTheWaitUpToTheFlushInterval() {
        let retry = DeliveryRetryState(flushInterval: 30)
        for expected in [1, 2, 4, 8, 16, 30, 30] as [TimeInterval] {
            XCTAssertEqual(retry.recordFailure(unexpected: false, retryAfter: nil), expected)
        }
    }

    func testDeliveryNormalCeilingIsNeverBelowASecond() {
        let retry = DeliveryRetryState(flushInterval: 0.2)
        retry.recordFailure(unexpected: false, retryAfter: nil)
        XCTAssertEqual(retry.recordFailure(unexpected: false, retryAfter: nil), 1)
    }

    func testDeliveryRefusalWaitsAboutEightAndAHalfMinutesAndDoublesToAnHour() {
        let retry = DeliveryRetryState(flushInterval: 30)
        for expected in [512, 1024, 2048, 3600] as [TimeInterval] {
            XCTAssertEqual(retry.recordFailure(unexpected: true, retryAfter: nil), expected)
        }
    }

    func testDeliveryOrdinaryFailureAfterARefusalKeepsTheLongerCeiling() {
        let retry = DeliveryRetryState(flushInterval: 30)
        retry.recordFailure(unexpected: true, retryAfter: nil)
        XCTAssertEqual(retry.recordFailure(unexpected: false, retryAfter: nil), 1024)
    }

    func testDeliveryAcceptedDeliveryPutsEverythingBack() {
        let retry = DeliveryRetryState(flushInterval: 30)
        retry.recordFailure(unexpected: true, retryAfter: nil)
        retry.recordFailure(unexpected: false, retryAfter: nil)
        retry.recordSuccess()
        XCTAssertEqual(retry.remainingWait, 0)
        XCTAssertEqual(retry.recordFailure(unexpected: false, retryAfter: nil), 1)
    }

    func testDeliveryRetryAfterSetsTheWaitJitteredToNoLessThanHalfOfIt() {
        let retry = DeliveryRetryState(flushInterval: 30)
        for _ in 0..<100 {
            let wait = retry.recordFailure(unexpected: false, retryAfter: 10)
            XCTAssertTrue((5...10).contains(wait), "\(wait) is outside 5...10")
        }
    }

    func testDeliveryRetryAfterIsCappedAtAnHour() {
        let retry = DeliveryRetryState(initialDelay: 1, normalCeiling: 30, extendedCeiling: 3600, random: { 0 })
        XCTAssertEqual(retry.recordFailure(unexpected: false, retryAfter: 5 * 3600), 3600)
    }

    func testDeliveryFailureWithARetryAfterStillCountsTowardTheBackoff() {
        let retry = DeliveryRetryState(flushInterval: 30)
        retry.recordFailure(unexpected: false, retryAfter: nil)
        retry.recordFailure(unexpected: false, retryAfter: 0)
        XCTAssertEqual(retry.recordFailure(unexpected: false, retryAfter: nil), 4)
    }

    func testDeliveryFailureDuringTheWaitLeavesTheBackoffWhereItWas() {
        let retry = DeliveryRetryState(flushInterval: 30)
        retry.recordFailure(unexpected: true, retryAfter: nil)
        let waiting = retry.remainingWait
        for _ in 0..<5 {
            XCTAssertLessThanOrEqual(retry.recordFailureDuringWait(unexpected: true, retryAfter: nil), waiting)
        }

        XCTAssertLessThanOrEqual(retry.remainingWait, waiting)
        // The next step is the one after the first refusal, not five steps on.
        XCTAssertEqual(retry.recordFailure(unexpected: true, retryAfter: nil), 1024)
    }

    func testDeliveryRetryAfterDuringTheWaitCanOnlyLengthenIt() {
        let retry = DeliveryRetryState(initialDelay: 1, normalCeiling: 30, extendedCeiling: 3600, random: { 0 })
        retry.recordFailure(unexpected: true, retryAfter: nil)
        let waiting = retry.remainingWait

        retry.recordFailureDuringWait(unexpected: false, retryAfter: 10)
        XCTAssertLessThanOrEqual(retry.remainingWait, waiting)

        XCTAssertGreaterThan(retry.recordFailureDuringWait(unexpected: false, retryAfter: 20 * 60), 19 * 60)
        XCTAssertGreaterThan(retry.remainingWait, 19 * 60)
    }

    func testDeliveryFailureDuringAWaitThatHasRunOutIsAnOrdinaryOne() {
        let retry = DeliveryRetryState(initialDelay: 0.02, normalCeiling: 1, extendedCeiling: 1)
        retry.recordFailure(unexpected: false, retryAfter: nil)
        Thread.sleep(forTimeInterval: 0.04)

        XCTAssertEqual(retry.recordFailureDuringWait(unexpected: false, retryAfter: nil), 0.04, accuracy: 0.0001)
    }

    func testDeliveryWaitRunsOut() {
        let retry = DeliveryRetryState(initialDelay: 0.02, normalCeiling: 0.02, extendedCeiling: 0.02)
        retry.recordFailure(unexpected: false, retryAfter: nil)
        XCTAssertGreaterThan(retry.remainingWait, 0)
        Thread.sleep(forTimeInterval: 0.04)
        XCTAssertEqual(retry.remainingWait, 0)
    }

    func testRetryAfterHeaderIsReadAsSecondsOrAnHttpDate() {
        func response(_ retryAfter: String?) -> HTTPURLResponse {
            HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 503, httpVersion: "1.1",
                            headerFields: retryAfter.map { ["retry-after": $0] })!
        }
        XCTAssertNil(response(nil).headerRetryAfter)
        XCTAssertEqual(response("120").headerRetryAfter, 120)
        XCTAssertNil(response("soon").headerRetryAfter)
        XCTAssertEqual(response(DateFormatter.httpUrlHeaderFormatter.string(from: Date(timeIntervalSinceNow: -60))).headerRetryAfter, 0)
        let date = DateFormatter.httpUrlHeaderFormatter.string(from: Date(timeIntervalSinceNow: 600))
        XCTAssertEqual(response(date).headerRetryAfter ?? 0, 600, accuracy: 2)
    }
}
