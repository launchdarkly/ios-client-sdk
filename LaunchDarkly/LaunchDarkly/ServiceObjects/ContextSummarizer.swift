import Foundation
import OSLog

/// Manages per-context summary events by tracking separate FlagRequestTracker instances for each unique context.
/// Each context gets its own tracker, and summaries are generated separately for each context during flush.
class ContextSummarizer {
    private var trackers: [ContextKey: TrackerWithContext] = [:]
    private let logger: OSLog

    /// A context used as a dictionary key.
    ///
    /// Hashes only the fully qualified key, which the context already stores; `LDContext.contextHash()` would encode
    /// the whole context on every evaluation. Equal contexts share that key, so the `Hashable` contract holds, and
    /// contexts that collide are separated by `==`.
    struct ContextKey: Hashable {
        let context: LDContext

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

    /// Clears all trackers.
    func clear() {
        trackers.removeAll()
    }
}
