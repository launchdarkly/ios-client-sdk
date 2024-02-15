import Foundation

enum TaskResult {
    case complete
    case error
    case shed
}

typealias TaskHandlerCompletion = () -> Void
typealias TaskHandler = (_ completion: @escaping TaskHandlerCompletion) -> Void
typealias TaskCompletion = (_ result: TaskResult) -> Void

struct Task {
    let work: TaskHandler
    let sheddable: Bool
    let completion: TaskCompletion
}

class SheddingQueue {
    private let stateQueue: DispatchQueue = DispatchQueue(label: "StateQueue")
    private let identifyQueue: DispatchQueue = DispatchQueue(label: "IdentifyQueue")

    private var inFlight: Task?
    private var queue: [Task] = []

    func enqueue(request: Task) {
        stateQueue.async { [self] in
            guard inFlight != nil else {
                inFlight = request
                identifyQueue.async { self.execute() }
                return
            }

            if let lastTask = queue.last, lastTask.sheddable {
                queue.removeLast()
                lastTask.completion(.shed)
            }

            queue.append(request)
        }
    }

    private func execute() {
        var nextTask: Task?

        stateQueue.sync {
            nextTask = inFlight
        }

        if nextTask == nil {
            return
        }

        guard let request = nextTask else { return }

        request.work() { [self] in
            request.completion(.complete)

            stateQueue.sync {
                inFlight = queue.first
                if inFlight != nil {
                    queue.remove(at: 0)
                    identifyQueue.async { self.execute() }
                }
            }
        }
    }
}
