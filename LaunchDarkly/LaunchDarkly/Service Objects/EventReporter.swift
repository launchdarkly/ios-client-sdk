//
//  EventReporter.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 7/24/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

enum EventSyncResult {
    case success([[String: Any]])
    case error(SynchronizingError)
}

typealias EventSyncCompleteClosure = ((EventSyncResult) -> Void)

//sourcery: AutoMockable
protocol EventReporting {
    //sourcery: DefaultMockValue = LDConfig.stub
    var config: LDConfig { get set }
    //sourcery: DefaultMockValue = false
    var isOnline: Bool { get set }
    //sourcery: DefaultMockValue = nil
    var lastEventResponseDate: Date? { get }
    //sourcery: DefaultMockValue = DarklyServiceMock()
    var service: DarklyServiceProvider { get set }
    func record(_ event: Event, completion: CompletionClosure?)
    //sourcery: NoMock
    func record(_ event: Event)
    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: Any?, defaultValue: Any?, featureFlag: FeatureFlag?, user: LDUser)
    func recordSummaryEvent()
    func resetFlagRequestTracker()

    func reportEvents()
}

extension EventReporting {
    //sourcery: NoMock
    func record(_ event: Event) {
        record(event, completion: nil)
    }
}

class EventReporter: EventReporting {
    fileprivate struct Constants {
        static let eventQueueLabel = "com.launchdarkly.eventSyncQueue"
    }
    
    var config: LDConfig {
        didSet {
            Log.debug(typeName(and: #function, appending: ": ") + "\(config)")
            isOnline = false
        }
    }
    private let eventQueue = DispatchQueue(label: Constants.eventQueueLabel, qos: .userInitiated)
    var isOnline: Bool = false {
        didSet {
            Log.debug(typeName(and: #function, appending: ": ") + "\(isOnline)")
            isOnline ? startReporting() : stopReporting()
        }
    }
    private (set) var lastEventResponseDate: Date? = nil

    var service: DarklyServiceProvider
    private(set) var eventStore = [[String: Any]]()
    private(set) var flagRequestTracker = FlagRequestTracker()
    
    private var eventReportTimer: TimeResponding?
    var isReportingActive: Bool {
        return eventReportTimer != nil
    }

    private let onSyncComplete: EventSyncCompleteClosure?

    init(config: LDConfig, service: DarklyServiceProvider, onSyncComplete: EventSyncCompleteClosure?) {
        self.config = config
        self.service = service
        self.onSyncComplete = onSyncComplete
    }

    func record(_ event: Event, completion: CompletionClosure? = nil) {
        //The eventReporter is created when the LDClient singleton is created, and kept for the app's lifetime. So while the use of self in the async block does setup a retain cycle, it's not going to cause a memory leak
        eventQueue.async {
            defer {
                DispatchQueue.main.async {
                    completion?()
                }
            }
            guard !self.isEventStoreFull
            else {
                Log.debug(self.typeName(and: #function) + "aborted. Event store is full")
                return
            }
            self.eventStore.append(event.dictionaryValue(config: self.config))
        }
    }
    
    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: Any?, defaultValue: Any?, featureFlag: FeatureFlag?, user: LDUser) {
        recordFlagEvaluationEvents(flagKey: flagKey, value: value, defaultValue: defaultValue, featureFlag: featureFlag, user: user, completion: nil)
    }

    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: Any?, defaultValue: Any?, featureFlag: FeatureFlag?, user: LDUser, completion: CompletionClosure? = nil) {

        let recordingFeatureEvent = featureFlag?.eventTrackingContext?.trackEvents == true
        let recordingDebugEvent = featureFlag?.eventTrackingContext?.shouldCreateDebugEvents(lastEventReportResponseTime: lastEventResponseDate) ?? false
        let dispatchGroup = DispatchGroup()

        //If flag requests come from multiple threads, record them one at a time in the event queue to keep the count from getting messed up in the tracker
        //Use the eventQueue so that when creating the summary event we get all the requests in the tracker before replacing it with a new tracker
        dispatchGroup.enter()
        eventQueue.async { [weak self] in
            self?.flagRequestTracker.trackRequest(flagKey: flagKey, reportedValue: value, featureFlag: featureFlag, defaultValue: defaultValue)
            dispatchGroup.leave()
        }

        if recordingFeatureEvent {
            let featureEvent = Event.featureEvent(key: flagKey, value: value, defaultValue: defaultValue, featureFlag: featureFlag, user: user)
            dispatchGroup.enter()
            record(featureEvent) {
                dispatchGroup.leave()
            }
        }

        if recordingDebugEvent, let featureFlag = featureFlag {
            let debugEvent = Event.debugEvent(key: flagKey, value: value, defaultValue: defaultValue, featureFlag: featureFlag, user: user)
            dispatchGroup.enter()
            record(debugEvent) {
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion?()
        }
    }

    func recordSummaryEvent() {
        recordSummaryEvent(completion: nil)
    }

    //This method is not intended for public use, as is hinted at by its absence from the EventReporting protocol. It helps testing the asynchronous method. Other type instances should not be concerned with responding to recording the summary event.
    func recordSummaryEvent(completion: CompletionClosure?) {
        if let summaryEvent = Event.summaryEvent(flagRequestTracker: flagRequestTracker) {
            resetFlagRequestTracker()
            record(summaryEvent) {
                completion?()
            }
            return
        }
        resetFlagRequestTracker()
        completion?()
    }

    func resetFlagRequestTracker() {
        flagRequestTracker = FlagRequestTracker()
    }

    private func startReporting() {
        guard isOnline && !isReportingActive
        else {
            return
        }
        eventReportTimer = LDTimer(withTimeInterval: config.eventFlushInterval, repeats: true, fireQueue: eventQueue, execute: reportEvents)
    }
    
    private func stopReporting() {
        guard isReportingActive
        else {
            return
        }
        eventReportTimer?.cancel()
        eventReportTimer = nil
    }

    func reportEvents() {
        guard isOnline
        else {
            Log.debug(typeName(and: #function) + "aborted. EventReporter is offline")
            reportSyncComplete(.error(.isOffline))
            return
        }
        guard !eventStore.isEmpty || flagRequestTracker.hasLoggedRequests
        else {
            Log.debug(typeName(and: #function) + "aborted. Event store is empty")
            reportSyncComplete(.success([[String: Any]]()))
            return
        }
        Log.debug(typeName(and: #function, appending: " - ") + "starting")

        //The eventReporter is created when the LDClient singleton is created, and kept for the app's lifetime. So while the use of self in the async block does setup a retain cycle, it's not going to cause a memory leak
        recordSummaryEvent {
            self.publish(self.eventStore)
        }
    }

    private func publish(_ eventDictionaries: [[String: Any]]) {
        //The eventReporter is created when the LDClient singleton is created, and kept for the app's lifetime. So while the use of self in the async block does setup a retain cycle, it's not going to cause a memory leak
        service.publishEventDictionaries(eventDictionaries) { serviceResponse in
            self.processEventResponse(reportedEventDictionaries: eventDictionaries, serviceResponse: serviceResponse)
        }
    }
    
    private func processEventResponse(reportedEventDictionaries: [[String: Any]], serviceResponse: ServiceResponse) {
        if let serviceResponseError = serviceResponse.error {
            Log.debug(typeName(and: #function) + "error: \(String(describing: serviceResponseError))")
            reportSyncComplete(.error(.request(serviceResponseError)))
            return
        }

        guard let httpResponse = serviceResponse.urlResponse as? HTTPURLResponse,
            httpResponse.statusCode == HTTPURLResponse.StatusCodes.accepted
        else {
            Log.debug(typeName(and: #function) + "response: \(String(describing: serviceResponse.urlResponse))")
            reportSyncComplete(.error(.response(serviceResponse.urlResponse)))
            return
        }
        lastEventResponseDate = httpResponse.headerDate
        updateEventStore(reportedEventDictionaries: reportedEventDictionaries)
        Log.debug(typeName(and: #function) + " completed for keys: " + reportedEventDictionaries.eventKeys)
        reportSyncComplete(.success(reportedEventDictionaries))
    }
    
    private func reportSyncComplete(_ result: EventSyncResult) {
        //The eventReporter is created when the LDClient singleton is created, and kept for the app's lifetime. So while the use of self in the async block does setup a retain cycle, it's not going to cause a memory leak
        guard let onSyncComplete = onSyncComplete
        else {
            return
        }
        DispatchQueue.main.async {
            onSyncComplete(result)
        }
    }
    
    private func updateEventStore(reportedEventDictionaries: [[String: Any]]) {
        //The eventReporter is created when the LDClient singleton is created, and kept for the app's lifetime. So while the use of self in the async block does setup a retain cycle, it's not going to cause a memory leak
        eventQueue.async {
            let remainingEventDictionaries = self.eventStore.filter { (eventDictionary) in
                !reportedEventDictionaries.contains(eventDictionary)
            }
            self.eventStore = remainingEventDictionaries
        }
    }
    
    private var isEventStoreFull: Bool {
        return eventStore.count >= config.eventCapacity
    }
}

extension EventReporter: TypeIdentifying { }

extension Array where Element == [String: Any] {
    var eventKeys: String {
        let keys = compactMap { (eventDictionary) in
            eventDictionary.eventKey
        }
        guard !keys.isEmpty
        else {
            return ""
        }
        return keys.joined(separator: ", ")
    }
}

#if DEBUG
    extension EventReporter {
        convenience init(config: LDConfig,
                         service: DarklyServiceProvider,
                         events: [Event],
                         lastEventResponseDate: Date?,
                         flagRequestTracker: FlagRequestTracker? = nil,
                         onSyncComplete: EventSyncCompleteClosure?) {
            self.init(config: config, service: service, onSyncComplete: onSyncComplete)
            eventStore.append(contentsOf: events.dictionaryValues(config: config))
            self.lastEventResponseDate = lastEventResponseDate
            if let flagRequestTracker = flagRequestTracker {
                self.flagRequestTracker = flagRequestTracker
            }
        }

        var testOnSyncComplete: EventSyncCompleteClosure? {
            return onSyncComplete
        }

        func add(_ events: [Event]) {
            eventStore.append(contentsOf: events.dictionaryValues(config: config))
        }

        func setFlagRequestTracker(_ tracker: FlagRequestTracker) {
            flagRequestTracker = tracker
        }
    }
#endif
