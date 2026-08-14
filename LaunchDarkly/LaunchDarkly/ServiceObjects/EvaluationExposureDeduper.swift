import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/**
 Identifies the evaluation result a hook is about to be told about, so that an `EvaluationExposureDeduper` can recognize
 a repeat of it.

 Two evaluations are the same exposure when every component here matches. The value is included directly rather than
 inferred from the variation and version: those are the identity LaunchDarkly uses to bucket summary events, but neither
 by itself guarantees that the payload is unchanged. The environment is a component because a hook set on `LDConfig` is
 one instance shared by the clients for every environment in `secondaryMobileKeys`, and so is its deduper. It is
 identified by a hash of the mobile key rather than by the key itself, so that a hook cannot read the credential out of
 what it is told, and rather than by the configured environment name, which is arbitrary metadata that is always
 `"default"` for the primary environment.

 The components describe the result the evaluation returns, which is how the SDK identifies an evaluation on analytics
 events too. An evaluation the SDK has no flag data for returns the default value, and so is described by that value with
 no variation and no version, the same identity it summarizes such an evaluation under. Evaluations made before the
 client has flags are of that kind, as are evaluations of a flag that does not exist, so the data arriving changes the
 value, variation, and version, and the hook is told about the flag again rather than waiting out a window. A flag whose
 data carries no value, which is what a flag that is off without an off variation has, likewise returns the default value
 and is described by it, under the flag's own variation and version. The environment is never unknown this way: it is
 derived from the configuration, so it is fixed before the client it belongs to evaluates anything.

 The reason the SDK gives for a result is not a component, so neither is the experiment membership drawn from it. A
 prerequisite that starts failing to the variation an experiment had been choosing leaves the value, the variation, and
 the version unchanged while moving the flag out of that experiment, and the evaluations that follow are repeats here.
 The analytics the SDK sends are untouched by any of this, each carrying its own reason, so what LaunchDarkly attributes
 to an experiment does not depend on the window; a hook that reads the reason itself is what can miss such a change
 until the window elapses.
 */
public struct EvaluationExposureKey: Hashable {
    /// Identifies the environment the evaluation was made against, for comparison only: the mobile key is hashed so
    /// that a hook is not handed the credential, and the hash the SDK uses is not part of its contract. All that is
    /// guaranteed is that two evaluations made against the same environment give the same value, and evaluations made
    /// against different environments do not.
    public let mobileKeyHash: String
    /// The key of the flag that was evaluated.
    public let flagKey: LDFlagKey
    /// The value the evaluation returns, which is the default value if the flag was not found.
    public let value: LDValue
    /// The index of the variation the result came from, or `nil` if the evaluation did not resolve to one.
    public let variation: Int?
    /// The flag version reported on events, or `nil` if the flag was not found.
    public let flagVersion: Int?
    /// The fully qualified key of the evaluation context.
    public let fullyQualifiedContextKey: String

    /**
     - parameter mobileKeyHash: A hash of the mobile key of the environment the evaluation was made against.
     - parameter flagKey: The key of the flag that was evaluated.
     - parameter value: The value the evaluation returns, which is the default value if the flag was not found.
     Defaults to null; prefer stating it, since the variation and version do not by themselves distinguish one result
     from another.
     - parameter variation: The index of the variation the result came from.
     - parameter flagVersion: The flag version reported on events.
     - parameter fullyQualifiedContextKey: The fully qualified key of the evaluation context.
     */
    public init(mobileKeyHash: String,
                flagKey: LDFlagKey,
                variation: Int?,
                flagVersion: Int?,
                fullyQualifiedContextKey: String,
                value: LDValue = .null) {
        self.mobileKeyHash = mobileKeyHash
        self.flagKey = flagKey
        self.value = value
        self.variation = variation
        self.flagVersion = flagVersion
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
     DedupingHook(ExperimentHook(), deduper: sharedDeduper)
 ]
 ```

 This class is the SDK's implementation: it remembers the result each flag last reported, and tells the hook about the
 flag again as soon as that result changes, or once the window elapses while it stays the same. Tracking one result per
 flag rather than every result seen keeps a flag that flips back and forth from hiding the flips, and holds one record per
 flag the application evaluates, so the window is the only thing there is to configure.

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

     `CLOCK_MONOTONIC` counts from an arbitrary point rather than from the epoch, so that correcting the device clock
     cannot stretch a window: were this `Date()`, a correction that moved the clock backwards would leave every recorded
     time in the future and suppress those flags until real time caught up. It is POSIX rather than one of Darwin's own
     clocks, so the same reading is available on every platform Swift builds for.

     On Apple platforms it keeps advancing while the device sleeps, unlike `mach_absolute_time` and everything built on
     it, such as `DispatchTime.now()` and `ProcessInfo.systemUptime`, so a window is an interval of real time rather
     than of awake time. Where a platform's monotonic clock instead stops while the host is suspended, a window outlasts
     the suspension, which holds a repeat back for longer rather than reporting one too often.
     */
    public static func monotonicNow() -> TimeInterval {
        var now = timespec()
        clock_gettime(CLOCK_MONOTONIC, &now)
        return TimeInterval(now.tv_sec) + TimeInterval(now.tv_nsec) / nanosecondsPerSecond
    }

    private static let nanosecondsPerSecond: TimeInterval = 1_000_000_000

    private let window: TimeInterval

    // A plain lock rather than a DispatchQueue, because this is consulted once per evaluation:
    // `DispatchQueue.sync` measured around 3.4µs per call once a second thread reaches it, against under 200ns here.
    // Reading the records concurrently was measured too and lost to a plain lock, the section being one dictionary
    // lookup and one comparison, so there is less to overlap than dispatching costs.
    private let lock = UnfairLock()
    // Last result reported for each flag, per environment. Entries stay until `reset()`.
    // Should only be used while holding the lock.
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

        lock.lock()
        defer { lock.unlock() }

        let flag = TrackedFlag(mobileKeyHash: key.mobileKeyHash, flagKey: key.flagKey)
        if let reported = lastReported[flag], reported.reportedAt > now - window, reported.isSameResult(as: key) {
            return false
        }

        lastReported[flag] = LastReported(key: key, reportedAt: now)
        return true
    }

    /// Clears all recorded exposures, so the next evaluation of each is reported again. `DedupingHook` calls this when
    /// the evaluation context changes.
    open func reset() {
        lock.lock()
        defer { lock.unlock() }

        lastReported.removeAll()
    }
}

/// The flag a record belongs to. The environment is part of it because a hook set on `LDConfig` is one instance shared
/// by the clients for every environment in `secondaryMobileKeys`: were the environments to share a record, each would
/// look like the other having changed its result, and neither would ever be suppressed.
private struct TrackedFlag: Hashable {
    let mobileKeyHash: String
    let flagKey: LDFlagKey
}

/// The result a flag last reported, and when.
private struct LastReported {
    let key: EvaluationExposureKey
    let reportedAt: TimeInterval

    /// Holding the key rather than a copy of the components that describe its result is what keeps this from having to
    /// be revisited whenever `EvaluationExposureKey` gains one. The environment and flag key it also compares are equal
    /// by the time this is asked, since a record is only ever found under the `TrackedFlag` they make up.
    func isSameResult(as key: EvaluationExposureKey) -> Bool {
        return self.key == key
    }
}
