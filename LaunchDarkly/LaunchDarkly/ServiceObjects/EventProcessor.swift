import Foundation

typealias EventSyncCompleteClosure = ((SynchronizingError?) -> Void)
/// Reports whether LaunchDarkly accepted every event a flush covered.
typealias FlushOutcomeClosure = (Bool) -> Void
// sourcery: autoMockable
protocol EventProcessor {
    // sourcery: defaultMockValue = false
    var isOnline: Bool { get set }
    // sourcery: defaultMockValue = Date.distantPast
    var lastEventResponseDate: Date { get }

    func record(_ event: Event)
    // swiftlint:disable:next function_parameter_count
    func recordFlagEvaluationEvents(flagKey: LDFlagKey,
                                    value: LDValue,
                                    defaultValue: LDValue,
                                    featureFlag: FeatureFlag?,
                                    context: LDContext,
                                    includeReason: Bool)
    func flush(completion: CompletionClosure?)

    /// Like `flush`. Reports `true` if LaunchDarkly accepted the pending batches, or there were none to send. Reports
    /// `false` if the reporter is offline, a batch was refused for good, a retryable failure left batches on disk, or
    /// an event the SDK had accepted could not be kept to send at all.
    ///
    /// Flushes arriving faster than a delivery completes join the one that is queued, since a delivery that has not
    /// started yet will send their events too. A delivery that has already started is not joined, so an answer is
    /// always about the batch the caller's own delivery took, never one an earlier delivery lost.
    ///
    /// The completion, like `flush`'s, runs on a background queue, and never on the reporter's own: a completion is
    /// free to record events or flush again without waiting on the queue it is running on. It is not the caller's
    /// thread either, and two completions may run at once, so anything it touches needs to expect that.
    func flushReportingOutcome(completion: @escaping FlushOutcomeClosure)

    /// Makes everything recorded so far outlive the process, without waiting for a delivery.
    ///
    /// The SDK does this itself at the points where an application is most likely to be about to die. It is worth
    /// calling directly before deliberately terminating the process.
    func commitRecordedEvents()

    /// Commits as a commit point does: before returning at `.immediate`, on a background queue at `.deferred`, and not
    /// at all where nothing is persisted, where a commit would only move the encode earlier.
    func commitAtCommitPoint()
}
