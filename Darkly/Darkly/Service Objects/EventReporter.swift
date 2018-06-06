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
    //sourcery: DefaultMockValue = DarklyServiceMock()
    var service: DarklyServiceProvider { get set }
    func record(_ event: Event, completion: CompletionClosure?)
    //sourcery: NoMock
    func record(_ event: Event)

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

    var service: DarklyServiceProvider
    private(set) var eventStore = [[String: Any]]()
    
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
    
    private func startReporting() {
        guard isOnline && !isReportingActive else { return }
        if #available(iOS 10.0, watchOS 3.0, macOS 10.12, *) {
            eventReportTimer = Timer.scheduledTimer(withTimeInterval: config.eventFlushInterval, repeats: true) { [weak self] (_) in self?.reportEvents() }
        } else {
            // the run loop retains the timer, so eventReportTimer is weak to avoid the retain cycle. Setting the timer to a strong reference is important so that the timer doesn't get nil'd before added to the run loop.
            let timer = Timer(timeInterval: config.eventFlushInterval, target: self, selector: #selector(reportEvents), userInfo: nil, repeats: true)
            eventReportTimer = timer
            RunLoop.current.add(timer, forMode: .defaultRunLoopMode)
        }
        reportEvents()
    }
    
    private func stopReporting() {
        guard isReportingActive else { return }
        eventReportTimer?.invalidate()
        eventReportTimer = nil
    }
    
    @objc func reportEvents() {
        guard isOnline && !eventStore.isEmpty else {
            if !isOnline { Log.debug(typeName(and: #function) + "aborted. EventReporter is offline") }
            else if eventStore.isEmpty { Log.debug(typeName(and: #function) + "aborted. Event store is empty") }
            return
        }
        Log.debug(typeName(and: #function, appending: " - ") + "starting")
        let reportedEventDictionaries = eventStore //this is async, so keep what we're reporting at this time for later use
        service.publishEventDictionaries(eventStore) { serviceResponse in
            self.processEventResponse(reportedEventDictionaries: reportedEventDictionaries, serviceResponse: serviceResponse)
        }
    }
    
    private func processEventResponse(reportedEventDictionaries: [[String: Any]], serviceResponse: ServiceResponse) {
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
            let remainingEventDictionaries = self.eventStore.filter { (eventDictionary) in !reportedEventDictionaries.contains(eventDictionary) }
            self.eventStore = remainingEventDictionaries
            Log.debug(self.typeName + ".reportEvents() completed for keys: " + reportedEventDictionaries.eventKeys)
        }
    }
    
    private var isEventStoreFull: Bool { return eventStore.count >= config.eventCapacity}
}

extension EventReporter: TypeIdentifying { }

extension Array where Element == [String: Any] {
    var eventKeys: String {
        let keys = self.flatMap { (eventDictionary) in eventDictionary.eventKey }
        guard !keys.isEmpty else { return "" }
        return keys.joined(separator: ", ")
    }
}
