import Foundation
import XCTest

@testable import LaunchDarkly

final class RetryStateSpec: XCTestCase {
    // nextDelay applies random jitter. Each result is asserted to fall within a
    // range over many samples rather than against a fixed value.
    private func assertDelay(_ retry: RetryState,
                             inClosedRange range: ClosedRange<TimeInterval>,
                             file: StaticString = #filePath,
                             line: UInt = #line) {
        for _ in 0..<50 {
            let delay = retry.nextDelay()
            XCTAssertTrue(range.contains(delay), "\(delay) is outside \(range)", file: file, line: line)
        }
    }

    func testStreamingRetryLifecycle() {
        let retry = RetryState.forStreaming(initialReconnectDelay: 1)

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

        // A reset returns to the normal regime, backing off from the initial delay again.
        retry.reset()
        retry.recordFailure(unexpected: false)
        assertDelay(retry, inClosedRange: 0.5...1)
    }

    func testPollingRetryLifecycle() {
        let retry = RetryState.forPolling(pollInterval: 30)

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

        // A reset returns to the poll interval.
        retry.reset()
        retry.recordFailure(unexpected: false)
        assertDelay(retry, inClosedRange: 30...30)
    }

    func testPollingWaitFloorRaisesToPollInterval() {
        // A poll interval above the 5 minute extended base floors every delay at the interval.
        let retry = RetryState.forPolling(pollInterval: 600)
        retry.recordFailure(unexpected: false)
        assertDelay(retry, inClosedRange: 600...600)
        retry.recordFailure(unexpected: true)
        assertDelay(retry, inClosedRange: 600...600)
    }
}
