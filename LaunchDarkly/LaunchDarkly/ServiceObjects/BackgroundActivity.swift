import Foundation

/// The extra execution time a backgrounded application can ask the system for, held for the length of one piece of
/// work.
///
/// The system suspends a backgrounded process as soon as it goes idle, which would abandon a delivery that has only
/// just reached the network. An assertion asks the system to hold the suspension off until the work reports itself
/// finished or the system runs out of patience, whichever comes first.
///
/// This uses `ProcessInfo.performExpiringActivity` rather than the more familiar `UIApplication.beginBackgroundTask`
/// because the framework is built extension-safe and `UIApplication.shared` is unavailable to it. Both take out the
/// same kind of assertion; they differ only in how it is asked for.
///
/// The system may refuse the request or end it early, so this widens the window in which a delivery can finish rather
/// than guaranteeing one. Whatever does not get out is already on disk before any of this starts.
enum BackgroundActivity {
    /// The longest the assertion is held for work that never reports back. The system's own budget is much shorter in
    /// practice; this only exists so a caller that never calls `finished` cannot hold a thread indefinitely.
    private static let maximumDuration: TimeInterval = 30

    /// Runs `work` while holding an assertion, releasing it when `work` calls `finished`, when the system expires the
    /// activity, or after `maximumDuration` — whichever comes first.
    ///
    /// `work` runs on a system-provided background queue and should call `finished` once; further calls do nothing.
    /// On a platform with no such assertion to take, `work` runs on the calling thread and only the assertion is
    /// missing.
    static func run(reason: String, work: @escaping (_ finished: @escaping () -> Void) -> Void) {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let finished = DispatchSemaphore(value: 0)
        ProcessInfo.processInfo.performExpiringActivity(withReason: reason) { expired in
            guard !expired
            else {
                // The system's second call into this block: it wants the process back, so release the first one.
                finished.signal()
                return
            }
            work { finished.signal() }
            // The assertion lasts exactly as long as this block, so holding it means blocking here. This is a queue
            // the system supplies for the purpose, never the main thread.
            _ = finished.wait(timeout: .now() + maximumDuration)
        }
        #else
        work {}
        #endif
    }
}
