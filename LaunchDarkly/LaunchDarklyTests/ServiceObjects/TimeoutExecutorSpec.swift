import XCTest

@testable import LaunchDarkly

final class TimeoutExecutorSpec: XCTestCase {

    // Create a specific queue and tag it so we can assert where completion ran.
    private func makeTaggedQueue(label: String = "com.test.timeout.queue") -> DispatchQueue {
        let q = DispatchQueue(label: label)
        let key = DispatchSpecificKey<String>()
        q.setSpecific(key: key, value: label)
        // stash both so tests can read them
        queueKey = key
        queueLabel = label
        return q
    }

    private var queueKey = DispatchSpecificKey<String>()
    private var queueLabel = "com.test.timeout.queue"

    // MARK: - Tests

    func test_ResultBeforeTimeout_CallsCompletionWithResult() {
        let exp = expectation(description: "completion called with result")
        let callbackQueue = makeTaggedQueue()

        TimeoutExecutor.run(
            timeout: 1.0,
            queue: callbackQueue,
            operation: { done in
                // Finish well before timeout
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    done("OK")
                }
            },
            timeoutValue: "TIMEOUT"
        ) { result in
            XCTAssertEqual(result, "OK")
            // Assert queue
            XCTAssertEqual(DispatchQueue.getSpecific(key: self.queueKey), self.queueLabel)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
    }

    func test_TimeoutWins_CallsCompletionWithTimeoutValue() {
        let exp = expectation(description: "completion called with timeout")
        let callbackQueue = makeTaggedQueue()

        TimeoutExecutor.run(
            timeout: 0.2,
            queue: callbackQueue,
            operation: { _ in
                // Complete after the timeout
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { /* never calls done */ }
            },
            timeoutValue: "TIMEOUT"
        ) { result in
            XCTAssertEqual(result, "TIMEOUT")
            // Assert queue
            XCTAssertEqual(DispatchQueue.getSpecific(key: self.queueKey), self.queueLabel)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
    }

    func test_Race_ResultAndTimeout_CompletionCalledOnce() {
        let exp = expectation(description: "completion called once")
        exp.expectedFulfillmentCount = 1

        let callbackQueue = makeTaggedQueue()
        var callCount = 0
        let countLock = NSLock()

        TimeoutExecutor.run(
            timeout: 0.15,
            queue: callbackQueue,
            operation: { done in
                // Schedule completion very close to timeout to create a race.
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.14) {
                    done("OK")
                }
            },
            timeoutValue: "TIMEOUT"
        ) { _ in
            countLock.lock(); callCount += 1; countLock.unlock()
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(callCount, 1, "Completion should be called exactly once")
    }

    func test_CompletionsRunsOnSpecifiedQueue() {
        let exp = expectation(description: "completion on specified queue")
        let callbackQueue = makeTaggedQueue(label: "com.test.specific.queue")

        TimeoutExecutor.run(
            timeout: 1.0,
            queue: callbackQueue,
            operation: { done in
                DispatchQueue.global().async { done("OK") }
            },
            timeoutValue: "TIMEOUT"
        ) { result in
            XCTAssertEqual(result, "OK")
            // Verify we're on our queue
            XCTAssertEqual(DispatchQueue.getSpecific(key: self.queueKey), self.queueLabel)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
    }

    func test_NoCompletion_NoTimeoutScheduled_OperationStillRuns() {
        // We can’t directly assert no timeout is scheduled, but we can ensure:
        //  - no completion is called (test would fail if it did)
        //  - the operation body executed (via a flag/expectation)
        let opExp = expectation(description: "operation executed")

        TimeoutExecutor.run(
            timeout: 0.1,
            queue: .main,
            operation: { done in
                // Simulate some work and signal we ran.
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                    // We pass a value to `done`—it should be ignored since completion is nil.
                    opExp.fulfill()
                    done("IGNORED")
                }
            },
            timeoutValue: "TIMEOUT",
            completion: nil // <- optional completion
        )

        // If the executor accidentally called a completion, this test would hang or require extra plumbing.
        wait(for: [opExp], timeout: 1.0)
    }

    func test_LongOperation_ResultAfterTimeout_Ignored() {
        let exp = expectation(description: "timeout fired and late result ignored")
        let callbackQueue = makeTaggedQueue()
        var observedResults: [String] = []
        let lock = NSLock()

        TimeoutExecutor.run(
            timeout: 0.1,
            queue: callbackQueue,
            operation: { done in
                // Complete after timeout
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { done("LATE") }
            },
            timeoutValue: "TIMEOUT"
        ) { result in
            lock.lock(); observedResults.append(result); lock.unlock()
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
        // Give a little extra time for any accidental second call
        Thread.sleep(forTimeInterval: 0.3)
        lock.lock(); defer { lock.unlock() }
        XCTAssertEqual(observedResults, ["TIMEOUT"])
    }
}
