import Foundation
import OSLog

/**
 How a flush through `LDClient.flush(timeout:completion:)` went.

 - Warning: Experimental. This type is not stable, and not subject to any backwards compatibility guarantees or semantic
   versioning.
 */
@objc(LDFlushResult)
public enum FlushResult: Int {
    /// LaunchDarkly accepted the events of every environment, or there were none to send.
    case complete
    /// The timeout expired before every environment answered. The deliveries are left running, and their events may
    /// still arrive; whatever does not is kept and sent later.
    case timeout
    /// Nothing was sent, because the client is offline or closed. Where events persist, they were written, and go out
    /// once the client is online again.
    case offline
    /// A delivery did not get its events out, or events the SDK had accepted were lost. Events the service refused or
    /// that failed to post are kept, and posted again once the backoff allows. Events that could not be serialized, or
    /// whose payload LaunchDarkly refused twice in a row, are lost, and are not sent again.
    case failed

    /// - Parameters:
    ///   - offline: whether the client was offline when the flush started.
    ///   - delivered: each environment's answer, or nil where it had not answered by the deadline.
    init(offline: Bool, delivered: [Bool?]) {
        if delivered.allSatisfy({ $0 == true }) {
            self = .complete
        } else if offline {
            self = .offline
        } else if delivered.contains(false) {
            // Ahead of a timeout: a failure is known, while an environment that has not answered may yet succeed.
            self = .failed
        } else {
            self = .timeout
        }
    }
}

// MARK: - Flush
extension LDClient {
    /// The longest a flush waits, whatever timeout it is given. A delivery has no end of its own to rely on: a request's
    /// `LDConfig.connectionTimeout` only bounds the time between packets, so a server answering slowly enough keeps it
    /// going for as long as Foundation's resource timeout, which is a week.
    static let longestFlushWait: TimeInterval = 30

    /// `timeout` as a flush waits it: at most `longestFlushWait`, and zero where it is zero or less, or not a number.
    static func flushWait(for timeout: TimeInterval) -> TimeInterval {
        timeout > 0 ? min(timeout, longestFlushWait) : 0
    }

    /**
     Writes down all pending events and sends them to LaunchDarkly.

     There should not normally be a need to call this function. While online, the LDClient automatically reports events
     on an interval defined by `LDConfig.eventFlushInterval`. Note that this function does not block until events are
     sent, it only triggers a background task to send them immediately.

     Because it does not wait, it cannot report how the delivery went. Use `flush(timeout:completion:)` where that
     matters but blocking does not suit, or `flushAndWait` where blocking is acceptable.

     Where `LDConfig.eventPersistence` is on, it also writes before it returns, on the calling thread, at `.deferred`
     as well as at `.immediate`. Recording an event does not on its own make it outlive the process: events are written
     in runs, so one recorded shortly before the process ends may never have been written at all. This call writes
     everything recorded so far, and those events then survive whether or not the delivery does. Where it is off,
     events live in memory only and nothing survives the process, whether or not this was called.

     That is what makes it worth calling where the process is about to end deliberately. It is not a crash-time
     mechanism — Apple gives the SDK no crash hook, and a trap or a `SIGKILL` loses whatever was recorded since the
     last write. What was written before then is delivered on the next launch.
     */
    public func flush() {
        // Taken under the queue and flushed after it is released, since each flush writes, and every other client call
        // in the process that reads the instances would otherwise wait behind every environment's write.
        let clients = LDClient.instancesQueue.sync { LDClient.instances.map { Array($0.values) } } ?? []
        clients.forEach { $0.internalFlush() }
    }

    /**
     Sends any currently queued events to LaunchDarkly and reports how the delivery went, within `timeout` seconds.

     Like `flushAndWait`, but without blocking: the completion runs once every environment has answered, or once the
     timeout expires, whichever comes first. The timeout bounds the wait, not the delivery: an in-flight request is
     left to finish. This is the one to reach for from a Swift concurrency task, where blocking is not safe.

     Unlike `flushAndWait`, it does not post while delivery is backing off after a failure. It sits out a wait of a
     second or so, and reports `.failed` without posting through a longer one, such as the minutes that follow a
     refusal.

     - Warning: Experimental. This method is not stable, and not subject to any backwards compatibility guarantees or
       semantic versioning.

     - parameter timeout: How long to wait for the answer, in seconds, up to 30. Zero or less gives the deliveries no
       time, so it reports `.timeout` unless the client is offline or closed.
     - parameter completion: Given how the flush went; see `FlushResult`. Runs once, on a background queue that is
       neither the caller's thread nor the one recorded events wait on, so it is free to record or flush again.
     */
    public func flush(timeout: TimeInterval, completion: @escaping (FlushResult) -> Void) {
        // Taken first, so that the timeout covers the whole call, finding the clients included.
        let wait = LDClient.flushWait(for: timeout)
        let deadline = DispatchTime.now() + wait
        let clients = instancesIncludingThisClient()
        guard !clients.isEmpty
        else {
            os_log("%s called on a closed client", log: config.logger, type: .debug, self.typeName(and: #function))
            // Answered off the caller's thread even with nothing to wait for, so that the contract holds whether or
            // not the client turned out to be closed.
            DispatchQueue.global().async { completion(.offline) }
            return
        }

        let offline = !isOnline
        guard wait > 0 || offline
        else {
            // Started all the same: wherever events persist, each delivery queues their write.
            flush(clients, offline: offline, deadline: deadline, bypassingBackoff: false) { _ in }
            DispatchQueue.global().async { completion(.timeout) }
            return
        }
        flush(clients, offline: offline, deadline: deadline, bypassingBackoff: false, completion: completion)
    }

    /// Starts every environment's delivery and reports how they went, at `deadline` at the latest.
    private func flush(_ clients: [LDClient], offline: Bool, deadline: DispatchTime, bypassingBackoff: Bool,
                       completion: @escaping (FlushResult) -> Void) {
        clients.map { $0.eventProcessor }.flushReportingOutcomes(bypassingBackoff: bypassingBackoff,
                                                                  deadline: deadline) { delivered in
            completion(FlushResult(offline: offline, delivered: delivered))
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
     `flush(timeout:completion:)` reports it without waiting.

     Do not call this from a Swift concurrency task. Blocking there holds a thread of the cooperative pool, which
     cannot grow to replace it, and enough of them will stall every other task in the process. Use
     `flush(timeout:completion:)` from a task, wrapped in a continuation where you want to await it.

     This is not a crash-time mechanism. It is safe to call from the main thread, but keep the budget well below
     15 seconds there.

     It posts even while delivery is backing off after a failure, as closing the client does, since it is for a moment
     after which the SDK may not get to send. After a refusal such as a 401 or 403 the SDK waits about eight and a half
     minutes before posting again, doubling up to an hour, and a call that sat that out would make no attempt at all.
     A post that fails then leaves the wait as it was, so `flush`, `flush(timeout:completion:)` and the periodic
     delivery go on waiting out the same one rather than a longer one. That also means nothing slows these posts down:
     a call made routinely, rather than just before the process is suspended or ends, posts once per call for as long
     as LaunchDarkly keeps refusing. Keep it for those last moments; the SDK already flushes on every move to the
     background.

     - Warning: Experimental. This method is not stable, and not subject to any backwards compatibility guarantees or
       semantic versioning.

     - parameter timeout: How long to wait, in seconds, up to 30. Zero or less does not wait, and so reports `false`.
     - returns: `true` if LaunchDarkly accepted the events, or there were none to send. `false` if the timeout expired
       first, the client is offline or closed, or the events did not get out. Events the service refused or that
       failed to post are kept, and posted again once the backoff allows, or by the next call to this method. Events
       that could not be serialized, or whose payload LaunchDarkly refused twice in a row, are lost, and calling this
       again does not resend them. A `false` because the timeout expired does not mean the events were not sent: the
       delivery is left running, and may still arrive.
     */
    @discardableResult
    public func flushAndWait(timeout: TimeInterval) -> Bool {
        // Taken first, so that the timeout covers the whole call, finding the clients included.
        let wait = LDClient.flushWait(for: timeout)
        let deadline = DispatchTime.now() + wait
        let clients = instancesIncludingThisClient()
        guard !clients.isEmpty
        else {
            // Closed, or replaced by a later start, or caught while a start is still filling the instances in. None of
            // them can deliver this client's events, and saying otherwise would tell the caller they were safe.
            os_log("%s called on a closed client", log: config.logger, type: .debug, self.typeName(and: #function))
            return false
        }
        // Signaled once, by the last environment to answer or at the deadline. A DispatchGroup would fit as well, but
        // its `leave` traps without a matching `enter`, which turns a broken reporter into a crash in the application.
        let answered = DispatchSemaphore(value: 0)
        let lock = UnfairLock()
        /// Only to be used while holding `lock`: the last environment answers from whichever thread its delivery ended on.
        var result = FlushResult.timeout

        // Every environment is started before any of them is waited on. Each has its own event reporter, so waiting on
        // one before starting the next would spend the caller's budget on deliveries that could have been running all
        // along, and leave the last environment with none of it.
        flush(clients, offline: !isOnline, deadline: deadline, bypassingBackoff: true) { outcome in
            lock.withLock { result = outcome }
            answered.signal()
        }

        // Started, then given up on. The deliveries are what makes a zero timeout worth calling at all: wherever events
        // persist, each `flushReportingOutcome` has queued their write, which no longer waits on this thread. Waiting
        // is what is skipped, and deliveries that already answered must not turn that into a `true`.
        guard wait > 0
        else { return false }

        // The deadline was taken on entry, so the timeout the caller asked for is the time this call can take however
        // many environments there are. A delivery still running when the wait gives up is left to finish rather than
        // canceled: its events are already in flight, so abandoning it would only make losing them certain.
        guard answered.wait(timeout: deadline) == .success
        else { return false }
        return lock.withLock { result } == .complete
    }

    func internalFlush() {
        eventProcessor.flush(completion: nil)
    }
}
