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
}
