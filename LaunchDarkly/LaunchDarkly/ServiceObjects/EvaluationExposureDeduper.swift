import Foundation

/**
 Identifies the evaluation result a hook is about to be told about, so that an `EvaluationExposureDeduper` can recognize
 a repeat of it.

 Two evaluations are the same exposure when every component here matches. The variation and version pair is the same
 identity LaunchDarkly uses to bucket evaluations in summary events, so two evaluations sharing that pair report
 identical data. Experiment status needs its own component because `versionForEvents` prefers `flagVersion`, which only
 moves when the flag itself changes: a prerequisite flipping can move an evaluation into or out of an experiment while it
 lands on the same variation of the same flag version. The environment is a component because a hook set on `LDConfig` is
 one instance shared by the clients for every environment in `secondaryMobileKeys`, and so is its deduper.
 */
public struct EvaluationExposureKey: Hashable {
    /// The name of the environment the evaluation was made against.
    public let environmentName: String
    /// The key of the flag that was evaluated.
    public let flagKey: LDFlagKey
    /// The index of the variation the result came from, or `nil` if the evaluation did not resolve to one.
    public let variation: Int?
    /// The flag version reported on events, or `nil` if the flag was not found.
    public let flagVersion: Int?
    /// Whether the evaluation was part of an experiment rollout.
    public let inExperiment: Bool
    /// The fully qualified key of the evaluation context.
    public let fullyQualifiedContextKey: String

    /**
     - parameter environmentName: The name of the environment the evaluation was made against.
     - parameter flagKey: The key of the flag that was evaluated.
     - parameter variation: The index of the variation the result came from.
     - parameter flagVersion: The flag version reported on events.
     - parameter inExperiment: Whether the evaluation was part of an experiment rollout.
     - parameter fullyQualifiedContextKey: The fully qualified key of the evaluation context.
     */
    public init(environmentName: String,
                flagKey: LDFlagKey,
                variation: Int?,
                flagVersion: Int?,
                inExperiment: Bool,
                fullyQualifiedContextKey: String) {
        self.environmentName = environmentName
        self.flagKey = flagKey
        self.variation = variation
        self.flagVersion = flagVersion
        self.inExperiment = inExperiment
        self.fullyQualifiedContextKey = fullyQualifiedContextKey
    }
}

/**
 Decides whether a hook should be told about an evaluation, so that repeated evaluations resolving to the same result do
 not invoke the hook again within a time window.

 Deduplication is opt-in per hook: a hook is told about every evaluation until it returns its own
 `Hook.evaluationExposureDeduper`.

 ```
 class MetricsHook: Hook {
     // Told about every evaluation.
 }

 class ObservabilityHook: Hook {
     // Told about an evaluation at most once per `defaultWindow`, for at most `defaultMaxSize` results at a time.
     let evaluationExposureDeduper: EvaluationExposureDeduper? = EvaluationExposureDeduper()
 }

 class TelemetryHook: Hook {
     let evaluationExposureDeduper: EvaluationExposureDeduper? = EvaluationExposureDeduper(window: 30, maxSize: 5_000)
 }

 class ExperimentHook: Hook {
     let evaluationExposureDeduper: EvaluationExposureDeduper? = myCustomDeduper
 }
 ```

 This class is the SDK's implementation: it remembers the result each flag last reported, and tells the hook about the
 flag again as soon as that result changes, or once the window elapses while it stays the same. Tracking one result per
 flag rather than every result seen keeps a flag that flips back and forth from hiding the flips, and bounds the cache by
 the size of the flag set. The cap is a safety net on top of that: flags whose window has elapsed are reclaimed first,
 and if more flags than the cap are live at once the cache starts over. Subclass this to implement a different policy;
 only `shouldRecord(key:now:)` and `reset()` are called by the SDK.

 A deduper is consulted once per evaluation, before the series opens, so a suppressed evaluation invokes neither
 `beforeEvaluation` nor `afterEvaluation`. Implementations must be thread-safe, because evaluations may be made from any
 thread. Give each hook its own instance unless you intend hooks to share a window: the first hook to be told about an
 exposure starts the window that suppresses the rest.
 */
open class EvaluationExposureDeduper {
    /// The dedupe window used by a deduper built without a window of its own. (10 minutes)
    public static let defaultWindow: TimeInterval = 600

    /// The number of flags tracked by a deduper built without a positive cap of its own. (2000)
    public static let defaultMaxSize = 2_000

    /**
     A deduper that suppresses nothing, so its hook is told about every evaluation.

     This is what a hook gets when it returns `nil` for `evaluationExposureDeduper`, so returning it is only useful to
     state that intent explicitly. This instance holds no state and may be given to any number of hooks.
     */
    public static let disabled: EvaluationExposureDeduper = DisabledEvaluationExposureDeduper()

    private let window: TimeInterval
    private let maxSize: Int

    private let queue = DispatchQueue(label: "com.launchdarkly.evaluationExposureDedupeQueue")
    // These fields should only be used synchronized on the queue.
    private var lastReported: [TrackedFlag: LastReported] = [:]

    /**
     - parameter window: The dedupe window, in seconds. Defaults to `defaultWindow`. A value of zero or less disables
     deduplication, so every evaluation reaches the hook.
     - parameter maxSize: The maximum number of flags to track, counting a flag once per environment it is evaluated
     in. Defaults to `defaultMaxSize`, as does a value of zero or less.
     */
    public init(window: TimeInterval = EvaluationExposureDeduper.defaultWindow,
                maxSize: Int = EvaluationExposureDeduper.defaultMaxSize) {
        self.window = window
        self.maxSize = maxSize > 0 ? maxSize : Self.defaultMaxSize
    }

    /**
     Returns whether the hook should be told about the evaluation identified by the given key, and if so starts a new
     dedupe window for the flag.

     The SDK calls this once per evaluation per hook. This implementation answers true when the flag is reporting a
     different result than it last did, and when the window has elapsed on the result it is repeating. See
     `EvaluationExposureKey` for what makes two evaluations the same result.

     The check and the update are performed together so that concurrent evaluations of the same flag cannot both be told
     to record.

     - parameter key: The key identifying the evaluation result.
     - parameter now: The current time as seconds since the epoch.
     */
    open func shouldRecord(key: EvaluationExposureKey, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        guard window > 0
        else { return true }

        return queue.sync {
            let flag = TrackedFlag(environmentName: key.environmentName, flagKey: key.flagKey)
            if let reported = lastReported[flag], reported.reportedAt > now - window, reported.isSameResult(as: key) {
                return false
            }

            lastReported[flag] = LastReported(key: key, reportedAt: now)
            if lastReported.count > maxSize {
                evict(keeping: flag, now: now)
            }
            return true
        }
    }

    /// Clears all recorded exposures, so the next evaluation of each is reported again. The SDK calls this when the
    /// evaluation context changes.
    open func reset() {
        queue.sync { lastReported.removeAll() }
    }

    private func evict(keeping flag: TrackedFlag, now: TimeInterval) {
        // The exposure being recorded right now opened its window a moment ago, so it would be the worst one to drop.
        let justReported = lastReported[flag]

        // Flags whose window has elapsed no longer change the outcome of shouldRecord, so reclaim those first.
        lastReported = lastReported.filter { $0.value.reportedAt > now - window }
        guard lastReported.count > maxSize
        else { return }

        // More flags are live at once than the cap allows, so nothing can be reclaimed without discarding a window that
        // is still open. Start over rather than ranking the flags by age: Dictionary is unordered, so singling out the
        // oldest would mean sorting the whole cache. Refilling takes another maxSize exposures, which keeps the cost of
        // starting over amortized, and the flags that were dropped are suppressed again as soon as they are re-reported.
        // Raise maxSize to stop reaching this at all.
        lastReported.removeAll(keepingCapacity: true)
        lastReported[flag] = justReported
    }
}

/// The flag a record belongs to. The environment is part of it because a hook set on `LDConfig` is one instance shared
/// by the clients for every environment in `secondaryMobileKeys`: were the environments to share a record, each would
/// look like the other having changed its result, and neither would ever be suppressed.
private struct TrackedFlag: Hashable {
    let environmentName: String
    let flagKey: LDFlagKey
}

/// The result a flag last reported, and when.
private struct LastReported {
    let variation: Int?
    let flagVersion: Int?
    let inExperiment: Bool
    let fullyQualifiedContextKey: String
    let reportedAt: TimeInterval

    init(key: EvaluationExposureKey, reportedAt: TimeInterval) {
        self.variation = key.variation
        self.flagVersion = key.flagVersion
        self.inExperiment = key.inExperiment
        self.fullyQualifiedContextKey = key.fullyQualifiedContextKey
        self.reportedAt = reportedAt
    }

    func isSameResult(as key: EvaluationExposureKey) -> Bool {
        return variation == key.variation
            && flagVersion == key.flagVersion
            && inExperiment == key.inExperiment
            && fullyQualifiedContextKey == key.fullyQualifiedContextKey
    }
}

private final class DisabledEvaluationExposureDeduper: EvaluationExposureDeduper {
    init() {
        super.init(window: 0, maxSize: 0)
    }

    override func shouldRecord(key: EvaluationExposureKey, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        return true
    }

    override func reset() {
    }
}
