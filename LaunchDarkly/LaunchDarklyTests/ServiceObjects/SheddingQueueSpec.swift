import Foundation
import XCTest
@testable import LaunchDarkly

final class SheddingQueueSpec: XCTestCase {
    let noop = { (completion: TaskHandlerCompletion) in completion() }

    func testQueueCanCompleteASingleTask() {
        let semaphore = DispatchSemaphore(value: 0)

        let task = Task(work: noop, sheddable: true) { result in
            XCTAssertEqual(result, .complete)
            semaphore.signal()
        }

        let queue = SheddingQueue()
        queue.enqueue(request: task)
        semaphore.wait()
    }

    func testQueueCanCompleteTwoTasks() {
        let blockFirstWork = DispatchSemaphore(value: 0)
        let blockUntilFullyComplete = DispatchSemaphore(value: 0)

        let delayedWork = { (completion: TaskHandlerCompletion) in
            blockFirstWork.wait()
            completion()
        }

        var executionCount = 0
        let firstTask = Task(work: delayedWork, sheddable: true) { result in
            XCTAssertEqual(result, .complete)
            executionCount += 1
        }
        let finalTask = Task(work: noop, sheddable: true) { result in
            XCTAssertEqual(result, .complete)
            executionCount += 1
            blockUntilFullyComplete.signal()
        }

        let queue = SheddingQueue()
        queue.enqueue(request: firstTask)
        queue.enqueue(request: finalTask)
        blockFirstWork.signal()
        blockUntilFullyComplete.wait()

        XCTAssertEqual(executionCount, 2)
    }

    func testQueueCanShedSubsequentRequests() {
        let blockFirstWork = DispatchSemaphore(value: 0)
        let blockUntilFullyComplete = DispatchSemaphore(value: 0)

        let delayedWork = { (completion: TaskHandlerCompletion) in
            blockFirstWork.wait()
            completion()
        }

        var sheddedExecutionCount = 0
        let sheddedWork = { (completion: TaskHandlerCompletion) in
            sheddedExecutionCount += 1
            completion()
        }

        let firstTask = Task(work: delayedWork, sheddable: true) { result in
            XCTAssertEqual(result, .complete)
        }
        var sheddedCount = 0
        let sheddingTask = Task(work: sheddedWork, sheddable: true) { result in
            sheddedCount += 1
            XCTAssertEqual(result, .shed)
        }
        let finalTask = Task(work: noop, sheddable: true) { result in
            XCTAssertEqual(result, .complete)
            blockUntilFullyComplete.signal()
        }

        let queue = SheddingQueue()
        queue.enqueue(request: firstTask)

        queue.enqueue(request: sheddingTask)
        queue.enqueue(request: sheddingTask)
        queue.enqueue(request: sheddingTask)
        queue.enqueue(request: sheddingTask)

        queue.enqueue(request: finalTask)
        blockFirstWork.signal()

        blockUntilFullyComplete.wait()

        XCTAssertEqual(sheddedExecutionCount, 0)
        XCTAssertEqual(sheddedCount, 4)
    }

    func testUnsheddableTasksDoNotShed() {
        let blockUntilQueued = DispatchSemaphore(value: 0)
        let blockUntilComplete = DispatchSemaphore(value: 0)

        let work = { (completion: TaskHandlerCompletion) in
            blockUntilQueued.wait()
            completion()
            blockUntilQueued.signal()
        }

        let group = DispatchGroup()
        var shedCount = 0
        var completeCount = 0
        let task = Task(work: work, sheddable: false) { result in
            switch result {
            case .shed:
                shedCount += 1
            case .complete:
                completeCount += 1
            default:
                XCTFail("Task should either shed or complete.")
            }
            group.leave()
        }

        let queue = SheddingQueue()

        for _ in 0...4 {
            group.enter()
            queue.enqueue(request: task)
        }
        blockUntilQueued.signal()

        group.notify(queue: .global()) {
            blockUntilComplete.signal()
        }

        blockUntilComplete.wait()

        XCTAssertEqual(shedCount, 0)
        XCTAssertEqual(completeCount, 5)
    }

    func testCanMixShedAndUnsheddable() {
        let blockUntilQueued = DispatchSemaphore(value: 0)
        let blockUntilComplete = DispatchSemaphore(value: 0)

        let work = { (completion: TaskHandlerCompletion) in
            blockUntilQueued.wait()
            completion()
            blockUntilQueued.signal()
        }

        let group = DispatchGroup()
        var shedCount = 0
        var completeCount = 0
        let completion: TaskCompletion = { result in
            switch result {
            case .shed:
                shedCount += 1
            case .complete:
                completeCount += 1
            default:
                XCTFail("Task should either shed or complete.")
            }
            group.leave()
        }
        let sheddableTask = Task(work: work, sheddable: true, completion: completion)
        let unsheddableTask = Task(work: work, sheddable: false, completion: completion)

        let queue = SheddingQueue()

        group.enter()
        queue.enqueue(request: sheddableTask) // Will complete, first job
        group.enter()
        queue.enqueue(request: unsheddableTask) // Will complete, unsheddable
        group.enter()
        queue.enqueue(request: sheddableTask) // Will be shed
        group.enter()
        queue.enqueue(request: sheddableTask) // Will be shed
        group.enter()
        queue.enqueue(request: unsheddableTask) // Will complete, unsheddable
        group.enter()
        queue.enqueue(request: unsheddableTask) // Will complete, unsheddable

        blockUntilQueued.signal()

        group.notify(queue: .global()) {
            blockUntilComplete.signal()
        }

        blockUntilComplete.wait()

        XCTAssertEqual(shedCount, 2)
        XCTAssertEqual(completeCount, 4)
    }
}
