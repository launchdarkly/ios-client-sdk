//
//  LDEventReporter.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/24/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

class LDEventReporter {
    fileprivate struct Constants {
        static let eventQueueLabel = "com.launchdarkly.eventSyncQueue"
        static let statusCodeAccepted = 202
    }
    
    private let config: LDConfig
    private let eventQueue = DispatchQueue(label: Constants.eventQueueLabel, qos: .userInitiated)
    var isOnline: Bool {
        didSet { isOnline ? startReporting() : stopReporting() }
    }

    private let mobileKey: String
    private let service: DarklyServiceProvider
    private(set) var eventStore = [LDarklyEvent]()
    
    private weak var eventReportTimer: Timer?
    var isReportingActive: Bool { return eventReportTimer != nil }

    init(mobileKey: String, config: LDConfig, events: [LDarklyEvent]? = nil, service: DarklyServiceProvider) {
        self.mobileKey = mobileKey
        self.config = config
        self.service = service

        if let events = events, !events.isEmpty {
            eventStore.append(contentsOf: events)
        }
        
        self.isOnline = config.launchOnline
        if isOnline { startReporting() }
    }

    func record(_ event: LDarklyEvent) {
        eventQueue.async {
            guard !self.isEventStoreFull else { return }
            self.eventStore.append(event)
        }
    }
    
    private func startReporting() {
        guard isOnline && !isReportingActive else { return }
        if #available(iOS 10.0, *) {
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
        guard isOnline && !eventStore.isEmpty else { return }
        let reportedEvents = eventStore //this is async, so keep what we're reporting at this time for later use
        service.publishEvents(eventStore) { serviceResponse in
            self.processEventResponse(reportedEvents: reportedEvents, serviceResponse: serviceResponse)
        }
    }
    
    private func processEventResponse(reportedEvents: [LDarklyEvent], serviceResponse: ServiceResponse) {
        guard serviceResponse.error == nil else {
            report(serviceResponse.error)
            return
        }
        guard let httpResponse = serviceResponse.urlResponse as? HTTPURLResponse,
            httpResponse.statusCode == Constants.statusCodeAccepted
        else {
            report(serviceResponse.urlResponse)
            return
        }
        updateEventStore(reportedEvents: reportedEvents)
    }
    
    private func report(_ error: Error?) {
        //TODO: Implement when error reporting architecture is established
    }
    
    private func report(_ response: URLResponse?) {
        //TODO: Implement when error reporting architecture is established
    }
    
    private func updateEventStore(reportedEvents: [LDarklyEvent]) {
        eventQueue.async {
            var updatedEvents = reportedEvents
            updatedEvents.forEach { (reportedEvent) in updatedEvents.removeEvent(reportedEvent) }
            self.eventStore = updatedEvents
        }
    }
    
    private var isEventStoreFull: Bool { return eventStore.count >= config.eventCapacity}
}
