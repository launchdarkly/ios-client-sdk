import Foundation
import OSLog
import Quick
import Nimble
import LDSwiftEventSource
import XCTest
@testable import LaunchDarkly

final class LDClientPluginsSpec: XCTestCase {
    func testPluginRegistration() {
        var registerCallCount = 0
        var receivedClient: LDClient?
        var receivedMetadata: EnvironmentMetadata?

        let mockPlugin = MockPlugin { client, metadata in
            registerCallCount += 1
            receivedClient = client
            receivedMetadata = metadata
        }

        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.plugins = [mockPlugin]

        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        XCTAssertEqual(registerCallCount, 1)

        XCTAssertNotNil(receivedClient)
        XCTAssertNotNil(receivedMetadata)
        XCTAssertEqual(receivedMetadata?.credential, "mobile-key")
        XCTAssertEqual(receivedMetadata?.sdkMetadata.name, SystemCapabilities.systemName)

        testContext.subject.boolVariation(forKey: "test-flag", defaultValue: false)
        XCTAssertEqual(mockPlugin.getCallRecord()[0], "first before")
        XCTAssertEqual(mockPlugin.getCallRecord()[1], "second before")
        XCTAssertEqual(mockPlugin.getCallRecord()[2], "second after")
        XCTAssertEqual(mockPlugin.getCallRecord()[3], "first after")
    }

    func testPluginRegistrationWithMultipleKeys() {
        var registerCallCount = 0
        var receivedClients: [LDClient] = []
        var receivedMetadata: [EnvironmentMetadata] = []

        let mockPlugin = MockPlugin { client, metadata in
            registerCallCount += 1
            receivedClients.append(client)
            receivedMetadata.append(metadata)
        }

        var config = LDConfig(mobileKey: "primary-mobile-key", autoEnvAttributes: .disabled)
        try! config.setSecondaryMobileKeys(["test": "secondary-key-1", "debug": "secondary-key-2"])
        config.plugins = [mockPlugin]

        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        XCTAssertEqual(registerCallCount, 3)

        XCTAssertEqual(receivedClients.count, 3)
        XCTAssertEqual(receivedMetadata.count, 3)

        let credentials = receivedMetadata.map { $0.credential }
        XCTAssertTrue(credentials.contains("primary-mobile-key"))
        XCTAssertTrue(credentials.contains("secondary-key-1"))
        XCTAssertTrue(credentials.contains("secondary-key-2"))

        for metadata in receivedMetadata {
            XCTAssertEqual(metadata.sdkMetadata.name, SystemCapabilities.systemName)
        }

        testContext.subject.boolVariation(forKey: "test-flag", defaultValue: false)
        XCTAssertEqual(mockPlugin.getCallRecord()[0], "first before")
        XCTAssertEqual(mockPlugin.getCallRecord()[1], "second before")
        XCTAssertEqual(mockPlugin.getCallRecord()[2], "second after")
        XCTAssertEqual(mockPlugin.getCallRecord()[3], "first after")
    }

    func testRegisterPluginPassesClientAndEnvironmentMetadata() {
        var registerCallCount = 0
        var receivedClient: LDClient?
        var receivedMetadata: EnvironmentMetadata?

        let mockPlugin = MockPlugin { client, metadata in
            registerCallCount += 1
            receivedClient = client
            receivedMetadata = metadata
        }

        let config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        // Nothing happens until the plugin is registered, since it was not in the configuration.
        XCTAssertEqual(registerCallCount, 0)

        testContext.subject.registerPlugin(mockPlugin)

        XCTAssertEqual(registerCallCount, 1)
        XCTAssertTrue(receivedClient === testContext.subject)
        // The same environment description a plugin configured up front would have been given.
        XCTAssertEqual(receivedMetadata?.credential, "mobile-key")
        XCTAssertEqual(receivedMetadata?.sdkMetadata.name, SystemCapabilities.systemName)
    }

    func testRegisterPluginActivatesBundledHooks() {
        let mockPlugin = MockPlugin { _, _ in }

        let config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        testContext.subject.registerPlugin(mockPlugin)
        testContext.subject.boolVariation(forKey: "test-flag", defaultValue: false)

        XCTAssertEqual(mockPlugin.getCallRecord(), ["first before", "second before", "second after", "first after"])
    }

    func testRegisterPluginDoesNotRunTheRegisteringPluginsOwnHooks() {
        // Evaluates a flag from inside register, so the test can tell whether this plugin's own hooks were live then.
        let mockPlugin = MockPlugin { client, _ in
            client.boolVariation(forKey: "test-flag", defaultValue: false)
        }

        let config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        // The hooks only go live once register has returned, so the evaluation register makes does not reach them.
        testContext.subject.registerPlugin(mockPlugin)
        XCTAssertEqual(mockPlugin.getCallRecord(), [])

        // They do run for evaluations made once registration has completed.
        testContext.subject.boolVariation(forKey: "test-flag", defaultValue: false)
        XCTAssertEqual(mockPlugin.getCallRecord(), ["first before", "second before", "second after", "first after"])
    }

    func testRegisterPluginHooksRunAfterConfiguredHooks() {
        var callRecord: [String] = []
        let record: (String) -> Void = { callRecord.append($0) }

        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.hooks = [LDClientPluginsSpec.recordingHook("config", into: record)]

        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        let plugin = StubPlugin(hooks: [LDClientPluginsSpec.recordingHook("plugin", into: record)])
        testContext.subject.registerPlugin(plugin)

        testContext.subject.boolVariation(forKey: "test-flag", defaultValue: false)

        // The configured hook was registered first, so it opens the series and, the after stage running in reverse,
        // closes it last.
        XCTAssertEqual(callRecord, ["config before", "plugin before", "plugin after", "config after"])
    }

    func testRegisterPluginAppliesOnlyToTheClientItIsCalledOn() {
        var callRecord: [String] = []
        let record: (String) -> Void = { callRecord.append($0) }

        var config = LDConfig(mobileKey: "primary-mobile-key", autoEnvAttributes: .disabled)
        try! config.setSecondaryMobileKeys(["test": "secondary-key-1"])

        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        let plugin = StubPlugin(hooks: [LDClientPluginsSpec.recordingHook("plugin", into: record)])
        testContext.subject.registerPlugin(plugin)

        testContext.subject.boolVariation(forKey: "test-flag", defaultValue: false)
        XCTAssertEqual(callRecord, ["plugin before", "plugin after"])

        // The other environment has its own client, which this plugin was not registered with.
        LDClient.get(environment: "test")?.boolVariation(forKey: "test-flag", defaultValue: false)
        XCTAssertEqual(callRecord, ["plugin before", "plugin after"])
    }

    func testConfiguredPluginHooksDoNotObserveAnotherPluginsRegister() {
        let firstPlugin = MockPlugin { _, _ in }
        // Registers after the first plugin, and evaluates a flag while doing so.
        let secondPlugin = MockPlugin { client, _ in
            _ = client.boolVariation(forKey: "test-flag", defaultValue: false)
        }

        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.plugins = [firstPlugin, secondPlugin]

        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        // Hooks are activated only once every plugin has registered, so the first plugin's hooks did not
        // observe the evaluation the second plugin made while registering.
        XCTAssertEqual(firstPlugin.getCallRecord(), [])

        _ = testContext.subject.boolVariation(forKey: "test-flag", defaultValue: false)
        XCTAssertEqual(firstPlugin.getCallRecord(), ["first before", "second before", "second after", "first after"])
    }

    private static func recordingHook(_ name: String, into record: @escaping (String) -> Void) -> MockHook {
        MockHook(
            before: { _, data in record("\(name) before"); return data },
            after: { _, data, _ in record("\(name) after"); return data })
    }

    /// Contributes a fixed set of hooks, and optionally runs a closure when registered.
    class StubPlugin: Plugin {
        private let hooksToReturn: [Hook]
        private let onRegister: (LDClient, EnvironmentMetadata) -> Void

        init(hooks: [Hook], onRegister: @escaping (LDClient, EnvironmentMetadata) -> Void = { _, _ in }) {
            self.hooksToReturn = hooks
            self.onRegister = onRegister
        }

        func getMetadata() -> PluginMetadata {
            return PluginMetadata(name: "StubPlugin")
        }

        func register(client: LDClient, metadata: EnvironmentMetadata) {
            onRegister(client, metadata)
        }

        func getHooks(metadata: EnvironmentMetadata) -> [Hook] {
            return hooksToReturn
        }
    }

    class MockPlugin: Plugin {
        private let registerCallback: (LDClient, EnvironmentMetadata) -> Void
        private var callRecord: [String] = []
        private var hooks: [Hook] = []

        init(registerCallback: @escaping (LDClient, EnvironmentMetadata) -> Void) {
            self.registerCallback = registerCallback
            let firstHook = MockHook(before: { _, data in self.callRecord.append("first before"); return data }, after: { _, data, _ in self.callRecord.append("first after"); return data })
            let secondHook = MockHook(before: { _, data in self.callRecord.append("second before"); return data }, after: { _, data, _ in self.callRecord.append("second after"); return data })
            self.hooks.append(firstHook)
            self.hooks.append(secondHook)
        }

        func getMetadata() -> PluginMetadata {
            return PluginMetadata(name: "MockPlugin")
        }

        func register(client: LDClient, metadata: EnvironmentMetadata) {
            registerCallback(client, metadata)
        }

        func getHooks(metadata: EnvironmentMetadata) -> [Hook] {
            return self.hooks
        }

        func getCallRecord() -> [String] {
            return self.callRecord
        }
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
