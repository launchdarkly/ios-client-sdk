import Foundation
import OSLog

/// Records analytics events and delivers them to LaunchDarkly.
///
/// Recorded events end up in an `EventStore`, an on-disk log, rather than held in memory until a delivery succeeds.
/// That is what lets an application that dies moments after recording an event still report it: the events are on disk
/// before the process is gone, and the next run of the application delivers them.
///
/// What the application records is accepted, held and committed to the store by `EventCommitter`, which says which
/// calls are commit points and which thread each commit runs on. This class delivers what is committed, and runs the
/// reporter's life: flushes, going online and offline, and the flush at close.
///
/// Flag values come first. Where events persist, what a previous run left waits at launch until a fixed time after the
/// reporter first goes online, and the deliveries this reporter starts on its own send one batch at a time, a gap apart,
/// leaving room for flag requests. Both go by time alone: nothing here hears what the flag synchronizer is doing. A
/// delivery the application asks for is never held.
class DirectEventProcessor: EventProcessor {
    /// How long the deliveries this reporter starts on its own wait, so that flag values come first.
    struct Pacing {
        static let specified = Pacing(launchDelay: 2, gap: 1)
        /// No waits at all, for tests about something else.
        static let noWaits = Pacing(launchDelay: 0, gap: 0)

        /// How long after first going online that a previous run's events, and the diagnostic init event, wait. It
        /// gives the application's startup traffic, the first flag request among it, the network first, and is short
        /// enough for an application that dies a few seconds after every launch to still send them.
        let launchDelay: TimeInterval
        /// The least time between one paced batch's answer and the next batch's request.
        let gap: TimeInterval
    }

    // MARK: Set in init and never changed

    let service: DarklyServiceProvider
    let store: EventStoring
    let committer: EventCommitter
    private let lostEvents: LostEventCount
    private let deliveryScheduler: EventDeliveryScheduler

    private let onSyncComplete: EventSyncCompleteClosure?

    private let sender: AnalyticsEventSender

    /// When a post is allowed after a failure. Nothing is posted while it says to wait.
    private let retryState: DeliveryRetryState

    private let pacing: Pacing
    /// Whether events give way to flag values: only where they persist, like the rest of what persistence brings.
    /// Without it there is no previous run to hold back, and delivery is what it was before persistence: no launch
    /// gate and no pacing.
    let givesWayToFlags: Bool

    var lastEventResponseDate: Date {
        committer.lastEventResponseDate
    }

    // MARK: Guarded by stateLock

    /// Guards which losses have been told to a caller, and the count of refused payloads.
    private let stateLock = UnfairLock()

    /// The mark up to which losses have already been reported to a caller, so that none is told twice. Only to be
    /// used while holding `stateLock`.
    private var reportedLostEvents: UInt64 = 0

    /// How many refusals of the payload in a row drop a batch: a 400, 413, 415 or 422, in any mix
    /// (`isEventPayloadRefused`). Each says the service will not take this body, which posting it again will not
    /// change, and a kept batch is the oldest and so the next posted: kept for good, it would hold every batch behind
    /// it. Two rather than one, so one from a proxy or an incident costs nothing.
    static let badRequestsBeforeDropping = 2

    /// The batch that last had its payload refused and how many times in a row: delivery goes oldest first and stops at
    /// a kept failure, so the next post is that batch's unless capacity dropped it. Held only in memory, so a new run of
    /// the application counts again. Only to be used while holding `stateLock`.
    private var badRequests: (payloadId: String, inARow: Int)?

    // MARK: Guarded by claimLock

    /// Guards `batchesInFlight`.
    ///
    /// Its own lock rather than `stateLock`, which an evaluating thread takes to read `lastEventResponseDate`: a claim
    /// is made next to a listing of the store, and nothing a flag evaluation waits on may be held near the disk.
    private let claimLock = UnfairLock()

    /// The batches a delivery has taken and not yet had an answer for, by payload ID. Only to be used while holding
    /// `claimLock`.
    ///
    /// A batch stays on disk until its response arrives. `EventDeliveryScheduler` keeps a second delivery from listing it
    /// inside that window; this is what keeps it from being sent twice, under the same payload ID, should two ever overlap.
    /// A delivery that finds a batch claimed waits on that claim's outcome rather than sending it.
    private var batchesInFlight: [String: Claim] = [:]

    // MARK: Confined to timerQueue

    var isOnline: Bool {
        get { timerQueue.sync { eventReportTimer != nil } }
        set { timerQueue.sync { newValue ? startReporting() : stopReporting() } }
    }

    private var timerQueue = DispatchQueue(label: "com.launchdarkly.DirectEventProcessor.timerQueue")
    private var eventReportTimer: TimeResponding?
    var isReportingActive: Bool { eventReportTimer != nil }

    // MARK: Confined to deliveryQueue

    /// Deliveries run here, off whatever thread recorded an event.
    private let deliveryQueue = DispatchQueue(label: "com.launchdarkly.eventSyncQueue", qos: .userInitiated)

    /// Whether the store held events from a previous run of the application when this reporter started.
    ///
    /// Only to be used on `deliveryQueue`, which is what makes it safe without a lock: the recovery that answers the
    /// question and the delivery that acts on it are both enqueued there, in that order.
    private var hasEventsFromPreviousRun = false

    /// Whether the launch gate has opened. It opens once the launch delay has passed since first going online. Until then
    /// neither a previous run's events nor the diagnostic init event are sent. Open from the start where events do not
    /// give way.
    private var launchGateOpen: Bool
    /// When the reporter first went online, which the gate counts from.
    private var wentOnlineAt: DispatchTime?
    /// What waits for the gate to open.
    private var launchGateWaiters: [() -> Void] = []

    init(service: DarklyServiceProvider,
         onSyncComplete: EventSyncCompleteClosure?,
         store: EventStoring? = nil,
         encoding: OutboundEventBuffer.Encoding = .handWritten,
         commitQueue: DispatchQueue = DispatchQueue(label: "com.launchdarkly.DirectEventProcessor.commitQueue", qos: .userInitiated),
         retryState: DeliveryRetryState? = nil,
         pacing: Pacing = .specified) {
        let eventStore = store ?? DirectEventProcessor.makeStore(config: service.config)
        let lostEvents = LostEventCount()
        self.service = service
        self.onSyncComplete = onSyncComplete
        self.sender = AnalyticsEventSender(service: service)
        self.retryState = retryState ?? DeliveryRetryState(flushInterval: service.config.eventFlushInterval)
        self.lostEvents = lostEvents
        self.committer = EventCommitter(config: service.config, store: eventStore, encoding: encoding,
                                        commitQueue: commitQueue, diagnosticCache: service.diagnosticCache,
                                        lostEvents: lostEvents)
        self.store = eventStore
        self.pacing = pacing
        self.givesWayToFlags = eventStore.isPersisting
        self.deliveryScheduler = EventDeliveryScheduler(pacesDeliveries: eventStore.isPersisting, gap: pacing.gap)
        self.launchGateOpen = !eventStore.isPersisting

        // A log left open by a previous run has to be closed before it can be delivered, but nothing waits on that:
        // doing it on the caller's thread would put file I/O in the way of the client starting up. Below the queue's
        // own priority, and so below the flag requests, which matter more at launch than what a previous run left.
        // Only where events persist, since memory holds nothing from a previous run.
        guard eventStore.isPersisting
        else { return }
        let store = eventStore
        deliveryQueue.async(qos: .utility, flags: .enforceQoS) { [weak self] in
            store.preparePayloadsFromInterruptedLogs()
            self?.reportDiscarded(store.discardExpired())
            let listing = store.listPendingBatches()
            self?.reportVanished(listing.vanishedEvents)
            self?.hasEventsFromPreviousRun = !listing.batches.isEmpty
        }
    }

    private static func makeStore(config: LDConfig) -> EventStoring {
        let mobileKey = config.mobileKey
        return EventStore(locatingDirectory: { EventDirectory.defaultUrl(mobileKey: mobileKey) },
                          capacity: config.eventCapacity,
                          byteCapacity: shareOfCapacityBytes(config: config),
                          maxAge: config.eventMaxAge,
                          persistEvents: config.eventPersistence != .disabled,
                          logger: config.logger)
    }

    /// This environment's share of the byte capacity, which is for every environment the application configured together,
    /// where the event capacity is for each one.
    static func shareOfCapacityBytes(config: LDConfig) -> Int {
        let total = config.eventCapacityBytes > 0 ? config.eventCapacityBytes : LDConfig.Defaults.eventCapacityBytes
        // At least one byte, since the store reads zero as the default.
        return max(1, total / (1 + config.getSecondaryMobileKeys().count))
    }

    // MARK: Recording

    func record(_ event: Event) {
        committer.record(event)
    }

    // swiftlint:disable:next function_parameter_count
    func recordFlagEvaluationEvents(flagKey: LDFlagKey,
                                    value: LDValue,
                                    defaultValue: LDValue,
                                    featureFlag: FeatureFlag?,
                                    context: LDContext,
                                    includeReason: Bool) {
        committer.recordFlagEvaluationEvents(flagKey: flagKey, value: value, defaultValue: defaultValue,
                                             featureFlag: featureFlag, context: context, includeReason: includeReason)
    }

    func commitRecordedEvents() {
        committer.commitRecordedEvents()
    }

    func commitWherePersisting() {
        committer.commitWherePersisting()
    }

    /// Records stored events discarded for being older than the maximum age.
    ///
    /// Counted as dropped rather than lost: a flush is about the caller's events, and the ones discarded are long
    /// past anything a caller is waiting on.
    private func reportDiscarded(_ events: Int) {
        guard events > 0
        else { return }
        os_log("%s discarded %d stored event(s) older than the maximum age", log: service.config.logger, type: .debug, typeName(and: #function), events)
        for _ in 0..<events {
            service.diagnosticCache?.incrementDroppedEventCount()
        }
    }

    /// Records a batch lost for good. The pass that lost it tells its caller, but a delivery nobody waits on -- the
    /// periodic one, a `flush()`, the one going online starts -- has no one to tell, so the loss is also counted for the
    /// next `flushReportingOutcome` to hear about. A caller waiting on this pass can then hear about it from the next
    /// one too.
    private func reportBatchLost(_ batch: EventBatch) {
        reportStoredEventsLost(batch.eventCount)
    }

    /// `reportBatchLost(_:)` for part of a batch.
    private func reportStoredEventsLost(_ events: Int) {
        lostEvents.add(events)
    }

    /// Whether anything was lost up to `mark` that no caller has been told about, which this caller is now the one to
    /// hear about.
    ///
    /// Marks it reported, so the next caller is not told about the same loss. A delivery that nobody is waiting on
    /// never asks, so a scheduled delivery does not consume the answer a later caller is owed.
    private func takeEventsLost(upTo mark: UInt64) -> Bool {
        stateLock.withLock {
            guard mark > reportedLostEvents
            else { return false }
            reportedLostEvents = mark
            return true
        }
    }

}

// MARK: Reporting

extension DirectEventProcessor {
    private func startReporting() {
        guard eventReportTimer == nil
        else { return }
        eventReportTimer = LDTimer(withTimeInterval: service.config.eventFlushInterval, fireQueue: deliveryQueue, execute: queueScheduledDelivery)

        // Events a previous run left behind are already late by however long the application was gone, so they do not
        // wait out a report interval on top of that, only the launch gate: an application that crashed reports it as
        // soon as it is next able to. Only the first time online brings a delivery forward, so going online again
        // later, as a network comes and goes, keeps to the ordinary cadence.
        deliveryQueue.async { [weak self] in
            guard let self
            else { return }
            if self.wentOnlineAt == nil {
                self.wentOnlineAt = .now()
                if !self.launchGateOpen {
                    self.checkLaunchGate(after: self.pacing.launchDelay)
                }
            }
            guard self.launchGateOpen, self.hasEventsFromPreviousRun
            else { return }
            self.hasEventsFromPreviousRun = false
            self.queueScheduledDelivery()
        }
    }

    private func stopReporting() {
        eventReportTimer?.cancel()
        eventReportTimer = nil
        deliveryScheduler.endPacing()
    }

    /// Runs `block`, on a global queue, once the launch gate is open.
    func whenLaunchGateOpens(_ block: @escaping () -> Void) {
        deliveryQueue.async { [weak self] in
            guard let self, !self.launchGateOpen
            else {
                DispatchQueue.global().async(execute: block)
                return
            }
            self.launchGateWaiters.append(block)
        }
    }

    private func checkLaunchGate(after delay: TimeInterval) {
        deliveryQueue.asyncAfter(deadline: .now() + max(0, delay)) { [weak self] in self?.checkLaunchGate() }
    }

    /// Opens the launch gate once the launch delay has passed since first going online, and otherwise looks again then.
    /// On `deliveryQueue`.
    private func checkLaunchGate() {
        guard !launchGateOpen, let wentOnlineAt
        else { return }
        let sinceOnline = TimeInterval(DispatchTime.now().uptimeNanoseconds - wentOnlineAt.uptimeNanoseconds) / 1_000_000_000
        guard sinceOnline >= pacing.launchDelay
        else {
            checkLaunchGate(after: pacing.launchDelay - sinceOnline)
            return
        }
        launchGateOpen = true
        let waiters = launchGateWaiters
        launchGateWaiters = []
        waiters.forEach { DispatchQueue.global().async(execute: $0) }
        guard hasEventsFromPreviousRun
        else { return }
        os_log("%s Sending events from a previous run, %dms after going online", log: service.config.logger, type: .debug, typeName(and: #function), Int(pacing.launchDelay * 1000))
        // Offline, they wait for the reporter to go online, which finds the gate open.
        guard isOnline
        else { return }
        hasEventsFromPreviousRun = false
        queueScheduledDelivery()
    }

    func flush(completion: CompletionClosure?) {
        // Nil stays nil, so a flush nobody waits on joins a queued delivery without adding to its waiters.
        commitThenQueueDelivery(completion.map { done in { _ in done() } })
    }

    func flushReportingOutcome(completion: @escaping FlushOutcomeClosure) {
        committer.queueCommitWherePersisting()
        queueDelivery(completion)
    }

    func flushAtClose() {
        commitWherePersisting()
        // Offline, it is an ordinary delivery, which finds the reporter offline and sends nothing: offline is the
        // application keeping the SDK off the network, and closing does not revoke that.
        queueDelivery(nil, closing: isOnline)
    }

    /// Queues a delivery the way a caller asking for one expects, which is as a commit point.
    ///
    /// Wherever events persist, everything accepted before the call is on disk by the time it returns, even where the
    /// delivery itself cannot run because the client is offline. What it does not do is close those events into a
    /// batch: only a delivery does that, so a delivery already under way may be the one holding them. That is why the
    /// answer waits on the claims it skips rather than only on what it sent itself.
    private func commitThenQueueDelivery(_ completion: FlushOutcomeClosure?) {
        commitWherePersisting()
        queueDelivery(completion)
    }

    /// Queues the delivery the report timer and the launch gate start, which nobody asked for now and which is paced.
    private func queueScheduledDelivery() {
        queueDelivery(nil, paced: true)
    }

    /// As `EventDeliveryScheduler.queue(_:closing:paced:)`, starting the delivery where nothing is running.
    private func queueDelivery(_ completion: FlushOutcomeClosure?, closing: Bool = false, paced: Bool = false) {
        if deliveryScheduler.queue(completion, closing: closing, paced: paced) {
            deliveryQueue.async { self.runDelivery() }
        }
    }

    private func runDelivery() {
        let (run, waiters) = deliveryScheduler.begin()
        reportEvents(run) { delivered, lossMark in
            // Taken once for the delivery rather than once per waiter, so that every caller joined to it hears about
            // a loss instead of only whichever happened to be answered first. Taken before the next delivery starts,
            // which could otherwise answer first and take this one's loss with its own.
            let kept = waiters.isEmpty || !self.takeEventsLost(upTo: lossMark)
            // Before the waiters are answered, so a completion that flushes again finds this delivery over.
            self.startQueuedDeliveryOrStop()
            guard !waiters.isEmpty
            else { return }
            // Answered away from `deliveryQueue`, and from whichever thread the delivery ended on, so that every
            // completion reaches its caller the same way. A completion is free to flush again: it is never running
            // on the queue the delivery it asks for would be queued on.
            DispatchQueue.global().async {
                for waiter in waiters {
                    waiter(delivered && kept)
                }
            }
        }
    }

    /// Ends the delivery that just had its answer, starting the one queued behind it if there is one.
    private func startQueuedDeliveryOrStop() {
        if deliveryScheduler.finish() {
            deliveryQueue.async { self.runDelivery() }
        }
    }

    /// - Parameter run: the delivery; a closing one was online when it was asked for.
    private func reportEvents(_ run: DeliveryRun, completion: ((_ delivered: Bool, _ lossMark: UInt64) -> Void)?) {
        guard run.isClosing || isOnline
        else {
            os_log("%s aborted. DirectEventProcessor is offline", log: service.config.logger, type: .debug, typeName(and: #function))
            reportSyncComplete(.isOffline)
            completion?(false, 0)
            return
        }

        // The batches already waiting go first, and what has been committed since is closed into a batch of its own
        // only once none of them is left blocked. Closing first would add a batch for every pass a failure lasts: every
        // flush, periodic delivery and trip to the background of an outage would leave one more file, or one more batch
        // held in memory, each with the summary its commit staged. Held back, what is committed meanwhile goes on into
        // the open log, which closes once it is full or once the batches ahead of it are gone, so an outage costs a
        // batch per `EventLogFormat.maxBatchSize` rather than one per pass.
        let waiting = claimDeliverableBatches(discardingExpired: true)
        // Settled before this delivery's own outcome is reported, which is what the answer waits for last.
        var settled = (lossMark: UInt64(0), accountsForEverything: false)
        // This delivery's own outcome, plus that of every batch another delivery is already sending. The caller's
        // events may be in either: a delivery that started after they were recorded closed them into its batch.
        let answer = PassAnswer(outstanding: waiting.waitingOn.count + 1) { outcome in
            completion?(outcome == .delivered && settled.accountsForEverything, settled.lossMark)
        }
        // Waited on for the answer, but not before closing.
        waitOn(waiting.waitingOn, answer)

        deliverOwn(waiting.deliverable, run, lostAnything: waiting.lostAnything) { waitingOutcome in
            guard waitingOutcome != .blocked
            else {
                // Committed all the same, since a delivery is a commit point. Nothing was closed, so the caller's events
                // did not go, and the mark is as of this commit, the last point anything the caller recorded was staged.
                settled = (self.committer.commitLeavingTheLogOpen(), false)
                os_log("%s will report failure: an earlier batch could not be delivered", log: self.service.config.logger, type: .debug, self.typeName(and: #function))
                answer.report(.blocked)
                return
            }

            let (lossMark, closedEverything) = self.committer.commitAndCloseBatch()
            let new = self.claimDeliverableBatches(discardingExpired: false)
            // Events left in a log that would not close, or in a batch a listing that failed could not see, are still on
            // the disk for a later delivery. This one delivers what it has, and cannot say the caller's events got out.
            settled = (lossMark, closedEverything && waiting.isComplete && new.isComplete)
            if !settled.accountsForEverything {
                os_log("%s will report failure: %s", log: self.service.config.logger, type: .debug, self.typeName(and: #function),
                       closedEverything ? "the stored events could not be listed" : "the event log could not be closed")
            }
            if waiting.deliverable.isEmpty && waiting.waitingOn.isEmpty && new.deliverable.isEmpty && new.waitingOn.isEmpty {
                os_log("%s aborted. Event store is empty", log: self.service.config.logger, type: .debug, self.typeName(and: #function))
                self.reportSyncComplete(nil)
            }

            let newAnswer = PassAnswer(outstanding: new.waitingOn.count + 1) { newOutcome in
                answer.report(max(waitingOutcome, newOutcome))
            }
            self.waitOn(new.waitingOn, newAnswer)
            self.deliverOwn(new.deliverable, run, lostAnything: new.lostAnything, newAnswer.report)
        }
    }

    /// Delivers the batches this delivery claimed, releasing the claims once it has an outcome.
    ///
    /// - Parameter lostAnything: whether the listing that found them found other batches deleted unsent.
    private func deliverOwn(_ batches: [EventBatch], _ run: DeliveryRun, lostAnything: Bool, _ completion: @escaping (PassOutcome) -> Void) {
        guard !batches.isEmpty
        else {
            completion(lostAnything ? .lost : .delivered)
            return
        }
        os_log("%s starting", log: service.config.logger, type: .debug, typeName(and: #function))
        deliver(batches, run, lostAnything: lostAnything, retried: false) { outcome in
            self.releaseClaim(on: batches, delivered: outcome == .delivered)
            completion(outcome)
        }
    }

    /// Reports the outcome of each batch another delivery is sending to `answer`, once it has one.
    private func waitOn(_ claims: [Claim], _ answer: PassAnswer) {
        for claim in claims {
            whenSettled(claim) { answer.report($0 ? .delivered : .blocked) }
        }
    }

    /// What `claimDeliverableBatches(discardingExpired:)` took.
    private struct ClaimedBatches {
        let deliverable: [EventBatch]
        /// The claims on the batches left out. One may hold this caller's events -- `commitRecordedEvents` only stages
        /// them, and whichever delivery runs next is what closes them into a batch -- so the answer has to wait for
        /// those claims rather than assume they are someone else's business.
        let waitingOn: [Claim]
        let isComplete: Bool
        /// Whether the listing found batches deleted unsent.
        let lostAnything: Bool
    }

    /// Takes the batches this delivery will send, leaving out any another delivery is still waiting on a response for.
    ///
    /// - Parameter discardingExpired: whether to discard what is too old to report first, which a second pass moments
    ///   after the first has no need to do again.
    private func claimDeliverableBatches(discardingExpired: Bool) -> ClaimedBatches {
        // Listed before the lock is taken, because listing reads the disk. Taking what appeared after it is the next
        // delivery's business; all this has to be atomic is deciding which of these batches are this delivery's.
        // Expired first, so that a batch too old to report is not sent.
        if discardingExpired {
            reportDiscarded(store.discardExpired())
        }
        let listing = store.listPendingBatches()
        reportVanished(listing.vanishedEvents)
        return claimLock.withLock {
            var deliverable: [EventBatch] = []
            var waitingOn: [Claim] = []
            for batch in listing.batches {
                if let claimed = batchesInFlight[batch.payloadId] {
                    waitingOn.append(claimed)
                } else {
                    batchesInFlight[batch.payloadId] = Claim()
                    deliverable.append(batch)
                }
            }
            return ClaimedBatches(deliverable: deliverable, waitingOn: waitingOn, isComplete: listing.isComplete,
                                  lostAnything: listing.vanishedEvents > 0)
        }
    }

    /// Counts as lost the events of batches a listing found deleted unsent, or of an open log a close found gone.
    private func reportVanished(_ events: Int) {
        guard events > 0
        else { return }
        os_log("%s %d stored event(s) were deleted before they could be sent", log: service.config.logger, type: .error, typeName(and: #function), events)
        reportStoredEventsLost(events)
    }

    /// Releases the claims once the delivery has an answer, whether or not every batch was sent: `deliver` stops at the
    /// first retryable failure, and what it did not reach has to be deliverable again.
    ///
    /// Every batch in the pass is settled with the pass's own result, rather than its own. A pass that stopped partway
    /// did not hear back about what it never reached, so the batches it is giving up are not known to have arrived.
    private func releaseClaim(on batches: [EventBatch], delivered: Bool) {
        let waiters = claimLock.withLock { () -> [FlushOutcomeClosure] in
            batches.flatMap { batch -> [FlushOutcomeClosure] in
                guard let claimed = batchesInFlight.removeValue(forKey: batch.payloadId)
                else { return [] }
                claimed.outcome = delivered
                return claimed.waiters
            }
        }

        for waiter in waiters {
            waiter(delivered)
        }
    }

    /// Calls back with a claimed batch's outcome, once there is one.
    ///
    /// Settling and registering both happen under `claimLock`, so a claim released between the listing and this call
    /// answers from what it recorded rather than leaving a waiter nobody will ever come back to.
    private func whenSettled(_ claim: Claim, _ completion: @escaping FlushOutcomeClosure) {
        let settled = claimLock.withLock { () -> Bool? in
            guard let outcome = claim.outcome
            else {
                claim.waiters.append(completion)
                return nil
            }
            return outcome
        }

        if let settled {
            completion(settled)
        }
    }

    /// How a pass over some batches went, from best to worst.
    enum PassOutcome: Int, Comparable {
        /// Every batch was accepted.
        case delivered
        /// Every batch was attempted, and at least one was lost for good: unreadable, damaged, deleted unsent, or had its
        /// payload refused `badRequestsBeforeDropping` times in a row.
        case lost
        /// A batch is still there to be sent again: its request failed, the backoff did not allow it to be posted yet,
        /// or it could not be read this time. The batches after it were not attempted.
        case blocked

        static func < (lhs: PassOutcome, rhs: PassOutcome) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Delivers batches oldest first, stopping at the first one that failed.
    ///
    /// Stopping matters: the batches that are left keep their place in the log, and a later delivery attempts them
    /// again rather than the SDK spending the rest of the session's requests on a service that is refusing them.
    ///
    /// A failure whose wait is no longer than the initial delay is retried here, once a pass, so a caller waiting on
    /// the pass hears from the retry; a longer wait ends the pass at once, with a delivery set for when the wait ends.
    ///
    /// `lostAnything` carries whether a batch already taken in this pass was lost for good, so that the caller hears
    /// about it even where the batches after it were accepted. `retried` whether this pass has had its retry.
    ///
    /// A paced delivery holds each batch after its first until a gap has passed since the last one was answered. A
    /// backlog this sends unasked otherwise takes the network for as long as it lasts, an `identify`'s flag request
    /// included. `hadTurn` is whether the first batch has been held already.
    private func deliver(_ batches: [EventBatch], _ run: DeliveryRun, lostAnything: Bool, retried: Bool, hadTurn: Bool = false, _ completion: @escaping (PassOutcome) -> Void) {
        var remaining = batches
        guard !remaining.isEmpty
        else {
            completion(lostAnything ? .lost : .delivered)
            return
        }

        if !hadTurn, run.awaitTurn(then: {
            self.deliver(batches, run, lostAnything: lostAnything, retried: retried, hadTurn: true, completion)
        }) {
            return
        }

        guard mayPost(run)
        else {
            completion(.blocked)
            return
        }

        let wait = run.isClosing ? 0 : retryState.remainingWait
        guard wait <= 0
        else {
            // Not an attempt, so it moves nothing in the backoff. A wait no longer than a retry's is sat out, as this
            // pass's retry; a longer one ends the pass.
            if !retried && wait <= retryState.initialDelay {
                DispatchQueue.global().asyncAfter(deadline: .now() + wait) {
                    self.deliver(batches, run, lostAnything: lostAnything, retried: true, completion)
                }
            } else {
                scheduleDeliveryWhenWaitEnds()
                completion(.blocked)
            }
            return
        }

        let batch = remaining.removeFirst()
        let read: BatchPayload?
        do {
            read = try store.payload(of: batch)
        } catch is UnreadableBatch {
            // Lost: nothing will ever send it, so it is removed, the rest are still attempted, and the caller hears
            // that this pass lost events.
            os_log("%s dropping %d stored event(s) this version cannot read", log: service.config.logger, type: .error, typeName(and: #function), batch.eventCount)
            store.remove(batch)
            reportBatchLost(batch)
            deliver(remaining, run, lostAnything: true, retried: retried, completion)
            return
        } catch is VanishedBatch {
            os_log("%s %d stored event(s) were deleted before they could be sent", log: service.config.logger, type: .error, typeName(and: #function), batch.eventCount)
            store.remove(batch)
            reportBatchLost(batch)
            deliver(remaining, run, lostAnything: true, retried: retried, completion)
            return
        } catch {
            // Kept: the batch is still there, and a read that failed may not fail next time.
            os_log("%s could not read stored events: %s", log: service.config.logger, type: .debug, typeName(and: #function), String(describing: error))
            completion(.blocked)
            return
        }

        guard let payload = read
        else {
            // Delivered by another process or store, or holding no events. Either way nothing is lost and there is
            // nothing to keep.
            store.remove(batch)
            deliver(remaining, run, lostAnything: lostAnything, retried: retried, completion)
            return
        }

        // Damage after the first frame: what came before it is sent, and the rest is gone with the file. Counted once
        // the batch is removed rather than now, since one kept for a retry is read, and found short, again.
        let leftOut = max(0, batch.eventCount - payload.eventCount)
        service.diagnosticCache?.recordEventsInLastBatch(eventsInLastBatch: payload.eventCount)
        post(batch, payload, run, leftOut: leftOut, remaining: remaining, lostAnything: lostAnything, retried: retried, completion)
    }

    /// Whether the delivery running may post: online, or `flushAtClose()`'s. Going offline stops a delivery before its
    /// next post, its retry's included, and leaves what it has not sent for a later one.
    private func mayPost(_ run: DeliveryRun) -> Bool {
        run.isClosing || isOnline
    }

    /// Posts a batch already read, then goes on to the rest. Requires the backoff to allow a post.
    // swiftlint:disable:next function_parameter_count
    private func post(_ batch: EventBatch,
                      _ payload: BatchPayload,
                      _ run: DeliveryRun,
                      leftOut: Int,
                      remaining: [EventBatch],
                      lostAnything: Bool,
                      retried: Bool,
                      _ completion: @escaping (PassOutcome) -> Void) {
        publish(batch, payload, run) { outcome in
            switch outcome {
            case .accepted:
                _ = self.countBadRequest(batch, statusCode: nil)
                guard leftOut > 0
                else {
                    self.deliver(remaining, run, lostAnything: lostAnything, retried: retried, completion)
                    return
                }
                os_log("%s dropped %d damaged stored event(s) from a batch it delivered", log: self.service.config.logger, type: .error, self.typeName(and: #function), leftOut)
                self.reportStoredEventsLost(leftOut)
                self.deliver(remaining, run, lostAnything: true, retried: retried, completion)
            case .failed(let failure):
                let wait = self.retryState.recordFailure(unexpected: failure.unexpected, retryAfter: failure.retryAfter)
                if self.countBadRequest(batch, statusCode: failure.statusCode) >= DirectEventProcessor.badRequestsBeforeDropping {
                    // The rest are still attempted, once the backoff allows.
                    os_log("%s dropping %d event(s) whose payload the service refused %d times in a row, last with HTTP %d", log: self.service.config.logger, type: .error, self.typeName(and: #function), batch.eventCount, DirectEventProcessor.badRequestsBeforeDropping, failure.statusCode ?? 0)
                    self.store.remove(batch)
                    self.reportBatchLost(batch)
                    self.reportSyncComplete(failure.error)
                    self.deliver(remaining, run, lostAnything: true, retried: retried, completion)
                    return
                }
                guard !retried, wait <= self.retryState.initialDelay
                else {
                    // Told once the pass gives the batch up, not for a failure its retry may still answer.
                    self.reportSyncComplete(failure.error)
                    self.scheduleDeliveryWhenWaitEnds()
                    completion(.blocked)
                    return
                }
                os_log("%s Retrying event post after %.1fs", log: self.service.config.logger, type: .debug, self.typeName(and: #function), wait)
                DispatchQueue.global().asyncAfter(deadline: .now() + wait) {
                    // Another delivery's failure may have set a longer wait meanwhile, or the reporter gone offline.
                    guard self.mayPost(run)
                    else {
                        self.reportSyncComplete(failure.error)
                        completion(.blocked)
                        return
                    }
                    guard self.retryState.remainingWait <= 0
                    else {
                        self.reportSyncComplete(failure.error)
                        self.scheduleDeliveryWhenWaitEnds()
                        completion(.blocked)
                        return
                    }
                    self.post(batch, payload, run, leftOut: leftOut, remaining: remaining, lostAnything: lostAnything, retried: true, completion)
                }
            }
        }
    }

    /// - Returns: how many refusals of the payload in a row this batch has had, counting this response; zero for any
    ///   other status, which ends the run, and once the batch is dropped.
    private func countBadRequest(_ batch: EventBatch, statusCode: Int?) -> Int {
        stateLock.withLock {
            guard let statusCode, HTTPURLResponse.StatusCodes.isEventPayloadRefused(statusCode)
            else {
                badRequests = nil
                return 0
            }
            var inARow = 1
            if let previous = badRequests, previous.payloadId == batch.payloadId {
                inARow = previous.inARow + 1
            }
            badRequests = inARow >= DirectEventProcessor.badRequestsBeforeDropping ? nil : (batch.payloadId, inARow)
            return inARow
        }
    }

    /// Sets a delivery for when the backoff's wait ends, unless one is set already, so a batch kept through a failure
    /// goes out then rather than at the next report interval after it.
    ///
    /// A delivery that fails again sets the next one, each a longer wait away, which is what keeps this from posting
    /// in a loop. Going offline leaves the one set to find nothing to do.
    private func scheduleDeliveryWhenWaitEnds() {
        let wait = retryState.remainingWait
        guard wait > 0
        else { return }
        guard deliveryScheduler.claimRetry()
        else { return }

        os_log("%s Will retry posting events in %.1fs after a failure", log: service.config.logger, type: .debug, typeName(and: #function), wait)
        DispatchQueue.global().asyncAfter(deadline: .now() + wait) { [weak self] in
            guard let self
            else { return }
            self.deliveryScheduler.retryDue()
            self.queueDelivery(nil)
        }
    }

    /// Sends one batch and acts on what LaunchDarkly made of it, before handing the outcome on.
    private func publish(_ batch: EventBatch,
                         _ payload: BatchPayload,
                         _ run: DeliveryRun,
                         _ completion: @escaping (AnalyticsEventSender.Outcome) -> Void) {
        store.startedSending(batch)
        // The store is settled before observers are told, so that one looking at it on hearing the outcome sees it.
        sender.send(payload.body, payloadId: batch.payloadId, eventCount: payload.eventCount) { outcome in
            run.postAnswered()
            switch outcome {
            case .accepted(let serverTime):
                self.retryState.recordSuccess()
                if let serverTime {
                    self.committer.recordResponseDate(serverTime)
                }
                self.store.remove(batch)
                self.store.stoppedSending(batch)
                self.reportSyncComplete(nil)
            case .failed:
                self.store.stoppedSending(batch)
                // Kept whatever the failure, a 401 included: a valid key is sometimes refused for minutes, and deleting
                // on a refusal would lose every event recorded meanwhile. A later delivery, in this run of the
                // application or the next one, sends it under the same payload ID, so LaunchDarkly can tell it is not
                // new.
                os_log("%s Keeping %d event(s) to retry later", log: self.service.config.logger, type: .debug, self.typeName(and: #function), batch.eventCount)
            }
            completion(outcome)
        }
    }

    private func reportSyncComplete(_ result: SynchronizingError?) {
        // The eventProcessor is created when the LDClient singleton is created, and kept for the app's lifetime. So while the use of self in the async block does setup a retain cycle, it's not going to cause a memory leak
        guard let onSyncComplete = onSyncComplete
        else { return }
        DispatchQueue.main.async {
            onSyncComplete(result)
        }
    }
}

extension DirectEventProcessor: TypeIdentifying { }

#if DEBUG
    extension DirectEventProcessor {
        /// Full events accepted but not yet handed to a commit.
        var pendingEventsForTesting: [Event] {
            committer.pendingEventsForTesting
        }

        func setLastEventResponseDate(_ date: Date) {
            committer.setLastEventResponseDate(date)
        }

        /// Occupies the queue a delivery runs on, so a test can see what one that has not started yet collects.
        func occupyQueue(until released: DispatchSemaphore) {
            deliveryQueue.async { _ = released.wait(timeout: .now() + 10) }
        }

        /// Callers waiting on the queued delivery.
        var queuedDeliveryWaiterCount: Int {
            deliveryScheduler.queuedWaiterCount
        }

        /// Deliveries started, counting one for a run of flushes that joined each other.
        var startedDeliveryCount: Int {
            deliveryScheduler.startedCount
        }

        /// As `EventCommitter.withContextSummarizer(_:)`.
        func withContextSummarizer<T>(_ read: (ContextSummarizer) -> T) -> T {
            committer.withContextSummarizer(read)
        }
    }
#endif
