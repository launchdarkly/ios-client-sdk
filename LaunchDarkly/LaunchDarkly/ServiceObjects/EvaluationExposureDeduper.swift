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

 Deduplication is opt-in per hook: a hook is told about every evaluation until you wrap it in a `DedupingHook`, which is
 what consults a deduper.

 ```swift
 config.hooks = [
     MetricsHook(),                                     // told about every evaluation
     DedupingHook(ObservabilityHook()),                  // default window
     DedupingHook(TelemetryHook(), window: 30),
     DedupingHook(ExperimentHook(), deduper: myCustomDeduper)
 ]
 ```

 This class is the SDK's implementation: it remembers the result each flag last reported, and tells the hook about the
 flag again as soon as that result changes, or once the window elapses while it stays the same. Tracking one result per
 flag rather than every result seen keeps a flag that flips back and forth from hiding the flips, and holds one record per
 flag the application evaluates, so the window is the only thing there is to configure. Subclass this to implement a
 different policy; only `shouldRecord(key:now:)` and `reset()` are called by `DedupingHook`.

 A deduper is consulted once per evaluation, before the series opens, so a suppressed evaluation invokes neither
 `beforeEvaluation` nor `afterEvaluation`. Implementations must be thread-safe, because evaluations may be made from any
 thread. Give each hook its own instance unless you intend hooks to share a window: the first hook to be told about an
 exposure starts the window that suppresses the rest.
 */
open class EvaluationExposureDeduper {
    /// The dedupe window used by a deduper built without a window of its own. (10 minutes)
    public static let defaultWindow: TimeInterval = 600

    /**
     Reads the clock a window is measured against, in seconds. This is what `shouldRecord(key:now:)` reads when it is
     not given a time.

     `CLOCK_MONOTONIC_RAW` counts from an arbitrary point rather than from the epoch, so that correcting the device
     clock cannot stretch a window: were this `Date()`, a correction that moved the clock backwards would leave every
     recorded time in the future and suppress those flags until real time caught up. It also advances while the device
     sleeps, unlike `mach_absolute_time` and everything built on it, such as `DispatchTime.now()` and
     `ProcessInfo.systemUptime`, so a window is an interval of real time rather than of awake time.

     Only differences between readings are meaningful: this is not a time of day, and comparing it with
     `Date().timeIntervalSince1970` is a mistake.
     */
    public static func monotonicNow() -> TimeInterval {
        return TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / TimeInterval(NSEC_PER_SEC)
    }

    private let window: TimeInterval

    private let queue = DispatchQueue(label: "com.launchdarkly.evaluationExposureDedupeQueue")
    // Holds one record per flag the application evaluates, in each environment it evaluates it in. Nothing is evicted,
    // because that set is the flags the environment serves. Should only be used synchronized on the queue.
    private var lastReported: [TrackedFlag: LastReported] = [:]

    /**
     - parameter window: The dedupe window, in seconds. Defaults to `defaultWindow`. A value of zero or less disables
     deduplication, so every evaluation reaches the hook.
     */
    public init(window: TimeInterval = EvaluationExposureDeduper.defaultWindow) {
        self.window = window
    }

    /**
     Returns whether the hook should be told about the evaluation identified by the given key, and if so starts a new
     dedupe window for the flag.

     `DedupingHook` calls this once per evaluation. This implementation answers true when the flag is reporting a
     different result than it last did, and when the window has elapsed on the result it is repeating. See
     `EvaluationExposureKey` for what makes two evaluations the same result.

     The check and the update are performed together so that concurrent evaluations of the same flag cannot both be told
     to record.

     - parameter key: The key identifying the evaluation result.
     - parameter now: A reading of a clock that counts from an arbitrary point, in seconds. Defaults to
     `monotonicNow()`, which is not a time of day; see it for why a window is not measured against `Date()`.
     */
    open func shouldRecord(key: EvaluationExposureKey, now: TimeInterval = EvaluationExposureDeduper.monotonicNow()) -> Bool {
        guard window > 0
        else { return true }

        return queue.sync {
            let flag = TrackedFlag(environmentName: key.environmentName, flagKey: key.flagKey)
            if let reported = lastReported[flag], reported.reportedAt > now - window, reported.isSameResult(as: key) {
                return false
            }

            lastReported[flag] = LastReported(key: key, reportedAt: now)
            return true
        }
    }

    /// Clears all recorded exposures, so the next evaluation of each is reported again. `DedupingHook` calls this when
    /// the evaluation context changes.
    open func reset() {
        queue.sync { lastReported.removeAll() }
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
