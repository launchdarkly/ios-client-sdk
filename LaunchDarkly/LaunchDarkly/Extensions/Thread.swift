import Foundation

extension Thread {
    static func performOnMain(_ executionClosure: () -> Void) {
        guard Thread.isMainThread
        else {
            DispatchQueue.main.sync {
                executionClosure()
            }
            return
        }
        executionClosure()
    }
}
