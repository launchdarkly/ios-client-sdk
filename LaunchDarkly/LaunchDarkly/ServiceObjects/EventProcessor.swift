import Foundation

typealias EventSyncCompleteClosure = ((SynchronizingError?) -> Void)
/// Reports whether LaunchDarkly accepted every event a flush covered.
typealias FlushOutcomeClosure = (Bool) -> Void
// sourcery: autoMockable
protocol EventProcessor {
    // sourcery: defaultMockValue = false
    var isOnline: Bool { get set }
    // sourcery: defaultMockValue = Date.distantPast
    var lastEventResponseDate: Date { get }

    func record(_ event: Event)
    // swiftlint:disable:next function_parameter_count
    func recordFlagEvaluationEvents(flagKey: LDFlagKey,
                                    value: LDValue,
                                    defaultValue: LDValue,
                                    featureFlag: FeatureFlag?,
                                    context: LDContext,
                                    includeReason: Bool)
    func flush(completion: CompletionClosure?)

    /// Like `flush`. Reports `true` if LaunchDarkly accepted the pending batches, or there were none to send. Reports
    /// `false` if the reporter is offline, a batch was refused for good, a retryable failure left batches on disk, or
    /// an event the SDK had accepted could not be kept to send at all.
    ///
    /// Flushes arriving faster than a delivery completes join the one that is queued, since a delivery that has not
    /// started yet will send their events too. A delivery that has already started is not joined, so an answer is
    /// always about the batch the caller's own delivery took, never one an earlier delivery lost.
    ///
    /// The completion, like `flush`'s, runs on a background queue, and never on the reporter's own: a completion is
    /// free to record events or flush again without waiting on the queue it is running on. It is not the caller's
    /// thread either, and two completions may run at once, so anything it touches needs to expect that.
    ///
    /// Unlike `flush`, it writes nothing on the caller's thread: wherever events persist, it queues that write, so a
    /// caller with a deadline is not held by the disk before it can start waiting. A `true` still means the events
    /// were written, since the delivery writes them before it sends.
    func flushReportingOutcome(completion: @escaping FlushOutcomeClosure)

    /// `flushReportingOutcome` for a caller about to lose the ability to send, `LDClient.flushAndWait`: it posts
    /// whatever wait the backoff is in, as `flushAtClose()` does. After a refusal that wait is minutes to an hour, and
    /// where nothing persists the events would not outlive it.
    func flushBypassingBackoff(completion: @escaping FlushOutcomeClosure)

    /// The last delivery before the client closes: `flush`, except that it posts whatever wait the backoff is in, which
    /// closing cuts short. After a refusal that wait is minutes to an hour, and where nothing persists the events would
    /// not outlive it.
    ///
    /// Whether it posts is settled by whether the reporter is online when this is called, so the client going offline
    /// as it closes, straight after, does not stop it.
    func flushAtClose()

    /// Makes everything recorded so far outlive the process, without waiting for a delivery.
    ///
    /// The SDK does this itself at the points where an application is most likely to be about to die. It is worth
    /// calling directly before deliberately terminating the process.
    func commitRecordedEvents()

    /// Commits before returning wherever events persist, at `.deferred` as well as at `.immediate`, and not at all where
    /// nothing is persisted, where a commit would only move the encode earlier.
    ///
    /// What a flush does, and what entering the background does: both are points the process may end soon after, where
    /// a write that was only queued may never happen.
    func commitWherePersisting()
}

extension Array where Element == EventProcessor {
    /// Starts every processor's delivery at once, and gives `completion` each one's outcome, in order, once all of them
    /// have answered or `deadline` has passed, whichever is first. A processor that has not answered by the deadline
    /// counts as not delivered, and its answer, should it come later, is ignored. With no processors it answers at
    /// once, on the calling thread.
    ///
    /// The completion runs once, on the thread of the last answer, or a global queue at the deadline. A reporter
    /// answering twice neither ends the wait before every processor has answered nor ends it again: its second answer
    /// is ignored.
    ///
    /// - parameter deadline: where a caller cannot wait on a reporter that never answers. Without one, the completion
    ///   waits for every answer.
    func flushReportingOutcomes(bypassingBackoff: Bool = false,
                                deadline: DispatchTime? = nil,
                                completion: @escaping (_ delivered: [Bool]) -> Void) {
        guard !isEmpty
        else {
            completion([])
            return
        }
        let lock = UnfairLock()
        /// Only to be used while holding `lock`: each processor answers from whichever thread its delivery ended on.
        var outcomes = [Bool?](repeating: nil, count: count)
        var outstanding = count
        /// Taken by whichever ends the wait, and only reached through here: the timer stays scheduled until the
        /// deadline however soon the last answer comes, and must not keep what the completion holds alive until then.
        /// Only to be used while holding `lock`.
        var pending: (([Bool]) -> Void)? = completion
        if let deadline {
            DispatchQueue.global().asyncAfter(deadline: deadline) {
                let ended: (finish: ([Bool]) -> Void, delivered: [Bool])? = lock.withLock {
                    guard let finish = pending
                    else { return nil }
                    pending = nil
                    return (finish, outcomes.map { $0 ?? false })
                }
                ended.map { $0.finish($0.delivered) }
            }
        }
        for (index, processor) in enumerated() {
            let answer: FlushOutcomeClosure = { delivered in
                let ended: (finish: ([Bool]) -> Void, delivered: [Bool])? = lock.withLock {
                    guard pending != nil, outcomes[index] == nil
                    else { return nil }
                    outcomes[index] = delivered
                    outstanding -= 1
                    guard outstanding == 0, let finish = pending
                    else { return nil }
                    pending = nil
                    return (finish, outcomes.compactMap { $0 })
                }
                ended.map { $0.finish($0.delivered) }
            }
            if bypassingBackoff {
                processor.flushBypassingBackoff(completion: answer)
            } else {
                processor.flushReportingOutcome(completion: answer)
            }
        }
    }
}
