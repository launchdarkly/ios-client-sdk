//
//  DiagnosticEventSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2020 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
@testable import LaunchDarkly

final class DiagnosticEventSpec: QuickSpec {

    // We test against plist as well as JSON. Originally we were going to use plist for
    // the device cache and JSON on the wire, but JSON encoding is faster and smaller
    // than plist. Leaving testing against it for now.
    private let testEncoders: [(String, CodingScheme)] =
        [("JSON", CodingScheme(JSONEncoder(), JSONDecoder())),
         ("plist", CodingScheme(PropertyListEncoder(), PropertyListDecoder()))]

    override func spec() {
        diagnosticIdSpec()
        diagnosticSdkSpec()
        diagnosticPlatformSpec()
        diagnosticStreamInitSpec()
        diagnosticConfigSpec()
        diagnosticKindSpec()
        diagnosticInitSpec()
        diagnosticStatsSpec()
    }

    private func diagnosticIdSpec() {
        context("DiagnosticId init") {
            context("with empty mobile key") {
                it("inits with correct values") {
                    let uuid = UUID().uuidString
                    let diagnosticId = DiagnosticId(diagnosticId: uuid, sdkKey: "")
                    expect(diagnosticId.diagnosticId) == uuid
                    expect(diagnosticId.sdkKeySuffix) == ""
                }
            }
            context("with short mobile key") {
                it("inits with whole key") {
                    let uuid = UUID().uuidString
                    let diagnosticId = DiagnosticId(diagnosticId: uuid, sdkKey: "foo")
                    expect(diagnosticId.diagnosticId) == uuid
                    expect(diagnosticId.sdkKeySuffix) == "foo"
                }
            }
            context("with mobile key") {
                it("inits with suffix") {
                    let diagnosticId = DiagnosticId(diagnosticId: "", sdkKey: "this_is_a_fake_key")
                    expect(diagnosticId.diagnosticId) == ""
                    expect(diagnosticId.sdkKeySuffix) == "ke_key"
                }
            }
        }
        context("DiagnosticId encoding") {
            for (desc, scheme) in testEncoders {
                context("using \(desc) encoding") {
                    it("encodes correct values to keys") {
                        let uuid = UUID().uuidString
                        let diagnosticId = DiagnosticId(diagnosticId: uuid, sdkKey: "this_is_a_fake_key")
                        let decoded = self.loadAndRestoreRaw(scheme, diagnosticId)
                        expect(decoded.count) == 2
                        expect((decoded["diagnosticId"] as! String)) == uuid
                        expect((decoded["sdkKeySuffix"] as! String)) == "ke_key"
                    }
                    it("can load and restore through codable protocol") {
                        let uuid = UUID().uuidString
                        let diagnosticId = DiagnosticId(diagnosticId: uuid, sdkKey: "this_is_a_fake_key")
                        let decoded = self.loadAndRestore(scheme, diagnosticId)
                        expect(decoded?.diagnosticId) == diagnosticId.diagnosticId
                        expect(decoded?.sdkKeySuffix) == diagnosticId.sdkKeySuffix
                    }
                }
            }
        }
    }

    private func diagnosticSdkSpec() {
        context("DiagnosticSdk") {
            let defaultConfig = LDConfig.stub
            var wrapperConfig = LDConfig.stub
            wrapperConfig.wrapperName = "ReactNative"
            wrapperConfig.wrapperVersion = "0.1.0"
            for (title, config) in [("defaults", defaultConfig), ("wrapper set", wrapperConfig)] {
                context("with \(title)") {
                    it("inits with correct values") {
                        let diagnosticSdk = DiagnosticSdk(config: config)
                        expect(diagnosticSdk.name) == "ios-client-sdk"
                        expect(diagnosticSdk.version) == config.environmentReporter.sdkVersion
                        expect(diagnosticSdk.wrapperName == config.wrapperName) == true
                        expect(diagnosticSdk.wrapperVersion == config.wrapperVersion) == true
                    }
                    for (desc, scheme) in testEncoders {
                        context("using \(desc) encoding") {
                            it("encodes correct values to keys") {
                                let diagnosticSdk = DiagnosticSdk(config: config)
                                let decoded = self.loadAndRestoreRaw(scheme, diagnosticSdk)
                                expect((decoded["name"] as! String)) == "ios-client-sdk"
                                expect((decoded["version"] as! String)) == config.environmentReporter.sdkVersion
                                expect((decoded["wrapperName"] as! String?) == config.wrapperName) == true
                                expect((decoded["wrapperVersion"] as! String?) == config.wrapperVersion) == true
                                let expectedKeys = ["name", "version", "wrapperName", "wrapperVersion"]
                                expect(decoded.keys.allSatisfy(expectedKeys.contains)) == true
                            }
                            it("can load and restore through codable protocol") {
                                let diagnosticSdk = DiagnosticSdk(config: config)
                                let decoded = self.loadAndRestore(scheme, diagnosticSdk)
                                expect(decoded?.name) == diagnosticSdk.name
                                expect(decoded?.version) == diagnosticSdk.version
                                expect(decoded?.wrapperName == diagnosticSdk.wrapperName) == true
                                expect(decoded?.wrapperVersion == diagnosticSdk.wrapperVersion) == true
                            }
                        }
                    }
                }
            }
        }
    }

    private func diagnosticPlatformSpec() {
        var environmentReporter: EnvironmentReportingMock!
        var diagnosticPlatform: DiagnosticPlatform!
        context("DiagnosticPlatform") {
            for os in OperatingSystem.allOperatingSystems {
                context("with operating system \(String(describing: os))") {
                    beforeEach {
                        environmentReporter = EnvironmentReportingMock()
                        environmentReporter.operatingSystem = os
                        let config = LDConfig(mobileKey: "testKey", environmentReporter: environmentReporter)
                        diagnosticPlatform = DiagnosticPlatform(config: config)
                    }
                    it("inits with os values") {
                        expect(diagnosticPlatform.name) == "swift"
                        expect(diagnosticPlatform.systemName) == environmentReporter.operatingSystem.rawValue
                        expect(diagnosticPlatform.systemVersion) == environmentReporter.systemVersion
                        expect(diagnosticPlatform.backgroundEnabled) == environmentReporter.operatingSystem.isBackgroundEnabled
                        expect(diagnosticPlatform.streamingEnabled) == environmentReporter.operatingSystem.isStreamingEnabled
                        expect(diagnosticPlatform.deviceType) == environmentReporter.deviceType
                    }
                    for (desc, scheme) in testEncoders {
                        context("using \(desc) encoding") {
                            it("encodes correct values to keys") {
                                let decoded = self.loadAndRestoreRaw(scheme, diagnosticPlatform)
                                expect(decoded.count) == 6
                                expect((decoded["name"] as! String)) == diagnosticPlatform.name
                                expect((decoded["systemName"] as! String)) == diagnosticPlatform.systemName
                                expect((decoded["systemVersion"] as! String)) == diagnosticPlatform.systemVersion
                                expect((decoded["backgroundEnabled"] as! Bool)) == diagnosticPlatform.backgroundEnabled
                                expect((decoded["streamingEnabled"] as! Bool)) == diagnosticPlatform.streamingEnabled
                                expect((decoded["deviceType"] as! String)) == diagnosticPlatform.deviceType
                            }
                            it("can load and restore through codable protocol") {
                                let decoded = self.loadAndRestore(scheme, diagnosticPlatform)
                                expect(decoded?.name) == diagnosticPlatform.name
                                expect(decoded?.systemName) == diagnosticPlatform.systemName
                                expect(decoded?.systemVersion) == diagnosticPlatform.systemVersion
                                expect(decoded?.backgroundEnabled) == diagnosticPlatform.backgroundEnabled
                                expect(decoded?.streamingEnabled) == diagnosticPlatform.streamingEnabled
                                expect(decoded?.deviceType) == diagnosticPlatform.deviceType
                            }
                        }
                    }
                }
            }
        }
    }

    private func diagnosticStreamInitSpec() {
        context("DiagnosticStreamInit") {
            it("inits with given values") {
                let streamInit = DiagnosticStreamInit(timestamp: 1000, durationMillis: 100, failed: true)
                expect(streamInit.timestamp) == 1000
                expect(streamInit.durationMillis) == 100
                expect(streamInit.failed) == true
            }
            for streamInit in [DiagnosticStreamInit(timestamp: 1000, durationMillis: 100, failed: true),
                               DiagnosticStreamInit(timestamp: Date().millisSince1970, durationMillis: 0, failed: false)] {
                context("for init \(String(describing: streamInit))") {
                    for (desc, scheme) in testEncoders {
                        context("using \(desc) encoding") {
                            it("encodes correct values to keys") {
                                let decoded = self.loadAndRestoreRaw(scheme, streamInit)
                                expect(decoded.count) == 3
                                expect((decoded["timestamp"] as! Int64)) == streamInit.timestamp
                                expect((decoded["durationMillis"] as! Int64)) == Int64(streamInit.durationMillis)
                                expect((decoded["failed"] as! Bool) == streamInit.failed) == true
                            }
                            it("can load and restore through codable protocol") {
                                let decoded = self.loadAndRestore(scheme, streamInit)
                                expect(decoded?.timestamp) == streamInit.timestamp
                                expect(decoded?.durationMillis) == streamInit.durationMillis
                                expect(decoded?.failed) == streamInit.failed
                            }
                        }
                    }
                }
            }
        }
    }

    private func customizedConfig() -> LDConfig {
        let environmentReporter = EnvironmentReportingMock()
        environmentReporter.operatingSystem = OperatingSystem.backgroundEnabledOperatingSystems.first!
        var customConfig = LDConfig(mobileKey: "foobar", environmentReporter: environmentReporter)
        customConfig.baseUrl = URL(string: "https://clientstream.launchdarkly.com")!
        customConfig.eventsUrl = URL(string: "https://app.launchdarkly.com")!
        customConfig.streamUrl = URL(string: "https://mobile.launchdarkly.com")!
        customConfig.eventCapacity = 1_000
        customConfig.connectionTimeout = 30.0
        customConfig.eventFlushInterval = 60.0
        customConfig.streamingMode = .polling
        customConfig.allUserAttributesPrivate = true
        customConfig.flagPollingInterval = 360.0
        customConfig.backgroundFlagPollingInterval = 1_800.0
        customConfig.inlineUserInEvents = true
        customConfig.useReport = true
        customConfig.enableBackgroundUpdates = true
        customConfig.evaluationReasons = true
        customConfig.maxCachedUsers = -2
        // TODO: When adding Multi-environment, add additional keys
        customConfig.diagnosticRecordingInterval = 600.0
        customConfig.wrapperName = "ReactNative"
        customConfig.wrapperVersion = "0.1.0"
        return customConfig
    }

    private func diagnosticConfigSpec() {
        let environmentReporter = EnvironmentReportingMock()
        environmentReporter.operatingSystem = OperatingSystem.backgroundEnabledOperatingSystems.first!
        let defaultConfig = LDConfig(mobileKey: "foobar", environmentReporter: environmentReporter)
        let customConfig = customizedConfig()
        context("DiagnosticConfig") {
            context("init with default config") {
                it("has expected values") {
                    let diagnosticConfig = DiagnosticConfig(config: defaultConfig)
                    expect(diagnosticConfig.customBaseURI) == false
                    expect(diagnosticConfig.customEventsURI) == false
                    expect(diagnosticConfig.customStreamURI) == false
                    expect(diagnosticConfig.eventsCapacity) == 100
                    expect(diagnosticConfig.connectTimeoutMillis) == 10_000
                    expect(diagnosticConfig.eventsFlushIntervalMillis) == 30_000
                    expect(diagnosticConfig.streamingDisabled) == false
                    expect(diagnosticConfig.allAttributesPrivate) == false
                    expect(diagnosticConfig.pollingIntervalMillis) == 300_000
                    expect(diagnosticConfig.backgroundPollingIntervalMillis) == 3_600_000
                    expect(diagnosticConfig.inlineUsersInEvents) == false
                    expect(diagnosticConfig.useReport) == false
                    expect(diagnosticConfig.backgroundPollingDisabled) == true
                    expect(diagnosticConfig.evaluationReasonsRequested) == false
                    expect(diagnosticConfig.maxCachedUsers) == 5
                    expect(diagnosticConfig.mobileKeyCount) == 1
                    expect(diagnosticConfig.diagnosticRecordingIntervalMillis) == 900_000
                }
            }
            context("init with custom config") {
                it("has expected values") {
                    let diagnosticConfig = DiagnosticConfig(config: customConfig)
                    expect(diagnosticConfig.customBaseURI) == true
                    expect(diagnosticConfig.customEventsURI) == true
                    expect(diagnosticConfig.customStreamURI) == true
                    expect(diagnosticConfig.eventsCapacity) == 1_000
                    expect(diagnosticConfig.connectTimeoutMillis) == 30_000
                    expect(diagnosticConfig.eventsFlushIntervalMillis) == 60_000
                    expect(diagnosticConfig.streamingDisabled) == true
                    expect(diagnosticConfig.allAttributesPrivate) == true
                    expect(diagnosticConfig.pollingIntervalMillis) == 360_000
                    expect(diagnosticConfig.backgroundPollingIntervalMillis) == 1_800_000
                    expect(diagnosticConfig.inlineUsersInEvents) == true
                    expect(diagnosticConfig.useReport) == true
                    expect(diagnosticConfig.backgroundPollingDisabled) == false
                    expect(diagnosticConfig.evaluationReasonsRequested) == true
                    // All negative values become -1 for consistency
                    expect(diagnosticConfig.maxCachedUsers) == -1
                    // TODO: When adding Multi-environment, update count here
                    expect(diagnosticConfig.mobileKeyCount) == 1
                    expect(diagnosticConfig.diagnosticRecordingIntervalMillis) == 600_000
                }
            }
            var diagnosticConfig: DiagnosticConfig!
            for (name, config) in [("default", defaultConfig), ("custom", customConfig)] {
                context("with \(name) config") {
                    beforeEach {
                        diagnosticConfig = DiagnosticConfig(config: config)
                    }
                    for (desc, scheme) in testEncoders {
                        context("using \(desc) encoding") {
                            it("encodes correct values to keys") {
                                let decoded = self.loadAndRestoreRaw(scheme, diagnosticConfig)
                                expect(decoded.count) == 17
                                expect((decoded["customBaseURI"] as! Bool)) == diagnosticConfig.customBaseURI
                                expect((decoded["customEventsURI"] as! Bool)) == diagnosticConfig.customEventsURI
                                expect((decoded["customStreamURI"] as! Bool)) == diagnosticConfig.customStreamURI
                                expect((decoded["eventsCapacity"] as! Int64)) == Int64(diagnosticConfig.eventsCapacity)
                                expect((decoded["connectTimeoutMillis"] as! Int64)) == Int64(diagnosticConfig.connectTimeoutMillis)
                                expect((decoded["eventsFlushIntervalMillis"] as! Int64)) == Int64(diagnosticConfig.eventsFlushIntervalMillis)
                                expect((decoded["streamingDisabled"] as! Bool)) == diagnosticConfig.streamingDisabled
                                expect((decoded["allAttributesPrivate"] as! Bool)) == diagnosticConfig.allAttributesPrivate
                                expect((decoded["pollingIntervalMillis"] as! Int64)) == Int64(diagnosticConfig.pollingIntervalMillis)
                                expect((decoded["backgroundPollingIntervalMillis"] as! Int64)) == Int64(diagnosticConfig.backgroundPollingIntervalMillis)
                                expect((decoded["inlineUsersInEvents"] as! Bool)) == diagnosticConfig.inlineUsersInEvents
                                expect((decoded["useReport"] as! Bool)) == diagnosticConfig.useReport
                                expect((decoded["backgroundPollingDisabled"] as! Bool)) == diagnosticConfig.backgroundPollingDisabled
                                expect((decoded["evaluationReasonsRequested"] as! Bool)) == diagnosticConfig.evaluationReasonsRequested
                                expect((decoded["maxCachedUsers"] as! Int64)) == Int64(diagnosticConfig.maxCachedUsers)
                                expect((decoded["mobileKeyCount"] as! Int64)) == Int64(diagnosticConfig.mobileKeyCount)
                                expect((decoded["diagnosticRecordingIntervalMillis"] as! Int64)) == Int64(diagnosticConfig.diagnosticRecordingIntervalMillis)
                            }
                            it("can load and restore through codable protocol") {
                                let decoded = self.loadAndRestore(scheme, diagnosticConfig)
                                expect(decoded?.customBaseURI) == diagnosticConfig.customBaseURI
                                expect(decoded?.customEventsURI) == diagnosticConfig.customEventsURI
                                expect(decoded?.customStreamURI) == diagnosticConfig.customStreamURI
                                expect(decoded?.eventsCapacity) == diagnosticConfig.eventsCapacity
                                expect(decoded?.connectTimeoutMillis) == diagnosticConfig.connectTimeoutMillis
                                expect(decoded?.eventsFlushIntervalMillis) == diagnosticConfig.eventsFlushIntervalMillis
                                expect(decoded?.streamingDisabled) == diagnosticConfig.streamingDisabled
                                expect(decoded?.allAttributesPrivate) == diagnosticConfig.allAttributesPrivate
                                expect(decoded?.pollingIntervalMillis) == diagnosticConfig.pollingIntervalMillis
                                expect(decoded?.backgroundPollingIntervalMillis) == diagnosticConfig.backgroundPollingIntervalMillis
                                expect(decoded?.inlineUsersInEvents) == diagnosticConfig.inlineUsersInEvents
                                expect(decoded?.useReport) == diagnosticConfig.useReport
                                expect(decoded?.backgroundPollingDisabled) == diagnosticConfig.backgroundPollingDisabled
                                expect(decoded?.evaluationReasonsRequested) == diagnosticConfig.evaluationReasonsRequested
                                expect(decoded?.maxCachedUsers) == diagnosticConfig.maxCachedUsers
                                expect(decoded?.mobileKeyCount) == diagnosticConfig.mobileKeyCount
                                expect(decoded?.diagnosticRecordingIntervalMillis) == diagnosticConfig.diagnosticRecordingIntervalMillis
                            }
                        }
                    }
                }
            }
        }
    }

    private func diagnosticKindSpec() {
        context("DiagnosticKind") {
            // Cannot encode raw primitives in plist. JSONEncoder will encode raw primitives on newer platforms, but not all supported platforms. For these tests we wrap the kind in an array to allow us to test the encoding.
            for (desc, scheme) in testEncoders {
                context("using \(desc) encoding") {
                    it("encodes to correct values") {
                        let encodedInit = try? scheme.encode([DiagnosticKind.diagnosticInit])
                        expect(encodedInit).toNot(beNil())
                        let decodedInit = (try? scheme.decode(ArrayDecoder.self, from: encodedInit!))!.decoded
                        expect((decodedInit as! [String])[0]) == "diagnostic-init"

                        let encodedStats = try? scheme.encode([DiagnosticKind.diagnosticStats])
                        expect(encodedStats).toNot(beNil())
                        let decodedStats = (try? scheme.decode(ArrayDecoder.self, from: encodedStats!))!.decoded
                        expect((decodedStats as! [String])[0]) == "diagnostic"
                    }
                    it("can load and restore through codable protocol") {
                        for kind in [DiagnosticKind.diagnosticInit, DiagnosticKind.diagnosticStats] {
                            let decoded = self.loadAndRestore(scheme, [kind])
                            expect(decoded) == [kind]
                        }
                    }
                }
            }
        }
    }

    private func diagnosticInitSpec() {
        let customConfig = customizedConfig()
        var now: Int64!
        var diagnosticId: DiagnosticId!
        var diagnosticInit: DiagnosticInit!
        context("DiagnosticInit") {
            beforeEach {
                now = Date().millisSince1970
                diagnosticId = DiagnosticId(diagnosticId: UUID().uuidString, sdkKey: "foobar")
                diagnosticInit = DiagnosticInit(config: customConfig, diagnosticId: diagnosticId, creationDate: now)
            }
            it("inits with correct values") {
                expect(diagnosticInit.kind) == DiagnosticKind.diagnosticInit
                expect(diagnosticInit.id.diagnosticId) == diagnosticId.diagnosticId
                expect(diagnosticInit.id.sdkKeySuffix) == "foobar"
                expect(diagnosticInit.creationDate) == now
                // Spot check sub objects, just to ensure config is being passed along
                expect(diagnosticInit.sdk.wrapperName) == customConfig.wrapperName
                expect(diagnosticInit.configuration.customBaseURI) == true
                expect(diagnosticInit.platform.backgroundEnabled) == true
            }
            for (desc, scheme) in testEncoders {
                context("using \(desc) encoding") {
                    it("encodes correct values to keys") {
                        let expectedId = self.loadAndRestoreRaw(scheme, diagnosticId)
                        let expectedSdk = self.loadAndRestoreRaw(scheme, diagnosticInit.sdk)
                        let expectedConfig = self.loadAndRestoreRaw(scheme, diagnosticInit.configuration)
                        let expectedPlatform = self.loadAndRestoreRaw(scheme, diagnosticInit.platform)
                        let decoded = self.loadAndRestoreRaw(scheme, diagnosticInit)
                        expect(decoded.count) == 6
                        expect((decoded["kind"] as! String)) == DiagnosticKind.diagnosticInit.rawValue
                        expect(AnyComparer.isEqual(decoded["id"], to: expectedId)) == true
                        expect((decoded["creationDate"] as! Int64)) == now
                        expect(AnyComparer.isEqual(decoded["sdk"], to: expectedSdk)) == true
                        expect(AnyComparer.isEqual(decoded["configuration"], to: expectedConfig)) == true
                        expect(AnyComparer.isEqual(decoded["platform"], to: expectedPlatform)) == true
                    }
                    it("can load and restore through codable protocol") {
                        let decoded = self.loadAndRestore(scheme, diagnosticInit)
                        expect(decoded?.kind) == diagnosticInit.kind
                        expect(decoded?.id.diagnosticId) == diagnosticInit.id.diagnosticId
                        expect(decoded?.id.sdkKeySuffix) == diagnosticInit.id.sdkKeySuffix
                        expect(decoded?.creationDate) == diagnosticInit.creationDate
                        // Spot check sub objects, actual coding is testing separately
                        expect(decoded?.sdk.wrapperName) == diagnosticInit.sdk.wrapperName
                        expect(decoded?.configuration.customBaseURI) == diagnosticInit.configuration.customBaseURI
                        expect(decoded?.platform.backgroundEnabled) == diagnosticInit.platform.backgroundEnabled
                    }
                }
            }
        }
    }

    private func diagnosticStatsSpec() {
        var now: Int64!
        var diagnosticId: DiagnosticId!
        var diagnosticStats: DiagnosticStats!
        context("DiagnosticStats") {
            for streamInits in [[], [DiagnosticStreamInit(timestamp: 1_000, durationMillis: 100, failed: true),
                                     DiagnosticStreamInit(timestamp: 500, durationMillis: 0, failed: false)]] {
                context("with \(streamInits.count) inits") {
                    beforeEach {
                        now = Date().millisSince1970
                        diagnosticId = DiagnosticId(diagnosticId: UUID().uuidString, sdkKey: "foobar")
                        diagnosticStats = DiagnosticStats(id: diagnosticId, creationDate: now, dataSinceDate: now - 60_000, droppedEvents: 5, eventsInLastBatch: 10, streamInits: streamInits)
                    }
                    it("inits with correct values") {
                        expect(diagnosticStats.kind) == DiagnosticKind.diagnosticStats
                        expect(diagnosticStats.id.diagnosticId) == diagnosticId.diagnosticId
                        expect(diagnosticStats.id.sdkKeySuffix) == diagnosticId.sdkKeySuffix
                        expect(diagnosticStats.creationDate) == now
                        expect(diagnosticStats.dataSinceDate) == now - 60_000
                        expect(diagnosticStats.droppedEvents) == 5
                        expect(diagnosticStats.eventsInLastBatch) == 10
                        expect(diagnosticStats.streamInits.count) == streamInits.count
                        for i in 0..<streamInits.count {
                            expect(diagnosticStats.streamInits[i].timestamp) == streamInits[i].timestamp
                        }
                    }
                    for (desc, scheme) in testEncoders {
                        context("using \(desc) encoding") {
                            it("encodes correct values to keys") {
                                let expectedId = self.loadAndRestoreRaw(scheme, diagnosticId)
                                let expectedInits = streamInits.map { self.loadAndRestoreRaw(scheme, $0) }
                                let decoded = self.loadAndRestoreRaw(scheme, diagnosticStats)
                                expect(decoded.count) == 7
                                expect((decoded["kind"] as! String)) == DiagnosticKind.diagnosticStats.rawValue
                                expect(AnyComparer.isEqual(decoded["id"], to: expectedId)) == true
                                expect((decoded["creationDate"] as! Int64)) == now
                                expect((decoded["dataSinceDate"] as! Int64)) == now - 60_000
                                expect((decoded["droppedEvents"] as! Int64)) == 5
                                expect((decoded["eventsInLastBatch"] as! Int64)) == 10
                                expect(AnyComparer.isEqual(decoded["streamInits"], to: expectedInits)) == true
                            }
                            it("can load and restore through codable protocol") {
                                let decoded = self.loadAndRestore(scheme, diagnosticStats)
                                expect(decoded?.kind) == diagnosticStats.kind
                                expect(decoded?.id.diagnosticId) == diagnosticStats.id.diagnosticId
                                expect(decoded?.id.sdkKeySuffix) == diagnosticStats.id.sdkKeySuffix
                                expect(decoded?.creationDate) == diagnosticStats.creationDate
                                expect(decoded?.dataSinceDate) == diagnosticStats.dataSinceDate
                                expect(decoded?.droppedEvents) == diagnosticStats.droppedEvents
                                expect(decoded?.eventsInLastBatch) == diagnosticStats.eventsInLastBatch
                                expect(decoded?.streamInits.count) == diagnosticStats.streamInits.count
                                for i in 0..<diagnosticStats.streamInits.count {
                                    expect(decoded?.streamInits[i].timestamp) == diagnosticStats.streamInits[i].timestamp
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func loadAndRestore<T: Codable>(_ scheme: CodingScheme, _ subject: T?) -> T? {
        let encoded = try? scheme.encode(subject)
        return try? scheme.decode(T.self, from: encoded!)
    }

    private func loadAndRestoreRaw<T: Encodable>(_ scheme: CodingScheme, _ subject: T) -> [String: Any] {
        let encoded = try? scheme.encode(subject)
        expect(encoded).toNot(beNil())
        return (try? scheme.decode(ObjectDecoder.self, from: encoded!))!.decoded
    }
}

private struct DynamicKey: CodingKey {
    var intValue: Int?
    var stringValue: String

    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }
}

private struct ObjectDecoder: Decodable {
    let decoded: [String: Any]

    init(from decoder: Decoder) throws {
        var decoded: [String: Any] = [:]
        let container = try decoder.container(keyedBy: DynamicKey.self)
        for key in container.allKeys {
            if let prim = try? container.decode(PrimDecoder.self, forKey: key) {
                decoded[key.stringValue] = prim.decoded
            } else if let arr = try? container.decode(ArrayDecoder.self, forKey: key) {
                decoded[key.stringValue] = arr.decoded
            } else if let obj = try? container.decode(ObjectDecoder.self, forKey: key) {
                decoded[key.stringValue] = obj.decoded
            }
        }
        self.decoded = decoded
    }
}

private struct ArrayDecoder: Decodable {
    let decoded: [Any]

    init(from decoder: Decoder) throws {
        var decoded: [Any] = []
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            if let prim = try? container.decode(PrimDecoder.self) {
                decoded.append(prim.decoded)
            } else if let arr = try? container.decode(ArrayDecoder.self) {
                decoded.append(arr.decoded)
            } else if let obj = try? container.decode(ObjectDecoder.self) {
                decoded.append(obj.decoded)
            }
        }
        self.decoded = decoded
    }
}

private struct PrimDecoder: Decodable {
    let decoded: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let i = try? container.decode(Int64.self) {
            decoded = i
        } else if let b = try? container.decode(Bool.self) {
            decoded = b
        } else {
            decoded = try container.decode(String.self)
        }
    }
}

private class CodingScheme: TopLevelEncoder, TopLevelDecoder {
    let encoder: TopLevelEncoder
    let decoder: TopLevelDecoder

    init(_ encoder: TopLevelEncoder, _ decoder: TopLevelDecoder) {
        self.encoder = encoder
        self.decoder = decoder
    }

    func encode<T>(_ value: T) throws -> Data where T: Encodable {
        try encoder.encode(value)
    }

    func decode<T>(_ type: T.Type, from: Data) throws -> T where T: Decodable {
        try decoder.decode(type, from: from)
    }
}

protocol TopLevelEncoder {
    func encode<T>(_ value: T) throws -> Data where T: Encodable
}

protocol TopLevelDecoder {
    func decode<T>(_ type: T.Type, from: Data) throws -> T where T: Decodable
}

extension PropertyListEncoder: TopLevelEncoder { }
extension PropertyListDecoder: TopLevelDecoder { }
extension JSONEncoder: TopLevelEncoder { }
extension JSONDecoder: TopLevelDecoder { }
