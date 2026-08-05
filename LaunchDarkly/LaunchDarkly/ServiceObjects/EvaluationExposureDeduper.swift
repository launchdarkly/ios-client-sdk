import Foundation

/**
 Tracks recently recorded evaluation exposures so that repeated evaluations resolving to the same result do not
 report a new exposure within a configured time window.

 Each unique exposure key is only recorded once per window. The number of tracked keys is bounded: keys whose window
 has elapsed are reclaimed first, and if more keys than the cap are live at once the cache starts over.

 This type provides no synchronization of its own. Callers are responsible for serializing access; `EventReporter`
 uses it only from its event queue.
 */
class EvaluationExposureDeduper {
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
        self.maxSize = maxSize > 0 ? maxSize : LDConfig.Defaults.evaluationExposureDedupeMaxSize
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
            evict(keeping: key, now: now)
        }
        return true
    }

    /// Clears all recorded exposures. Called when the evaluation context changes.
    func reset() {
        lastRecordedAt.removeAll()
    }

    private func evict(keeping key: String, now: TimeInterval) {
        // Keys whose window has already elapsed no longer change the outcome of shouldRecord, so reclaim those first.
        lastRecordedAt = lastRecordedAt.filter { $0.value > now - window }
        guard lastRecordedAt.count > maxSize
        else { return }

        // More keys are live at once than the cap allows, so nothing can be reclaimed without discarding a window that
        // is still open. Start over rather than ranking the keys by age: Dictionary is unordered, so singling out the
        // oldest would mean sorting the whole cache. Refilling takes another maxSize exposures, which keeps the cost of
        // starting over amortized, and the keys that were dropped are suppressed again as soon as they are re-recorded.
        // Raise maxSize to stop reaching this at all.
        lastRecordedAt.removeAll(keepingCapacity: true)

        // The exposure being recorded right now opened its window a moment ago, so it would be the worst one to drop.
        lastRecordedAt[key] = now
    }
}
