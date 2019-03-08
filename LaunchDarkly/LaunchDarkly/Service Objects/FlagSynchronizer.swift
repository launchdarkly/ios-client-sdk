//
//  FlagSynchronizer.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 7/24/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
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
    case isOffline
    case request(Error)
    case response(URLResponse?)
    case data(Data?)
    case event(DarklyEventSource.LDEvent?)

    var isClientUnauthorized: Bool {
        switch self {
        case .response(let urlResponse):
            guard let httpResponse = urlResponse as? HTTPURLResponse
            else {
                return false
            }
            return httpResponse.statusCode == HTTPURLResponse.StatusCodes.unauthorized
        case .event(let event):
            return event?.isUnauthorized ?? false
        default: return false
        }
    }
}

enum FlagSyncResult {
    case success([String: Any], DarklyEventSource.LDEvent.EventType?)
    case error(SynchronizingError)
}

typealias CompletionClosure = (() -> Void)
typealias FlagSyncCompleteClosure = ((FlagSyncResult) -> Void)

extension DarklyEventSource.LDEvent {
    enum EventType: String {
        case heartbeat = ":", ping, put, patch, delete
    }

    var eventType: EventType? {
        return EventType(rawValue: event ?? "")
    }

    var isUnauthorized: Bool {
        let error = self.error as NSError?
        return error?.domain == DarklyEventSource.LDEventSourceErrorDomain && error?.code == -HTTPURLResponse.StatusCodes.unauthorized
    }
}

class FlagSynchronizer: LDFlagSynchronizing {
    struct Constants {
        fileprivate static let queueName = "LaunchDarkly.FlagSynchronizer.syncQueue"
    }

    let service: DarklyServiceProvider
    private var eventSource: DarklyStreamingProvider?
    private var flagRequestTimer: TimeResponding?
    var onSyncComplete: FlagSyncCompleteClosure?

    let streamingMode: LDStreamingMode
    
    var isOnline: Bool = false {
        didSet {
            Log.debug(typeName(and: #function, appending: ": ") + "\(isOnline)")
            configureCommunications()
        }
    }

    let pollingInterval: TimeInterval
    let useReport: Bool
    
    var streamingActive: Bool {
        return eventSource != nil
    }
    var pollingActive: Bool {
        return flagRequestTimer != nil
    }
    private var syncQueue = DispatchQueue(label: Constants.queueName, qos: .utility)

    init(streamingMode: LDStreamingMode, pollingInterval: TimeInterval, useReport: Bool, service: DarklyServiceProvider, onSyncComplete: FlagSyncCompleteClosure?) {
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
            if !isOnline {
                reason = "Flag Synchronizer is offline."
            }
            if reason.isEmpty && streamingMode != .streaming {
                reason = "Flag synchronizer is not set for streaming."
            }
            if reason.isEmpty && streamingActive {
                reason  = "Clientstream already connected."
            }
            Log.debug(typeName(and: #function) + "aborted. " + reason)
            return
        }
        Log.debug(typeName(and: #function))
        eventSource = service.createEventSource(useReport: useReport)  //The LDConfig.connectionTimeout should NOT be set here. Heartbeat is sent every 3m. ES default timeout is 5m. This is an async operation.
        //LDEventSource reacts to connection errors by closing the connection and establishing a new one after an exponentially increasing wait. That makes it self healing.
        //While we could keep the LDEventSource state, there's not much we can do to help it connect. If it can't connect, it's likely we won't be able to poll the server either...so it seems best to just do nothing and let it heal itself.
        eventSource?.onMessageEvent { [weak self] (event) in
            self?.process(event)
        }
        eventSource?.onErrorEvent { [weak self] (event) in
            self?.process(event)
        }
        eventSource?.open()
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
        //Because this method is called asynchronously by the LDEventSource, need to check these conditions prior to processing the event.
        if !isOnline {
            Log.debug(typeName(and: #function) + "aborted. " + "Flag Synchronizer is offline.")
            reportSyncComplete(.error(.isOffline))
            return
        }
        if streamingMode == .polling {
            Log.debug(typeName(and: #function) + "aborted. " + "Flag Synchronizer is in polling mode.")
            reportSyncComplete(.error(.event(event)))
            return
        }
        if !streamingActive {
            //Since eventSource.close() is async, this prevents responding to events after .close() is called, but before it's actually closed
            Log.debug(typeName(and: #function) + "aborted. " + "Clientstream is not active.")
            reportSyncComplete(.error(.isOffline))
            return
        }
        guard let event = event
        else {
            Log.debug(typeName(and: #function) + "aborted. No streaming event.")
            reportSyncComplete(.error(.event(nil)))
            return
        }
        //NOTE: It is possible that an LDEventSource was replaced and the event reported here is from the previous eventSource. However there is no information about the eventSource in the LDEvent to do anything about it.
        if event.error != nil {
            Log.debug(typeName(and: #function) + "aborted. Streaming event reported an error. event: \(event)")
            reportSyncComplete(.error(.event(event)))
            return
        }
        guard let eventType = event.eventType
        else {
            Log.debug(typeName(and: #function) + "aborted. Unknown event type.")
            reportSyncComplete(.error(.event(event)))
            return
        }

        switch eventType {
        case .ping: makeFlagRequest()
        case .put, .patch, .delete: process(event, eventType: eventType)
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
            if reason.isEmpty && streamingMode != .polling {
                reason = "Flag synchronizer is not set for polling."
            }
            if reason.isEmpty && pollingActive {
                reason  = "Polling already active."
            }
            Log.debug(typeName(and: #function) + "aborted. " + reason)
            return
        }
        Log.debug(typeName(and: #function))
        flagRequestTimer = LDTimer(withTimeInterval: pollingInterval, repeats: true, fireQueue: syncQueue, execute: processTimer)
        makeFlagRequest()
    }
    
    private func stopPolling() {
        guard pollingActive else {
            Log.debug(typeName(and: #function) + "aborted. Polling already inactive.")
            return
        }
        Log.debug(typeName(and: #function))
        flagRequestTimer?.cancel()
        flagRequestTimer = nil
    }
    
    @objc private func processTimer() {
        makeFlagRequest()
    }
    
    // MARK: Flag Request
    
    private func makeFlagRequest() {
        guard isOnline
        else {
            Log.debug(typeName(and: #function) + "aborted. Flag Synchronizer is offline.")
            reportSyncComplete(.error(.isOffline))
            return
        }
        Log.debug(typeName(and: #function, appending: " - ") + "starting")
        let context = (useReport: useReport,
                       logPrefix: typeName(and: #function, appending: " - "))
        service.getFeatureFlags(useReport: useReport, completion: { [weak self] (serviceResponse) in
            if FlagSynchronizer.shouldRetryFlagRequest(useReport: context.useReport, statusCode: (serviceResponse.urlResponse as? HTTPURLResponse)?.statusCode) {
                Log.debug(context.logPrefix + "retrying via GET")
                self?.service.getFeatureFlags(useReport: false, completion: { (retryServiceResponse) in
                    self?.processFlagResponse(serviceResponse: retryServiceResponse)
                })
            } else {
                self?.processFlagResponse(serviceResponse: serviceResponse)
            }
            Log.debug(context.logPrefix + "complete")
        })
    }

    private class func shouldRetryFlagRequest(useReport: Bool, statusCode: Int?) -> Bool {
        guard let statusCode = statusCode
        else {
            return false
        }
        return useReport && LDConfig.isReportRetryStatusCode(statusCode)
    }

    private func processFlagResponse(serviceResponse: ServiceResponse) {
        if let serviceResponseError = serviceResponse.error {
            Log.debug(typeName(and: #function) + "error: \(serviceResponseError)")
            reportSyncComplete(.error(.request(serviceResponseError)))
            return
        }
        guard let httpResponse = serviceResponse.urlResponse as? HTTPURLResponse,
            httpResponse.statusCode == HTTPURLResponse.StatusCodes.ok
        else {
            Log.debug(typeName(and: #function) + "response: \(String(describing: serviceResponse.urlResponse))")
            reportSyncComplete(.error(.response(serviceResponse.urlResponse)))
            return
        }
        guard let data = serviceResponse.data,
            let flags = try? JSONSerialization.jsonDictionary(with: data, options: .allowFragments)
        else {
            reportDataError(serviceResponse.data)
            return
        }
        reportSuccess(flagDictionary: flags, eventType: streamingActive ? .ping : nil)
    }

    private func reportSuccess(flagDictionary: [String: Any], eventType: DarklyEventSource.LDEvent.EventType?) {
        Log.debug(typeName(and: #function) + "flagDictionary: \(flagDictionary)" + (eventType == nil ? "" : ", eventType: \(String(describing: eventType))"))
        reportSyncComplete(.success(flagDictionary, streamingActive ? eventType : nil))
    }
    
    private func reportDataError(_ data: Data?) {
        Log.debug(typeName(and: #function) + "data: \(String(describing: data))")
        reportSyncComplete(.error(.data(data)))
    }

    private func reportSyncComplete(_ result: FlagSyncResult) {
        guard let onSyncComplete = onSyncComplete
        else {
            return
        }
        DispatchQueue.main.async {
            onSyncComplete(result)
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

#if DEBUG
extension FlagSynchronizer {
    var testEventSource: DarklyStreamingProvider? {
        set {
            eventSource = newValue
        }
        get {
            return eventSource
        }
    }

    func testMakeFlagRequest() {
        makeFlagRequest()
    }

    func testProcessEvent(_ event: DarklyEventSource.LDEvent?) {
        process(event)
    }
}
#endif
