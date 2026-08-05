import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class EvaluationExposureDeduperSpec: QuickSpec {
    override func spec() {
        describe("EvaluationExposureDeduper") {
            it("is disabled for a non-positive window") {
                for window: TimeInterval in [0, -1] {
                    let deduper = EvaluationExposureDeduper(window: window, maxSize: 10)
                    expect(deduper.isEnabled) == false
                    expect(deduper.shouldRecord(key: "a", now: 0)) == true
                    expect(deduper.shouldRecord(key: "a", now: 0)) == true
                }
            }
            it("suppresses repeats within the window") {
                let deduper = EvaluationExposureDeduper(window: 10, maxSize: 10)
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == true
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == false
                expect(deduper.shouldRecord(key: "a", now: 1_009)) == false
            }
            it("records again once the window elapses") {
                let deduper = EvaluationExposureDeduper(window: 10, maxSize: 10)
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == true
                expect(deduper.shouldRecord(key: "a", now: 1_010)) == true
                // Recording restarts the window rather than extending the original one.
                expect(deduper.shouldRecord(key: "a", now: 1_015)) == false
                expect(deduper.shouldRecord(key: "a", now: 1_020)) == true
            }
            it("applies a sub-second window") {
                let deduper = EvaluationExposureDeduper(window: 0.5, maxSize: 10)
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == true
                expect(deduper.shouldRecord(key: "a", now: 1_000.4)) == false
                expect(deduper.shouldRecord(key: "a", now: 1_000.5)) == true
            }
            it("tracks keys independently") {
                let deduper = EvaluationExposureDeduper(window: 10, maxSize: 10)
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == true
                expect(deduper.shouldRecord(key: "b", now: 1_000)) == true
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == false
                expect(deduper.shouldRecord(key: "b", now: 1_000)) == false
            }
            it("records again after reset") {
                let deduper = EvaluationExposureDeduper(window: 10, maxSize: 10)
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == true
                deduper.reset()
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == true
            }
            it("starts over when more keys are live than the cap allows") {
                let deduper = EvaluationExposureDeduper(window: 1_000, maxSize: 4)
                for i in 0..<4 {
                    expect(deduper.shouldRecord(key: "key-\(i)", now: 1_000)) == true
                }
                // This key exceeds the cap while every tracked window is still open, so there is nothing to reclaim
                // and the cache starts over.
                expect(deduper.shouldRecord(key: "key-new", now: 1_000)) == true
                // The key that triggered the reset keeps its window, since it only just opened...
                expect(deduper.shouldRecord(key: "key-new", now: 1_000)) == false
                // ...while a key dropped by the reset is reported again.
                expect(deduper.shouldRecord(key: "key-0", now: 1_000)) == true
            }
            it("reclaims the key whose window elapsed rather than one that was re-recorded") {
                let deduper = EvaluationExposureDeduper(window: 10, maxSize: 2)
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == true
                expect(deduper.shouldRecord(key: "b", now: 1_000)) == true
                // Re-recording "a" refreshes its window, so when the cap is reached "b" is the one whose window has
                // elapsed. Reclaiming it is enough, and "a" keeps being suppressed.
                expect(deduper.shouldRecord(key: "a", now: 1_010)) == true
                expect(deduper.shouldRecord(key: "c", now: 1_010)) == true
                expect(deduper.shouldRecord(key: "a", now: 1_010)) == false
                expect(deduper.shouldRecord(key: "b", now: 1_010)) == true
            }
            it("keeps live keys when reclaiming expired ones is enough") {
                // maxSize is 8 so that the batch term (maxSize / 4) is non-zero, which is what makes an over-eager
                // batch drop observable.
                let deduper = EvaluationExposureDeduper(window: 10, maxSize: 8)
                for i in 0..<2 {
                    expect(deduper.shouldRecord(key: "expired-\(i)", now: 1_000)) == true
                }
                // The 7th of these exceeds the cap and triggers eviction. Reclaiming the two keys whose window has
                // elapsed brings the map back within the cap on its own, so every one of these keys is still tracked
                // and none of them should be reported again.
                for i in 0..<7 {
                    expect(deduper.shouldRecord(key: "live-\(i)", now: 1_015)) == true
                }
                for i in 0..<7 {
                    expect(deduper.shouldRecord(key: "live-\(i)", now: 1_015)) == false
                }
            }
            it("falls back to the default cap for a non-positive maxSize") {
                let deduper = EvaluationExposureDeduper(window: 1_000, maxSize: 0)
                for i in 0..<LDConfig.Defaults.evaluationExposureDedupeMaxSize {
                    expect(deduper.shouldRecord(key: "key-\(i)", now: 1_000)) == true
                }
                expect(deduper.shouldRecord(key: "key-0", now: 1_000)) == false
            }
        }
    }
}
