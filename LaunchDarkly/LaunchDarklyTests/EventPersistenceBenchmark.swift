import XCTest
import Foundation
@testable import LaunchDarkly

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Measures what recording an event costs, so the choices behind `EventStore` can be checked rather than assumed.
///
/// Skipped unless `LD_EVENT_BENCH=1`, because the durability figures spend seconds waiting on the disk on purpose and
/// nothing here asserts anything a regression would trip.
///
///     LD_EVENT_BENCH=1 xcrun xctest -XCTest LaunchDarklyTests.EventPersistenceBenchmark <bundle>
final class EventPersistenceBenchmark: XCTestCase {
    private func requireBenchmarking() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LD_EVENT_BENCH"] == "1",
                          "Set LD_EVENT_BENCH=1 to measure event recording")
    }

    /// The claim W3 rests on: taking a lock is cheap enough to do once per evaluation, and a queue hop is not.
    func testCriticalSectionCost() throws {
        try requireBenchmarking()

        let lock = UnfairLock()
        let queue = DispatchQueue(label: "com.launchdarkly.benchmark")
        var counter = 0

        report("critical section, uncontended", [
            ("UnfairLock lock/unlock", measure(iterations: 2_000_000) {
                lock.lock()
                counter += 1
                lock.unlock()
            }),
            ("DispatchQueue.sync", measure(iterations: 200_000) {
                queue.sync { counter += 1 }
            })
        ])

        // Contended, which is what concurrent evaluations actually do to it.
        report("critical section, 8 threads contending", [
            ("UnfairLock lock/unlock", measureConcurrent(threads: 8, iterationsPerThread: 200_000) {
                lock.lock()
                counter += 1
                lock.unlock()
            }),
            ("DispatchQueue.sync", measureConcurrent(threads: 8, iterationsPerThread: 20_000) {
                queue.sync { counter += 1 }
            })
        ])

        XCTAssertGreaterThan(counter, 0)
    }

    /// Why the store writes and does not sync: the gap between handing bytes to the kernel and insisting they are on
    /// the medium is three orders of magnitude, and only the second one survives losing the kernel.
    func testDurabilityPrimitiveCost() throws {
        try requireBenchmarking()

        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let descriptor = file.withUnsafeFileSystemRepresentation { open($0!, O_WRONLY | O_APPEND | O_CREAT, 0o600) }
        defer {
            close(descriptor)
            try? FileManager.default.removeItem(at: file)
        }
        XCTAssertGreaterThanOrEqual(descriptor, 0)

        let payload = [UInt8](repeating: 0x41, count: 512)

        var results: [(String, Double)] = [
            ("write(2), 512 bytes", measure(iterations: 200_000) {
                payload.withUnsafeBytes { _ = write(descriptor, $0.baseAddress, $0.count) }
            }),
            ("write(2) + fsync", measure(iterations: 500) {
                payload.withUnsafeBytes { _ = write(descriptor, $0.baseAddress, $0.count) }
                _ = fsync(descriptor)
            })
        ]

        #if canImport(Darwin)
        results.append(("write(2) + F_FULLFSYNC", measure(iterations: 200) {
            payload.withUnsafeBytes { _ = write(descriptor, $0.baseAddress, $0.count) }
            _ = fcntl(descriptor, F_FULLFSYNC)
        }))
        #endif

        report("making 512 bytes durable", results)
    }

    /// What the store adds to recording an event, separated from what serializing one costs.
    func testStoreCost() throws {
        try requireBenchmarking()

        let store = EventStore.temporary(capacity: .max)
        defer { store.deleteEverything() }
        let event = Data(#"{"kind":"feature","key":"benchmark-flag","value":true,"default":false,"variation":1,"version":7,"creationDate":1740000000000}"#.utf8)

        let stagedOnly = measure(iterations: 200_000) {
            _ = store.stage(event)
        }

        let committingStore = EventStore.temporary(capacity: .max)
        defer { committingStore.deleteEverything() }
        let committedEach = measure(iterations: 100_000) {
            _ = committingStore.stage(event)
            committingStore.commit()
        }

        report("appending one \(event.count) byte event", [
            ("stage, committed at the 16 KiB threshold", stagedOnly),
            ("stage + commit, every event", committedEach)
        ])
    }

    /// The figures that decide whether this is affordable: what an evaluation and a track cost end to end.
    func testRecordingCost() throws {
        try requireBenchmarking()

        let service = DarklyServiceMock()
        var config = LDConfig.stub
        config.eventCapacity = .max
        service.config = config

        let store = EventStore.temporary(capacity: .max)
        defer { store.deleteEverything() }
        let reporter = EventReporter(service: service, onSyncComplete: nil, store: store)
        let context = LDContext.stub()
        let trackedFlag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: true)
        let summaryOnlyFlag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: false)
        reporter.setLastEventResponseDate(Date())

        let summarized = measure(iterations: 100_000) {
            reporter.recordFlagEvaluationEvents(flagKey: "benchmark-flag", value: true, defaultValue: false, featureFlag: summaryOnlyFlag, context: context, includeReason: false)
        }

        let tracked = measure(iterations: 50_000) {
            reporter.recordFlagEvaluationEvents(flagKey: "benchmark-flag", value: true, defaultValue: false, featureFlag: trackedFlag, context: context, includeReason: false)
        }

        // A commit point: the summary of what came before it, the event itself, and the write that makes both durable.
        let commitPoint = measure(iterations: 20_000) { iteration in
            reporter.recordFlagEvaluationEvents(flagKey: "benchmark-flag", value: true, defaultValue: false, featureFlag: summaryOnlyFlag, context: context, includeReason: false)
            reporter.record(CustomEvent(key: "benchmark-\(iteration)", context: context, data: nil))
        }

        report("recording, per call", [
            ("evaluation, summary only", summarized),
            ("evaluation, trackEvents on", tracked),
            ("evaluation + track (commit point)", commitPoint)
        ])
    }

    /// Where an evaluation's time actually goes, since serializing it is the one cost this design moves off the delivery
    /// thread and onto the caller's.
    func testSerializationCost() throws {
        try requireBenchmarking()

        let context = LDContext.stub()
        let flag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: true)

        let dateAsMillis: (Date, Encoder) throws -> Void = { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.millisSince1970)
        }

        let building = measure(iterations: 200_000) {
            let event = FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
            _ = event.kind
        }

        let buildingAndEncoding = measure(iterations: 100_000) {
            let event = FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .custom(dateAsMillis)
            _ = try? encoder.encode(event)
        }

        // The same work with the encoder built once, to show what a fresh `JSONEncoder` per event is worth.
        let sharedEncoder = JSONEncoder()
        sharedEncoder.dateEncodingStrategy = .custom(dateAsMillis)
        let reusingEncoder = measure(iterations: 100_000) {
            let event = FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
            _ = try? sharedEncoder.encode(event)
        }

        report("preparing one feature event", [
            ("build the event only", building),
            ("build + encode, encoder per event", buildingAndEncoding),
            ("build + encode, encoder reused", reusingEncoder)
        ])
    }

    // MARK: Harness

    private func measure(iterations: Int, _ body: () -> Void) -> Double {
        measure(iterations: iterations) { _ in body() }
    }

    private func measure(iterations: Int, _ body: (Int) -> Void) -> Double {
        // Warm up, so the first allocation or page fault is not charged to the measurement.
        for iteration in 0..<max(1, iterations / 100) {
            body(iteration)
        }

        let start = monotonicNanoseconds()
        for iteration in 0..<iterations {
            body(iteration)
        }
        let elapsed = monotonicNanoseconds() - start
        return Double(elapsed) / Double(iterations)
    }

    private func measureConcurrent(threads: Int, iterationsPerThread: Int, _ body: () -> Void) -> Double {
        let start = monotonicNanoseconds()
        DispatchQueue.concurrentPerform(iterations: threads) { _ in
            for _ in 0..<iterationsPerThread {
                body()
            }
        }
        let elapsed = monotonicNanoseconds() - start
        return Double(elapsed) / Double(threads * iterationsPerThread)
    }

    private func monotonicNanoseconds() -> UInt64 {
        var now = timespec()
        clock_gettime(CLOCK_MONOTONIC, &now)
        return UInt64(now.tv_sec) * 1_000_000_000 + UInt64(now.tv_nsec)
    }

    private func report(_ title: String, _ results: [(String, Double)]) {
        let width = results.map { $0.0.count }.max() ?? 0
        print("\n\(title)")
        for (name, nanoseconds) in results {
            let padded = name.padding(toLength: width, withPad: " ", startingAt: 0)
            print("  \(padded)  \(format(nanoseconds))")
        }
    }

    private func format(_ nanoseconds: Double) -> String {
        if nanoseconds >= 1_000_000 {
            return String(format: "%8.2f ms", nanoseconds / 1_000_000)
        }
        if nanoseconds >= 1_000 {
            return String(format: "%8.2f µs", nanoseconds / 1_000)
        }
        return String(format: "%8.1f ns", nanoseconds)
    }
}
