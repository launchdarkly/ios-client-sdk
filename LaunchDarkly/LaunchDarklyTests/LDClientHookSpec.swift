import Foundation
import OSLog
import Quick
import Nimble
import LDSwiftEventSource
import XCTest
@testable import LaunchDarkly

final class LDClientHookSpec: XCTestCase {
//    final class LDContextSpec: XCTestCase {
//    override func spec() {
//        registrationSpec()
//        evaluationOrderSpec()
//        dataPassingSpec()
//    }

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

    typealias BeforeHook = (_: EvaluationSeriesContext, _: EvaluationSeriesData) -> EvaluationSeriesData
    typealias AfterHook = (_: EvaluationSeriesContext, _: EvaluationSeriesData, _: LDEvaluationDetail<LDValue>) -> EvaluationSeriesData

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
