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

    private func dedupeTestContext(hooks: [Hook]) -> TestContext {
        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.hooks = hooks

        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }
        testContext.flagStoreMock.replaceStore(newStoredItems: FlagMaintainingMock.stubStoredItems())
        return testContext
    }

    func testRepeatedEvaluationsReachAHookThatAskedForNoDedupe() {
        var befores = 0
        var afters = 0
        let hook = MockHook(before: { _, data in befores += 1; return data }, after: { _, data, _ in afters += 1; return data })
        let testContext = dedupeTestContext(hooks: [hook])

        for _ in 0..<3 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        // Deduplication is opt-in per hook, and this one did not opt in.
        XCTAssertEqual(befores, 3)
        XCTAssertEqual(afters, 3)
    }

    func testRepeatedEvaluationsAreDeduplicatedWithinTheHooksWindow() {
        var befores = 0
        var afters = 0
        let hook = MockHook(before: { _, data in befores += 1; return data }, after: { _, data, _ in afters += 1; return data })
        let testContext = dedupeTestContext(hooks: [DedupingHook(hook, window: 60)])

        for _ in 0..<3 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        // The whole series is skipped, so a hook pairing its stages never sees an unmatched before.
        XCTAssertEqual(befores, 1)
        XCTAssertEqual(afters, 1)
    }

    func testDeduplicatedEvaluationsStillRecordEvents() {
        let hook = MockHook(before: { _, data in data }, after: { _, data, _ in data })
        let testContext = dedupeTestContext(hooks: [DedupingHook(hook, window: 60)])

        for _ in 0..<3 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        // Deduplication applies to hooks only, so analytics events are unaffected.
        XCTAssertEqual(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount, 3)
    }

    func testEvaluationsOfDifferentFlagsReachHooksSeparately() {
        var afters = 0
        let hook = MockHook(before: { _, data in data }, after: { _, data, _ in afters += 1; return data })
        let testContext = dedupeTestContext(hooks: [DedupingHook(hook, window: 60)])

        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        _ = testContext.subject.stringVariation(forKey: DarklyServiceMock.FlagKeys.string, defaultValue: DefaultFlagValues.string)
        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)

        XCTAssertEqual(afters, 2)
    }

    func testEvaluationsReachHooksAgainAfterTheFlagChanges() {
        var afters = 0
        let hook = MockHook(before: { _, data in data }, after: { _, data, _ in afters += 1; return data })
        let testContext = dedupeTestContext(hooks: [DedupingHook(hook, window: 60)])

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
        let testContext = dedupeTestContext(hooks: [DedupingHook(hook, window: 60)])

        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        XCTAssertEqual(afters, 1)

        // Identifying to the unchanged context still lets the flag be reported again, so the evaluation after it is not
        // suppressed. Restoring the store afterwards keeps the flag resolving to the same result it did before, which is
        // what makes this a test of the identify rather than of a change to the flag.
        waitUntil { done in
            testContext.subject.identify(context: testContext.subject.context) { _ in done() }
        }
        testContext.flagStoreMock.replaceStore(newStoredItems: FlagMaintainingMock.stubStoredItems())
        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)

        XCTAssertEqual(afters, 2)
    }

    func testHooksWithDifferentWindowsSuppressIndependently() {
        var noDedupe = 0
        var deduped = 0
        var zeroWindow = 0
        let noDedupeHook = MockHook(before: { _, data in data }, after: { _, data, _ in noDedupe += 1; return data })
        let dedupingHook = MockHook(before: { _, data in data }, after: { _, data, _ in deduped += 1; return data })
        let zeroWindowHook = MockHook(before: { _, data in data }, after: { _, data, _ in zeroWindow += 1; return data })
        let testContext = dedupeTestContext(hooks: [noDedupeHook,
                                                    DedupingHook(dedupingHook, window: 60),
                                                    DedupingHook(zeroWindowHook, window: 0)])

        for _ in 0..<3 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        // Only the hook wrapped in a window suppresses. Being unwrapped and being wrapped in a window of zero behave the
        // same way.
        XCTAssertEqual(noDedupe, 3)
        XCTAssertEqual(deduped, 1)
        XCTAssertEqual(zeroWindow, 3)

        // identify lets every wrapped hook be told about the flag again.
        waitUntil { done in
            testContext.subject.identify(context: testContext.subject.context) { _ in done() }
        }
        testContext.flagStoreMock.replaceStore(newStoredItems: FlagMaintainingMock.stubStoredItems())
        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        XCTAssertEqual(deduped, 2)
    }

    func testHooksGivenSeparateDedupersDoNotSuppressEachOther() {
        var first = 0
        var second = 0
        let firstHook = MockHook(before: { _, data in data }, after: { _, data, _ in first += 1; return data })
        let secondHook = MockHook(before: { _, data in data }, after: { _, data, _ in second += 1; return data })
        let testContext = dedupeTestContext(hooks: [DedupingHook(firstHook, window: 60),
                                                    DedupingHook(secondHook, window: 60)])

        for _ in 0..<3 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        // Sharing a deduper would let the first hook consume the window and leave the second hook with nothing.
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 1)
    }

    func testHooksSharingOneDeduperShareItsWindow() {
        var first = 0
        var second = 0
        let shared = EvaluationExposureDeduper(window: 60)
        let firstHook = MockHook(before: { _, data in data }, after: { _, data, _ in first += 1; return data })
        let secondHook = MockHook(before: { _, data in data }, after: { _, data, _ in second += 1; return data })
        let testContext = dedupeTestContext(hooks: [DedupingHook(firstHook, deduper: shared),
                                                    DedupingHook(secondHook, deduper: shared)])

        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)

        // The first hook's report starts the window, which suppresses the second hook's.
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 0)
    }

    func testACustomDeduperDecidesWhichEvaluationsReachItsHook() {
        var afters = 0
        let hook = MockHook(before: { _, data in data }, after: { _, data, _ in afters += 1; return data })
        let deduper = CountingDeduper()
        let testContext = dedupeTestContext(hooks: [DedupingHook(hook, deduper: deduper)])

        for _ in 0..<4 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        // The subclass reports every other evaluation, which the SDK's implementation would not.
        XCTAssertEqual(afters, 2)
        XCTAssertEqual(deduper.keys.count, 4)
        XCTAssertEqual(Set(deduper.keys).count, 1)
        XCTAssertEqual(deduper.keys[0].flagKey, DarklyServiceMock.FlagKeys.bool)
        XCTAssertEqual(deduper.keys[0].environmentName, LDConfig.Constants.primaryEnvironmentName)
    }

    func testEnvironmentsSharingAHookDoNotSuppressEachOther() {
        var afters = 0
        let hook = MockHook(before: { _, data in data }, after: { _, data, _ in afters += 1; return data })
        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.hooks = [DedupingHook(hook, window: 60)]
        try! config.setSecondaryMobileKeys(["other": "other-mobile-key"])

        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }
        guard let other = LDClient.get(environment: "other")
        else {
            fail("The secondary environment's client was never created.")
            return
        }
        for client in [testContext.subject, other] {
            (client?.flagStore as? FlagMaintainingMock)?.replaceStore(newStoredItems: FlagMaintainingMock.stubStoredItems())
        }

        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        _ = other.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)

        // Both environments resolve the flag identically, but the hook they share is told about each of them.
        XCTAssertEqual(afters, 2)
    }

    func testIdentifyResetsACustomDeduper() {
        let hook = MockHook(before: { _, data in data }, after: { _, data, _ in data })
        let deduper = CountingDeduper()
        let testContext = dedupeTestContext(hooks: [DedupingHook(hook, deduper: deduper)])

        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        let resetsBeforeIdentify = deduper.resets

        waitUntil { done in
            testContext.subject.identify(context: LDContext.stub()) { _ in done() }
        }

        XCTAssertEqual(deduper.resets, resetsBeforeIdentify + 1)
    }

    func testADeduperStacksInsideAnotherDecorator() {
        var afters = 0
        let hook = MockHook(before: { _, data in data }, after: { _, data, _ in afters += 1; return data })
        let counting = CountingDecorator(DedupingHook(hook, window: 60))
        let testContext = dedupeTestContext(hooks: [counting])

        for _ in 0..<3 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        // The outer decorator sees every evaluation, and the deduper inside it passes on one.
        XCTAssertEqual(counting.evaluationsForwarded, 3)
        XCTAssertEqual(afters, 1)
    }

    func testADeduperStacksAroundAnotherDecorator() {
        var afters = 0
        let hook = MockHook(before: { _, data in data }, after: { _, data, _ in afters += 1; return data })
        let counting = CountingDecorator(hook)
        let testContext = dedupeTestContext(hooks: [DedupingHook(counting, window: 60)])

        for _ in 0..<3 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        // The deduper is outermost this time, so the decorator inside it sees only what it forwards.
        XCTAssertEqual(counting.evaluationsForwarded, 1)
        XCTAssertEqual(afters, 1)
    }

    func testADeduperDoesNotSwallowTheStagesOfADeduperInsideIt() {
        var afters = 0
        let hook = MockHook(before: { _, data in data }, after: { _, data, _ in afters += 1; return data })
        let counting = CountingDecorator(DedupingHook(hook, window: 60))
        // The outer deduper reports everything, so what the inner one suppresses has to travel back out through the
        // decorator between them, which each stage of still belongs to.
        let testContext = dedupeTestContext(hooks: [DedupingHook(counting, window: 0)])

        for _ in 0..<3 {
            _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
        }

        XCTAssertEqual(counting.evaluationsForwarded, 3)
        XCTAssertEqual(counting.resultsForwarded, 3)
        XCTAssertEqual(afters, 1)
    }

    /// A decorator with its own behavior, to check that decorators compose.
    class CountingDecorator: HookDecorator {
        private(set) var evaluationsForwarded = 0
        private(set) var resultsForwarded = 0

        override func beforeEvaluation(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData) -> EvaluationSeriesData {
            evaluationsForwarded += 1
            return super.beforeEvaluation(seriesContext: seriesContext, seriesData: seriesData)
        }

        override func afterEvaluation(seriesContext: EvaluationSeriesContext, seriesData: EvaluationSeriesData, evaluationDetail: LDEvaluationDetail<LDValue>) -> EvaluationSeriesData {
            resultsForwarded += 1
            return super.afterEvaluation(seriesContext: seriesContext, seriesData: seriesData, evaluationDetail: evaluationDetail)
        }
    }

    typealias BeforeHook = (_: EvaluationSeriesContext, _: EvaluationSeriesData) -> EvaluationSeriesData
    typealias AfterHook = (_: EvaluationSeriesContext, _: EvaluationSeriesData, _: LDEvaluationDetail<LDValue>) -> EvaluationSeriesData

    /// Reports every other evaluation, so that it can be told apart from both of the dedupers the SDK provides.
    class CountingDeduper: EvaluationExposureDeduper {
        private(set) var keys: [EvaluationExposureKey] = []
        private(set) var resets = 0

        init() {
            super.init(window: 0)
        }

        override func shouldRecord(key: EvaluationExposureKey, now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
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
