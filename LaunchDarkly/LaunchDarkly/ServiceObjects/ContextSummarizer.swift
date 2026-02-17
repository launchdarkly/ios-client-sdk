import Foundation
import OSLog

/// Manages per-context summary events by tracking separate FlagRequestTracker instances for each unique context.
/// Each context is identified by its hash, and summaries are generated separately for each context during flush.
class ContextSummarizer {
    private var trackers: [String: TrackerWithContext] = [:]
    private let logger: OSLog

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
        let contextHashKey = context.contextHash()
        ensureTrackerExists(for: context, hashKey: contextHashKey)

        trackers[contextHashKey]?.tracker.trackRequest(
            flagKey: flagKey,
            reportedValue: reportedValue,
            featureFlag: featureFlag,
            defaultValue: defaultValue,
            context: context
        )
    }

    /// Ensures a tracker exists for the context hash, creating one if needed.
    private func ensureTrackerExists(for context: LDContext, hashKey: String) {
        guard trackers[hashKey] == nil else { return }

        // Create filtered context for privacy
        var filteredContext = LDContext(copyFrom: context)
        filteredContext.redactAnonymousAttributes = true

        trackers[hashKey] = TrackerWithContext(
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
