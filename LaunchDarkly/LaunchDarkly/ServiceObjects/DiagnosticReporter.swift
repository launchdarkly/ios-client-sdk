//
//  DiagnosticEventProcessor.swift
//  LaunchDarkly
//
//  Copyright © 2020 Catamorphic Co. All rights reserved.
//

import Foundation

//sourcery: autoMockable
protocol DiagnosticReporting {
    //sourcery: defaultMockValue = DarklyServiceMock()
    var service: DarklyServiceProvider { get set }
    //sourcery: defaultMockValue = .foreground
    var runMode: LDClientRunMode { get set }
    //sourcery: defaultMockValue = false
    var isOnline: Bool { get set }
}

class DiagnosticReporter: DiagnosticReporting {
    var service: DarklyServiceProvider {
        didSet {
            guard service.config != oldValue.config
            else { return }
            stateQueue.async {
                self.stopReporting()
                self.sentInit = false
                self.maybeStartReporting()
            }
        }
    }

    var runMode: LDClientRunMode {
        didSet {
            guard runMode != oldValue
            else { return }
            stateQueue.async {
                self.stopReporting()
                self.maybeStartReporting()
            }
        }
    }

    var isOnline: Bool = false {
        didSet {
            guard isOnline != oldValue
            else { return }
            stateQueue.async {
                self.stopReporting()
                self.maybeStartReporting()
            }
        }
    }

    private var timer: TimeResponding?
    private var sentInit: Bool
    private let stateQueue = DispatchQueue(label: "com.launchdarkly.diagnosticReporter.state", qos: .background)
    private let workQueue = DispatchQueue(label: "com.launchdarkly.diagnosticReporter.work", qos: .background)

    init(service: DarklyServiceProvider, runMode: LDClientRunMode) {
        self.service = service
        self.runMode = runMode
        self.sentInit = false
        maybeStartReporting()
    }

    private func maybeStartReporting() {
        guard isOnline && runMode == .foreground
        else { return }
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

            timer = LDTimer(withTimeInterval: service.config.diagnosticRecordingInterval, repeats: true, fireQueue: workQueue) {
                self.sendDiagnosticEventSync(diagnosticEvent: cache.getCurrentStatsAndReset())
            }
        }
    }

    private func stopReporting() {
        timer?.cancel()
        timer = nil
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
