//
//  LDClientSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 11/13/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
import DarklyEventSource
@testable import Darkly

final class LDClientSpec: QuickSpec {
    struct Constants {
        fileprivate static let mockMobileKey = "mockMobileKey"
        fileprivate static let alternateMockUrl = URL(string: "https://dummy.alternate.com")!

        fileprivate static let newFlagKey = "LDClientSpec.newFlagKey"
        fileprivate static let newFlagValue = "LDClientSpec.newFlagValue"
    }

    struct BadFlagKeys {
        static let bool = "bool-flag-bad"
        static let int = "int-flag-bad"
        static let double = "double-flag-bad"
        static let string = "string-flag-bad"
        static let array = "array-flag-bad"
        static let dictionary = "dictionary-flag-bad"
    }

    struct DefaultFlagValues {
        static let bool = false
        static let int = 5
        static let double = 2.71828
        static let string = "default string value"
        static let array = [-1, -2]
        static let dictionary: [String: Any] = ["sub-flag-x": true, "sub-flag-y": 1, "sub-flag-z": 42.42]
    }

    struct TestContext {
        var config: LDConfig!
        var user: LDUser!
        var serviceFactoryMock: ClientServiceMockFactory! { return subject.serviceFactory as? ClientServiceMockFactory }
        var flagCacheMock: UserFlagCachingMock! { return serviceFactoryMock.userFlagCache }
        var flagStoreMock: FlagMaintainingMock! { return user.flagStore as? FlagMaintainingMock }
        var flagSynchronizerMock: LDFlagSynchronizingMock! { return subject.flagSynchronizer as? LDFlagSynchronizingMock }
        var eventReporterMock: LDEventReportingMock! { return subject.eventReporter as? LDEventReportingMock }
        var changeNotifierMock: FlagChangeNotifyingMock! { return subject.flagChangeNotifier as? FlagChangeNotifyingMock }
        var flagObserver: LDFlagObserver? { return changeNotifierMock.addObserverReceivedObserver }
        var flagChangeObserver: LDFlagChangeObserver? { return flagObserver?.flagChangeObserver }
        var flagCollectionChangeObserver: LDFlagCollectionChangeObserver? { return flagObserver?.flagCollectionChangeObserver }
        var onSyncComplete: SyncCompleteClosure? { return serviceFactoryMock.onSyncComplete }
        var replaceStoreComplete: CompletionClosure? { return flagStoreMock.replaceStoreReceivedArguments?.completion }
        var subject: LDClient!

        init(startOnline: Bool = false, runMode: LDClientRunMode = .foreground) {
            config = LDConfig.stub
            config.startOnline = startOnline
            config.eventFlushIntervalMillis = 300_000   //5 min...don't want this to trigger

            user = LDUser.stub()

            subject = LDClient.makeClient(with: ClientServiceMockFactory(), runMode: runMode)
        }
    }

    override func spec() {
        startSpec()
        setConfigSpec()
        setUserSpec()
        changeIsOnlineSpec()
        stopSpec()
        trackEventSpec()
        variationSpec()
        variationAndSourceSpec()
        observeSpec()
        onSyncCompleteSpec()

        //TODO: When implementing background mode, verify switching background modes affects the service objects
        //TODO: When the notification engine is installed, verify that an update to feature flags results in a notification of flags changed
    }

    func startSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext()
        }

        describe("start") {
            context("when configured to start online") {
                beforeEach {
                    testContext.config.startOnline = true

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                }
                it("takes the client and service objects online") {
                    expect(testContext.subject.isOnline) == true
                    expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                    expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                }
                it("saves the config") {
                    expect(testContext.subject.config) == testContext.config
                    expect(testContext.subject.service.config) == testContext.config
                    expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.streamingMode) == testContext.config.streamingMode
                        expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
                    }
                    expect(testContext.subject.eventReporter.config) == testContext.config
                }
                it("saves the user") {
                    expect(testContext.subject.user) == testContext.user
                    expect(testContext.subject.service.user) == testContext.user
                    expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service) === testContext.subject.service
                    }
                    expect(testContext.subject.eventReporter.service.user) == testContext.user
                }
            }
            context("when configured to start offline") {
                beforeEach {
                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                }
                it("leaves the client and service objects offline") {
                    expect(testContext.subject.isOnline) == false
                    expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                    expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                }
                it("saves the config") {
                    expect(testContext.subject.config) == testContext.config
                    expect(testContext.subject.service.config) == testContext.config
                    expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.streamingMode) == testContext.config.streamingMode
                        expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
                    }
                    expect(testContext.subject.eventReporter.config) == testContext.config
                }
                it("saves the user") {
                    expect(testContext.subject.user) == testContext.user
                    expect(testContext.subject.service.user) == testContext.user
                    expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service) === testContext.subject.service
                    }
                    expect(testContext.subject.eventReporter.service.user) == testContext.user
                }
            }
            context("when configured to allow background updates and running in background mode") {
                beforeEach {
                    testContext = TestContext(startOnline: true, runMode: .background)

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                }
                it("takes the client and service objects online") {
                    expect(testContext.subject.isOnline) == true
                    expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                    expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                }
                it("saves the config") {
                    expect(testContext.subject.config) == testContext.config
                    expect(testContext.subject.service.config) == testContext.config
                    expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.streamingMode) == LDStreamingMode.polling
                        expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == testContext.config.flagPollingInterval(runMode: .background)
                    }
                    expect(testContext.subject.eventReporter.config) == testContext.config
                }
                it("saves the user") {
                    expect(testContext.subject.user) == testContext.user
                    expect(testContext.subject.service.user) == testContext.user
                    expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service) === testContext.subject.service
                    }
                    expect(testContext.subject.eventReporter.service.user) == testContext.user
                }
            }
            context("when configured to not allow background updates and running in background mode") {
                beforeEach {
                    testContext = TestContext(startOnline: true, runMode: .background)
                    testContext.config.enableBackgroundUpdates = false

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                }
                it("leaves the client and service objects offline") {
                    expect(testContext.subject.isOnline) == false
                    expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                    expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                }
                it("saves the config") {
                    expect(testContext.subject.config) == testContext.config
                    expect(testContext.subject.service.config) == testContext.config
                    expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.streamingMode) == LDStreamingMode.polling
                        expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == testContext.config.flagPollingInterval(runMode: .foreground)
                    }
                    expect(testContext.subject.eventReporter.config) == testContext.config
                }
                it("saves the user") {
                    expect(testContext.subject.user) == testContext.user
                    expect(testContext.subject.service.user) == testContext.user
                    expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service.user) == testContext.user
                    }
                    expect(testContext.subject.eventReporter.service.user) == testContext.user
                }
            }
            context("when called more than once") {
                var newConfig: LDConfig!
                var newUser: LDUser!
                context("while online") {
                    beforeEach {
                        testContext.config.startOnline = true
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                        newConfig = testContext.subject.config
                        newConfig.baseUrl = Constants.alternateMockUrl

                        newUser = LDUser.stub()

                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: newConfig, user: newUser)
                    }
                    it("takes the client and service objects online") {
                        expect(testContext.subject.isOnline) == true
                        expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                        expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                    }
                    it("saves the config") {
                        expect(testContext.subject.config) == newConfig
                        expect(testContext.subject.service.config) == newConfig
                        expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.streamingMode) == newConfig.streamingMode
                            expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == newConfig.flagPollingInterval(runMode: testContext.subject.runMode)
                        }
                        expect(testContext.subject.eventReporter.config) == newConfig
                    }
                    it("saves the user") {
                        expect(testContext.subject.user) == newUser
                        expect(testContext.subject.service.user) == newUser
                        expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.service.user) == newUser
                        }
                        expect(testContext.subject.eventReporter.service.user) == newUser
                    }
                }
                context("while offline") {
                    beforeEach {
                        testContext.config.startOnline = false
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                        newConfig = testContext.subject.config
                        newConfig.baseUrl = Constants.alternateMockUrl

                        newUser = LDUser.stub()

                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: newConfig, user: newUser)
                    }
                    it("leaves the client and service objects offline") {
                        expect(testContext.subject.isOnline) == false
                        expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                        expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                    }
                    it("saves the config") {
                        expect(testContext.subject.config) == newConfig
                        expect(testContext.subject.service.config) == newConfig
                        expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.streamingMode) == newConfig.streamingMode
                            expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == newConfig.flagPollingInterval(runMode: testContext.subject.runMode)
                        }
                        expect(testContext.subject.eventReporter.config) == newConfig
                    }
                    it("saves the user") {
                        expect(testContext.subject.user) == newUser
                        expect(testContext.subject.service.user) == newUser
                        expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.service.user) == newUser
                        }
                        expect(testContext.subject.eventReporter.service.user) == newUser
                    }
                }
            }
            context("when called without config or user") {
                context("after setting config and user") {
                    beforeEach {
                        testContext.subject.config = testContext.config
                        testContext.subject.user = testContext.user
                        testContext.subject.start(mobileKey: Constants.mockMobileKey)
                    }
                    it("saves the config") {
                        expect(testContext.subject.config) == testContext.config
                        expect(testContext.subject.service.config) == testContext.config
                        expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.streamingMode) == testContext.config.streamingMode
                            expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
                        }
                        expect(testContext.subject.eventReporter.config) == testContext.config
                    }
                    it("saves the user") {
                        expect(testContext.subject.user) == testContext.user
                        expect(testContext.subject.service.user) == testContext.user
                        expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.service.user) == testContext.user
                        }
                        expect(testContext.subject.eventReporter.service.user) == testContext.user
                    }
                }
                context("without setting config or user") {
                    beforeEach {
                        testContext.subject.start(mobileKey: Constants.mockMobileKey)
                        testContext.config = testContext.subject.config
                        testContext.user = testContext.subject.user
                    }
                    it("saves the config") {
                        expect(testContext.subject.config) == testContext.config
                        expect(testContext.subject.service.config) == testContext.config
                        expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.streamingMode) == testContext.config.streamingMode
                            expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
                        }
                        expect(testContext.subject.eventReporter.config) == testContext.config
                    }
                    it("saves the user") {
                        expect(testContext.subject.user) == testContext.user
                        expect(testContext.subject.service.user) == testContext.user
                        expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.service.user) == testContext.user
                        }
                        expect(testContext.subject.eventReporter.service.user) == testContext.user
                    }
                }
            }
            context("when called with cached flags for the user") {
                var retrievedFlags: [LDFlagKey: FeatureFlag]!
                beforeEach {
                    testContext.flagCacheMock.retrieveFlagsReturnValue = CacheableUserFlags(user: testContext.user)
                    retrievedFlags = testContext.flagCacheMock.retrieveFlagsReturnValue!.flags
                    testContext.flagStoreMock.featureFlags = [:]

                    testContext.config.startOnline = false
                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                }
                it("checks the user flag cache for the user") {
                    expect(testContext.flagCacheMock.retrieveFlagsCallCount) == 1
                    expect(testContext.flagCacheMock.retrieveFlagsReceivedUser) == testContext.user
                }
                it("restores user flags from cache") {
                    expect(testContext.flagStoreMock.replaceStoreReceivedArguments?.newFlags == retrievedFlags).to(beTrue())
                }
            }
            context("when called without cached flags for the user") {
                beforeEach {
                    testContext.flagStoreMock.featureFlags = [:]

                    testContext.config.startOnline = false
                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                }
                it("checks the user flag cache for the user") {
                    expect(testContext.flagCacheMock.retrieveFlagsCallCount) == 1
                    expect(testContext.flagCacheMock.retrieveFlagsReceivedUser) == testContext.user
                }
                it("does not restore user flags from cache") {
                    expect(testContext.flagStoreMock.replaceStoreCallCount) == 0
                }
            }
        }
    }

    func setConfigSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext()
        }

        describe("set config") {
            var setIsOnlineCount: (flagSync: Int, event: Int) = (0, 0)
            context("when config values are the same") {
                beforeEach {
                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                    setIsOnlineCount = (testContext.flagSynchronizerMock.isOnlineSetCount, testContext.eventReporterMock.isOnlineSetCount)

                    testContext.subject.config = testContext.config
                }
                it("retains the config") {
                    expect(testContext.subject.config) == testContext.config
                }
                it("doesn't try to change service object isOnline state") {
                    expect(testContext.flagSynchronizerMock.isOnlineSetCount) == setIsOnlineCount.flagSync
                    expect(testContext.eventReporterMock.isOnlineSetCount) == setIsOnlineCount.event
                }
            }
            context("when config values differ") {
                var newConfig: LDConfig!
                beforeEach {
                    testContext.config.startOnline = true

                    newConfig = testContext.config
                    //change some values and check they're propagated to supporting objects
                    newConfig.baseUrl = Constants.alternateMockUrl
                    newConfig.pollIntervalMillis += 1
                    newConfig.eventFlushIntervalMillis += 1
                }
                context("with run mode set to foreground") {
                    beforeEach {
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                        testContext.subject.config = newConfig
                    }
                    it("changes to the new config values") {
                        expect(testContext.subject.config) == newConfig
                        expect(testContext.subject.service.config) == newConfig
                        expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.streamingMode) == newConfig.streamingMode
                            expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == newConfig.flagPollingInterval(runMode: testContext.subject.runMode)
                        }
                        expect(testContext.subject.eventReporter.config) == newConfig
                    }
                    it("leaves the client online") {
                        expect(testContext.subject.isOnline) == true
                        expect(testContext.flagSynchronizerMock.isOnline) == testContext.subject.isOnline
                        expect(testContext.eventReporterMock.isOnline) == testContext.subject.isOnline
                    }
                }
                context("with run mode set to background") {
                    beforeEach {
                        testContext = TestContext(startOnline: true, runMode: .background)
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                        testContext.subject.config = newConfig
                    }
                    it("changes to the new config values") {
                        expect(testContext.subject.config) == newConfig
                        expect(testContext.subject.service.config) == newConfig
                        expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.streamingMode) == LDStreamingMode.polling
                            expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == newConfig.flagPollingInterval(runMode: testContext.subject.runMode)
                        }
                        expect(testContext.subject.eventReporter.config) == newConfig
                    }
                    it("leaves the client online") {
                        expect(testContext.subject.isOnline) == true
                        expect(testContext.flagSynchronizerMock.isOnline) == testContext.subject.isOnline
                        expect(testContext.eventReporterMock.isOnline) == testContext.subject.isOnline
                    }
                }
            }
            context("when the client is offline") {
                var newConfig: LDConfig!
                beforeEach {
                    testContext.config.startOnline = false
                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    newConfig = testContext.config
                    //change some values and check they're propagated to supporting objects
                    newConfig.baseUrl = Constants.alternateMockUrl
                    newConfig.pollIntervalMillis += 1
                    newConfig.eventFlushIntervalMillis += 1

                    testContext.subject.config = newConfig
                }
                it("changes to the new config values") {
                    expect(testContext.subject.config) == newConfig
                    expect(testContext.subject.service.config) == newConfig
                    expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.streamingMode) == newConfig.streamingMode
                        expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == newConfig.flagPollingInterval(runMode: testContext.subject.runMode)
                    }
                    expect(testContext.subject.eventReporter.config) == newConfig
                }
                it("leaves the client offline") {
                    expect(testContext.subject.isOnline) == false
                    expect(testContext.flagSynchronizerMock.isOnline) == testContext.subject.isOnline
                    expect(testContext.eventReporterMock.isOnline) == testContext.subject.isOnline
                }
            }
            context("when the client is not started") {
                var newConfig: LDConfig!
                beforeEach {
                    newConfig = testContext.subject.config
                    //change some values and check they're propagated to supporting objects
                    newConfig.baseUrl = Constants.alternateMockUrl
                    newConfig.pollIntervalMillis += 1
                    newConfig.eventFlushIntervalMillis += 1

                    testContext.subject.config = newConfig
                }
                it("changes to the new config values") {
                    expect(testContext.subject.config) == newConfig
                    expect(testContext.subject.service.config) == newConfig
                    expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.streamingMode) == newConfig.streamingMode
                        expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == newConfig.flagPollingInterval(runMode: testContext.subject.runMode)
                    }
                    expect(testContext.subject.eventReporter.config) == newConfig
                }
                it("leaves the client offline") {
                    expect(testContext.subject.isOnline) == false
                    expect(testContext.flagSynchronizerMock.isOnline) == testContext.subject.isOnline
                    expect(testContext.eventReporterMock.isOnline) == testContext.subject.isOnline
                }
            }
        }
    }

    func setUserSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext()
        }

        describe("set user") {
            var newUser: LDUser!
            context("when the client is online") {
                beforeEach {
                    testContext.config.startOnline = true
                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    newUser = LDUser.stub()
                    testContext.subject.user = newUser
                }
                it("changes to the new user") {
                    expect(testContext.subject.user) == newUser
                    expect(testContext.subject.service.user) == newUser
                    expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service.user) == newUser
                    }
                    expect(testContext.subject.eventReporter.service.user) == newUser
                }
                it("leaves the client online") {
                    expect(testContext.subject.isOnline) == true
                    expect(testContext.subject.eventReporter.isOnline) == true
                    expect(testContext.subject.flagSynchronizer.isOnline) == true
                }
                it("records an identify event") {
                    expect(testContext.eventReporterMock.recordReceivedArguments?.event.kind == .identify).to(beTrue())
                }
            }
            context("when the client is offline") {
                beforeEach {
                    testContext.config.startOnline = false
                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    newUser = LDUser.stub()
                    testContext.subject.user = newUser
                }
                it("changes to the new user") {
                    expect(testContext.subject.user) == newUser
                    expect(testContext.subject.service.user) == newUser
                    expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service.user) == newUser
                    }
                    expect(testContext.subject.eventReporter.service.user) == newUser
                }
                it("leaves the client offline") {
                    expect(testContext.subject.isOnline) == false
                    expect(testContext.subject.eventReporter.isOnline) == false
                    expect(testContext.subject.flagSynchronizer.isOnline) == false
                }
                it("records an identify event") {
                    expect(testContext.eventReporterMock.recordReceivedArguments?.event.kind == .identify).to(beTrue())
                }
            }
            context("when the client is not started") {
                beforeEach {
                    newUser = LDUser.stub()
                    testContext.subject.user = newUser
                }
                it("changes to the new user") {
                    expect(testContext.subject.user) == newUser
                    expect(testContext.subject.service.user) == newUser
                    expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service.user) == newUser
                    }
                    expect(testContext.subject.eventReporter.service.user) == newUser
                }
                it("leaves the client offline") {
                    expect(testContext.subject.isOnline) == false
                    expect(testContext.subject.eventReporter.isOnline) == false
                    expect(testContext.subject.flagSynchronizer.isOnline) == false
                }
                it("does not record any event") {
                    expect(testContext.eventReporterMock.recordCallCount) == 0
                }
            }
        }
    }

    func changeIsOnlineSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext()
        }

        describe("change isOnline") {
            context("when the client is offline") {
                context("setting online") {
                    beforeEach {
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                        testContext.subject.isOnline = true
                    }
                    it("sets the client and service objects online") {
                        expect(testContext.subject.isOnline) == true
                        expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                        expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                    }
                }
            }
            context("when the client is online") {
                context("setting offline") {
                    beforeEach {
                        testContext.config.startOnline = true
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                        testContext.subject.isOnline = false
                    }
                    it("takes the client and service objects offline") {
                        expect(testContext.subject.isOnline) == false
                        expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                        expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                    }
                }
            }
            context("when the client has not been started") {
                beforeEach {
                    testContext.subject.isOnline = true
                }
                it("leaves the client and service objects offline") {
                    expect(testContext.subject.isOnline) == false
                    expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                    expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                }
            }
            context("when the client runs in the background") {
                beforeEach {
                    testContext = TestContext(runMode: .background)
                }
                context("while configured to enable background updates") {
                    beforeEach {
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                    }
                    context("and setting online") {
                        beforeEach {
                            testContext.subject.isOnline = true
                        }
                        it("takes the client and service objects online") {
                            expect(testContext.subject.isOnline) == true
                            expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                            expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                            if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                                expect(makeFlagSynchronizerReceivedParameters.streamingMode) == LDStreamingMode.polling
                                expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
                            }
                            expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                        }
                    }
                }
                context("while configured to disable background updates") {
                    beforeEach {
                        testContext.config.enableBackgroundUpdates = false
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                    }
                    context("and setting online") {
                        beforeEach {
                            testContext.subject.isOnline = true
                        }
                        it("leaves the client and service objects offline") {
                            expect(testContext.subject.isOnline) == false
                            expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                            expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                            if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                                expect(makeFlagSynchronizerReceivedParameters.streamingMode) == LDStreamingMode.polling
                                expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == testContext.config.flagPollingInterval(runMode: .foreground)
                            }

                            expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                        }
                    }
                }
            }
        }
    }

    func stopSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext()
        }

        describe("stop") {
            var event: Darkly.LDEvent!
            var priorRecordedEvents: Int!
            beforeEach {
                event = LDEvent.stub(for: .custom, with: testContext.user)
            }
            context("when started") {
                beforeEach {
                    priorRecordedEvents = 0
                }
                context("and online") {
                    beforeEach {
                        testContext.config.startOnline = true
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                        priorRecordedEvents = testContext.eventReporterMock.recordCallCount

                        testContext.subject.stop()
                    }
                    it("takes the client offline") {
                        expect(testContext.subject.isOnline) == false
                    }
                    it("stops recording events") {
                        testContext.subject.trackEvent(key: event.key)
                        expect(testContext.eventReporterMock.recordCallCount) == priorRecordedEvents
                    }
                }
                context("and offline") {
                    beforeEach {
                        testContext.config.startOnline = false
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                        priorRecordedEvents = testContext.eventReporterMock.recordCallCount

                        testContext.subject.stop()
                    }
                    it("leaves the client offline") {
                        expect(testContext.subject.isOnline) == false
                    }
                    it("stops recording events") {
                        testContext.subject.trackEvent(key: event.key)
                        expect(testContext.eventReporterMock.recordCallCount) == priorRecordedEvents
                    }
                }
            }
            context("when not yet started") {
                beforeEach {
                    testContext.subject.stop()
                }
                it("leaves the client offline") {
                    expect(testContext.subject.isOnline) == false
                }
                it("does not record events") {
                    testContext.subject.trackEvent(key: event.key)
                    expect(testContext.eventReporterMock.recordCallCount) == 0
                }
            }
            context("when already stopped") {
                beforeEach {
                    testContext.config.startOnline = false
                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                    testContext.subject.stop()
                    priorRecordedEvents = testContext.eventReporterMock.recordCallCount

                    testContext.subject.stop()
                }
                it("leaves the client offline") {
                    expect(testContext.subject.isOnline) == false
                }
                it("stops recording events") {
                    testContext.subject.trackEvent(key: event.key)
                    expect(testContext.eventReporterMock.recordCallCount) == priorRecordedEvents
                }
            }
        }
    }

    func trackEventSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext()
        }

        describe("track event") {
            var event: Darkly.LDEvent!
            beforeEach {
                event = LDEvent.stub(for: .custom, with: testContext.user)
            }
            context("when client was started") {
                beforeEach {
                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    testContext.subject.trackEvent(key: event.key, data: event.data)
                }
                it("records a custom event") {
                    expect(testContext.eventReporterMock.recordReceivedArguments?.event.key) == event.key
                    expect(testContext.eventReporterMock.recordReceivedArguments?.event.user) == event.user
                    expect(testContext.eventReporterMock.recordReceivedArguments?.event.data).toNot(beNil())
                    expect(testContext.eventReporterMock.recordReceivedArguments?.event.data == event.data).to(beTrue())
                }
            }
            context("when client was not started") {
                beforeEach {
                    testContext.subject.trackEvent(key: event.key, data: event.data)
                }
                it("does not record any events") {
                    expect(testContext.eventReporterMock.recordCallCount) == 0
                }
            }
            context("when client was stopped") {
                var priorRecordedEvents: Int!
                beforeEach {
                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                    testContext.subject.stop()
                    priorRecordedEvents = testContext.eventReporterMock.recordCallCount

                    testContext.subject.trackEvent(key: event.key, data: event.data)
                }
                it("does not record any more events") {
                    expect(testContext.eventReporterMock.recordCallCount) == priorRecordedEvents
                }
            }
        }
    }

    func variationSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext()
        }

        describe("variation") {
            context("flag store contains the requested value") {
                beforeEach {
                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                }
                it("returns the flag value") {
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool)) == DarklyServiceMock.FlagValues.bool
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.int, fallback: DefaultFlagValues.int)) == DarklyServiceMock.FlagValues.int
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.double, fallback: DefaultFlagValues.double)) == DarklyServiceMock.FlagValues.double
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.string, fallback: DefaultFlagValues.string)) == DarklyServiceMock.FlagValues.string
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.array, fallback: DefaultFlagValues.array) == DarklyServiceMock.FlagValues.array).to(beTrue())
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: DefaultFlagValues.dictionary) == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                }
            }
            context("flag store does not contain the requested value") {
                beforeEach {
                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                }
                it("returns the fallback value") {
                    expect(testContext.subject.variation(forKey: BadFlagKeys.bool, fallback: DefaultFlagValues.bool)) == DefaultFlagValues.bool
                    expect(testContext.subject.variation(forKey: BadFlagKeys.int, fallback: DefaultFlagValues.int)) == DefaultFlagValues.int
                    expect(testContext.subject.variation(forKey: BadFlagKeys.double, fallback: DefaultFlagValues.double)) == DefaultFlagValues.double
                    expect(testContext.subject.variation(forKey: BadFlagKeys.string, fallback: DefaultFlagValues.string)) == DefaultFlagValues.string
                    expect(testContext.subject.variation(forKey: BadFlagKeys.array, fallback: DefaultFlagValues.array) == DefaultFlagValues.array).to(beTrue())
                    expect(testContext.subject.variation(forKey: BadFlagKeys.dictionary, fallback: DefaultFlagValues.dictionary) == DefaultFlagValues.dictionary).to(beTrue())
                }
            }
        }
    }

    func variationAndSourceSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext()
        }

        describe("variation and source") {
            var arrayValue: (value: [Int], source: LDFlagValueSource)!
            var dictionaryValue: (value: [String: Any], source: LDFlagValueSource)!

            context("flag store contains the requested value") {
                beforeEach {
                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    arrayValue = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.array, fallback: DefaultFlagValues.array)
                    dictionaryValue = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: DefaultFlagValues.dictionary)
                }
                it("returns the flag value and source") {
                    expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool) == (DarklyServiceMock.FlagValues.bool, LDFlagValueSource.server)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.int, fallback: DefaultFlagValues.int) == (DarklyServiceMock.FlagValues.int, LDFlagValueSource.server)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.double, fallback: DefaultFlagValues.double) == (DarklyServiceMock.FlagValues.double, LDFlagValueSource.server)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.string, fallback: DefaultFlagValues.string) == (DarklyServiceMock.FlagValues.string, LDFlagValueSource.server)).to(beTrue())
                    expect(arrayValue.value == DarklyServiceMock.FlagValues.array).to(beTrue())
                    expect(arrayValue.source) == LDFlagValueSource.server
                    expect(dictionaryValue.value == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                    expect(dictionaryValue.source) == LDFlagValueSource.server
                }
            }
            context("flag store does not contain the requested value") {
                beforeEach {
                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    arrayValue = testContext.subject.variationAndSource(forKey: BadFlagKeys.array, fallback: DefaultFlagValues.array)
                    dictionaryValue = testContext.subject.variationAndSource(forKey: BadFlagKeys.dictionary, fallback: DefaultFlagValues.dictionary)
                }
                it("returns the fallback value and fallback source") {
                    expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.bool, fallback: DefaultFlagValues.bool) == (DefaultFlagValues.bool, LDFlagValueSource.fallback)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.int, fallback: DefaultFlagValues.int) == (DefaultFlagValues.int, LDFlagValueSource.fallback)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.double, fallback: DefaultFlagValues.double) == (DefaultFlagValues.double, LDFlagValueSource.fallback)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.string, fallback: DefaultFlagValues.string) == (DefaultFlagValues.string, LDFlagValueSource.fallback)).to(beTrue())
                    expect(arrayValue.value == DefaultFlagValues.array).to(beTrue())
                    expect(arrayValue.source) == LDFlagValueSource.fallback
                    expect(dictionaryValue.value == DefaultFlagValues.dictionary).to(beTrue())
                    expect(dictionaryValue.source) == LDFlagValueSource.fallback
                }
            }
        }
    }

    func observeSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext()
        }

        describe("observe") {
            var changedFlag: LDChangedFlag!
            var receivedChangedFlag: LDChangedFlag!

            beforeEach {
                testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                changedFlag = LDChangedFlag(key: DarklyServiceMock.FlagKeys.bool, oldValue: false, oldValueSource: .cache, newValue: true, newValueSource: .server)

                testContext.subject.observe(DarklyServiceMock.FlagKeys.bool, owner: self, observer: { (change) in
                    receivedChangedFlag = change
                })
            }
            it("registers a single flag observer") {
                expect(testContext.changeNotifierMock.addObserverCallCount) == 1
                expect(testContext.changeNotifierMock.addObserverReceivedObserver).toNot(beNil())
                expect(testContext.flagObserver?.flagKeys) == [DarklyServiceMock.FlagKeys.bool]
                expect(testContext.flagObserver?.owner) === self
                testContext.flagChangeObserver?(changedFlag)
                expect(receivedChangedFlag.key) == changedFlag.key
            }
        }

        describe("observeAll") {
            var changedFlags: [String: LDChangedFlag]!
            var receivedChangedFlags: [String: LDChangedFlag]!
            beforeEach {
                testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                changedFlags = [DarklyServiceMock.FlagKeys.bool: LDChangedFlag(key: DarklyServiceMock.FlagKeys.bool, oldValue: false, oldValueSource: .cache, newValue: true, newValueSource: .server)]

                testContext.subject.observeAll(owner: self, observer: { (changes) in
                    receivedChangedFlags = changes
                })
            }
            it("registers a collection flag observer") {
                expect(testContext.changeNotifierMock.addObserverCallCount) == 1
                expect(testContext.flagObserver?.flagKeys) == LDFlagKey.anyKey
                expect(testContext.flagObserver?.owner) === self
                expect(testContext.flagObserver?.flagCollectionChangeObserver).toNot(beNil())
                testContext.flagCollectionChangeObserver?(changedFlags)
                expect(receivedChangedFlags.keys == changedFlags.keys).to(beTrue())
            }
        }

        describe("stopObserving") {
            beforeEach {
                testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                testContext.subject.stopObserving(owner: self)
            }
            it("unregisters the owner") {
                expect(testContext.changeNotifierMock.removeObserverCallCount) == 1
                expect(testContext.changeNotifierMock.removeObserverReceivedArguments?.owner) === self
            }
        }
    }

    func onSyncCompleteSpec() {
        describe("on sync complete") {
            onSyncCompleteSuccessSpec()
            onSyncCompleteErrorSpec()
        }
    }

    func onSyncCompleteSuccessSpec() {
        context("polling") {
            onSyncCompleteSuccess(streamingMode: .polling)
        }
        context("streaming ping") {
            onSyncCompleteSuccess(streamingMode: .streaming, eventType: .ping)
        }
        context("streaming put") {
            onSyncCompleteSuccess(streamingMode: .streaming, eventType: .put)
        }
    }

    func onSyncCompleteSuccess(streamingMode: LDStreamingMode, eventType: DarklyEventSource.LDEvent.EventType? = nil) {
        var testContext: TestContext!
        var oldFlags: [String: Any]!
        var newFlags: [String: Any]!
        var eventType: DarklyEventSource.LDEvent.EventType?

        beforeEach {
            testContext = TestContext(startOnline: true)
            eventType = streamingMode == .streaming ? eventType : nil
        }

        context("flags have different values") {
            beforeEach {
                oldFlags = testContext.user.flagStore.featureFlags
                newFlags = testContext.user.flagStore.featureFlags
                newFlags[DarklyServiceMock.FlagKeys.bool] = !DarklyServiceMock.FlagValues.bool

                testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                testContext.onSyncComplete?(.success(newFlags, eventType))
                if testContext.flagStoreMock.replaceStoreCallCount > 0 { testContext.replaceStoreComplete?() }
            }
            it("updates the flag store") {
                expect(testContext.flagStoreMock.replaceStoreCallCount) == 1
                expect(testContext.flagStoreMock.replaceStoreReceivedArguments?.newFlags == newFlags).to(beTrue())
            }
            it("caches the new flags") {
                expect(testContext.flagCacheMock.cacheFlagsCallCount) == 1
                expect(testContext.flagCacheMock.cacheFlagsReceivedUser) == testContext.user
            }
            it("informs the flag change notifier of the changed flags") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.changedFlags.isEmpty).toNot(beTrue())
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.changedFlags) == oldFlags.symmetricDifference(newFlags)
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == oldFlags).to(beTrue())
            }
        }
        context("a flag was added") {
            beforeEach {
                oldFlags = testContext.user.flagStore.featureFlags
                newFlags = testContext.user.flagStore.featureFlags
                newFlags[Constants.newFlagKey] = Constants.newFlagValue

                testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                testContext.onSyncComplete?(.success(newFlags, eventType))
                if testContext.flagStoreMock.replaceStoreCallCount > 0 { testContext.replaceStoreComplete?() }
            }
            it("updates the flag store") {
                expect(testContext.flagStoreMock.replaceStoreCallCount) == 1
                expect(testContext.flagStoreMock.replaceStoreReceivedArguments?.newFlags == newFlags).to(beTrue())
            }
            it("caches the new flags") {
                expect(testContext.flagCacheMock.cacheFlagsCallCount) == 1
                expect(testContext.flagCacheMock.cacheFlagsReceivedUser) == testContext.user
            }
            it("informs the flag change notifier of the changed flags") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.changedFlags.isEmpty).toNot(beTrue())
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.changedFlags) == oldFlags.symmetricDifference(newFlags)
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == oldFlags).to(beTrue())
            }
        }
        context("a flag was removed") {
            beforeEach {
                oldFlags = testContext.user.flagStore.featureFlags
                newFlags = testContext.user.flagStore.featureFlags
                newFlags.removeValue(forKey: DarklyServiceMock.FlagKeys.dictionary)

                testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                testContext.onSyncComplete?(.success(newFlags, eventType))
                if testContext.flagStoreMock.replaceStoreCallCount > 0 { testContext.replaceStoreComplete?() }
            }
            it("updates the flag store") {
                expect(testContext.flagStoreMock.replaceStoreCallCount) == 1
                expect(testContext.flagStoreMock.replaceStoreReceivedArguments?.newFlags == newFlags).to(beTrue())
            }
            it("caches the new flags") {
                expect(testContext.flagCacheMock.cacheFlagsCallCount) == 1
                expect(testContext.flagCacheMock.cacheFlagsReceivedUser) == testContext.user
            }
            it("informs the flag change notifier of the changed flags") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.changedFlags.isEmpty).toNot(beTrue())
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.changedFlags) == oldFlags.symmetricDifference(newFlags)
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == oldFlags).to(beTrue())
            }
        }
        context("there were no changes to the flags") {
            beforeEach {
                oldFlags = testContext.user.flagStore.featureFlags
                newFlags = testContext.user.flagStore.featureFlags

                testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                testContext.onSyncComplete?(.success(newFlags, eventType))
                if testContext.flagStoreMock.replaceStoreCallCount > 0 { testContext.replaceStoreComplete?() }
            }
            it("does not update the flag store") {
                expect(testContext.flagStoreMock.replaceStoreCallCount) == 0
            }
            it("does not cache the new flags") {
                expect(testContext.flagCacheMock.cacheFlagsCallCount) == 0
            }
            it("calls the flags unchanged closure") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 0
            }
        }
    }

    func onSyncCompleteErrorSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext(startOnline: true)
        }

        context("there was an internal server error") {
            var serverUnavailableCalled: Bool! = false
            beforeEach {
                waitUntil { done in
                    testContext.subject.onServerUnavailable = {
                        serverUnavailableCalled = true
                        done()
                    }

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.error(.response(HTTPURLResponse(url: testContext.config.baseUrl, statusCode: HTTPURLResponse.StatusCodes.internalServerError, httpVersion: DarklyServiceMock.Constants.httpVersion, headerFields: nil))))
                }
            }
            it("does not take the client offline") {
                expect(testContext.subject.isOnline) == true
            }
            it("calls the server unavailable closure") {
                expect(serverUnavailableCalled) == true
            }
        }
        context("there was a request error") {
            var serverUnavailableCalled: Bool! = false
            beforeEach {
                waitUntil { done in
                    testContext.subject.onServerUnavailable = {
                        serverUnavailableCalled = true
                        done()
                    }

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.error(.request(DarklyServiceMock.Constants.error)))
                }
            }
            it("does not take the client offline") {
                expect(testContext.subject.isOnline) == true
            }
            it("calls the server unavailable closure") {
                expect(serverUnavailableCalled) == true
            }
        }
        context("there was a data error") {
            var serverUnavailableCalled: Bool! = false
            beforeEach {
                waitUntil { done in
                    testContext.subject.onServerUnavailable = {
                        serverUnavailableCalled = true
                        done()
                    }

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.error(.data(DarklyServiceMock.Constants.errorData)))
                }
            }
            it("does not take the client offline") {
                expect(testContext.subject.isOnline) == true
            }
            it("calls the server unavailable closure") {
                expect(serverUnavailableCalled) == true
            }
        }
        context("there was a client unauthorized error") {
            var serverUnavailableCalled: Bool! = false
            beforeEach {
                waitUntil { done in
                    testContext.subject.onServerUnavailable = {
                        serverUnavailableCalled = true
                        done()
                    }

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.error(.response(HTTPURLResponse(url: testContext.config.baseUrl, statusCode: HTTPURLResponse.StatusCodes.unauthorized, httpVersion: DarklyServiceMock.Constants.httpVersion, headerFields: nil))))
                }
            }
            it("takes the client offline") {
                expect(testContext.subject.isOnline) == false
            }
            it("calls the server unavailable closure") {
                expect(serverUnavailableCalled) == true
            }
        }
    }
}
