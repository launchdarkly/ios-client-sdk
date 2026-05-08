import Foundation

// sourcery: autoMockable
protocol DiagnosticCaching {
    func getDiagnosticId() -> DiagnosticId
    func getCurrentStatsAndReset() -> DiagnosticStats
    func incrementDroppedEventCount()
    func recordEventsInLastBatch(eventsInLastBatch: Int)
    func addStreamInit(streamInit: DiagnosticStreamInit)
}

/// In-memory diagnostic statistics (no persistence).
///
/// Older releases stored JSON in `UserDefaults` using the following key forms and
/// these key forms should not be reused to avoid collision with existing data:
/// `com.launchdarkly.DiagnosticCache.diagnosticData`, forming keys of the form
/// `com.launchdarkly.DiagnosticCache.diagnosticData.<mobileKey>`.
final class DiagnosticCache: DiagnosticCaching {
    private static let cacheQueueLabel = "com.launchdarkly.DiagnosticCache.cacheQueue"

    private let sdkKey: String
    private var cacheQueue = DispatchQueue(label: cacheQueueLabel)

    private var instanceId: String
    private var dataSinceDate: Int64
    private var droppedEvents: Int
    private var eventsInLastBatch: Int
    private var streamInits: [DiagnosticStreamInit]

    init(sdkKey: String) {
        self.sdkKey = sdkKey
        self.instanceId = UUID().uuidString
        self.dataSinceDate = Date().millisSince1970
        self.droppedEvents = 0
        self.eventsInLastBatch = 0
        self.streamInits = []
    }

    func getDiagnosticId() -> DiagnosticId {
        cacheQueue.sync {
            DiagnosticId(diagnosticId: instanceId, sdkKey: sdkKey)
        }
    }

    func getCurrentStatsAndReset() -> DiagnosticStats {
        cacheQueue.sync {
            let now = Date().millisSince1970
            let stats = DiagnosticStats(id: DiagnosticId(diagnosticId: instanceId, sdkKey: sdkKey),
                                        creationDate: now,
                                        dataSinceDate: dataSinceDate,
                                        droppedEvents: droppedEvents,
                                        eventsInLastBatch: eventsInLastBatch,
                                        streamInits: streamInits)
            dataSinceDate = now
            droppedEvents = 0
            eventsInLastBatch = 0
            streamInits = []
            return stats
        }
    }

    func incrementDroppedEventCount() {
        cacheQueue.sync {
            droppedEvents += 1
        }
    }

    func recordEventsInLastBatch(eventsInLastBatch: Int) {
        cacheQueue.sync {
            self.eventsInLastBatch = eventsInLastBatch
        }
    }

    func addStreamInit(streamInit: DiagnosticStreamInit) {
        cacheQueue.sync {
            streamInits.append(streamInit)
        }
    }
}
