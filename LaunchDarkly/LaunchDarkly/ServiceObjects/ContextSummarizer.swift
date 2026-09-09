import Foundation
import OSLog

/// Manages per-context summary events by tracking separate FlagRequestTracker instances for each unique context.
/// Each context gets its own tracker, and summaries are generated separately for each context during flush.
class ContextSummarizer {
    private var trackers: [ContextKey: TrackerWithContext] = [:]
    private let logger: OSLog

    /// A context used as a dictionary key.
    ///
    /// `LDContext.contextHash()` encodes the context to JSON and digests the result. That is the right price for the
    /// flag cache, which persists the digest and compares it across launches, but it is far more than a bucketing key
    /// needs to cost -- and an application reading a flag on every redraw pays it on every redraw. Hashing the
    /// canonicalized key instead reads a string the context already stores. Equal contexts always share that key, so
    /// the `Hashable` contract holds; the contexts that differ elsewhere collide, and `==` separates them.
    struct ContextKey: Hashable {
        let context: LDContext

        init(context: LDContext) {
            // `redactAnonymousAttributes` says how a context is encoded for output, not which context it is,
            // and Swift synthesizes `==` across every stored property. Left alone it would let an encoding
            // concern split one context into two buckets. Android keys on `LDContext.equals`, which has no
            // such field, so clearing it is also what keeps the two platforms agreeing on which evaluations
            // belong to the same summary.
            var normalized = context
            normalized.redactAnonymousAttributes = false
            self.context = normalized
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(context.fullyQualifiedKey())
        }
    }

    struct TrackerWithContext {
        var tracker: FlagRequestTracker
        let context: LDContext
    }

    init(logger: OSLog) {
        self.logger = logger
    }

    /// Tracks a flag evaluation request for a specific context.
    /// Creates a new tracker for the context if one doesn't exist, or reuses the existing one.
    func trackRequest(flagKey: LDFlagKey, reportedValue: LDValue, featureFlag: FeatureFlag?, defaultValue: LDValue, context: LDContext) {
        let key = ContextKey(context: context)
        ensureTrackerExists(for: context, key: key)

        trackers[key]?.tracker.trackRequest(
            flagKey: flagKey,
            reportedValue: reportedValue,
            featureFlag: featureFlag,
            defaultValue: defaultValue,
            context: context
        )
    }

    /// Ensures a tracker exists for the context, creating one if needed.
    private func ensureTrackerExists(for context: LDContext, key: ContextKey) {
        guard trackers[key] == nil else { return }

        // Create filtered context for privacy
        var filteredContext = LDContext(copyFrom: context)
        filteredContext.redactAnonymousAttributes = true

        trackers[key] = TrackerWithContext(
            tracker: FlagRequestTracker(logger: logger),
            context: filteredContext
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

    /// Clears all trackers.
    func clear() {
        trackers.removeAll()
    }
}
