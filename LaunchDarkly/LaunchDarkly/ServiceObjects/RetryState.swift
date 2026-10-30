import Foundation

private struct Constants {
    static let streamingNormalInitialDelay: TimeInterval = 1
    static let streamingNormalMaxDelay: TimeInterval = 30
    static let extendedInitialDelay: TimeInterval = 5 * 60
    static let extendedMaxDelay: TimeInterval = 60 * 60
    // The consecutive successful polls that clear the backoff.
    static let pollingResetThreshold = 2
    static let deliveryInitialDelay: TimeInterval = 1
    // Where the attempt count goes at least to on an unexpected failure, so its first wait is 2^9 initial delays.
    static let deliveryAttemptsAfterUnexpected = 10
    static let maxServerDirectedWait: TimeInterval = 60 * 60
}

/// The delay bounds for one retry regime.
struct RetryRegime {
    /// The base delay for the first attempt in this regime.
    let initialDelay: TimeInterval
    /// The largest delay this regime produces.
    let maxDelay: TimeInterval
}

/// The exponential backoff for an attempt, less a random amount up to half of it.
private func jitteredBackoff(_ regime: RetryRegime, attempts: Int) -> TimeInterval {
    let delay = min(regime.maxDelay, regime.initialDelay * pow(2, Double(max(0, attempts - 1))))
    return delay - Double.random(in: 0...(delay / 2))
}

/// Computes the wait before the streaming data source reconnects.
/// It is not thread safe.
final class StreamingRetryState {
    private let normal = RetryRegime(initialDelay: Constants.streamingNormalInitialDelay,
                                     maxDelay: Constants.streamingNormalMaxDelay)
    private let extended = RetryRegime(initialDelay: Constants.extendedInitialDelay,
                                       maxDelay: Constants.extendedMaxDelay)

    private var inExtendedRegime = false
    private var attempts = 0

    func recordFailure(unexpected: Bool) {
        if unexpected && !inExtendedRegime {
            inExtendedRegime = true
            attempts = 1
            return
        }
        attempts += 1
    }

    /// Clears the backoff. The next failure starts over in the normal regime.
    func reset() {
        inExtendedRegime = false
        attempts = 0
    }

    func nextDelay() -> TimeInterval {
        jitteredBackoff(inExtendedRegime ? extended : normal, attempts: attempts)
    }
}

/// Computes the wait before the polling data source polls again.
/// It is not thread safe.
final class PollingRetryState {
    private let pollInterval: TimeInterval
    private let extended: RetryRegime

    private var inExtendedRegime = false
    private var attempts = 0
    private var consecutiveSuccesses = 0

    init(pollInterval: TimeInterval) {
        self.pollInterval = pollInterval
        self.extended = RetryRegime(initialDelay: max(Constants.extendedInitialDelay, pollInterval),
                                    maxDelay: max(Constants.extendedMaxDelay, pollInterval))
    }

    func recordFailure(unexpected: Bool) {
        consecutiveSuccesses = 0
        if unexpected && !inExtendedRegime {
            inExtendedRegime = true
            attempts = 1
            return
        }
        attempts += 1
    }

    /// Records a successful poll. The backoff clears after enough consecutive successes.
    func recordSuccess() {
        consecutiveSuccesses += 1
        guard consecutiveSuccesses >= Constants.pollingResetThreshold
        else { return }
        // The service has recovered, so the next unexpected failure starts the backoff over.
        inExtendedRegime = false
        attempts = 0
    }

    func nextDelay() -> TimeInterval {
        // A normal failure does not grow the delay, and a success shows the service works.
        // Only an unresolved unexpected failure waits longer than the poll interval.
        guard inExtendedRegime, consecutiveSuccesses == 0
        else { return pollInterval }
        return max(pollInterval, jitteredBackoff(extended, attempts: attempts))
    }
}

/// When event delivery may post again after a failure, following the SDK Retry Behavior specification as event
/// durability §9 binds it. Android's `DeliveryRetryState` plays the same part.
///
/// A failure never stops delivery, it only makes the next post wait. An ordinary one, such as a 503 or no network,
/// waits from a second up to the flush interval, so it is never later than the schedule already would be. A refusal
/// that is unlikely to pass soon, such as a 401, waits about eight and a half minutes, doubling up to an hour, rather
/// than deleting the batch: a valid key is sometimes refused for minutes during an incident, and every event the fleet
/// recorded meanwhile would be lost. A `Retry-After` sets the wait instead. One accepted delivery puts everything back.
///
/// One per event processor, so each environment backs off on its own. Held only in memory, so a new run of the
/// application posts at once. Thread safe: a delivery's responses arrive on whichever thread the session answers on.
final class DeliveryRetryState {
    /// The wait after a first failure, which a flush waiting on the delivery that failed sits out.
    let initialDelay: TimeInterval
    private let normalCeiling: TimeInterval
    private let extendedCeiling: TimeInterval
    private let random: () -> Double

    private let lock = UnfairLock()
    // Guarded by lock.
    private var attempts = 0
    private var maxDelay: TimeInterval
    private var nextAttempt: DispatchTime?

    /// - Parameter flushInterval: the normal ceiling; never below the initial delay, so a short interval does not make
    ///   a failing service be posted to more often than once a second.
    convenience init(flushInterval: TimeInterval) {
        self.init(initialDelay: Constants.deliveryInitialDelay,
                  normalCeiling: max(flushInterval, Constants.deliveryInitialDelay),
                  extendedCeiling: Constants.extendedMaxDelay)
    }

    init(initialDelay: TimeInterval,
         normalCeiling: TimeInterval,
         extendedCeiling: TimeInterval,
         random: @escaping () -> Double = { Double.random(in: 0..<1) }) {
        self.initialDelay = initialDelay
        self.normalCeiling = normalCeiling
        self.extendedCeiling = extendedCeiling
        self.random = random
        self.maxDelay = normalCeiling
    }

    /// An accepted delivery, which is all it takes for the next failure to start from a second again.
    func recordSuccess() {
        lock.withLock {
            attempts = 0
            maxDelay = normalCeiling
            nextAttempt = nil
        }
    }

    /// - Parameters:
    ///   - unexpected: whether the failure is unlikely to pass soon: a 4xx other than 400, 408 and 429, or a TLS or
    ///     certificate failure.
    ///   - retryAfter: the wait the response asked for, or nil where it gave none.
    /// - Returns: how long nothing may be posted.
    @discardableResult
    func recordFailure(unexpected: Bool, retryAfter: TimeInterval?) -> TimeInterval {
        lock.withLock {
            if unexpected {
                attempts = max(attempts + 1, Constants.deliveryAttemptsAfterUnexpected)
                maxDelay = extendedCeiling
            } else {
                attempts += 1
            }
            let wait: TimeInterval
            if let retryAfter, retryAfter >= 0 {
                // Every instance hears the same value at the same moment, so it is jittered to keep them from posting
                // together when it runs out.
                let directed = min(retryAfter, Constants.maxServerDirectedWait)
                wait = directed - random() * (directed / 2)
            } else {
                // Not jittered: each instance's failures follow its own history, which already spreads them.
                wait = min(maxDelay, initialDelay * pow(2, Double(min(attempts - 1, 40))))
            }
            nextAttempt = .now() + wait
            return wait
        }
    }

    /// A failure of a post that went through a wait, as `flushAtClose()` and the blocking `flushAndWait` may: an extra
    /// try, not a step of the backoff. It leaves the attempt count and the ceiling as they were, so a caller flushing
    /// through a refusal several times does not push flush, the periodic delivery and the retry out to the hour. A
    /// `Retry-After` can still make the wait longer, never shorter. Once the wait has run out it is an ordinary failure.
    ///
    /// - Parameters: as `recordFailure(unexpected:retryAfter:)`.
    /// - Returns: how long nothing may be posted.
    @discardableResult
    func recordFailureDuringWait(unexpected: Bool, retryAfter: TimeInterval?) -> TimeInterval {
        let stillWaiting: TimeInterval? = lock.withLock {
            let now = DispatchTime.now()
            guard let waitingUntil = nextAttempt, now < waitingUntil
            else { return nil }
            var until = waitingUntil
            if let retryAfter, retryAfter >= 0 {
                let directed = min(retryAfter, Constants.maxServerDirectedWait)
                until = max(until, now + (directed - random() * (directed / 2)))
            }
            nextAttempt = until
            return TimeInterval(until.uptimeNanoseconds - now.uptimeNanoseconds) / 1_000_000_000
        }
        return stillWaiting ?? recordFailure(unexpected: unexpected, retryAfter: retryAfter)
    }

    /// How long until a post is allowed; zero once it is.
    var remainingWait: TimeInterval {
        lock.withLock {
            guard let nextAttempt
            else { return 0 }
            let now = DispatchTime.now()
            guard now < nextAttempt
            else {
                self.nextAttempt = nil
                return 0
            }
            return TimeInterval(nextAttempt.uptimeNanoseconds - now.uptimeNanoseconds) / 1_000_000_000
        }
    }
}
