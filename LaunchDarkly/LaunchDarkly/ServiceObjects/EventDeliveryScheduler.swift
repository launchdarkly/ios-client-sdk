import Foundation

/// One delivery, from taking its batches until it has an answer for everything it sent, its retry included.
///
/// Made by `EventDeliveryScheduler.begin()` and passed through the delivery, so that what is true of the delivery running is
/// held by it, and starts afresh with each one.
final class EventDeliveryRun {
    /// A paced batch waiting out its gap.
    private final class PacedTurn {
        let proceed: () -> Void

        init(_ proceed: @escaping () -> Void) {
            self.proceed = proceed
        }
    }

    /// Whether it is `flushAtClose()`'s, which runs although closing has turned `isOnline` off since. The delivery one of its failures sets for the end of the wait is another one, held
    /// by the backoff, and finds the reporter offline as any other.
    let isClosing: Bool
    /// Whether it posts whatever wait the backoff is in: `flushAtClose()`'s, and `flushBypassingBackoff(completion:)`'s.
    let bypassesBackoff: Bool

    /// The least time between one paced batch's answer and the next batch's request.
    private let gap: TimeInterval

    /// Guards the pacing, which a delivery somebody asks for, or going offline, ends from another thread.
    private let lock = UnfairLock()
    /// Whether it is paced: until a delivery somebody asked for is queued, after which it sends the rest back to back,
    /// or the reporter goes offline, after which it sends nothing more. Only to be used while holding `lock`.
    private var isPaced: Bool
    /// When it last had an answer for a post, or nil before its first. Only to be used while holding `lock`.
    private var lastPostAnswered: DispatchTime?
    /// The batch waiting out its gap, which ending the pacing lets go at once. Only to be used while holding `lock`.
    private var waitingTurn: PacedTurn?

    init(isClosing: Bool, bypassesBackoff: Bool, isPaced: Bool, gap: TimeInterval) {
        self.isClosing = isClosing
        self.bypassesBackoff = bypassesBackoff
        self.isPaced = isPaced
        self.gap = gap
    }

    /// Notes that a post had its answer, which the gap before the next one counts from.
    func postAnswered() {
        lock.withLock {
            if isPaced {
                lastPostAnswered = .now()
            }
        }
    }

    /// Ends the pacing, so that the rest go back to back, or, offline, stop.
    func endPacing() {
        let turn = lock.withLock { () -> PacedTurn? in
            defer {
                isPaced = false
                waitingTurn = nil
            }
            return waitingTurn
        }
        if let turn {
            DispatchQueue.global().async(execute: turn.proceed)
        }
    }

    /// Holds the next batch until the gap has passed since the last one was answered, where the delivery is paced and
    /// has posted before, and then calls `proceed` on a global queue; or sooner, once the pacing ends.
    ///
    /// - Returns: whether it holds the batch; false where the batch may go now, and `proceed` is not called.
    func awaitTurn(then proceed: @escaping () -> Void) -> Bool {
        let turn = PacedTurn(proceed)
        // Under the same lock that ends the pacing, so that the pacing cannot end between the check and the wait.
        guard let gapEnds = lock.withLock({ () -> DispatchTime? in
            guard isPaced, let answered = lastPostAnswered
            else { return nil }
            waitingTurn = turn
            return answered + gap
        })
        else { return false }
        DispatchQueue.global().asyncAfter(deadline: gapEnds) {
            let taken = self.lock.withLock { () -> Bool in
                guard self.waitingTurn === turn
                else { return false }
                self.waitingTurn = nil
                return true
            }
            if taken {
                turn.proceed()
            }
        }
        return true
    }
}

/// Decides which delivery runs next, one at a time: queues one, joins a caller to one that is queued and has not
/// started, starts the queued one once the one running has its answer, and sets one for when the backoff's wait ends.
///
/// Its lock is taken on a caller's thread, on the delivery queue and where a delivery's posts are answered, and never
/// held across any of them.
final class EventDeliveryScheduler {
    /// A delivery queued that has not taken its batches yet.
    private struct Queued {
        /// The callers waiting on it.
        var waiters: [FlushOutcomeClosure]
        /// Whether it is `flushAtClose()`'s, or has been joined by it.
        var isClosing: Bool
        /// Whether a caller bypassing the backoff asked for it, or joined it.
        var bypassesBackoff: Bool
        /// Whether it was asked for only by the report timer or by the launch gate, and so is paced.
        var isPaced: Bool
    }

    /// Whether deliveries nobody asked for are paced: only where events give way to flag values.
    private let pacesDeliveries: Bool
    private let gap: TimeInterval

    private let lock = UnfairLock()
    /// Only to be used while holding `lock`.
    private var queued: Queued?
    /// Whether a delivery has started, or is about to, and not yet had an answer for everything it sent, its retry
    /// included. Only to be used while holding `lock`.
    ///
    /// A delivery returns from the delivery queue as soon as its first request is out, so the queue alone does not keep
    /// two apart. Two at once would each leave the batch it is sending out of both capacities, and a run of flushes,
    /// each held up by a slow response, could take the store that many batches past them.
    private var isDelivering = false
    /// The delivery running, whose pacing a delivery somebody asks for ends. Only to be used while holding `lock`.
    private var running: EventDeliveryRun?
    /// Whether a delivery is already set to run when the backoff's wait ends, so a run of passes inside the wait sets
    /// one rather than one each. Only to be used while holding `lock`.
    private var isRetryScheduled = false

    #if DEBUG
        /// How many deliveries have started, which is fewer than the flushes asked for where they were joined.
        private var deliveryRunCount = 0
    #endif

    init(pacesDeliveries: Bool, gap: TimeInterval) {
        self.pacesDeliveries = pacesDeliveries
        self.gap = gap
    }

    /// Queues a delivery, or joins one that is queued and has not started.
    ///
    /// A delivery that has not started yet will send everything recorded before it starts, which includes this
    /// caller's events, so joining it is as good as queueing another. Without this, flushes arriving faster than a
    /// post completes each queue their own, and the one that matters -- the flush at shutdown -- waits behind all of
    /// them.
    ///
    /// A delivery that has already started is not joined. It has closed and taken its batches, so it cannot speak for
    /// anything recorded since. Nor does another start beside it: the one queued waits until the running one has an
    /// answer, then sends what that one left behind as well as what was recorded since, so its caller hears `true`
    /// only if both got out.
    ///
    /// - Parameters:
    ///   - closing: whether it is `flushAtClose()`'s, which a queued delivery it joins becomes.
    ///   - bypassingBackoff: whether it posts whatever wait the backoff is in, which a queued delivery it joins does too.
    ///   - paced: whether nobody asked for it, so that it gives way to flag requests. One that is not ends the pacing of
    ///     the delivery running, so that it is not held behind it.
    /// - Returns: whether the caller is to start it, which is where no delivery is running.
    func queue(_ completion: FlushOutcomeClosure?, closing: Bool, bypassingBackoff: Bool, paced: Bool) -> Bool {
        let (starts, unpaced) = lock.withLock { () -> (Bool, EventDeliveryRun?) in
            let unpaced = paced ? nil : running
            if var joined = queued {
                if let completion {
                    joined.waiters.append(completion)
                }
                joined.isClosing = joined.isClosing || closing
                joined.bypassesBackoff = joined.bypassesBackoff || bypassingBackoff
                joined.isPaced = joined.isPaced && paced
                queued = joined
                return (false, unpaced)
            }
            queued = Queued(waiters: completion.map { [$0] } ?? [], isClosing: closing, bypassesBackoff: bypassingBackoff,
                            isPaced: paced)
            let starts = !isDelivering
            isDelivering = true
            return (starts, unpaced)
        }
        unpaced?.endPacing()
        return starts
    }

    /// Starts the delivery queued. Requests arriving from here on need a delivery of their own: this one is about to
    /// close and take its batches, and what it takes is all it can speak for.
    ///
    /// - Returns: the delivery, and the callers waiting on it.
    func begin() -> (run: EventDeliveryRun, waiters: [FlushOutcomeClosure]) {
        lock.withLock {
            let next = queued ?? Queued(waiters: [], isClosing: false, bypassesBackoff: false, isPaced: false)
            queued = nil
            let run = EventDeliveryRun(isClosing: next.isClosing,
                                  bypassesBackoff: next.isClosing || next.bypassesBackoff,
                                  isPaced: next.isPaced && pacesDeliveries && !next.isClosing,
                                  gap: gap)
            running = run
            #if DEBUG
                deliveryRunCount += 1
            #endif
            return (run, next.waiters)
        }
    }

    /// Ends the delivery running, which has had its answer.
    ///
    /// - Returns: whether one queued behind it is to start now.
    func finish() -> Bool {
        lock.withLock {
            running = nil
            isDelivering = queued != nil
            return isDelivering
        }
    }

    /// Ends the pacing of the delivery running, which then sends the rest back to back, or, offline, stops.
    func endPacing() {
        lock.withLock { running }?.endPacing()
    }

    /// Takes the one delivery set for when the backoff's wait ends.
    ///
    /// - Returns: false where one is set already.
    func claimRetry() -> Bool {
        lock.withLock {
            defer { isRetryScheduled = true }
            return !isRetryScheduled
        }
    }

    /// Notes that the wait has ended and the delivery set for it is being queued, so a later failure can set another.
    func retryDue() {
        lock.withLock { isRetryScheduled = false }
    }

    #if DEBUG
        /// Callers waiting on the queued delivery.
        var queuedWaiterCount: Int {
            lock.withLock { queued?.waiters.count ?? 0 }
        }

        /// Deliveries started, counting one for a run of flushes that joined each other.
        var startedCount: Int {
            lock.withLock { deliveryRunCount }
        }
    #endif
}
