import Foundation
import OSLog
import Quick
import Nimble
import LDSwiftEventSource
import XCTest
@testable import LaunchDarkly

final class LDClientIdentifyHookSpec: XCTestCase {
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
        testContext.subject.identify(context: LDContext.stub()) { _ in }
        expect(count).toEventually(equal(6))
    }

    func testRegistrationWithTimeout() {
        var count = 0
        let hook = MockHook(before: { _, data in count += 1; return data }, after: { _, data, _ in count += 2; return data })
        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.hooks = [hook]
        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }
        testContext.subject.identify(context: LDContext.stub(), timeout: 30.0) { _ in }
        expect(count).toEventually(equal(6))
    }

    func testIdentifyOrder() {
        var callRecord: [String] = []
        let firstHook = MockHook(before: { sc, data in callRecord.append("first before \(sc.context.fullyQualifiedKey())"); return data }, after: { sc, data, _ in callRecord.append("first after \(sc.context.fullyQualifiedKey())"); return data })
        let secondHook = MockHook(before: { sc, data in callRecord.append("second before \(sc.context.fullyQualifiedKey())"); return data }, after: { sc, data, _ in callRecord.append("second after \(sc.context.fullyQualifiedKey())"); return data })
        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.hooks = [firstHook, secondHook]

        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        let initKey = testContext.subject.context.fullyQualifiedKey()
        testContext.subject.identify(context: LDContext.stub(key: "explicit-context")) { _ in }
        expect(callRecord).toEventually(equal([
            "first before \(initKey)", "second before \(initKey)", "second after \(initKey)", "first after \(initKey)",
            "first before explicit-context", "second before explicit-context", "second after explicit-context", "first after explicit-context"
        ]))
    }

    func testIdentifyResultIsCaptured() {
        var captured: IdentifyResult? = nil
        let hook = MockHook(before: { _, data in return data }, after: { _, data, result in captured = result; return data })
        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.hooks = [hook]

        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        testContext.subject.identify(context: LDContext.stub()) { _ in }

        expect(captured).toEventually(equal(.complete))
    }

    func testBeforeHookPassesDataToAfterHook() {
        var seriesData: IdentifySeriesData? = nil
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

        testContext.subject.identify(context: LDContext.stub()) { _ in }

        expect(seriesData?["before"] as? String).toEventually(equal("was called"))
    }

    func testPluginHooksFireDuringInit() {
        var count = 0
        let hook = MockHook(before: { _, data in count += 1; return data }, after: { _, data, _ in count += 2; return data })
        let plugin = MockPlugin(hooks: [hook])
        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.plugins = [plugin]
        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }
        // before=1, after=2 from init identify; no explicit identify call
        expect(count).toEventually(equal(3))
    }

    typealias BeforeHook = (_: IdentifySeriesContext, _: IdentifySeriesData) -> IdentifySeriesData
    typealias AfterHook = (_: IdentifySeriesContext, _: IdentifySeriesData, _: IdentifyResult) -> IdentifySeriesData

    class MockPlugin: Plugin {
        let hooks: [Hook]

        init(hooks: [Hook]) {
            self.hooks = hooks
        }

        func getMetadata() -> LaunchDarkly.PluginMetadata {
            return PluginMetadata(name: "mock-plugin")
        }

        func register(client: LaunchDarkly.LDClient, metadata: LaunchDarkly.EnvironmentMetadata) {}

        func getHooks(metadata: LaunchDarkly.EnvironmentMetadata) -> [LaunchDarkly.Hook] {
            return hooks
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

        func beforeIdentify(seriesContext: LaunchDarkly.IdentifySeriesContext, seriesData: LaunchDarkly.IdentifySeriesData) -> LaunchDarkly.IdentifySeriesData {
            return self.before(seriesContext, seriesData)
        }

        func afterIdentify(seriesContext: LaunchDarkly.IdentifySeriesContext, seriesData: LaunchDarkly.IdentifySeriesData, result: LaunchDarkly.IdentifyResult) -> LaunchDarkly.IdentifySeriesData {
            return self.after(seriesContext, seriesData, result)
        }
    }
}
