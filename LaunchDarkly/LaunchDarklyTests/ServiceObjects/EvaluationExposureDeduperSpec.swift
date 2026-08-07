import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

/// An exposure key that differs from every other one this spec builds only by its flag key, so that a test can talk
/// about "the exposure of a" without spelling out the whole key.
private func key(_ flagKey: LDFlagKey) -> EvaluationExposureKey {
    return EvaluationExposureKey(environmentName: "default",
                                 flagKey: flagKey,
                                 variation: 1,
                                 flagVersion: 2,
                                 inExperiment: false,
                                 fullyQualifiedContextKey: "user-key")
}

/// The same flag as `key(_:)`, resolved to a different variation.
private func otherResult(_ flagKey: LDFlagKey) -> EvaluationExposureKey {
    return EvaluationExposureKey(environmentName: "default",
                                 flagKey: flagKey,
                                 variation: 3,
                                 flagVersion: 2,
                                 inExperiment: false,
                                 fullyQualifiedContextKey: "user-key")
}

final class EvaluationExposureDeduperSpec: QuickSpec {
    override func spec() {
        describe("EvaluationExposureDeduper") {
            it("records everything for a non-positive window") {
                for window: TimeInterval in [0, -1] {
                    let deduper = EvaluationExposureDeduper(window: window, maxSize: 10)
                    expect(deduper.shouldRecord(key: key("a"), now: 0)) == true
                    expect(deduper.shouldRecord(key: key("a"), now: 0)) == true
                }
            }
            it("records everything when disabled") {
                let deduper = EvaluationExposureDeduper.disabled
                expect(deduper.shouldRecord(key: key("a"), now: 0)) == true
                expect(deduper.shouldRecord(key: key("a"), now: 0)) == true
                deduper.reset()
                expect(deduper.shouldRecord(key: key("a"), now: 0)) == true
            }
            it("suppresses repeats within the window") {
                let deduper = EvaluationExposureDeduper(window: 10, maxSize: 10)
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == false
                expect(deduper.shouldRecord(key: key("a"), now: 1_009)) == false
            }
            it("records again once the window elapses") {
                let deduper = EvaluationExposureDeduper(window: 10, maxSize: 10)
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
                expect(deduper.shouldRecord(key: key("a"), now: 1_010)) == true
                // Recording restarts the window rather than extending the original one.
                expect(deduper.shouldRecord(key: key("a"), now: 1_015)) == false
                expect(deduper.shouldRecord(key: key("a"), now: 1_020)) == true
            }
            it("applies a sub-second window") {
                let deduper = EvaluationExposureDeduper(window: 0.5, maxSize: 10)
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
                expect(deduper.shouldRecord(key: key("a"), now: 1_000.4)) == false
                expect(deduper.shouldRecord(key: key("a"), now: 1_000.5)) == true
            }
            it("tracks flags independently") {
                let deduper = EvaluationExposureDeduper(window: 10, maxSize: 10)
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
                expect(deduper.shouldRecord(key: key("b"), now: 1_000)) == true
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == false
                expect(deduper.shouldRecord(key: key("b"), now: 1_000)) == false
            }
            it("reports a flag again as soon as its result changes") {
                let deduper = EvaluationExposureDeduper(window: 10, maxSize: 10)
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
                expect(deduper.shouldRecord(key: otherResult("a"), now: 1_001)) == true
                expect(deduper.shouldRecord(key: otherResult("a"), now: 1_002)) == false
                // Only the result the flag reported last is tracked, so flipping back is a change too and the hook is
                // told about it rather than being left to think the flag never returned to it.
                expect(deduper.shouldRecord(key: key("a"), now: 1_003)) == true
                expect(deduper.shouldRecord(key: key("a"), now: 1_004)) == false
            }
            it("tracks the same flag separately per environment") {
                let deduper = EvaluationExposureDeduper(window: 10, maxSize: 10)
                let primary = EvaluationExposureKey(environmentName: "default", flagKey: "flag", variation: 1,
                                                    flagVersion: 2, inExperiment: false,
                                                    fullyQualifiedContextKey: "user-key")
                let secondary = EvaluationExposureKey(environmentName: "other", flagKey: "flag", variation: 3,
                                                      flagVersion: 4, inExperiment: false,
                                                      fullyQualifiedContextKey: "user-key")

                // A hook set on the configuration is shared by the clients for every environment, so its deduper sees
                // both. Neither environment may look to the other like its result changing.
                expect(deduper.shouldRecord(key: primary, now: 1_000)) == true
                expect(deduper.shouldRecord(key: secondary, now: 1_000)) == true
                expect(deduper.shouldRecord(key: primary, now: 1_001)) == false
                expect(deduper.shouldRecord(key: secondary, now: 1_001)) == false
            }
            it("records again after reset") {
                let deduper = EvaluationExposureDeduper(window: 10, maxSize: 10)
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
                deduper.reset()
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
            }
            it("starts over when more flags are live than the cap allows") {
                let deduper = EvaluationExposureDeduper(window: 1_000, maxSize: 4)
                for i in 0..<4 {
                    expect(deduper.shouldRecord(key: key("key-\(i)"), now: 1_000)) == true
                }
                // This flag exceeds the cap while every tracked window is still open, so there is nothing to reclaim
                // and the cache starts over.
                expect(deduper.shouldRecord(key: key("key-new"), now: 1_000)) == true
                // The flag that triggered the reset keeps its window, since it only just opened...
                expect(deduper.shouldRecord(key: key("key-new"), now: 1_000)) == false
                // ...while a flag dropped by the reset is reported again.
                expect(deduper.shouldRecord(key: key("key-0"), now: 1_000)) == true
            }
            it("reclaims the flag whose window elapsed rather than one that was re-recorded") {
                let deduper = EvaluationExposureDeduper(window: 10, maxSize: 2)
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
                expect(deduper.shouldRecord(key: key("b"), now: 1_000)) == true
                // Re-recording "a" refreshes its window, so when the cap is reached "b" is the one whose window has
                // elapsed. Reclaiming it is enough, and "a" keeps being suppressed.
                expect(deduper.shouldRecord(key: key("a"), now: 1_010)) == true
                expect(deduper.shouldRecord(key: key("c"), now: 1_010)) == true
                expect(deduper.shouldRecord(key: key("a"), now: 1_010)) == false
                expect(deduper.shouldRecord(key: key("b"), now: 1_010)) == true
            }
            it("keeps live flags when reclaiming expired ones is enough") {
                let deduper = EvaluationExposureDeduper(window: 10, maxSize: 8)
                for i in 0..<2 {
                    expect(deduper.shouldRecord(key: key("expired-\(i)"), now: 1_000)) == true
                }
                // The 7th of these exceeds the cap and triggers eviction. Reclaiming the two flags whose window has
                // elapsed brings the cache back within the cap on its own, so every one of these flags is still
                // tracked and none of them should be reported again.
                for i in 0..<7 {
                    expect(deduper.shouldRecord(key: key("live-\(i)"), now: 1_015)) == true
                }
                for i in 0..<7 {
                    expect(deduper.shouldRecord(key: key("live-\(i)"), now: 1_015)) == false
                }
            }
            it("uses the default window and cap when built without parameters") {
                // Ten minutes over 2000 flags.
                expect(EvaluationExposureDeduper.defaultWindow) == 600
                expect(EvaluationExposureDeduper.defaultMaxSize) == 2_000

                let deduper = EvaluationExposureDeduper()
                expect(deduper.shouldRecord(key: key("a"), now: 1_000)) == true
                expect(deduper.shouldRecord(key: key("a"), now: 1_599)) == false
                expect(deduper.shouldRecord(key: key("a"), now: 1_600)) == true

                for i in 0..<(EvaluationExposureDeduper.defaultMaxSize - 1) {
                    expect(deduper.shouldRecord(key: key("key-\(i)"), now: 1_600)) == true
                }
                // "a" and these flags fill the cap exactly, so nothing has been reclaimed yet.
                expect(deduper.shouldRecord(key: key("key-0"), now: 1_600)) == false
            }
            it("falls back to the default cap for a non-positive maxSize") {
                let deduper = EvaluationExposureDeduper(window: 1_000, maxSize: 0)
                for i in 0..<EvaluationExposureDeduper.defaultMaxSize {
                    expect(deduper.shouldRecord(key: key("key-\(i)"), now: 1_000)) == true
                }
                expect(deduper.shouldRecord(key: key("key-0"), now: 1_000)) == false
            }
        }
        describe("EvaluationExposureKey") {
            let base = EvaluationExposureKey(environmentName: "default", flagKey: "flag", variation: 1,
                                             flagVersion: 2, inExperiment: false, fullyQualifiedContextKey: "user-key")
            it("distinguishes every component") {
                expect(base) == EvaluationExposureKey(environmentName: "default", flagKey: "flag", variation: 1,
                                                      flagVersion: 2, inExperiment: false,
                                                      fullyQualifiedContextKey: "user-key")
                expect(base) != EvaluationExposureKey(environmentName: "default", flagKey: "other-flag", variation: 1,
                                                      flagVersion: 2, inExperiment: false,
                                                      fullyQualifiedContextKey: "user-key")
                expect(base) != EvaluationExposureKey(environmentName: "default", flagKey: "flag", variation: 3,
                                                      flagVersion: 2, inExperiment: false,
                                                      fullyQualifiedContextKey: "user-key")
                expect(base) != EvaluationExposureKey(environmentName: "default", flagKey: "flag", variation: 1,
                                                      flagVersion: 4, inExperiment: false,
                                                      fullyQualifiedContextKey: "user-key")
                expect(base) != EvaluationExposureKey(environmentName: "default", flagKey: "flag", variation: 1,
                                                      flagVersion: 2, inExperiment: false,
                                                      fullyQualifiedContextKey: "other-user-key")
                // Moving into an experiment on the same variation of the same flag version reports again.
                expect(base) != EvaluationExposureKey(environmentName: "default", flagKey: "flag", variation: 1,
                                                      flagVersion: 2, inExperiment: true,
                                                      fullyQualifiedContextKey: "user-key")
                // A hook shared across environments observes the same result once per environment.
                expect(base) != EvaluationExposureKey(environmentName: "other-env", flagKey: "flag", variation: 1,
                                                      flagVersion: 2, inExperiment: false,
                                                      fullyQualifiedContextKey: "user-key")
            }
            it("tells a missing variation and version apart from any present one") {
                let missing = EvaluationExposureKey(environmentName: "default", flagKey: "flag", variation: nil,
                                                    flagVersion: nil, inExperiment: false,
                                                    fullyQualifiedContextKey: "user-key")
                expect(missing) != base
                expect(missing) == EvaluationExposureKey(environmentName: "default", flagKey: "flag", variation: nil,
                                                         flagVersion: nil, inExperiment: false,
                                                         fullyQualifiedContextKey: "user-key")
            }
        }
    }
}
