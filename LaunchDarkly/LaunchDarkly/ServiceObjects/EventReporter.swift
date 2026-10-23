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

    /// Like `flush`. Reports `true` if LaunchDarkly accepted the events, or there were none to send. Reports `false` if
    /// the reporter is offline, or any of the events were lost: refused, still failing after the retry, or unable to
    /// be serialized.
    ///
    /// Flushes arriving faster than a delivery completes join the one that is queued, since a delivery that has not
    /// started yet will send their events too. A delivery that has already started is not joined, so an answer is
    /// always about the batch the caller's own delivery took, never one an earlier delivery lost.
    ///
    /// The completion, like `flush`'s, runs on a background queue, and never on the reporter's own: a completion is
    /// free to record events or flush again without waiting on the queue it is running on. It is not the caller's
    /// thread either, and two completions may run at once, so anything it touches needs to expect that.
    func flushReportingOutcome(completion: @escaping FlushOutcomeClosure)
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
}

class EventReporter: EventReporting {
    var isOnline: Bool {
        get { timerQueue.sync { eventReportTimer != nil } }
        set { timerQueue.sync { newValue ? startReporting() : stopReporting() } }
    }

    private(set) var lastEventResponseDate: Date

    let service: DarklyServiceProvider

    private let eventQueue = DispatchQueue(label: "com.launchdarkly.eventSyncQueue", qos: .userInitiated)
    // These fields should only be used synchronized on the eventQueue
    private(set) var eventStore: [Event] = []
    private(set) var contextSummarizer: ContextSummarizer

    /// Guards `queuedDelivery`. Taken on a caller's thread and on `eventQueue`, and never held across either.
    private let deliveryLock = UnfairLock()
    /// Callers waiting on a delivery that is queued and has not taken the event store yet, or nil where none is
    /// queued.
    private var queuedDelivery: [FlushOutcomeClosure]?

    #if DEBUG
        /// How many deliveries have started, which is fewer than the flushes asked for where they were joined.
        private var deliveryRunCount = 0
    #endif

    private var timerQueue = DispatchQueue(label: "com.launchdarkly.EventReporter.timerQueue")
    private var eventReportTimer: TimeResponding?
    var isReportingActive: Bool { eventReportTimer != nil }

    private let onSyncComplete: EventSyncCompleteClosure?

    /// Shared across concurrent flushes, so it must not be mutated after `init`.
    private let encoder: JSONEncoder

    let encoding: Encoding

    init(service: DarklyServiceProvider,
         onSyncComplete: EventSyncCompleteClosure?,
         encoding: Encoding = .handWritten) {
        self.service = service
        self.onSyncComplete = onSyncComplete
        self.lastEventResponseDate = Date()
        self.encoding = encoding
        self.encoder = EventReporter.makeEncoder(config: service.config)
        self.contextSummarizer = ContextSummarizer(logger: service.config.logger, maxContexts: service.config.eventCapacity)
    }

    func record(_ event: Event) {
        // The eventReporter is created when the LDClient singleton is created, and kept for the app's lifetime. So while the use of self in the async block does setup a retain cycle, it's not going to cause a memory leak
        eventQueue.sync { recordNoSync(event) }
    }

    func recordNoSync(_ event: Event) {
        if self.eventStore.count >= self.service.config.eventCapacity {
            os_log("%s aborted. Event store is full", log: service.config.logger, type: .debug, typeName(and: #function))
            self.service.diagnosticCache?.incrementDroppedEventCount()
            return
        }
        self.eventStore.append(event)
    }

    // swiftlint:disable:next function_parameter_count
    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: LDValue, defaultValue: LDValue, featureFlag: FeatureFlag?, context: LDContext, includeReason: Bool) {
        let recordingFeatureEvent = featureFlag?.trackEvents == true
        let recordingDebugEvent = featureFlag?.shouldCreateDebugEvents(lastEventReportResponseTime: lastEventResponseDate) ?? false

        eventQueue.sync {
            // A refused evaluation is a loss like a refused event, since nothing later reconstructs its counter. Its
            // full event is still decided by the event capacity alone.
            if !contextSummarizer.trackRequest(flagKey: flagKey, reportedValue: value, featureFlag: featureFlag, defaultValue: defaultValue, context: context) {
                service.diagnosticCache?.incrementDroppedEventCount()
            }
            if recordingFeatureEvent {
                let featureEvent = FeatureEvent(key: flagKey, context: context, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason, isDebug: false)
                recordNoSync(featureEvent)
            }
            if recordingDebugEvent {
                let debugEvent = FeatureEvent(key: flagKey, context: context, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason, isDebug: true)
                recordNoSync(debugEvent)
            }
        }
    }

    private func startReporting() {
        guard eventReportTimer == nil
        else { return }
        eventReportTimer = LDTimer(withTimeInterval: service.config.eventFlushInterval, fireQueue: eventQueue, execute: queueScheduledDelivery)
    }

    private func stopReporting() {
        eventReportTimer?.cancel()
        eventReportTimer = nil
    }

    func flush(completion: CompletionClosure?) {
        // Nil stays nil, so a flush nobody waits on joins a queued delivery without adding to its waiters.
        queueDelivery(completion.map { done in { _ in done() } })
    }

    func flushReportingOutcome(completion: @escaping FlushOutcomeClosure) {
        queueDelivery(completion)
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
    /// A delivery that has already started is not joined. It has taken the event store, so it cannot speak for
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

        eventQueue.async { self.runDelivery() }
    }

    private func runDelivery() {
        // Requests arriving from here on need a delivery of their own: this one is about to take the event store, and
        // what it takes is all it can speak for.
        deliveryLock.lock()
        let waiters = queuedDelivery ?? []
        queuedDelivery = nil
        #if DEBUG
            deliveryRunCount += 1
        #endif
        deliveryLock.unlock()

        reportEvents { delivered in
            guard !waiters.isEmpty
            else { return }
            // Answered away from `eventQueue`, and from whichever thread the delivery ended on, so that every
            // completion reaches its caller the same way. A completion is free to record or flush again: it is never
            // running on the queue those wait for.
            DispatchQueue.global().async {
                for waiter in waiters {
                    waiter(delivered)
                }
            }
        }
    }

    private func reportEvents(completion: FlushOutcomeClosure?) {
        guard isOnline
        else {
            os_log("%s aborted. EventReporter is offline", log: service.config.logger, type: .debug, typeName(and: #function))
            reportSyncComplete(.isOffline)
            completion?(false)
            return
        }

        if contextSummarizer.hasLoggedRequests {
            let summaries = contextSummarizer.getSummaries()
            for summary in summaries {
                let summaryEvent = SummaryEvent(flagRequestTracker: summary.tracker, context: summary.context)
                self.eventStore.append(summaryEvent)
            }
            contextSummarizer.clear()
        }

        guard !eventStore.isEmpty
        else {
            os_log("%s aborted. Event store is empty", log: service.config.logger, type: .debug, typeName(and: #function))
            reportSyncComplete(nil)
            completion?(true)
            return
        }

        os_log("%s starting", log: service.config.logger, type: .debug, typeName(and: #function))

        let toPublish = self.eventStore
        self.eventStore = []

        service.diagnosticCache?.recordEventsInLastBatch(eventsInLastBatch: toPublish.count)

        DispatchQueue.global().async {
            self.publish(toPublish, UUID().uuidString, completion)
        }
    }

    private func publish(_ events: [Event], _ payloadId: String, _ completion: FlushOutcomeClosure?) {
        guard let (eventData, isComplete) = encode(events)
        else {
            os_log("%s Failed to serialize event(s) for publication: %s", log: service.config.logger, type: .error, typeName(and: #function), String(describing: events))
            // Encoding is deterministic, so no retry would succeed; the events are lost.
            completion?(false)
            return
        }
        self.service.publishEventData(eventData, payloadId) { response in
            switch self.processEventResponse(sentEvents: events.count, response: response.urlResponse as? HTTPURLResponse, error: response.error, isRetry: false) {
            case .accepted:
                completion?(isComplete)
            case .refused, .dropped:
                completion?(false)
            case .retryable:
                os_log("%s Retrying event post after delay.", log: self.service.config.logger, type: .debug, self.typeName(and: #function))
                DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 1.0) {
                    self.service.publishEventData(eventData, payloadId) { response in
                        let outcome = self.processEventResponse(sentEvents: events.count, response: response.urlResponse as? HTTPURLResponse, error: response.error, isRetry: true)
                        completion?(outcome == .accepted && isComplete)
                    }
                }
            }
        }
    }

    private enum DeliveryOutcome {
        case accepted
        /// Refused with a status that no retry would change. The events are dropped.
        case refused
        case retryable
        /// Failed with no retry left.
        case dropped
    }

    /// Encodes a run of events as the array the events endpoint takes.
    ///
    /// If the run cannot be encoded as a whole, each event is retried on its own. Events that fail are dropped rather
    /// than put back, because encoding is deterministic and they would fail every later flush too. `isComplete` is
    /// false when any were dropped.
    private func encode(_ events: [Event]) -> (data: Data, isComplete: Bool)? {
        guard encoding != .codable
        else {
            if let data = try? encoder.encode(events) {
                return (data, true)
            }
            return encodeSkippingFailures(events, using: { try encoder.encode($0) })
        }

        let eventJSONWriter = EventJSONWriter(config: service.config)
        return encodeSkippingFailures(events, using: { event in
            guard let encoded = eventJSONWriter.encode(event)
            else { throw EventEncodingError.handWritten }
            return encoded
        })
    }

    private func encodeSkippingFailures(_ events: [Event], using encodeOne: (Event) throws -> Data) -> (data: Data, isComplete: Bool)? {
        var payload = Data([UInt8(ascii: "[")])
        var written = 0
        for event in events {
            let encoded: Data
            do {
                encoded = try encodeOne(event)
            } catch {
                os_log("%s dropping unserializable event: %s",
                       log: service.config.logger,
                       type: .error,
                       typeName(and: #function),
                       String(describing: event))
                continue
            }
            if written > 0 {
                payload.append(UInt8(ascii: ","))
            }
            payload.append(encoded)
            written += 1
        }
        guard written > 0
        else { return nil }
        payload.append(UInt8(ascii: "]"))
        return (payload, written == events.count)
    }

    private enum EventEncodingError: Error {
        case handWritten
    }

    private func processEventResponse(sentEvents: Int, response: HTTPURLResponse?, error: Error?, isRetry: Bool) -> DeliveryOutcome {
        if error == nil && (200..<300).contains(response?.statusCode ?? 0) {
            let serverTime = response?.headerDate ?? self.lastEventResponseDate
            if serverTime > self.lastEventResponseDate {
                self.lastEventResponseDate = serverTime
            }

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
            os_log("%s dropping events due to failed retry", log: service.config.logger, type: .debug, typeName(and: #function))
            if let error = error {
                reportSyncComplete(.request(error))
            } else {
                reportSyncComplete(.response(response))
            }
            return .dropped
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

#if DEBUG
    extension EventReporter {
        func setLastEventResponseDate(_ date: Date) {
            lastEventResponseDate = date
        }

        /// Occupies the queue a delivery runs on, so a test can see what one that has not started yet collects.
        func occupyQueue(until released: DispatchSemaphore) {
            eventQueue.async { _ = released.wait(timeout: .now() + 10) }
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
    }
#endif
