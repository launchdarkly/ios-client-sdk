#if DEBUG
import Foundation
import OSLog
@testable import LaunchDarkly

/// The Android test app's `EventPersistenceBenchmarkRunner`, for the Benchmark button: the same five sections, contexts
/// and table layout, measured against this SDK's `OutboundEventBuffer` and `EventStore` rather than a client.
///
/// Those are internal to the SDK, hence `@testable`, which only a Debug build allows. The harness is the XCTest
/// `EventPersistenceBenchmark`'s rather than Android's: a smaller warmup, since Swift is compiled ahead of time, and a
/// tenth of the iterations on a watch. Two rows differ from Android's by necessity. Serializing goes through
/// `EventJSONWriter`, whose context cache is part of the path every event takes, so a context encoded again is a hit.
/// And there is no table for hashing a context, since `LDContext` is not `Hashable`.
///
/// It runs in the app's own process beside a live client, in a Debug build, so read it as ratios between rows.
final class EventPersistenceBenchmarkRunner {
    private static let flagKey = "benchmark-flag"
    private static let creationDate = Date(timeIntervalSince1970: 1_700_000_000)
    private static let serializedEvent = Data(#"{"kind":"feature","key":"benchmark-flag","value":true,"default":false,"variation":1,"version":7,"creationDate":1740000000000}"#.utf8)
    private static let rounds = 5
    private static let bulkSizes = [100, 1_000, 10_000]

    private let scratch: URL
    private let progress: (String) -> Void
    private var output = ""
    private var folders = 0

    /// Consumes results so that the optimizer cannot prove the work is unused and delete it.
    private var sink = 0
    /// Holds an allocation so that it genuinely exists.
    private var escaped: AnyObject?

    private init(scratch: URL, progress: @escaping (String) -> Void) {
        self.scratch = scratch
        self.progress = progress
    }

    /// Runs every section, which takes from several seconds to a few minutes. Never on the main thread.
    ///
    /// - Parameters:
    ///   - scratch: a directory for the stores it measures, emptied before and after
    ///   - progress: told the title of each section as it starts, on the thread running the benchmark
    /// - Returns: the tables, headed by a line describing the device
    static func run(scratch: URL, progress: @escaping (String) -> Void) throws -> String {
        let runner = EventPersistenceBenchmarkRunner(scratch: scratch, progress: progress)
        try? FileManager.default.removeItem(at: scratch)
        defer { try? FileManager.default.removeItem(at: scratch) }
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)

        runner.output = "device=\(machine()) os=\(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        try runner.encodingCostByContextShape()
        try runner.recordingCostPerCall()
        try runner.commitPointOutliers()
        runner.contextComparisonCost()
        runner.summarySerializationCost()
        return runner.output
    }

    // MARK: Sections

    private func encodingCostByContextShape() throws {
        progress("encoding cost by context shape")
        var building: [(String, Double)] = []
        var serializing: [(String, Double)] = []

        for shape in ContextShape.allCases {
            let context = try Self.makeContext(shape, key: "benchmark-key")

            building.append((shape.rawValue, measure(iterations: 200_000) {
                escaped = Self.featureEvent(context, trackEvents: true)
            }))

            for privacy in PrivacyShape.all {
                let writer = EventJSONWriter(allAttributesPrivate: privacy.allAttributesPrivate,
                                             globalPrivateAttributes: privacy.privateAttributes)
                guard let sample = writer.encode(Self.featureEvent(context, trackEvents: true))
                else { throw BenchmarkError("the corpus produced an event that will not serialize") }

                let nanos = measure(iterations: 50_000) {
                    sink &+= writer.encode(Self.featureEvent(context, trackEvents: true))?.count ?? 0
                }
                serializing.append(("\(shape.rawValue), \(privacy.name), \(sample.count) bytes", nanos))
            }
        }

        report("building one feature event, no serialization", building)
        report("serializing one feature event", serializing)
    }

    private func recordingCostPerCall() throws {
        progress("recording cost per call")
        let buffer = OutboundEventBuffer(config: Self.config(PrivacyShape.none), encoding: .handWritten)
        let store = EventStore(directory: try newFolder(), capacity: .max, logger: .disabled)
        let context = try Self.makeContext(.stub, key: "benchmark-key")
        let untracked = Self.flag(Self.flagKey, trackEvents: false)
        let tracked = Self.flag(Self.flagKey, trackEvents: true)

        let summaryOnly = measure(iterations: 200_000) {
            _ = buffer.summarize(flagKey: Self.flagKey, reportedValue: true, featureFlag: untracked, defaultValue: false,
                                 context: context)
        }

        let fullEvent = measure(iterations: 50_000) {
            _ = buffer.summarize(flagKey: Self.flagKey, reportedValue: true, featureFlag: tracked, defaultValue: false,
                                 context: context)
            if let encoded = buffer.encode(Self.featureEvent(context, trackEvents: true)) {
                _ = store.stage(encoded)
                sink &+= encoded.count
            }
        }

        let commitPoint = measure(iterations: 20_000) {
            _ = buffer.summarize(flagKey: Self.flagKey, reportedValue: true, featureFlag: untracked, defaultValue: false,
                                 context: context)
            let custom = CustomEvent(key: "benchmark-event", context: context, data: nil, creationDate: Self.creationDate)
            if let encoded = buffer.encode(custom) {
                _ = store.stage(encoded)
                sink &+= encoded.count
            }
            for summary in buffer.takeSummaries() {
                if let encoded = buffer.encodeSummary(summary) {
                    _ = store.stage(encoded, bypassingCapacity: true)
                    sink &+= encoded.count
                }
            }
            store.commit()
        }

        report("recording, per call", [
            ("evaluation, summary only", summaryOnly),
            ("evaluation, full event", fullEvent),
            ("evaluation + track (commit point)", commitPoint)
        ])
    }

    private func commitPointOutliers() throws {
        let buffer = OutboundEventBuffer(config: Self.config(PrivacyShape.none), encoding: .handWritten)
        let context = try Self.makeContext(.stub, key: "benchmark-key")
        let tracked = Self.flag(Self.flagKey, trackEvents: true)

        // A store of its own for each size and each row, so that a log inherited from an earlier measurement does not
        // charge the next one for the file it had already grown.
        for calls in Self.bulkSizes {
            progress("commit point outliers, \(count(calls)) calls")
            let committing = EventStore(directory: try newFolder(), capacity: .max, logger: .disabled)
            let staging = EventStore(directory: try newFolder(), capacity: .max, logger: .disabled)

            let commits = measureDistribution(iterations: calls) {
                _ = committing.stage(Self.serializedEvent)
                committing.commit()
            }
            let stagedOnly = measureDistribution(iterations: calls) {
                _ = buffer.summarize(flagKey: Self.flagKey, reportedValue: true, featureFlag: tracked, defaultValue: false,
                                     context: context)
                if let encoded = buffer.encode(Self.featureEvent(context, trackEvents: true)) {
                    _ = staging.stage(encoded)
                    sink &+= encoded.count
                }
            }

            reportDistribution("one call, \(count(calls)) of them, on the caller's thread", [
                ("track, commits on this thread", commits),
                ("evaluation, staged only", stagedOnly)
            ])
        }
    }

    private func contextComparisonCost() {
        progress("context comparison cost")
        var comparisons: [(String, Double)] = []

        for shape in ContextShape.allCases {
            guard let context = try? Self.makeContext(shape, key: "benchmark-key"),
                  let rebuilt = try? Self.makeContext(shape, key: "benchmark-key"),
                  context == rebuilt
            else {
                // Unequal, the figures below would measure an early exit rather than a comparison.
                comparisons.append(("\(shape.rawValue): rebuilt context is not equal", 0))
                continue
            }
            let sameInstance = context

            comparisons.append(("same instance, \(shape.rawValue)", measure(iterations: 500_000) {
                sink &+= context == sameInstance ? 1 : 0
            }))
            comparisons.append(("independently built, \(shape.rawValue)", measure(iterations: 200_000) {
                sink &+= context == rebuilt ? 1 : 0
            }))
        }

        report("comparing two equal contexts", comparisons)
    }

    private func summarySerializationCost() {
        progress("summary serialization cost")
        guard let context = try? Self.makeContext(.stub, key: "benchmark-key")
        else { return }
        var results: [(String, Double)] = []

        for flagCount in [1, 10, 50] {
            let buffer = OutboundEventBuffer(config: Self.config(PrivacyShape.none), encoding: .handWritten)
            let flags = (0..<flagCount).map { Self.flag("\(Self.flagKey)-\($0)", trackEvents: false) }
            let summarize = {
                for flag in flags {
                    _ = buffer.summarize(flagKey: flag.flagKey, reportedValue: true, featureFlag: flag, defaultValue: false,
                                         context: context)
                }
            }

            let countingOnly = measure(iterations: 20_000) { summarize() }
            // Drained, so the counters left behind above do not inflate the first serialized round.
            _ = buffer.takeSummaries()

            let countingAndSerializing = measure(iterations: 20_000) {
                summarize()
                for summary in buffer.takeSummaries() {
                    sink &+= buffer.encodeSummary(summary)?.count ?? 0
                }
            }

            results.append(("\(flagCount) flags: counting only", countingOnly))
            results.append(("\(flagCount) flags: counting + serializing", countingAndSerializing))
            results.append(("\(flagCount) flags: serializing alone", countingAndSerializing - countingOnly))
        }

        report("turning counters into a summary event", results)
    }

    // MARK: Corpus

    private enum ContextShape: String, CaseIterable {
        case keyOnly = "key only"
        case stub = "stub, 9 attributes"
        case wide = "20 flat attributes"
        case nested = "nested attributes"
        case multi = "multi-context"
    }

    private static func makeContext(_ shape: ContextShape, key: String) throws -> LDContext {
        switch shape {
        case .keyOnly:
            return try LDContextBuilder(key: key).build().get()
        case .stub:
            return try stubContext(key)
        case .wide:
            var builder = LDContextBuilder(key: key)
            builder.name("Wide")
            for index in 0..<20 {
                _ = builder.trySetValue("attribute\(index)", .string("value\(index)"))
            }
            return try builder.build().get()
        case .nested:
            var builder = LDContextBuilder(key: key)
            builder.name("Nested")
            _ = builder.trySetValue("address", ["street": "1 Main St", "city": "Springfield", "geo": ["lat": 1.5, "lon": -2.5]])
            _ = builder.trySetValue("tags", ["a", "b", "c", "d", "e"])
            return try builder.build().get()
        case .multi:
            var device = LDContextBuilder(key: "device-\(key)")
            device.kind("device")
            _ = device.trySetValue("os", ["name": "iOS", "version": 18])
            var builder = LDMultiContextBuilder()
            builder.addContext(try stubContext(key))
            builder.addContext(try device.build().get())
            return try builder.build().get()
        }
    }

    /// Nine attributes, the same nine as the Android runner's stub context.
    private static func stubContext(_ key: String) throws -> LDContext {
        var builder = LDContextBuilder(key: key)
        builder.name("Stub Context")
        _ = builder.trySetValue("firstName", "Ada")
        _ = builder.trySetValue("lastName", "Lovelace")
        _ = builder.trySetValue("email", "ada@example.com")
        _ = builder.trySetValue("country", "US")
        _ = builder.trySetValue("age", 36)
        _ = builder.trySetValue("score", 12.5)
        _ = builder.trySetValue("verified", true)
        _ = builder.trySetValue("plan", "enterprise")
        return try builder.build().get()
    }

    private struct PrivacyShape {
        let name: String
        let allAttributesPrivate: Bool
        let privateAttributes: [Reference]

        static let none = PrivacyShape(name: "no redaction", allAttributesPrivate: false, privateAttributes: [])
        static let all = [
            none,
            PrivacyShape(name: "1 global private", allAttributesPrivate: false, privateAttributes: [Reference("email")]),
            PrivacyShape(name: "all private", allAttributesPrivate: true, privateAttributes: [])
        ]
    }

    private static func config(_ privacy: PrivacyShape) -> LDConfig {
        var config = LDConfig(mobileKey: "benchmark", autoEnvAttributes: .disabled)
        config.eventCapacity = .max
        config.allContextAttributesPrivate = privacy.allAttributesPrivate
        config.privateContextAttributes = privacy.privateAttributes
        return config
    }

    private static func flag(_ key: String, trackEvents: Bool) -> FeatureFlag {
        FeatureFlag(flagKey: key, value: true, variation: 1, flagVersion: 7, trackEvents: trackEvents)
    }

    private static func featureEvent(_ context: LDContext, trackEvents: Bool) -> FeatureEvent {
        FeatureEvent(key: flagKey, context: context, value: true, defaultValue: false,
                     featureFlag: flag(flagKey, trackEvents: trackEvents), includeReason: false, isDebug: false,
                     creationDate: creationDate)
    }

    // MARK: Harness

    /// Times `body`, returning nanoseconds per iteration: warmed, then the fastest of several rounds, since a
    /// descheduled thread or a page fault can only ever make a round slower.
    private func measure(iterations: Int, _ body: () -> Void) -> Double {
        #if os(watchOS)
        let measuredIterations = max(1, iterations / 10)
        #else
        let measuredIterations = iterations
        #endif

        for _ in 0..<max(1, measuredIterations / 100) {
            body()
        }

        var best = Double.greatestFiniteMagnitude
        for _ in 0..<Self.rounds {
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<measuredIterations {
                body()
            }
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            best = min(best, Double(elapsed) / Double(measuredIterations))
        }
        return best
    }

    private struct Distribution {
        let median: Double
        let mean: Double
        let p999: Double
        let worst: Double
    }

    /// Times every call rather than the loop, in one round, so the tail survives to be reported. One call of warmup,
    /// which is what it takes to get the log open.
    private func measureDistribution(iterations: Int, _ body: () -> Void) -> Distribution {
        body()
        var samples = [Double](repeating: 0, count: iterations)
        for index in 0..<iterations {
            let start = DispatchTime.now().uptimeNanoseconds
            body()
            samples[index] = Double(DispatchTime.now().uptimeNanoseconds - start)
        }

        let mean = samples.reduce(0, +) / Double(iterations)
        samples.sort()
        return Distribution(median: samples[iterations / 2],
                            mean: mean,
                            p999: samples[min(iterations - 1, (iterations * 999) / 1_000)],
                            worst: samples[iterations - 1])
    }

    private func report(_ title: String, _ results: [(String, Double)]) {
        let width = results.map { $0.0.count }.max() ?? 0
        output += "\n\(title)\n"
        for (name, nanoseconds) in results {
            output += "  \(name.padding(toLength: width, withPad: " ", startingAt: 0))  \(format(nanoseconds))\n"
        }
    }

    private func reportDistribution(_ title: String, _ results: [(String, Distribution)]) {
        let width = results.map { $0.0.count }.max() ?? 0
        output += "\n\(title)\n"
        output += "  \(String(repeating: " ", count: width))  \(column("median"))  \(column("mean"))  \(column("p99.9"))  \(column("worst"))\n"
        for (name, distribution) in results {
            output += "  \(name.padding(toLength: width, withPad: " ", startingAt: 0))  \(format(distribution.median))"
                + "  \(format(distribution.mean))  \(format(distribution.p999))  \(format(distribution.worst))\n"
        }
    }

    private func newFolder() throws -> URL {
        let folder = scratch.appendingPathComponent("store-\(folders)", isDirectory: true)
        folders += 1
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// The hardware model, such as `iPhone17,1`. A simulator reports only the host's architecture, so it is named for
    /// the device it simulates instead.
    private static func machine() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return "\(simulated) (simulator)"
        }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    private func column(_ title: String) -> String {
        String(repeating: " ", count: max(0, 11 - title.count)) + title
    }

    private func count(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
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

private struct BenchmarkError: LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}
#endif
