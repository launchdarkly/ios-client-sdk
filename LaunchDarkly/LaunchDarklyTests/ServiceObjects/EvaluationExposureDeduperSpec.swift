import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

/// An exposure key that differs from every other one this spec builds only by its flag key, so that a test can talk
/// about "the exposure of a" without spelling out the whole key.
private func key(_ flagKey: LDFlagKey) -> EvaluationExposureKey {
    return EvaluationExposureKey(mobileKeyHash: "mobile-key-hash",
                                 flagKey: flagKey,
                                 variation: 1,
                                 flagVersion: 2,
                                 fullyQualifiedContextKey: "user-key",
                                 value: .string("value"))
}

/// The same flag as `key(_:)`, resolved to a different variation.
private func otherResult(_ flagKey: LDFlagKey) -> EvaluationExposureKey {
    return EvaluationExposureKey(mobileKeyHash: "mobile-key-hash",
                                 flagKey: flagKey,
                                 variation: 3,
                                 flagVersion: 2,
                                 fullyQualifiedContextKey: "user-key",
                                 value: .string("other-value"))
}

/// The key the SDK builds for an evaluation it has no flag data for: one made before the client has flags, or one of a
/// flag that does not exist. Such an evaluation returns the default value, so that is the value describing it, with no
/// variation and no version.
private func unknownFlag(_ flagKey: LDFlagKey, _ defaultValue: LDValue) -> EvaluationExposureKey {
    return EvaluationExposureKey(mobileKeyHash: "mobile-key-hash",
                                 flagKey: flagKey,
                                 variation: nil,
                                 flagVersion: nil,
                                 fullyQualifiedContextKey: "user-key",
                                 value: defaultValue)
}

final class EvaluationExposureDeduperSpec: QuickSpec {
    override func spec() {
        describe("EvaluationExposureDeduper") {
            it("records everything for a non-positive window") {
                for window: TimeInterval in [0, -1] {
                    let deduper = EvaluationExposureDeduper(window: window)
                    expect(deduper.shouldRecord(key: key("a"), now: 0)) == true
                    expect(deduper.shouldRecord(key: key("a"), now: 0)) == true
                }
            }
            it("suppresses repeats within the window") {
                let deduper = EvaluationExposureDeduper(window: 10)
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == false
                expect(deduper.shouldRecord(key: key("a"), now: 1_009)) == false
            }
            it("records again once the window elapses") {
                let deduper = EvaluationExposureDeduper(window: 10)
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
                expect(deduper.shouldRecord(key: key("a"), now: 1_010)) == true
                // Recording restarts the window rather than extending the original one.
                expect(deduper.shouldRecord(key: key("a"), now: 1_015)) == false
                expect(deduper.shouldRecord(key: key("a"), now: 1_020)) == true
            }
            it("applies a sub-second window") {
                let deduper = EvaluationExposureDeduper(window: 0.5)
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
                expect(deduper.shouldRecord(key: key("a"), now: 1_000.4)) == false
                expect(deduper.shouldRecord(key: key("a"), now: 1_000.5)) == true
            }
            it("tracks flags independently") {
                let deduper = EvaluationExposureDeduper(window: 10)
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
                expect(deduper.shouldRecord(key: key("b"), now: 1_000)) == true
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == false
                expect(deduper.shouldRecord(key: key("b"), now: 1_000)) == false
            }
            it("reports a flag again as soon as its result changes") {
                let deduper = EvaluationExposureDeduper(window: 10)
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
                expect(deduper.shouldRecord(key: otherResult("a"), now: 1_001)) == true
                expect(deduper.shouldRecord(key: otherResult("a"), now: 1_002)) == false
                // Only the result the flag reported last is tracked, so flipping back is a change too and the hook is
                // told about it rather than being left to think the flag never returned to it.
                expect(deduper.shouldRecord(key: key("a"), now: 1_003)) == true
                expect(deduper.shouldRecord(key: key("a"), now: 1_004)) == false
            }
            it("reports again when only the flag value changes") {
                let deduper = EvaluationExposureDeduper(window: 10)
                let first = EvaluationExposureKey(mobileKeyHash: "mobile-key-hash", flagKey: "flag", variation: 1,
                                                  flagVersion: 2,
                                                  fullyQualifiedContextKey: "user-key", value: .string("first"))
                let second = EvaluationExposureKey(mobileKeyHash: "mobile-key-hash", flagKey: "flag", variation: 1,
                                                   flagVersion: 2,
                                                   fullyQualifiedContextKey: "user-key", value: .string("second"))

                expect(deduper.shouldRecord(key: first, now: 1_000)) == true
                expect(deduper.shouldRecord(key: second, now: 1_001)) == true
                expect(deduper.shouldRecord(key: second, now: 1_002)) == false
            }
            it("treats evaluations with no flag data resolving to the same default as one exposure") {
                let deduper = EvaluationExposureDeduper(window: 10)

                // Evaluations the SDK has no flag data for return the default value, and repeats of that result are a
                // repeat like any other.
                expect(deduper.shouldRecord(key: unknownFlag("a", .bool(false)), now: 1_000)) == true
                expect(deduper.shouldRecord(key: unknownFlag("a", .bool(false)), now: 1_001)) == false

                // A different default is a different result, because it is a different value returned to the
                // application.
                expect(deduper.shouldRecord(key: unknownFlag("a", .bool(true)), now: 1_002)) == true
                expect(deduper.shouldRecord(key: unknownFlag("a", .bool(true)), now: 1_003)) == false
            }
            it("reports again when the flag becomes known") {
                let deduper = EvaluationExposureDeduper(window: 10)
                expect(deduper.shouldRecord(key: unknownFlag("a", .string("value")), now: 1_000)) == true

                // The data arriving is a change of result even when the flag resolves to the value the default had
                // already produced, because the evaluation now has a variation and a version. So is the flag going away
                // again.
                expect(deduper.shouldRecord(key: key("a"), now: 1_001)) == true
                expect(deduper.shouldRecord(key: key("a"), now: 1_002)) == false
                expect(deduper.shouldRecord(key: unknownFlag("a", .string("value")), now: 1_003)) == true
            }
            it("tracks the same flag separately per environment") {
                let deduper = EvaluationExposureDeduper(window: 10)
                let primary = EvaluationExposureKey(mobileKeyHash: "mobile-key-hash", flagKey: "flag", variation: 1,
                                                    flagVersion: 2,
                                                    fullyQualifiedContextKey: "user-key")
                let secondary = EvaluationExposureKey(mobileKeyHash: "other-mobile-key-hash", flagKey: "flag", variation: 3,
                                                      flagVersion: 4,
                                                      fullyQualifiedContextKey: "user-key")

                // A hook set on the configuration is shared by the clients for every environment, so its deduper sees
                // both. Neither environment may look to the other like its result changing.
                expect(deduper.shouldRecord(key: primary, now: 1_000)) == true
                expect(deduper.shouldRecord(key: secondary, now: 1_000)) == true
                expect(deduper.shouldRecord(key: primary, now: 1_001)) == false
                expect(deduper.shouldRecord(key: secondary, now: 1_001)) == false
            }
            it("records again after reset") {
                let deduper = EvaluationExposureDeduper(window: 10)
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
                deduper.reset()
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
            }
            it("uses the default window when built without one") {
                // Ten minutes.
                expect(EvaluationExposureDeduper.defaultWindow) == 600

                let deduper = EvaluationExposureDeduper()
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
                expect(deduper.shouldRecord(key: key("a"), now: 1_599)) == false
                expect(deduper.shouldRecord(key: key("a"), now: 1_600)) == true
            }
            it("records once when the same key is checked concurrently") {
                let deduper = EvaluationExposureDeduper(window: 10)
                let counting = DispatchQueue(label: "EvaluationExposureDeduperSpec.recorded")
                var recorded = 0

                DispatchQueue.concurrentPerform(iterations: 10) { _ in
                    if deduper.shouldRecord(key: key("a"), now: 1_000) {
                        counting.sync { recorded += 1 }
                    }
                }

                // The check and the update are performed together, so concurrent evaluations of one flag cannot both
                // be told to record.
                expect(recorded) == 1
            }
            it("tracks every flag the application evaluates") {
                let deduper = EvaluationExposureDeduper(window: 600)
                for i in 0..<2_000 {
                    expect(deduper.shouldRecord(key: key("key-\(i)"), now: 1_000)) == true
                }

                // Records accumulate; the first flag is still suppressed after two thousand others have been recorded.
                expect(deduper.shouldRecord(key: key("key-0"), now: 1_000)) == false
                expect(deduper.shouldRecord(key: key("key-1999"), now: 1_000)) == false
            }
        }
        describe("EvaluationExposureKey") {
            let base = EvaluationExposureKey(mobileKeyHash: "mobile-key-hash", flagKey: "flag", variation: 1,
                                             flagVersion: 2, fullyQualifiedContextKey: "user-key")
            it("distinguishes every component") {
                expect(base) == EvaluationExposureKey(mobileKeyHash: "mobile-key-hash", flagKey: "flag", variation: 1,
                                                      flagVersion: 2,
                                                      fullyQualifiedContextKey: "user-key")
                expect(base) != EvaluationExposureKey(mobileKeyHash: "mobile-key-hash", flagKey: "flag", variation: 1,
                                                      flagVersion: 2,
                                                      fullyQualifiedContextKey: "user-key", value: .string("value"))
                expect(base) != EvaluationExposureKey(mobileKeyHash: "mobile-key-hash", flagKey: "other-flag", variation: 1,
                                                      flagVersion: 2,
                                                      fullyQualifiedContextKey: "user-key")
                expect(base) != EvaluationExposureKey(mobileKeyHash: "mobile-key-hash", flagKey: "flag", variation: 3,
                                                      flagVersion: 2,
                                                      fullyQualifiedContextKey: "user-key")
                expect(base) != EvaluationExposureKey(mobileKeyHash: "mobile-key-hash", flagKey: "flag", variation: 1,
                                                      flagVersion: 4,
                                                      fullyQualifiedContextKey: "user-key")
                expect(base) != EvaluationExposureKey(mobileKeyHash: "mobile-key-hash", flagKey: "flag", variation: 1,
                                                      flagVersion: 2,
                                                      fullyQualifiedContextKey: "other-user-key")
                // A hook shared across environments observes the same result once per environment.
                expect(base) != EvaluationExposureKey(mobileKeyHash: "other-mobile-key-hash", flagKey: "flag", variation: 1,
                                                      flagVersion: 2,
                                                      fullyQualifiedContextKey: "user-key")
            }
            it("tells a missing variation and version apart from any present one") {
                let missing = EvaluationExposureKey(mobileKeyHash: "mobile-key-hash", flagKey: "flag", variation: nil,
                                                    flagVersion: nil,
                                                    fullyQualifiedContextKey: "user-key")
                expect(missing) != base
                expect(missing) == EvaluationExposureKey(mobileKeyHash: "mobile-key-hash", flagKey: "flag", variation: nil,
                                                         flagVersion: nil,
                                                         fullyQualifiedContextKey: "user-key")
            }
            it("tells evaluations with no flag data apart by the default they returned") {
                let key = unknownFlag("flag", .bool(false))
                let same = unknownFlag("flag", .bool(false))
                expect(key) == same
                expect(key.hashValue) == same.hashValue

                expect(key) != unknownFlag("flag", .bool(true))
            }
        }
    }
}
