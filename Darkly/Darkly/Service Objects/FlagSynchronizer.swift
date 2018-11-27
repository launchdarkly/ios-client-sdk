//
//  FlagSynchronizer.swift
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
    //sourcery: DefaultMockValue = .streaming
    var streamingMode: LDStreamingMode { get }
    //sourcery: DefaultMockValue = 60_000
    var pollingInterval: TimeInterval { get }
}

enum SynchronizingError: Error {
    case request(Error)
    case response(URLResponse?)
    case data(Data?)
    case event(DarklyEventSource.LDEvent)

    var isClientUnauthorized: Bool {
        switch self {
        case .response(let urlResponse):
            guard let httpResponse = urlResponse as? HTTPURLResponse else { return false }
            return httpResponse.statusCode == HTTPURLResponse.StatusCodes.unauthorized
        case .event(let event): return event.isUnauthorized
        default: return false
        }
    }
}

enum SyncResult {
    case success([String: Any], DarklyEventSource.LDEvent.EventType?)
    case error(SynchronizingError)
}

typealias CompletionClosure = (() -> Void)
typealias SyncCompleteClosure = ((SyncResult) -> Void)

extension DarklyEventSource.LDEvent {
    enum EventType: String {
        case heartbeat = ":", ping, put, patch, delete
    }

    var isUnauthorized: Bool {
        let error = self.error as NSError?
        return error?.domain == DarklyEventSource.LDEventSourceErrorDomain && error?.code == -HTTPURLResponse.StatusCodes.unauthorized
    }
}

class FlagSynchronizer: LDFlagSynchronizing {
    let service: DarklyServiceProvider
    private var eventSource: DarklyStreamingProvider?
    private weak var flagRequestTimer: Timer?
    var onSyncComplete: SyncCompleteClosure?

    let streamingMode: LDStreamingMode
    
    var isOnline: Bool = false {
        didSet {
            Log.debug(typeName(and: #function, appending: ": ") + "\(isOnline)")
            configureCommunications()
        }
    }

    let pollingInterval: TimeInterval
    let useReport: Bool
    
    var streamingActive: Bool { return eventSource != nil }
    var pollingActive: Bool { return flagRequestTimer != nil }
    
    init(streamingMode: LDStreamingMode, pollingInterval: TimeInterval, useReport: Bool, service: DarklyServiceProvider, onSyncComplete: SyncCompleteClosure?) {
        Log.debug(FlagSynchronizer.typeName(and: #function) + "streamingMode: \(streamingMode), " + "pollingInterval: \(pollingInterval), " + "useReport: \(useReport)")
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
        else {
            var reason = ""
            if !isOnline { reason = "Flag Synchronizer is offline." }
            if reason.isEmpty && streamingMode != .streaming { reason = "Flag synchronizer is not set for streaming." }
            if reason.isEmpty && streamingActive { reason  = "Clientstream already connected." }
            Log.debug(typeName(and: #function) + "aborted. " + reason)
            return
        }
        Log.debug(typeName(and: #function))
        eventSource = service.createEventSource(useReport: useReport)  //The LDConfig.connectionTimeout should NOT be set here. Heartbeat is sent every 3m. ES default timeout is 5m. This is an async operation.
        //LDEventSource waits 1s before attempting the connection, providing time to set handlers.
        //LDEventSource reacts to connection errors by closing the connection and establishing a new one after an exponentially increasing wait. That makes it self healing.
        //While we could keep the LDEventSource state, there's not much we can do to help it connect. If it can't connect, it's likely we won't be able to poll the server either...so it seems best to just do nothing and let it heal itself.
        eventSource?.onMessageEvent { [weak self] (event) in
            self?.process(event)
        }
        eventSource?.onErrorEvent { [weak self] (event) in
            self?.process(event)
        }
    }
    
    private func stopEventSource() {
        guard streamingActive else {
            Log.debug(typeName(and: #function) + "aborted. Clientstream is not connected.")
            return
        }
        Log.debug(typeName(and: #function))
        eventSource?.close() //This is an async operation.
        eventSource = nil
    }
    
    private func process(_ event: DarklyEventSource.LDEvent?) {
        guard streamingActive,
            let event = event
        else {
            var reason = ""
            if !streamingActive { reason = "Clientstream is not active." }
            else { reason = "Event is nil." }
            Log.debug(typeName(and: #function) + "aborted. " + reason)
            return
        }    //Since eventSource.close() is async, this prevents responding to events after .close() is called, but before it's actually closed
        //NOTE: It is possible that an LDEventSource was replaced and the event reported here is from the previous eventSource. However there is no information about the eventSource in the LDEvent to do anything about it.
        guard let eventDescription = event.event, !eventDescription.isEmpty
        else {
            Log.debug(typeName(and: #function) + "aborted. Event Description is empty.")
            if event.error != nil { reportEventError(event) }
            return
        }

        Log.debug(typeName(and: #function) + "event: \(event)")
        switch eventDescription {
        case DarklyEventSource.LDEvent.EventType.ping.rawValue: makeFlagRequest()
        case DarklyEventSource.LDEvent.EventType.put.rawValue: process(event, eventType: .put)
        case DarklyEventSource.LDEvent.EventType.patch.rawValue: process(event, eventType: .patch)
        case DarklyEventSource.LDEvent.EventType.delete.rawValue: process(event, eventType: .delete)
        default: break
        }
    }

    private func process(_ event: DarklyEventSource.LDEvent, eventType: DarklyEventSource.LDEvent.EventType) {
        guard let data = event.data?.data(using: .utf8),
            let flagDictionary = try? JSONSerialization.jsonDictionary(with: data, options: .allowFragments)
        else {
            reportDataError(event.data?.data(using: .utf8))
            return
        }
        reportSuccess(flagDictionary: flagDictionary, eventType: eventType)
    }
    
    // MARK: Polling
    
    private func startPolling() {
        guard isOnline,
            streamingMode == .polling,
            !pollingActive
            else {
                var reason = ""
                if !isOnline { reason = "Flag Synchronizer is offline." }
                if reason.isEmpty && streamingMode != .polling { reason = "Flag synchronizer is not set for polling." }
                if reason.isEmpty && pollingActive { reason  = "Polling already active." }
                Log.debug(typeName(and: #function) + "aborted. " + reason)
                return
        }
        Log.debug(typeName(and: #function))
        if #available(iOS 10.0, watchOS 3.0, macOS 10.12, tvOS 10.0, *) {
            flagRequestTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] (_) in self?.processTimer() }
        } else {
            // the run loop retains the timer, so flagRequestTimer is weak to avoid a retain cycle. Setting the timer to a strong reference is important so that the timer doesn't get nil'd before it's added to the run loop.
            let timer = Timer(timeInterval: pollingInterval, target: self, selector: #selector(processTimer), userInfo: nil, repeats: true)
            flagRequestTimer = timer
            RunLoop.current.add(timer, forMode: RunLoop.Mode.default)
        }
        makeFlagRequest()
    }
    
    private func stopPolling() {
        guard pollingActive else {
            Log.debug(typeName(and: #function) + "aborted. Polling already inactive.")
            return
        }
        Log.debug(typeName(and: #function))
        flagRequestTimer?.invalidate()
        flagRequestTimer = nil
    }
    
    @objc private func processTimer() {
        makeFlagRequest()
    }
    
    // MARK: Flag Request
    
    private func makeFlagRequest() {
        guard isOnline else {
            Log.debug(typeName(and: #function) + "aborted. Flag Synchronizer is offline.")
            return
        }
        Log.debug(typeName(and: #function, appending: " - ") + "starting")
        service.getFeatureFlags(useReport: useReport, completion: { serviceResponse in
            if self.shouldRetryFlagRequest(useReport: self.useReport, statusCode: (serviceResponse.urlResponse as? HTTPURLResponse)?.statusCode) {
                Log.debug(self.typeName(and: #function, appending: " - ") + "retrying via GET")
                self.service.getFeatureFlags(useReport: false, completion: { (retryServiceResponse) in
                    self.processFlagResponse(serviceResponse: retryServiceResponse)
                })
            } else {
                self.processFlagResponse(serviceResponse: serviceResponse)
            }
            Log.debug(self.typeName(and: #function, appending: " - ") + "complete")
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
        reportSuccess(flagDictionary: flags, eventType: self.streamingActive ? .ping : nil)
    }

    private func reportSuccess(flagDictionary: [String: Any], eventType: DarklyEventSource.LDEvent.EventType?) {
        Log.debug(typeName(and: #function) + "flagDictionary: \(flagDictionary)" + (eventType == nil ? "" : ", eventType: \(String(describing: eventType))"))
        guard let onSyncComplete = self.onSyncComplete else { return }
        DispatchQueue.main.async {
            onSyncComplete(.success(flagDictionary, self.streamingActive ? eventType : nil))
        }
    }
    
    private func report(_ error: Error) {
        Log.debug(typeName(and: #function) + "error: \(error)")
        guard let onSyncComplete = self.onSyncComplete else { return }
        DispatchQueue.main.async {
            onSyncComplete(.error(.request(error)))
        }
    }
    
    private func report(_ response: URLResponse?) {
        Log.debug(typeName(and: #function) + "response: \(String(describing: response))")
        guard let onSyncComplete = self.onSyncComplete else { return }
        DispatchQueue.main.async {
            onSyncComplete(.error(.response(response)))
        }
    }
    
    private func reportDataError(_ data: Data?) {
        Log.debug(typeName(and: #function) + "data: \(String(describing: data))")
        guard let onSyncComplete = self.onSyncComplete else { return }
        DispatchQueue.main.async {
            onSyncComplete(.error(.data(data)))
        }
    }

    private func reportEventError(_ event: DarklyEventSource.LDEvent) {
        Log.debug(typeName(and: #function) + "event: \(event)")
        guard let onSyncComplete = self.onSyncComplete else { return }
        DispatchQueue.main.async {
            onSyncComplete(.error(.event(event)))
        }
    }
    
    //sourcery: NoMock
    deinit {
        onSyncComplete = nil
        stopEventSource()
        stopPolling()
    }
}

extension FlagSynchronizer: TypeIdentifying { }
