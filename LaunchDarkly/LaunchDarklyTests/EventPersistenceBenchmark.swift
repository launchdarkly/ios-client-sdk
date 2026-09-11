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

        // Everything `EventReporter.encode` used to do per event: a fresh `JSONEncoder`, a `userInfo` dictionary
        // rebuilt from the configuration, and the array copy of the private attributes that goes into it. Measuring
        // only the `JSONEncoder()` allocation understates what reusing one is worth, because the dictionary and the
        // array are the larger half of the setup.
        let privateAttributes: [Reference] = []
        let buildingAndEncoding = measure(iterations: 100_000) {
            let event = FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
            let encoder = JSONEncoder()
            encoder.userInfo = [
                LDContext.UserInfoKeys.allAttributesPrivate: false,
                LDContext.UserInfoKeys.globalPrivateAttributes: privateAttributes.map { $0 }
            ]
            encoder.dateEncodingStrategy = .custom(dateAsMillis)
            _ = try? encoder.encode(event)
        }

        // The same work with the encoder built and configured once, which is what the reporter now does.
        let sharedEncoder = JSONEncoder()
        sharedEncoder.userInfo = [
            LDContext.UserInfoKeys.allAttributesPrivate: false,
            LDContext.UserInfoKeys.globalPrivateAttributes: privateAttributes.map { $0 }
        ]
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

    /// O3 from the encoding research: what replacing `Codable` with a hand-written writer actually buys.
    ///
    /// Measured across context shapes and privacy settings, because the research's open question is not whether a
    /// hand-written writer is faster but *where* the time goes. If the cost is the context walk and its redaction, the
    /// gap should stay roughly constant as contexts grow; if it is `Codable`'s container machinery, the gap should widen
    /// with the number of attributes encoded.
    func testHandWrittenEncoderCost() throws {
        try requireBenchmarking()

        let flag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: true)

        for (shapeName, context) in EventPersistenceBenchmark.contextShapes() {
            for (privacyName, allAttributesPrivate, globalPrivateAttributes) in EventPersistenceBenchmark.privacyShapes() {
                let codable = EventPersistenceBenchmark.makeCodableEncoder(allAttributesPrivate: allAttributesPrivate,
                                                                          globalPrivateAttributes: globalPrivateAttributes)
                let handWritten = EventJSONWriter(allAttributesPrivate: allAttributesPrivate,
                                                  globalPrivateAttributes: globalPrivateAttributes)

                let codableTime = measure(iterations: 50_000) {
                    let event = FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
                    _ = try? codable.encode(event)
                }
                let handWrittenTime = measure(iterations: 50_000) {
                    let event = FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
                    _ = handWritten.encode(event)
                }

                let bytes = handWritten.encode(FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false))?.count ?? 0

                report("encoding a feature event -- \(shapeName), \(privacyName), \(bytes) bytes out", [
                    ("Codable", codableTime),
                    ("hand-written", handWrittenTime),
                    ("saved", codableTime - handWrittenTime)
                ])
                print("  speedup                                   \(String(format: "%8.2fx", codableTime / handWrittenTime))")
            }
        }
    }

    /// The same comparison on the path a customer actually pays for, rather than on the encoder in isolation.
    func testRecordingCostByEncoder() throws {
        try requireBenchmarking()

        let context = LDContext.stub()
        let trackedFlag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: true)
        let summaryOnlyFlag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: false)

        var results: [(String, Double)] = []
        for (name, encoding) in [("Codable", EventReporter.Encoding.codable),
                                 ("hand-written", .handWritten),
                                 ("hand-written + cache", .handWrittenCachingContext)] {
            let service = DarklyServiceMock()
            var config = LDConfig.stub
            config.eventCapacity = .max
            service.config = config

            let store = EventStore.temporary(capacity: .max)
            defer { store.deleteEverything() }
            let reporter = EventReporter(service: service, onSyncComplete: nil, store: store, encoding: encoding)
            reporter.setLastEventResponseDate(Date())

            results.append(("\(name): evaluation, summary only", measure(iterations: 100_000) {
                reporter.recordFlagEvaluationEvents(flagKey: "benchmark-flag", value: true, defaultValue: false, featureFlag: summaryOnlyFlag, context: context, includeReason: false)
            }))
            results.append(("\(name): evaluation, trackEvents on", measure(iterations: 50_000) {
                reporter.recordFlagEvaluationEvents(flagKey: "benchmark-flag", value: true, defaultValue: false, featureFlag: trackedFlag, context: context, includeReason: false)
            }))
            reporter.contextCache?.resetCounters()
            results.append(("\(name): evaluation + track (commit point)", measure(iterations: 20_000) { iteration in
                reporter.recordFlagEvaluationEvents(flagKey: "benchmark-flag", value: true, defaultValue: false, featureFlag: summaryOnlyFlag, context: context, includeReason: false)
                reporter.record(CustomEvent(key: "benchmark-\(iteration)", context: context, data: nil))
            }))
            if let cache = reporter.contextCache {
                let total = cache.hits + cache.misses
                let rate = total == 0 ? 0 : 100 * Double(cache.hits) / Double(total)
                print("  \(name) at a commit point: \(cache.hits) hits / \(total) lookups (\(String(format: "%.1f", rate))%)")
            }
        }

        report("recording, per call, by encoder", results)
    }

    /// O2: reusing the last context's encoded bytes when the context has not changed.
    ///
    /// Measured at both ends of the hit rate, because the cache is only worth having if a miss costs close to nothing.
    /// The comparison `LDContext ==` is reported alongside, since that is what a hit actually pays -- and note that
    /// every feature event builds a fresh context copy, so the comparison runs against a new value each time rather
    /// than short-circuiting on identity.
    func testContextCacheCost() throws {
        try requireBenchmarking()

        let flag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: true)
        let shapes = EventPersistenceBenchmark.contextShapes()

        var comparisons: [(String, Double)] = []
        for (shapeName, context) in shapes {
            let copy = LDContext(copyFrom: context)
            comparisons.append(("LDContext == , \(shapeName)", measure(iterations: 500_000) {
                _ = context == copy
            }))
        }
        report("comparing two equal contexts", comparisons)

        // The context to alternate with differs only in its key, so a miss costs the same encode as a hit would have.
        // Alternating between contexts of different sizes would price the other context, not the miss.
        for (shapeName, context, other) in EventPersistenceBenchmark.contextShapePairs() {
            let uncached = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [])
            let allHits = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [], cachingContexts: true)
            let allMisses = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [], cachingContexts: true)

            func event(_ carried: LDContext) -> FeatureEvent {
                FeatureEvent(key: "benchmark-flag", context: carried, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
            }

            let uncachedTime = measure(iterations: 50_000) {
                _ = uncached.encode(event(context))
            }
            let hitTime = measure(iterations: 50_000) {
                _ = allHits.encode(event(context))
            }
            // Both sides of the miss comparison walk the same alternating sequence.
            let uncachedAlternating = measure(iterations: 50_000) { iteration in
                _ = uncached.encode(event(iteration.isMultiple(of: 2) ? context : other))
            }
            let missTime = measure(iterations: 50_000) { iteration in
                _ = allMisses.encode(event(iteration.isMultiple(of: 2) ? context : other))
            }

            report("hand-written encode -- \(shapeName)", [
                ("no cache", uncachedTime),
                ("cache, every event hits", hitTime),
                ("no cache, alternating contexts", uncachedAlternating),
                ("cache, every event misses", missTime),
                ("cost of a miss", missTime - uncachedAlternating)
            ])
            print("  speedup on a hit                          \(String(format: "%8.2fx", uncachedTime / hitTime))")
            print("  observed: \(allHits.contextCache?.hits ?? 0) hits all-hit, \(allMisses.contextCache?.hits ?? 0) hits alternating")
        }
    }

    /// What the per-event `JSONWriter` allocation costs, which is the cheapest of the memory questions to answer.
    func testWriterAllocationCost() throws {
        try requireBenchmarking()

        let context = LDContext.stub()
        let flag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: true)
        let writer = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [])
        let reused = JSONWriter()

        let fresh = measure(iterations: 100_000) {
            let event = FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
            _ = writer.encode(event)
        }
        let reusing = measure(iterations: 100_000) {
            let event = FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
            _ = writer.encode(event, into: reused)
        }

        report("encoding a feature event, stub context", [
            ("a fresh JSONWriter per event", fresh),
            ("one JSONWriter reused", reusing),
            ("saved", fresh - reusing)
        ])
    }

    // MARK: Corpus

    private static func makeCodableEncoder(allAttributesPrivate: Bool, globalPrivateAttributes: [Reference]) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.userInfo = [
            LDContext.UserInfoKeys.allAttributesPrivate: allAttributesPrivate,
            LDContext.UserInfoKeys.globalPrivateAttributes: globalPrivateAttributes.map { $0 }
        ]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.millisSince1970)
        }
        return encoder
    }

    private static func privacyShapes() -> [(String, Bool, [Reference])] {
        [("no redaction", false, []),
         ("1 global private", false, [Reference("email")]),
         ("all private", true, [])]
    }

    private enum ContextShape: String, CaseIterable {
        case keyOnly = "key only"
        case stub = "stub, 9 attributes"
        case wide = "20 flat attributes"
        case nested = "nested attributes"
        case multi = "multi-context"
    }

    /// Built from a key so the cache benchmark can make two contexts of identical shape that never compare equal.
    private static func makeContext(_ shape: ContextShape, key: String) -> LDContext {
        switch shape {
        case .keyOnly:
            let builder = LDContextBuilder(key: key)
            return (try? builder.build().get()) ?? LDContext.stub()
        case .stub:
            return LDContext.stub(key: key)
        case .wide:
            var builder = LDContextBuilder(key: key)
            builder.name("Wide")
            for index in 0..<20 {
                _ = builder.trySetValue("attribute\(index)", .string("value\(index)"))
            }
            return (try? builder.build().get()) ?? LDContext.stub()
        case .nested:
            var builder = LDContextBuilder(key: key)
            builder.name("Nested")
            _ = builder.trySetValue("address", ["street": "1 Main St", "city": "Springfield", "geo": ["lat": 1.5, "lon": -2.5]])
            _ = builder.trySetValue("tags", ["a", "b", "c", "d", "e"])
            return (try? builder.build().get()) ?? LDContext.stub()
        case .multi:
            var device = LDContextBuilder(key: "device-\(key)")
            device.kind("device")
            _ = device.trySetValue("os", ["name": "iOS", "version": 18])

            var builder = LDMultiContextBuilder()
            builder.addContext(LDContext.stub(key: key))
            builder.addContext((try? device.build().get()) ?? LDContext.stub())
            return (try? builder.build().get()) ?? LDContext.stub()
        }
    }

    private static func contextShapes() -> [(String, LDContext)] {
        ContextShape.allCases.map { ($0.rawValue, makeContext($0, key: "benchmark-key")) }
    }

    /// Each shape as a pair that costs the same to encode but never compares equal, for pricing a cache miss.
    private static func contextShapePairs() -> [(String, LDContext, LDContext)] {
        ContextShape.allCases.map { ($0.rawValue,
                                     makeContext($0, key: "benchmark-key"),
                                     makeContext($0, key: "benchmark-key-alternate")) }
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
