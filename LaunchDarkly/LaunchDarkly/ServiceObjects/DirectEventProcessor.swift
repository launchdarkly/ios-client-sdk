import Foundation
import OSLog

/// Records analytics events and delivers them to LaunchDarkly.
///
/// Recorded events end up in an `EventStore`, an on-disk log, rather than held in memory until a delivery succeeds.
/// That is what lets an application that dies moments after recording an event still report it: the events are on disk
/// before the process is gone, and the next run of the application delivers them.
///
/// What the application records is accepted, held and committed to the store by `EventCommitter`, which says which
/// calls are commit points and which thread each commit runs on. This class decides when what is committed is
/// delivered, and `EventBatchDeliverer` sends it. This class also runs the reporter's life: flushes, going online and
/// offline, and the flush at close.
///
/// Flag values come first. What this reporter sends on its own waits at launch until `LDConfig.eventDeliveryDelay` after
/// it first goes online, and where events persist, the deliveries it starts on its own send one batch at a time, a gap
/// apart, leaving room for flag requests. Both go by time alone: nothing here hears what the flag synchronizer is doing.
/// A delivery the application asks for is never held.
class DirectEventProcessor: EventProcessor {
    /// How long the deliveries this reporter starts on its own wait, so that flag values come first.
    struct Pacing {
        /// The gap the specification gives, after the launch delay the application configured.
        static func specified(launchDelay: TimeInterval) -> Pacing {
            Pacing(launchDelay: launchDelay, gap: 1)
        }
        /// No waits at all, for tests about something else.
        static let noWaits = Pacing(launchDelay: 0, gap: 0)

        /// How long after first going online that a previous run's events, this run's periodic delivery, and the
        /// diagnostic init event wait. It gives the application's startup traffic, the first flag request among it, the
        /// network first, and is short enough for an application that dies a few seconds after every launch to still
        /// send them.
        let launchDelay: TimeInterval
        /// The least time between one paced batch's answer and the next batch's request.
        let gap: TimeInterval
    }

    /// How long `flushAtClose()` waits in all: first for its commit and the store's close, the last chance to get what
    /// was recorded to disk, as a batch, before the client goes away, then for the closing delivery with whatever is
    /// left. Waited for on a thread that for an application closing the client is usually the main one, and once per
    /// environment, so well inside what the system tolerates from a main thread that has stopped answering. Android's
    /// `close()` spends the same two seconds per environment on the same two steps.
    ///
    /// A request that has to open a connection first pays a DNS lookup and the TCP and TLS handshakes, about three
    /// round trips, which two seconds covers up to a round trip of about 600 ms. Whatever outlasts it is not cancelled.
    static let flushAtCloseBudget: TimeInterval = 2

    // MARK: Set in init and never changed

    let service: DarklyServiceProvider
    let store: EventStoring
    let committer: EventCommitter
    private let lostEvents: LostEventCount
    private let deliveryScheduler: EventDeliveryScheduler

    private let onSyncComplete: EventSyncCompleteClosure?

    /// Sends the batches each pass of a delivery lists.
    private let deliverer: EventBatchDeliverer

    private let pacing: Pacing

    /// `LDConfig.eventFlushInterval`, or its default where that is not a positive finite number. The
    /// report timer, the backoff and the read-failure spacing all take it: NaN would trap the timer and make the backoff
    /// wait for good, and nought would fire the timer ten thousand times a second and let three quick passes drop an
    /// intact batch.
    private let flushInterval: TimeInterval

    static func flushInterval(config: LDConfig) -> TimeInterval {
        let configured = config.eventFlushInterval
        return configured.isFinite && configured > 0 ? configured : LDConfig.Defaults.eventFlushInterval
    }

    var lastEventResponseDate: Date {
        committer.lastEventResponseDate
    }

    // MARK: Guarded by stateLock

    /// Guards which losses have been told to a caller.
    private let stateLock = UnfairLock()

    /// The mark up to which losses have already been reported to a caller, so that none is told twice. Only to be
    /// used while holding `stateLock`.
    private var reportedLostEvents: UInt64 = 0

    // MARK: Confined to timerQueue

    var isOnline: Bool {
        get { timerQueue.sync { online } }
        set { timerQueue.sync { newValue ? startReporting() : stopReporting() } }
    }

    private var timerQueue = DispatchQueue(label: "com.launchdarkly.DirectEventProcessor.timerQueue")
    private var online = false
    /// Started the first time the reporter goes online, and left running through going offline: cancelling it would
    /// restart the interval on every reconnect, and a run of brief outages would then hold events back for far longer
    /// than one interval. Only closing cancels it.
    private var eventReportTimer: TimeResponding?
    var isReportingActive: Bool { timerQueue.sync { eventReportTimer != nil } }

    // MARK: Confined to deliveryQueue

    /// Deliveries run here, off whatever thread recorded an event.
    private let deliveryQueue: DispatchQueue

    /// Whether the store held events from a previous run of the application when this reporter started, and no delivery
    /// has run since to send them.
    ///
    /// Only to be used on `deliveryQueue`, which is what makes it safe without a lock: the recovery that answers the
    /// question and the delivery that acts on it are both enqueued there, in that order.
    private var hasEventsFromPreviousRun = false

    /// Whether the launch gate has opened. It opens once the launch delay has passed since first going online. Until then
    /// neither a previous run's events, this run's periodic delivery, nor the diagnostic init event are sent. Open from
    /// the start where there is no launch delay.
    private var launchGateOpen: Bool
    /// When the reporter first went online, which the gate counts from.
    private var wentOnlineAt: DispatchTime?
    /// What waits for the gate to open with the reporter online.
    private var launchGateWaiters: [() -> Void] = []

    init(service: DarklyServiceProvider,
         onSyncComplete: EventSyncCompleteClosure?,
         store: EventStoring? = nil,
         encoding: OutboundEventBuffer.Encoding = .handWritten,
         commitQueue: DispatchQueue = DispatchQueue(label: "com.launchdarkly.DirectEventProcessor.commitQueue", qos: .userInitiated),
         retryState: DeliveryRetryState? = nil,
         pacing: Pacing? = nil) {
        let eventStore = store ?? DirectEventProcessor.makeStore(config: service.config)
        let lostEvents = LostEventCount()
        self.service = service
        self.onSyncComplete = onSyncComplete
        let flushInterval = DirectEventProcessor.flushInterval(config: service.config)
        self.flushInterval = flushInterval
        self.lostEvents = lostEvents
        let committer = EventCommitter(config: service.config, store: eventStore, encoding: encoding,
                                       commitQueue: commitQueue, diagnosticCache: service.diagnosticCache,
                                       lostEvents: lostEvents)
        self.committer = committer
        self.store = eventStore
        let deliveryQueue = DispatchQueue(label: "com.launchdarkly.eventSyncQueue", qos: .userInitiated)
        self.deliveryQueue = deliveryQueue
        self.deliverer = EventBatchDeliverer(service: service, store: eventStore, committer: committer,
                                             retryState: retryState ?? DeliveryRetryState(flushInterval: flushInterval),
                                             deliveryQueue: deliveryQueue)
        let pacing = pacing ?? .specified(launchDelay: service.config.eventDeliveryDelay)
        self.pacing = pacing
        self.deliveryScheduler = EventDeliveryScheduler(pacesDeliveries: eventStore.isPersisting, gap: pacing.gap)
        self.launchGateOpen = pacing.launchDelay <= 0
        deliverer.owner = self
    }

    /// Starts what the reporter does on its own: closing and listing what a previous run left, then discarding what has
    /// expired.
    ///
    /// Called once, straight after init and before anything else uses the reporter, as `ClientServiceFactory` does.
    /// `deliveryQueue` is suspended until the logs are closed and listed, and suspending holds back only what has not
    /// started: a delivery already running would list the store beside the recovery.
    func start() {
        // A log left open by a previous run has to be closed before it can be delivered, but nothing waits on that:
        // doing it on the caller's thread would put file I/O in the way of the client starting up. At utility, below
        // the flag requests, which matter more at launch than what a previous run left. Not as a block on
        // `deliveryQueue`, whose own userInitiated QoS a block cannot go below; the queue is suspended instead, so
        // everything enqueued on it meanwhile still runs after the recovery. Only where events persist, since memory
        // holds nothing from a previous run.
        guard store.isPersisting
        else { return }
        let store = self.store
        let queue = deliveryQueue
        let recovered = RecoveredListing()
        queue.suspend()
        queue.async { [weak self] in
            self?.reportVanished(recovered.vanishedEvents)
            self?.hasEventsFromPreviousRun = recovered.hasBatches
        }
        // Enforced, since the caller is usually the main thread, whose QoS would otherwise be carried over.
        DispatchQueue.global(qos: .utility).async(qos: .utility, flags: .enforceQoS) { [weak self] in
            do {
                // Resumed whatever happens: a dispatch queue released while suspended traps.
                defer { queue.resume() }
                store.preparePayloadsFromInterruptedLogs()
                let listing = store.listPendingBatches()
                recovered.vanishedEvents = listing.vanishedEvents
                recovered.hasBatches = !listing.batches.isEmpty
            }
            // After the resume, since no delivery needs it first: each one discards what has expired before it lists,
            // and a batch discarded here while a delivery reads it is found removed in this process, not lost. Still at
            // launch rather than left to the first delivery, which never comes while offline, so that expired batches
            // stop counting against capacity. The first call also empties the directories of abandoned environments,
            // which is no reason to hold back a delivery.
            self?.reportDiscarded(store.discardExpired())
        }
    }

    /// What the recovery found, handed to `deliveryQueue`. Written before the queue resumes and read after, so the
    /// resume orders the two. Listed before expiry, so it can count batches the delivery it starts finds expired.
    private final class RecoveredListing {
        var vanishedEvents = 0
        var hasBatches = false
    }

    static func makeStore(config: LDConfig) -> EventStoring {
        let mobileKey = config.mobileKey
        return EventStore(locatingDirectory: { EventDirectory.defaultUrl(environmentName: Util.hashedStorageName(mobileKey: mobileKey)) },
                          capacity: config.eventCapacity,
                          byteCapacity: config.eventCapacityBytes,
                          maxAge: config.eventMaxAge,
                          persistEvents: config.eventPersistence != .disabled,
                          logger: config.logger)
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
        service.diagnosticCache?.incrementDroppedEventCount(by: events)
    }

    /// Records stored events lost for good. The pass that lost them tells its caller, but a delivery nobody waits on --
    /// the periodic one, a `flush()`, the one going online starts -- has no one to tell, so the loss is also counted for
    /// the next `flushReportingOutcome` to hear about. A caller waiting on this pass can then hear about it from the
    /// next one too.
    func reportStoredEventsLost(_ events: Int) {
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
        guard !online
        else { return }
        online = true
        if eventReportTimer == nil {
            eventReportTimer = LDTimer(withTimeInterval: flushInterval, fireQueue: deliveryQueue) { [weak self] in
                self?.reportIntervalEnded()
            }
        }

        // Events a previous run left behind are already late by however long the application was gone, so they do not
        // wait out a report interval on top of that, only the launch gate: an application that crashed reports it as
        // soon as it is next able to. Going online again later, as a network comes and goes, keeps to the ordinary
        // cadence, unless a post failed in a way the network coming back may cure: that delivery goes now, rather than
        // after the rest of a wait set while the network was gone, or at the next report interval.
        deliveryQueue.async { [weak self] in
            guard let self
            else { return }
            if self.wentOnlineAt == nil {
                self.wentOnlineAt = .now()
                if !self.launchGateOpen {
                    self.checkLaunchGate(after: self.pacing.launchDelay)
                }
            }
            self.releaseLaunchGateWaiters()
            if self.deliverer.endOrdinaryWait() && self.launchGateOpen {
                self.queueScheduledDelivery()
            }
            self.deliverWhatAPreviousRunLeft()
        }
    }

    private func stopReporting() {
        online = false
        deliveryScheduler.endPacing()
    }

    private func cancelReportTimer() {
        timerQueue.sync {
            eventReportTimer?.cancel()
            eventReportTimer = nil
        }
    }

    /// Runs `block`, on a global queue, once the launch gate is open and the reporter is online. Offline, including once
    /// closed, it waits for the reporter to go online.
    func whenLaunchGateOpens(_ block: @escaping () -> Void) {
        deliveryQueue.async { [weak self] in
            guard let self
            else { return }
            self.launchGateWaiters.append(block)
            self.releaseLaunchGateWaiters()
        }
    }

    /// On `deliveryQueue`.
    private func releaseLaunchGateWaiters() {
        guard launchGateOpen, !launchGateWaiters.isEmpty, isOnline
        else { return }
        let waiters = launchGateWaiters
        launchGateWaiters = []
        waiters.forEach { DispatchQueue.global(qos: .userInitiated).async(execute: $0) }
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
        releaseLaunchGateWaiters()

        deliverWhatAPreviousRunLeft()
    }

    /// Queues the delivery that sends what a previous run left, once the gate is open with the reporter online. Offline,
    /// it waits for the reporter to go online, which calls this again. Does nothing where a delivery has already run
    /// online, since that sent the oldest batches first. The flag is left to that delivery to clear, so going offline
    /// before it starts leaves them for the next time online. On `deliveryQueue`.
    private func deliverWhatAPreviousRunLeft() {
        guard launchGateOpen, hasEventsFromPreviousRun, isOnline
        else { return }

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

    func flushBypassingBackoff(completion: @escaping FlushOutcomeClosure) {
        committer.queueCommitWherePersisting()
        queueDelivery(completion, bypassingBackoff: true)
    }

    func flushAtClose() {
        committer.refuseRecordings()
        cancelReportTimer()
        let budget = DirectEventProcessor.flushAtCloseBudget
        let deadline = DispatchTime.now() + budget
        committer.commitAndClose(by: deadline, budget: budget)
        // Offline, it is an ordinary delivery, which finds the reporter offline and sends nothing, so there is nothing
        // to wait for: offline is the application keeping the SDK off the network, and closing does not revoke that.
        guard isOnline
        else {
            queueDelivery(nil)
            return
        }
        // Waited for, as this run's last chance to send what it recorded, which where nothing persists is gone with
        // the process. Where events persist it only sends: the store is closed, so it writes and closes nothing. It
        // starts once a delivery already running ends, and waiting for that comes out of the same budget.
        let answered = DispatchSemaphore(value: 0)
        queueDelivery({ _ in answered.signal() }, closing: true)
        if answered.wait(timeout: deadline) == .timedOut {
            os_log("%s gave up waiting for the final event delivery after %dms; it continues in the background", log: service.config.logger, type: .info, typeName(and: #function), Int(budget * 1000))
        }
    }

    /// Queues a delivery the way a caller asking for one expects, which is as a commit point.
    ///
    /// Wherever events persist, everything accepted before the call is on disk by the time it returns, even where the
    /// delivery itself cannot run because the client is offline. What it does not do is close those events into a
    /// batch: only a delivery does that, and the one this queues, or the queued one it joins, is the next to start and
    /// so the one that will.
    private func commitThenQueueDelivery(_ completion: FlushOutcomeClosure?) {
        commitWherePersisting()
        queueDelivery(completion)
    }

    /// The report timer's delivery, on `deliveryQueue`. Until the launch gate opens it only commits: a delivery sends the
    /// oldest batches first, which are what a previous run left, so one now would send them ahead of the gate. What this
    /// run recorded goes with the first delivery after the gate opens. Offline it only commits too, and what it committed
    /// goes with the first delivery after the reporter is back online.
    private func reportIntervalEnded() {
        guard launchGateOpen, isOnline
        else {
            committer.queueCommitWherePersisting()
            return
        }
        queueScheduledDelivery()
    }

    /// Queues the delivery the report timer, the launch gate and the end of a backoff's wait start, which nobody asked
    /// for now and which is paced. Unpaced, it would also end the pacing of the delivery running.
    private func queueScheduledDelivery() {
        queueDelivery(nil, paced: true)
    }

    /// As `EventDeliveryScheduler.queue(_:closing:bypassingBackoff:paced:)`, starting the delivery where nothing is
    /// running.
    private func queueDelivery(_ completion: FlushOutcomeClosure?,
                               closing: Bool = false,
                               bypassingBackoff: Bool = false,
                               paced: Bool = false) {
        if deliveryScheduler.queue(completion, closing: closing, bypassingBackoff: bypassingBackoff, paced: paced) {
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
            // Answered away from `deliveryQueue`, where every delivery ends. A completion is free to flush again: it is
            // never running on the queue the delivery it asks for would be queued on.
            DispatchQueue.global(qos: .userInitiated).async {
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
    private func reportEvents(_ run: EventDeliveryRun, completion: ((_ delivered: Bool, _ lossMark: UInt64) -> Void)?) {
        guard run.isClosing || isOnline
        else {
            os_log("%s aborted. DirectEventProcessor is offline", log: service.config.logger, type: .debug, typeName(and: #function))
            reportSyncComplete(.isOffline)
            completion?(false, 0)
            return
        }
        // This delivery sends the oldest batches first, which are what a previous run left.
        if hasEventsFromPreviousRun {
            hasEventsFromPreviousRun = false
            let sinceOnline = wentOnlineAt.map { Int((DispatchTime.now().uptimeNanoseconds - $0.uptimeNanoseconds) / 1_000_000) } ?? 0
            os_log("%s Delivering events a previous run left, %dms after first going online", log: service.config.logger, type: .debug, typeName(and: #function), sinceOnline)
        }

        // The batches already waiting go first, and what has been committed since is closed into a batch of its own
        // only once none of them is left blocked. Closing first would add a batch for every pass a failure lasts: every
        // flush, periodic delivery and trip to the background of an outage would leave one more file, or one more batch
        // held in memory, each with the summary its commit staged. Held back, what is committed meanwhile goes on into
        // the open log, which closes once it is full or once the batches ahead of it are gone, so an outage costs a
        // batch per `EventLogFormat.maxBatchSize` rather than one per pass.
        let waiting = listDeliverableBatches(discardingExpired: true)
        deliverer.deliver(waiting, run) { waitingOutcome in
            guard waitingOutcome != .blocked
            else {
                // Committed all the same, since a delivery is a commit point. Nothing was closed, so the caller's events
                // did not go, and the mark is as of this commit, the last point anything the caller recorded was staged.
                let lossMark = self.committer.commitLeavingTheLogOpen()
                os_log("%s will report failure: an earlier batch could not be delivered", log: self.service.config.logger, type: .debug, self.typeName(and: #function))
                completion?(false, lossMark)
                return
            }

            let (lossMark, closedEverything) = self.committer.commitAndCloseBatch()
            let new = self.listDeliverableBatches(discardingExpired: false)
            // Events left in a log that would not close, or in a batch a listing that failed could not see, are still on
            // the disk for a later delivery. This one delivers what it has, and cannot say the caller's events got out.
            let accountsForEverything = closedEverything && waiting.isComplete && new.isComplete
            if !accountsForEverything {
                os_log("%s will report failure: %s", log: self.service.config.logger, type: .debug, self.typeName(and: #function),
                       closedEverything ? "the stored events could not be listed" : "the event log could not be closed")
            }
            if waiting.batches.isEmpty && new.batches.isEmpty {
                os_log("%s aborted. Event store is empty", log: self.service.config.logger, type: .debug, self.typeName(and: #function))
                self.reportSyncComplete(nil)
            }

            self.deliverer.deliver(new, run) { newOutcome in
                completion?(max(waitingOutcome, newOutcome) == .delivered && accountsForEverything, lossMark)
            }
        }
    }

    /// Lists the batches this delivery will send.
    ///
    /// A batch stays on disk until its response arrives, so a delivery listing beside another would send it twice.
    /// `EventDeliveryScheduler` runs deliveries one at a time, and each ends its passes before the next lists.
    ///
    /// - Parameter discardingExpired: whether to discard what is too old to report first, which a second pass moments
    ///   after the first has no need to do again.
    private func listDeliverableBatches(discardingExpired: Bool) -> BatchListing {
        // Expired first, so that a batch too old to report is not sent.
        if discardingExpired {
            reportDiscarded(store.discardExpired())
        }
        let listing = store.listPendingBatches()
        reportVanished(listing.vanishedEvents)
        return listing
    }

    /// Counts as lost the events of batches that left the directory without being sent: the store counted them on disk,
    /// and a listing no longer finds them, though no store in this process removed them and no other process shares the
    /// directory. tvOS purging a cache directory is one way it happens.
    private func reportVanished(_ events: Int) {
        guard events > 0
        else { return }
        os_log("%s %d stored event(s) were deleted before they could be sent", log: service.config.logger, type: .error, typeName(and: #function), events)
        reportStoredEventsLost(events)
    }

    /// Sets a delivery for when the backoff's wait ends, unless one is set already, so a batch kept through a failure
    /// goes out then rather than at the next report interval after it.
    ///
    /// A delivery that fails again sets the next one, each a longer wait away, which is what keeps this from posting
    /// in a loop. Going offline leaves the one set to find nothing to do.
    func deliverWhenWaitEnds(in wait: TimeInterval) {
        guard deliveryScheduler.claimRetry()
        else { return }

        os_log("%s Will retry posting events in %.1fs after a failure", log: service.config.logger, type: .debug, typeName(and: #function), wait)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + wait) { [weak self] in
            guard let self
            else { return }
            self.deliveryScheduler.retryDue()
            self.queueScheduledDelivery()
        }
    }

    func reportSyncComplete(_ result: SynchronizingError?) {
        // The eventProcessor is created when the LDClient singleton is created, and kept for the app's lifetime. So while the use of self in the async block does setup a retain cycle, it's not going to cause a memory leak
        guard let onSyncComplete = onSyncComplete
        else { return }
        DispatchQueue.main.async {
            onSyncComplete(result)
        }
    }
}

extension DirectEventProcessor: TypeIdentifying { }

extension DirectEventProcessor: EventBatchDelivererOwner { }

#if DEBUG
extension DirectEventProcessor {
    /// Full events accepted but not yet handed to a commit.
    var pendingEventsForTesting: [Event] {
        committer.pendingEventsForTesting
    }

    func setLastEventResponseDate(_ date: Date) {
        committer.setLastEventResponseDate(date)
    }

    /// As `EventBatchDeliverer.readFailureSpacing`.
    var readFailureSpacing: TimeInterval {
        get { deliverer.readFailureSpacing }
        set { deliverer.readFailureSpacing = newValue }
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
