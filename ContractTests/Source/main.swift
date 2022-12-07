import Foundation
import Vapor

let semaphore = DispatchSemaphore(value: 0)

DispatchQueue.global(qos: .userInitiated).async {
    do {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        let app = Application(env)
        defer { app.shutdown() }
        try routes(app)
        try app.run()
    } catch {
    }
    semaphore.signal()
}

let runLoop = RunLoop.current

while semaphore.wait(timeout: .now()) == .timedOut {
    runLoop.run(mode: .default, before: .distantFuture)
}
