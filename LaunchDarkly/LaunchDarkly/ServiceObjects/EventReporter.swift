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

    func commitRecordedEvents() {
    }
}

/// Records analytics events and delivers them to LaunchDarkly.
///
/// Recorded events are serialized immediately and appended to an `EventStore`, an on-disk log, rather than held in
/// memory until a delivery succeeds. That is what lets an application that dies moments after recording an event still
/// report it: the events are on disk before the process is gone, and the next run of the application delivers them.
///
/// Committing an event to the log is a syscall, so it is not done once per event. Staged bytes are committed when the
/// buffer fills, when a delivery starts, and at a *durable barrier* -- recording a custom or identify event, or the
/// application being backgrounded. An evaluation is not a barrier, which is the deliberate trade: the exposures an
/// application accumulates become durable when it next does something that suggests it cares, such as tracking the
/// error that is about to end the session.
class EventReporter: EventReporting {
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

    private let onSyncComplete: EventSyncCompleteClosure?

    init(service: DarklyServiceProvider, onSyncComplete: EventSyncCompleteClosure?, store: EventStoring? = nil) {
        self.service = service
        self.onSyncComplete = onSyncComplete
        self.responseDate = Date()
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
        return EventStore(directory: directory, capacity: config.eventCapacity, logger: config.logger)
    }

    // MARK: Recording

    func record(_ event: Event) {
        guard let encoded = encode(event)
        else { return }

        let isBarrier = EventReporter.isDurableBarrier(event.kind)
        // Ahead of the event, so that the exposures an application accumulated before tracking something are made
        // durable by the same commit rather than left behind by it.
        if isBarrier {
            stageSummaries()
        }

        stage(encoded)

        if isBarrier {
            store.commit()
        }
    }

    // swiftlint:disable:next function_parameter_count
    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: LDValue, defaultValue: LDValue, featureFlag: FeatureFlag?, context: LDContext, includeReason: Bool) {
        let recordingFeatureEvent = featureFlag?.trackEvents == true
        let recordingDebugEvent = featureFlag?.shouldCreateDebugEvents(lastEventReportResponseTime: lastEventResponseDate) ?? false

        // Built and serialized before the lock is taken. Copying the context and walking it to produce JSON is the
        // expensive part of recording an evaluation, and no other evaluation needs to wait for it.
        var encodedEvents: [Data] = []
        if recordingFeatureEvent {
            let featureEvent = FeatureEvent(key: flagKey, context: context, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason, isDebug: false)
            encode(featureEvent).map { encodedEvents.append($0) }
        }
        if recordingDebugEvent {
            let debugEvent = FeatureEvent(key: flagKey, context: context, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason, isDebug: true)
            encode(debugEvent).map { encodedEvents.append($0) }
        }

        stateLock.lock()
        contextSummarizer.trackRequest(flagKey: flagKey, reportedValue: value, featureFlag: featureFlag, defaultValue: defaultValue, context: context)
        stateLock.unlock()

        encodedEvents.forEach { stage($0) }
    }

    func commitRecordedEvents() {
        stageSummaries()
        store.commit()
    }

    /// Whether recording this kind of event should leave the log durable when it returns.
    ///
    /// Custom and identify events are recorded because the application did something it chose to report, which is both
    /// rare enough to afford a write and the moment it is least acceptable to lose. Evaluations are neither.
    private static func isDurableBarrier(_ kind: Event.Kind) -> Bool {
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
    /// durable barrier rather than only at a delivery is what bounds that loss, and it costs nothing in accuracy:
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
        let encoder = JSONEncoder()
        encoder.userInfo = [
            LDContext.UserInfoKeys.allAttributesPrivate: service.config.allContextAttributesPrivate,
            LDContext.UserInfoKeys.globalPrivateAttributes: service.config.privateContextAttributes.map { $0 }
        ]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.millisSince1970)
        }

        guard let encoded = try? encoder.encode(event)
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
        deliveryQueue.async {
            self.reportEvents(completion: completion)
        }
    }

    private func reportEvents() {
        reportEvents(completion: nil)
    }

    private func reportEvents(completion: CompletionClosure?) {
        guard isOnline
        else {
            os_log("%s aborted. EventReporter is offline", log: service.config.logger, type: .debug, typeName(and: #function))
            reportSyncComplete(.isOffline)
            completion?()
            return
        }

        stageSummaries()
        _ = store.closeBatch()

        let batches = store.pendingBatches()
        guard !batches.isEmpty
        else {
            os_log("%s aborted. Event store is empty", log: service.config.logger, type: .debug, typeName(and: #function))
            reportSyncComplete(nil)
            completion?()
            return
        }

        os_log("%s starting", log: service.config.logger, type: .debug, typeName(and: #function))
        deliver(batches, completion)
    }

    /// Delivers batches oldest first, stopping at the first one that failed in a way worth retrying.
    ///
    /// Stopping matters: the batches that are left keep their place in the log, and a later delivery attempts them
    /// again rather than the SDK spending the rest of the session's requests on a service that is refusing them.
    private func deliver(_ batches: [EventBatch], _ completion: CompletionClosure?) {
        var remaining = batches
        guard !remaining.isEmpty
        else {
            completion?()
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
                completion?()
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
        func setLastEventResponseDate(_ date: Date) {
            stateLock.lock()
            responseDate = date
            stateLock.unlock()
        }
    }
#endif
