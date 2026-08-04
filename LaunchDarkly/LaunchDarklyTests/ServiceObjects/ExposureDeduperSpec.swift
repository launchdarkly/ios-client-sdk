import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class ExposureDeduperSpec: QuickSpec {
    override func spec() {
        describe("ExposureDeduper") {
            it("is disabled for a non-positive window") {
                for window in [0, -1] {
                    let deduper = ExposureDeduper(windowMillis: window, maxSize: 10)
                    expect(deduper.isEnabled) == false
                    expect(deduper.shouldRecord(key: "a", now: 0)) == true
                    expect(deduper.shouldRecord(key: "a", now: 0)) == true
                }
            }
            it("suppresses repeats within the window") {
                let deduper = ExposureDeduper(windowMillis: 100, maxSize: 10)
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == true
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == false
                expect(deduper.shouldRecord(key: "a", now: 1_099)) == false
            }
            it("records again once the window elapses") {
                let deduper = ExposureDeduper(windowMillis: 100, maxSize: 10)
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == true
                expect(deduper.shouldRecord(key: "a", now: 1_100)) == true
                // Recording restarts the window rather than extending the original one.
                expect(deduper.shouldRecord(key: "a", now: 1_150)) == false
                expect(deduper.shouldRecord(key: "a", now: 1_200)) == true
            }
            it("tracks keys independently") {
                let deduper = ExposureDeduper(windowMillis: 100, maxSize: 10)
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == true
                expect(deduper.shouldRecord(key: "b", now: 1_000)) == true
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == false
                expect(deduper.shouldRecord(key: "b", now: 1_000)) == false
            }
            it("records again after reset") {
                let deduper = ExposureDeduper(windowMillis: 100, maxSize: 10)
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == true
                deduper.reset()
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == true
            }
            it("evicts the least recently recorded keys past the cap") {
                let deduper = ExposureDeduper(windowMillis: 10_000, maxSize: 4)
                for i in 0..<5 {
                    expect(deduper.shouldRecord(key: "key-\(i)", now: Int64(1_000 + i))) == true
                }
                // "key-0" was recorded first, so it is the one dropped and can be recorded again, while the most
                // recently recorded key is still being tracked.
                expect(deduper.shouldRecord(key: "key-0", now: 1_010)) == true
                expect(deduper.shouldRecord(key: "key-4", now: 1_010)) == false
            }
            it("moves a re-recorded key to the most recent end of the eviction order") {
                let deduper = ExposureDeduper(windowMillis: 100, maxSize: 2)
                expect(deduper.shouldRecord(key: "a", now: 1_000)) == true
                expect(deduper.shouldRecord(key: "b", now: 1_000)) == true
                // "a" is re-recorded once its window elapses, which makes "b" the oldest tracked key.
                expect(deduper.shouldRecord(key: "a", now: 1_100)) == true
                expect(deduper.shouldRecord(key: "c", now: 1_100)) == true
                expect(deduper.shouldRecord(key: "a", now: 1_100)) == false
            }
            it("falls back to the default cap for a non-positive maxSize") {
                let deduper = ExposureDeduper(windowMillis: 10_000, maxSize: 0)
                for i in 0..<LDConfig.Defaults.flagExposureDedupeMaxSize {
                    expect(deduper.shouldRecord(key: "key-\(i)", now: 1_000)) == true
                }
                expect(deduper.shouldRecord(key: "key-0", now: 1_000)) == false
            }
        }
    }
}
