import Foundation
import OSLog

// sourcery: autoMockable
protocol DiagnosticReporting {
    func setMode(_ runMode: LDClientRunMode, online: Bool)
}

class NullDiagnosticReporter: DiagnosticReporting {
    func setMode(_ runMode: LDClientRunMode, online: Bool) {
    }
}

class DiagnosticReporter: DiagnosticReporting {
    private let service: DarklyServiceProvider
    private let environmentReporting: EnvironmentReporting
    private var timer: TimeResponding?
    private var sentInit: Bool
    private let stateQueue = DispatchQueue(label: "com.launchdarkly.diagnosticReporter.state", qos: .background)
    private let workQueue = DispatchQueue(label: "com.launchdarkly.diagnosticReporter.work", qos: .background)

    init(service: DarklyServiceProvider, environmentReporting: EnvironmentReporting) {
        self.service = service
        self.environmentReporting = environmentReporting
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
                                                   environmentReporting: environmentReporting,
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
        os_log("%s Sending diagnostic event: %s", log: service.config.logger, type: .debug, typeName(and: #function), String(describing: diagnosticEvent))
        self.service.publishDiagnostic(diagnosticEvent: diagnosticEvent) { response in
            let shouldRetry = self.processSendResponse(response: response.urlResponse as? HTTPURLResponse, error: response.error, isRetry: false)
            if shouldRetry {
                self.service.publishDiagnostic(diagnosticEvent: diagnosticEvent) { response in
                    _ = self.processSendResponse(response: response.urlResponse as? HTTPURLResponse, error: response.error, isRetry: true)
                }
            }
        }
    }

    private func processSendResponse(response: HTTPURLResponse?, error: Error?, isRetry: Bool) -> Bool {
        if error == nil && (200..<300).contains(response?.statusCode ?? 0) {
            os_log("%s Completed sending diagnostic event.", log: service.config.logger, type: .debug, typeName)
            return false
        }

        if let statusCode = response?.statusCode, (400..<500).contains(statusCode) && ![400, 408, 429].contains(statusCode) {
            os_log("%s Dropping diagnostic event due to non-retriable response: %s", log: service.config.logger, type: .debug, typeName, String(describing: response))
            return false
        }

        os_log("%s Sending diagnostic failed with error: %s response: %s", log: service.config.logger, type: .debug,
            typeName,
            String(describing: error),
            String(describing: response))

        if isRetry {
            os_log("%s dropping diagnostic due to failed retry", log: service.config.logger, type: .debug, typeName)
            return false
        }

        return true
    }
}

extension DiagnosticReporter: TypeIdentifying { }
