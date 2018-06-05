//
//  LDConfigSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 11/10/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
@testable import LaunchDarkly

final class LDConfigSpec: QuickSpec {
    struct Constants {
        fileprivate static let alternateMockUrl = URL(string: "https://dummy.alternate.com")!
        fileprivate static let eventCapacity = 10
        fileprivate static let connectionTimeoutMillis = 10
        fileprivate static let eventFlushIntervalMillis = 10
        fileprivate static let pollIntervalMillis = 10
        fileprivate static let backgroundPollIntervalMillis = 10

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
            if let operatingSystem = operatingSystem { self.environmentReporter.operatingSystem = operatingSystem }
            if let isDebugBuild = isDebugBuild { self.environmentReporter.isDebugBuild = isDebugBuild }
            subject = useStub ? LDConfig.stub(environmentReporter: self.environmentReporter) : LDConfig(environmentReporter: self.environmentReporter)
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
                config = LDConfig()
            }
            context("without changing config values") {
                it("has the default config values") {
                    expect(config.baseUrl) == LDConfig.Defaults.baseUrl
                    expect(config.eventsUrl) == LDConfig.Defaults.eventsUrl
                    expect(config.streamUrl) == LDConfig.Defaults.streamUrl
                    expect(config.eventCapacity) == LDConfig.Defaults.eventCapacity
                    expect(config.connectionTimeoutMillis) == LDConfig.Defaults.connectionTimeoutMillis
                    expect(config.eventFlushIntervalMillis) == LDConfig.Defaults.eventFlushIntervalMillis
                    expect(config.pollIntervalMillis) == LDConfig.Defaults.pollIntervalMillis
                    expect(config.backgroundPollIntervalMillis) == LDConfig.Defaults.backgroundPollIntervalMillis
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
                beforeEach {
                    config.baseUrl = Constants.alternateMockUrl
                    config.eventsUrl = Constants.alternateMockUrl
                    config.streamUrl = Constants.alternateMockUrl
                    config.eventCapacity = Constants.eventCapacity
                    config.connectionTimeoutMillis = Constants.connectionTimeoutMillis
                    config.eventFlushIntervalMillis = Constants.eventFlushIntervalMillis
                    config.pollIntervalMillis = Constants.pollIntervalMillis
                    config.backgroundPollIntervalMillis = Constants.backgroundPollIntervalMillis
                    config.streamingMode = Constants.streamingMode
                    config.enableBackgroundUpdates = Constants.enableBackgroundUpdates
                    config.startOnline = Constants.startOnline
                    config.allUserAttributesPrivate = Constants.allUserAttributesPrivate
                    config.privateUserAttributes = Constants.privateUserAttributes
                    config.useReport = Constants.useReport
                    config.inlineUserInEvents = Constants.inlineUserInEvents
                    config.isDebugMode = Constants.debugMode
                }
                it("has the changed config values") {
                    expect(config.baseUrl) == Constants.alternateMockUrl
                    expect(config.eventsUrl) == Constants.alternateMockUrl
                    expect(config.streamUrl) == Constants.alternateMockUrl
                    expect(config.eventCapacity) == Constants.eventCapacity
                    expect(config.connectionTimeoutMillis) == Constants.connectionTimeoutMillis
                    expect(config.eventFlushIntervalMillis) == Constants.eventFlushIntervalMillis
                    expect(config.pollIntervalMillis) == Constants.pollIntervalMillis
                    expect(config.backgroundPollIntervalMillis) == Constants.backgroundPollIntervalMillis
                    expect(config.streamingMode) == Constants.streamingMode
                    expect(config.enableBackgroundUpdates) == Constants.enableBackgroundUpdates
                    expect(config.startOnline) == Constants.startOnline
                    expect(config.allUserAttributesPrivate) == Constants.allUserAttributesPrivate
                    expect(config.privateUserAttributes) == Constants.privateUserAttributes
                    expect(config.useReport) == Constants.useReport
                    expect(config.inlineUserInEvents) == Constants.inlineUserInEvents
                    expect(config.isDebugMode) == Constants.debugMode
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
                    expect(minima.pollingIntervalMillis) == LDConfig.Minima.Production.pollingIntervalMillis
                    expect(minima.backgroundPollIntervalMillis) == LDConfig.Minima.Production.backgroundPollIntervalMillis
                }
            }
            context("for debug builds") {
                beforeEach {
                    environmentReporter.isDebugBuild = true
                    minima = LDConfig.Minima(environmentReporter: environmentReporter)
                }
                it("has the debug minima") {
                    expect(minima.pollingIntervalMillis) == LDConfig.Minima.Debug.pollingIntervalMillis
                    expect(minima.backgroundPollIntervalMillis) == LDConfig.Minima.Debug.backgroundPollIntervalMillis
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
                        testContext.subject.pollIntervalMillis = testContext.subject.minima.pollingIntervalMillis + 1

                        effectivePollingInterval = testContext.subject.flagPollingInterval(runMode: .foreground)
                    }
                    it("returns pollIntervalMillis") {
                        expect(effectivePollingInterval) == testContext.subject.flagPollInterval
                    }
                }
                context("polling interval at the minimum") {
                    beforeEach {
                        testContext.subject.pollIntervalMillis = testContext.subject.minima.pollingIntervalMillis

                        effectivePollingInterval = testContext.subject.flagPollingInterval(runMode: .foreground)
                    }
                    it("returns pollIntervalMillis") {
                        expect(effectivePollingInterval) == testContext.subject.flagPollInterval
                    }
                }
                context("polling interval below the minimum") {
                    beforeEach {
                        testContext.subject.pollIntervalMillis = testContext.subject.minima.pollingIntervalMillis - 1

                        effectivePollingInterval = testContext.subject.flagPollingInterval(runMode: .foreground)
                    }
                    it("returns Minima.pollIntervalMillis") {
                        expect(effectivePollingInterval) == testContext.subject.minima.pollingIntervalMillis.timeInterval
                    }
                }
            }
            context("when running in background mode") {
                context("polling interval above the minimum") {
                    beforeEach {
                        testContext.subject.backgroundPollIntervalMillis = testContext.subject.minima.backgroundPollIntervalMillis + 1

                        effectivePollingInterval = testContext.subject.flagPollingInterval(runMode: .background)
                    }
                    it("returns backgroundPollIntervalMillis") {
                        expect(effectivePollingInterval) == testContext.subject.backgroundFlagPollInterval
                    }
                }
                context("polling interval at the minimum") {
                    beforeEach {
                        testContext.subject.backgroundPollIntervalMillis = testContext.subject.minima.backgroundPollIntervalMillis

                        effectivePollingInterval = testContext.subject.flagPollingInterval(runMode: .background)
                    }
                    it("returns backgroundPollIntervalMillis") {
                        expect(effectivePollingInterval) == testContext.subject.backgroundFlagPollInterval
                    }
                }
                context("polling interval below the minimum") {
                    beforeEach {
                        testContext.subject.backgroundPollIntervalMillis = testContext.subject.minima.backgroundPollIntervalMillis - 1

                        effectivePollingInterval = testContext.subject.flagPollingInterval(runMode: .background)
                    }
                    it("returns Minima.backgroundPollIntervalMillis") {
                        expect(effectivePollingInterval) == testContext.subject.minima.backgroundPollIntervalMillis.timeInterval
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
            context("when the connection timeouts differ") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.connectionTimeoutMillis = testContext.subject.connectionTimeoutMillis + 1
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when the event flush intervals differ") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.eventFlushIntervalMillis = testContext.subject.eventFlushIntervalMillis + 1
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when the poll intervals differ") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.pollIntervalMillis = testContext.subject.pollIntervalMillis + 1
                }
                it("returns false") {
                    expect(testContext.subject) != otherConfig
                }
            }
            context("when the background poll intervals differ") {
                beforeEach {
                    otherConfig = testContext.subject
                    otherConfig.backgroundPollIntervalMillis = testContext.subject.backgroundPollIntervalMillis + 1
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
                        otherConfig.privateUserAttributes = LDUser.privatizableAttributes.filter { $0 != attribute }
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
                    testStatusCodes = HTTPURLResponse.StatusCodes.all.filter { (code) in !LDConfig.reportRetryStatusCodes.contains(code) }
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
            //TODO: When adding tv support, add test covering that OS too
        }
    }

    private func allowBackgroundUpdatesSpec() {
        var testContext: TestContext!
        describe("enableBackgroundUpdates") {
            context("when using a debug build") {
                beforeEach {
                    testContext = TestContext(useStub: true, isDebugBuild: true)
                    testContext.subject.enableBackgroundUpdates = true
                }
                it("enables background updates") {
                    expect(testContext.subject.enableBackgroundUpdates) == true
                }
            }
            context("when using a production build") {
                it("enables background updates only on selected operating systems") {
                    for operatingSystem in OperatingSystem.allOperatingSystems {
                        testContext = TestContext(useStub: true, operatingSystem: operatingSystem, isDebugBuild: false)
                        testContext.subject.enableBackgroundUpdates = true
                        expect(testContext.subject.enableBackgroundUpdates) == operatingSystem.isBackgroundEnabled
                    }
                }
            }
        }
    }
}
