//
//  LDConfigSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 11/10/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
@testable import LaunchDarkly

final class LDConfigSpec: QuickSpec {
    struct Constants {
        fileprivate static let alternateMockUrl = URL(string: "https://dummy.alternate.com")!
        fileprivate static let eventCapacity = 10
        fileprivate static let connectionTimeout: TimeInterval = 0.01
        fileprivate static let eventFlushInterval: TimeInterval = 0.01
        fileprivate static let flagPollingInterval: TimeInterval = 0.01
        fileprivate static let backgroundFlagPollingInterval: TimeInterval = 0.01

        fileprivate static let streamingMode = LDStreamingMode.polling
        fileprivate static let enableBackgroundUpdates = true
        fileprivate static let startOnline = false

        fileprivate static let allUserAttributesPrivate = true
        fileprivate static let privateUserAttributes: [String]? = ["dummy"]

        fileprivate static let useReport = true

        fileprivate static let inlineUserInEvents = true

        fileprivate static let debugMode = true
    }

    struct TestContext {
        var subject: LDConfig!
        var environmentReporter: EnvironmentReportingMock!

        init(useStub: Bool = false, operatingSystem: OperatingSystem? = nil, isDebugBuild: Bool? = nil) {
            self.environmentReporter = EnvironmentReportingMock()
            if let operatingSystem = operatingSystem {
                self.environmentReporter.operatingSystem = operatingSystem
            }
            if let isDebugBuild = isDebugBuild {
                self.environmentReporter.isDebugBuild = isDebugBuild
            }
            subject = useStub ? LDConfig.stub(mobileKey: LDConfig.Constants.mockMobileKey, environmentReporter: self.environmentReporter) :
                LDConfig(mobileKey: LDConfig.Constants.mockMobileKey, environmentReporter: self.environmentReporter)
        }
    }

    override func spec() {
        initSpec()
        flagPollingIntervalSpec()
        equalsSpec()
        isReportRetryStatusCodeSpec()
        allowStreamingModeSpec()
        allowBackgroundUpdatesSpec()
    }

    func initSpec() {
        describe("init") {
            var config: LDConfig!
            beforeEach {
                config = LDConfig(mobileKey: LDConfig.Constants.mockMobileKey)
            }
            context("without changing config values") {
                it("has the default config values") {
                    expect(config.mobileKey) == LDConfig.Constants.mockMobileKey
                    expect(config.baseUrl) == LDConfig.Defaults.baseUrl
                    expect(config.eventsUrl) == LDConfig.Defaults.eventsUrl
                    expect(config.streamUrl) == LDConfig.Defaults.streamUrl
                    expect(config.eventCapacity) == LDConfig.Defaults.eventCapacity
                    expect(config.connectionTimeout) == LDConfig.Defaults.connectionTimeout
                    expect(config.eventFlushInterval) == LDConfig.Defaults.eventFlushInterval
                    expect(config.flagPollingInterval) == LDConfig.Defaults.flagPollingInterval
                    expect(config.backgroundFlagPollingInterval) == LDConfig.Defaults.backgroundFlagPollingInterval
                    expect(config.streamingMode) == LDConfig.Defaults.streamingMode
                    expect(config.enableBackgroundUpdates) == LDConfig.Defaults.enableBackgroundUpdates
                    expect(config.startOnline) == LDConfig.Defaults.startOnline
                    expect(config.allUserAttributesPrivate) == LDConfig.Defaults.allUserAttributesPrivate
                    expect(config.privateUserAttributes).to(beNil())
                    expect(config.useReport) == LDConfig.Defaults.useReport
                    expect(config.inlineUserInEvents) == LDConfig.Defaults.inlineUserInEvents
                    expect(config.isDebugMode) == LDConfig.Defaults.debugMode
                }
            }
            context("changing the config values") {
                var testElements: [(OperatingSystem, LDConfig)]!
                beforeEach {
                    testElements = [(OperatingSystem, LDConfig)]()
                    OperatingSystem.allOperatingSystems.forEach { (os) in   //iOS, watchOS, & tvOS don't allow enableBackgroundUpdates to change, macOS should
                        let testContext = TestContext(operatingSystem: os)
                        config = testContext.subject

                        config.baseUrl = Constants.alternateMockUrl
                        config.eventsUrl = Constants.alternateMockUrl
                        config.streamUrl = Constants.alternateMockUrl
                        config.eventCapacity = Constants.eventCapacity
                        config.connectionTimeout = Constants.connectionTimeout
                        config.eventFlushInterval = Constants.eventFlushInterval
                        config.flagPollingInterval = Constants.flagPollingInterval
                        config.backgroundFlagPollingInterval = Constants.backgroundFlagPollingInterval
                        config.streamingMode = Constants.streamingMode
                        config.enableBackgroundUpdates = Constants.enableBackgroundUpdates
                        config.startOnline = Constants.startOnline
                        config.allUserAttributesPrivate = Constants.allUserAttributesPrivate
                        config.privateUserAttributes = Constants.privateUserAttributes
                        config.useReport = Constants.useReport
                        config.inlineUserInEvents = Constants.inlineUserInEvents
                        config.isDebugMode = Constants.debugMode

                        testElements.append((os, config))
                    }
                }
                it("has the changed config values") {
                    testElements.forEach { (os, config) in
                        expect(config.baseUrl) == Constants.alternateMockUrl
                        expect(config.eventsUrl) == Constants.alternateMockUrl
                        expect(config.streamUrl) == Constants.alternateMockUrl
                        expect(config.eventCapacity) == Constants.eventCapacity
                        expect(config.connectionTimeout) == Constants.connectionTimeout
                        expect(config.eventFlushInterval) == Constants.eventFlushInterval
                        expect(config.flagPollingInterval) == Constants.flagPollingInterval
                        expect(config.backgroundFlagPollingInterval) == Constants.backgroundFlagPollingInterval
                        expect(config.streamingMode) == Constants.streamingMode
                        expect(config.enableBackgroundUpdates) == os.isBackgroundEnabled    //iOS, watchOS, & tvOS don't allow this to change, macOS should
                        expect(config.startOnline) == Constants.startOnline
                        expect(config.allUserAttributesPrivate) == Constants.allUserAttributesPrivate
                        expect(config.privateUserAttributes) == Constants.privateUserAttributes
                        expect(config.useReport) == Constants.useReport
                        expect(config.inlineUserInEvents) == Constants.inlineUserInEvents
                        expect(config.isDebugMode) == Constants.debugMode
                    }
                }
            }
        }
        describe("Minima init") {
            var environmentReporter: EnvironmentReportingMock!
            var minima: LDConfig.Minima!
            beforeEach {
                environmentReporter = EnvironmentReportingMock()
            }
            context("for production builds") {
                beforeEach {
                    environmentReporter.isDebugBuild = false
                    minima = LDConfig.Minima(environmentReporter: environmentReporter)
                }
                it("has the production minima") {
                    expect(minima.flagPollingInterval) == LDConfig.Minima.Production.flagPollingInterval
                    expect(minima.backgroundFlagPollingInterval) == LDConfig.Minima.Production.backgroundFlagPollingInterval
                }
            }
            context("for debug builds") {
                beforeEach {
                    environmentReporter.isDebugBuild = true
                    minima = LDConfig.Minima(environmentReporter: environmentReporter)
                }
                it("has the debug minima") {
                    expect(minima.flagPollingInterval) == LDConfig.Minima.Debug.flagPollingInterval
                    expect(minima.backgroundFlagPollingInterval) == LDConfig.Minima.Debug.backgroundFlagPollingInterval
                }
            }
        }
    }

    func flagPollingIntervalSpec() {
        var testContext: TestContext!
        var effectivePollingInterval: TimeInterval!

        beforeEach {
            testContext = TestContext()
        }

        describe("flagPollingInterval") {
            context("when running in foreground mode") {
                context("polling interval above the minimum") {
                    beforeEach {
                        testContext.subject.flagPollingInterval = testContext.subject.minima.flagPollingInterval + 0.001

                        effectivePollingInterval = testContext.subject.flagPollingInterval(runMode: .foreground)
                    }
                    it("returns flagPollingInterval") {
                        expect(effectivePollingInterval) == testContext.subject.flagPollingInterval
                    }
                }
                context("polling interval at the minimum") {
                    beforeEach {
                        testContext.subject.flagPollingInterval = testContext.subject.minima.flagPollingInterval

                        effectivePollingInterval = testContext.subject.flagPollingInterval(runMode: .foreground)
                    }
                    it("returns flagPollingInterval") {
                        expect(effectivePollingInterval) == testContext.subject.flagPollingInterval
                    }
                }
                context("polling interval below the minimum") {
                    beforeEach {
                        testContext.subject.flagPollingInterval = testContext.subject.minima.flagPollingInterval - 0.001

                        effectivePollingInterval = testContext.subject.flagPollingInterval(runMode: .foreground)
                    }
                    it("returns Minima.flagPollingInterval") {
                        expect(effectivePollingInterval) == testContext.subject.minima.flagPollingInterval
                    }
                }
            }
            context("when running in background mode") {
                context("polling interval above the minimum") {
                    beforeEach {
                        testContext.subject.backgroundFlagPollingInterval = testContext.subject.minima.backgroundFlagPollingInterval + 0.001

                        effectivePollingInterval = testContext.subject.flagPollingInterval(runMode: .background)
                    }
                    it("returns backgroundFlagPollingInterval") {
                        expect(effectivePollingInterval) == testContext.subject.backgroundFlagPollingInterval
                    }
                }
                context("polling interval at the minimum") {
                    beforeEach {
                        testContext.subject.backgroundFlagPollingInterval = testContext.subject.minima.backgroundFlagPollingInterval

                        effectivePollingInterval = testContext.subject.flagPollingInterval(runMode: .background)
                    }
                    it("returns backgroundFlagPollingInterval") {
                        expect(effectivePollingInterval) == testContext.subject.backgroundFlagPollingInterval
                    }
                }
                context("polling interval below the minimum") {
                    beforeEach {
                        testContext.subject.backgroundFlagPollingInterval = testContext.subject.minima.backgroundFlagPollingInterval - 0.001

                        effectivePollingInterval = testContext.subject.flagPollingInterval(runMode: .background)
                    }
                    it("returns Minima.backgroundFlagPollingInterval") {
                        expect(effectivePollingInterval) == testContext.subject.minima.backgroundFlagPollingInterval
                    }
                }
            }
        }
    }

    func equalsSpec() {
        var testContext: TestContext!
        var otherConfig: LDConfig!

        beforeEach {
            testContext = TestContext(useStub: true)
            testContext.subject.useReport = true
        }

        describe("equals") {
            context("when settable values are all the same") {
                beforeEach {
                    otherConfig = testContext.subject
                }
                it("returns true") {
                    expect(testContext.subject) == otherConfig
                }
            }
            context("when the mobile keys differ") {
                beforeEach {
                    otherConfig = LDConfig.stub(mobileKey: LDConfig.Constants.alternateMobileKey, environmentReporter: testContext.environmentReporter)
                    otherConfig.useReport = testContext.subject.useReport
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when the base URLs differ") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.baseUrl = Constants.alternateMockUrl
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when the event URLs differ") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.eventsUrl = Constants.alternateMockUrl
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when the stream URLs differ") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.streamUrl = Constants.alternateMockUrl
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when the event capacities differ") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.eventCapacity = testContext.subject.eventCapacity + 1
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when the connection timeouts differ") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.connectionTimeout = testContext.subject.connectionTimeout + 0.001
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when the event flush intervals differ") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.eventFlushInterval = testContext.subject.eventFlushInterval + 0.001
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when the poll intervals differ") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.flagPollingInterval = testContext.subject.flagPollingInterval + 0.001
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when the background poll intervals differ") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.backgroundFlagPollingInterval = testContext.subject.backgroundFlagPollingInterval + 0.001
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when the streaming modes differ") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.streamingMode = testContext.subject.streamingMode == .streaming ? .polling : .streaming
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when enable background updates differ") {
                beforeEach {
                    testContext = TestContext(useStub: true, operatingSystem: OperatingSystem.backgroundEnabledOperatingSystems.first!) //must use a background enabled OS to test inequality
                    testContext.subject.useReport = true

                    otherConfig = testContext.subject
                    otherConfig.enableBackgroundUpdates = !testContext.subject.enableBackgroundUpdates
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when start online differs") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.startOnline = !testContext.subject.startOnline
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when debug modes differ") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.isDebugMode = !testContext.subject.isDebugMode
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when allUserAttributesPrivate differs") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.allUserAttributesPrivate = !testContext.subject.allUserAttributesPrivate
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when privateUserAttributes differ") {
                beforeEach {
                    testContext.subject.privateUserAttributes = LDUser.privatizableAttributes
                    otherConfig = testContext.subject
                }
                it("returns false") {
                    LDUser.privatizableAttributes.forEach { (attribute) in
                        otherConfig.privateUserAttributes = LDUser.privatizableAttributes.filter {
                            $0 != attribute
                        }
                        expect(testContext.subject) != otherConfig
                    }
                }
            }
            context("when useReport differs") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.useReport = !testContext.subject.useReport
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when inlineUserInEvents differs") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.inlineUserInEvents = !testContext.subject.inlineUserInEvents
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
        }
    }

    func isReportRetryStatusCodeSpec() {
        describe("isReportRetryStatusCode") {
            var testStatusCodes: [Int]!
            context("when status code is a retry status code") {
                beforeEach {
                    testStatusCodes = LDConfig.reportRetryStatusCodes
                }
                it("returns true") {
                    testStatusCodes.forEach { (testCode) in
                        expect(LDConfig.isReportRetryStatusCode(testCode)) == true
                    }
                }
            }
            context("when status code is not a retry status code") {
                beforeEach {
                    testStatusCodes = HTTPURLResponse.StatusCodes.all.filter { (code) in
                        !LDConfig.reportRetryStatusCodes.contains(code)
                    }
                }
                it("returns false") {
                    testStatusCodes.forEach { (testCode) in
                        expect(LDConfig.isReportRetryStatusCode(testCode)) == false
                    }
                }
            }
        }
    }

    private func allowStreamingModeSpec() {
        var testContext: TestContext!
        describe("allowStreamingMode") {
            it("allows streaming mode only on selected operating systems") {
                for operatingSystem in OperatingSystem.allOperatingSystems {
                    testContext = TestContext(useStub: true, operatingSystem: operatingSystem)
                    expect(testContext.subject.allowStreamingMode) == operatingSystem.isStreamingEnabled
                }
            }
        }
    }

    private func allowBackgroundUpdatesSpec() {
        var testContext: TestContext!
        describe("enableBackgroundUpdates") {
            it("enables background updates only on selected operating systems") {
                for operatingSystem in OperatingSystem.allOperatingSystems {
                    testContext = TestContext(useStub: true, operatingSystem: operatingSystem)
                    testContext.subject.enableBackgroundUpdates = true
                    expect(testContext.subject.enableBackgroundUpdates) == operatingSystem.isBackgroundEnabled
                }
            }
        }
    }
}
