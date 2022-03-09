import Foundation

// sourcery: autoMockable
protocol DiagnosticReporting {
    func setMode(_ runMode: LDClientRunMode, online: Bool)
}

class DiagnosticReporter: DiagnosticReporting {
    private let service: DarklyServiceProvider
    private var timer: TimeResponding?
    private var sentInit: Bool
    private let stateQueue = DispatchQueue(label: "com.launchdarkly.diagnosticReporter.state", qos: .background)
    private let workQueue = DispatchQueue(label: "com.launchdarkly.diagnosticReporter.work", qos: .background)

    init(service: DarklyServiceProvider) {
        self.service = service
        self.sentInit = false
    }

    func setMode(_ runMode: LDClientRunMode, online: Bool) {
        if online && runMode == .foreground {
            startReporting()
        } else {
            stopReporting()
        }
    }

    private func startReporting() {
        stateQueue.sync {
            timer?.cancel()
            if let cache = self.service.diagnosticCache {
                if !sentInit {
                    sentInit = true
                    if let lastStats = cache.lastStats {
                        sendDiagnosticEventAsync(diagnosticEvent: lastStats)
                    }
                    let initEvent = DiagnosticInit(config: service.config,
                                                   diagnosticId: cache.getDiagnosticId(),
                                                   creationDate: Date().millisSince1970)
                    sendDiagnosticEventAsync(diagnosticEvent: initEvent)
                }

                timer = LDTimer(withTimeInterval: service.config.diagnosticRecordingInterval, fireQueue: workQueue) {
                    self.sendDiagnosticEventSync(diagnosticEvent: cache.getCurrentStatsAndReset())
                }
            }
        }
    }

    private func stopReporting() {
        stateQueue.sync {
            timer?.cancel()
            timer = nil
        }
    }

    private func sendDiagnosticEventAsync<T: DiagnosticEvent & Encodable>(diagnosticEvent: T) {
        workQueue.async {
            self.sendDiagnosticEventSync(diagnosticEvent: diagnosticEvent)
        }
    }

    private func sendDiagnosticEventSync<T: DiagnosticEvent & Encodable>(diagnosticEvent: T) {
        Log.debug(typeName + ": Sending diagnostic event: \(String(describing: diagnosticEvent))")
        self.service.publishDiagnostic(diagnosticEvent: diagnosticEvent) { _, urlResponse, error in
            let shouldRetry = self.processSendResponse(response: urlResponse as? HTTPURLResponse, error: error, isRetry: false)
            if shouldRetry {
                self.service.publishDiagnostic(diagnosticEvent: diagnosticEvent) { _, urlResponse, error in
                    _ = self.processSendResponse(response: urlResponse as? HTTPURLResponse, error: error, isRetry: true)
                }
            }
        }
    }

    private func processSendResponse(response: HTTPURLResponse?, error: Error?, isRetry: Bool) -> Bool {
        if error == nil && (200..<300).contains(response?.statusCode ?? 0) {
            Log.debug(typeName + ": Completed sending diagnostic event.")
            return false
        }

        if let statusCode = response?.statusCode, (400..<500).contains(statusCode) && ![400, 408, 429].contains(statusCode) {
            Log.debug(typeName + ": Dropping diagnostic event due to non-retriable response: \(String(describing: response))")
            return false
        }

        Log.debug(typeName + ": Sending diagnostic failed with error: \(String(describing: error)) response: \(String(describing: response))")

        if isRetry {
            Log.debug(typeName + ": dropping diagnostic due to failed retry")
            return false
        }

        return true
    }
}

extension DiagnosticReporter: TypeIdentifying { }
