import Foundation
import OSLog

/// What an `EventBatchDeliverer` asks of the processor it delivers for, and tells it.
protocol EventBatchDelivererOwner: AnyObject {
    /// Whether the reporter is online. Only `flushAtClose()`'s delivery posts while it is not.
    var isOnline: Bool { get }
    /// Counts stored events lost for good.
    func reportStoredEventsLost(_ events: Int)
    /// Tells the application that a post was answered, or that a pass gave a batch up.
    func reportSyncComplete(_ result: SynchronizingError?)
    /// Sets a delivery for when the backoff's wait ends, `wait` from now.
    func deliverWhenWaitEnds(in wait: TimeInterval)
}

/// Sends the batches a delivery listed, one pass at a time: reads each, drops what is lost for good, and posts the rest
/// oldest first, through the pacing, the backoff and a pass's one retry.
///
/// One for each `DirectEventProcessor`, which decides when a delivery runs and what it lists. Everything here runs on
/// the processor's delivery queue, and each wait of a pass ends by going back there.
final class EventBatchDeliverer {
    /// How a pass over some batches ended, from best to worst. Only `blocked` ends a pass before its last batch; the
    /// others mean it got through every one.
    enum PassOutcome: Int, Comparable {
        /// Every batch was accepted.
        case delivered
        /// Every batch was accepted or lost for good, and at least one was lost: unreadable, damaged, deleted unsent, or
        /// had its payload refused `badRequestsBeforeDropping` times in a row.
        case lost
        /// The pass got through every batch, and this delivery passed at least one by: its read failed, and it is kept
        /// for a later delivery to read again.
        case passedBy
        /// The pass stopped at a batch that is still there to be sent again: its request failed, or the backoff did not
        /// allow it to be posted yet. The batches after it were not attempted.
        case blocked

        static func < (lhs: PassOutcome, rhs: PassOutcome) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Where a pass is once it has gone as far as it can with its first batch.
    private enum PassStep {
        /// Done with the batch: passed by, lost, or holding nothing to send.
        case moveOn
        /// Waiting for its turn under the pacing, for its retry or for a post's answer, after which it goes on.
        case waiting
        /// Stopped at the batch, which is still there to be sent again.
        case blocked
    }

    /// How many refusals of the payload in a row drop a batch: a 400, 413, 415 or 422, in any mix
    /// (`isEventPayloadRefused`). Each says the service will not take this body, which posting it again will not
    /// change, and a kept batch is the oldest and so the next posted: kept for good, it would hold every batch behind
    /// it. Two rather than one, so one from a proxy or an incident costs nothing.
    static let badRequestsBeforeDropping = 2

    /// How many counted failed reads in a row drop a batch. A read that fails is mostly one that will go on failing, a
    /// permission taken away or a directory named like a batch, and expiry cannot delete a file it cannot open, so the
    /// batch would be read, and fail, at every delivery for good. More than one, and counted at most once per
    /// `readFailureSpacing`, so a passing failure such as running out of file descriptors costs nothing.
    static let readFailuresBeforeDropping = 3

    // MARK: Set in init and never changed

    private let service: DarklyServiceProvider
    private let store: EventStoring
    private let committer: EventCommitter
    private let sender: AnalyticsEventSender
    /// When a post is allowed after a failure. Nothing is posted while it says to wait.
    private let retryState: DeliveryRetryState
    private let deliveryQueue: DispatchQueue

    /// Set once, as the processor is made.
    weak var owner: EventBatchDelivererOwner?

    // MARK: Guarded by lock

    /// Guards the counts of refused payloads and failed reads.
    private let lock = UnfairLock()

    /// The batch that last had its payload refused and how many times in a row: delivery goes oldest first and stops at
    /// a kept failure, so the next post is that batch's unless capacity dropped it. Any response other than a refusal
    /// ends the run; a post that got no response leaves it. Held only in memory, so a new run of the application counts
    /// again. Only to be used while holding `lock`.
    private var badRequests: (payloadId: String, inARow: Int)?

    /// The least time between two failed reads of a batch that both count toward dropping it: the flush interval, so a
    /// drop takes failures across at least two of them. Every pass that reaches the batch reads it, and passes can come
    /// milliseconds apart, from flushes called in a row or the blocking `flushAndWait` posting through the backoff;
    /// counted by pass, a failure lasting a moment would drop an intact batch. A failed read closer than this to the
    /// last counted one passes the batch by without counting. Settable only for tests.
    var readFailureSpacing: TimeInterval {
        get { lock.withLock { readFailureSpacingValue } }
        set { lock.withLock { readFailureSpacingValue = newValue } }
    }
    // Only to be used while holding `lock`.
    private var readFailureSpacingValue: TimeInterval

    /// Counted failed reads in a row, by payload ID, of the batches whose last read failed, and when the last of them
    /// was. Unlike refusals, these are counted for several batches at once, since a batch whose read failed is passed
    /// by. Held only in memory, so a new run of the application counts again. Only to be used while holding `lock`.
    private var readFailures: [String: (counted: Int, lastCounted: DispatchTime)] = [:]

    init(service: DarklyServiceProvider,
         store: EventStoring,
         committer: EventCommitter,
         retryState: DeliveryRetryState,
         deliveryQueue: DispatchQueue) {
        self.service = service
        self.store = store
        self.committer = committer
        self.sender = AnalyticsEventSender(service: service)
        self.retryState = retryState
        self.deliveryQueue = deliveryQueue
        self.readFailureSpacingValue = DirectEventProcessor.flushInterval(config: service.config)
    }

    /// Delivers the batches one pass of a delivery listed, oldest first, one at a time, and calls `completion` once with
    /// how the pass ended. On the delivery queue.
    ///
    /// - A failed post stops the pass. The batches left keep their place, and a later delivery tries them again, rather
    ///   than the SDK spending the session's requests on a service that is refusing them. Where the backoff's wait is no
    ///   longer than the initial delay, the pass sits it out once, as its retry, so a caller waiting on it hears the
    ///   retry's answer; a longer wait ends the pass, with a delivery set for when it ends.
    /// - A batch whose read fails is passed by, kept, and not read again in this delivery. A read says nothing about the
    ///   service, so it stops nothing.
    /// - A paced delivery holds each batch until the gap has passed since the last post was answered, so a backlog sent
    ///   unasked does not take the network from an `identify`'s flag request.
    func deliver(_ listing: BatchListing, _ run: EventDeliveryRun, _ completion: @escaping (PassOutcome) -> Void) {
        let lostAnything = listing.vanishedEvents > 0
        guard !listing.batches.isEmpty
        else {
            completion(lostAnything ? .lost : .delivered)
            return
        }
        os_log("%s starting", log: service.config.logger, type: .debug, typeName(and: #function))
        advance(EventDeliveryPass(listing.batches, run, lostAnything: lostAnything, completion: completion))
    }

    /// As `DeliveryRetryState.endOrdinaryWait()`, for the reporter going online again.
    func endOrdinaryWait() -> Bool {
        retryState.endOrdinaryWait()
    }

    /// Goes on with a pass from its first batch left, and calls its completion once it ends.
    ///
    /// Loops over the batches it can go through without waiting, so a run of them passed by or lost costs the stack
    /// nothing however long it is, and returns at the first wait, whose end calls it again.
    private func advance(_ pass: EventDeliveryPass) {
        while let batch = pass.remaining.first {
            switch step(pass, batch) {
            case .moveOn:
                pass.moveOn()
            case .waiting:
                return
            case .blocked:
                pass.completion(.blocked)
                return
            }
        }
        pass.completion(pass.outcome)
    }

    /// Goes as far as it can with the first batch a pass has left: passes it by, drops it, posts it, or waits until it
    /// may.
    private func step(_ pass: EventDeliveryPass, _ batch: EventBatch) -> PassStep {
        let run = pass.run
        guard !run.passedBy(batch.payloadId)
        else { return .moveOn }

        if !pass.hadTurn, run.awaitTurn(then: {
            self.deliveryQueue.async {
                pass.hadTurn = true
                self.advance(pass)
            }
        }) {
            return .waiting
        }

        guard mayPost(run)
        else { return .blocked }

        let wait = run.bypassesBackoff ? 0 : retryState.remainingWait
        guard wait <= 0
        else {
            // Not an attempt, so it moves nothing in the backoff. A wait no longer than a retry's is sat out, as this
            // pass's retry; a longer one ends the pass.
            guard !pass.retried && wait <= retryState.initialDelay
            else {
                scheduleDeliveryWhenWaitEnds()
                return .blocked
            }
            deliveryQueue.asyncAfter(deadline: .now() + wait) {
                pass.retried = true
                self.advance(pass)
            }
            return .waiting
        }

        let read: BatchPayload?
        do {
            read = try store.payload(of: batch)
        } catch is UnreadableBatch {
            // Lost: nothing will ever send it, so it is removed, the rest are still attempted, and the caller hears
            // that this pass lost events.
            os_log("%s dropping %d stored event(s) this version cannot read", log: service.config.logger, type: .error, typeName(and: #function), batch.eventCount)
            store.remove(batch)
            reportBatchLost(batch)
            pass.lostAnything = true
            return .moveOn
        } catch is VanishedBatch {
            os_log("%s %d stored event(s) were deleted before they could be sent", log: service.config.logger, type: .error, typeName(and: #function), batch.eventCount)
            store.remove(batch)
            reportBatchLost(batch)
            pass.lostAnything = true
            return .moveOn
        } catch {
            if passByOrDrop(batch, readFailedWith: error, run) {
                pass.lostAnything = true
            }
            return .moveOn
        }
        endReadFailures(batch)

        guard let payload = read
        else {
            // Delivered by another process or store, or holding no events. Either way nothing is lost and there is
            // nothing to keep.
            store.remove(batch)
            return .moveOn
        }

        // Damage after the first frame: what came before it is sent, and the rest is gone with the file. Counted once
        // the batch is removed rather than now, since one kept for a retry is read, and found short, again.
        let leftOut = max(0, batch.eventCount - payload.eventCount)
        service.diagnosticCache?.recordEventsInLastBatch(eventsInLastBatch: payload.eventCount)
        post(batch, payload, leftOut: leftOut, pass)
        return .waiting
    }

    /// Passes by a batch whose read failed, or drops it as lost once that is `readFailuresBeforeDropping` in a row.
    ///
    /// Kept, since a read that failed may not fail next time, but passed by rather than stopped at. Stopped at, it held
    /// back every batch behind it, the open log's included, on every pass for as long as the read kept failing: for good
    /// where expiry cannot open the file to delete it either.
    ///
    /// - Returns: whether it dropped the batch.
    private func passByOrDrop(_ batch: EventBatch, readFailedWith error: Error, _ run: EventDeliveryRun) -> Bool {
        guard countReadFailure(batch) < EventBatchDeliverer.readFailuresBeforeDropping
        else {
            os_log("%s dropping %d stored event(s) that could not be read %d times in a row: %s", log: service.config.logger, type: .error, typeName(and: #function), batch.eventCount, EventBatchDeliverer.readFailuresBeforeDropping, String(describing: error))
            store.remove(batch)
            reportBatchLost(batch)
            return true
        }
        os_log("%s could not read stored events, will try again at the next delivery: %s", log: service.config.logger, type: .info, typeName(and: #function), String(describing: error))
        run.passBy(batch.payloadId)
        return false
    }

    /// Whether the delivery running may post: online, or `flushAtClose()`'s. Going offline stops a delivery before its
    /// next post, its retry's included, and leaves what it has not sent for a later one.
    private func mayPost(_ run: EventDeliveryRun) -> Bool {
        run.isClosing || owner?.isOnline == true
    }

    /// Posts the first batch a pass has left, already read, and goes on with the pass once it has the answer. Requires
    /// the backoff to allow a post.
    private func post(_ batch: EventBatch, _ payload: BatchPayload, leftOut: Int, _ pass: EventDeliveryPass) {
        let run = pass.run
        publish(batch, payload, run) { outcome in
            switch outcome {
            case .accepted:
                self.endBadRequests()
                if leftOut > 0 {
                    os_log("%s dropped %d damaged stored event(s) from a batch it delivered", log: self.service.config.logger, type: .error, self.typeName(and: #function), leftOut)
                    self.owner?.reportStoredEventsLost(leftOut)
                    pass.lostAnything = true
                }
                pass.moveOn()
                self.advance(pass)
            case .failed(let failure):
                // Only a run bypassing the backoff posts during its wait.
                let wait = run.bypassesBackoff
                    ? self.retryState.recordFailureDuringWait(unexpected: failure.unexpected, retryAfter: failure.retryAfter)
                    : self.retryState.recordFailure(unexpected: failure.unexpected, retryAfter: failure.retryAfter)
                if self.countBadRequest(batch, statusCode: failure.statusCode) >= EventBatchDeliverer.badRequestsBeforeDropping {
                    // The rest are still attempted, once the backoff allows.
                    os_log("%s dropping %d event(s) whose payload the service refused %d times in a row, last with HTTP %d", log: self.service.config.logger, type: .error, self.typeName(and: #function), batch.eventCount, EventBatchDeliverer.badRequestsBeforeDropping, failure.statusCode ?? 0)
                    self.store.remove(batch)
                    self.reportBatchLost(batch)
                    self.owner?.reportSyncComplete(failure.error)
                    pass.lostAnything = true
                    pass.moveOn()
                    self.advance(pass)
                    return
                }
                guard !pass.retried, wait <= self.retryState.initialDelay
                else {
                    // Told once the pass gives the batch up, not for a failure its retry may still answer.
                    self.owner?.reportSyncComplete(failure.error)
                    self.scheduleDeliveryWhenWaitEnds()
                    pass.completion(.blocked)
                    return
                }
                self.retry(batch, payload, leftOut: leftOut, pass, after: wait, failedWith: failure.error)
            }
        }
    }

    /// Posts the batch whose post just failed again once `wait` has passed, as the pass's retry.
    // swiftlint:disable:next function_parameter_count
    private func retry(_ batch: EventBatch,
                       _ payload: BatchPayload,
                       leftOut: Int,
                       _ pass: EventDeliveryPass,
                       after wait: TimeInterval,
                       failedWith error: SynchronizingError) {
        os_log("%s Retrying event post after %.1fs", log: service.config.logger, type: .debug, typeName(and: #function), wait)
        deliveryQueue.asyncAfter(deadline: .now() + wait) {
            // Another delivery's failure may have set a longer wait meanwhile, or the reporter gone offline.
            guard self.mayPost(pass.run)
            else {
                self.owner?.reportSyncComplete(error)
                pass.completion(.blocked)
                return
            }
            guard self.retryState.remainingWait <= 0
            else {
                self.owner?.reportSyncComplete(error)
                self.scheduleDeliveryWhenWaitEnds()
                pass.completion(.blocked)
                return
            }
            pass.retried = true
            self.post(batch, payload, leftOut: leftOut, pass)
        }
    }

    /// Sends one batch and acts on what LaunchDarkly made of it, before handing the outcome on. Both on the delivery
    /// queue, rather than on the URL session's delegate queue, which every environment shares.
    private func publish(_ batch: EventBatch,
                         _ payload: BatchPayload,
                         _ run: EventDeliveryRun,
                         _ completion: @escaping (AnalyticsEventSender.Outcome) -> Void) {
        store.startedSending(batch)
        // The store is settled before observers are told, so that one looking at it on hearing the outcome sees it.
        sender.send(payload.body, payloadId: batch.payloadId, eventCount: payload.eventCount) { outcome in
            run.postAnswered()
            self.deliveryQueue.async {
                switch outcome {
                case .accepted(let serverTime):
                    self.retryState.recordSuccess()
                    if let serverTime {
                        self.committer.recordResponseDate(serverTime)
                    }
                    self.store.remove(batch)
                    self.store.stoppedSending(batch)
                    self.owner?.reportSyncComplete(nil)
                case .failed:
                    self.store.stoppedSending(batch)
                    // Kept whatever the failure, a 401 included: a valid key is sometimes refused for minutes, and
                    // deleting on a refusal would lose every event recorded meanwhile. A later delivery, in this run of
                    // the application or the next one, sends it under the same payload ID, so LaunchDarkly can tell it
                    // is not new.
                    os_log("%s Keeping %d event(s) to retry later", log: self.service.config.logger, type: .debug, self.typeName(and: #function), batch.eventCount)
                }
                completion(outcome)
            }
        }
    }

    /// Asks the owner for a delivery when the backoff's wait ends, so a batch kept through a failure goes out then
    /// rather than at the next report interval after it.
    private func scheduleDeliveryWhenWaitEnds() {
        let wait = retryState.remainingWait
        guard wait > 0
        else { return }
        owner?.deliverWhenWaitEnds(in: wait)
    }

    /// `EventBatchDelivererOwner.reportStoredEventsLost(_:)` for a whole batch.
    private func reportBatchLost(_ batch: EventBatch) {
        owner?.reportStoredEventsLost(batch.eventCount)
    }

    /// - Parameter statusCode: the response's status, or nil where there was no response.
    /// - Returns: how many refusals of the payload in a row this batch has had, counting this response; zero for any
    ///   other status, which ends the run, and once the batch is dropped.
    private func countBadRequest(_ batch: EventBatch, statusCode: Int?) -> Int {
        lock.withLock {
            guard let statusCode
            else {
                // A network or TLS failure leaves the run as it was. The service did not answer, so it said nothing
                // about the payload: had it ended the run, refusals with network failures between them would never
                // reach two, and a batch the service will never take would stay the oldest, holding back every
                // batch behind it.
                if let previous = badRequests, previous.payloadId == batch.payloadId {
                    return previous.inARow
                }
                return 0
            }
            guard HTTPURLResponse.StatusCodes.isEventPayloadRefused(statusCode)
            else {
                badRequests = nil
                return 0
            }
            var inARow = 1
            if let previous = badRequests, previous.payloadId == batch.payloadId {
                inARow = previous.inARow + 1
            }
            badRequests = inARow >= EventBatchDeliverer.badRequestsBeforeDropping ? nil : (batch.payloadId, inARow)
            return inARow
        }
    }

    /// Ends the run of refusals of the payload, as an accepted post does.
    private func endBadRequests() {
        lock.withLock { badRequests = nil }
    }

    /// - Returns: how many counted reads in a row of this batch have failed, this one included if it is at least
    ///   `readFailureSpacing` after the last counted one; once that reaches `readFailuresBeforeDropping` the count is
    ///   ended, since the batch is dropped.
    private func countReadFailure(_ batch: EventBatch) -> Int {
        let now = DispatchTime.now()
        return lock.withLock {
            if let last = readFailures[batch.payloadId], now < last.lastCounted + readFailureSpacingValue {
                return last.counted
            }
            let counted = (readFailures[batch.payloadId]?.counted ?? 0) + 1
            readFailures[batch.payloadId] = counted >= EventBatchDeliverer.readFailuresBeforeDropping
                ? nil : (counted, now)
            return counted
        }
    }

    /// Ends a batch's run of failed reads, at a read that worked.
    private func endReadFailures(_ batch: EventBatch) {
        lock.withLock { _ = readFailures.removeValue(forKey: batch.payloadId) }
    }
}

extension EventBatchDeliverer: TypeIdentifying { }

/// One pass over the batches a delivery listed, from its first batch until it has gone through the last or stops.
///
/// Only used on the delivery queue. The pass takes its batches there, and each wait it makes, for its turn under the
/// pacing, for a retry or for a post's answer, ends by going back there, so the rest of the pass never runs on
/// whichever thread the wait ended on.
final class EventDeliveryPass {
    let run: EventDeliveryRun
    /// The batches it has not gone through, oldest first.
    private(set) var remaining: ArraySlice<EventBatch>
    /// Whether a batch it went through was lost for good, so the caller hears of it even where the batches after it
    /// were accepted.
    var lostAnything: Bool
    /// Whether it has had its retry.
    var retried = false
    /// Whether the first of `remaining` has already waited its turn under the pacing, so it is not held again.
    var hadTurn = false
    /// Called once, with how the pass ended.
    let completion: (EventBatchDeliverer.PassOutcome) -> Void

    init(_ batches: [EventBatch],
         _ run: EventDeliveryRun,
         lostAnything: Bool,
         completion: @escaping (EventBatchDeliverer.PassOutcome) -> Void) {
        self.run = run
        self.remaining = batches[...]
        self.lostAnything = lostAnything
        self.completion = completion
    }

    /// Goes on to the next batch, which waits its own turn.
    func moveOn() {
        remaining.removeFirst()
        hadTurn = false
    }

    /// How it ended, once it has gone through every batch.
    var outcome: EventBatchDeliverer.PassOutcome {
        run.passedAnyBy ? .passedBy : lostAnything ? .lost : .delivered
    }
}
