import Foundation
import OSLog

typealias EventSyncCompleteClosure = ((SynchronizingError?) -> Void)
/// Reports whether LaunchDarkly accepted every event a flush covered.
typealias FlushOutcomeClosure = (Bool) -> Void
// sourcery: autoMockable
protocol EventReporting {
    // sourcery: defaultMockValue = false
    var isOnline: Bool { get set }
    // sourcery: defaultMockValue = Date.distantPast
    var lastEventResponseDate: Date { get }

    func record(_ event: Event)
    // swiftlint:disable:next function_parameter_count
    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: LDValue, defaultValue: LDValue, featureFlag: FeatureFlag?, context: LDContext, includeReason: Bool)
    func flush(completion: CompletionClosure?)

    /// Like `flush`. Reports `true` if LaunchDarkly accepted the pending batches, or there were none to send. Reports
    /// `false` if the reporter is offline, a batch was refused for good, a retryable failure left batches on disk, or
    /// an event the SDK had accepted could not be kept to send at all.
    ///
    /// The completion runs on the reporter's delivery queue. Keep it short: a long one holds up the deliveries behind
    /// it, though it cannot block an evaluation, which records under a lock rather than on that queue.
    func flushReportingOutcome(completion: @escaping FlushOutcomeClosure)

    /// Makes everything recorded so far outlive the process, without waiting for a delivery.
    ///
    /// The SDK does this itself at the points where an application is most likely to be about to die. It is worth
    /// calling directly before deliberately terminating the process.
    func commitRecordedEvents()

    /// Commits as a commit point does: before returning at `.immediate`, on a background queue at `.deferred`, and not
    /// at all where nothing is persisted, where a commit would only move the encode earlier.
    func commitAtCommitPoint()
}

class NullEventReporter: EventReporting {
    var isOnline: Bool = true
    var lastEventResponseDate: Date = Date()

    func record(_ event: Event) {
    }

    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: LDValue, defaultValue: LDValue, featureFlag: FeatureFlag?, context: LDContext, includeReason: Bool) {
    }

    func flush(completion: CompletionClosure?) {
        completion?()
    }

    func flushReportingOutcome(completion: @escaping FlushOutcomeClosure) {
        completion(true)
    }

    func commitRecordedEvents() {
    }

    func commitAtCommitPoint() {
    }
}

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
class EventReporter: EventReporting {
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
    private static let pendingCommitThreshold = 32

    var isOnline: Bool {
        get { timerQueue.sync { eventReportTimer != nil } }
        set { timerQueue.sync { newValue ? startReporting() : stopReporting() } }
    }

    var lastEventResponseDate: Date {
        stateLock.lock()
        defer { stateLock.unlock() }
        return responseDate
    }

    let service: DarklyServiceProvider
    let store: EventStoring

    /// Guards the last response date and the record of what has been lost.
    private let stateLock = UnfairLock()
    /// Only to be used while holding `pendingLock`.
    private(set) var contextSummarizer: ContextSummarizer
    /// Only to be used while holding `stateLock`.
    private var responseDate: Date

    /// Whether events the SDK accepted were dropped for good, cleared once a caller who hears an outcome has been
    /// told so. Only to be used while holding `stateLock`.
    ///
    /// A batch LaunchDarkly refuses in a way that may pass is kept and retried, so it is not a loss. What is lost is
    /// what the store never received: an event or a summary that could not be serialized when it was committed, or
    /// that serialized too large to store. A delivery that finds nothing to send cannot tell those apart from events
    /// that arrived, so without this it would report success for them.
    private var eventsLostSinceLastAnswer = false

    /// Held for the whole of a commit, so that only one runs at a time.
    ///
    /// This is what a commit point's guarantee rests on. Without it a commit already in flight could take the caller's
    /// event out of `pending` before the caller got there, leaving the caller nothing to write and returning while
    /// those bytes were still being produced somewhere else. Waiting here instead means that when the call returns the
    /// event is on disk, whichever commit put it there. It also keeps two encoders from staging their runs in
    /// whichever order they happened to finish.
    ///
    /// Taken before `pendingLock` and before anything the store locks, never after.
    private let commitLock = UnfairLock()

    /// Guards everything one recording writes: the held events and the summarizer.
    ///
    /// One evaluation can produce a counter, a full event and a debug event, and the three have to land together. Taken
    /// separately, a commit landing between them splits one evaluation across two payloads.
    ///
    /// Held for the appends and the handover of the run, never across the encoder or a syscall. It is a lock rather
    /// than a queue because it is taken once per evaluation, and a `DispatchQueue.sync` costs enough at that rate to be
    /// worth avoiding: the same measurement that made `EvaluationExposureDeduper` a lock applies here.
    private let pendingLock = UnfairLock()

    /// Full events recorded but not yet encoded. Only to be used while holding `pendingLock`.
    ///
    /// Held rather than encoded because encoding early would not make them durable: the store stages bytes into memory
    /// too, and only a commit reaches the file. Both forms are equally lost to a crash, so the encode may as well
    /// happen where it is cheapest.
    private var pending: [Event] = []

    /// Whether a commit is already queued, so a run of recordings past the threshold asks for one write rather than
    /// one each. Only to be used while holding `pendingLock`.
    private var isCommitScheduled = false

    /// How many events the SDK will hold in total, across `pending` and the store.
    private let capacity: Int

    /// Where a commit runs when no caller is waiting on it.
    private let commitQueue: DispatchQueue

    private var timerQueue = DispatchQueue(label: "com.launchdarkly.EventReporter.timerQueue")
    private var eventReportTimer: TimeResponding?
    var isReportingActive: Bool { eventReportTimer != nil }

    /// Deliveries run here, off whatever thread recorded an event.
    private let deliveryQueue = DispatchQueue(label: "com.launchdarkly.eventSyncQueue", qos: .userInitiated)

    /// Whether the store held events from a previous run of the application when this reporter started.
    ///
    /// Only to be used on `deliveryQueue`, which is what makes it safe without a lock: the recovery that answers the
    /// question and the delivery that acts on it are both enqueued there, in that order.
    private var hasEventsFromPreviousRun = false

    /// Whether a delivery is running, from the request being sent until its response has been handled.
    ///
    /// `deliveryQueue` serializes the *start* of a delivery but not the round trip it waits on, and a batch stays on
    /// disk until its response arrives. Without this, a delivery beginning inside that window would list the same batch
    /// again and send it a second time -- under the same payload ID, leaving it to LaunchDarkly to notice that two
    /// requests arriving at once are the same one.
    ///
    /// Only to be used on `deliveryQueue`, like the two below.
    private var isDelivering = false

    /// A flush requested while a delivery was running, run once that delivery finishes. Later requests join it rather
    /// than queueing another.
    private var hasPendingFlush = false

    /// Callers answered by the pending flush.
    private var pendingFlushCompletions: [FlushOutcomeClosure] = []

    private let onSyncComplete: EventSyncCompleteClosure?

    /// Shared by the threads recording events, so it must not be mutated after `init`.
    private let encoder: JSONEncoder

    let encoding: Encoding
    /// Outlives a commit rather than being built per commit, so that its buffer and context cache span them.
    ///
    /// A commit point writes a single event, so a cache that lived for one commit would never be read. It needs no
    /// lock of its own because it is only ever reached from `encode(_:)`, which runs under `commitLock`.
    fileprivate let eventJSONWriter: EventJSONWriter

    init(service: DarklyServiceProvider,
         onSyncComplete: EventSyncCompleteClosure?,
         store: EventStoring? = nil,
         encoding: Encoding = .handWritten,
         commitQueue: DispatchQueue = DispatchQueue(label: "com.launchdarkly.EventReporter.commitQueue", qos: .userInitiated)) {
        self.eventJSONWriter = EventJSONWriter(config: service.config)
        self.service = service
        self.onSyncComplete = onSyncComplete
        self.responseDate = Date()
        self.encoding = encoding
        self.capacity = service.config.eventCapacity
        self.commitQueue = commitQueue
        self.encoder = EventReporter.makeEncoder(config: service.config)
        self.contextSummarizer = ContextSummarizer(logger: service.config.logger, maxContexts: service.config.eventCapacity)
        self.store = store ?? EventReporter.makeStore(config: service.config)

        // A log left open by a previous run has to be closed before it can be delivered, but nothing waits on that:
        // doing it on the caller's thread would put file I/O in the way of the client starting up.
        let store = self.store
        deliveryQueue.async { [weak self] in
            store.recoverInterruptedLog()
            self?.hasEventsFromPreviousRun = !store.pendingBatches().isEmpty
        }
    }

    private static func makeStore(config: LDConfig) -> EventStoring {
        guard let directory = EventStore.defaultDirectory(mobileKey: config.mobileKey)
        else {
            os_log("Events cannot be persisted: no writable directory was available", log: config.logger, type: .debug)
            return NullEventStore()
        }
        return EventStore(directory: directory,
                          capacity: config.eventCapacity,
                          persistEvents: config.eventPersistence != .disabled,
                          logger: config.logger)
    }

    // MARK: Recording

    func record(_ event: Event) {
        pendingLock.lock()
        let dropped = !holdHoldingPendingLock(event)
        let needsCommit = pending.count >= EventReporter.pendingCommitThreshold
        pendingLock.unlock()

        if dropped {
            reportDropped()
        }
        if EventReporter.isCommitPoint(event.kind) {
            commitAtCommitPoint()
        } else if needsCommit {
            scheduleCommitWherePersisting()
        }
    }

    // swiftlint:disable:next function_parameter_count
    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: LDValue, defaultValue: LDValue, featureFlag: FeatureFlag?, context: LDContext, includeReason: Bool) {
        let recordingFeatureEvent = featureFlag?.trackEvents == true
        let recordingDebugEvent = featureFlag?.shouldCreateDebugEvents(lastEventReportResponseTime: lastEventResponseDate) ?? false
        // Built before the lock is taken, so that the critical section is only the writes.
        let featureEvent = recordingFeatureEvent ? FeatureEvent(key: flagKey, context: context, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason, isDebug: false) : nil
        let debugEvent = recordingDebugEvent ? FeatureEvent(key: flagKey, context: context, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason, isDebug: true) : nil

        var dropped = 0
        pendingLock.lock()
        let counted = contextSummarizer.trackRequest(flagKey: flagKey, reportedValue: value, featureFlag: featureFlag, defaultValue: defaultValue, context: context)
        for event in [featureEvent, debugEvent].compactMap({ $0 }) where !holdHoldingPendingLock(event) {
            dropped += 1
        }
        let needsCommit = pending.count >= EventReporter.pendingCommitThreshold
        pendingLock.unlock()

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

    /// Holds an event for the next commit to encode, returning false if the SDK is already full. Requires `pendingLock`.
    ///
    /// Capacity is consulted before anything else, so an event that will not be kept is never encoded. That ordering is
    /// what bounds an application re-evaluating a tracked flag in a render loop: once the limit is reached an
    /// evaluation costs no more than its summary counter, however fast the loop runs.
    private func holdHoldingPendingLock(_ event: Event) -> Bool {
        guard pending.count + store.pendingEventCount < capacity
        else { return false }

        pending.append(event)
        return true
    }

    private func reportDropped() {
        os_log("%s aborted. Event store is full", log: service.config.logger, type: .debug, typeName(and: #function))
        service.diagnosticCache?.incrementDroppedEventCount()
    }

    /// Records the loss of an event the SDK accepted and then could not keep, which no later attempt recovers.
    private func reportLost() {
        os_log("%s dropping an event the store would not take", log: service.config.logger, type: .error, typeName(and: #function))
        service.diagnosticCache?.incrementDroppedEventCount()
        stateLock.lock()
        eventsLostSinceLastAnswer = true
        stateLock.unlock()
    }

    /// Whether anything has been lost since the last caller was told, which that caller is now the one to hear about.
    private func takeEventsLost() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        let lost = eventsLostSinceLastAnswer
        eventsLostSinceLastAnswer = false
        return lost
    }

    /// Commits at a commit point, on the caller's thread or off it as the application asked.
    ///
    /// Committing on the caller's thread is what lets `track` promise its event is on disk by the time it returns.
    /// Scheduling it instead keeps the encode and the write off that thread, and the event is durable a moment later
    /// rather than immediately.
    func commitAtCommitPoint() {
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
        pendingLock.lock()
        guard !isCommitScheduled
        else {
            pendingLock.unlock()
            return
        }
        isCommitScheduled = true
        pendingLock.unlock()

        commitQueue.async { [weak self] in
            guard let self
            else { return }
            // Cleared before the commit rather than after it, so that an event held while this one is in flight can ask
            // for another commit instead of finding one apparently already on its way.
            self.pendingLock.lock()
            self.isCommitScheduled = false
            self.pendingLock.unlock()

            self.commitRecordedEvents()
        }
    }

    /// Encodes everything recorded since the last commit, stages it, and commits it.
    ///
    /// The run and the counters are taken in one critical section, so that an evaluation's counter and its full event
    /// are staged by the same commit, and encoded outside it, so recording does not wait on the encoder.
    func commitRecordedEvents() {
        commitLock.lock()
        defer { commitLock.unlock() }
        commitRecordedEventsHoldingCommitLock()
    }

    /// Commits what is held and closes it into a batch, as one step with respect to other commits.
    ///
    /// Closing takes everything staged so far, and a commit stages its run one event at a time, so a commit running
    /// between the two would be closed partway: an evaluation's event in this batch and its summary in the next.
    private func commitAndCloseBatch() {
        commitLock.lock()
        defer { commitLock.unlock() }
        commitRecordedEventsHoldingCommitLock()
        _ = store.closeBatch()
    }

    private func commitRecordedEventsHoldingCommitLock() {
        pendingLock.lock()
        let run = pending
        pending = []
        let summaries = contextSummarizer.hasLoggedRequests ? contextSummarizer.getSummaries() : []
        if !summaries.isEmpty {
            contextSummarizer.clear()
        }
        // Reserved in the same critical section the run leaves `pending` in, so capacity counts it in one place or the
        // other throughout the encode.
        store.reserve(run.count)
        pendingLock.unlock()

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
        for event in run {
            guard let encoded = encode(event)
            else {
                reportLost()
                continue
            }
            // Capacity is bypassed here, so what is left is a frame too large to store, which no later attempt fixes.
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
            let summaryEvent = SummaryEvent(flagRequestTracker: summary.tracker, context: summary.context)
            guard let encoded = encode(summaryEvent)
            else {
                reportLost()
                continue
            }
            // Summaries are an aggregate of evaluations that were already counted, so refusing one for capacity would
            // lose evaluations the SDK promised to report rather than shed new load.
            if !store.stage(encoded, bypassingCapacity: true) {
                reportLost()
            }
        }
    }

    private func encode(_ event: Event) -> Data? {
        let encoded: Data? = encoding == .codable ? try? encoder.encode(event) : eventJSONWriter.encode(event)
        guard let encoded = encoded
        else {
            os_log("%s Failed to serialize event for publication: %s", log: service.config.logger, type: .error, typeName(and: #function), String(describing: event))
            return nil
        }
        return encoded
    }

    // MARK: Reporting

    private func startReporting() {
        guard eventReportTimer == nil
        else { return }
        eventReportTimer = LDTimer(withTimeInterval: service.config.eventFlushInterval, fireQueue: deliveryQueue, execute: reportEvents)

        // Events a previous run left behind are already late by however long the application was gone, so they do not
        // wait out a report interval on top of that: an application that crashed reports it as soon as it is next able
        // to. Only the first time online brings a delivery forward, so going online again later, as a network comes and
        // goes, keeps to the ordinary cadence.
        deliveryQueue.async { [weak self] in
            guard let self, self.hasEventsFromPreviousRun
            else { return }
            self.hasEventsFromPreviousRun = false
            self.reportEvents()
        }
    }

    private func stopReporting() {
        eventReportTimer?.cancel()
        eventReportTimer = nil
    }

    func flush(completion: CompletionClosure?) {
        flushReportingOutcome { _ in completion?() }
    }

    func flushReportingOutcome(completion: @escaping FlushOutcomeClosure) {
        // Flush is a commit point, so at `.immediate` everything accepted before this call is on disk before control
        // returns, even when delivery cannot run because the client is offline.
        commitAtCommitPoint()
        deliveryQueue.async {
            self.reportEvents { delivered in
                // Committing first is what makes this the answer for everything recorded before the call: whatever
                // could not be kept has been counted by now. Cleared as it is reported, so that the next caller is not
                // told again about a loss this answer has already accounted for.
                completion(delivered && !self.takeEventsLost())
            }
        }
    }

    private func reportEvents() {
        reportEvents(completion: nil)
    }

    private func reportEvents(completion: FlushOutcomeClosure?) {
        guard !isDelivering
        else {
            // Joins the pending flush, which commits whatever this caller recorded once the current delivery finishes,
            // so it covers them. Starting one now would only re-send what is still in flight.
            hasPendingFlush = true
            if let completion {
                pendingFlushCompletions.append(completion)
            }
            return
        }

        guard isOnline
        else {
            os_log("%s aborted. EventReporter is offline", log: service.config.logger, type: .debug, typeName(and: #function))
            reportSyncComplete(.isOffline)
            completion?(false)
            return
        }

        commitAndCloseBatch()

        let batches = store.pendingBatches()
        guard !batches.isEmpty
        else {
            os_log("%s aborted. Event store is empty", log: service.config.logger, type: .debug, typeName(and: #function))
            reportSyncComplete(nil)
            completion?(true)
            return
        }

        os_log("%s starting", log: service.config.logger, type: .debug, typeName(and: #function))
        isDelivering = true
        deliver(batches) { [weak self] delivered in
            guard let self
            else {
                completion?(false)
                return
            }
            // `deliver` reports from whichever queue the response arrived on.
            self.deliveryQueue.async {
                self.finishDelivery(delivered, completion)
            }
        }
    }

    /// Releases the in-flight claim and, if a flush was requested while it was held, runs the pending flush on behalf
    /// of every caller that joined it.
    private func finishDelivery(_ delivered: Bool, _ completion: FlushOutcomeClosure?) {
        isDelivering = false
        completion?(delivered)

        guard hasPendingFlush
        else { return }

        let completions = pendingFlushCompletions
        hasPendingFlush = false
        pendingFlushCompletions = []
        reportEvents { result in
            completions.forEach { $0(delivered && result) }
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
        } catch {
            // Kept: the batch is still there, and a read that failed may not fail next time.
            os_log("%s could not read stored events: %s", log: service.config.logger, type: .debug, typeName(and: #function), String(describing: error))
            completion?(false)
            return
        }

        guard let body = read
        else {
            // Gone, or holding nothing this version can send. Either way there is nothing to send and nothing to keep.
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

    private func publish(_ batch: EventBatch, _ body: Data, _ completion: @escaping (DeliveryOutcome) -> Void) {
        service.publishEventData(body, batch.payloadId) { response in
            let outcome = self.outcome(sentEvents: batch.eventCount, response: response.urlResponse as? HTTPURLResponse, error: response.error, isRetry: false)
            switch outcome {
            case .accepted, .refused:
                self.store.remove(batch)
                completion(outcome)
            case .retryable:
                os_log("%s Retrying event post after delay.", log: self.service.config.logger, type: .debug, self.typeName(and: #function))
                DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 1.0) {
                    self.service.publishEventData(body, batch.payloadId) { retryResponse in
                        let retried = self.outcome(sentEvents: batch.eventCount, response: retryResponse.urlResponse as? HTTPURLResponse, error: retryResponse.error, isRetry: true)
                        switch retried {
                        case .accepted, .refused:
                            self.store.remove(batch)
                        case .retryable:
                            // The batch stays on disk. A later delivery, in this run of the application or the next
                            // one, sends it under the same payload ID, so LaunchDarkly can tell it is not new.
                            os_log("%s Keeping %d event(s) on disk to retry later", log: self.service.config.logger, type: .debug, self.typeName(and: #function), batch.eventCount)
                        }
                        completion(retried)
                    }
                }
            }
        }
    }

    private enum DeliveryOutcome {
        /// LaunchDarkly took the events.
        case accepted
        /// LaunchDarkly will never take these events, so keeping them only wastes space.
        case refused
        /// The events may still be deliverable.
        case retryable
    }

    private func outcome(sentEvents: Int, response: HTTPURLResponse?, error: Error?, isRetry: Bool) -> DeliveryOutcome {
        if error == nil && (200..<300).contains(response?.statusCode ?? 0) {
            let serverTime = response?.headerDate
            stateLock.lock()
            if let serverTime = serverTime, serverTime > responseDate {
                responseDate = serverTime
            }
            stateLock.unlock()

            os_log("%s Completed sending %d event(s)", log: service.config.logger, type: .debug, typeName(and: #function), sentEvents)
            self.reportSyncComplete(nil)
            return .accepted
        }

        if let statusCode = response?.statusCode, HTTPURLResponse.StatusCodes.isTerminalStatusCode(statusCode) {
            os_log("%s dropping events due to non-retriable response: %s", log: service.config.logger, type: .debug, typeName(and: #function), String(describing: response))
            isOnline = false
            self.reportSyncComplete(.response(response))
            return .refused
        }

        os_log("%s Sending events failed with error: %s response: %s", log: service.config.logger, type: .debug, typeName(and: #function), String(describing: error), String(describing: response))

        if isRetry {
            if let error = error {
                reportSyncComplete(.request(error))
            } else {
                reportSyncComplete(.response(response))
            }
            return .retryable
        }

        return .retryable
    }

    private func reportSyncComplete(_ result: SynchronizingError?) {
        // The eventReporter is created when the LDClient singleton is created, and kept for the app's lifetime. So while the use of self in the async block does setup a retain cycle, it's not going to cause a memory leak
        guard let onSyncComplete = onSyncComplete
        else { return }
        DispatchQueue.main.async {
            onSyncComplete(result)
        }
    }
}

extension EventReporter {
    /// Which encoder recorded events go through.
    ///
    /// `.codable` is the reference `.handWritten` is tested against. The two produce equal JSON but not identical
    /// bytes: key order differs, as do `/` against `\/` and `0` against `-0`.
    enum Encoding {
        case codable
        case handWritten
    }

    fileprivate static func makeEncoder(config: LDConfig) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.userInfo = [
            LDContext.UserInfoKeys.allAttributesPrivate: config.allContextAttributesPrivate,
            LDContext.UserInfoKeys.globalPrivateAttributes: config.privateContextAttributes.map { $0 }
        ]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.millisSince1970)
        }
        return encoder
    }
}

extension EventReporter: TypeIdentifying { }

/// Stands in where the platform gave the SDK nowhere to write. Events are recorded and delivered from memory for the
/// life of the process, which is the behavior the SDK had before it kept a log.
private final class NullEventStore: EventStoring {
    private let lock = UnfairLock()
    private var staged: [Data] = []
    private var reserved = 0
    private var closed: [String: [Data]] = [:]

    var pendingEventCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return reserved + staged.count + closed.values.reduce(0) { $0 + $1.count }
    }

    var isPersisting: Bool { false }

    func stage(_ encodedEvent: Data, bypassingCapacity: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        staged.append(encodedEvent)
        return true
    }

    func reserve(_ events: Int) {
        lock.lock()
        defer { lock.unlock() }
        reserved += events
    }

    func stageReserved(_ encodedEvent: Data) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        reserved = max(0, reserved - 1)
        staged.append(encodedEvent)
        return true
    }

    func releaseReservations() {
        lock.lock()
        defer { lock.unlock() }
        reserved = 0
    }

    func commit() {
    }

    func closeBatch() -> EventBatch? {
        lock.lock()
        defer { lock.unlock() }

        guard !staged.isEmpty
        else { return nil }

        let payloadId = UUID().uuidString
        let events = staged
        staged = []
        closed[payloadId] = events
        return EventBatch(payloadId: payloadId, eventCount: events.count)
    }

    func pendingBatches() -> [EventBatch] {
        lock.lock()
        defer { lock.unlock() }
        return closed.map { EventBatch(payloadId: $0.key, eventCount: $0.value.count) }
    }

    func body(of batch: EventBatch) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        guard let events = closed[batch.payloadId]
        else { return nil }

        var body = Data("[".utf8)
        for (index, event) in events.enumerated() {
            if index > 0 {
                body.append(UInt8(ascii: ","))
            }
            body.append(event)
        }
        body.append(UInt8(ascii: "]"))
        return body
    }

    func remove(_ batch: EventBatch) {
        lock.lock()
        defer { lock.unlock() }
        closed[batch.payloadId] = nil
    }

    func recoverInterruptedLog() {
    }
}

#if DEBUG
    extension EventReporter {
        /// Full events accepted but not yet handed to a commit.
        var pendingEventsForTesting: [Event] {
            pendingLock.lock()
            defer { pendingLock.unlock() }
            return pending
        }

        func setLastEventResponseDate(_ date: Date) {
            stateLock.lock()
            responseDate = date
            stateLock.unlock()
        }
    }
#endif
