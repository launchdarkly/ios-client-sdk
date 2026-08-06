import Foundation

/**
 Decides whether a hook should be told about an evaluation, so that repeated evaluations resolving to the same result do
 not invoke the hook again within a time window.

 The SDK gives each registered hook its own deduper. Return one from `Hook.evaluationExposureDeduper` to control that
 hook's behavior; a hook returning `nil` gets a deduper built from `LDConfig.evaluationExposureDedupeWindow` and
 `LDConfig.evaluationExposureDedupeMaxSize`.

 ```
 class AuditHook: Hook {
     // Observes every evaluation, whatever the SDK is configured to do.
     let evaluationExposureDeduper: EvaluationExposureDeduper? = .disabled
 }

 class ObservabilityHook: Hook {
     let evaluationExposureDeduper: EvaluationExposureDeduper? = EvaluationExposureDeduper(window: 30, maxSize: 5_000)
 }
 ```

 This class is the SDK's implementation: it records each unique exposure key once per window and bounds the number of
 tracked keys. Keys whose window has elapsed are reclaimed first, and if more keys than the cap are live at once the
 cache starts over. Subclass it to implement a different policy; only `shouldRecord(key:now:)` and `reset()` are called
 by the SDK.

 A deduper is consulted once per evaluation, before the series opens, so a suppressed evaluation invokes neither
 `beforeEvaluation` nor `afterEvaluation`. Implementations must be thread-safe, because evaluations may be made from any
 thread. Give each hook its own instance unless you intend hooks to share a window: the first hook to be told about an
 exposure starts the window that suppresses the rest.
 */
open class EvaluationExposureDeduper {
    /**
     A deduper that suppresses nothing, so its hook is told about every evaluation regardless of the window configured
     on `LDConfig`.

     This instance holds no state and may be given to any number of hooks.
     */
    public static let disabled: EvaluationExposureDeduper = DisabledEvaluationExposureDeduper()

    private let window: TimeInterval
    private let maxSize: Int

    private let queue = DispatchQueue(label: "com.launchdarkly.evaluationExposureDedupeQueue")
    // These fields should only be used synchronized on the queue.
    private var lastRecordedAt: [String: TimeInterval] = [:]

    /**
     - parameter window: The dedupe window. A value of zero or less disables deduplication, so every evaluation reaches
     the hook.
     - parameter maxSize: The maximum number of exposure keys to track. A value of zero or less falls back to the
     default.
     */
    public init(window: TimeInterval, maxSize: Int) {
        self.window = window
        self.maxSize = maxSize > 0 ? maxSize : LDConfig.Defaults.evaluationExposureDedupeMaxSize
    }

    /**
     Returns whether the hook should be told about the evaluation identified by the given key, and if so starts a new
     dedupe window for it.

     The SDK calls this once per evaluation per hook. The key identifies the evaluation result: two evaluations share a
     key when they resolve to the same variation of the same flag version, with the same experiment status, for the same
     context.

     The check and the update are performed together so that concurrent evaluations of the same flag cannot both be told
     to record.

     - parameter key: A stable key identifying the evaluation result.
     - parameter now: The current time as seconds since the epoch.
     */
    open func shouldRecord(key: String, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        guard window > 0
        else { return true }

        return queue.sync {
            if let last = lastRecordedAt[key], last > now - window {
                return false
            }

            lastRecordedAt[key] = now
            if lastRecordedAt.count > maxSize {
                evict(keeping: key, now: now)
            }
            return true
        }
    }

    /// Clears all recorded exposures, so the next evaluation of each is reported again. The SDK calls this when the
    /// evaluation context changes.
    open func reset() {
        queue.sync { lastRecordedAt.removeAll() }
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

private final class DisabledEvaluationExposureDeduper: EvaluationExposureDeduper {
    init() {
        super.init(window: 0, maxSize: 0)
    }

    override func shouldRecord(key: String, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        return true
    }

    override func reset() {
    }
}
