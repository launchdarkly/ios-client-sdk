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
        XCTAssertEqual(receivedMetadata?.sdkMetadata.name, ReportingConsts.sdkName)
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
            XCTAssertEqual(metadata.sdkMetadata.name, ReportingConsts.sdkName)
        }
    }
    
    class MockPlugin: Plugin {
        private let registerCallback: (LDClient, EnvironmentMetadata) -> Void
        
        init(registerCallback: @escaping (LDClient, EnvironmentMetadata) -> Void) {
            self.registerCallback = registerCallback
        }
        
        func getMetadata() -> PluginMetadata {
            return PluginMetadata(name: "MockPlugin")
        }
        
        func register(client: LDClient, metadata: EnvironmentMetadata) {
            registerCallback(client, metadata)
        }
        
        func getHooks(metadata: EnvironmentMetadata) -> [Hook] {
            return []
        }
    }
}
