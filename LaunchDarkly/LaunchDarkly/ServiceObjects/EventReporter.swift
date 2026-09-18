import Foundation
import OSLog

typealias EventSyncCompleteClosure = ((SynchronizingError?) -> Void)
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

    /// Same as `flush`, and reports whether the pending batches left the SDK's hands.
    ///
    /// `true` if they were delivered, refused for good, or there were none. `false` if the SDK is offline or a
    /// retryable failure left batches on disk.
    func flushReportingOutcome(completion: @escaping (Bool) -> Void)

    /// Makes everything recorded so far outlive the process, without waiting for a delivery.
    ///
    /// The SDK does this itself at the points where an application is most likely to be about to die. It is worth
    /// calling directly before deliberately terminating the process.
    func commitRecordedEvents()
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

    func flushReportingOutcome(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func commitRecordedEvents() {
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
/// custom or identify event is a *commit point*: it encodes and writes before returning, because an application
/// reporting something it chose to report is saying this matters more than the microseconds it costs, and the crash it
/// describes may be moments away. That commit takes the whole held run with it, so the exposures leading up to the
/// error go down alongside it. Evaluations get no such promise, and are committed once `pendingCommitThreshold` of
/// them have accumulated, when a delivery starts, or on `flush`.
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

    /// Guards the summarizer and the last response date.
    ///
    /// This is a lock rather than a queue because it is taken once per evaluation, and a `DispatchQueue.sync` costs
    /// enough at that rate to be worth avoiding: the same measurement that made `EvaluationExposureDeduper` a lock
    /// applies here. It is never held across encoding an event or across a syscall, so an evaluation contends only with
    /// another evaluation's bookkeeping.
    private let stateLock = UnfairLock()
    /// Only to be used while holding `stateLock`.
    private(set) var contextSummarizer: ContextSummarizer
    /// Only to be used while holding `stateLock`.
    private var responseDate: Date

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

    /// Guards the held events. Held only long enough to append one or to hand the run over, never across the encoder.
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

    /// Whether a delivery was asked for while one was already running.
    private var hasWaitingRequest = false

    /// Callers waiting on the pass that `hasWaitingRequest` will start.
    private var waitingCompletions: [(Bool) -> Void] = []

    private let onSyncComplete: EventSyncCompleteClosure?

    /// The encoder every recorded event goes through.
    ///
    /// Built once and then only read. `JSONEncoder` is `@unchecked Sendable` and constructs a fresh internal encoder
    /// for each `encode` call, so the threads recording events can share this one — but only while nothing mutates it,
    /// which is why `userInfo` is set here rather than per event. What it holds cannot go stale: `config` is a `let` on
    /// the service, so the privacy settings the encoding depends on are fixed for as long as this reporter exists.
    private let encoder: JSONEncoder

    let encoding: Encoding
    fileprivate let handWrittenEncoder: EventJSONWriter

    init(service: DarklyServiceProvider,
         onSyncComplete: EventSyncCompleteClosure?,
         store: EventStoring? = nil,
         encoding: Encoding = .codable,
         commitQueue: DispatchQueue = DispatchQueue(label: "com.launchdarkly.EventReporter.commitQueue", qos: .userInitiated)) {
        self.service = service
        self.onSyncComplete = onSyncComplete
        self.responseDate = Date()
        self.encoding = encoding
        self.capacity = service.config.eventCapacity
        self.commitQueue = commitQueue
        self.encoder = EventReporter.makeEncoder(config: service.config)
        self.handWrittenEncoder = EventJSONWriter(config: service.config,
                                                  cachingContexts: encoding == .handWrittenCachingContext)
        self.contextSummarizer = ContextSummarizer(logger: service.config.logger)
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
                          persistEvents: config.persistEvents,
                          logger: config.logger)
    }

    // MARK: Recording

    func record(_ event: Event) {
        hold(event)

        if EventReporter.isCommitPoint(event.kind) {
            commitRecordedEvents()
        }
    }

    // swiftlint:disable:next function_parameter_count
    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: LDValue, defaultValue: LDValue, featureFlag: FeatureFlag?, context: LDContext, includeReason: Bool) {
        let recordingFeatureEvent = featureFlag?.trackEvents == true
        let recordingDebugEvent = featureFlag?.shouldCreateDebugEvents(lastEventReportResponseTime: lastEventResponseDate) ?? false

        stateLock.lock()
        contextSummarizer.trackRequest(flagKey: flagKey, reportedValue: value, featureFlag: featureFlag, defaultValue: defaultValue, context: context)
        stateLock.unlock()

        if recordingFeatureEvent {
            hold(FeatureEvent(key: flagKey, context: context, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason, isDebug: false))
        }
        if recordingDebugEvent {
            hold(FeatureEvent(key: flagKey, context: context, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason, isDebug: true))
        }
        // Deliberately no commit. An evaluation is expected to cost what bookkeeping costs, and it is usually the main
        // thread doing it; the run is encoded and written on the commit queue once enough of them have piled up, and
        // the next event recorded at a commit point makes them durable along with itself.
    }

    /// Holds an event for the next commit to encode, counting it as dropped if the SDK is already full.
    ///
    /// Capacity is consulted before anything else, so an event that will not be kept is never encoded. That ordering is
    /// what bounds an application re-evaluating a tracked flag in a render loop: once the limit is reached an
    /// evaluation costs no more than its summary counter, however fast the loop runs.
    private func hold(_ event: Event) {
        pendingLock.lock()

        guard pending.count + store.pendingEventCount < capacity
        else {
            pendingLock.unlock()
            os_log("%s aborted. Event store is full", log: service.config.logger, type: .debug, typeName(and: #function))
            service.diagnosticCache?.incrementDroppedEventCount()
            return
        }

        pending.append(event)
        let needsCommit = pending.count >= EventReporter.pendingCommitThreshold && !isCommitScheduled
        if needsCommit {
            isCommitScheduled = true
        }
        pendingLock.unlock()

        guard needsCommit
        else { return }

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

    func commitRecordedEvents() {
        commitLock.lock()
        defer { commitLock.unlock() }

        stagePendingEvents()
        stageSummaries()
        store.commit()
    }

    /// Encodes the held events as one run and stages the bytes.
    ///
    /// The run is taken under `pendingLock` and encoded outside it, so recording does not wait on the encoder. Staging
    /// bypasses capacity because the decision to keep these events was made in `hold`, and refusing them here would
    /// drop events the SDK has already counted as accepted.
    ///
    /// Requires `commitLock`: two threads draining separate runs would stage them in whichever order they finished
    /// encoding, which is not the order they were recorded in.
    private func stagePendingEvents() {
        pendingLock.lock()
        if pending.isEmpty {
            pendingLock.unlock()
            return
        }
        let run = pending
        pending = []
        pendingLock.unlock()

        for event in run {
            guard let encoded = encode(event)
            else { continue }
            stage(encoded, bypassingCapacity: true)
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

    private func stage(_ encodedEvent: Data, bypassingCapacity: Bool = false) {
        guard store.stage(encodedEvent, bypassingCapacity: bypassingCapacity)
        else {
            os_log("%s aborted. Event store is full", log: service.config.logger, type: .debug, typeName(and: #function))
            service.diagnosticCache?.incrementDroppedEventCount()
            return
        }
    }

    /// Turns the evaluations counted so far into summary events and stages them, leaving the counters empty.
    ///
    /// Counters live only in memory, so a crash takes whatever has not been summarized with it. Summarizing at each
    /// commit point rather than only at a delivery is what bounds that loss, and it costs nothing in accuracy:
    /// LaunchDarkly sums the counters of every summary it receives, so a session that produced several summaries is
    /// counted the same as one that produced a single summary covering the same evaluations.
    private func stageSummaries() {
        stateLock.lock()
        let summaries = contextSummarizer.hasLoggedRequests ? contextSummarizer.getSummaries() : []
        if !summaries.isEmpty {
            contextSummarizer.clear()
        }
        stateLock.unlock()

        for summary in summaries {
            let summaryEvent = SummaryEvent(flagRequestTracker: summary.tracker, context: summary.context)
            guard let encoded = encode(summaryEvent)
            else { continue }
            // Summaries are an aggregate of evaluations that were already counted, so refusing one for capacity would
            // lose evaluations the SDK promised to report rather than shed new load.
            stage(encoded, bypassingCapacity: true)
        }
    }

    private func encode(_ event: Event) -> Data? {
        let encoded: Data? = encoding == .codable ? try? encoder.encode(event) : handWrittenEncoder.encode(event)
        guard let encoded = encoded
        else {
            os_log("%s Failed to serialize event for publication: %s", log: service.config.logger, type: .debug, typeName(and: #function), String(describing: event))
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

    func flushReportingOutcome(completion: @escaping (Bool) -> Void) {
        // Flush is a commit point: everything accepted before this call must be on disk before control returns,
        // even when delivery cannot run because the client is offline.
        commitRecordedEvents()
        deliveryQueue.async {
            self.reportEvents(completion: completion)
        }
    }

    private func reportEvents() {
        reportEvents(completion: nil)
    }

    private func reportEvents(completion: ((Bool) -> Void)?) {
        guard !isDelivering
        else {
            // Everything this caller recorded is already committed, so one pass after the current delivery finishes
            // covers it. Starting one now would only re-send what is still in flight.
            hasWaitingRequest = true
            if let completion {
                waitingCompletions.append(completion)
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

        commitRecordedEvents()
        _ = store.closeBatch()

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

    /// Releases the in-flight claim and, if a delivery was asked for while it was held, makes the one pass that covers
    /// every caller that waited.
    private func finishDelivery(_ delivered: Bool, _ completion: ((Bool) -> Void)?) {
        isDelivering = false
        completion?(delivered)

        guard hasWaitingRequest
        else { return }

        let waiting = waitingCompletions
        hasWaitingRequest = false
        waitingCompletions = []
        reportEvents { result in
            waiting.forEach { $0(result) }
        }
    }

    /// Delivers batches oldest first, stopping at the first one that failed in a way worth retrying.
    ///
    /// Stopping matters: the batches that are left keep their place in the log, and a later delivery attempts them
    /// again rather than the SDK spending the rest of the session's requests on a service that is refusing them.
    private func deliver(_ batches: [EventBatch], _ completion: ((Bool) -> Void)?) {
        var remaining = batches
        guard !remaining.isEmpty
        else {
            completion?(true)
            return
        }

        let batch = remaining.removeFirst()
        guard let body = store.body(of: batch)
        else {
            // Nothing deliverable in it, so it will never become deliverable.
            store.remove(batch)
            deliver(remaining, completion)
            return
        }

        service.diagnosticCache?.recordEventsInLastBatch(eventsInLastBatch: batch.eventCount)
        publish(batch, body) { shouldContinue in
            if shouldContinue {
                self.deliver(remaining, completion)
            } else {
                completion?(false)
            }
        }
    }

    private func publish(_ batch: EventBatch, _ body: Data, _ completion: @escaping (Bool) -> Void) {
        service.publishEventData(body, batch.payloadId) { response in
            let outcome = self.outcome(sentEvents: batch.eventCount, response: response.urlResponse as? HTTPURLResponse, error: response.error, isRetry: false)
            switch outcome {
            case .accepted, .refused:
                self.store.remove(batch)
                completion(true)
            case .retryable:
                os_log("%s Retrying event post after delay.", log: self.service.config.logger, type: .debug, self.typeName(and: #function))
                DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 1.0) {
                    self.service.publishEventData(body, batch.payloadId) { retryResponse in
                        let retried = self.outcome(sentEvents: batch.eventCount, response: retryResponse.urlResponse as? HTTPURLResponse, error: retryResponse.error, isRetry: true)
                        switch retried {
                        case .accepted, .refused:
                            self.store.remove(batch)
                            completion(true)
                        case .retryable:
                            // The batch stays on disk. A later delivery, in this run of the application or the next
                            // one, sends it under the same payload ID, so LaunchDarkly can tell it is not new.
                            os_log("%s Keeping %d event(s) on disk to retry later", log: self.service.config.logger, type: .debug, self.typeName(and: #function), batch.eventCount)
                            completion(false)
                        }
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

        if let statusCode = response?.statusCode, (400..<500).contains(statusCode) && ![400, 408, 429].contains(statusCode) {
            os_log("%s dropping events due to non-retriable response: %s", log: service.config.logger, type: .debug, typeName(and: #function), String(describing: response))
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
    /// Which encoder recorded events go through. Experimental: `.codable` is the shipping path, and `.handWritten`
    /// exists so the two can be measured against each other on the same recording path rather than in isolation.
    enum Encoding {
        case codable
        case handWritten
        /// The hand-written writer, reusing the last context's encoded bytes when the context has not changed.
        case handWrittenCachingContext
    }

    /// Exposed so the benchmark can report an observed hit rate instead of assuming one.
    var contextCache: ContextEncodingCache? { handWrittenEncoder.contextCache }

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
    private var closed: [String: [Data]] = [:]

    var pendingEventCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return staged.count + closed.values.reduce(0) { $0 + $1.count }
    }

    func stage(_ encodedEvent: Data, bypassingCapacity: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        staged.append(encodedEvent)
        return true
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
