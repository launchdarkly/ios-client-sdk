import Foundation

/// What one delivery's answer is made of, where deliveries overlap.
///
/// A commit only stages events; whichever delivery runs next is what closes them into a batch. So the batch holding a
/// caller's events may belong to a delivery already under way, and answering that caller means hearing from it. These
/// are the two small pieces that arrange it: a `Claim` is a batch somebody is waiting on, and a `PassAnswer` gathers
/// the claims one pass of a delivery depends on.
extension DirectEventProcessor {
    /// A batch one delivery has taken, which another delivery's answer may depend on.
    final class Claim {
        /// This batch's result, or nil while the delivery holding it is still waiting. Only to be used while holding
        /// the reporter's `claimLock`.
        var outcome: Bool?
        /// Deliveries whose answer waits on this batch. Only to be used while holding the reporter's `claimLock`.
        var waiters: [FlushOutcomeClosure] = []
    }

    /// Gathers the outcomes one pass of a delivery depends on, and reports the worst of them: blocked where any batch
    /// was, lost where any was lost, and delivered only where all of them were.
    ///
    /// How many there are is settled before the first can arrive, so this needs no notion of being complete beyond
    /// counting down.
    final class PassAnswer {
        private let lock = UnfairLock()
        /// Outcomes still to come, and the answer to make once there are none. Only to be used while holding `lock`.
        private var outstanding: Int
        private var outcome = PassOutcome.delivered
        private var answer: ((PassOutcome) -> Void)?

        init(outstanding: Int, _ answer: @escaping (PassOutcome) -> Void) {
            self.outstanding = outstanding
            self.answer = answer
        }

        func report(_ outcome: PassOutcome) {
            let (answer, worst) = lock.withLock { () -> (((PassOutcome) -> Void)?, PassOutcome) in
                self.outcome = max(self.outcome, outcome)
                outstanding -= 1
                guard outstanding <= 0
                else { return (nil, self.outcome) }
                defer { self.answer = nil }
                return (self.answer, self.outcome)
            }
            answer?(worst)
        }
    }
}
