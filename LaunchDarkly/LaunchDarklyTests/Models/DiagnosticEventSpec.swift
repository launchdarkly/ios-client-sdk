import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class DiagnosticEventSpec: QuickSpec {

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
            it("encodes correct values to keys") {
                let uuid = UUID().uuidString
                let diagnosticId = DiagnosticId(diagnosticId: uuid, sdkKey: "this_is_a_fake_key")
                encodesToObject(diagnosticId) { decoded in
                    expect(decoded.count) == 2
                    expect(decoded["diagnosticId"]) == .string(uuid)
                    expect(decoded["sdkKeySuffix"]) == "ke_key"
                }
            }
            it("can load and restore through codable protocol") {
                let uuid = UUID().uuidString
                let diagnosticId = DiagnosticId(diagnosticId: uuid, sdkKey: "this_is_a_fake_key")
                let decoded = self.loadAndRestore(diagnosticId)
                expect(decoded?.diagnosticId) == diagnosticId.diagnosticId
                expect(decoded?.sdkKeySuffix) == diagnosticId.sdkKeySuffix
            }
        }
    }

    private func diagnosticSdkSpec() {
        context("DiagnosticSdk") {
            context("without wrapper configured") {
                it("has correct values and encoding") {
                    let config = LDConfig.stub
                    let diagnosticSdk = DiagnosticSdk(config: config)
                    expect(diagnosticSdk.name) == "ios-client-sdk"
                    expect(diagnosticSdk.version) == ReportingConsts.sdkVersion
                    expect(diagnosticSdk.wrapperName).to(beNil())
                    expect(diagnosticSdk.wrapperVersion).to(beNil())
                    encodesToObject(diagnosticSdk) { decoded in
                        expect(decoded.count) == 2
                        expect(decoded["name"]) == "ios-client-sdk"
                        expect(decoded["version"]) == .string(ReportingConsts.sdkVersion)
                    }
                }
            }
            context("with wrapper configured") {
                it("has correct values and encoding") {
                    var config = LDConfig.stub
                    config.wrapperName = "ReactNative"
                    config.wrapperVersion = "0.1.0"
                    let diagnosticSdk = DiagnosticSdk(config: config)
                    expect(diagnosticSdk.name) == "ios-client-sdk"
                    expect(diagnosticSdk.version) == ReportingConsts.sdkVersion
                    expect(diagnosticSdk.wrapperName) == config.wrapperName
                    expect(diagnosticSdk.wrapperVersion) == config.wrapperVersion
                    encodesToObject(diagnosticSdk) { decoded in
                        expect(decoded.count) == 4
                        expect(decoded["name"]) == "ios-client-sdk"
                        expect(decoded["version"]) == .string(ReportingConsts.sdkVersion)
                        expect(decoded["wrapperName"]) == "ReactNative"
                        expect(decoded["wrapperVersion"]) == "0.1.0"
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
                        diagnosticPlatform = DiagnosticPlatform(environmentReporting: environmentReporter)
                    }
                    it("inits with os values") {
                        expect(diagnosticPlatform.name) == "swift"
                        expect(diagnosticPlatform.systemVersion) == environmentReporter.systemVersion
                        expect(diagnosticPlatform.deviceType) == environmentReporter.deviceModel

                        // TODO(os-tests): We need to expand this to the other OSs
                        if os == .iOS && os == SystemCapabilities.operatingSystem {
                            expect(diagnosticPlatform.systemName) == os.rawValue
                            expect(diagnosticPlatform.backgroundEnabled) == os.isBackgroundEnabled
                            expect(diagnosticPlatform.streamingEnabled) == os.isStreamingEnabled
                        }
                    }
                    it("encodes correct values to keys") {
                        encodesToObject(diagnosticPlatform) { decoded in
                            expect(decoded.count) == 6
                            expect(decoded["name"]) == .string(diagnosticPlatform.name)
                            expect(decoded["systemName"]) == .string(diagnosticPlatform.systemName)
                            expect(decoded["systemVersion"]) == .string(diagnosticPlatform.systemVersion)
                            expect(decoded["backgroundEnabled"]) == .bool(diagnosticPlatform.backgroundEnabled)
                            expect(decoded["streamingEnabled"]) == .bool(diagnosticPlatform.streamingEnabled)
                            expect(decoded["deviceType"]) == .string(diagnosticPlatform.deviceType)
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
                    it("encodes correct values to keys") {
                        encodesToObject(streamInit) { decoded in
                            expect(decoded.count) == 3
                            expect(decoded["timestamp"]) == .number(Double(streamInit.timestamp))
                            expect(decoded["durationMillis"]) == .number(Double(streamInit.durationMillis))
                            expect(decoded["failed"]) == .bool(streamInit.failed)
                        }
                    }
                    it("can load and restore through codable protocol") {
                        let decoded = self.loadAndRestore(streamInit)
                        expect(decoded?.timestamp) == streamInit.timestamp
                        expect(decoded?.durationMillis) == streamInit.durationMillis
                        expect(decoded?.failed) == streamInit.failed
                    }
                }
            }
        }
    }

    private func customizedConfig() -> LDConfig {
        var customConfig = LDConfig(mobileKey: "foobar", autoEnvAttributes: .disabled, isDebugBuild: true)
        customConfig.baseUrl = URL(string: "https://clientstream.launchdarkly.com")!
        customConfig.eventsUrl = URL(string: "https://app.launchdarkly.com")!
        customConfig.streamUrl = URL(string: "https://mobile.launchdarkly.com")!
        customConfig.eventCapacity = 1_000
        customConfig.connectionTimeout = 30.0
        customConfig.eventFlushInterval = 60.0
        customConfig.streamingMode = .polling
        customConfig.allContextAttributesPrivate = true
        customConfig.flagPollingInterval = 360.0
        customConfig.backgroundFlagPollingInterval = 1_800.0
        customConfig.useReport = true
        customConfig.enableBackgroundUpdates = true
        customConfig.evaluationReasons = true
        customConfig.maxCachedContexts = -2
        try! customConfig.setSecondaryMobileKeys(["test": "foobar1", "debug": "foobar2"])
        customConfig.diagnosticRecordingInterval = 600.0
        customConfig.wrapperName = "ReactNative"
        customConfig.wrapperVersion = "0.1.0"
        return customConfig
    }

    private func diagnosticConfigSpec() {
        let defaultConfig = LDConfig(mobileKey: "foobar", autoEnvAttributes: .disabled, isDebugBuild: true)
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
                    expect(diagnosticConfig.useReport) == false
                    expect(diagnosticConfig.backgroundPollingDisabled) == true
                    expect(diagnosticConfig.evaluationReasonsRequested) == false
                    expect(diagnosticConfig.maxCachedContexts) == 5
                    expect(diagnosticConfig.mobileKeyCount) == 1
                    expect(diagnosticConfig.diagnosticRecordingIntervalMillis) == 900_000
                    expect(diagnosticConfig.customHeaders) == false
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
                    expect(diagnosticConfig.useReport) == true
                    // TODO(os-tests): We need to expand this to the other OSs
                    if SystemCapabilities.operatingSystem == .iOS {
                        expect(diagnosticConfig.backgroundPollingDisabled) == true
                    }
                    expect(diagnosticConfig.evaluationReasonsRequested) == true
                    // All negative values become -1 for consistency
                    expect(diagnosticConfig.maxCachedContexts) == -1
                    expect(diagnosticConfig.mobileKeyCount) == 3
                    expect(diagnosticConfig.diagnosticRecordingIntervalMillis) == 600_000
                    expect(diagnosticConfig.customHeaders) == false
                }
            }
            context("init with overflowing config values") {
                it("has expected values") {
                    var overflowingConfig = customConfig
                    overflowingConfig.backgroundFlagPollingInterval = .greatestFiniteMagnitude
                    overflowingConfig.connectionTimeout = .greatestFiniteMagnitude
                    overflowingConfig.diagnosticRecordingInterval = .greatestFiniteMagnitude
                    overflowingConfig.eventFlushInterval = .greatestFiniteMagnitude
                    overflowingConfig.flagPollingInterval = .greatestFiniteMagnitude
                    let diagnosticConfig = DiagnosticConfig(config: overflowingConfig)
                    expect(diagnosticConfig.backgroundPollingIntervalMillis) == Int.max
                    expect(diagnosticConfig.connectTimeoutMillis) == Int.max
                    expect(diagnosticConfig.diagnosticRecordingIntervalMillis) == Int.max
                    expect(diagnosticConfig.eventsFlushIntervalMillis) == Int.max
                    expect(diagnosticConfig.pollingIntervalMillis) == Int.max
                }
            }
            var diagnosticConfig: DiagnosticConfig!
            for (name, config) in [("default", defaultConfig), ("custom", customConfig)] {
                context("with \(name) config") {
                    beforeEach {
                        diagnosticConfig = DiagnosticConfig(config: config)
                    }
                    it("encodes correct values to keys") {
                        encodesToObject(diagnosticConfig) { decoded in
                            expect(decoded.count) == 17
                            expect(decoded["customBaseURI"]) == .bool(diagnosticConfig.customBaseURI)
                            expect(decoded["customEventsURI"]) == .bool(diagnosticConfig.customEventsURI)
                            expect(decoded["customStreamURI"]) == .bool(diagnosticConfig.customStreamURI)
                            expect(decoded["eventsCapacity"]) == .number(Double(diagnosticConfig.eventsCapacity))
                            expect(decoded["connectTimeoutMillis"]) == .number(Double(diagnosticConfig.connectTimeoutMillis))
                            expect(decoded["eventsFlushIntervalMillis"]) == .number(Double(diagnosticConfig.eventsFlushIntervalMillis))
                            expect(decoded["streamingDisabled"]) == .bool(diagnosticConfig.streamingDisabled)
                            expect(decoded["allAttributesPrivate"]) == .bool(diagnosticConfig.allAttributesPrivate)
                            expect(decoded["pollingIntervalMillis"]) == .number(Double(diagnosticConfig.pollingIntervalMillis))
                            expect(decoded["backgroundPollingIntervalMillis"]) == .number(Double(diagnosticConfig.backgroundPollingIntervalMillis))
                            expect(decoded["useReport"]) == .bool(diagnosticConfig.useReport)
                            expect(decoded["backgroundPollingDisabled"]) == .bool(diagnosticConfig.backgroundPollingDisabled)
                            expect(decoded["evaluationReasonsRequested"]) == .bool(diagnosticConfig.evaluationReasonsRequested)
                            expect(decoded["maxCachedContexts"]) == .number(Double(diagnosticConfig.maxCachedContexts))
                            expect(decoded["mobileKeyCount"]) == .number(Double(diagnosticConfig.mobileKeyCount))
                            expect(decoded["diagnosticRecordingIntervalMillis"]) == .number(Double(diagnosticConfig.diagnosticRecordingIntervalMillis))
                        }
                    }
                    it("can load and restore through codable protocol") {
                        let decoded = self.loadAndRestore(diagnosticConfig)
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
                        expect(decoded?.useReport) == diagnosticConfig.useReport
                        expect(decoded?.backgroundPollingDisabled) == diagnosticConfig.backgroundPollingDisabled
                        expect(decoded?.evaluationReasonsRequested) == diagnosticConfig.evaluationReasonsRequested
                        expect(decoded?.maxCachedContexts) == diagnosticConfig.maxCachedContexts
                        expect(decoded?.mobileKeyCount) == diagnosticConfig.mobileKeyCount
                        expect(decoded?.diagnosticRecordingIntervalMillis) == diagnosticConfig.diagnosticRecordingIntervalMillis
                    }
                }
            }
        }
    }

    private func diagnosticKindSpec() {
        context("DiagnosticKind") {
            // JSONEncoder will encode raw primitives on newer platforms, but not all supported platforms. For these
            // tests we wrap the kind in an object to allow us to test the encoding.
            it("encodes to correct values") {
                encodesToObject(["abc": DiagnosticKind.diagnosticInit]) { value in
                    expect(value.count) == 1
                    expect(value["abc"]) == "diagnostic-init"
                }
                encodesToObject(["abc": DiagnosticKind.diagnosticStats]) { value in
                    expect(value.count) == 1
                    expect(value["abc"]) == "diagnostic"
                }
            }
            it("can load and restore through codable protocol") {
                for kind in [DiagnosticKind.diagnosticInit, DiagnosticKind.diagnosticStats] {
                    let decoded = self.loadAndRestore([kind])
                    expect(decoded) == [kind]
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
                diagnosticInit = DiagnosticInit(config: customConfig, environmentReporting: EnvironmentReportingMock(), diagnosticId: diagnosticId, creationDate: now)
            }
            it("inits with correct values") {
                expect(diagnosticInit.kind) == DiagnosticKind.diagnosticInit
                expect(diagnosticInit.id.diagnosticId) == diagnosticId.diagnosticId
                expect(diagnosticInit.id.sdkKeySuffix) == "foobar"
                expect(diagnosticInit.creationDate) == now
                // Spot check sub objects, just to ensure config is being passed along
                expect(diagnosticInit.sdk.wrapperName) == customConfig.wrapperName
                expect(diagnosticInit.configuration.customBaseURI) == true
                // TODO(os-tests): We need to expand this to the other OSs
                if SystemCapabilities.operatingSystem == .iOS {
                    expect(diagnosticInit.platform.backgroundEnabled) == false
                }
            }
            it("encodes correct values to keys") {
                let expectedId = encodeToLDValue(diagnosticId)
                let expectedSdk = encodeToLDValue(diagnosticInit.sdk)
                let expectedConfig = encodeToLDValue(diagnosticInit.configuration)
                let expectedPlatform = encodeToLDValue(diagnosticInit.platform)
                encodesToObject(diagnosticInit) { decoded in
                    expect(decoded.count) == 6
                    expect(decoded["kind"]) == .string(DiagnosticKind.diagnosticInit.rawValue)
                    expect(decoded["id"]) == expectedId
                    expect(decoded["creationDate"]) == .number(Double(now))
                    expect(decoded["sdk"]) == expectedSdk
                    expect(decoded["configuration"]) == expectedConfig
                    expect(decoded["platform"]) == expectedPlatform
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
                        diagnosticStats = DiagnosticStats(id: diagnosticId,
                                                          creationDate: now,
                                                          dataSinceDate: now - 60_000,
                                                          droppedEvents: 5,
                                                          eventsInLastBatch: 10,
                                                          streamInits: streamInits)
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
                    it("encodes correct values to keys") {
                        let expectedId = encodeToLDValue(diagnosticId)
                        let expectedInits = encodeToLDValue(streamInits)
                        encodesToObject(diagnosticStats) { decoded in
                            expect(decoded.count) == 7
                            expect(decoded["kind"]) == .string(DiagnosticKind.diagnosticStats.rawValue)
                            expect(decoded["id"]) == expectedId
                            expect(decoded["creationDate"]) == .number(Double(now))
                            expect(decoded["dataSinceDate"]) == .number(Double(now - 60_000))
                            expect(decoded["droppedEvents"]) == 5
                            expect(decoded["eventsInLastBatch"]) == 10
                            expect(decoded["streamInits"]) == expectedInits
                        }
                    }
                }
            }
        }
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private func loadAndRestore<T: Codable>(_ subject: T?) -> T? {
        let encoded = try? encoder.encode(subject)
        return try? decoder.decode(T.self, from: encoded!)
    }
}
