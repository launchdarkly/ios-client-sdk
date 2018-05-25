//
//  LDConfigSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 11/10/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
@testable import Darkly

final class LDConfigSpec: QuickSpec {
    struct Constants {
        fileprivate static let alternateMockUrl = URL(string: "https://dummy.alternate.com")!
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
        flagPollingIntervalSpec()
        equalsSpec()
        isReportRetryStatusCodeSpec()
        allowStreamingModeSpec()
        allowBackgroundUpdatesSpec()
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
            context("on iOS devices") {
                beforeEach {
                    testContext = TestContext(useStub: true, operatingSystem: .iOS)
                }
                it("allows streaming mode") {
                    expect(testContext.subject.allowStreamingMode) == true
                }
            }
            context("on watchOS devices") {
                beforeEach {
                    testContext = TestContext(useStub: true, operatingSystem: .watchOS)
                }
                it("disallows streaming mode") {
                    expect(testContext.subject.allowStreamingMode) == false
                }
            }
            //TODO: When adding mac & tv support, add tests covering those OS's too
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
                context("on a background disabled operating system") {
                    it("does not enable background updates") {
                        for operatingSystem in OperatingSystem.backgroundDisabledOperatingSystems {
                            testContext = TestContext(useStub: true, operatingSystem: operatingSystem, isDebugBuild: false)
                            testContext.subject.enableBackgroundUpdates = true
                            expect(testContext.subject.enableBackgroundUpdates) == false
                        }
                    }
                }
                context("on a background enabled operating system") {
                    it("enables background updates") {
                        for operatingSystem in OperatingSystem.backgroundEnabledOperatingSystems {
                            testContext = TestContext(useStub: true, operatingSystem: operatingSystem, isDebugBuild: false)
                            testContext.subject.enableBackgroundUpdates = true
                            expect(testContext.subject.enableBackgroundUpdates) == true
                        }
                    }
                }
            }
        }
    }
}
