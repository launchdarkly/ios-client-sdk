//
//  LDEventReporter.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/24/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

//sourcery: AutoMockable
protocol LDEventReporting {
    //sourcery: DefaultMockValue = LDConfig.stub
    var config: LDConfig { get set }
    //sourcery: DefaultMockValue = false
    var isOnline: Bool { get set }
    //sourcery: DefaultMockValue = DarklyServiceMock()
    var service: DarklyServiceProvider { get set }
    func record(_ event: LDEvent, completion: CompletionClosure?)
    //sourcery: NoMock
    func record(_ event: LDEvent)

    func reportEvents()
}

extension LDEventReporting {
    //sourcery: NoMock
    func record(_ event: LDEvent) {
        record(event, completion: nil)
    }
}

class LDEventReporter: LDEventReporting {
    fileprivate struct Constants {
        static let eventQueueLabel = "com.launchdarkly.eventSyncQueue"
    }
    
    var config: LDConfig {
        didSet {
            isOnline = false
        }
    }
    private let eventQueue = DispatchQueue(label: Constants.eventQueueLabel, qos: .userInitiated)
    var isOnline: Bool = false {
        didSet { isOnline ? startReporting() : stopReporting() }
    }

    private let mobileKey: String
    var service: DarklyServiceProvider
    private(set) var eventStore = [LDEvent]()
    
    private weak var eventReportTimer: Timer?
    var isReportingActive: Bool { return eventReportTimer != nil }

    init(mobileKey: String, config: LDConfig, service: DarklyServiceProvider) {
        self.mobileKey = mobileKey
        self.config = config
        self.service = service
    }

    func record(_ event: LDEvent, completion: CompletionClosure? = nil) {
        eventQueue.async {
            if let completion = completion {
                defer {
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            }
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
        //TODO: Do we need to resume the eventQueue too?
        reportEvents()
    }
    
    private func stopReporting() {
        guard isReportingActive else { return }
        eventReportTimer?.invalidate()
        eventReportTimer = nil
        //TODO: Do we need to suspend the eventQueue too?
    }
    
    @objc func reportEvents() {
        guard isOnline && !eventStore.isEmpty else { return }
        let reportedEvents = eventStore //this is async, so keep what we're reporting at this time for later use
        service.publishEvents(eventStore) { serviceResponse in
            self.processEventResponse(reportedEvents: reportedEvents, serviceResponse: serviceResponse)
        }
    }
    
    private func processEventResponse(reportedEvents: [LDEvent], serviceResponse: ServiceResponse) {
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
        updateEventStore(reportedEvents: reportedEvents)
    }
    
    private func report(_ error: Error?) {
        //TODO: Implement when error reporting architecture is established
    }
    
    private func report(_ response: URLResponse?) {
        //TODO: Implement when error reporting architecture is established
    }
    
    private func updateEventStore(reportedEvents: [LDEvent]) {
        eventQueue.async {
            var updatedEvents = reportedEvents
            updatedEvents.forEach { (reportedEvent) in updatedEvents.remove(reportedEvent) }
            self.eventStore = updatedEvents
        }
    }
    
    private var isEventStoreFull: Bool { return eventStore.count >= config.eventCapacity}
}
