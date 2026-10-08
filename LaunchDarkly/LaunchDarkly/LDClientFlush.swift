import Foundation
import OSLog

// MARK: - Flush
extension LDClient {
    /**
     Tells the SDK to immediately send any currently queued events to LaunchDarkly.

     There should not normally be a need to call this function. While online, the LDClient automatically reports events
     on an interval defined by `LDConfig.eventFlushInterval`. Note that this function does not block until events are
     sent, it only triggers a background task to send events immediately.

     Because it does not wait, it cannot report how the delivery went. Use `flush(completion:)` where that matters
     but blocking does not suit, or `flushAndWait` where blocking is acceptable.
     */
    public func flush() {
        LDClient.instancesQueue.sync(flags: .barrier) {
            LDClient.instances?.forEach { $1.internalFlush() }
        }
    }

    /**
     Sends any currently queued events to LaunchDarkly and reports how the delivery went.

     Like `flushAndWait`, but without blocking: the completion runs once every environment has answered. There is no
     timeout, because a delivery always ends, by its own request timeouts if nothing else. This is the one to reach
     for from a Swift concurrency task, where blocking is not safe.

     - parameter completion: Given `true` if LaunchDarkly accepted the events, or there were none to send, and
       `false` if the client is offline or closed, or any of the events were lost. See `flushAndWait` for what being
       lost covers. Runs once, on a background queue that is neither the caller's thread nor the one recorded events
       wait on, so it is free to record or flush again.
     */
    public func flush(completion: @escaping (Bool) -> Void) {
        let clients = instancesIncludingThisClient()
        guard !clients.isEmpty
        else {
            os_log("%s called on a closed client", log: config.logger, type: .debug, self.typeName(and: #function))
            completion(false)
            return
        }

        let lock = UnfairLock()
        /// Only to be used while holding `lock`: each environment answers from whichever thread its delivery ended on.
        var delivered = true
        var outstanding = clients.count

        for client in clients {
            client.eventReporter.flushReportingOutcome { result in
                lock.lock()
                delivered = delivered && result
                outstanding -= 1
                // Nil until the last environment answers, so the completion runs once. A reporter answering twice
                // takes the count past zero rather than back to it, which cannot match again.
                let outcome = outstanding == 0 ? delivered : nil
                lock.unlock()

                if let outcome {
                    completion(outcome)
                }
            }
        }
    }

    /// Every environment's client, or none where this client is no longer one of them.
    private func instancesIncludingThisClient() -> [LDClient] {
        let clients = LDClient.instancesQueue.sync { LDClient.instances.map { Array($0.values) } } ?? []
        return clients.contains { $0 === self } ? clients : []
    }

    /**
     Sends any currently queued events to LaunchDarkly and waits up to `timeout` seconds for the result.

     The timeout bounds the wait, not the delivery: an in-flight request is left to finish. Multiple environments
     deliver at the same time and share the one budget, so the call takes no longer for several of them than for one.

     A delivery that definitively failed is reported as a failure. Some other LaunchDarkly SDKs report that as a
     success, on the grounds that the attempt is over, so an expectation carried from another platform may not hold
     here.

     This blocks the thread it is called on until the answer is in or the budget runs out. Where the answer is not
     needed, `flush` queues the same delivery and returns at once; where it is needed but blocking does not suit,
     `flush(completion:)` reports it without waiting.

     Do not call this from a Swift concurrency task. Blocking there holds a thread of the cooperative pool, which
     cannot grow to replace it, and enough of them will stall every other task in the process. Use
     `flush(completion:)` from a task, wrapped in a continuation where you want to await it.

     This is not a crash-time mechanism. It is safe to call from the main thread, but keep the budget well below
     15 seconds there.

     - parameter timeout: How long to wait, in seconds. Zero or less does not wait, and so reports `false`. There is
       no upper limit: a delivery always ends, by its own request timeouts if nothing else, so a very long timeout
       waits for that.
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

        let clients = instancesIncludingThisClient()
        guard !clients.isEmpty
        else {
            // Closed, or replaced by a later start, or caught while a start is still filling the instances in. None of
            // them can deliver this client's events, and saying otherwise would tell the caller they were safe.
            os_log("%s called on a closed client", log: config.logger, type: .debug, self.typeName(and: #function))
            return false
        }
        let deadline = DispatchTime.now() + max(0, timeout)
        // Counts answers rather than tracking each delivery, so that a reporter answering twice costs a spare permit
        // no one reads. A DispatchGroup would fit as well, but its `leave` traps without a matching `enter`, which
        // turns a broken reporter into a crash in the application.
        let answered = DispatchSemaphore(value: 0)
        let lock = UnfairLock()
        /// Only to be used while holding `lock`: each environment answers from whichever thread its delivery ended on.
        var delivered = true

        // Every environment is started before any of them is waited on. Each has its own event reporter, so waiting on
        // one before starting the next would spend the caller's budget on deliveries that could have been running all
        // along, and leave the last environment with none of it.
        for client in clients {
            client.eventReporter.flushReportingOutcome { result in
                lock.lock()
                delivered = delivered && result
                lock.unlock()
                answered.signal()
            }
        }

        // Every wait is against the one deadline rather than a fresh copy of it, so the timeout the caller asked for
        // is the time this call can take however many environments there are. A delivery still running when the wait
        // gives up is left to finish rather than canceled: its events are already in flight, so abandoning it would
        // only make losing them certain.
        for _ in clients {
            guard answered.wait(timeout: deadline) == .success
            else { return false }
        }

        // The waits count answers rather than environments, so a reporter answering twice can end them while another
        // environment's answer is still being written.
        lock.lock()
        defer { lock.unlock() }
        return delivered
    }

    func internalFlush() {
        eventReporter.flush(completion: nil)
    }
}
