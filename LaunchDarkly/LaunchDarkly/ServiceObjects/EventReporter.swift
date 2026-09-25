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

    private var timerQueue = DispatchQueue(label: "com.launchdarkly.EventReporter.timerQueue")
    private var eventReportTimer: TimeResponding?
    var isReportingActive: Bool { eventReportTimer != nil }

    private let onSyncComplete: EventSyncCompleteClosure?

    /// The reflective encoder, built once and then only read.
    ///
    /// `JSONEncoder` is `@unchecked Sendable` and constructs a fresh internal encoder for each `encode` call, so one
    /// instance can be shared — but only while nothing mutates it, which is why `userInfo` is set here rather than per
    /// call. What it holds cannot go stale: `config` is a `let` on the service, so the privacy settings the encoding
    /// depends on are fixed for as long as this reporter exists.
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
        self.contextSummarizer = ContextSummarizer(logger: service.config.logger)
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
            contextSummarizer.trackRequest(flagKey: flagKey, reportedValue: value, featureFlag: featureFlag, defaultValue: defaultValue, context: context)
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
        eventReportTimer = LDTimer(withTimeInterval: service.config.eventFlushInterval, fireQueue: eventQueue, execute: reportEvents)
    }

    private func stopReporting() {
        eventReportTimer?.cancel()
        eventReportTimer = nil
    }

    func flush(completion: CompletionClosure?) {
        eventQueue.async {
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
            completion?()
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

    private func publish(_ events: [Event], _ payloadId: String, _ completion: CompletionClosure?) {
        guard let eventData = encode(events)
        else {
            os_log("%s Failed to serialize event(s) for publication: %s", log: service.config.logger, type: .error, typeName(and: #function), String(describing: events))
            completion?()
            return
        }
        self.service.publishEventData(eventData, payloadId) { response in
            let shouldRetry = self.processEventResponse(sentEvents: events.count, response: response.urlResponse as? HTTPURLResponse, error: response.error, isRetry: false)
            if shouldRetry {
                os_log("%s Retrying event post after delay.", log: self.service.config.logger, type: .debug, self.typeName(and: #function))
                DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 1.0) {
                    self.service.publishEventData(eventData, payloadId) { response in
                        _ = self.processEventResponse(sentEvents: events.count, response: response.urlResponse as? HTTPURLResponse, error: response.error, isRetry: true)
                        completion?()
                    }
                }
            } else {
                completion?()
            }
        }
    }

    /// Encodes a run of events as the array the events endpoint takes.
    ///
    /// One `EventJSONWriter` covers the whole run rather than one per event, so its byte buffer and the capacity it
    /// has grown into are reused. That, and its context cache, is most of what the hand-written path saves over the
    /// reflective one — a run of evaluations is nearly always the same context encoded again and again.
    ///
    /// If the run cannot be encoded as a whole, each event is retried on its own. Failures are dropped rather than
    /// put back: the writer cannot fail transiently, so a failed event would fail every later flush.
    private func encode(_ events: [Event]) -> Data? {
        guard encoding != .codable
        else {
            if let data = try? encoder.encode(events) {
                return data
            }
            return encodeSkippingFailures(events, using: { try encoder.encode($0) })
        }

        let handWritten = EventJSONWriter(config: service.config)
        return encodeSkippingFailures(events, using: { event in
            guard let encoded = handWritten.encode(event)
            else { throw EventEncodingError.handWritten }
            return encoded
        })
    }

    private func encodeSkippingFailures(_ events: [Event], using encodeOne: (Event) throws -> Data) -> Data? {
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
        return payload
    }

    private enum EventEncodingError: Error {
        case handWritten
    }

    private func processEventResponse(sentEvents: Int, response: HTTPURLResponse?, error: Error?, isRetry: Bool) -> Bool {
        if error == nil && (200..<300).contains(response?.statusCode ?? 0) {
            let serverTime = response?.headerDate ?? self.lastEventResponseDate
            if serverTime > self.lastEventResponseDate {
                self.lastEventResponseDate = serverTime
            }

            os_log("%s Completed sending %d event(s)", log: service.config.logger, type: .debug, typeName(and: #function), sentEvents)
            self.reportSyncComplete(nil)
            return false
        }

        if let statusCode = response?.statusCode, (400..<500).contains(statusCode) && ![400, 408, 429].contains(statusCode) {
            os_log("%s dropping events due to non-retriable response: %s", log: service.config.logger, type: .debug, typeName(and: #function), String(describing: response))
            self.reportSyncComplete(.response(response))
            return false
        }

        os_log("%s Sending events failed with error: %s response: %s", log: service.config.logger, type: .debug, typeName(and: #function), String(describing: error), String(describing: response))

        if isRetry {
            os_log("%s dropping events due to failed retry", log: service.config.logger, type: .debug, typeName(and: #function))
            if let error = error {
                reportSyncComplete(.request(error))
            } else {
                reportSyncComplete(.response(response))
            }
            return false
        }

        return true
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
    /// `.handWritten` is the shipping path. Writing the wire form directly rather than through a reflective encoder is
    /// what the Android SDK does, and reusing a context's encoded bytes across the batch pays off because a run of
    /// evaluations is nearly always the same context encoded again and again.
    ///
    /// `.codable` is kept because it is the oracle the writer is checked against: `EventJSONWriterTests` asserts the
    /// two produce identical bytes, and where they disagree `.codable` is right.
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
    }
#endif
