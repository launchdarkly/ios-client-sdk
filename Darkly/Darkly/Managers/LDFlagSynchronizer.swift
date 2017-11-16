//
//  LDFlagSynchronizer.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/24/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation
import Dispatch
import DarklyEventSource

//sourcery: AutoMockable
protocol LDFlagSynchronizing {
    //sourcery: DefaultMockValue = .streaming
    var streamingMode: LDStreamingMode { get }
    //sourcery: DefaultMockValue = false
    var isOnline: Bool { get set }
    //sourcery: DefaultMockValue = 0.0
    var pollingInterval: TimeInterval { get }
}

class LDFlagSynchronizer: LDFlagSynchronizing {
    enum Event: String {
        //swiftlint:disable:next identifier_name
        case ping, put, patch, delete
    }
    
    private let mobileKey: String
    private let service: DarklyServiceProvider
    private let flagStore: LDFlagMaintaining
    private var eventSource: DarklyStreamingProvider?
    private weak var flagRequestTimer: Timer?
    private var flagRequestCompletion: (() -> Void)?
    
    let streamingMode: LDStreamingMode
    
    var isOnline: Bool = false {
        didSet {
            configureCommunications()
        }
    }

    let pollingInterval: TimeInterval
    
    var streamingActive: Bool { return eventSource != nil }
    var pollingActive: Bool { return flagRequestTimer != nil }
    
    init(mobileKey: String, streamingMode: LDStreamingMode, pollingInterval: TimeInterval, service: DarklyServiceProvider, store: LDFlagMaintaining) {
        self.mobileKey = mobileKey
        self.streamingMode = streamingMode
        self.pollingInterval = pollingInterval
        self.service = service
        self.flagStore = store
        
        configureCommunications()
    }
    
    private func configureCommunications() {
        if isOnline {
            switch streamingMode {
            case .streaming:
                stopPolling()
                startEventSource()
            case .polling:
                stopEventSource()
                startPolling()
            }
        } else {
            stopEventSource()
            stopPolling()
        }
    }
    
    // MARK: Streaming
    
    private func startEventSource() {
        guard isOnline,
            streamingMode == .streaming,
            !streamingActive
        else { return }
        eventSource = service.createEventSource()  //The LDConfig.connectionTimeout should NOT be set here. Heartbeat is sent every 3m. ES default timeout is 5m. This is an async operation.
        //LDEventSource waits 1s before attempting the connection, providing time to set handlers.
        //LDEventSource reacts to connection errors by closing the connection and establishing a new one after an exponentially increasing wait. That makes it self healing.
        //While we could keep the LDEventSource state, there's not much we can do to help it connect. If it can't connect, it's likely we won't be able to poll the server either...so it seems best to just do nothing and let it heal itself.
        eventSource?.onMessageEvent { [weak self] (event) in
            self?.process(event)
        }
    }
    
    private func stopEventSource() {
        guard streamingActive else { return }
        eventSource?.close() //This is an async operation.
        eventSource = nil
    }
    
    private func process(_ event: DarklyEventSource.LDEvent?) {
        guard streamingActive,
            let event = event
        else { return }    //Since eventSource.close() is async, this prevents responding to events after .close() is called, but before it's actually closed
        //NOTE: It is possible that an LDEventSource was replaced and the event reported here is from the previous eventSource. However there is no information about the eventSource in the LDEvent to do anything about it.

        switch event.event {
        case Event.ping.rawValue: makeFlagRequest()
        //TODO: Add put, patch, & delete
        default: break
        }
    }
    
    // MARK: Polling
    
    private func startPolling() {
        guard isOnline,
            streamingMode == .polling,
            !pollingActive
            else { return }
        if #available(iOS 10.0, *) {
            flagRequestTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] (_) in self?.processTimer() }
        } else {
            // the run loop retains the timer, so eventReportTimer is weak to avoid a retain cycle. Setting the timer to a strong reference is important so that the timer doesn't get nil'd before it's added to the run loop.
            let timer = Timer(timeInterval: pollingInterval, target: self, selector: #selector(processTimer), userInfo: nil, repeats: true)
            flagRequestTimer = timer
            RunLoop.current.add(timer, forMode: .defaultRunLoopMode)
        }
        makeFlagRequest()
    }
    
    private func stopPolling() {
        guard pollingActive else { return }
        flagRequestTimer?.invalidate()
        flagRequestTimer = nil
    }
    
    @objc private func processTimer() {
        makeFlagRequest()
    }
    
    // MARK: Flag Request
    
    //TODO: When the flag response callback engine is implemented, refactor this to pass it the completion closure
    func requestFlags(completion: (() -> Void)? = nil) {
        flagRequestCompletion = completion
        makeFlagRequest()
    }

    private func makeFlagRequest() {
        guard isOnline else { return }
        service.getFeatureFlags(completion: { serviceResponse in
            self.processFlagResponse(serviceResponse: serviceResponse)
        })
    }

    private func processFlagResponse(serviceResponse: ServiceResponse) {
        defer {
            flagRequestCompletion = nil
        }
        guard serviceResponse.error == nil else {
            report(serviceResponse.error)
            return
        }
        guard let httpResponse = serviceResponse.urlResponse as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            report(serviceResponse.urlResponse)
            return
        }
        guard let data = serviceResponse.data,
            let flags = try? JSONSerialization.jsonDictionary(with: data, options: .allowFragments)
        else {
            reportDataError()
            return
        }
        
        flagStore.replaceStore(newFlags: flags, source: .server)
        flagRequestCompletion?()
    }
    
    private func report(_ error: Error?) {
        //TODO: Implement when error reporting architecture is established
    }
    
    private func report(_ response: URLResponse?) {
        //TODO: Implement when error reporting architecture is established
    }
    
    private func reportDataError() {
        //TODO: Implement when error reporting architecture is established
    }
    
    //sourcery: NoMock
    deinit {
        stopEventSource()
        stopPolling()
    }
}
