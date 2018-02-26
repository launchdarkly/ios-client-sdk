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
    //sourcery: DefaultMockValue = false
    var isOnline: Bool { get set }
}

enum SynchronizingError: Error {
    case request(Error)
    case response(URLResponse?)
    case data(Data?)

    var isClientUnauthorized: Bool {
        guard case let .response(urlResponse) = self,
            let httpResponse = urlResponse as? HTTPURLResponse
        else { return false }
        return httpResponse.statusCode == HTTPURLResponse.StatusCodes.unauthorized
    }
}

enum SyncResult {
    case success([String: Any])
    case error(SynchronizingError)
}

typealias CompletionClosure = (() -> Void)
typealias SyncCompleteClosure = ((SyncResult) -> Void)

extension DarklyEventSource.LDEvent {
    enum EventType: String {
        case heartbeat = ":", ping, put, patch, delete
    }
}

class LDFlagSynchronizer: LDFlagSynchronizing {
    let service: DarklyServiceProvider
    private var eventSource: DarklyStreamingProvider?
    private weak var flagRequestTimer: Timer?
    var onSyncComplete: SyncCompleteClosure?

    let streamingMode: LDStreamingMode
    
    var isOnline: Bool = false {
        didSet {
            configureCommunications()
        }
    }

    let pollingInterval: TimeInterval
    let useReport: Bool
    
    var streamingActive: Bool { return eventSource != nil }
    var pollingActive: Bool { return flagRequestTimer != nil }
    
    init(streamingMode: LDStreamingMode, pollingInterval: TimeInterval, useReport: Bool, service: DarklyServiceProvider, onSyncComplete: SyncCompleteClosure?) {
        self.streamingMode = streamingMode
        self.pollingInterval = pollingInterval
        self.useReport = useReport
        self.service = service
        self.onSyncComplete = onSyncComplete

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
            let event = event?.event
        else { return }    //Since eventSource.close() is async, this prevents responding to events after .close() is called, but before it's actually closed
        //NOTE: It is possible that an LDEventSource was replaced and the event reported here is from the previous eventSource. However there is no information about the eventSource in the LDEvent to do anything about it.

        switch event {
        case DarklyEventSource.LDEvent.EventType.ping.rawValue: makeFlagRequest()
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
    
    private func makeFlagRequest() {
        guard isOnline else { return }
        service.getFeatureFlags(useReport: useReport, completion: { serviceResponse in
            if self.shouldRetryFlagRequest(useReport: self.useReport, statusCode: (serviceResponse.urlResponse as? HTTPURLResponse)?.statusCode) {
                self.service.getFeatureFlags(useReport: false, completion: { (retryServiceResponse) in
                    self.processFlagResponse(serviceResponse: retryServiceResponse)
                })
            } else {
                self.processFlagResponse(serviceResponse: serviceResponse)
            }
        })
    }

    private func shouldRetryFlagRequest(useReport: Bool, statusCode: Int?) -> Bool {
        guard let statusCode = statusCode else { return false }
        return useReport && LDConfig.isReportRetryStatusCode(statusCode)
    }

    private func processFlagResponse(serviceResponse: ServiceResponse) {
        if let serviceResponseError = serviceResponse.error {
            report(serviceResponseError)
            return
        }
        guard let httpResponse = serviceResponse.urlResponse as? HTTPURLResponse,
            httpResponse.statusCode == HTTPURLResponse.StatusCodes.ok
        else {
            report(serviceResponse.urlResponse)
            return
        }
        guard let data = serviceResponse.data,
            let flags = try? JSONSerialization.jsonDictionary(with: data, options: .allowFragments)
        else {
            reportDataError(serviceResponse.data)
            return
        }
        guard let onSyncComplete = self.onSyncComplete else { return }
        DispatchQueue.main.async {
            onSyncComplete(.success(flags))
        }
    }
    
    private func report(_ error: Error) {
        guard let onSyncComplete = self.onSyncComplete else { return }
        DispatchQueue.main.async {
            onSyncComplete(.error(.request(error)))
        }
    }
    
    private func report(_ response: URLResponse?) {
        guard let onSyncComplete = self.onSyncComplete else { return }
        DispatchQueue.main.async {
            onSyncComplete(.error(.response(response)))
        }
    }
    
    private func reportDataError(_ data: Data?) {
        guard let onSyncComplete = self.onSyncComplete else { return }
        DispatchQueue.main.async {
            onSyncComplete(.error(.data(data)))
        }
    }
    
    //sourcery: NoMock
    deinit {
        stopEventSource()
        stopPolling()
    }
}
