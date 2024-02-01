import Foundation
import OSLog

typealias RunClosure = () -> Void

// sourcery: autoMockable
protocol Throttling {
    func runThrottled(_ runClosure: @escaping RunClosure)
    func cancelThrottledRun()
}

final class Throttler: Throttling {
    struct Constants {
        static let defaultDelay: TimeInterval = 60.0
        fileprivate static let runQueueName = "LaunchDarkly.Throttler.runQueue"
    }

    // Exposed to let tests keep tsan happy
    let runQueue = DispatchQueue(label: Constants.runQueueName, qos: .userInitiated)
    let dispatcher: ((@escaping RunClosure) -> Void)
    let throttlingEnabled: Bool
    let maxDelay: TimeInterval
    private let logger: OSLog

    private (set) var runAttempts = -1
    private (set) var workItem: DispatchWorkItem?

    init(
        logger: OSLog,
        maxDelay: TimeInterval = Constants.defaultDelay,
        isDebugBuild: Bool = false,
        dispatcher: ((@escaping RunClosure) -> Void)? = nil) {
        self.logger = logger
        self.throttlingEnabled = !isDebugBuild
        self.maxDelay = maxDelay
        self.dispatcher = dispatcher ?? { DispatchQueue.global(qos: .userInitiated).async(execute: $0) }
    }

    func runThrottled(_ runClosure: @escaping RunClosure) {
        if let logMsg = runThrottledSync(runClosure) {
            os_log("%s", log: self.logger, type: .debug, typeName(and: #function), logMsg)
        }
    }

    func runThrottledSync(_ runClosure: @escaping RunClosure) -> String? {
        if !throttlingEnabled {
            dispatcher(runClosure)
            return typeName(and: #function) + "Executing run closure unthrottled, as throttling is disabled."
        }

        return runQueue.sync {
            runAttempts += 1

            let resetDelay = min(maxDelay, TimeInterval(pow(2.0, Double(runAttempts - 1))))
            runQueue.asyncAfter(deadline: .now() + resetDelay) { [weak self] in
                guard let self = self else { return }
                self.runAttempts = max(0, self.runAttempts - 1)
            }

            if runAttempts <= 1 {
                dispatcher(runClosure)
                return typeName(and: #function) + "Executing run closure unthrottled."
            }

            let jittered = resetDelay / 2 + Double.random(in: 0.0...(resetDelay / 2))
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.dispatcher(runClosure)
                self.workItem = nil
            }
            self.workItem?.cancel()
            self.workItem = workItem
            runQueue.asyncAfter(deadline: .now() + jittered, execute: workItem)
            return typeName(and: #function) + "Throttling run closure. Run attempts: \(runAttempts), Delay: \(jittered)"
        }
    }

    func cancelThrottledRun() {
        runQueue.sync {
            self.workItem?.cancel()
            self.workItem = nil
        }
    }
}

extension Throttler: TypeIdentifying { }
