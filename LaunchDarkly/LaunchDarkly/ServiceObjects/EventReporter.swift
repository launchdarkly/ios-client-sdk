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

    private (set) var lastEventResponseDate: Date

    let service: DarklyServiceProvider

    private let eventQueue = DispatchQueue(label: "com.launchdarkly.eventSyncQueue", qos: .userInitiated)
    // These fields should only be used synchronized on the eventQueue
    private(set) var eventStore: [Event] = []
    private(set) var flagRequestTracker: FlagRequestTracker

    private var timerQueue = DispatchQueue(label: "com.launchdarkly.EventReporter.timerQueue")
    private var eventReportTimer: TimeResponding?
    var isReportingActive: Bool { eventReportTimer != nil }

    private let onSyncComplete: EventSyncCompleteClosure?

    init(service: DarklyServiceProvider, onSyncComplete: EventSyncCompleteClosure?) {
        self.service = service
        self.onSyncComplete = onSyncComplete
        self.lastEventResponseDate = Date()
        self.flagRequestTracker = FlagRequestTracker(logger: service.config.logger)
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
            flagRequestTracker.trackRequest(flagKey: flagKey, reportedValue: value, featureFlag: featureFlag, defaultValue: defaultValue, context: context)
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

        if flagRequestTracker.hasLoggedRequests {
            let summaryEvent = SummaryEvent(flagRequestTracker: flagRequestTracker)
            self.eventStore.append(summaryEvent)
            flagRequestTracker = FlagRequestTracker(logger: service.config.logger)
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
        let encodingConfig: [CodingUserInfoKey: Any] =
            [
                LDContext.UserInfoKeys.allAttributesPrivate: service.config.allContextAttributesPrivate,
                LDContext.UserInfoKeys.globalPrivateAttributes: service.config.privateContextAttributes.map { $0 }
            ]
        let encoder = JSONEncoder()
        encoder.userInfo = encodingConfig
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.millisSince1970)
        }
        guard let eventData = try? encoder.encode(events)
        else {
            os_log("%s Failed to serialize event(s) for publication: %s", log: service.config.logger, type: .debug, typeName(and: #function), String(describing: events))
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

extension EventReporter: TypeIdentifying { }

#if DEBUG
    extension EventReporter {
        func setLastEventResponseDate(_ date: Date) {
            lastEventResponseDate = date
        }

        func setFlagRequestTracker(_ tracker: FlagRequestTracker) {
            flagRequestTracker = tracker
        }
    }
#endif
