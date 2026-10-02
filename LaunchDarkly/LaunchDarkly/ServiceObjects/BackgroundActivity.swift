import Foundation

/// Holds a background activity assertion so a backgrounded process is not suspended mid-delivery.
///
/// Uses `ProcessInfo.performExpiringActivity` because the framework is extension-safe and cannot use
/// `UIApplication.beginBackgroundTask`. The system may refuse or end the assertion early.
enum BackgroundActivity {
    /// Upper bound for work that never calls `finished`.
    private static let maximumDuration: TimeInterval = 30

    /// Runs `work` under an assertion released when `work` calls `finished`, the system expires it, or
    /// `maximumDuration` passes. Without assertions on this platform, `work` runs on the calling thread.
    static func run(reason: String, work: @escaping (_ finished: @escaping () -> Void) -> Void) {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let finished = DispatchSemaphore(value: 0)
        ProcessInfo.processInfo.performExpiringActivity(withReason: reason) { expired in
            guard !expired
            else {
                // Expiration: release the blocked first call.
                finished.signal()
                return
            }
            work { finished.signal() }
            // The assertion lasts as long as this block, which runs on a system queue, not main.
            _ = finished.wait(timeout: .now() + maximumDuration)
        }
        #else
        work {}
        #endif
    }
}
