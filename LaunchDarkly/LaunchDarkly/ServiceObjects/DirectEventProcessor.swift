import Foundation
import OSLog

/// Records analytics events and delivers them to LaunchDarkly.
///
/// Recorded events end up in an `EventStore`, an on-disk log, rather than held in memory until a delivery succeeds.
/// That is what lets an application that dies moments after recording an event still report it: the events are on disk
/// before the process is gone, and the next run of the application delivers them.
///
/// Recording an event summarizes it and, if it has to be delivered in full, holds it as an `Event`. Nothing is encoded
/// on the thread that recorded it; a commit turns the whole held run into bytes at once. So an evaluation of an
/// untracked flag costs a counter update, and an evaluation of a tracked one costs that plus an array append.
///
/// Where the line falls is between the events an application asked for by name and the ones it did not. Recording a
/// custom or identify event is a *commit point*, because an application reporting something it chose to report is
/// saying this matters more than the microseconds it costs, and the crash it describes may be moments away. A commit
/// takes the whole held run with it, so the exposures leading up to the error go down alongside it. Evaluations get no
/// such promise, and are committed once `pendingCommitThreshold` of them have accumulated, when a delivery starts, or
/// on `flush`.
///
/// Whether a commit point runs on the caller's thread is the application's choice, through
/// `LDConfig.eventPersistence`. Only at `.immediate` can `track` promise the event is on disk by the time it returns.
/// At `.disabled` nothing commits early: the held run waits for the delivery, which encodes it.
class DirectEventProcessor: EventProcessor {
    /// How many full events may be held unencoded before one of them pays for a commit.
    ///
    /// It sets two things at once. The first is how many evaluations a termination can take -- not everything a crash
    /// could take, since an application that flushes on its way out commits the whole run, but the window for the
    /// terminations that run nothing on the way out, such as the system reclaiming a backgrounded process. Recording a
    /// custom or identify event closes it too, because that commits.
    ///
    /// The second is the worst a commit point can cost, since it encodes whatever is held before returning. The common
    /// case is far below the bound, because the commit queue keeps the run drained; raising this trades that tail
    /// against the number of writes.
    ///
    /// It is the only thing that writes events no caller asked to have written. The store writes only when told to, so
    /// every staged byte reaches the disk through a commit that started here, at a commit point, or at a delivery.
    private static let pendingCommitThreshold = 32

    // MARK: Set in init and never changed

    let service: DarklyServiceProvider
    let store: EventStoring

    /// How many events the SDK will hold in total, across `pending` and the store.
    private let eventCapacity: Int

    /// Where a commit runs when no caller is waiting on it.
    private let commitQueue: DispatchQueue

    private let onSyncComplete: EventSyncCompleteClosure?

    private let sender: AnalyticsEventSender

    /// Its summarizer is guarded by `recordLock`, and its encoders are reached only under `commitLock`.
    let eventBuffer: OutboundEventBuffer

    // MARK: Guarded by commitLock

    /// Held for the whole of a commit, so that only one runs at a time.
    ///
    /// This is what a commit point's guarantee rests on. Without it a commit already in flight could take the caller's
    /// event out of `pending` before the caller got there, leaving the caller nothing to write and returning while
    /// those bytes were still being produced somewhere else. Waiting here instead means that when the call returns the
    /// event is on disk, whichever commit put it there. It also keeps two encoders from staging their runs in
    /// whichever order they happened to finish.
    ///
    /// Taken before `recordLock` and before anything the store locks, never after.
    private let commitLock = UnfairLock()

    // MARK: Guarded by recordLock

    /// Guards everything one recording writes: the held events and the summarizer.
    ///
    /// One evaluation can produce a counter, a full event and a debug event, and the three have to land together. Taken
    /// separately, a commit landing between them splits one evaluation across two payloads.
    ///
    /// Held for the appends and the handover of the run, never across the encoder or a syscall. It is a lock rather
    /// than a queue because it is taken once per evaluation, and a `DispatchQueue.sync` costs enough at that rate to be
    /// worth avoiding: the same measurement that made `EvaluationExposureDeduper` a lock applies here.
    private let recordLock = UnfairLock()

    /// Full events recorded but not yet encoded. Only to be used while holding `recordLock`.
    ///
    /// Held rather than encoded because encoding early would not make them durable: the store stages bytes into memory
    /// too, and only a commit reaches the file. Both forms are equally lost to a crash, so the encode may as well
    /// happen where it is cheapest.
    private var pending: [Event] = []

    /// Whether a commit is already queued, so a run of recordings past the threshold asks for one write rather than
    /// one each. Only to be used while holding `recordLock`.
    private var isCommitScheduled = false

    // MARK: Guarded by stateLock

    var lastEventResponseDate: Date {
        stateLock.withLock { responseDate }
    }

    /// Guards the last response date and the record of what has been lost.
    private let stateLock = UnfairLock()
    /// Only to be used while holding `stateLock`.
    private var responseDate: Date

    /// How many events the SDK accepted and then dropped for good. Only to be used while holding `stateLock`.
    ///
    /// A batch LaunchDarkly refuses in a way that may pass is kept and retried, so it is not a loss. What is lost is
    /// what the store never received: an event or a summary that could not be serialized when it was committed, or
    /// that serialized too large to store. A delivery that finds nothing to send cannot tell those apart from events
    /// that arrived, so without this it would report success for them.
    ///
    /// A count rather than a flag because deliveries overlap. Each takes the count as it closes its batch, and
    /// answers for the losses up to that mark, so a loss is told to the caller whose delivery it happened before
    /// rather than to whichever response arrived first.
    private var lostEvents: UInt64 = 0

    /// The mark up to which losses have already been reported to a caller, so that none is told twice. Only to be
    /// used while holding `stateLock`.
    private var reportedLostEvents: UInt64 = 0

    // MARK: Guarded by deliveryLock

    /// Guards `queuedDelivery`. Taken on a caller's thread and on `deliveryQueue`, and never held across either.
    private let deliveryLock = UnfairLock()
    /// Callers waiting on a delivery that is queued and has not taken the batches yet, or nil where none is queued.
    private var queuedDelivery: [FlushOutcomeClosure]?

    #if DEBUG
        /// How many deliveries have started, which is fewer than the flushes asked for where they were joined.
        private var deliveryRunCount = 0
    #endif

    // MARK: Guarded by claimLock

    /// Guards `batchesInFlight`.
    ///
    /// Its own lock rather than `stateLock`, which an evaluating thread takes to read `lastEventResponseDate`: a claim
    /// is made next to a listing of the store, and nothing a flag evaluation waits on may be held near the disk.
    private let claimLock = UnfairLock()

    /// The batches a delivery has taken and not yet had an answer for, by payload ID. Only to be used while holding
    /// `claimLock`.
    ///
    /// `deliveryQueue` serializes the *start* of a delivery but not the round trip it waits on, and a batch stays on
    /// disk until its response arrives. Without this, a delivery beginning inside that window would list the same batch
    /// again and send it a second time -- under the same payload ID, leaving it to LaunchDarkly to notice that two
    /// requests arriving at once are the same one.
    ///
    /// This bounds the overlap rather than preventing it, which is the point: a later delivery still runs, and still
    /// sends what it closed for itself. Only the batches already on their way are left out of it, and a caller waiting
    /// on that later delivery hears their outcome too.
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

    init(service: DarklyServiceProvider,
         onSyncComplete: EventSyncCompleteClosure?,
         store: EventStoring? = nil,
         encoding: OutboundEventBuffer.Encoding = .handWritten,
         commitQueue: DispatchQueue = DispatchQueue(label: "com.launchdarkly.DirectEventProcessor.commitQueue", qos: .userInitiated)) {
        self.service = service
        self.onSyncComplete = onSyncComplete
        self.sender = AnalyticsEventSender(service: service)
        self.responseDate = Date()
        self.eventCapacity = service.config.eventCapacity
        self.commitQueue = commitQueue
        self.eventBuffer = OutboundEventBuffer(config: service.config, encoding: encoding)
        self.store = store ?? DirectEventProcessor.makeStore(config: service.config)

        // A log left open by a previous run has to be closed before it can be delivered, but nothing waits on that:
        // doing it on the caller's thread would put file I/O in the way of the client starting up.
        let store = self.store
        deliveryQueue.async { [weak self] in
            store.recoverInterruptedLog()
            self?.reportDiscarded(store.discardExpired())
            self?.hasEventsFromPreviousRun = !store.pendingBatches().isEmpty
        }
    }

    private static func makeStore(config: LDConfig) -> EventStoring {
        let mobileKey = config.mobileKey
        return EventStore(locatingDirectory: { EventDirectory.defaultUrl(mobileKey: mobileKey) },
                          capacity: config.eventCapacity,
                          byteCapacity: config.eventCapacityBytes,
                          maxAge: config.eventMaxAge,
                          persistEvents: config.eventPersistence != .disabled,
                          logger: config.logger)
    }

    // MARK: Recording

    func record(_ event: Event) {
        let (dropped, needsCommit) = recordLock.withLock {
            (!admitToPending(event), pending.count >= DirectEventProcessor.pendingCommitThreshold)
        }

        if dropped {
            reportDropped()
        }
        if DirectEventProcessor.isCommitPoint(event.kind) {
            commitAtCommitPoint()
        } else if needsCommit {
            scheduleCommitWherePersisting()
        }
    }

    // swiftlint:disable:next function_parameter_count
    func recordFlagEvaluationEvents(flagKey: LDFlagKey,
                                    value: LDValue,
                                    defaultValue: LDValue,
                                    featureFlag: FeatureFlag?,
                                    context: LDContext,
                                    includeReason: Bool) {
        let recordingFeatureEvent = featureFlag?.trackEvents == true
        let recordingDebugEvent = featureFlag?.shouldCreateDebugEvents(lastEventReportResponseTime: lastEventResponseDate) ?? false
        // Built before the lock is taken, so that the critical section is only the writes.
        let featureEvent = recordingFeatureEvent ? FeatureEvent(key: flagKey, context: context, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason, isDebug: false) : nil
        let debugEvent = recordingDebugEvent ? FeatureEvent(key: flagKey, context: context, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason, isDebug: true) : nil

        var dropped = 0
        let (counted, needsCommit) = recordLock.withLock { () -> (Bool, Bool) in
            let counted = eventBuffer.summarize(flagKey: flagKey, reportedValue: value, featureFlag: featureFlag, defaultValue: defaultValue, context: context)
            if let featureEvent, !admitToPending(featureEvent) { dropped += 1 }
            if let debugEvent, !admitToPending(debugEvent) { dropped += 1 }
            return (counted, pending.count >= DirectEventProcessor.pendingCommitThreshold)
        }

        // A refused evaluation is a loss like a refused event, since nothing later reconstructs its counter. Its full
        // event is still decided by the event capacity alone.
        if !counted {
            service.diagnosticCache?.incrementDroppedEventCount()
        }
        for _ in 0..<dropped {
            reportDropped()
        }
        // Deliberately no commit point. An evaluation is expected to cost what bookkeeping costs, and it is usually the
        // main thread doing it; where events are persisted, the run is encoded and written on the commit queue once
        // enough of them have piled up, and the next event recorded at a commit point makes them durable along with
        // itself.
        if needsCommit {
            scheduleCommitWherePersisting()
        }
    }

    /// Adds an event to `pending` for the next commit to encode, returning false if the SDK is already full. Requires
    /// `recordLock`.
    ///
    /// Capacity is consulted before anything else, so an event that will not be kept is never encoded. That ordering is
    /// what bounds an application re-evaluating a tracked flag in a render loop: once the limit is reached an
    /// evaluation costs no more than its summary counter, however fast the loop runs.
    ///
    /// The byte capacity can only be consulted as far as whether any room is left, since the event has no size until
    /// it is encoded; whether it fits is decided when it is staged.
    private func admitToPending(_ event: Event) -> Bool {
        recordLock.assertOwned()
        guard pending.count + store.pendingEventCount < eventCapacity, store.hasRoomForEventBytes
        else { return false }

        pending.append(event)
        return true
    }

    private func reportDropped() {
        os_log("%s aborted. Event store is full", log: service.config.logger, type: .debug, typeName(and: #function))
        service.diagnosticCache?.incrementDroppedEventCount()
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

    /// Records the loss of an event the SDK accepted and then could not keep, which no later attempt recovers.
    private func reportLost() {
        os_log("%s dropping an event the store would not take", log: service.config.logger, type: .error, typeName(and: #function))
        service.diagnosticCache?.incrementDroppedEventCount()
        stateLock.withLock { lostEvents += 1 }
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

    /// Commits at a commit point, on the caller's thread or off it as the application asked.
    ///
    /// Committing on the caller's thread is what lets `track` promise its event is on disk by the time it returns.
    /// Scheduling it instead keeps the encode and the write off that thread, and the event is durable a moment later
    /// rather than immediately.
    private func commitAtCommitPoint() {
        if service.config.eventPersistence == .immediate {
            commitRecordedEvents()
        } else {
            scheduleCommitWherePersisting()
        }
    }

    /// Queues a commit where there is a disk for it to reach.
    ///
    /// Without persistence a commit makes nothing durable. All it would do is move the encode into the middle of the
    /// application's evaluations, where it competes with them for the CPU and splits their counters across summaries;
    /// left alone, the run waits for the delivery, which encodes it anyway, and capacity still bounds how much is held.
    private func scheduleCommitWherePersisting() {
        if store.isPersisting {
            scheduleCommit()
        }
    }

    /// Queues a commit unless one is already queued, so a run of recordings asks for one write rather than one each.
    private func scheduleCommit() {
        let alreadyScheduled = recordLock.withLock { () -> Bool in
            defer { isCommitScheduled = true }
            return isCommitScheduled
        }
        guard !alreadyScheduled
        else { return }

        commitQueue.async { [weak self] in
            guard let self
            else { return }
            // Cleared before the commit rather than after it, so that an event held while this one is in flight can ask
            // for another commit instead of finding one apparently already on its way.
            self.recordLock.withLock { self.isCommitScheduled = false }

            self.commitRecordedEvents()
        }
    }

    /// Encodes everything recorded since the last commit, stages it, and commits it.
    ///
    /// The run and the counters are taken in one critical section, so that an evaluation's counter and its full event
    /// are staged by the same commit, and encoded outside it, so recording does not wait on the encoder.
    func commitRecordedEvents() {
        commitLock.withLock { encodeAndCommitPending() }
    }

    /// Commits what is held and closes it into a batch, as one step with respect to other commits.
    ///
    /// Closing takes everything staged so far, and a commit stages its run one event at a time, so a commit running
    /// between the two would be closed partway: an evaluation's event in this batch and its summary in the next.
    ///
    /// - Returns: the loss count as of the close, which is the mark this delivery answers for. Taken under the same
    ///   lock, so it covers every loss the closed batch could have suffered and nothing a later commit suffers.
    private func commitAndCloseBatch() -> UInt64 {
        commitLock.withLock {
            encodeAndCommitPending()
            _ = store.closeBatch()
            return stateLock.withLock { lostEvents }
        }
    }

    /// Requires `commitLock`.
    private func encodeAndCommitPending() {
        commitLock.assertOwned()
        let (run, summaries) = recordLock.withLock { () -> ([Event], [(tracker: FlagRequestTracker, context: LDContext)]) in
            let run = pending
            pending = []
            let summaries = eventBuffer.takeSummaries()
            // Reserved in the same critical section the run leaves `pending` in, so capacity counts it in one place or
            // the other throughout the encode.
            store.reserve(run.count)
            return (run, summaries)
        }

        stage(run)
        store.releaseReservations()
        stageSummaries(summaries)
        store.commit()
    }

    /// Encodes the held events as one run and stages the bytes.
    ///
    /// Staging uses the reservation taken with the run rather than checking capacity, because the decision to keep
    /// these events was made when they were held, and refusing them here would drop events the SDK has already counted
    /// as accepted.
    ///
    /// Requires `commitLock`: two threads draining separate runs would stage them in whichever order they finished
    /// encoding, which is not the order they were recorded in.
    private func stage(_ run: [Event]) {
        commitLock.assertOwned()
        for event in run {
            guard let encoded = eventBuffer.encode(event)
            else {
                reportLost()
                continue
            }
            // The event capacity is bypassed here, so what is left is an event too large for a frame or for the bytes
            // left in the store, which were not known until now. Either way it was accepted and is not kept.
            if !store.stageReserved(encoded) {
                reportLost()
            }
        }
    }

    /// Whether recording this kind of event should encode and write the held run before it returns.
    ///
    /// Custom and identify events are recorded because the application did something it chose to report, which is both
    /// rare enough to afford a write and the moment it is least acceptable to lose. Evaluations are neither.
    private static func isCommitPoint(_ kind: Event.Kind) -> Bool {
        switch kind {
        case .custom, .identify: return true
        case .feature, .debug, .summary: return false
        }
    }

    /// Turns the counters taken with the run into summary events and stages them.
    ///
    /// Counters live only in memory, so a crash takes whatever has not been summarized with it. Summarizing at each
    /// commit point rather than only at a delivery is what bounds that loss, and it costs nothing in accuracy:
    /// LaunchDarkly sums the counters of every summary it receives, so a session that produced several summaries is
    /// counted the same as one that produced a single summary covering the same evaluations.
    private func stageSummaries(_ summaries: [(tracker: FlagRequestTracker, context: LDContext)]) {
        for summary in summaries {
            guard let encoded = eventBuffer.encodeSummary(summary)
            else {
                reportLost()
                continue
            }
            // Summaries are an aggregate of evaluations that were already counted, so refusing one for capacity would
            // lose evaluations the SDK promised to report rather than shed new load. Only the byte capacity refuses
            // one, once even the room held back for summaries is used up, since nothing else bounds how many are
            // staged while delivery keeps failing.
            if !store.stage(encoded, bypassingCapacity: true) {
                reportLost()
            }
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
        // wait out a report interval on top of that: an application that crashed reports it as soon as it is next able
        // to. Only the first time online brings a delivery forward, so going online again later, as a network comes and
        // goes, keeps to the ordinary cadence.
        deliveryQueue.async { [weak self] in
            guard let self, self.hasEventsFromPreviousRun
            else { return }
            self.hasEventsFromPreviousRun = false
            self.queueScheduledDelivery()
        }
    }

    private func stopReporting() {
        eventReportTimer?.cancel()
        eventReportTimer = nil
    }

    func flush(completion: CompletionClosure?) {
        // Nil stays nil, so a flush nobody waits on joins a queued delivery without adding to its waiters.
        commitThenQueueDelivery(completion.map { done in { _ in done() } })
    }

    func flushReportingOutcome(completion: @escaping FlushOutcomeClosure) {
        commitThenQueueDelivery(completion)
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

    /// Writes on the caller's thread at `.deferred` as well as at `.immediate`, unlike `track` and `identify`.
    ///
    /// A flush is what an application calls when it is about to end the process on purpose, and entering the background
    /// is when the system is most likely to end it; a write only queued is one the process may end before. Deferring is
    /// for the recordings an application makes all the time, which neither is. Where nothing persists, a commit makes
    /// nothing durable, and is left to the delivery.
    func commitWherePersisting() {
        if service.config.eventPersistence == .immediate || store.isPersisting {
            commitRecordedEvents()
        }
    }

    private func queueScheduledDelivery() {
        queueDelivery(nil)
    }

    /// Queues a delivery, or joins one that is queued and has not started.
    ///
    /// A delivery that has not started yet will send everything recorded before it starts, which includes this
    /// caller's events, so joining it is as good as queueing another. Without this, flushes arriving faster than a
    /// post completes each queue their own, and the one that matters -- the flush at shutdown -- waits behind all of
    /// them.
    ///
    /// A delivery that has already started is not joined. It has closed and taken its batches, so it cannot speak for
    /// anything recorded since, and holding later deliveries back until it answers would leave the store growing
    /// through a retry while nothing drained it.
    private func queueDelivery(_ completion: FlushOutcomeClosure?) {
        deliveryLock.lock()
        if queuedDelivery != nil {
            if let completion {
                queuedDelivery?.append(completion)
            }
            deliveryLock.unlock()
            return
        }
        queuedDelivery = completion.map { [$0] } ?? []
        deliveryLock.unlock()

        deliveryQueue.async { self.runDelivery() }
    }

    private func runDelivery() {
        // Requests arriving from here on need a delivery of their own: this one is about to close and take its
        // batches, and what it takes is all it can speak for.
        deliveryLock.lock()
        let waiters = queuedDelivery ?? []
        queuedDelivery = nil
        #if DEBUG
            deliveryRunCount += 1
        #endif
        deliveryLock.unlock()

        reportEvents { delivered, lossMark in
            guard !waiters.isEmpty
            else { return }
            // Taken once for the delivery rather than once per waiter, so that every caller joined to it hears about
            // a loss instead of only whichever happened to be answered first.
            let kept = !self.takeEventsLost(upTo: lossMark)
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

    private func reportEvents(completion: ((_ delivered: Bool, _ lossMark: UInt64) -> Void)?) {
        guard isOnline
        else {
            os_log("%s aborted. DirectEventProcessor is offline", log: service.config.logger, type: .debug, typeName(and: #function))
            reportSyncComplete(.isOffline)
            completion?(false, 0)
            return
        }

        let lossMark = commitAndCloseBatch()

        let (batches, waitingOn) = claimDeliverableBatches()
        // This delivery's own outcome, plus that of every batch another delivery is already sending. The caller's
        // events may be in either: a delivery that started after they were recorded closed them into its batch.
        let answer = DeliveryAnswer(outstanding: waitingOn.count + 1) { delivered in
            completion?(delivered, lossMark)
        }
        for claim in waitingOn {
            whenSettled(claim, answer.report)
        }

        guard !batches.isEmpty
        else {
            os_log("%s aborted. Event store is empty", log: service.config.logger, type: .debug, typeName(and: #function))
            reportSyncComplete(nil)
            answer.report(true)
            return
        }

        os_log("%s starting", log: service.config.logger, type: .debug, typeName(and: #function))
        deliver(batches) { [weak self] delivered in
            self?.releaseClaim(on: batches, delivered: delivered)
            answer.report(delivered)
        }
    }

    /// Takes the batches this delivery will send, leaving out any another delivery is still waiting on a response for.
    ///
    /// - Returns: the batches to send, and the claims on the ones left out. A batch left out may hold this caller's
    ///   events -- `commitRecordedEvents` only stages them, and whichever delivery runs next is what closes them into
    ///   a batch -- so the answer has to wait for those claims rather than assume they are someone else's business.
    private func claimDeliverableBatches() -> (deliverable: [EventBatch], waitingOn: [Claim]) {
        // Listed before the lock is taken, because listing reads the disk. Taking what appeared after it is the next
        // delivery's business; all this has to be atomic is deciding which of these batches are this delivery's.
        // Expired first, so that a batch too old to report is not sent.
        reportDiscarded(store.discardExpired())
        let pending = store.pendingBatches()
        return claimLock.withLock {
            var deliverable: [EventBatch] = []
            var waitingOn: [Claim] = []
            for batch in pending {
                if let claimed = batchesInFlight[batch.payloadId] {
                    waitingOn.append(claimed)
                } else {
                    batchesInFlight[batch.payloadId] = Claim()
                    deliverable.append(batch)
                }
            }
            return (deliverable, waitingOn)
        }
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

    private func deliver(_ batches: [EventBatch], _ completion: FlushOutcomeClosure?) {
        deliver(batches, lostAnything: false, completion)
    }

    /// Delivers batches oldest first, stopping at the first one that failed in a way worth retrying.
    ///
    /// Stopping matters: the batches that are left keep their place in the log, and a later delivery attempts them
    /// again rather than the SDK spending the rest of the session's requests on a service that is refusing them.
    ///
    /// `lostAnything` carries whether a batch already taken in this pass was lost for good, so that the caller hears
    /// about it even where the batches after it were accepted.
    private func deliver(_ batches: [EventBatch], lostAnything: Bool, _ completion: FlushOutcomeClosure?) {
        var remaining = batches
        guard !remaining.isEmpty
        else {
            completion?(!lostAnything)
            return
        }

        let batch = remaining.removeFirst()
        let read: Data?
        do {
            read = try store.body(of: batch)
        } catch is UnreadableBatch {
            // Lost like a refused batch: nothing will ever send it, so it is removed, the rest are still attempted, and
            // the caller hears that this pass lost events.
            os_log("%s dropping %d stored event(s) this version cannot read", log: service.config.logger, type: .error, typeName(and: #function), batch.eventCount)
            store.remove(batch)
            deliver(remaining, lostAnything: true, completion)
            return
        } catch {
            // Kept: the batch is still there, and a read that failed may not fail next time.
            os_log("%s could not read stored events: %s", log: service.config.logger, type: .debug, typeName(and: #function), String(describing: error))
            completion?(false)
            return
        }

        guard let body = read
        else {
            // Gone, which is usually another process having delivered it, or holding no events. Either way nothing is
            // lost and there is nothing to keep.
            store.remove(batch)
            deliver(remaining, lostAnything: lostAnything, completion)
            return
        }

        service.diagnosticCache?.recordEventsInLastBatch(eventsInLastBatch: batch.eventCount)
        publish(batch, body) { outcome in
            switch outcome {
            case .accepted:
                self.deliver(remaining, lostAnything: lostAnything, completion)
            case .refused:
                // The rest are still attempted, so that batches LaunchDarkly will never take do not sit on the device
                // for the rest of the session, taking up the room the capacity limit leaves for new events.
                self.deliver(remaining, lostAnything: true, completion)
            case .retryable:
                completion?(false)
            }
        }
    }

    /// Sends one batch and acts on what LaunchDarkly made of it, before handing the outcome on.
    private func publish(_ batch: EventBatch,
                         _ body: Data,
                         _ completion: @escaping (AnalyticsEventSender.Outcome) -> Void) {
        store.startedSending(batch)
        // The store is settled before observers are told, so that one looking at it on hearing the outcome sees it.
        sender.send(body, payloadId: batch.payloadId, eventCount: batch.eventCount) { outcome in
            switch outcome {
            case .accepted(let serverTime):
                self.stateLock.withLock {
                    if let serverTime = serverTime, serverTime > self.responseDate {
                        self.responseDate = serverTime
                    }
                }
                self.store.remove(batch)
                self.reportSyncComplete(nil)
            case .refused(let response):
                self.isOnline = false
                self.store.remove(batch)
                self.reportSyncComplete(.response(response))
            case .retryable(let error):
                self.store.stoppedSending(batch)
                self.reportSyncComplete(error)
                // The batch stays on disk. A later delivery, in this run of the application or the next one, sends it
                // under the same payload ID, so LaunchDarkly can tell it is not new.
                os_log("%s Keeping %d event(s) on disk to retry later", log: self.service.config.logger, type: .debug, self.typeName(and: #function), batch.eventCount)
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
            recordLock.withLock { pending }
        }

        func setLastEventResponseDate(_ date: Date) {
            stateLock.withLock { responseDate = date }
        }

        /// Occupies the queue a delivery runs on, so a test can see what one that has not started yet collects.
        func occupyQueue(until released: DispatchSemaphore) {
            deliveryQueue.async { _ = released.wait(timeout: .now() + 10) }
        }

        /// Callers waiting on the queued delivery.
        var queuedDeliveryWaiterCount: Int {
            deliveryLock.lock()
            defer { deliveryLock.unlock() }
            return queuedDelivery?.count ?? 0
        }

        /// Deliveries started, counting one for a run of flushes that joined each other.
        var startedDeliveryCount: Int {
            deliveryLock.lock()
            defer { deliveryLock.unlock() }
            return deliveryRunCount
        }

        /// Reads the summarizer under `recordLock`, which a scheduled commit may be holding to take its counters.
        func withContextSummarizer<T>(_ read: (ContextSummarizer) -> T) -> T {
            recordLock.withLock { read(eventBuffer.contextSummarizer) }
        }
    }
#endif
