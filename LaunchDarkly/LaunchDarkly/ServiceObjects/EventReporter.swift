import Foundation

typealias EventSyncCompleteClosure = ((SynchronizingError?) -> Void)
// sourcery: autoMockable
protocol EventReporting {
    // sourcery: defaultMockValue = false
    var isOnline: Bool { get set }
    var lastEventResponseDate: Date? { get }

    func record(_ event: Event)
    // swiftlint:disable:next function_parameter_count
    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: LDValue, defaultValue: LDValue, featureFlag: FeatureFlag?, user: LDUser, includeReason: Bool)
    func flush(completion: CompletionClosure?)
}

class EventReporter: EventReporting {
    var isOnline: Bool {
        get { timerQueue.sync { eventReportTimer != nil } }
        set { timerQueue.sync { newValue ? startReporting() : stopReporting() } }
    }

    private (set) var lastEventResponseDate: Date?

    let service: DarklyServiceProvider

    private let eventQueue = DispatchQueue(label: "com.launchdarkly.eventSyncQueue", qos: .userInitiated)
    // These fields should only be used synchronized on the eventQueue
    private(set) var eventStore: [Event] = []
    private(set) var flagRequestTracker = FlagRequestTracker()

    private var timerQueue = DispatchQueue(label: "com.launchdarkly.EventReporter.timerQueue")
    private var eventReportTimer: TimeResponding?
    var isReportingActive: Bool { eventReportTimer != nil }

    private let onSyncComplete: EventSyncCompleteClosure?

    init(service: DarklyServiceProvider, onSyncComplete: EventSyncCompleteClosure?) {
        self.service = service
        self.onSyncComplete = onSyncComplete
    }

    func record(_ event: Event) {
        // The eventReporter is created when the LDClient singleton is created, and kept for the app's lifetime. So while the use of self in the async block does setup a retain cycle, it's not going to cause a memory leak
        eventQueue.sync { recordNoSync(event) }
    }

    func recordNoSync(_ event: Event) {
        if self.eventStore.count >= self.service.config.eventCapacity {
            Log.debug(self.typeName(and: #function) + "aborted. Event store is full")
            self.service.diagnosticCache?.incrementDroppedEventCount()
            return
        }
        self.eventStore.append(event)
    }

    // swiftlint:disable:next function_parameter_count
    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: LDValue, defaultValue: LDValue, featureFlag: FeatureFlag?, user: LDUser, includeReason: Bool) {
        let recordingFeatureEvent = featureFlag?.trackEvents == true
        let recordingDebugEvent = featureFlag?.shouldCreateDebugEvents(lastEventReportResponseTime: lastEventResponseDate) ?? false

        eventQueue.sync {
            flagRequestTracker.trackRequest(flagKey: flagKey, reportedValue: value, featureFlag: featureFlag, defaultValue: defaultValue)
            if recordingFeatureEvent {
                let featureEvent = FeatureEvent(key: flagKey, user: user, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason, isDebug: false)
                recordNoSync(featureEvent)
            }
            if recordingDebugEvent {
                let debugEvent = FeatureEvent(key: flagKey, user: user, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason, isDebug: true)
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
            Log.debug(typeName(and: #function) + "aborted. EventReporter is offline")
            reportSyncComplete(.isOffline)
            completion?()
            return
        }

        if flagRequestTracker.hasLoggedRequests {
            let summaryEvent = SummaryEvent(flagRequestTracker: flagRequestTracker)
            self.eventStore.append(summaryEvent)
            flagRequestTracker = FlagRequestTracker()
        }

        guard !eventStore.isEmpty
        else {
            Log.debug(typeName(and: #function) + "aborted. Event store is empty")
            reportSyncComplete(nil)
            completion?()
            return
        }
        Log.debug(typeName(and: #function, appending: " - ") + "starting")

        let toPublish = self.eventStore
        self.eventStore = []

        service.diagnosticCache?.recordEventsInLastBatch(eventsInLastBatch: toPublish.count)

        DispatchQueue.global().async {
            self.publish(toPublish, UUID().uuidString, completion)
        }
    }

    private func publish(_ events: [Event], _ payloadId: String, _ completion: CompletionClosure?) {
        let encodingConfig: [CodingUserInfoKey: Any] =
            [Event.UserInfoKeys.inlineUserInEvents: service.config.inlineUserInEvents,
             LDUser.UserInfoKeys.allAttributesPrivate: service.config.allUserAttributesPrivate,
             LDUser.UserInfoKeys.globalPrivateAttributes: service.config.privateUserAttributes.map { $0.name }]
        let encoder = JSONEncoder()
        encoder.userInfo = encodingConfig
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.millisSince1970)
        }
        guard let eventData = try? encoder.encode(events)
        else {
            Log.debug(self.typeName(and: #function) + "Failed to serialize event(s) for publication: \(events)")
            completion?()
            return
        }
        self.service.publishEventData(eventData, payloadId) { _, urlResponse, error in
            let shouldRetry = self.processEventResponse(sentEvents: events.count, response: urlResponse as? HTTPURLResponse, error: error, isRetry: false)
            if shouldRetry {
                Log.debug("Retrying event post after delay.")
                DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 1.0) {
                    self.service.publishEventData(eventData, payloadId) { _, urlResponse, error in
                        _ = self.processEventResponse(sentEvents: events.count, response: urlResponse as? HTTPURLResponse, error: error, isRetry: true)
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
            self.lastEventResponseDate = response?.headerDate ?? self.lastEventResponseDate
            Log.debug(self.typeName(and: #function) + "Completed sending \(sentEvents) event(s)")
            self.reportSyncComplete(nil)
            return false
        }

        if let statusCode = response?.statusCode, (400..<500).contains(statusCode) && ![400, 408, 429].contains(statusCode) {
            Log.debug(typeName(and: #function) + "dropping events due to non-retriable response: \(String(describing: response))")
            self.reportSyncComplete(.response(response))
            return false
        }

        Log.debug(typeName(and: #function) + "Sending events failed with error: \(String(describing: error)) response: \(String(describing: response))")

        if isRetry {
            Log.debug(typeName(and: #function) + "dropping events due to failed retry")
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
        func setLastEventResponseDate(_ date: Date?) {
            lastEventResponseDate = date
        }

        func setFlagRequestTracker(_ tracker: FlagRequestTracker) {
            flagRequestTracker = tracker
        }
    }
#endif
