import Foundation
import LaunchDarkly

/// Counts the evaluation series stages it observes, so the app can show what exposure deduplication does.
/// Deduplication is configured at registration by wrapping this hook in a `DedupingHook`, the same way an application
/// would wrap any other hook.
///
/// Deduplication skips the whole series, so both counts stay equal, and both stop climbing while repeated evaluations
/// resolve to the same result.
final class ExposureCountingHook: Hook {
    private let label: String
    private let onStage: () -> Void
    private let lock = NSLock()
    private var befores = 0
    private var afters = 0

    /// - Parameters:
    ///   - label: a name for this hook, shown in the app's dedupe status.
    ///   - onStage: called after each stage, on whichever thread evaluated, so the app can refresh its display.
    init(label: String, onStage: @escaping () -> Void) {
        self.label = label
        self.onStage = onStage
    }

    func metadata() -> Metadata {
        Metadata(name: label)
    }

    func beforeEvaluation(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData) -> EvaluationSeriesData {
        lock.lock()
        befores += 1
        lock.unlock()
        onStage()
        return seriesData
    }

    func afterEvaluation(seriesContext: EvaluationSeriesContext,
                         seriesData: EvaluationSeriesData,
                         evaluationDetail: LDEvaluationDetail<LDValue>) -> EvaluationSeriesData {
        lock.lock()
        afters += 1
        lock.unlock()
        onStage()
        return seriesData
    }

    /// This hook's window and how many evaluations have reached each stage, as `fast 5s: 3/3`.
    func status(window: TimeInterval) -> String {
        lock.lock()
        defer { lock.unlock() }
        return "\(label) \(Int(window))s: \(befores)/\(afters)"
    }
}
