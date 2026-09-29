import Foundation

private struct Constants {
    static let streamingNormalInitialDelay: TimeInterval = 1
    static let streamingNormalMaxDelay: TimeInterval = 30
    static let extendedInitialDelay: TimeInterval = 5 * 60
    static let extendedMaxDelay: TimeInterval = 60 * 60
    // The consecutive successful polls that clear the backoff.
    static let pollingResetThreshold = 2
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
