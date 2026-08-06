import Foundation
import OSLog
import Quick
import Nimble
import LDSwiftEventSource
import XCTest
@testable import LaunchDarkly

final class LDClientEvaluationHookSpec: XCTestCase {
    func testRegistration() {
        var count = 0
        let hook = MockHook(before: { _, data in count += 1; return data }, after: { _, data, _ in count += 2; return data })
        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.hooks = [hook]
        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }
        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        XCTAssertEqual(count, 3)
    }

    func testEvaluationOrder() {
        var callRecord: [String] = []
        let firstHook = MockHook(before: { _, data in callRecord.append("first before"); return data }, after: { _, data, _ in callRecord.append("first after"); return data })
        let secondHook = MockHook(before: { _, data in callRecord.append("second before"); return data }, after: { _, data, _ in callRecord.append("second after"); return data })
        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.hooks = [firstHook, secondHook]

        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        XCTAssertEqual(callRecord.count, 4)
        XCTAssertEqual(callRecord[0], "first before")
        XCTAssertEqual(callRecord[1], "second before")
        XCTAssertEqual(callRecord[2], "second after")
        XCTAssertEqual(callRecord[3], "first after")
    }

    func testEvaluationDetailIsCaptured() {
        var detail: LDEvaluationDetail<LDValue>? = nil
        let hook = MockHook(before: { _, data in return data }, after: { _, data, d in detail = d; return data })
        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.hooks = [hook]

        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        testContext.flagStoreMock.replaceStore(newStoredItems: FlagMaintainingMock.stubStoredItems())
        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)

        guard let det = detail
        else {
            fail("Details were never set by closure.")
            return
        }

        XCTAssertEqual(det.value, true)
        XCTAssertEqual(det.variationIndex, 2)
    }

    func testBeforeHookPassesDataToAfterHook() {
        var seriesData: EvaluationSeriesData? = nil
        let beforeHook: BeforeHook = { _, seriesData in
            var modified = seriesData
            modified["before"] = "was called"

            return modified
        }
        let hook = MockHook(before: beforeHook, after: { _, sd, _ in seriesData = sd; return sd })
        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.hooks = [hook]

        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        testContext.flagStoreMock.replaceStore(newStoredItems: FlagMaintainingMock.stubStoredItems())
        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)

        guard let data = seriesData
        else {
            fail("seriesData was never set by closure.")
            return
        }

        XCTAssertEqual(data["before"] as! String, "was called")
    }

    private func dedupeTestContext(window: TimeInterval, hooks: [Hook]) -> TestContext {
        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.hooks = hooks
        config.evaluationExposureDedupeWindow = window

        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }
        testContext.flagStoreMock.replaceStore(newStoredItems: FlagMaintainingMock.stubStoredItems())
        return testContext
    }

    private func dedupeTestContext(window: TimeInterval, hook: Hook) -> TestContext {
        return dedupeTestContext(window: window, hooks: [hook])
    }

    func testRepeatedEvaluationsReachHooksWhenDedupeIsDisabledByDefault() {
        var befores = 0
        var afters = 0
        let hook = MockHook(before: { _, data in befores += 1; return data }, after: { _, data, _ in afters += 1; return data })
        let testContext = dedupeTestContext(window: 0, hook: hook)

        for _ in 0..<3 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        XCTAssertEqual(befores, 3)
        XCTAssertEqual(afters, 3)
    }

    func testRepeatedEvaluationsAreDeduplicatedWithinTheWindow() {
        var befores = 0
        var afters = 0
        let hook = MockHook(before: { _, data in befores += 1; return data }, after: { _, data, _ in afters += 1; return data })
        let testContext = dedupeTestContext(window: 60, hook: hook)

        for _ in 0..<3 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        // The whole series is skipped, so a hook pairing its stages never sees an unmatched before.
        XCTAssertEqual(befores, 1)
        XCTAssertEqual(afters, 1)
    }

    func testDeduplicatedEvaluationsStillRecordEvents() {
        let hook = MockHook(before: { _, data in data }, after: { _, data, _ in data })
        let testContext = dedupeTestContext(window: 60, hook: hook)

        for _ in 0..<3 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        // Deduplication applies to hooks only, so analytics events are unaffected.
        XCTAssertEqual(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount, 3)
    }

    func testEvaluationsOfDifferentFlagsReachHooksSeparately() {
        var afters = 0
        let hook = MockHook(before: { _, data in data }, after: { _, data, _ in afters += 1; return data })
        let testContext = dedupeTestContext(window: 60, hook: hook)

        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        _ = testContext.subject.stringVariation(forKey: DarklyServiceMock.FlagKeys.string, defaultValue: DefaultFlagValues.string)
        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)

        XCTAssertEqual(afters, 2)
    }

    func testEvaluationsReachHooksAgainAfterTheFlagChanges() {
        var afters = 0
        let hook = MockHook(before: { _, data in data }, after: { _, data, _ in afters += 1; return data })
        let testContext = dedupeTestContext(window: 60, hook: hook)

        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        XCTAssertEqual(afters, 1)

        let updated = FeatureFlag(flagKey: DarklyServiceMock.FlagKeys.bool, value: true, variation: 2, flagVersion: 99)
        testContext.flagStoreMock.replaceStore(newStoredItems: [DarklyServiceMock.FlagKeys.bool: .item(updated)])
        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)

        XCTAssertEqual(afters, 2)
    }

    func testIdentifyLetsEveryHookObserveEvaluationsAgain() {
        var afters = 0
        let hook = MockHook(before: { _, data in data }, after: { _, data, _ in afters += 1; return data })
        let testContext = dedupeTestContext(window: 60, hook: hook)

        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        XCTAssertEqual(afters, 1)

        testContext.subject.internalIdentify(newContext: LDContext.stub(), useCache: .yes)
        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)

        XCTAssertEqual(afters, 2)
    }

    func testAHookOptsOutOfDeduplication() {
        var deduped = 0
        var everyEvaluation = 0
        let dedupedHook = MockHook(before: { _, data in data }, after: { _, data, _ in deduped += 1; return data })
        let auditHook = MockHook(before: { _, data in data }, after: { _, data, _ in everyEvaluation += 1; return data })
        auditHook.deduper = .disabled
        let testContext = dedupeTestContext(window: 60, hooks: [dedupedHook, auditHook])

        for _ in 0..<3 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        XCTAssertEqual(deduped, 1)
        XCTAssertEqual(everyEvaluation, 3)
    }

    func testAHookDeduplicatesWhileTheSdkDefaultIsDisabled() {
        var deduped = 0
        var everyEvaluation = 0
        let dedupedHook = MockHook(before: { _, data in data }, after: { _, data, _ in deduped += 1; return data })
        dedupedHook.deduper = EvaluationExposureDeduper(window: 60, maxSize: 10)
        let defaultHook = MockHook(before: { _, data in data }, after: { _, data, _ in everyEvaluation += 1; return data })
        let testContext = dedupeTestContext(window: 0, hooks: [dedupedHook, defaultHook])

        for _ in 0..<3 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        XCTAssertEqual(deduped, 1)
        XCTAssertEqual(everyEvaluation, 3)
    }

    func testEachHookGetsItsOwnDefaultDeduper() {
        var first = 0
        var second = 0
        let firstHook = MockHook(before: { _, data in data }, after: { _, data, _ in first += 1; return data })
        let secondHook = MockHook(before: { _, data in data }, after: { _, data, _ in second += 1; return data })
        let testContext = dedupeTestContext(window: 60, hooks: [firstHook, secondHook])

        for _ in 0..<3 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        // Sharing a deduper would let the first hook consume the window and leave the second hook with nothing.
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 1)
    }

    func testACustomDeduperDecidesWhichEvaluationsReachItsHook() {
        var afters = 0
        let hook = MockHook(before: { _, data in data }, after: { _, data, _ in afters += 1; return data })
        let deduper = CountingDeduper()
        hook.deduper = deduper
        let testContext = dedupeTestContext(window: 0, hooks: [hook])

        for _ in 0..<4 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        // The subclass reports every other evaluation, which neither the SDK's implementation nor the disabled one does.
        XCTAssertEqual(afters, 2)
        XCTAssertEqual(deduper.keys.count, 4)
        XCTAssertEqual(Set(deduper.keys).count, 1)
        XCTAssertTrue(deduper.keys[0].hasPrefix(DarklyServiceMock.FlagKeys.bool))
    }

    func testIdentifyResetsACustomDeduper() {
        let hook = MockHook(before: { _, data in data }, after: { _, data, _ in data })
        let deduper = CountingDeduper()
        hook.deduper = deduper
        let testContext = dedupeTestContext(window: 0, hooks: [hook])

        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        let resetsBeforeIdentify = deduper.resets

        testContext.subject.internalIdentify(newContext: LDContext.stub(), useCache: .yes)

        XCTAssertEqual(deduper.resets, resetsBeforeIdentify + 1)
    }

    typealias BeforeHook = (_: EvaluationSeriesContext, _: EvaluationSeriesData) -> EvaluationSeriesData
    typealias AfterHook = (_: EvaluationSeriesContext, _: EvaluationSeriesData, _: LDEvaluationDetail<LDValue>) -> EvaluationSeriesData

    /// Reports every other evaluation, so that it can be told apart from both of the dedupers the SDK provides.
    class CountingDeduper: EvaluationExposureDeduper {
        private(set) var keys: [String] = []
        private(set) var resets = 0

        init() {
            super.init(window: 0, maxSize: 0)
        }

        override func shouldRecord(key: String, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
            keys.append(key)
            return keys.count % 2 == 1
        }

        override func reset() {
            resets += 1
        }
    }

    class MockHook: Hook {
        let before: BeforeHook
        let after: AfterHook
        var deduper: EvaluationExposureDeduper?

        var evaluationExposureDeduper: EvaluationExposureDeduper? {
            return deduper
        }

        init(before: @escaping BeforeHook, after: @escaping AfterHook) {
            self.before = before
            self.after = after
        }

        func metadata() -> LaunchDarkly.Metadata {
            return Metadata(name: "counting-hook")
        }

        func beforeEvaluation(seriesContext: LaunchDarkly.EvaluationSeriesContext, seriesData: LaunchDarkly.EvaluationSeriesData) -> LaunchDarkly.EvaluationSeriesData {
            return self.before(seriesContext, seriesData)
        }

        func afterEvaluation(seriesContext: LaunchDarkly.EvaluationSeriesContext, seriesData: LaunchDarkly.EvaluationSeriesData, evaluationDetail: LaunchDarkly.LDEvaluationDetail<LaunchDarkly.LDValue>) -> LaunchDarkly.EvaluationSeriesData {
            return self.after(seriesContext, seriesData, evaluationDetail)
        }
    }
}
