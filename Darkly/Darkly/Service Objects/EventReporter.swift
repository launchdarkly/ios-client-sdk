//
//  EventReporter.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/24/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

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
    
    private weak var eventReportTimer: Timer?
    var isReportingActive: Bool { return eventReportTimer != nil }

    init(config: LDConfig, service: DarklyServiceProvider) {
        self.config = config
        self.service = service
    }

    func record(_ event: Event, completion: CompletionClosure? = nil) {
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
        guard isOnline && !isReportingActive else {
            return
        }
        if #available(iOS 10.0, watchOS 3.0, macOS 10.12, *, tvOS 10.0) {
            eventReportTimer = Timer.scheduledTimer(withTimeInterval: config.eventFlushInterval, repeats: true) { [weak self] (_) in self?.reportEvents() }
        } else {
            // the run loop retains the timer, so eventReportTimer is weak to avoid the retain cycle. Setting the timer to a strong reference is important so that the timer doesn't get nil'd before added to the run loop.
            let timer = Timer(timeInterval: config.eventFlushInterval, target: self, selector: #selector(eventReportTimerFired), userInfo: nil, repeats: true)
            eventReportTimer = timer
            RunLoop.current.add(timer, forMode: RunLoop.Mode.default)
        }
    }
    
    private func stopReporting() {
        guard isReportingActive else {
            return
        }
        eventReportTimer?.invalidate()
        eventReportTimer = nil
    }

    @objc func eventReportTimerFired() {
        reportEvents(completion: nil)
    }

    func reportEvents() {
        reportEvents(completion: nil)
    }
    
    func reportEvents(completion: CompletionClosure?) {
        guard isOnline && (!eventStore.isEmpty || flagRequestTracker.hasLoggedRequests) else {
            if !isOnline {
                Log.debug(typeName(and: #function) + "aborted. EventReporter is offline")
            } else if eventStore.isEmpty && !flagRequestTracker.hasLoggedRequests {
                Log.debug(typeName(and: #function) + "aborted. Event store is empty")
            }
            completion?()
            return
        }
        Log.debug(typeName(and: #function, appending: " - ") + "starting")

        recordSummaryEvent {
            self.publish(self.eventStore, completion: completion)
        }
    }

    private func publish(_ eventDictionaries: [[String: Any]], completion: CompletionClosure?) {
        self.service.publishEventDictionaries(eventDictionaries) { serviceResponse in
            self.processEventResponse(reportedEventDictionaries: eventDictionaries, serviceResponse: serviceResponse, completion: completion)
        }
    }
    
    private func processEventResponse(reportedEventDictionaries: [[String: Any]], serviceResponse: ServiceResponse, completion: CompletionClosure?) {
        defer {
            DispatchQueue.main.async {
                completion?()
            }
        }
        guard serviceResponse.error == nil else {
            report(serviceResponse.error)
            return
        }
        guard let httpResponse = serviceResponse.urlResponse as? HTTPURLResponse,
            httpResponse.statusCode == HTTPURLResponse.StatusCodes.accepted
        else {
            report(serviceResponse.urlResponse)
            return
        }
        lastEventResponseDate = httpResponse.headerDate
        updateEventStore(reportedEventDictionaries: reportedEventDictionaries)
    }
    
    private func report(_ error: Error?) {
        Log.debug(typeName + ".reportEvents() " + "error: \(String(describing: error))")
        //TODO: Implement when error reporting architecture is established
    }
    
    private func report(_ response: URLResponse?) {
        Log.debug(typeName + ".reportEvents() " + "response: \(String(describing: response))")
        //TODO: Implement when error reporting architecture is established
    }
    
    private func updateEventStore(reportedEventDictionaries: [[String: Any]]) {
        eventQueue.async {
            let remainingEventDictionaries = self.eventStore.filter { (eventDictionary) in
                !reportedEventDictionaries.contains(eventDictionary)
            }
            self.eventStore = remainingEventDictionaries
            Log.debug(self.typeName + ".reportEvents() completed for keys: " + reportedEventDictionaries.eventKeys)
        }
    }
    
    private var isEventStoreFull: Bool { return eventStore.count >= config.eventCapacity}
}

extension EventReporter: TypeIdentifying { }

extension Array where Element == [String: Any] {
    var eventKeys: String {
        let keys = self.compactMap { (eventDictionary) in
            eventDictionary.eventKey
        }
        guard !keys.isEmpty else {
            return ""
        }
        return keys.joined(separator: ", ")
    }
}

#if DEBUG
    extension EventReporter {
        convenience init(config: LDConfig, service: DarklyServiceProvider, events: [Event], lastEventResponseDate: Date?, flagRequestTracker: FlagRequestTracker? = nil) {
            self.init(config: config, service: service)
            eventStore.append(contentsOf: events.dictionaryValues(config: config))
            self.lastEventResponseDate = lastEventResponseDate
            if let flagRequestTracker = flagRequestTracker {
                self.flagRequestTracker = flagRequestTracker
            }
        }

        func setFlagRequestTracker(_ tracker: FlagRequestTracker) {
            flagRequestTracker = tracker
        }
    }
#endif
