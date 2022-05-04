import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class DiagnosticCacheSpec: QuickSpec {
    override func spec() {
        context("DiagnosticCache") {
            getCurrentStatsAndResetSpec()
            incrementDroppedEventCountSpec()
            recordEventsInLastBatchSpec()
            addStreamInitSpec()
            lastStatsSpec()
            backingStoreSpec()
        }
    }

    private func getCurrentStatsAndResetSpec() {
        context("getCurrentStatsAndReset") {
            beforeEach {
                self.clearStoredCaches()
            }
            it("has expected initial values") {
                let diagnosticCache = DiagnosticCache(sdkKey: "this_is_a_fake_key")
                let diagnosticId = diagnosticCache.getDiagnosticId()
                Thread.sleep(forTimeInterval: 0.01)
                let diagnosticStats = diagnosticCache.getCurrentStatsAndReset()
                let now = Date().millisSince1970
                expect(diagnosticCache.lastStats).to(beNil())
                expect(diagnosticId.sdkKeySuffix) == "ke_key"
                expect(UUID(uuidString: diagnosticId.diagnosticId)).toNot(beNil())
                expect(diagnosticStats.id.sdkKeySuffix) == diagnosticId.sdkKeySuffix
                expect(diagnosticStats.id.diagnosticId) == diagnosticId.diagnosticId
                expect(diagnosticStats.creationDate) <= now
                expect(diagnosticStats.creationDate) >= now - 1_000
                expect(diagnosticStats.dataSinceDate) <= now
                expect(diagnosticStats.dataSinceDate) >= now - 2_000
                expect(diagnosticStats.dataSinceDate) < diagnosticStats.creationDate
                expect(diagnosticStats.droppedEvents) == 0
                expect(diagnosticStats.eventsInLastBatch) == 0
                expect(diagnosticStats.streamInits.count) == 0
            }
            it("resets values") {
                let diagnosticCache = DiagnosticCache(sdkKey: "this_is_a_fake_key")
                diagnosticCache.incrementDroppedEventCount()
                diagnosticCache.recordEventsInLastBatch(eventsInLastBatch: 5)
                diagnosticCache.addStreamInit(streamInit: DiagnosticStreamInit(timestamp: 100, durationMillis: 100, failed: false))
                let diagnosticStats = diagnosticCache.getCurrentStatsAndReset()
                Thread.sleep(forTimeInterval: 0.01)
                let resetDiagnosticStats = diagnosticCache.getCurrentStatsAndReset()
                let now = Date().millisSince1970
                expect(resetDiagnosticStats.id.sdkKeySuffix) == diagnosticStats.id.sdkKeySuffix
                expect(resetDiagnosticStats.id.diagnosticId) == diagnosticStats.id.diagnosticId
                expect(resetDiagnosticStats.creationDate) <= now
                expect(resetDiagnosticStats.creationDate) >= now - 1_000
                expect(resetDiagnosticStats.dataSinceDate) == diagnosticStats.creationDate
                expect(resetDiagnosticStats.droppedEvents) == 0
                expect(resetDiagnosticStats.eventsInLastBatch) == 0
                expect(resetDiagnosticStats.streamInits.count) == 0
            }
        }
    }

    private func incrementDroppedEventCountSpec() {
        context("incrementDroppedEventCount") {
            beforeEach {
                self.clearStoredCaches()
            }
            it("increments dropped event count") {
                let diagnosticCache = DiagnosticCache(sdkKey: "this_is_a_fake_key")
                let diagnosticId = diagnosticCache.getDiagnosticId()
                diagnosticCache.incrementDroppedEventCount()
                let diagnosticStats = diagnosticCache.getCurrentStatsAndReset()
                let now = Date().millisSince1970
                expect(diagnosticStats.id.sdkKeySuffix) == diagnosticId.sdkKeySuffix
                expect(diagnosticStats.id.diagnosticId) == diagnosticId.diagnosticId
                expect(diagnosticStats.creationDate) <= now
                expect(diagnosticStats.creationDate) >= now - 1_000
                expect(diagnosticStats.dataSinceDate) <= now
                expect(diagnosticStats.dataSinceDate) >= now - 2_000
                expect(diagnosticStats.dataSinceDate) <= diagnosticStats.creationDate
                expect(diagnosticStats.droppedEvents) == 1
                expect(diagnosticStats.eventsInLastBatch) == 0
                expect(diagnosticStats.streamInits.count) == 0
            }
            it("concurrently increments dropped event counts") {
                let diagnosticCache = DiagnosticCache(sdkKey: "this_is_a_fake_key")
                let diagnosticId = diagnosticCache.getDiagnosticId()

                let counter = DispatchSemaphore(value: 0)
                DispatchQueue.concurrentPerform(iterations: 10) { _ in
                    diagnosticCache.incrementDroppedEventCount()
                    counter.signal()
                }
                (0..<10).forEach { _ in counter.wait() }

                let diagnosticStats = diagnosticCache.getCurrentStatsAndReset()
                expect(UUID(uuidString: diagnosticId.diagnosticId)).toNot(beNil())
                expect(diagnosticStats.droppedEvents) == 10
                expect(diagnosticStats.eventsInLastBatch) == 0
                expect(diagnosticStats.streamInits.count) == 0
            }
        }
    }

    private func recordEventsInLastBatchSpec() {
        context("recordEventsInLastBatch") {
            beforeEach {
                self.clearStoredCaches()
            }
            it("sets events in last batch") {
                let diagnosticCache = DiagnosticCache(sdkKey: "this_is_a_fake_key")
                let diagnosticId = diagnosticCache.getDiagnosticId()
                diagnosticCache.recordEventsInLastBatch(eventsInLastBatch: 10)
                let diagnosticStats = diagnosticCache.getCurrentStatsAndReset()
                let now = Date().millisSince1970
                expect(diagnosticStats.id.sdkKeySuffix) == diagnosticId.sdkKeySuffix
                expect(diagnosticStats.id.diagnosticId) == diagnosticId.diagnosticId
                expect(diagnosticStats.creationDate) <= now
                expect(diagnosticStats.creationDate) >= now - 1_000
                expect(diagnosticStats.dataSinceDate) <= now
                expect(diagnosticStats.dataSinceDate) >= now - 2_000
                expect(diagnosticStats.dataSinceDate) <= diagnosticStats.creationDate
                expect(diagnosticStats.droppedEvents) == 0
                expect(diagnosticStats.eventsInLastBatch) == 10
                expect(diagnosticStats.streamInits.count) == 0
            }
        }
    }

    private func addStreamInitSpec() {
        context("addStreamInit") {
            beforeEach {
                self.clearStoredCaches()
            }
            it("adds a stream init") {
                let diagnosticCache = DiagnosticCache(sdkKey: "this_is_a_fake_key")
                let diagnosticId = diagnosticCache.getDiagnosticId()
                diagnosticCache.addStreamInit(streamInit: DiagnosticStreamInit(timestamp: 100, durationMillis: 50, failed: false))
                let diagnosticStats = diagnosticCache.getCurrentStatsAndReset()
                let now = Date().millisSince1970
                expect(diagnosticStats.id.sdkKeySuffix) == diagnosticId.sdkKeySuffix
                expect(diagnosticStats.id.diagnosticId) == diagnosticId.diagnosticId
                expect(diagnosticStats.creationDate) <= now
                expect(diagnosticStats.creationDate) >= now - 1_000
                expect(diagnosticStats.dataSinceDate) <= now
                expect(diagnosticStats.dataSinceDate) >= now - 2_000
                expect(diagnosticStats.dataSinceDate) <= diagnosticStats.creationDate
                expect(diagnosticStats.droppedEvents) == 0
                expect(diagnosticStats.eventsInLastBatch) == 0
                expect(diagnosticStats.streamInits.count) == 1
                expect(diagnosticStats.streamInits[0].timestamp) == 100
                expect(diagnosticStats.streamInits[0].durationMillis) == 50
                expect(diagnosticStats.streamInits[0].failed) == false
            }
            it("concurrently adds stream inits") {
                let diagnosticCache = DiagnosticCache(sdkKey: "this_is_a_fake_key")

                let requestQueue = DispatchQueue(label: "com.launchdarkly.test.diagnosticCacheSpec.addStreamInit.concurrent",
                                                 qos: .userInitiated,
                                                 attributes: .concurrent)
                let testInits = [DiagnosticStreamInit(timestamp: 10, durationMillis: 5, failed: false),
                                 DiagnosticStreamInit(timestamp: 11, durationMillis: 6, failed: true),
                                 DiagnosticStreamInit(timestamp: 12, durationMillis: 7, failed: false),
                                 DiagnosticStreamInit(timestamp: 13, durationMillis: 8, failed: true),
                                 DiagnosticStreamInit(timestamp: 14, durationMillis: 9, failed: false)]
                var addCallCount = 0
                waitUntil { done in
                    let fireTime = DispatchTime.now() + 0.1
                    for i in 0..<testInits.count {
                        requestQueue.asyncAfter(deadline: fireTime) {
                            diagnosticCache.addStreamInit(streamInit: testInits[i])
                            DispatchQueue.main.async {
                                addCallCount += 1
                                if addCallCount == testInits.count {
                                    done()
                                }
                            }
                        }
                    }
                }

                let diagnosticStats = diagnosticCache.getCurrentStatsAndReset()
                expect(diagnosticStats.droppedEvents) == 0
                expect(diagnosticStats.eventsInLastBatch) == 0
                expect(diagnosticStats.streamInits.count) == testInits.count
                for streamInit in testInits {
                    expect(diagnosticStats.streamInits.contains {
                        $0.timestamp == streamInit.timestamp &&
                            $0.durationMillis == streamInit.durationMillis &&
                            $0.failed == streamInit.failed
                    }) == true
                }
            }
        }
    }

    private func lastStatsSpec() {
        context("lastStats") {
            beforeEach {
                self.clearStoredCaches()
            }
            it("restores from previous initialization with same key") {
                let diagnosticCache = DiagnosticCache(sdkKey: "this_is_a_fake_key")
                let diagnosticId = diagnosticCache.getDiagnosticId()
                let initialStats = diagnosticCache.getCurrentStatsAndReset()
                diagnosticCache.incrementDroppedEventCount()
                diagnosticCache.recordEventsInLastBatch(eventsInLastBatch: 5)
                diagnosticCache.addStreamInit(streamInit: DiagnosticStreamInit(timestamp: 100, durationMillis: 50, failed: false))
                let restoredCache = DiagnosticCache(sdkKey: "this_is_a_fake_key")
                let restoredId = restoredCache.getDiagnosticId()
                guard let lastStats = restoredCache.lastStats
                else {
                    fail("No restored stats")
                    return
                }
                expect(lastStats.id.diagnosticId) == diagnosticId.diagnosticId
                expect(lastStats.id.sdkKeySuffix) == diagnosticId.sdkKeySuffix
                expect(restoredId.diagnosticId) != diagnosticId.diagnosticId
                expect(restoredId.sdkKeySuffix) == diagnosticId.sdkKeySuffix
                expect(lastStats.creationDate) >= initialStats.creationDate
                expect(lastStats.dataSinceDate) == initialStats.creationDate
                expect(lastStats.droppedEvents) == 1
                expect(lastStats.eventsInLastBatch) == 5
                expect(lastStats.streamInits.count) == 1
                expect(lastStats.streamInits[0].timestamp) == 100
                expect(lastStats.streamInits[0].durationMillis) == 50
                expect(lastStats.streamInits[0].failed) == false
            }
            it("does not restore from previous initialization with different key") {
                let diagnosticCache = DiagnosticCache(sdkKey: "this_is_a_fake_key")
                diagnosticCache.incrementDroppedEventCount()
                diagnosticCache.recordEventsInLastBatch(eventsInLastBatch: 5)
                diagnosticCache.addStreamInit(streamInit: DiagnosticStreamInit(timestamp: 100, durationMillis: 50, failed: false))
                let restoredCache = DiagnosticCache(sdkKey: "this_is_a_different_fake_key")
                let lastStats = restoredCache.lastStats
                expect(lastStats).to(beNil())
            }
        }
    }

    private func backingStoreSpec() {
        context("backing store") {
            it("stores to expected key") {
                self.clearStoredCaches()

                let expectedDataKey = "com.launchdarkly.DiagnosticCache.diagnosticData.this_is_a_fake_key"
                let defaults = UserDefaults.standard
                let beforeData = defaults.data(forKey: expectedDataKey)
                expect(beforeData).to(beNil())
                _ = DiagnosticCache(sdkKey: "this_is_a_fake_key")
                let afterData = defaults.data(forKey: expectedDataKey)
                expect(afterData).toNot(beNil())
            }
        }
    }

    private func clearStoredCaches() {
        let defaults = UserDefaults.standard
        defaults.dictionaryRepresentation().keys.filter {
            $0.starts(with: "com.launchdarkly.DiagnosticCache.diagnosticData")
        }.forEach { defaults.removeObject(forKey: $0) }
    }
}
