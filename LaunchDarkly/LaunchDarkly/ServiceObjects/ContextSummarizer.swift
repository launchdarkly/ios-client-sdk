import Foundation
import OSLog

/// Manages per-context summary events by tracking separate FlagRequestTracker instances for each unique context.
/// Each context gets its own tracker, and summaries are generated separately for each context during flush.
class ContextSummarizer {
    private var trackers: [ContextKey: TrackerWithContext] = [:]
    private let logger: OSLog
    /// How many distinct contexts may be counted between two calls to `clear()`.
    ///
    /// Each one retains its context and its own counters, and nothing clears them while the client is offline, so
    /// without a bound the only limit on their memory is how long the outage lasts.
    private let maxContexts: Int
    /// Whether reaching `maxContexts` has been logged since the last `clear()`, so it is logged once per delivery.
    private var hasLoggedContextsExceeded = false

    /// A context used as a dictionary key.
    ///
    /// Groups contexts as keying by `LDContext.contextHash()` did, without encoding the whole context on every
    /// evaluation. That hash saw only whether a context has private attributes, not which, and a context JSON cannot
    /// represent, because an attribute holds NaN or an infinity, fell back to its fully qualified key. Equal keys share a
    /// fully qualified key, so hashing only that, which the context already stores, keeps the `Hashable` contract.
    struct ContextKey: Hashable {
        let context: LDContext

        func hash(into hasher: inout Hasher) {
            hasher.combine(context.fullyQualifiedKey())
        }

        static func == (lhs: ContextKey, rhs: ContextKey) -> Bool {
            guard lhs.context.fullyQualifiedKey() == rhs.context.fullyQualifiedKey()
            else { return false }

            // Attributes that compare equal are equally representable, so only a mismatch needs this walk.
            return lhs.context.equalsIgnoringWhichAttributesArePrivate(rhs.context)
                || (lhs.context.containsNonFiniteNumber() && rhs.context.containsNonFiniteNumber())
        }
    }

    struct TrackerWithContext {
        var tracker: FlagRequestTracker
        let context: LDContext
    }

    init(logger: OSLog, maxContexts: Int = .max) {
        self.logger = logger
        self.maxContexts = maxContexts
    }

    /// Tracks a flag evaluation request for a specific context.
    /// Creates a new tracker for the context if one doesn't exist, or reuses the existing one.
    ///
    /// - Returns: false if the evaluation was not counted, because its context is not counted yet and `maxContexts`
    ///   already are. A context already being counted is never turned away.
    @discardableResult
    func trackRequest(flagKey: LDFlagKey, reportedValue: LDValue, featureFlag: FeatureFlag?, defaultValue: LDValue, context: LDContext) -> Bool {
        let key = ContextKey(context: context)
        if trackers[key] == nil && trackers.count >= maxContexts {
            if !hasLoggedContextsExceeded {
                hasLoggedContextsExceeded = true
                os_log("Exceeded the number of contexts that can be summarized at once. Increase eventCapacity to avoid dropping evaluations.", log: logger, type: .default)
            }
            return false
        }
        ensureTrackerExists(for: context, key: key)

        trackers[key]?.tracker.trackRequest(
            flagKey: flagKey,
            reportedValue: reportedValue,
            featureFlag: featureFlag,
            defaultValue: defaultValue,
            context: context
        )
        return true
    }

    /// Ensures a tracker exists for the context, creating one if needed.
    private func ensureTrackerExists(for context: LDContext, key: ContextKey) {
        guard trackers[key] == nil else { return }

        // Redaction is applied when the summary is encoded; see `Event.redactsAnonymousAttributes`.
        trackers[key] = TrackerWithContext(
            tracker: FlagRequestTracker(logger: logger),
            context: context
        )
    }

    /// Returns all tracker-context pairs for summary event generation.
    func getSummaries() -> [(tracker: FlagRequestTracker, context: LDContext)] {
        return trackers.values.map { ($0.tracker, $0.context) }
    }

    /// Returns true if any tracker has logged requests.
    var hasLoggedRequests: Bool {
        return trackers.values.contains { $0.tracker.hasLoggedRequests }
    }

    /// Clears all trackers, which makes room for `maxContexts` new contexts.
    func clear() {
        trackers.removeAll()
        hasLoggedContextsExceeded = false
    }
}
