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
    private let sdkKey: String
    /// A lock rather than a queue because a full event store counts every refused evaluation here, on the thread that
    /// evaluated, and a `DispatchQueue.sync` costs enough at that rate to be visible.
    private let lock = UnfairLock()

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
        lock.withLock {
            DiagnosticId(diagnosticId: instanceId, sdkKey: sdkKey)
        }
    }

    func getCurrentStatsAndReset() -> DiagnosticStats {
        lock.withLock {
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
        lock.withLock {
            droppedEvents += 1
        }
    }

    func recordEventsInLastBatch(eventsInLastBatch: Int) {
        lock.withLock {
            self.eventsInLastBatch = eventsInLastBatch
        }
    }

    func addStreamInit(streamInit: DiagnosticStreamInit) {
        lock.withLock {
            streamInits.append(streamInit)
        }
    }
}
