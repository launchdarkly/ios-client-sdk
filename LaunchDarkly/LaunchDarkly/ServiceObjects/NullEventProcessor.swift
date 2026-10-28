import Foundation

class NullEventProcessor: EventProcessor {
    var isOnline: Bool = true
    var lastEventResponseDate: Date = Date()

    func record(_ event: Event) {
    }

    // swiftlint:disable:next function_parameter_count
    func recordFlagEvaluationEvents(flagKey: LDFlagKey,
                                    value: LDValue,
                                    defaultValue: LDValue,
                                    featureFlag: FeatureFlag?,
                                    context: LDContext,
                                    includeReason: Bool) {
    }

    // There is never anything to send, but a completion still answers on a background queue, as
    // `DirectEventProcessor`'s does. Were it answered inline, the threading a caller sees would depend on whether events
    // are turned on, and a caller doing what the contract allows -- taking a lock it already holds, say -- would
    // deadlock only there.
    func flush(completion: CompletionClosure?) {
        guard let completion
        else { return }
        DispatchQueue.global().async { completion() }
    }

    func flushReportingOutcome(completion: @escaping FlushOutcomeClosure) {
        DispatchQueue.global().async { completion(true) }
    }

    func flushAtClose() {
    }

    func commitRecordedEvents() {
    }

    func commitWherePersisting() {
    }
}
