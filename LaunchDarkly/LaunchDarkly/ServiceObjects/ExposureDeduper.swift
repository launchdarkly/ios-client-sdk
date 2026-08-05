import Foundation

/**
 Tracks recently recorded feature flag exposures so that repeated evaluations resolving to the same result do not
 report a new exposure within a configured time window.

 Each unique exposure key is only recorded once per window. The number of tracked keys is bounded; when the cap is
 exceeded the least recently recorded keys are evicted.

 This type provides no synchronization of its own. Callers are responsible for serializing access; `EventReporter`
 uses it only from its event queue.
 */
class ExposureDeduper {
    private let window: TimeInterval
    private let maxSize: Int
    private var lastRecordedAt: [String: TimeInterval] = [:]

    /**
     - parameter window: The dedupe window. A value of zero or less disables deduplication, so every exposure is
     recorded.
     - parameter maxSize: The maximum number of exposure keys to track. A value of zero or less falls back to the
     default.
     */
    init(window: TimeInterval, maxSize: Int) {
        self.window = window
        self.maxSize = maxSize > 0 ? maxSize : LDConfig.Defaults.flagExposureDedupeMaxSize
    }

    var isEnabled: Bool { window > 0 }

    /**
     Returns whether an exposure for the given key should be recorded, and if so starts a new dedupe window for it.

     The check and the update are performed together so that concurrent evaluations of the same flag cannot both be
     told to record.

     - parameter key: A stable key identifying the exposure result.
     - parameter now: The current time as seconds since the epoch.
     */
    func shouldRecord(key: String, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        guard isEnabled
        else { return true }

        if let last = lastRecordedAt[key], last > now - window {
            return false
        }

        lastRecordedAt[key] = now
        if lastRecordedAt.count > maxSize {
            evict(now: now)
        }
        return true
    }

    /// Clears all recorded exposures. Called when the evaluation context changes.
    func reset() {
        lastRecordedAt.removeAll()
    }

    private func evict(now: TimeInterval) {
        // Keys whose window has already elapsed no longer change the outcome of shouldRecord, so reclaim those first.
        lastRecordedAt = lastRecordedAt.filter { $0.value > now - window }
        guard lastRecordedAt.count > maxSize
        else { return }

        // Evict a batch rather than a single key, so that a workload tracking more live keys than maxSize doesn't pay
        // for a scan on every subsequent exposure.
        let dropCount = lastRecordedAt.count - maxSize + maxSize / 4
        lastRecordedAt.sorted { $0.value < $1.value }
            .prefix(dropCount)
            .forEach { lastRecordedAt.removeValue(forKey: $0.key) }
    }
}
