import Foundation

/// The delay bounds for one retry regime.
struct RetryRegime {
    /// The base delay for the first attempt in this regime.
    let initialDelay: TimeInterval
    /// The largest delay this regime produces.
    let maxDelay: TimeInterval
}

/// Computes the wait before the next connection attempt using exponential
/// backoff with jitter. A `normal` failure advances the backoff on the current
/// regime. An `unexpected` failure moves to the extended regime and stays there
/// until `reset()`. It is not thread safe.
final class RetryState {
    private let normal: RetryRegime
    private let extended: RetryRegime
    private let minDelay: TimeInterval

    private var inExtendedRegime = false
    private var attempts = 0

    init(normal: RetryRegime, extended: RetryRegime, minDelay: TimeInterval) {
        self.normal = normal
        self.extended = extended
        self.minDelay = minDelay
    }

    /// Streaming. Normal backoff runs from 1 second up to 30 seconds. Extended
    /// runs from 5 minutes up to 1 hour. There is no wait floor.
    static func forStreaming() -> RetryState {
        RetryState(
            normal: RetryRegime(initialDelay: 1, maxDelay: 30),
            extended: RetryRegime(initialDelay: 5 * 60, maxDelay: 60 * 60),
            minDelay: 0)
    }

    /// Polling. Normal retries at `pollInterval`. An unexpected failure backs off
    /// from 5 minutes up to 1 hour.
    static func forPolling(pollInterval: TimeInterval) -> RetryState {
        RetryState(
            normal: RetryRegime(initialDelay: pollInterval, maxDelay: pollInterval),
            extended: RetryRegime(initialDelay: max(5 * 60, pollInterval),
                                  maxDelay: max(60 * 60, pollInterval)),
            minDelay: pollInterval)
    }

    func recordFailure(unexpected: Bool) {
        if unexpected && !inExtendedRegime {
            inExtendedRegime = true
            attempts = 1
            return
        }
        attempts += 1
    }

    func reset() {
        inExtendedRegime = false
        attempts = 0
    }

    func nextDelay() -> TimeInterval {
        let regime = inExtendedRegime ? extended : normal
        let exponent = Double(max(0, attempts - 1))
        let delay = min(regime.maxDelay, regime.initialDelay * pow(2, exponent))
        return max(minDelay, delay - Double.random(in: 0...(delay / 2)))
    }
}
