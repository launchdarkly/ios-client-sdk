//
//  FlagSynchronizer.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import Dispatch
import LDSwiftEventSource

// sourcery: autoMockable
protocol LDFlagSynchronizing {
    // sourcery: defaultMockValue = false
    var isOnline: Bool { get set }
    // sourcery: defaultMockValue = .streaming
    var streamingMode: LDStreamingMode { get }
    // sourcery: defaultMockValue = 60_000
    var pollingInterval: TimeInterval { get }
}

enum SynchronizingError: Error {
    case isOffline
    case request(Error)
    case response(URLResponse?)
    case data(Data?)
    case streamError(Error)
    case streamEventWhilePolling
    case unknownEventType(String)

    var isClientUnauthorized: Bool {
        switch self {
        case .response(let urlResponse):
            guard let httpResponse = urlResponse as? HTTPURLResponse
            else { return false }
            return httpResponse.statusCode == HTTPURLResponse.StatusCodes.unauthorized
        case .streamError(let error as UnsuccessfulResponseError):
            return error.responseCode == HTTPURLResponse.StatusCodes.unauthorized
        default: return false
        }
    }
}

enum FlagSyncResult {
    case success([String: Any], FlagUpdateType?)
    case upToDate
    case error(SynchronizingError)
}

typealias CompletionClosure = (() -> Void)
typealias FlagSyncCompleteClosure = ((FlagSyncResult) -> Void)

enum FlagUpdateType: String {
    case ping, put, patch, delete
}

class FlagSynchronizer: LDFlagSynchronizing, EventHandler {
    struct Constants {
        fileprivate static let queueName = "LaunchDarkly.FlagSynchronizer.syncQueue"
        static let didCloseEventSourceName = "didCloseEventSource"
    }

    let service: DarklyServiceProvider
    private var eventSource: DarklyStreamingProvider?
    private var flagRequestTimer: TimeResponding?
    var onSyncComplete: FlagSyncCompleteClosure?

    let streamingMode: LDStreamingMode

    var isOnline: Bool {
        get { isOnlineQueue.sync { _isOnline } }
        set {
            isOnlineQueue.sync {
                _isOnline = newValue
                Log.debug(typeName(and: #function, appending: ": ") + "\(_isOnline)")
                configureCommunications(isOnline: _isOnline)
            }
        }
    }

    private var _isOnline = false
    private var isOnlineQueue = DispatchQueue(label: "com.launchdarkly.FlagSynchronizer.isOnlineQueue")
    let pollingInterval: TimeInterval
    let useReport: Bool
    
    var streamingActive: Bool { eventSource != nil }
    var pollingActive: Bool { flagRequestTimer != nil }
    private var syncQueue = DispatchQueue(label: Constants.queueName, qos: .utility)
    private var eventSourceStarted: Date?

    init(streamingMode: LDStreamingMode, 
         pollingInterval: TimeInterval, 
         useReport: Bool, 
         service: DarklyServiceProvider,
         onSyncComplete: FlagSyncCompleteClosure?) {
        Log.debug(FlagSynchronizer.typeName(and: #function) + "streamingMode: \(streamingMode), " + "pollingInterval: \(pollingInterval), " + "useReport: \(useReport)")
        self.streamingMode = streamingMode
        self.pollingInterval = pollingInterval
        self.useReport = useReport
        self.service = service
        self.onSyncComplete = onSyncComplete
    }

    private func configureCommunications(isOnline: Bool) {
        if isOnline {
            switch streamingMode {
            case .streaming:
                stopPolling()
                startEventSource(isOnline: isOnline)
            case .polling:
                stopEventSource()
                startPolling(isOnline: isOnline)
            }
        } else {
            stopEventSource()
            stopPolling()
        }
    }

    // MARK: Streaming

    private func startEventSource(isOnline: Bool) {
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
        eventSourceStarted = Date()
        // The LDConfig.connectionTimeout should NOT be set here. Heartbeat is sent every 3m. ES default timeout is 5m. This is an async operation.
        // LDEventSource reacts to connection errors by closing the connection and establishing a new one after an exponentially increasing wait. That makes it self healing.
        // While we could keep the LDEventSource state, there's not much we can do to help it connect. If it can't connect, it's likely we won't be able to poll the server either...so it seems best to just do nothing and let it heal itself.
        eventSource = service.createEventSource(useReport: useReport, handler: self, errorHandler: eventSourceErrorHandler)
        eventSource?.start()
    }

    private func stopEventSource() {
        guard streamingActive else {
            Log.debug(typeName(and: #function) + "aborted. Clientstream is not connected.")
            return
        }
        Log.debug(typeName(and: #function))
        eventSource?.stop()
        eventSource = nil
    }

    // MARK: Polling

    private func startPolling(isOnline: Bool) {
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
        flagRequestTimer = LDTimer(withTimeInterval: pollingInterval, fireQueue: syncQueue, execute: processTimer)
        makeFlagRequest(isOnline: isOnline)
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
        makeFlagRequest(isOnline: isOnline)
    }

    // MARK: Flag Request

    private func makeFlagRequest(isOnline: Bool) {
        guard isOnline
        else {
            Log.debug(typeName(and: #function) + "aborted. Flag Synchronizer is offline.")
            reportSyncComplete(.error(.isOffline))
            return
        }
        Log.debug(typeName(and: #function, appending: " - ") + "starting")
        let context = (useReport: useReport,
                       logPrefix: typeName(and: #function, appending: " - "))
        service.getFeatureFlags(useReport: useReport) { [weak self] serviceResponse in
            if FlagSynchronizer.shouldRetryFlagRequest(useReport: context.useReport, statusCode: (serviceResponse.urlResponse as? HTTPURLResponse)?.statusCode) {
                Log.debug(context.logPrefix + "retrying via GET")
                self?.service.getFeatureFlags(useReport: false) { retryServiceResponse in
                    self?.processFlagResponse(serviceResponse: retryServiceResponse)
                }
            } else {
                self?.processFlagResponse(serviceResponse: serviceResponse)
            }
        }
    }

    private class func shouldRetryFlagRequest(useReport: Bool, statusCode: Int?) -> Bool {
        guard let statusCode = statusCode
        else { return false }
        return useReport && LDConfig.isReportRetryStatusCode(statusCode)
    }

    private func processFlagResponse(serviceResponse: ServiceResponse) {
        if let serviceResponseError = serviceResponse.error {
            Log.debug(typeName(and: #function) + "error: \(serviceResponseError)")
            reportSyncComplete(.error(.request(serviceResponseError)))
            return
        }
        if serviceResponse.urlResponse?.httpStatusCode == HTTPURLResponse.StatusCodes.notModified {
            reportSyncComplete(.upToDate)
            return
        }
        guard serviceResponse.urlResponse?.httpStatusCode == HTTPURLResponse.StatusCodes.ok
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

    private func reportSuccess(flagDictionary: [String: Any], eventType: FlagUpdateType?) {
        Log.debug(typeName(and: #function) + "flagDictionary: \(flagDictionary)" + (eventType == nil ? "" : ", eventType: \(String(describing: eventType))"))
        reportSyncComplete(.success(flagDictionary, streamingActive ? eventType : nil))
    }

    private func reportDataError(_ data: Data?) {
        Log.debug(typeName(and: #function) + "data: \(String(describing: data))")
        reportSyncComplete(.error(.data(data)))
    }

    private func reportSyncComplete(_ result: FlagSyncResult) {
        guard let onSyncComplete = onSyncComplete
        else { return }
        DispatchQueue.main.async {
            onSyncComplete(result)
        }
    }
    
    // sourcery: noMock
    deinit {
        onSyncComplete = nil
        stopEventSource()
        stopPolling()
    }

    func eventSourceErrorHandler(error: Error) -> ConnectionErrorAction {
        let now = Date()
        if let startedAt = eventSourceStarted?.millisSince1970 {
            let streamInit = DiagnosticStreamInit(timestamp: now.millisSince1970, durationMillis: Int(now.millisSince1970 - startedAt), failed: true)
            service.diagnosticCache?.addStreamInit(streamInit: streamInit)
        }
        eventSourceStarted = now

        guard let unsuccessfulResponseError = error as? UnsuccessfulResponseError
        else { return .proceed }
        // Now we know that we received an error HTTP response code
        let responseCode: Int = unsuccessfulResponseError.responseCode
        if (400..<500).contains(responseCode) && ![400, 408, 429].contains(responseCode) {
            // Not a invalid request, timeout, or too many requests error
            // We will not retry in this case
            reportSyncComplete(.error(.streamError(error)))
            return .shutdown
        }
        // Otherwise we will retry
        return .proceed
    }

    func shouldAbortStreamUpdate() -> Bool {
        // Because this method is called asynchronously by the LDEventSource, need to check these conditions prior to processing the event.
        if !isOnline {
            Log.debug(typeName(and: #function) + "aborted. " + "Flag Synchronizer is offline.")
            reportSyncComplete(.error(.isOffline))
            return true
        }
        if streamingMode == .polling {
            Log.debug(typeName(and: #function) + "aborted. " + "Flag Synchronizer is in polling mode.")
            reportSyncComplete(.error(.streamEventWhilePolling))
            return true
        }
        if !streamingActive {
            // Since eventSource.close() is async, this prevents responding to events after .close() is called, but before it's actually closed
            Log.debug(typeName(and: #function) + "aborted. " + "Clientstream is not active.")
            reportSyncComplete(.error(.isOffline))
            return true
        }
        return false
    }

    // MARK: EventHandler methods
    public func onOpened() {
        Log.debug(self.typeName(and: #function) + "EventSource opened")
        if let startedAt = eventSourceStarted?.millisSince1970 {
            let now = Date().millisSince1970
            let streamInit = DiagnosticStreamInit(timestamp: now, durationMillis: Int(now - startedAt), failed: false)
            service.diagnosticCache?.addStreamInit(streamInit: streamInit)
        }
    }

    public func onClosed() {
        Log.debug(self.typeName(and: #function) + "EventSource closed")
        NotificationCenter.default.post(name: Notification.Name(FlagSynchronizer.Constants.didCloseEventSourceName), object: nil)
    }

    public func onMessage(eventType: String, messageEvent: MessageEvent) {
        guard !shouldAbortStreamUpdate()
        else { return }

        let updateType: FlagUpdateType? = FlagUpdateType(rawValue: eventType)
        switch updateType {
        case .ping: makeFlagRequest(isOnline: isOnline)
        case .put, .patch, .delete:
            guard let data = messageEvent.data.data(using: .utf8),
                  let flagDictionary = try? JSONSerialization.jsonDictionary(with: data)
            else {
                reportDataError(messageEvent.data.data(using: .utf8))
                return
            }
            reportSuccess(flagDictionary: flagDictionary, eventType: updateType)
        case nil:
            Log.debug(typeName(and: #function) + "aborted. Unknown event type.")
            reportSyncComplete(.error(.unknownEventType(eventType)))
            return
        }
    }

    public func onComment(comment: String) {
    }

    public func onError(error: Error) {
        guard !shouldAbortStreamUpdate()
        else { return }

        Log.debug(typeName(and: #function) + "aborted. Streaming event reported an error. error: \(error)")
        reportSyncComplete(.error(.streamError(error)))
    }
}

extension FlagSynchronizer: TypeIdentifying { }

#if DEBUG
extension FlagSynchronizer {
    var testEventSource: DarklyStreamingProvider? {
        get { eventSource }
        set { eventSource = newValue }
    }

    func testMakeFlagRequest() {
        makeFlagRequest(isOnline: isOnline)
    }

    func testStreamOnOpened() {
        onOpened()
    }

    func testStreamOnClosed() {
        onClosed()
    }

    func testStreamOnMessage(event: String, messageEvent: MessageEvent) {
        onMessage(eventType: event, messageEvent: messageEvent)
    }

    func testStreamOnError(error: Error) {
        onError(error: error)
    }
}

#endif
