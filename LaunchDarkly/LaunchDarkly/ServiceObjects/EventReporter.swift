//
//  EventReporter.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

enum EventSyncResult {
    case success([[String: Any]])
    case error(SynchronizingError)
}

typealias EventSyncCompleteClosure = ((EventSyncResult) -> Void)
// sourcery: autoMockable
protocol EventReporting {
    // sourcery: defaultMockValue = false
    var isOnline: Bool { get set }
    var lastEventResponseDate: Date? { get }

    func record(_ event: Event)
    // swiftlint:disable:next function_parameter_count
    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: Any?, defaultValue: Any?, featureFlag: FeatureFlag?, user: LDUser, includeReason: Bool)
    func flush(completion: CompletionClosure?)
}

class EventReporter: EventReporting {
    fileprivate struct Constants {
        static let eventQueueLabel = "com.launchdarkly.eventSyncQueue"
    }

    private let eventQueue = DispatchQueue(label: Constants.eventQueueLabel, qos: .userInitiated)
    var isOnline: Bool {
        get { isOnlineQueue.sync { _isOnline } }
        set {
            isOnlineQueue.sync {
                _isOnline = newValue
                Log.debug(typeName(and: #function, appending: ": ") + "\(_isOnline)")
                _isOnline ? startReporting(isOnline: _isOnline) : stopReporting()
            }
        }
    }

    private var _isOnline = false
    private var isOnlineQueue = DispatchQueue(label: "com.launchdarkly.EventReporter.isOnlineQueue")
    private (set) var lastEventResponseDate: Date?

    let service: DarklyServiceProvider

    // These fields should only be used synchronized on the eventQueue
    private(set) var eventStore: [Event] = []
    private(set) var flagRequestTracker = FlagRequestTracker()

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
    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: Any?, defaultValue: Any?, featureFlag: FeatureFlag?, user: LDUser, includeReason: Bool) {
        let recordingFeatureEvent = featureFlag?.trackEvents == true
        let recordingDebugEvent = featureFlag?.shouldCreateDebugEvents(lastEventReportResponseTime: lastEventResponseDate) ?? false

        eventQueue.sync {
            flagRequestTracker.trackRequest(flagKey: flagKey, reportedValue: value, featureFlag: featureFlag, defaultValue: defaultValue)
            if recordingFeatureEvent {
                let featureEvent = Event.featureEvent(key: flagKey, value: value, defaultValue: defaultValue, featureFlag: featureFlag, user: user, includeReason: includeReason)
                recordNoSync(featureEvent)
            }
            if recordingDebugEvent, let featureFlag = featureFlag {
                let debugEvent = Event.debugEvent(key: flagKey, value: value, defaultValue: defaultValue, featureFlag: featureFlag, user: user, includeReason: includeReason)
                recordNoSync(debugEvent)
            }
        }
    }

    private func startReporting(isOnline: Bool) {
        guard isOnline && !isReportingActive
        else { return }
        eventReportTimer = LDTimer(withTimeInterval: service.config.eventFlushInterval, fireQueue: eventQueue, execute: reportEvents)
    }
    
    private func stopReporting() {
        guard isReportingActive
        else { return }
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
            reportSyncComplete(.error(.isOffline))
            completion?()
            return
        }

        let summaryEvent = Event.summaryEvent(flagRequestTracker: flagRequestTracker)
        if let summaryEvent = summaryEvent { recordNoSync(summaryEvent) }
        flagRequestTracker = FlagRequestTracker()

        guard !eventStore.isEmpty
        else {
            Log.debug(typeName(and: #function) + "aborted. Event store is empty")
            reportSyncComplete(.success([]))
            completion?()
            return
        }
        Log.debug(typeName(and: #function, appending: " - ") + "starting")

        let toPublish = self.eventStore
        self.eventStore = []

        service.diagnosticCache?.recordEventsInLastBatch(eventsInLastBatch: toPublish.count)

        DispatchQueue.main.async {
            self.publish(toPublish, UUID().uuidString, completion)
        }
    }

    private func publish(_ events: [Event], _ payloadId: String, _ completion: CompletionClosure?) {
        let eventDictionaries = events.map { $0.dictionaryValue(config: service.config) }
        self.service.publishEventDictionaries(eventDictionaries, payloadId) { _, urlResponse, error in
            let shouldRetry = self.processEventResponse(sentEvents: eventDictionaries, response: urlResponse as? HTTPURLResponse, error: error, isRetry: false)
            if shouldRetry {
                Log.debug("Retrying event post after delay.")
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0) {
                    self.service.publishEventDictionaries(eventDictionaries, payloadId) { _, urlResponse, error in
                        _ = self.processEventResponse(sentEvents: eventDictionaries, response: urlResponse as? HTTPURLResponse, error: error, isRetry: true)
                        completion?()
                    }
                }
            } else {
                completion?()
            }
        }
    }

    private func processEventResponse(sentEvents: [[String: Any]], response: HTTPURLResponse?, error: Error?, isRetry: Bool) -> Bool {
        if error == nil && (200..<300).contains(response?.statusCode ?? 0) {
            self.lastEventResponseDate = response?.headerDate ?? self.lastEventResponseDate
            Log.debug(self.typeName(and: #function) + "Completed sending \(sentEvents.count) event(s)")
            self.reportSyncComplete(.success(sentEvents))
            return false
        }

        if let statusCode = response?.statusCode, (400..<500).contains(statusCode) && ![400, 408, 429].contains(statusCode) {
            Log.debug(typeName(and: #function) + "dropping events due to non-retriable response: \(String(describing: response))")
            self.reportSyncComplete(.error(.response(response)))
            return false
        }

        Log.debug(typeName(and: #function) + "Sending events failed with error: \(String(describing: error)) response: \(String(describing: response))")

        if isRetry {
            Log.debug(typeName(and: #function) + "dropping events due to failed retry")
            if let error = error {
                reportSyncComplete(.error(.request(error)))
            } else {
                reportSyncComplete(.error(.response(response)))
            }
            return false
        }

        return true
    }

    private func reportSyncComplete(_ result: EventSyncResult) {
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
