import Foundation
import OSLog

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
    /// What grants the assertion, so a test can refuse one, or expire one, without the system's cooperation.
    typealias ExpiringActivity = (_ reason: String, _ whileGranted: @escaping (_ expired: Bool) -> Void) -> Void

    /// Upper bound for work that never calls `finished`.
    private static let maximumDuration: TimeInterval = 30

    private let reason: String
    private let assertion: Assertion
    private let lock = UnfairLock()
    /// Only to be used while holding `lock`.
    private var isHeld = false
    /// The work to run again before the held assertion is released. Only to be used while holding `lock`.
    private var rerun: Work?

    init(reason: String, assertion: @escaping Assertion) {
        self.reason = reason
        self.assertion = assertion
    }

    convenience init(reason: String, logger: OSLog) {
        self.init(reason: reason, assertion: BackgroundActivity.processAssertion(logger: logger))
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

    /// An assertion from the process, over an injectable system call and cap so that a test can drive both.
    ///
    /// Without assertions on this platform, `whileHeld` runs on the calling thread.
    static func processAssertion(logger: OSLog,
                                 perform: @escaping ExpiringActivity = BackgroundActivity.performExpiringActivity,
                                 maximumDuration: TimeInterval = BackgroundActivity.maximumDuration) -> Assertion {
        { reason, whileHeld in
            #if os(iOS) || os(tvOS) || os(watchOS)
            let finished = DispatchSemaphore(value: 0)
            // The work does not wait on the assertion, and does not run inside it. The system refuses one outright
            // under the very resource pressure this is here for, and a delivery it may suspend is better than no
            // delivery.
            perform(reason) { expired in
                guard !expired
                else {
                    // The system taking the assertion back, or declining to give one. Nothing should stay blocked on
                    // it, and the work goes ahead either way.
                    os_log("%s unprotected by a background assertion: %s",
                           log: logger, type: .debug, String(describing: BackgroundActivity.self), reason)
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

    private static func performExpiringActivity(_ reason: String, _ whileGranted: @escaping (Bool) -> Void) {
        #if os(iOS) || os(tvOS) || os(watchOS)
        ProcessInfo.processInfo.performExpiringActivity(withReason: reason, using: whileGranted)
        #endif
    }
}
