import Foundation

/// The delay bounds for one retry regime.
struct RetryRegime {
    /// The base delay for the first attempt in this regime.
    let initialDelay: TimeInterval
    /// The largest delay this regime produces.
    let maxDelay: TimeInterval
}

/// Computes the wait before the next connection attempt using exponential backoff with jitter.
/// A `normal` failure advances the backoff on the current regime.
/// An `unexpected` failure moves to the extended regime and stays there until enough consecutive successes clear the backoff.
/// It is not thread safe.
final class RetryState {
    private struct Constants {
        static let streamingNormalInitialDelay: TimeInterval = 1
        static let streamingNormalMaxDelay: TimeInterval = 30
        static let extendedInitialDelay: TimeInterval = 5 * 60
        static let extendedMaxDelay: TimeInterval = 60 * 60
        // The consecutive successes that clear the backoff.
        static let streamingResetThreshold = 1
        static let pollingResetThreshold = 2
    }

    private let normal: RetryRegime
    private let extended: RetryRegime
    private let minDelay: TimeInterval
    private let resetThreshold: Int

    private var inExtendedRegime = false
    private var attempts = 0
    private var consecutiveSuccesses = 0

    init(normal: RetryRegime, extended: RetryRegime, minDelay: TimeInterval, resetThreshold: Int) {
        self.normal = normal
        self.extended = extended
        self.minDelay = minDelay
        self.resetThreshold = resetThreshold
    }

    static func forStreaming() -> RetryState {
        RetryState(
            normal: RetryRegime(initialDelay: Constants.streamingNormalInitialDelay,
                                maxDelay: Constants.streamingNormalMaxDelay),
            extended: RetryRegime(initialDelay: Constants.extendedInitialDelay,
                                  maxDelay: Constants.extendedMaxDelay),
            minDelay: 0,
            resetThreshold: Constants.streamingResetThreshold)
    }

    static func forPolling(pollInterval: TimeInterval) -> RetryState {
        RetryState(
            normal: RetryRegime(initialDelay: pollInterval, maxDelay: pollInterval),
            extended: RetryRegime(initialDelay: max(Constants.extendedInitialDelay, pollInterval),
                                  maxDelay: max(Constants.extendedMaxDelay, pollInterval)),
            minDelay: pollInterval,
            resetThreshold: Constants.pollingResetThreshold)
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

    /// Records a successful operation. The backoff clears after enough consecutive successes.
    func recordSuccess() {
        consecutiveSuccesses += 1
        if consecutiveSuccesses >= resetThreshold {
            // The service has recovered, so the next failure starts over in the normal regime instead of the extended one.
            reset()
        }
    }

    private func reset() {
        inExtendedRegime = false
        attempts = 0
        consecutiveSuccesses = 0
    }

    func nextDelay() -> TimeInterval {
        // The extended regime applies only after a failure.
        // A success uses the normal regime, even when the extended regime has not cleared.
        let useExtended = inExtendedRegime && consecutiveSuccesses == 0
        let regime = useExtended ? extended : normal
        let exponent = Double(max(0, attempts - 1))
        let delay = min(regime.maxDelay, regime.initialDelay * pow(2, exponent))
        return max(minDelay, delay - Double.random(in: 0...(delay / 2)))
    }
}
