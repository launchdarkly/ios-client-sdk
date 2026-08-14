import Foundation

#if canImport(Darwin)
/// A mutex that wraps Darwin's `os_unfair_lock`. The lock is held behind a pointer, because `os_unfair_lock` must not
/// be copied and a stored property would be.
final class UnfairLock {
    private let unfairLock: UnsafeMutablePointer<os_unfair_lock>

    init() {
        unfairLock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        unfairLock.initialize(to: os_unfair_lock())
    }

    deinit {
        unfairLock.deinitialize(count: 1)
        unfairLock.deallocate()
    }

    func lock() {
        os_unfair_lock_lock(unfairLock)
    }

    func unlock() {
        os_unfair_lock_unlock(unfairLock)
    }
}
#else
/// `os_unfair_lock` is Darwin only, so elsewhere this is Foundation's mutex.
typealias UnfairLock = NSLock
#endif
