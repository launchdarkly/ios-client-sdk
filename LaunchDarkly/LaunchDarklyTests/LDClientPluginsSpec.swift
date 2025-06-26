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
