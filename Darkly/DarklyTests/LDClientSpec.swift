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
@testable import LaunchDarkly

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
        var subject: LDClient!
        // mock getters based on setting up the user & subject
        var serviceFactoryMock: ClientServiceMockFactory! { return subject.serviceFactory as? ClientServiceMockFactory }
        var flagCacheMock: UserFlagCachingMock! { return serviceFactoryMock.userFlagCache }
        var flagStoreMock: FlagMaintainingMock! { return user.flagStore as? FlagMaintainingMock }
        var flagSynchronizerMock: LDFlagSynchronizingMock! { return subject.flagSynchronizer as? LDFlagSynchronizingMock }
        var eventReporterMock: EventReportingMock! { return subject.eventReporter as? EventReportingMock }
        var changeNotifierMock: FlagChangeNotifyingMock! { return subject.flagChangeNotifier as? FlagChangeNotifyingMock }
        var environmentReporterMock: EnvironmentReportingMock! { return subject.environmentReporter as? EnvironmentReportingMock }
        // makeFlagSynchronizer getters
        var makeFlagSynchronizerStreamingMode: LDStreamingMode? { return serviceFactoryMock.makeFlagSynchronizerReceivedParameters?.streamingMode }
        var makeFlagSynchronizerPollingInterval: TimeInterval? { return serviceFactoryMock.makeFlagSynchronizerReceivedParameters?.pollingInterval }
        var makeFlagSynchronizerService: DarklyServiceProvider? { return serviceFactoryMock.makeFlagSynchronizerReceivedParameters?.service }
        // flag observing getters
        var flagChangeObserver: FlagChangeObserver? { return changeNotifierMock.addFlagChangeObserverReceivedObserver }
        var flagChangeHandler: LDFlagChangeHandler? { return flagChangeObserver?.flagChangeHandler }
        var flagCollectionChangeHandler: LDFlagCollectionChangeHandler? { return flagChangeObserver?.flagCollectionChangeHandler }
        var flagsUnchangedCallCount = 0
        var flagsUnchangedObserver: FlagsUnchangedObserver? { return changeNotifierMock?.addFlagsUnchangedObserverReceivedObserver }
        var flagsUnchangedHandler: LDFlagsUnchangedHandler? { return flagsUnchangedObserver?.flagsUnchangedHandler }
        var onSyncComplete: SyncCompleteClosure? { return serviceFactoryMock.onSyncComplete }
        // flag maintaining mock accessors
        var replaceStoreComplete: CompletionClosure? { return flagStoreMock.replaceStoreReceivedArguments?.completion }
        var updateStoreComplete: CompletionClosure? { return flagStoreMock.updateStoreReceivedArguments?.completion }
        var deleteFlagComplete: CompletionClosure? { return flagStoreMock.deleteFlagReceivedArguments?.completion }
        var recordedEvent: LaunchDarkly.Event? { return eventReporterMock.recordReceivedArguments?.event }
        // user flags
        var oldFlags: [LDFlagKey: FeatureFlag]!
        var oldFlagSource: LDFlagValueSource!
        // throttler
        var throttlerMock: ThrottlingMock? { return subject.throttler as? ThrottlingMock }

        init(startOnline: Bool = false,
             streamingMode: LDStreamingMode = .streaming,
             enableBackgroundUpdates: Bool = true,
             runMode: LDClientRunMode = .foreground,
             operatingSystem: OperatingSystem? = nil) {

            let clientServiceFactory = ClientServiceMockFactory()
            if let operatingSystem = operatingSystem { clientServiceFactory.makeEnvironmentReporterReturnValue.operatingSystem = operatingSystem }

            config = LDConfig.stub(environmentReporter: clientServiceFactory.makeEnvironmentReporterReturnValue)
            config.startOnline = startOnline
            config.streamingMode = streamingMode
            config.enableBackgroundUpdates = enableBackgroundUpdates
            config.eventFlushIntervalMillis = 300_000   //5 min...don't want this to trigger

            user = LDUser.stub()
            oldFlags = user.flagStore.featureFlags
            oldFlagSource = user.flagStore.flagValueSource

            subject = LDClient.makeClient(with: clientServiceFactory, runMode: runMode)
            subject.config = config
            subject.user = user

            self.flagCacheMock.reset()
            self.setFlagStoreCallbackToMimicRealFlagStore()

            setThrottlerToExecuteRunClosure()
        }

        ///Pass nil to leave the flags unchanged
        func setFlagStoreCallbackToMimicRealFlagStore(newFlags: [LDFlagKey: FeatureFlag]? = nil) {
            flagStoreMock.replaceStoreCallback = {
                self.flagStoreMock!.featureFlags = newFlags ?? self.flagStoreMock!.featureFlags
            }
            flagStoreMock.updateStoreCallback = {
                self.flagStoreMock!.featureFlags = newFlags ?? self.flagStoreMock!.featureFlags
            }
            flagStoreMock.deleteFlagCallback = {
                self.flagStoreMock!.featureFlags = newFlags ?? self.flagStoreMock!.featureFlags
            }
        }

        func setThrottlerToExecuteRunClosure() {
            throttlerMock?.runThrottledCallback = {
                self.throttlerMock?.runThrottledReceivedRunClosure?()
            }
        }
    }

    override func spec() {
        startSpec()
        setConfigSpec()
        setUserSpec()
        setOnlineSpec()
        stopSpec()
        trackEventSpec()
        variationSpec()
        variationAndSourceSpec()
        observeSpec()
        onSyncCompleteSpec()
        runModeSpec()
        streamingModeSpec()
    }

    private func startSpec() {
        describe("start") {
            var testContext: TestContext!

            context("when configured to start online") {
                beforeEach {
                    testContext = TestContext()
                    testContext.config.startOnline = true

                    waitUntil { done in
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user, completion: done)
                    }
                }
                it("takes the client and service objects online") {
                    expect(testContext.subject.isOnline) == true
                    expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                    expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                }
                it("saves the config") {
                    expect(testContext.subject.config) == testContext.config
                    expect(testContext.subject.service.config) == testContext.config
                    expect(testContext.makeFlagSynchronizerStreamingMode) == testContext.config.streamingMode
                    expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
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
                it("records an identify event") {
                    expect(testContext.eventReporterMock.recordCallCount) == 1
                    expect(testContext.recordedEvent?.kind) == .identify
                    expect(testContext.recordedEvent?.key) == testContext.user.key
                }
            }
            context("when configured to start offline") {
                beforeEach {
                    testContext = TestContext()
                    waitUntil { done in
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user, completion: done)
                    }
                }
                it("leaves the client and service objects offline") {
                    expect(testContext.subject.isOnline) == false
                    expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                    expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                }
                it("saves the config") {
                    expect(testContext.subject.config) == testContext.config
                    expect(testContext.subject.service.config) == testContext.config
                    expect(testContext.makeFlagSynchronizerStreamingMode) == testContext.config.streamingMode
                    expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
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
                it("records an identify event") {
                    expect(testContext.eventReporterMock.recordCallCount) == 1
                    expect(testContext.recordedEvent?.kind) == .identify
                    expect(testContext.recordedEvent?.key) == testContext.user.key
                }
            }
            context("when configured to allow background updates and running in background mode") {
                beforeEach {
                    testContext = TestContext(startOnline: true, runMode: .background)

                    waitUntil { done in
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user, completion: done)
                    }
                }
                it("takes the client and service objects online") {
                    expect(testContext.subject.isOnline) == true
                    expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                    expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                }
                it("saves the config") {
                    expect(testContext.subject.config) == testContext.config
                    expect(testContext.subject.service.config) == testContext.config
                    expect(testContext.makeFlagSynchronizerStreamingMode) == LDStreamingMode.polling
                    expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: .background)
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
                it("records an identify event") {
                    expect(testContext.eventReporterMock.recordCallCount) == 1
                    expect(testContext.recordedEvent?.kind) == .identify
                    expect(testContext.recordedEvent?.key) == testContext.user.key
                }
            }
            context("when configured to not allow background updates and running in background mode") {
                beforeEach {
                    testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, runMode: .background)
                    testContext.config.enableBackgroundUpdates = false

                    waitUntil { done in
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user, completion: done)
                    }
                }
                it("leaves the client and service objects offline") {
                    expect(testContext.subject.isOnline) == false
                    expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                    expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                }
                it("saves the config") {
                    expect(testContext.subject.config) == testContext.config
                    expect(testContext.subject.service.config) == testContext.config
                    expect(testContext.makeFlagSynchronizerStreamingMode) == LDStreamingMode.polling
                    expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: .background)
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
                it("records an identify event") {
                    expect(testContext.eventReporterMock.recordCallCount) == 1
                    expect(testContext.recordedEvent?.kind) == .identify
                    expect(testContext.recordedEvent?.key) == testContext.user.key
                }
            }
            context("when called more than once") {
                var newConfig: LDConfig!
                var newUser: LDUser!
                context("while online") {
                    beforeEach {
                        testContext = TestContext()
                        testContext.config.startOnline = true
                        waitUntil { done in
                            testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user, completion: done)
                        }

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
                        expect(testContext.makeFlagSynchronizerStreamingMode) == newConfig.streamingMode
                        expect(testContext.makeFlagSynchronizerPollingInterval) == newConfig.flagPollingInterval(runMode: testContext.subject.runMode)
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
                    it("records an identify event") {
                        expect(testContext.eventReporterMock.recordCallCount) == 2
                        expect(testContext.recordedEvent?.kind) == .identify
                        expect(testContext.recordedEvent?.key) == newUser.key
                    }
                }
                context("while offline") {
                    beforeEach {
                        testContext = TestContext()
                        testContext.config.startOnline = false
                        waitUntil { done in
                            testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user, completion: done)
                        }

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
                        expect(testContext.makeFlagSynchronizerStreamingMode) == newConfig.streamingMode
                        expect(testContext.makeFlagSynchronizerPollingInterval) == newConfig.flagPollingInterval(runMode: testContext.subject.runMode)
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
                    it("records an identify event") {
                        expect(testContext.eventReporterMock.recordCallCount) == 2
                        expect(testContext.recordedEvent?.kind) == .identify
                        expect(testContext.recordedEvent?.key) == newUser.key
                    }
                }
            }
            context("when called without config or user") {
                context("after setting config and user") {
                    beforeEach {
                        testContext = TestContext()
                        testContext.subject.config = testContext.config
                        testContext.subject.user = testContext.user
                        waitUntil { done in
                            testContext.subject.start(mobileKey: Constants.mockMobileKey, completion: done)
                        }
                    }
                    it("saves the config") {
                        expect(testContext.subject.config) == testContext.config
                        expect(testContext.subject.service.config) == testContext.config
                        expect(testContext.makeFlagSynchronizerStreamingMode) == testContext.config.streamingMode
                        expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
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
                    it("records an identify event") {
                        expect(testContext.eventReporterMock.recordCallCount) == 1
                        expect(testContext.recordedEvent?.kind) == .identify
                        expect(testContext.recordedEvent?.key) == testContext.user.key
                    }
                }
                context("without setting config or user") {
                    beforeEach {
                        testContext = TestContext()
                        waitUntil { done in
                            testContext.subject.start(mobileKey: Constants.mockMobileKey, completion: done)
                        }
                        testContext.config = testContext.subject.config
                        testContext.user = testContext.subject.user
                    }
                    it("saves the config") {
                        expect(testContext.subject.config) == testContext.config
                        expect(testContext.subject.service.config) == testContext.config
                        expect(testContext.makeFlagSynchronizerStreamingMode) == testContext.config.streamingMode
                        expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
                        expect(testContext.subject.eventReporter.config) == testContext.config
                    }
                    it("saves the user") {
                        expect(testContext.subject.user) == testContext.user
                        expect(testContext.subject.service.user) == testContext.user
                        expect(testContext.makeFlagSynchronizerService?.user) == testContext.user
                        expect(testContext.subject.eventReporter.service.user) == testContext.user
                    }
                    it("records an identify event") {
                        expect(testContext.eventReporterMock.recordCallCount) == 1
                        expect(testContext.recordedEvent?.kind) == .identify
                        expect(testContext.recordedEvent?.key) == testContext.user.key
                    }
                }
            }
            context("when called with cached flags for the user") {
                var retrievedFlags: [LDFlagKey: FeatureFlag]!
                beforeEach {
                    testContext = TestContext()
                    testContext.flagCacheMock.retrieveFlagsReturnValue = CacheableUserFlags(user: testContext.user)
                    retrievedFlags = testContext.flagCacheMock.retrieveFlagsReturnValue!.flags
                    testContext.flagStoreMock.featureFlags = [:]

                    testContext.config.startOnline = false
                    waitUntil { done in
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user, completion: done)
                    }
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
                    testContext = TestContext()
                    testContext.flagStoreMock.featureFlags = [:]

                    testContext.config.startOnline = false
                    waitUntil { done in
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user, completion: done)
                    }
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

    private func setConfigSpec() {
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
                        expect(testContext.makeFlagSynchronizerStreamingMode) == newConfig.streamingMode
                        expect(testContext.makeFlagSynchronizerPollingInterval) == newConfig.flagPollingInterval(runMode: testContext.subject.runMode)
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
                        expect(testContext.makeFlagSynchronizerStreamingMode) == LDStreamingMode.polling
                        expect(testContext.makeFlagSynchronizerPollingInterval) == newConfig.flagPollingInterval(runMode: testContext.subject.runMode)
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
                    expect(testContext.makeFlagSynchronizerStreamingMode) == newConfig.streamingMode
                    expect(testContext.makeFlagSynchronizerPollingInterval) == newConfig.flagPollingInterval(runMode: testContext.subject.runMode)
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
                    expect(testContext.makeFlagSynchronizerStreamingMode) == newConfig.streamingMode
                    expect(testContext.makeFlagSynchronizerPollingInterval) == newConfig.flagPollingInterval(runMode: testContext.subject.runMode)
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

    private func setUserSpec() {
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
                    expect(testContext.makeFlagSynchronizerService?.user) == newUser
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
                    expect(testContext.makeFlagSynchronizerService?.user) == newUser
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
                    expect(testContext.makeFlagSynchronizerService?.user) == newUser
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

    private func setOnlineSpec() {
        describe("setOnline") {
            var testContext: TestContext!

            beforeEach {
                testContext = TestContext()
            }
            context("when the client is offline") {
                context("setting online") {
                    beforeEach {
                        testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                        waitUntil { done in
                            testContext.subject.setOnline(true) {
                                done()
                            }
                        }
                    }
                    it("sets the client and service objects online") {
                        expect(testContext.throttlerMock?.runThrottledCallCount ?? 0) == 1
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
                        testContext.throttlerMock?.runThrottledCallCount = 0

                        testContext.subject.setOnline(false)
                    }
                    it("takes the client and service objects offline") {
                        expect(testContext.throttlerMock?.runThrottledCallCount ?? 0) == 0
                        expect(testContext.subject.isOnline) == false
                        expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                        expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                    }
                }
            }
            context("when the client has not been started") {
                beforeEach {
                    testContext.subject.setOnline(true)
                }
                it("leaves the client and service objects offline") {
                    expect(testContext.throttlerMock?.runThrottledCallCount ?? 0) == 0
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
                            waitUntil { done in
                                testContext.subject.setOnline(true) {
                                    done()
                                }
                            }
                        }
                        it("takes the client and service objects online") {
                            expect(testContext.throttlerMock?.runThrottledCallCount ?? 0) == 1
                            expect(testContext.subject.isOnline) == true
                            expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                            expect(testContext.makeFlagSynchronizerStreamingMode) == LDStreamingMode.polling
                            expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
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
                            testContext.subject.setOnline(true)
                        }
                        it("leaves the client and service objects offline") {
                            expect(testContext.throttlerMock?.runThrottledCallCount ?? 0) == 0
                            expect(testContext.subject.isOnline) == false
                            expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                            expect(testContext.makeFlagSynchronizerStreamingMode) == LDStreamingMode.polling
                            expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: .background)

                            expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                        }
                    }
                }
            }
        }
    }

    private func stopSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext()
        }

        describe("stop") {
            var event: LaunchDarkly.Event!
            var priorRecordedEvents: Int!
            beforeEach {
                event = Event.stub(.custom, with: testContext.user)
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

    private func trackEventSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext()
        }

        describe("track event") {
            var event: LaunchDarkly.Event!
            beforeEach {
                event = Event.stub(.custom, with: testContext.user)
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

    private func variationSpec() {
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
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: DefaultFlagValues.dictionary)
                        == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                }
                it("records a flag request event") {
                    _ = testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool)
                    expect(testContext.eventReporterMock.recordCallCount) == 2  //the first event comes from the start call
                    expect(testContext.recordedEvent?.kind) == .feature
                    expect(testContext.recordedEvent?.key) == DarklyServiceMock.FlagKeys.bool
                    expect(AnyComparer.isEqual(testContext.recordedEvent?.value, to: DarklyServiceMock.FlagValues.bool)).to(beTrue())
                    expect(AnyComparer.isEqual(testContext.recordedEvent?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
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
                it("records a flag request event") {
                    _ = testContext.subject.variation(forKey: BadFlagKeys.bool, fallback: DefaultFlagValues.bool)
                    expect(testContext.eventReporterMock.recordCallCount) == 2  //the first event comes from the start call
                    expect(testContext.recordedEvent?.kind) == .feature
                    expect(testContext.recordedEvent?.key) == BadFlagKeys.bool
                    expect(AnyComparer.isEqual(testContext.recordedEvent?.value, to: DefaultFlagValues.bool)).to(beTrue())
                    expect(AnyComparer.isEqual(testContext.recordedEvent?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                }
            }
            context("when it hasnt started") {
                beforeEach {
                    testContext = TestContext(startOnline: false)
                }
                it("returns the fallback value") {
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool)) == DefaultFlagValues.bool
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.int, fallback: DefaultFlagValues.int)) == DefaultFlagValues.int
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.double, fallback: DefaultFlagValues.double)) == DefaultFlagValues.double
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.string, fallback: DefaultFlagValues.string)) == DefaultFlagValues.string
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.array, fallback: DefaultFlagValues.array) == DefaultFlagValues.array).to(beTrue())
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: DefaultFlagValues.dictionary) == DefaultFlagValues.dictionary).to(beTrue())
                }
                it("does not record a flag request event") {
                    _ = testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool)
                    expect(testContext.eventReporterMock.recordCallCount) == 0
                }
            }
        }
    }

    private func variationAndSourceSpec() {
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
                }
                it("returns the flag value and source") {
                    expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool)
                        == (DarklyServiceMock.FlagValues.bool, LDFlagValueSource.server)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.int, fallback: DefaultFlagValues.int)
                        == (DarklyServiceMock.FlagValues.int, LDFlagValueSource.server)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.double, fallback: DefaultFlagValues.double)
                        == (DarklyServiceMock.FlagValues.double, LDFlagValueSource.server)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.string, fallback: DefaultFlagValues.string) == (DarklyServiceMock.FlagValues.string, LDFlagValueSource.server)).to(beTrue())
                    arrayValue = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.array, fallback: DefaultFlagValues.array)
                    expect(arrayValue.value == DarklyServiceMock.FlagValues.array).to(beTrue())
                    expect(arrayValue.source) == LDFlagValueSource.server
                    dictionaryValue = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: DefaultFlagValues.dictionary)
                    expect(dictionaryValue.value == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                    expect(dictionaryValue.source) == LDFlagValueSource.server
                }
                it("records a flag request event") {
                    _ = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool)
                    expect(testContext.eventReporterMock.recordCallCount) == 2  //the first event comes from the start call
                    expect(testContext.recordedEvent?.kind) == .feature
                    expect(testContext.recordedEvent?.key) == DarklyServiceMock.FlagKeys.bool
                    expect(AnyComparer.isEqual(testContext.recordedEvent?.value, to: DarklyServiceMock.FlagValues.bool)).to(beTrue())
                    expect(AnyComparer.isEqual(testContext.recordedEvent?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                }
            }
            context("flag store does not contain the requested value") {
                beforeEach {
                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                }
                it("returns the fallback value and fallback source") {
                    expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.bool, fallback: DefaultFlagValues.bool) == (DefaultFlagValues.bool, .fallback)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.int, fallback: DefaultFlagValues.int) == (DefaultFlagValues.int, .fallback)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.double, fallback: DefaultFlagValues.double) == (DefaultFlagValues.double, .fallback)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.string, fallback: DefaultFlagValues.string) == (DefaultFlagValues.string, .fallback)).to(beTrue())
                    arrayValue = testContext.subject.variationAndSource(forKey: BadFlagKeys.array, fallback: DefaultFlagValues.array)
                    expect(arrayValue.value == DefaultFlagValues.array).to(beTrue())
                    expect(arrayValue.source) == LDFlagValueSource.fallback
                    dictionaryValue = testContext.subject.variationAndSource(forKey: BadFlagKeys.dictionary, fallback: DefaultFlagValues.dictionary)
                    expect(dictionaryValue.value == DefaultFlagValues.dictionary).to(beTrue())
                    expect(dictionaryValue.source) == LDFlagValueSource.fallback
                }
                it("records a flag request event") {
                    _ = testContext.subject.variationAndSource(forKey: BadFlagKeys.bool, fallback: DefaultFlagValues.bool)
                    expect(testContext.eventReporterMock.recordCallCount) == 2  //the first event comes from the start call
                    expect(testContext.recordedEvent?.kind) == .feature
                    expect(testContext.recordedEvent?.key) == BadFlagKeys.bool
                    expect(AnyComparer.isEqual(testContext.recordedEvent?.value, to: DefaultFlagValues.bool)).to(beTrue())
                    expect(AnyComparer.isEqual(testContext.recordedEvent?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                }
            }
            context("when it hasnt started") {
                beforeEach {
                    testContext = TestContext(startOnline: false)
                }
                it("returns the fallback value and fallback source") {
                    expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.bool, fallback: DefaultFlagValues.bool) == (DefaultFlagValues.bool, .fallback)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.int, fallback: DefaultFlagValues.int) == (DefaultFlagValues.int, LDFlagValueSource.fallback)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.double, fallback: DefaultFlagValues.double)
                        == (DefaultFlagValues.double, LDFlagValueSource.fallback)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.string, fallback: DefaultFlagValues.string)
                        == (DefaultFlagValues.string, LDFlagValueSource.fallback)).to(beTrue())
                    expect(arrayValue.value == DefaultFlagValues.array).to(beTrue())
                    expect(arrayValue.source) == LDFlagValueSource.fallback
                    expect(dictionaryValue.value == DefaultFlagValues.dictionary).to(beTrue())
                    expect(dictionaryValue.source) == LDFlagValueSource.fallback
                }
                it("does not record a flag request event") {
                    _ = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool)
                    expect(testContext.eventReporterMock.recordCallCount) == 0
                }
            }
        }
    }

    private func observeSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext()
        }

        describe("observe") {
            var changedFlag: LDChangedFlag!
            var receivedChangedFlag: LDChangedFlag?

            beforeEach {
                testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                changedFlag = LDChangedFlag(key: DarklyServiceMock.FlagKeys.bool, oldValue: false, oldValueSource: .cache, newValue: true, newValueSource: .server)

                testContext.subject.observe(DarklyServiceMock.FlagKeys.bool, owner: self, handler: { (change) in
                    receivedChangedFlag = change
                })
            }
            it("registers a single flag observer") {
                expect(testContext.changeNotifierMock.addFlagChangeObserverCallCount) == 1
                expect(testContext.flagChangeObserver?.flagKeys) == [DarklyServiceMock.FlagKeys.bool]
                expect(testContext.flagChangeObserver?.owner) === self
                testContext.flagChangeHandler?(changedFlag)
                expect(receivedChangedFlag?.key) == changedFlag.key
            }
        }

        describe("observeKeys") {
            var changedFlags: [LDFlagKey: LDChangedFlag]!
            var receivedChangedFlags: [LDFlagKey: LDChangedFlag]?

            beforeEach {
                testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                changedFlags = [DarklyServiceMock.FlagKeys.bool: LDChangedFlag(key: DarklyServiceMock.FlagKeys.bool,
                                                                               oldValue: false,
                                                                               oldValueSource: .cache,
                                                                               newValue: true,
                                                                               newValueSource: .server)]

                testContext.subject.observe([DarklyServiceMock.FlagKeys.bool], owner: self, handler: { (changes) in
                    receivedChangedFlags = changes
                })
            }
            it("registers a multiple flag observer") {
                expect(testContext.changeNotifierMock.addFlagChangeObserverCallCount) == 1
                expect(testContext.flagChangeObserver?.flagKeys) == [DarklyServiceMock.FlagKeys.bool]
                expect(testContext.flagChangeObserver?.owner) === self
                testContext.flagCollectionChangeHandler?(changedFlags)
                expect(receivedChangedFlags?.keys == changedFlags.keys).to(beTrue())
            }
        }

        describe("observeAll") {
            var changedFlags: [LDFlagKey: LDChangedFlag]!
            var receivedChangedFlags: [LDFlagKey: LDChangedFlag]?
            beforeEach {
                testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                changedFlags = [DarklyServiceMock.FlagKeys.bool: LDChangedFlag(key: DarklyServiceMock.FlagKeys.bool,
                                                                               oldValue: false,
                                                                               oldValueSource: .cache,
                                                                               newValue: true,
                                                                               newValueSource: .server)]

                testContext.subject.observeAll(owner: self, handler: { (changes) in
                    receivedChangedFlags = changes
                })
            }
            it("registers a collection flag observer") {
                expect(testContext.changeNotifierMock.addFlagChangeObserverCallCount) == 1
                expect(testContext.flagChangeObserver?.flagKeys) == LDFlagKey.anyKey
                expect(testContext.flagChangeObserver?.owner) === self
                expect(testContext.flagChangeObserver?.flagCollectionChangeHandler).toNot(beNil())
                testContext.flagCollectionChangeHandler?(changedFlags)
                expect(receivedChangedFlags?.keys == changedFlags.keys).to(beTrue())
            }
        }

        describe("observeFlagsUnchanged") {
            beforeEach {
                testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                testContext.subject.observeFlagsUnchanged(owner: self, handler: {
                    testContext.flagsUnchangedCallCount += 1
                })
            }
            it("registers a flags unchanged observer") {
                expect(testContext.changeNotifierMock.addFlagsUnchangedObserverCallCount) == 1
                expect(testContext.flagsUnchangedObserver?.owner) === self
                expect(testContext.flagsUnchangedHandler).toNot(beNil())
                testContext.flagsUnchangedHandler?()
                expect(testContext.flagsUnchangedCallCount) == 1
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

    private func onSyncCompleteSpec() {
        describe("on sync complete") {
            onSyncCompleteSuccessSpec()
            onSyncCompleteErrorSpec()
        }
    }

    private func onSyncCompleteSuccessSpec() {
        context("polling") {
            onSyncCompleteSuccessReplacingFlagsSpec(streamingMode: .polling)
        }
        context("streaming ping") {
            onSyncCompleteSuccessReplacingFlagsSpec(streamingMode: .streaming, eventType: .ping)
        }
        context("streaming put") {
            onSyncCompleteSuccessReplacingFlagsSpec(streamingMode: .streaming, eventType: .put)
        }
        context("streaming patch") {
            onSyncCompleteStreamingPatchSpec()
        }
        context("streaming delete") {
            onSyncCompleteDeleteFlagSpec()
        }
    }

    /* The concept of the onSyncCompleteSuccess tests is to configure the flags & mocks to simulate the intended change, prep the callbacks to trigger done() to end the async wait, and then call onSyncComplete with the parameters for the area under test. onSyncComplete will call a flagStore method which has an async closure, and so the test has to trigger that closure to get the correct code to execute in onSyncComplete. Once the async flagStore closure runs for the appropriate update method, the result can be measured in the mocks. While setting up each test is slightly different, measuring the result is largely the same.
     */
    private func onSyncCompleteSuccessReplacingFlagsSpec(streamingMode: LDStreamingMode, eventType: DarklyEventSource.LDEvent.EventType? = nil) {
        var testContext: TestContext!
        var newFlags: [LDFlagKey: Any]!
        var eventType: DarklyEventSource.LDEvent.EventType?

        beforeEach {
            testContext = TestContext(startOnline: true)
            eventType = streamingMode == .streaming ? eventType : nil
        }

        context("flags have different values") {
            beforeEach {
                let newBoolFeatureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, useAlternateValue: true)
                newFlags = testContext.user.flagStore.featureFlags.dictionaryValue(exciseNil: false)
                newFlags[DarklyServiceMock.FlagKeys.bool] = newBoolFeatureFlag.dictionaryValue(exciseNil: false)
                testContext.setFlagStoreCallbackToMimicRealFlagStore(newFlags: newFlags.flagCollection!)

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(newFlags, eventType))
                    if testContext.flagStoreMock.replaceStoreCallCount > 0 { testContext.replaceStoreComplete?() }
                }
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
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == testContext.oldFlags).to(beTrue())
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlagSource) == testContext.oldFlagSource
            }
        }
        context("a flag was added") {
            beforeEach {
                newFlags = testContext.user.flagStore.featureFlags.dictionaryValue(exciseNil: false)
                newFlags[Constants.newFlagKey] = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.string, useAlternateValue: true).dictionaryValue(exciseNil: false)
                testContext.setFlagStoreCallbackToMimicRealFlagStore(newFlags: newFlags.flagCollection!)

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(newFlags, eventType))
                    if testContext.flagStoreMock.replaceStoreCallCount > 0 { testContext.replaceStoreComplete?() }
                }
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
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == testContext.oldFlags).to(beTrue())
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlagSource) == testContext.oldFlagSource
            }
        }
        context("a flag was removed") {
            beforeEach {
                newFlags = testContext.user.flagStore.featureFlags.dictionaryValue(exciseNil: false)
                newFlags.removeValue(forKey: DarklyServiceMock.FlagKeys.dictionary)
                testContext.setFlagStoreCallbackToMimicRealFlagStore(newFlags: newFlags.flagCollection!)

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(newFlags, eventType))
                    if testContext.flagStoreMock.replaceStoreCallCount > 0 { testContext.replaceStoreComplete?() }
                }
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
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == testContext.oldFlags).to(beTrue())
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlagSource) == testContext.oldFlagSource
            }
        }
        context("there were no changes to the flags") {
            beforeEach {
                newFlags = testContext.user.flagStore.featureFlags.dictionaryValue(exciseNil: false)

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(newFlags, eventType))
                    if testContext.flagStoreMock.replaceStoreCallCount > 0 { testContext.replaceStoreComplete?() }
                }
            }
            it("updates the flag store") {
                expect(testContext.flagStoreMock.replaceStoreCallCount) == 1
                expect(testContext.flagStoreMock.replaceStoreReceivedArguments?.newFlags == newFlags).to(beTrue())
            }
            it("caches the new flags") {
                expect(testContext.flagCacheMock.cacheFlagsCallCount) == 1
                expect(testContext.flagCacheMock.cacheFlagsReceivedUser) == testContext.user
            }
            it("informs the flag change notifier of the unchanged flags") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == testContext.oldFlags).to(beTrue())
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlagSource) == testContext.oldFlagSource
            }
        }
    }

    func onSyncCompleteStreamingPatchSpec() {
        var testContext: TestContext!
        var flagUpdateDictionary: [String: Any]!
        var oldFlags: [LDFlagKey: FeatureFlag]!
        var newFlags: [LDFlagKey: Any]!

        beforeEach {
            testContext = TestContext(startOnline: true)
        }

        context("update changes flags") {
            beforeEach {
                oldFlags = testContext.flagStoreMock.featureFlags
                flagUpdateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                               value: DarklyServiceMock.FlagValues.int + 1,
                                                                               variation: DarklyServiceMock.Constants.variation + 1,
                                                                               version: DarklyServiceMock.Constants.version + 1)
                let newIntFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.int, useAlternateValue: true)
                newFlags = oldFlags.dictionaryValue(exciseNil: false)
                newFlags[DarklyServiceMock.FlagKeys.int] = newIntFlag.dictionaryValue(exciseNil: false)
                testContext.setFlagStoreCallbackToMimicRealFlagStore(newFlags: newFlags.flagCollection!)

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(flagUpdateDictionary, .patch))
                    if testContext.flagStoreMock.updateStoreCallCount > 0 { testContext.updateStoreComplete?() }
                }
            }

            it("updates the flag store") {
                expect(testContext.flagStoreMock.updateStoreCallCount) == 1
                expect(testContext.flagStoreMock.updateStoreReceivedArguments?.updateDictionary == flagUpdateDictionary).to(beTrue())
            }
            it("caches the updated flags") {
                expect(testContext.flagCacheMock.cacheFlagsCallCount) == 1
                expect(testContext.flagCacheMock.cacheFlagsReceivedUser) == testContext.user
            }
            it("informs the flag change notifier of the changed flag") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == oldFlags).to(beTrue())
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlagSource) == testContext.oldFlagSource
            }
        }
        context("update does not change flags") {
            beforeEach {
                oldFlags = testContext.flagStoreMock.featureFlags
                flagUpdateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                               value: DarklyServiceMock.FlagValues.int + 1,
                                                                               variation: DarklyServiceMock.Constants.variation,
                                                                               version: DarklyServiceMock.Constants.version)
                newFlags = oldFlags.dictionaryValue(exciseNil: false)

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(flagUpdateDictionary, .patch))
                    if testContext.flagStoreMock.updateStoreCallCount > 0 { testContext.updateStoreComplete?() }
                }
            }

            it("updates the flag store") {
                expect(testContext.flagStoreMock.updateStoreCallCount) == 1
                expect(testContext.flagStoreMock.updateStoreReceivedArguments?.updateDictionary == flagUpdateDictionary).to(beTrue())
            }
            it("caches the updated flags") {
                expect(testContext.flagCacheMock.cacheFlagsCallCount) == 1
                expect(testContext.flagCacheMock.cacheFlagsReceivedUser) == testContext.user
            }
            it("informs the flag change notifier of the unchanged flag") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == oldFlags).to(beTrue())
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlagSource) == testContext.oldFlagSource
            }
        }
    }

    func onSyncCompleteDeleteFlagSpec() {
        var testContext: TestContext!
        var flagUpdateDictionary: [String: Any]!
        var oldFlags: [LDFlagKey: FeatureFlag]!
        var newFlags: [LDFlagKey: Any]!

        beforeEach {
            testContext = TestContext(startOnline: true)
        }

        context("delete changes flags") {
            beforeEach {
                oldFlags = testContext.flagStoreMock.featureFlags
                flagUpdateDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version + 1)
                newFlags = oldFlags.dictionaryValue(exciseNil: false)
                newFlags.removeValue(forKey: DarklyServiceMock.FlagKeys.int)
                testContext.setFlagStoreCallbackToMimicRealFlagStore(newFlags: newFlags.flagCollection!)

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(flagUpdateDictionary, .delete))
                    if testContext.flagStoreMock.deleteFlagCallCount > 0 { testContext.deleteFlagComplete?() }
                }
            }

            it("updates the flag store") {
                expect(testContext.flagStoreMock.deleteFlagCallCount) == 1
                expect(testContext.flagStoreMock.deleteFlagReceivedArguments?.deleteDictionary == flagUpdateDictionary).to(beTrue())
            }
            it("caches the updated flags") {
                expect(testContext.flagCacheMock.cacheFlagsCallCount) == 1
                expect(testContext.flagCacheMock.cacheFlagsReceivedUser) == testContext.user
            }
            it("informs the flag change notifier of the changed flag") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == oldFlags).to(beTrue())
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlagSource) == testContext.oldFlagSource
            }
        }
        context("delete does not change flags") {
            beforeEach {
                oldFlags = testContext.flagStoreMock.featureFlags
                flagUpdateDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version)
                newFlags = oldFlags.dictionaryValue(exciseNil: false)

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(flagUpdateDictionary, .delete))
                    if testContext.flagStoreMock.deleteFlagCallCount > 0 { testContext.deleteFlagComplete?() }
                }
            }

            it("updates the flag store") {
                expect(testContext.flagStoreMock.deleteFlagCallCount) == 1
                expect(testContext.flagStoreMock.deleteFlagReceivedArguments?.deleteDictionary == flagUpdateDictionary).to(beTrue())
            }
            it("caches the updated flags") {
                expect(testContext.flagCacheMock.cacheFlagsCallCount) == 1
                expect(testContext.flagCacheMock.cacheFlagsReceivedUser) == testContext.user
            }
            it("informs the flag change notifier of the unchanged flag") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == oldFlags).to(beTrue())
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlagSource) == testContext.oldFlagSource
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

                    testContext.onSyncComplete?(.error(.response(HTTPURLResponse(url: testContext.config.baseUrl,
                                                                                 statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                                                 httpVersion: DarklyServiceMock.Constants.httpVersion,
                                                                                 headerFields: nil))))
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

                    testContext.onSyncComplete?(.error(.response(HTTPURLResponse(url: testContext.config.baseUrl,
                                                                                 statusCode: HTTPURLResponse.StatusCodes.unauthorized,
                                                                                 httpVersion: DarklyServiceMock.Constants.httpVersion,
                                                                                 headerFields: nil))))
                }
            }
            it("takes the client offline") {
                expect(testContext.subject.isOnline) == false
            }
            it("calls the server unavailable closure") {
                expect(serverUnavailableCalled) == true
            }
        }
        context("there was a non-NSError error") {
            var serverUnavailableCalled: Bool! = false
            beforeEach {
                waitUntil { done in
                    testContext.subject.onServerUnavailable = {
                        serverUnavailableCalled = true
                        done()
                    }

                    testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.error(.event(DarklyEventSource.LDEvent.stubNonNSErrorEvent())))
                }
            }
            it("does not take the client offline") {
                expect(testContext.subject.isOnline) == true
            }
            it("calls the server unavailable closure") {
                expect(serverUnavailableCalled) == true
            }
        }
    }

    private func runModeSpec() {
        var testContext: TestContext!

        describe("didEnterBackground notification") {
            context("after starting client") {
                context("when online") {
                    context("background updates disabled") {
                        beforeEach {
                            testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, runMode: .foreground)
                            testContext.subject.start(mobileKey: Constants.mockMobileKey)

                            NotificationCenter.default.post(name: .UIApplicationDidEnterBackground, object: self)
                        }
                        it("takes the sdk offline and reports events") {
                            expect(testContext.subject.isOnline) == true
                            expect(testContext.subject.runMode) == LDClientRunMode.background
                            expect(testContext.eventReporterMock.reportEventsCallCount) == 1
                            expect(testContext.eventReporterMock.isOnline) == false
                            expect(testContext.flagSynchronizerMock.isOnline) == false
                        }
                    }
                    context("background updates enabled") {
                        beforeEach {
                            testContext = TestContext(startOnline: true, enableBackgroundUpdates: true, runMode: .foreground)
                            testContext.subject.start(mobileKey: Constants.mockMobileKey)

                            NotificationCenter.default.post(name: .UIApplicationDidEnterBackground, object: self)
                        }
                        it("leaves the sdk online and reports events") {
                            expect(testContext.subject.isOnline) == true
                            expect(testContext.subject.runMode) == LDClientRunMode.background
                            expect(testContext.eventReporterMock.reportEventsCallCount) == 1
                            expect(testContext.eventReporterMock.isOnline) == false
                            expect(testContext.flagSynchronizerMock.isOnline) == true
                        }
                    }
                }
                context("when offline") {
                    beforeEach {
                        testContext = TestContext(startOnline: false, runMode: .foreground)
                        testContext.subject.start(mobileKey: Constants.mockMobileKey)

                        NotificationCenter.default.post(name: .UIApplicationDidEnterBackground, object: self)
                    }
                    it("leaves the sdk offline and reports events") {
                        expect(testContext.subject.isOnline) == false
                        expect(testContext.subject.runMode) == LDClientRunMode.background
                        expect(testContext.eventReporterMock.reportEventsCallCount) == 1    //LDClient expects the EventReporter to ignore the report() request when offline
                        expect(testContext.eventReporterMock.isOnline) == false
                        expect(testContext.flagSynchronizerMock.isOnline) == false
                    }
                }
            }
            context("before starting client") {
                beforeEach {
                    testContext = TestContext(startOnline: true, runMode: .foreground)

                    NotificationCenter.default.post(name: .UIApplicationDidEnterBackground, object: self)
                }
                it("leaves the sdk offline and reports events") {
                    expect(testContext.subject.isOnline) == false
                    expect(testContext.subject.runMode) == LDClientRunMode.background
                    expect(testContext.eventReporterMock.reportEventsCallCount) == 1    //LDClient expects the EventReporter to ignore the report() request when offline
                    expect(testContext.eventReporterMock.isOnline) == false
                    expect(testContext.flagSynchronizerMock.isOnline) == false
                }
            }
        }

        describe("willEnterForeground notification") {
            context("after starting client") {
                context("when online at background notification") {
                    beforeEach {
                        testContext = TestContext(startOnline: true, runMode: .background)
                        testContext.subject.start(mobileKey: Constants.mockMobileKey)

                        NotificationCenter.default.post(name: .UIApplicationWillEnterForeground, object: self)
                    }
                    it("takes the sdk online") {
                        expect(testContext.subject.isOnline) == true
                        expect(testContext.subject.runMode) == LDClientRunMode.foreground
                        expect(testContext.eventReporterMock.isOnline) == true
                        expect(testContext.flagSynchronizerMock.isOnline) == true
                    }
                }
                context("when offline at background notification") {
                    beforeEach {
                        testContext = TestContext(startOnline: false, runMode: .background)
                        testContext.subject.start(mobileKey: Constants.mockMobileKey)

                        NotificationCenter.default.post(name: .UIApplicationWillEnterForeground, object: self)
                    }
                    it("leaves the sdk offline") {
                        expect(testContext.subject.isOnline) == false
                        expect(testContext.subject.runMode) == LDClientRunMode.foreground
                        expect(testContext.eventReporterMock.isOnline) == false
                        expect(testContext.flagSynchronizerMock.isOnline) == false
                    }
                }
            }
            context("before starting client") {
                beforeEach {
                    testContext = TestContext(startOnline: true, runMode: .background)

                    NotificationCenter.default.post(name: .UIApplicationWillEnterForeground, object: self)
                }
                it("leaves the sdk offline") {
                    expect(testContext.subject.isOnline) == false
                    expect(testContext.subject.runMode) == LDClientRunMode.foreground
                    expect(testContext.eventReporterMock.isOnline) == false
                    expect(testContext.flagSynchronizerMock.isOnline) == false
                }
            }
        }

        describe("change run mode on macOS") {
            context("while online") {
                context("and running in the foreground") {
                    context("set background") {
                        context("with background updates enabled") {
                            beforeEach {
                                testContext = TestContext(startOnline: true, enableBackgroundUpdates: true, runMode: .foreground, operatingSystem: .macOS)
                                testContext.subject.start(mobileKey: Constants.mockMobileKey)

                                testContext.subject.setRunMode(.background)
                            }
                            it("takes the event reporter offline") {
                                expect(testContext.eventReporterMock.isOnline) == false
                            }
                            it("sets the flag synchronizer for background polling online") {
                                expect(testContext.flagSynchronizerMock.isOnline) == true
                                expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.polling
                                expect(testContext.flagSynchronizerMock.pollingInterval) == testContext.config.flagPollingInterval(runMode: .background)
                            }
                        }
                        context("with background updates disabled") {
                            beforeEach {
                                testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, runMode: .foreground, operatingSystem: .macOS)
                                testContext.subject.start(mobileKey: Constants.mockMobileKey)

                                testContext.subject.setRunMode(.background)
                            }
                            it("takes the event reporter offline") {
                                expect(testContext.eventReporterMock.isOnline) == false
                            }
                            it("sets the flag synchronizer for background polling offline") {
                                expect(testContext.flagSynchronizerMock.isOnline) == false
                                expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.polling
                                expect(testContext.flagSynchronizerMock.pollingInterval) == testContext.config.flagPollingInterval(runMode: .background)
                            }
                        }
                    }
                    context("set foreground") {
                        var eventReporterIsOnlineSetCount: Int!
                        var flagSynchronizerIsOnlineSetCount: Int!
                        var makeFlagSynchronizerCallCount: Int!
                        beforeEach {
                            testContext = TestContext(startOnline: true, runMode: .foreground, operatingSystem: .macOS)
                            testContext.subject.start(mobileKey: Constants.mockMobileKey)
                            eventReporterIsOnlineSetCount = testContext.eventReporterMock.isOnlineSetCount
                            flagSynchronizerIsOnlineSetCount = testContext.flagSynchronizerMock.isOnlineSetCount
                            makeFlagSynchronizerCallCount = testContext.serviceFactoryMock.makeFlagSynchronizerCallCount

                            testContext.subject.setRunMode(.foreground)
                        }
                        it("makes no changes") {
                            expect(testContext.eventReporterMock.isOnline) == true
                            expect(testContext.eventReporterMock.isOnlineSetCount) == eventReporterIsOnlineSetCount
                            expect(testContext.flagSynchronizerMock.isOnline) == true
                            expect(testContext.flagSynchronizerMock.isOnlineSetCount) == flagSynchronizerIsOnlineSetCount
                            expect(testContext.serviceFactoryMock.makeFlagSynchronizerCallCount) == makeFlagSynchronizerCallCount
                        }
                    }
                }
                context("and running in the background") {
                    context("set background") {
                        var eventReporterIsOnlineSetCount: Int!
                        var flagSynchronizerIsOnlineSetCount: Int!
                        var makeFlagSynchronizerCallCount: Int!
                        beforeEach {
                            testContext = TestContext(startOnline: true, enableBackgroundUpdates: true, runMode: .background, operatingSystem: .macOS)
                            testContext.subject.start(mobileKey: Constants.mockMobileKey)
                            eventReporterIsOnlineSetCount = testContext.eventReporterMock.isOnlineSetCount
                            flagSynchronizerIsOnlineSetCount = testContext.flagSynchronizerMock.isOnlineSetCount
                            makeFlagSynchronizerCallCount = testContext.serviceFactoryMock.makeFlagSynchronizerCallCount

                            testContext.subject.setRunMode(.background)
                        }
                        it("makes no changes") {
                            expect(testContext.eventReporterMock.isOnline) == true
                            expect(testContext.eventReporterMock.isOnlineSetCount) == eventReporterIsOnlineSetCount
                            expect(testContext.flagSynchronizerMock.isOnline) == true
                            expect(testContext.flagSynchronizerMock.isOnlineSetCount) == flagSynchronizerIsOnlineSetCount
                            expect(testContext.serviceFactoryMock.makeFlagSynchronizerCallCount) == makeFlagSynchronizerCallCount
                        }
                    }
                    context("set foreground") {
                        context("streaming mode") {
                            beforeEach {
                                testContext = TestContext(startOnline: true, streamingMode: .streaming, runMode: .background, operatingSystem: .macOS)
                                testContext.subject.start(mobileKey: Constants.mockMobileKey)

                                testContext.subject.setRunMode(.foreground)
                            }
                            it("takes the event reporter online") {
                                expect(testContext.eventReporterMock.isOnline) == true
                            }
                            it("sets the flag synchronizer for foreground streaming online") {
                                expect(testContext.flagSynchronizerMock.isOnline) == true
                                expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.streaming
                            }
                        }
                        context("polling mode") {
                            beforeEach {
                                testContext = TestContext(startOnline: true, streamingMode: .polling, runMode: .background, operatingSystem: .macOS)
                                testContext.subject.start(mobileKey: Constants.mockMobileKey)

                                testContext.subject.setRunMode(.foreground)
                            }
                            it("takes the event reporter online") {
                                expect(testContext.eventReporterMock.isOnline) == true
                            }
                            it("sets the flag synchronizer for foreground polling online") {
                                expect(testContext.flagSynchronizerMock.isOnline) == true
                                expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.polling
                                expect(testContext.flagSynchronizerMock.pollingInterval) == testContext.config.flagPollingInterval(runMode: .foreground)
                            }
                        }
                    }
                }
            }
            context("while offline") {
                context("and running in the foreground") {
                    context("set background") {
                        context("with background updates enabled") {
                            beforeEach {
                                testContext = TestContext(startOnline: false, enableBackgroundUpdates: true, runMode: .foreground, operatingSystem: .macOS)
                                testContext.subject.start(mobileKey: Constants.mockMobileKey)

                                testContext.subject.setRunMode(.background)
                            }
                            it("leaves the event reporter offline") {
                                expect(testContext.eventReporterMock.isOnline) == false
                            }
                            it("configures the flag synchronizer for background polling offline") {
                                expect(testContext.flagSynchronizerMock.isOnline) == false
                                expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.polling
                                expect(testContext.flagSynchronizerMock.pollingInterval) == testContext.config.flagPollingInterval(runMode: .background)
                            }
                        }
                        context("with background updates disabled") {
                            beforeEach {
                                testContext = TestContext(startOnline: false, enableBackgroundUpdates: false, runMode: .foreground, operatingSystem: .macOS)
                                testContext.subject.start(mobileKey: Constants.mockMobileKey)

                                testContext.subject.setRunMode(.background)
                            }
                            it("leaves the event reporter offline") {
                                expect(testContext.eventReporterMock.isOnline) == false
                            }
                            it("configures the flag synchronizer for background polling offline") {
                                expect(testContext.flagSynchronizerMock.isOnline) == false
                                expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.polling
                                expect(testContext.flagSynchronizerMock.pollingInterval) == testContext.config.flagPollingInterval(runMode: .background)
                            }
                        }
                    }
                    context("set foreground") {
                        var eventReporterIsOnlineSetCount: Int!
                        var flagSynchronizerIsOnlineSetCount: Int!
                        var makeFlagSynchronizerCallCount: Int!
                        beforeEach {
                            testContext = TestContext(startOnline: false, runMode: .foreground, operatingSystem: .macOS)
                            testContext.subject.start(mobileKey: Constants.mockMobileKey)
                            eventReporterIsOnlineSetCount = testContext.eventReporterMock.isOnlineSetCount
                            flagSynchronizerIsOnlineSetCount = testContext.flagSynchronizerMock.isOnlineSetCount
                            makeFlagSynchronizerCallCount = testContext.serviceFactoryMock.makeFlagSynchronizerCallCount

                            testContext.subject.setRunMode(.foreground)
                        }
                        it("makes no changes") {
                            expect(testContext.eventReporterMock.isOnline) == false
                            expect(testContext.eventReporterMock.isOnlineSetCount) == eventReporterIsOnlineSetCount
                            expect(testContext.flagSynchronizerMock.isOnline) == false
                            expect(testContext.flagSynchronizerMock.isOnlineSetCount) == flagSynchronizerIsOnlineSetCount
                            expect(testContext.serviceFactoryMock.makeFlagSynchronizerCallCount) == makeFlagSynchronizerCallCount
                        }
                    }
                }
                context("and running in the background") {
                    context("set background") {
                        var eventReporterIsOnlineSetCount: Int!
                        var flagSynchronizerIsOnlineSetCount: Int!
                        var makeFlagSynchronizerCallCount: Int!
                        beforeEach {
                            testContext = TestContext(startOnline: false, runMode: .background, operatingSystem: .macOS)
                            testContext.subject.start(mobileKey: Constants.mockMobileKey)
                            eventReporterIsOnlineSetCount = testContext.eventReporterMock.isOnlineSetCount
                            flagSynchronizerIsOnlineSetCount = testContext.flagSynchronizerMock.isOnlineSetCount
                            makeFlagSynchronizerCallCount = testContext.serviceFactoryMock.makeFlagSynchronizerCallCount

                            testContext.subject.setRunMode(.background)
                        }
                        it("makes no changes") {
                            expect(testContext.eventReporterMock.isOnline) == false
                            expect(testContext.eventReporterMock.isOnlineSetCount) == eventReporterIsOnlineSetCount
                            expect(testContext.flagSynchronizerMock.isOnline) == false
                            expect(testContext.flagSynchronizerMock.isOnlineSetCount) == flagSynchronizerIsOnlineSetCount
                            expect(testContext.serviceFactoryMock.makeFlagSynchronizerCallCount) == makeFlagSynchronizerCallCount
                        }
                    }
                    context("set foreground") {
                        context("streaming mode") {
                            beforeEach {
                                testContext = TestContext(startOnline: false, streamingMode: .streaming, runMode: .background, operatingSystem: .macOS)
                                testContext.subject.start(mobileKey: Constants.mockMobileKey)

                                testContext.subject.setRunMode(.foreground)
                            }
                            it("leaves the event reporter offline") {
                                expect(testContext.eventReporterMock.isOnline) == false
                            }
                            it("configures the flag synchronizer for foreground streaming offline") {
                                expect(testContext.flagSynchronizerMock.isOnline) == false
                                expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.streaming
                            }
                        }
                        context("polling mode") {
                            beforeEach {
                                testContext = TestContext(startOnline: false, streamingMode: .polling, runMode: .background, operatingSystem: .macOS)
                                testContext.subject.start(mobileKey: Constants.mockMobileKey)

                                testContext.subject.setRunMode(.foreground)
                            }
                            it("leaves the event reporter offline") {
                                expect(testContext.eventReporterMock.isOnline) == false
                            }
                            it("configures the flag synchronizer for foreground polling offline") {
                                expect(testContext.flagSynchronizerMock.isOnline) == false
                                expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.polling
                                expect(testContext.flagSynchronizerMock.pollingInterval) == testContext.config.flagPollingInterval(runMode: .foreground)
                            }
                        }
                    }
                }
            }
        }
    }

    private func streamingModeSpec() {
        var testContext: TestContext!

        describe("flag synchronizer streaming mode") {
            context("when running on iOS") {
                beforeEach {
                    testContext = TestContext(startOnline: true, runMode: .foreground, operatingSystem: .iOS)
                }
                it("sets the flag synchronizer to streaming mode") {
                    expect(testContext.makeFlagSynchronizerStreamingMode) == LDStreamingMode.streaming
                }
            }
            context("when running on watchOS") {
                beforeEach {
                    testContext = TestContext(startOnline: true, runMode: .foreground, operatingSystem: .watchOS)
                }
                it("sets the flag synchronizer to streaming mode") {
                    expect(testContext.makeFlagSynchronizerStreamingMode) == LDStreamingMode.polling
                }
            }
            //TODO: When adding mac & tv support, add tests to verify the streaming mode
        }
    }
}

extension UserFlagCachingMock {
    func reset() {
        cacheFlagsCallCount = 0
        cacheFlagsReceivedUser = nil
        retrieveFlagsCallCount = 0
        retrieveFlagsReceivedUser = nil
    }
}
