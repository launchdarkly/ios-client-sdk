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
     deliver at the same time and share the one budget, so the call takes no longer for several of them than for one.

     This is not a crash-time mechanism. It is safe to call from the main thread, but keep the budget well below
     15 seconds there.

     - parameter timeout: How long to wait, in seconds.
     - returns: `true` if LaunchDarkly accepted the events, or there were none to send. `false` if the timeout expired
       first, the client is offline or closed, or any of the events were lost: refused by LaunchDarkly, still failing
       after one retry, or unable to be serialized. Lost events are not kept for a later flush, so calling this again
       does not resend them. A refusal also stops event delivery until the client is next set online, and until then
       this returns `false` even with nothing to send. A `false` because the timeout expired does not mean the events
       were not sent: the delivery is left running, and may still arrive.
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
        let deadline = DispatchTime.now() + max(0, timeout)
        // Every environment is started before any of them is waited on. Each has its own event reporter, so waiting on
        // one before starting the next would spend the caller's budget on deliveries that could have been running all
        // along, and leave the last environment with none of it.
        let deliveries = clients.map { $0.startFlush() }
        var delivered = true
        for delivery in deliveries {
            // Each wait gets what is left of the one budget rather than a fresh copy of it, so that the timeout the
            // caller asked for is the time this call can take.
            delivered = delivery.outcome(waitingUntil: deadline) && delivered
        }
        return delivered
    }

    func internalFlush() {
        eventReporter.flush(completion: nil)
    }

    private func startFlush() -> FlushDelivery {
        let delivery = FlushDelivery()
        eventReporter.flushReportingOutcome { delivery.finish($0) }
        return delivery
    }
}

/// One environment's delivery, started and not yet waited on.
private final class FlushDelivery {
    private let finished = DispatchSemaphore(value: 0)
    private let lock = UnfairLock()
    /// Only to be used while holding `lock`, because the delivery answers from whichever thread it ended on.
    private var delivered = false

    func finish(_ result: Bool) {
        lock.lock()
        delivered = result
        lock.unlock()
        finished.signal()
    }

    /// How the delivery went, or `false` if it has not answered by `deadline`.
    ///
    /// A delivery still running when the caller stops waiting is left to finish rather than canceled: its events are
    /// already in flight, so abandoning it would only make losing them certain.
    func outcome(waitingUntil deadline: DispatchTime) -> Bool {
        guard finished.wait(timeout: deadline) == .success
        else { return false }

        lock.lock()
        defer { lock.unlock() }
        return delivered
    }
}
