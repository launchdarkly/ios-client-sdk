import Foundation

/// Holds a background activity assertion so a backgrounded process is not suspended mid-delivery.
///
/// Uses `ProcessInfo.performExpiringActivity` because the framework is extension-safe and cannot use
/// `UIApplication.beginBackgroundTask`. The system may refuse or end the assertion early.
///
/// Holds at most one assertion at a time. Each blocks a system thread until its work finishes, so a burst of
/// backgroundings would otherwise hold one thread each. A request arriving while one is held does not start another:
/// the held assertion runs the work once more after its current pass, which covers whatever was recorded since that
/// pass began.
final class BackgroundActivity {
    typealias Work = (_ finished: @escaping () -> Void) -> Void
    typealias Assertion = (_ reason: String, _ whileHeld: @escaping Work) -> Void

    /// Upper bound for work that never calls `finished`.
    private static let maximumDuration: TimeInterval = 30

    private let reason: String
    private let assertion: Assertion
    private let lock = UnfairLock()
    /// Only to be used while holding `lock`.
    private var isHeld = false
    /// The work to run again before the held assertion is released. Only to be used while holding `lock`.
    private var rerun: Work?

    init(reason: String, assertion: @escaping Assertion = BackgroundActivity.holdProcessAssertion) {
        self.reason = reason
        self.assertion = assertion
    }

    /// Runs `work` under an assertion released when `work` calls `finished`, the system expires it, or
    /// `maximumDuration` passes.
    func run(_ work: @escaping Work) {
        lock.lock()
        guard !isHeld
        else {
            rerun = work
            lock.unlock()
            return
        }
        isHeld = true
        lock.unlock()

        assertion(reason) { finished in
            self.runHoldingAssertion(work, finished)
        }
    }

    private func runHoldingAssertion(_ work: @escaping Work, _ finished: @escaping () -> Void) {
        work {
            self.lock.lock()
            guard let next = self.rerun
            else {
                self.isHeld = false
                self.lock.unlock()
                finished()
                return
            }
            self.rerun = nil
            self.lock.unlock()
            self.runHoldingAssertion(next, finished)
        }
    }

    /// Without assertions on this platform, `whileHeld` runs on the calling thread.
    private static func holdProcessAssertion(reason: String, whileHeld: @escaping Work) {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let finished = DispatchSemaphore(value: 0)
        // The work does not wait on the assertion, and does not run inside it. The system refuses one outright under
        // the very resource pressure this is here for, and a delivery it may suspend is better than no delivery.
        ProcessInfo.processInfo.performExpiringActivity(withReason: reason) { expired in
            guard !expired
            else {
                // The system taking the assertion back, or declining to give one. Nothing should stay blocked on it.
                finished.signal()
                return
            }
            // The assertion lasts as long as this block, which runs on a system queue, not the caller's thread.
            _ = finished.wait(timeout: .now() + maximumDuration)
        }
        whileHeld { finished.signal() }
        #else
        whileHeld {}
        #endif
    }
}
