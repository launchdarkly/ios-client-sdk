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

    /// The key of the context counted last, reused while evaluations arrive for an equal context.
    private var lastKey: ContextKey?

    /// A context used as a dictionary key.
    ///
    /// Groups and hashes contexts by every attribute `==` compares, as Android does. A context holding NaN is not equal
    /// even to itself, so contexts holding NaN or an infinity that share a fully qualified key are grouped together, as
    /// keying by `LDContext.contextHash()` did, and hash by that key alone.
    ///
    /// The hash walks every attribute, so it is computed once, when the key is made.
    struct ContextKey: Hashable {
        let context: LDContext
        private let hashCode: Int

        init(context: LDContext) {
            self.context = context
            var hasher = Hasher()
            hasher.combine(context.fullyQualifiedKey())
            if !context.containsNonFiniteNumber() {
                context.combineComparedProperties(into: &hasher)
            }
            hashCode = hasher.finalize()
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(hashCode)
        }

        static func == (lhs: ContextKey, rhs: ContextKey) -> Bool {
            guard lhs.context.fullyQualifiedKey() == rhs.context.fullyQualifiedKey()
            else { return false }

            // Attributes that compare equal are equally representable, so only a mismatch needs this walk.
            return lhs.context == rhs.context
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
        let key = key(for: context)
        if let index = trackers.index(forKey: key) {
            trackers.values[index].tracker.trackRequest(
                flagKey: flagKey,
                reportedValue: reportedValue,
                featureFlag: featureFlag,
                defaultValue: defaultValue,
                context: context
            )
            return true
        }

        guard trackers.count < maxContexts
        else {
            if !hasLoggedContextsExceeded {
                hasLoggedContextsExceeded = true
                os_log("Exceeded the number of contexts that can be summarized at once. Increase eventCapacity to avoid dropping evaluations.", log: logger, type: .default)
            }
            return false
        }

        var tracker = FlagRequestTracker(logger: logger)
        tracker.trackRequest(
            flagKey: flagKey,
            reportedValue: reportedValue,
            featureFlag: featureFlag,
            defaultValue: defaultValue,
            context: context
        )
        // Redaction is applied when the summary is encoded; see `Event.redactsAnonymousAttributes`.
        trackers[key] = TrackerWithContext(tracker: tracker, context: context)
        return true
    }

    /// Copies of one context share storage, so comparing against the last key is cheap where hashing is not.
    private func key(for context: LDContext) -> ContextKey {
        if let last = lastKey, last.context == context {
            return last
        }
        let key = ContextKey(context: context)
        lastKey = key
        return key
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
        lastKey = nil
        hasLoggedContextsExceeded = false
    }
}
