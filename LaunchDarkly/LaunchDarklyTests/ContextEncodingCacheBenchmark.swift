import XCTest
import Foundation
@testable import LaunchDarkly

#if canImport(Darwin)
import Darwin
#endif

/// What reusing an encoded context across a run of events is worth, measured both ways.
///
/// The counterpart of `EventPersistenceBenchmark#contextEncodingCacheCostByContextShape` in the Android SDK, and
/// deliberately so: same context shapes, same privacy settings, same warm-then-fastest-of-five aggregation, same run
/// length. **Run this in the Simulator and that one in an emulator and both are executing on the host Mac's cores**,
/// which is the only way the two platforms' encoders have ever been compared without a difference in silicon sitting
/// in the middle of the answer.
///
/// Only the shapes whose output is byte-identical on both platforms are worth quoting across them; the byte counts are
/// printed next to every row so that can be checked rather than assumed.
///
/// Skipped unless `LD_EVENT_BENCH=1`, because nothing here asserts anything a regression would trip and the run takes
/// about 25 seconds.
///
/// Setting it is more awkward than it looks: `xcodebuild`'s own environment does not reach the test process, and
/// neither does `TEST_RUNNER_`-prefixed. It has to come from the scheme's Test action, which also needs
/// `shouldUseLaunchSchemeArgsEnv = "NO"` or the block is ignored in favour of the Launch action's. Rather than leave
/// that in the shared scheme, where it would run this on every CI build, set it in Xcode for a local run or patch the
/// scheme for a scripted one:
///
///     sed -i '' 's/shouldUseLaunchSchemeArgsEnv = "YES"/shouldUseLaunchSchemeArgsEnv = "NO"/' \
///       LaunchDarkly.xcodeproj/xcshareddata/xcschemes/LaunchDarkly_iOS.xcscheme
///     # add an <EnvironmentVariables> block with LD_EVENT_BENCH=1 inside <TestAction>, then:
///     xcodebuild test -project LaunchDarkly.xcodeproj -scheme LaunchDarkly_iOS \
///       -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
///       -only-testing:LaunchDarklyTests/ContextEncodingCacheBenchmark SWIFT_OPTIMIZATION_LEVEL=-O
///
/// `SWIFT_OPTIMIZATION_LEVEL=-O` is not optional. The test configuration is Debug, and a `-Onone` build measures
/// something no application ever runs.
final class ContextEncodingCacheBenchmark: XCTestCase {
    /// How many times each timed loop is repeated; the fastest round is reported. Same as Android's, because the
    /// aggregation is what decides whether the two platforms' numbers can go in one table.
    private static let rounds = 5

    /// How many events a commit encodes in one go, matching the pending threshold on both platforms.
    private static let pendingRun = 32

    private func requireBenchmarking() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LD_EVENT_BENCH"] == "1",
                          "Set LD_EVENT_BENCH=1 to measure event encoding")
    }

    func testContextEncodingCacheCostByContextShape() throws {
        try requireBenchmarking()

        let flag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: true)
        // Fixed rather than `Date()`, so repeated encodes produce identical bytes and the clock call is not charged
        // to the encoder. Without it the equality check below compares two different milliseconds.
        let creationDate = Date(timeIntervalSince1970: 1_700_000_000)
        var single: [Comparison] = []
        var runs: [Comparison] = []

        for (shapeName, context) in ContextEncodingCacheBenchmark.contextShapes() {
            for (privacyName, allAttributesPrivate, globalPrivate) in ContextEncodingCacheBenchmark.privacyShapes() {
                func writer(caching: Bool) -> EventJSONWriter {
                    EventJSONWriter(allAttributesPrivate: allAttributesPrivate,
                                    globalPrivateAttributes: globalPrivate,
                                    cachingContexts: caching)
                }
                func event() -> FeatureEvent {
                    FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false,
                                 featureFlag: flag, includeReason: false, isDebug: false, creationDate: creationDate)
                }

                let uncached = writer(caching: false), cached = writer(caching: true)
                let sample = try XCTUnwrap(cached.encode(event()))
                XCTAssertEqual(uncached.encode(event()), sample, "caching changed the bytes, which it is not allowed to do")

                let without = measure(iterations: 50_000) { _ = uncached.encode(event()) }
                let with = measure(iterations: 50_000) { _ = cached.encode(event()) }

                single.append(Comparison(name: "\(shapeName), \(privacyName), \(sample.count) bytes",
                                         without: without, with: with))
            }

            // Only the unredacted case for the run table: redaction is the same lever pulled harder, and the first
            // table already shows how it moves.
            let uncachedRun = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [], cachingContexts: false)
            let cachedRun = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [], cachingContexts: true)
            let run = (0..<ContextEncodingCacheBenchmark.pendingRun).map { _ in
                FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false,
                             featureFlag: flag, includeReason: false, isDebug: false, creationDate: creationDate)
            }

            let withoutRun = measure(iterations: 2_000) {
                for event in run { _ = uncachedRun.encode(event) }
            } / Double(ContextEncodingCacheBenchmark.pendingRun)
            let withRun = measure(iterations: 2_000) {
                for event in run { _ = cachedRun.encode(event) }
            } / Double(ContextEncodingCacheBenchmark.pendingRun)

            runs.append(Comparison(name: shapeName, without: withoutRun, with: withRun))
        }

        report("serializing one feature event", single)
        report("serializing a run of \(ContextEncodingCacheBenchmark.pendingRun) events, per event", runs)
    }

    // MARK: Corpus
    //
    // Identical to the Android benchmark's, so that rows whose byte counts match can be quoted side by side.

    private enum ContextShape: String, CaseIterable {
        case keyOnly = "key only"
        case stub = "stub, 9 attributes"
        case wide = "20 flat attributes"
        case nested = "nested attributes"
        case multi = "multi-context"
    }

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

    private static func privacyShapes() -> [(String, Bool, [Reference])] {
        [("no redaction", false, []),
         ("1 global private", false, [Reference("email")]),
         ("all private", true, [])]
    }

    // MARK: Harness

    private struct Comparison {
        let name: String
        let without: Double
        let with: Double
    }

    /// Times `body`, returning nanoseconds per iteration: warmed, then run several times with the fastest round
    /// reported, since a descheduled thread or a page fault can only ever make a round slower.
    private func measure(iterations: Int, _ body: () -> Void) -> Double {
        for _ in 0..<max(1, iterations / 100) {
            body()
        }

        var best = Double.greatestFiniteMagnitude
        for _ in 0..<ContextEncodingCacheBenchmark.rounds {
            let start = monotonicNanoseconds()
            for _ in 0..<iterations {
                body()
            }
            let elapsed = monotonicNanoseconds() - start
            best = min(best, Double(elapsed) / Double(iterations))
        }
        return best
    }

    private func monotonicNanoseconds() -> UInt64 {
        var now = timespec()
        clock_gettime(CLOCK_MONOTONIC, &now)
        return UInt64(now.tv_sec) * 1_000_000_000 + UInt64(now.tv_nsec)
    }

    private func report(_ title: String, _ results: [Comparison]) {
        let width = results.map { $0.name.count }.max() ?? 0
        var out = "\n\(title)\n  \(pad("", width))  \(column("no cache"))  \(column("cached"))  \(column("saved"))\n"
        for result in results {
            let saved = 100 * (result.without - result.with) / result.without
            out += "  \(pad(result.name, width))  \(format(result.without))  \(format(result.with))"
                + "  \(String(format: "%10.0f%%", saved))\n"
        }
        print(out)
    }

    private func column(_ title: String) -> String {
        String(repeating: " ", count: max(0, 11 - title.count)) + title
    }

    private func pad(_ value: String, _ width: Int) -> String {
        value + String(repeating: " ", count: max(0, width - value.count))
    }

    private func format(_ nanoseconds: Double) -> String {
        if nanoseconds >= 1_000_000 {
            return String(format: "%8.2f ms", nanoseconds / 1_000_000)
        }
        if nanoseconds >= 1_000 {
            return String(format: "%8.2f \u{b5}s", nanoseconds / 1_000)
        }
        return String(format: "%8.1f ns", nanoseconds)
    }
}
