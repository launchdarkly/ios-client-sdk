import Foundation
import OSLog

// MARK: - Flush
extension LDClient {
    /**
     Tells the SDK to immediately send any currently queued events to LaunchDarkly.

     There should not normally be a need to call this function. While online, the LDClient automatically reports events
     on an interval defined by `LDConfig.eventFlushInterval`. Note that this function does not block until events are
     sent, it only triggers a background task to send events immediately.
     */
    public func flush() {
        LDClient.instancesQueue.sync(flags: .barrier) {
            LDClient.instances?.forEach { $1.internalFlush() }
        }
    }

    /**
     Sends any currently queued events to LaunchDarkly and waits up to `timeout` seconds for the result.

     The timeout bounds the wait, not the delivery: an in-flight request is left to finish. Multiple environments
     share one budget.

     This is not a crash-time mechanism. It is safe to call from the main thread, but keep the budget well below
     15 seconds there.

     - parameter timeout: How long to wait, in seconds.
     - returns: Whether the pending events left the SDK's hands within the budget.
     */
    @discardableResult
    public func flushAndWait(timeout: TimeInterval) -> Bool {
        if timeout > LDClient.longTimeoutInterval {
            os_log("%s LDClient.flushAndWait was called with a timeout greater than %f seconds. We recommend a timeout of less than %f seconds.", log: config.logger, type: .info, self.typeName(and: #function), LDClient.longTimeoutInterval, LDClient.longTimeoutInterval)
        }

        guard let clients = LDClient.instancesQueue.sync(execute: { LDClient.instances.map { Array($0.values) } })
        else {
            os_log("%s called on a closed client", log: config.logger, type: .debug, self.typeName(and: #function))
            return false
        }
        let deadline = Date().addingTimeInterval(max(0, timeout))
        var delivered = true
        for client in clients {
            let remaining = max(0, deadline.timeIntervalSinceNow)
            delivered = client.internalFlushAndWait(timeout: remaining) && delivered
        }
        return delivered
    }

    func internalFlush() {
        eventReporter.flush(completion: nil)
    }

    /// Neither main (callers may be blocked on it) nor the reporter's queue, so the wait cannot deadlock.
    private static let flushWaitQueue = DispatchQueue(label: "com.launchdarkly.flushWait", qos: .userInitiated)

    private func internalFlushAndWait(timeout: TimeInterval) -> Bool {
        let timeout = max(0, timeout)
        let finished = DispatchSemaphore(value: 0)
        var delivered = false
        TimeoutExecutor.run(
            timeout: timeout,
            queue: LDClient.flushWaitQueue,
            operation: { done in
                self.eventReporter.flushReportingOutcome(completion: done)
            },
            timeoutValue: false,
            completion: { result in
                delivered = result
                finished.signal()
            }
        )
        // A little past the budget, so TimeoutExecutor's timer decides the outcome.
        let answered = finished.wait(timeout: .now() + timeout + 0.25)
        // `delivered` is only safe to read once the semaphore was signaled.
        return answered == .success && delivered
    }
}
