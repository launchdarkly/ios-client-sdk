import Foundation

let semaphore = DispatchSemaphore(value: 0)

DispatchQueue.global(qos: .userInitiated).async {
    do {
        try app(.detect()).run()
    } catch {
    }
    semaphore.signal()
}

let runLoop = RunLoop.current

while semaphore.wait(timeout: .now()) == .timedOut {
    runLoop.run(mode: .default, before: .distantFuture)
}
