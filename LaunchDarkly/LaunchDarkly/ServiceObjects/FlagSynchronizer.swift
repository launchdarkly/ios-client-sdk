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
    case flagCollection(FeatureFlagCollection)
    case patch(FeatureFlag)
    case delete(DeleteResponse)
    case upToDate
    case error(SynchronizingError)
}

struct DeleteResponse: Decodable {
    let key: String
    let version: Int?
}

typealias CompletionClosure = (() -> Void)
typealias FlagSyncCompleteClosure = ((FlagSyncResult) -> Void)

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
        guard eventSource == nil
        else { return Log.debug(typeName(and: #function) + "aborted. Clientstream already connected.") }

        Log.debug(typeName(and: #function))
        eventSourceStarted = Date()
        // The LDConfig.connectionTimeout should NOT be set here. Heartbeat is sent every 3m. ES default timeout is 5m. This is an async operation.
        // LDEventSource reacts to connection errors by closing the connection and establishing a new one after an exponentially increasing wait. That makes it self healing.
        // While we could keep the LDEventSource state, there's not much we can do to help it connect. If it can't connect, it's likely we won't be able to poll the server either...so it seems best to just do nothing and let it heal itself.
        eventSource = service.createEventSource(useReport: useReport, handler: self, errorHandler: eventSourceErrorHandler)
        eventSource?.start()
    }

    private func stopEventSource() {
        guard eventSource != nil
        else { return Log.debug(typeName(and: #function) + "aborted. Clientstream is not connected.") }

        Log.debug(typeName(and: #function))
        eventSource?.stop()
        eventSource = nil
    }

    // MARK: Polling

    private func startPolling() {
        guard flagRequestTimer == nil
        else { return Log.debug(typeName(and: #function) + "aborted. Polling already active.") }

        Log.debug(typeName(and: #function))
        flagRequestTimer = LDTimer(withTimeInterval: pollingInterval, fireQueue: syncQueue, execute: processTimer)
        makeFlagRequest(isOnline: true)
    }

    private func stopPolling() {
        guard flagRequestTimer != nil
        else { return Log.debug(typeName(and: #function) + "aborted. Polling already inactive.") }

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
              let flagCollection = try? JSONDecoder().decode(FeatureFlagCollection.self, from: data)
        else {
            reportDataError(serviceResponse.data)
            return
        }
        reportSyncComplete(.flagCollection(flagCollection))
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
        if eventSource == nil {
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

        switch eventType {
        case "ping": makeFlagRequest(isOnline: isOnline)
        case "put":
            guard let data = messageEvent.data.data(using: .utf8),
                  let flagCollection = try? JSONDecoder().decode(FeatureFlagCollection.self, from: data)
            else {
                reportDataError(messageEvent.data.data(using: .utf8))
                return
            }
            reportSyncComplete(.flagCollection(flagCollection))
        case "patch":
            guard let data = messageEvent.data.data(using: .utf8),
                  let flag = try? JSONDecoder().decode(FeatureFlag.self, from: data)
            else {
                reportDataError(messageEvent.data.data(using: .utf8))
                return
            }
            reportSyncComplete(.patch(flag))
        case "delete":
            guard let data = messageEvent.data.data(using: .utf8),
                  let deleteResponse = try? JSONDecoder().decode(DeleteResponse.self, from: data)
            else {
                reportDataError(messageEvent.data.data(using: .utf8))
                return
            }
            reportSyncComplete(.delete(deleteResponse))
        default:
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

    func testStreamOnMessage(event: String, messageEvent: MessageEvent) {
        onMessage(eventType: event, messageEvent: messageEvent)
    }
}

#endif
