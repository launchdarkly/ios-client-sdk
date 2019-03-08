//
//  LDClientSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 11/13/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
import DarklyEventSource
@testable import LaunchDarkly

final class LDClientSpec: QuickSpec {
    struct Constants {
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
        var serviceFactoryMock: ClientServiceMockFactory! {
            return subject.serviceFactory as? ClientServiceMockFactory
        }
        var flagCacheMock: UserFlagCachingMock! {
            return serviceFactoryMock.userFlagCache
        }
        var flagStoreMock: FlagMaintainingMock! {
            return user.flagStore as? FlagMaintainingMock
        }
        var flagSynchronizerMock: LDFlagSynchronizingMock! {
            return subject.flagSynchronizer as? LDFlagSynchronizingMock
        }
        var eventReporterMock: EventReportingMock! {
            return subject.eventReporter as? EventReportingMock
        }
        var changeNotifierMock: FlagChangeNotifyingMock! {
            return subject.flagChangeNotifier as? FlagChangeNotifyingMock
        }
        var errorNotifierMock: ErrorNotifyingMock! {
            return subject.errorNotifier as? ErrorNotifyingMock
        }
        var environmentReporterMock: EnvironmentReportingMock! {
            return subject.environmentReporter as? EnvironmentReportingMock
        }
        // makeFlagSynchronizer getters
        var makeFlagSynchronizerStreamingMode: LDStreamingMode? {
            return serviceFactoryMock.makeFlagSynchronizerReceivedParameters?.streamingMode
        }
        var makeFlagSynchronizerPollingInterval: TimeInterval? {
            return serviceFactoryMock.makeFlagSynchronizerReceivedParameters?.pollingInterval
        }
        var makeFlagSynchronizerService: DarklyServiceProvider? {
            return serviceFactoryMock.makeFlagSynchronizerReceivedParameters?.service
        }
        // flag observing getters
        var flagChangeObserver: FlagChangeObserver? {
            return changeNotifierMock.addFlagChangeObserverReceivedObserver
        }
        var flagChangeHandler: LDFlagChangeHandler? {
            return flagChangeObserver?.flagChangeHandler
        }
        var flagCollectionChangeHandler: LDFlagCollectionChangeHandler? {
            return flagChangeObserver?.flagCollectionChangeHandler
        }
        var flagsUnchangedCallCount = 0
        var observedError: Error? {
            return errorNotifierMock.notifyObserversReceivedError
        }
        var flagsUnchangedObserver: FlagsUnchangedObserver? {
            return changeNotifierMock?.addFlagsUnchangedObserverReceivedObserver
        }
        var flagsUnchangedHandler: LDFlagsUnchangedHandler? {
            return flagsUnchangedObserver?.flagsUnchangedHandler
        }
        var errorObserver: ErrorObserver? {
            return errorNotifierMock.addErrorObserverReceivedObserver
        }
        var onSyncComplete: FlagSyncCompleteClosure? {
            return serviceFactoryMock.onFlagSyncComplete
        }
        // flag maintaining mock accessors
        var replaceStoreComplete: CompletionClosure? {
            return flagStoreMock.replaceStoreReceivedArguments?.completion
        }
        var updateStoreComplete: CompletionClosure? {
            return flagStoreMock.updateStoreReceivedArguments?.completion
        }
        var deleteFlagComplete: CompletionClosure? {
            return flagStoreMock.deleteFlagReceivedArguments?.completion
        }
        var recordedEvent: LaunchDarkly.Event? {
            return eventReporterMock.recordReceivedArguments?.event
        }
        // user flags
        var oldFlags: [LDFlagKey: FeatureFlag]!
        var oldFlagSource: LDFlagValueSource!
        // throttler
        var throttlerMock: ThrottlingMock? {
            return subject.throttler as? ThrottlingMock
        }

        init(startOnline: Bool = false,
             streamingMode: LDStreamingMode = .streaming,
             enableBackgroundUpdates: Bool = true,
             runMode: LDClientRunMode = .foreground,
             operatingSystem: OperatingSystem? = nil,
             startClient: Bool = false) {

            let clientServiceFactory = ClientServiceMockFactory()
            if let operatingSystem = operatingSystem {
                clientServiceFactory.makeEnvironmentReporterReturnValue.operatingSystem = operatingSystem
            }

            config = LDConfig.stub(mobileKey: LDConfig.Constants.mockMobileKey, environmentReporter: clientServiceFactory.makeEnvironmentReporterReturnValue)
            config.startOnline = startOnline
            config.streamingMode = streamingMode
            config.enableBackgroundUpdates = enableBackgroundUpdates
            config.eventFlushInterval = 300.0   //5 min...don't want this to trigger

            user = LDUser.stub()
            oldFlags = user.flagStore.featureFlags
            oldFlagSource = user.flagStore.flagValueSource

            //In order to setup the client for background operation correctly, make it for the foreground, then set the runMode to background after start
            //Note that although LDClient is a singleton, calling makeClient here gets a fresh client
            subject = LDClient.makeClient(with: clientServiceFactory, config: config, user: user, runMode: .foreground)

            self.flagCacheMock.reset()
            self.setFlagStoreCallbackToMimicRealFlagStore()

            setThrottlerToExecuteRunClosure()

            if startClient {
                subject.start(config: config)
            }
            if runMode == .background {
                subject.setRunMode(.background)
            }
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
        reportEventsSpec()
        allFlagValuesSpec()
    }

    private func startSpec() {
        describe("start") {
            var testContext: TestContext!

            context("when configured to start online") {
                beforeEach {
                    testContext = TestContext()
                    testContext.config.startOnline = true

                    waitUntil { done in
                        testContext.subject.start(config: testContext.config, user: testContext.user, completion: done)
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
                        testContext.subject.start(config: testContext.config, user: testContext.user, completion: done)
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
                OperatingSystem.allOperatingSystems.forEach { (os) in
                    context("on \(os)") {
                        beforeEach {
                            testContext = TestContext(startOnline: true, runMode: .background, operatingSystem: os)

                            waitUntil { done in
                                testContext.subject.start(config: testContext.config, user: testContext.user, completion: done)
                            }
                        }
                        it("takes the client and service objects online when background enabled") {
                            expect(testContext.subject.isOnline) == os.isBackgroundEnabled
                            expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                            expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                        }
                        it("saves the config") {
                            expect(testContext.subject.config) == testContext.config
                            expect(testContext.subject.service.config) == testContext.config
                            expect(testContext.makeFlagSynchronizerStreamingMode) == os.backgroundStreamingMode
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
                }
            }
            context("when configured to not allow background updates and running in background mode") {
                OperatingSystem.allOperatingSystems.forEach { (os) in
                    context("on \(os)") {
                        beforeEach {
                            testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, runMode: .background, operatingSystem: os)
                            testContext.config.enableBackgroundUpdates = false

                            waitUntil { done in
                                testContext.subject.start(config: testContext.config, user: testContext.user, completion: done)
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
                            testContext.subject.start(config: testContext.config, user: testContext.user, completion: done)
                        }

                        newConfig = testContext.subject.config
                        newConfig.baseUrl = Constants.alternateMockUrl

                        newUser = LDUser.stub()

                        testContext.subject.start(config: newConfig, user: newUser)
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
                            testContext.subject.start(config: testContext.config, user: testContext.user, completion: done)
                        }

                        newConfig = testContext.subject.config
                        newConfig.baseUrl = Constants.alternateMockUrl

                        newUser = LDUser.stub()

                        testContext.subject.start(config: newConfig, user: newUser)
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
            context("when called without user") {
                context("after setting user") {
                    beforeEach {
                        testContext = TestContext()
                        testContext.subject.user = testContext.user
                        waitUntil { done in
                            testContext.subject.start(config: testContext.config, completion: done)
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
                context("without setting user") {
                    beforeEach {
                        testContext = TestContext()
                        waitUntil { done in
                            testContext.subject.start(config: testContext.config, completion: done)
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
                        testContext.subject.start(config: testContext.config, user: testContext.user, completion: done)
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
                        testContext.subject.start(config: testContext.config, user: testContext.user, completion: done)
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

        describe("set config") {
            var setIsOnlineCount: (flagSync: Int, event: Int) = (0, 0)
            beforeEach {
                testContext = TestContext()
            }
            context("when config values are the same") {
                beforeEach {
                    testContext.subject.start(config: testContext.config, user: testContext.user)
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
                    newConfig.flagPollingInterval += 0.001
                    newConfig.eventFlushInterval += 0.001
                }
                context("with run mode set to foreground") {
                    beforeEach {
                        testContext.subject.start(config: testContext.config, user: testContext.user)

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
                    OperatingSystem.allOperatingSystems.forEach { (os) in
                        context("on \(os)") {
                            beforeEach {
                                testContext = TestContext(startOnline: true, runMode: .background, operatingSystem: os)
                                testContext.subject.start(config: testContext.config, user: testContext.user)

                                newConfig = testContext.config
                                //change some values and check they're propagated to supporting objects
                                newConfig.baseUrl = Constants.alternateMockUrl
                                newConfig.flagPollingInterval += 0.001
                                newConfig.eventFlushInterval += 0.001

                                testContext.subject.config = newConfig
                            }
                            it("changes to the new config values") {
                                expect(testContext.subject.config) == newConfig
                                expect(testContext.subject.service.config) == newConfig
                                expect(testContext.makeFlagSynchronizerStreamingMode) == os.backgroundStreamingMode
                                expect(testContext.makeFlagSynchronizerPollingInterval) == newConfig.flagPollingInterval(runMode: testContext.subject.runMode)
                                expect(testContext.subject.eventReporter.config) == newConfig
                            }
                            it("leaves the client online") {
                                expect(testContext.subject.isOnline) == os.isBackgroundEnabled
                                expect(testContext.flagSynchronizerMock.isOnline) == testContext.subject.isOnline
                                expect(testContext.eventReporterMock.isOnline) == testContext.subject.isOnline
                            }
                        }
                    }
                }
            }
            context("when the client is offline") {
                var newConfig: LDConfig!
                beforeEach {
                    testContext.config.startOnline = false
                    testContext.subject.start(config: testContext.config, user: testContext.user)

                    newConfig = testContext.config
                    //change some values and check they're propagated to supporting objects
                    newConfig.baseUrl = Constants.alternateMockUrl
                    newConfig.flagPollingInterval += 0.001
                    newConfig.eventFlushInterval += 0.001

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
                    newConfig.flagPollingInterval += 0.001
                    newConfig.eventFlushInterval += 0.001

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

        describe("set user") {
            var newUser: LDUser!
            beforeEach {
                testContext = TestContext()
            }
            context("when the client is online") {
                beforeEach {
                    testContext.config.startOnline = true
                    testContext.subject.start(config: testContext.config, user: testContext.user)
                    testContext.eventReporterMock.recordSummaryEventCallCount = 0   //calling start sets the user, which calls eventReporter.recordSummaryEvent()

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
                it("records identify and summary events") {
                    expect(testContext.eventReporterMock.recordSummaryEventCallCount) == 1
                    expect(testContext.eventReporterMock.recordReceivedArguments?.event.kind == .identify).to(beTrue())
                }
            }
            context("when the client is offline") {
                beforeEach {
                    testContext.config.startOnline = false
                    testContext.subject.start(config: testContext.config, user: testContext.user)
                    testContext.eventReporterMock.recordSummaryEventCallCount = 0   //calling start sets the user, which calls eventReporter.recordSummaryEvent()

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
                it("records identify and summary events") {
                    expect(testContext.eventReporterMock.recordSummaryEventCallCount) == 1
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
                    expect(testContext.eventReporterMock.recordSummaryEventCallCount) == 0
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
                        testContext.subject.start(config: testContext.config, user: testContext.user)

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
                        testContext.subject.start(config: testContext.config, user: testContext.user)
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
                OperatingSystem.allOperatingSystems.forEach { (os) in
                    context("on \(os)") {
                        beforeEach {
                            testContext = TestContext(runMode: .background, operatingSystem: os)
                        }
                        context("while configured to enable background updates") {
                            beforeEach {
                                testContext.subject.start(config: testContext.config, user: testContext.user)
                            }
                            context("and setting online") {
                                var targetRunThrottledCalls: Int!
                                beforeEach {
                                    targetRunThrottledCalls = os.isBackgroundEnabled ? 1 : 0
                                    waitUntil { done in
                                        testContext.subject.setOnline(true, completion: done)
                                    }
                                }
                                it("takes the client and service objects online") {
                                    expect(testContext.throttlerMock?.runThrottledCallCount ?? 0) == targetRunThrottledCalls
                                    expect(testContext.subject.isOnline) == os.isBackgroundEnabled
                                    expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                                    expect(testContext.makeFlagSynchronizerStreamingMode) == os.backgroundStreamingMode
                                    expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
                                    expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                                }
                            }
                        }
                        context("while configured to disable background updates") {
                            beforeEach {
                                testContext.config.enableBackgroundUpdates = false
                                testContext.subject.start(config: testContext.config, user: testContext.user)
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
            context("when the mobile key is empty") {
                beforeEach {
                    testContext.config.mobileKey = ""
                    testContext.subject.start(config: testContext.config, user: testContext.user)
                    testContext.throttlerMock?.runThrottledCallCount = 0

                    testContext.subject.setOnline(true)
                }
                it("leaves the client and service objects offline") {
                    expect(testContext.throttlerMock?.runThrottledCallCount ?? 0) == 0
                    expect(testContext.subject.isOnline) == false
                    expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                    expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                }
            }
        }
    }

    private func stopSpec() {
        var testContext: TestContext!

        describe("stop") {
            var event: LaunchDarkly.Event!
            var priorRecordedEvents: Int!
            beforeEach {
                testContext = TestContext()
                event = Event.stub(.custom, with: testContext.user)
            }
            context("when started") {
                beforeEach {
                    priorRecordedEvents = 0
                }
                context("and online") {
                    beforeEach {
                        testContext.config.startOnline = true
                        testContext.subject.start(config: testContext.config, user: testContext.user)
                        priorRecordedEvents = testContext.eventReporterMock.recordCallCount

                        testContext.subject.stop()
                    }
                    it("takes the client offline") {
                        expect(testContext.subject.isOnline) == false
                    }
                    it("stops recording events") {
                        expect { try testContext.subject.trackEvent(key: event.key!) }.toNot(throwError())
                        expect(testContext.eventReporterMock.recordCallCount) == priorRecordedEvents
                    }
                }
                context("and offline") {
                    beforeEach {
                        testContext.config.startOnline = false
                        testContext.subject.start(config: testContext.config, user: testContext.user)
                        priorRecordedEvents = testContext.eventReporterMock.recordCallCount

                        testContext.subject.stop()
                    }
                    it("leaves the client offline") {
                        expect(testContext.subject.isOnline) == false
                    }
                    it("stops recording events") {
                        expect { try testContext.subject.trackEvent(key: event.key!) }.toNot(throwError())
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
                    expect { try testContext.subject.trackEvent(key: event.key!) }.toNot(throwError())
                    expect(testContext.eventReporterMock.recordCallCount) == 0
                }
            }
            context("when already stopped") {
                beforeEach {
                    testContext.config.startOnline = false
                    testContext.subject.start(config: testContext.config, user: testContext.user)
                    testContext.subject.stop()
                    priorRecordedEvents = testContext.eventReporterMock.recordCallCount

                    testContext.subject.stop()
                }
                it("leaves the client offline") {
                    expect(testContext.subject.isOnline) == false
                }
                it("stops recording events") {
                    expect { try testContext.subject.trackEvent(key: event.key!) }.toNot(throwError())
                    expect(testContext.eventReporterMock.recordCallCount) == priorRecordedEvents
                }
            }
        }
    }

    private func trackEventSpec() {
        var testContext: TestContext!

        describe("track event") {
            var event: LaunchDarkly.Event!
            beforeEach {
                testContext = TestContext()
                event = Event.stub(.custom, with: testContext.user)
            }
            context("when client was started") {
                beforeEach {
                    testContext.subject.start(config: testContext.config, user: testContext.user)

                    //swiftlint:disable:next force_try
                    try! testContext.subject.trackEvent(key: event.key!, data: event.data)
                }
                it("records a custom event") {
                    expect(testContext.eventReporterMock.recordReceivedArguments?.event.key) == event.key
                    expect(testContext.eventReporterMock.recordReceivedArguments?.event.user) == event.user
                    expect(testContext.eventReporterMock.recordReceivedArguments?.event.data).toNot(beNil())
                    expect(AnyComparer.isEqual(testContext.eventReporterMock.recordReceivedArguments?.event.data, to: event.data)).to(beTrue())
                }
            }
            context("when client was not started") {
                beforeEach {
                    //swiftlint:disable:next force_try
                    try! testContext.subject.trackEvent(key: event.key!, data: event.data)
                }
                it("does not record any events") {
                    expect(testContext.eventReporterMock.recordCallCount) == 0
                }
            }
            context("when client was stopped") {
                var priorRecordedEvents: Int!
                beforeEach {
                    testContext.subject.start(config: testContext.config, user: testContext.user)
                    testContext.subject.stop()
                    priorRecordedEvents = testContext.eventReporterMock.recordCallCount

                    //swiftlint:disable:next force_try
                    try! testContext.subject.trackEvent(key: event.key!, data: event.data)
                }
                it("does not record any more events") {
                    expect(testContext.eventReporterMock.recordCallCount) == priorRecordedEvents
                }
            }
        }
    }

    private func variationSpec() {
        describe("variation") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
            }
            context("flag store contains the requested value") {
                beforeEach {
                    testContext.subject.start(config: testContext.config, user: testContext.user)
                }
                context("non-Optional fallback value") {
                    it("returns the flag value") {
                        //The casts in the expect() calls allow the compiler to determine which variation method to use. This test calls the non-Optional variation method
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool) as Bool) == DarklyServiceMock.FlagValues.bool
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.int, fallback: DefaultFlagValues.int) as Int) == DarklyServiceMock.FlagValues.int
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.double, fallback: DefaultFlagValues.double) as Double) == DarklyServiceMock.FlagValues.double
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.string, fallback: DefaultFlagValues.string) as String) == DarklyServiceMock.FlagValues.string
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.array, fallback: DefaultFlagValues.array) == DarklyServiceMock.FlagValues.array).to(beTrue())
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: DefaultFlagValues.dictionary) as [String: Any]
                            == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                    }
                    it("records a flag evaluation event") {
                        _ = testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == DarklyServiceMock.FlagKeys.bool
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DarklyServiceMock.FlagValues.bool)).to(beTrue())
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag) == testContext.flagStoreMock.featureFlags[DarklyServiceMock.FlagKeys.bool]
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
                context("Optional fallback value") {
                    it("returns the flag value") {
                        //The casts in the expect() calls allow the compiler to determine which variation method to use. This test calls the Optional variation method
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool as Bool?)) == DarklyServiceMock.FlagValues.bool
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.int, fallback: DefaultFlagValues.int  as Int?)) == DarklyServiceMock.FlagValues.int
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.double, fallback: DefaultFlagValues.double as Double?)) == DarklyServiceMock.FlagValues.double
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.string, fallback: DefaultFlagValues.string as String?)) == DarklyServiceMock.FlagValues.string
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.array, fallback: DefaultFlagValues.array as Array?) == DarklyServiceMock.FlagValues.array).to(beTrue())
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: DefaultFlagValues.dictionary as [String: Any]?)
                            == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                    }
                    it("records a flag evaluation event") {
                        //The cast in the variation call directs the compiler to the Optional variation method
                        _ = testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool as Bool?)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == DarklyServiceMock.FlagKeys.bool
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DarklyServiceMock.FlagValues.bool)).to(beTrue())
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag) == testContext.flagStoreMock.featureFlags[DarklyServiceMock.FlagKeys.bool]
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
                context("No fallback value") {
                    it("returns the flag value") {
                        //The casts in the expect() calls allow the compiler to determine the return type.
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, fallback: nil as Bool?)) == DarklyServiceMock.FlagValues.bool
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.int, fallback: nil  as Int?)) == DarklyServiceMock.FlagValues.int
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.double, fallback: nil as Double?)) == DarklyServiceMock.FlagValues.double
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.string, fallback: nil as String?)) == DarklyServiceMock.FlagValues.string
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.array, fallback: nil as Array?) == DarklyServiceMock.FlagValues.array).to(beTrue())
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: nil as [String: Any]?)
                            == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                    }
                    it("records a flag evaluation event") {
                        //The cast in the variation call allows the compiler to determine the return type
                        _ = testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, fallback: nil as Bool?)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == DarklyServiceMock.FlagKeys.bool
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DarklyServiceMock.FlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag) == testContext.flagStoreMock.featureFlags[DarklyServiceMock.FlagKeys.bool]
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
            }
            context("flag store does not contain the requested value") {
                beforeEach {
                    testContext.subject.start(config: testContext.config, user: testContext.user)
                }
                context("non-Optional fallback value") {
                    it("returns the fallback value") {
                        //The casts in the expect() calls allow the compiler to determine which variation method to use. This test calls the non-Optional variation method
                        expect(testContext.subject.variation(forKey: BadFlagKeys.bool, fallback: DefaultFlagValues.bool) as Bool) == DefaultFlagValues.bool
                        expect(testContext.subject.variation(forKey: BadFlagKeys.int, fallback: DefaultFlagValues.int) as Int) == DefaultFlagValues.int
                        expect(testContext.subject.variation(forKey: BadFlagKeys.double, fallback: DefaultFlagValues.double) as Double) == DefaultFlagValues.double
                        expect(testContext.subject.variation(forKey: BadFlagKeys.string, fallback: DefaultFlagValues.string) as String) == DefaultFlagValues.string
                        expect(testContext.subject.variation(forKey: BadFlagKeys.array, fallback: DefaultFlagValues.array) == DefaultFlagValues.array).to(beTrue())
                        expect(testContext.subject.variation(forKey: BadFlagKeys.dictionary, fallback: DefaultFlagValues.dictionary) as [String: Any] == DefaultFlagValues.dictionary).to(beTrue())
                    }
                    it("records a flag evaluation event") {
                        _ = testContext.subject.variation(forKey: BadFlagKeys.bool, fallback: DefaultFlagValues.bool)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == BadFlagKeys.bool
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
                context("Optional fallback value") {
                    it("returns the fallback value") {
                        //The casts in the expect() calls allow the compiler to determine which variation method to use. This test calls the non-Optional variation method
                        expect(testContext.subject.variation(forKey: BadFlagKeys.bool, fallback: DefaultFlagValues.bool as Bool?)) == DefaultFlagValues.bool
                        expect(testContext.subject.variation(forKey: BadFlagKeys.int, fallback: DefaultFlagValues.int as Int?)) == DefaultFlagValues.int
                        expect(testContext.subject.variation(forKey: BadFlagKeys.double, fallback: DefaultFlagValues.double as Double?)) == DefaultFlagValues.double
                        expect(testContext.subject.variation(forKey: BadFlagKeys.string, fallback: DefaultFlagValues.string as String?)) == DefaultFlagValues.string
                        expect(testContext.subject.variation(forKey: BadFlagKeys.array, fallback: DefaultFlagValues.array as Array?) == DefaultFlagValues.array).to(beTrue())
                        expect(testContext.subject.variation(forKey: BadFlagKeys.dictionary, fallback: DefaultFlagValues.dictionary as [String: Any]?) == DefaultFlagValues.dictionary).to(beTrue())
                    }
                    it("records a flag evaluation event") {
                        //The cast in the variation call directs the compiler to the Optional variation method
                        _ = testContext.subject.variation(forKey: BadFlagKeys.bool, fallback: DefaultFlagValues.bool as Bool?)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == BadFlagKeys.bool
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
                context("no fallback value") {
                    it("returns nil") {
                        //The casts in the expect() calls allow the compiler to determine which variation method to use. This test calls the non-Optional variation method
                        expect(testContext.subject.variation(forKey: BadFlagKeys.bool, fallback: nil as Bool?)).to(beNil())
                        expect(testContext.subject.variation(forKey: BadFlagKeys.int, fallback: nil as Int?)).to(beNil())
                        expect(testContext.subject.variation(forKey: BadFlagKeys.double, fallback: nil as Double?)).to(beNil())
                        expect(testContext.subject.variation(forKey: BadFlagKeys.string, fallback: nil as String?)).to(beNil())
                        expect(testContext.subject.variation(forKey: BadFlagKeys.array, fallback: nil as [Any]?)).to(beNil())
                        expect(testContext.subject.variation(forKey: BadFlagKeys.dictionary, fallback: nil as [String: Any]?)).to(beNil())
                    }
                    it("records a flag evaluation event") {
                        //The cast in the variation call directs the compiler to the Optional variation method
                        _ = testContext.subject.variation(forKey: BadFlagKeys.bool, fallback: nil as Bool?)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == BadFlagKeys.bool
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
            }
            context("when it hasnt started") {
                beforeEach {
                    testContext = TestContext(startOnline: false)
                }
                it("returns the fallback value") {
                    //The casts in the expect() calls allow the compiler to determine which variation method to use. This test calls the non-Optional variation method
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool) as Bool) == DefaultFlagValues.bool
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.int, fallback: DefaultFlagValues.int) as Int) == DefaultFlagValues.int
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.double, fallback: DefaultFlagValues.double) as Double) == DefaultFlagValues.double
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.string, fallback: DefaultFlagValues.string) as String) == DefaultFlagValues.string
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.array, fallback: DefaultFlagValues.array) == DefaultFlagValues.array).to(beTrue())
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: DefaultFlagValues.dictionary) as [String: Any] == DefaultFlagValues.dictionary).to(beTrue())
                }
                it("does not record a flag evaluation event") {
                    _ = testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool)
                    expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 0
                }
            }
        }
    }

    private func variationAndSourceSpec() {
        describe("variation and source") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
            }
            context("flag store contains the requested value") {
                beforeEach {
                    testContext.flagStoreMock.flagValueSource = .server
                    testContext.subject.start(config: testContext.config, user: testContext.user)
                }
                context("non-Optional fallback value") {
                    var arrayValue: (value: [Int], source: LDFlagValueSource)!
                    var dictionaryValue: (value: [String: Any], source: LDFlagValueSource)!
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
                    it("records a flag evaluation event") {
                        _ = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == DarklyServiceMock.FlagKeys.bool
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DarklyServiceMock.FlagValues.bool)).to(beTrue())
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag) == testContext.flagStoreMock.featureFlags[DarklyServiceMock.FlagKeys.bool]
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
                context("Optional fallback value") {
                    var arrayValue: (value: [Int]?, source: LDFlagValueSource)!
                    var dictionaryValue: (value: [String: Any]?, source: LDFlagValueSource)!
                    it("returns the flag value and source") {
                        //The casts in the expect() calls allow the compiler to determine which variation method to use. This test calls the Optional variation method
                        expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool as Bool?)
                            == (DarklyServiceMock.FlagValues.bool, LDFlagValueSource.server)).to(beTrue())
                        expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.int, fallback: DefaultFlagValues.int as Int?)
                            == (DarklyServiceMock.FlagValues.int, LDFlagValueSource.server)).to(beTrue())
                        expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.double, fallback: DefaultFlagValues.double as Double?)
                            == (DarklyServiceMock.FlagValues.double, LDFlagValueSource.server)).to(beTrue())
                        expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.string, fallback: DefaultFlagValues.string as String?)
                            == (DarklyServiceMock.FlagValues.string, LDFlagValueSource.server)).to(beTrue())
                        arrayValue = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.array, fallback: DefaultFlagValues.array as Array?)
                        expect(arrayValue.value == DarklyServiceMock.FlagValues.array).to(beTrue())
                        expect(arrayValue.source) == LDFlagValueSource.server
                        dictionaryValue = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: DefaultFlagValues.dictionary as [String: Any]?)
                        expect(dictionaryValue.value == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                        expect(dictionaryValue.source) == LDFlagValueSource.server
                    }
                    it("records a flag evaluation event") {
                        //The cast in the variation call directs the compiler to the Optional variation method
                        _ = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool as Bool?)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == DarklyServiceMock.FlagKeys.bool
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DarklyServiceMock.FlagValues.bool)).to(beTrue())
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag) == testContext.flagStoreMock.featureFlags[DarklyServiceMock.FlagKeys.bool]
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
                context("No fallback value") {
                    var arrayValue: (value: [Int]?, source: LDFlagValueSource)!
                    var dictionaryValue: (value: [String: Any]?, source: LDFlagValueSource)!
                    it("returns the flag value and source") {
                        expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.bool, fallback: nil as Bool?)
                            == (DarklyServiceMock.FlagValues.bool, LDFlagValueSource.server)).to(beTrue())
                        expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.int, fallback: nil as Int?)
                            == (DarklyServiceMock.FlagValues.int, LDFlagValueSource.server)).to(beTrue())
                        expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.double, fallback: nil as Double?)
                            == (DarklyServiceMock.FlagValues.double, LDFlagValueSource.server)).to(beTrue())
                        expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.string, fallback: nil as String?)
                            == (DarklyServiceMock.FlagValues.string, LDFlagValueSource.server)).to(beTrue())
                        arrayValue = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.array, fallback: nil as Array?)
                        expect(arrayValue.value == DarklyServiceMock.FlagValues.array).to(beTrue())
                        expect(arrayValue.source) == LDFlagValueSource.server
                        dictionaryValue = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: nil as [String: Any]?)
                        expect(dictionaryValue.value == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                        expect(dictionaryValue.source) == LDFlagValueSource.server
                    }
                    it("records a flag evaluation event") {
                        _ = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.bool, fallback: nil as Bool?)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == DarklyServiceMock.FlagKeys.bool
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DarklyServiceMock.FlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag) == testContext.flagStoreMock.featureFlags[DarklyServiceMock.FlagKeys.bool]
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
                context("flag value is null") {
                    var arrayValue: (value: [Int], source: LDFlagValueSource)!
                    var dictionaryValue: (value: [String: Any], source: LDFlagValueSource)!
                    it("returns the fallback value and source") {
                        expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.null, fallback: DefaultFlagValues.bool)
                            == (DefaultFlagValues.bool, LDFlagValueSource.fallback)).to(beTrue())
                        expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.null, fallback: DefaultFlagValues.int)
                            == (DefaultFlagValues.int, LDFlagValueSource.fallback)).to(beTrue())
                        expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.null, fallback: DefaultFlagValues.double)
                            == (DefaultFlagValues.double, LDFlagValueSource.fallback)).to(beTrue())
                        expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.null, fallback: DefaultFlagValues.string)
                            == (DefaultFlagValues.string, LDFlagValueSource.fallback)).to(beTrue())
                        arrayValue = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.null, fallback: DefaultFlagValues.array)
                        expect(arrayValue.value == DefaultFlagValues.array).to(beTrue())
                        expect(arrayValue.source) == LDFlagValueSource.fallback
                        dictionaryValue = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.null, fallback: DefaultFlagValues.dictionary)
                        expect(dictionaryValue.value == DefaultFlagValues.dictionary).to(beTrue())
                        expect(dictionaryValue.source) == LDFlagValueSource.fallback
                    }
                    it("records a flag evaluation event") {
                        _ = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.null, fallback: DefaultFlagValues.bool)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == DarklyServiceMock.FlagKeys.null
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag) == testContext.flagStoreMock.featureFlags[DarklyServiceMock.FlagKeys.null]
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
            }
            context("flag store does not contain the requested value") {
                beforeEach {
                    testContext.subject.start(config: testContext.config, user: testContext.user)
                }
                context("non-Optional fallback value") {
                    var arrayValue: (value: [Int], source: LDFlagValueSource)!
                    var dictionaryValue: (value: [String: Any], source: LDFlagValueSource)!
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
                    it("records a flag evaluation event") {
                        _ = testContext.subject.variationAndSource(forKey: BadFlagKeys.bool, fallback: DefaultFlagValues.bool)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == BadFlagKeys.bool
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
                context("Optional fallback value") {
                    var arrayValue: (value: [Int]?, source: LDFlagValueSource)!
                    var dictionaryValue: (value: [String: Any]?, source: LDFlagValueSource)!
                    it("returns the fallback value and fallback source") {
                        //The casts in the expect() calls allow the compiler to determine which variation method to use. This test calls the non-Optional variation method
                        expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.bool, fallback: DefaultFlagValues.bool as Bool?)
                            == (DefaultFlagValues.bool, .fallback)).to(beTrue())
                        expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.int, fallback: DefaultFlagValues.int as Int?)
                            == (DefaultFlagValues.int, .fallback)).to(beTrue())
                        expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.double, fallback: DefaultFlagValues.double as Double?)
                            == (DefaultFlagValues.double, .fallback)).to(beTrue())
                        expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.string, fallback: DefaultFlagValues.string as String?)
                            == (DefaultFlagValues.string, .fallback)).to(beTrue())
                        arrayValue = testContext.subject.variationAndSource(forKey: BadFlagKeys.array, fallback: DefaultFlagValues.array as Array?)
                        expect(arrayValue.value == DefaultFlagValues.array).to(beTrue())
                        expect(arrayValue.source) == LDFlagValueSource.fallback
                        dictionaryValue = testContext.subject.variationAndSource(forKey: BadFlagKeys.dictionary, fallback: DefaultFlagValues.dictionary as [String: Any]?)
                        expect(dictionaryValue.value == DefaultFlagValues.dictionary).to(beTrue())
                        expect(dictionaryValue.source) == LDFlagValueSource.fallback
                    }
                    it("records a flag evaluation event") {
                        //The cast in the variation call directs the compiler to the Optional variation method
                        _ = testContext.subject.variationAndSource(forKey: BadFlagKeys.bool, fallback: DefaultFlagValues.bool as Bool?)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == BadFlagKeys.bool
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
                context("no fallback value") {
                    var arrayValue: (value: [Int]?, source: LDFlagValueSource)!
                    var dictionaryValue: (value: [String: Any]?, source: LDFlagValueSource)!
                    it("returns the fallback value and fallback source") {
                        //The casts in the expect() calls allow the compiler to determine which variation method to use. This test calls the non-Optional variation method
                        expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.bool, fallback: nil as Bool?)
                            == (nil, .fallback)).to(beTrue())
                        expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.int, fallback: nil as Int?)
                            == (nil, .fallback)).to(beTrue())
                        expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.double, fallback: nil as Double?)
                            == (nil, .fallback)).to(beTrue())
                        expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.string, fallback: nil as String?)
                            == (nil, .fallback)).to(beTrue())
                        arrayValue = testContext.subject.variationAndSource(forKey: BadFlagKeys.array, fallback: nil as Array?)
                        expect(arrayValue.value).to(beNil())
                        expect(arrayValue.source) == LDFlagValueSource.fallback
                        dictionaryValue = testContext.subject.variationAndSource(forKey: BadFlagKeys.dictionary, fallback: nil as [String: Any]?)
                        expect(dictionaryValue.value).to(beNil())
                        expect(dictionaryValue.source) == LDFlagValueSource.fallback
                    }
                    it("records a flag evaluation event") {
                        //The cast in the variation call directs the compiler to the Optional variation method
                        _ = testContext.subject.variationAndSource(forKey: BadFlagKeys.bool, fallback: nil as Bool?)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == BadFlagKeys.bool
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
            }
            context("when it hasnt started") {
                var arrayValue: (value: [Int], source: LDFlagValueSource)!
                var dictionaryValue: (value: [String: Any], source: LDFlagValueSource)!
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
                    arrayValue = testContext.subject.variationAndSource(forKey: BadFlagKeys.array, fallback: DefaultFlagValues.array)
                    expect(arrayValue.value == DefaultFlagValues.array).to(beTrue())
                    expect(arrayValue.source) == LDFlagValueSource.fallback
                    dictionaryValue = testContext.subject.variationAndSource(forKey: BadFlagKeys.dictionary, fallback: DefaultFlagValues.dictionary)
                    expect(dictionaryValue.value == DefaultFlagValues.dictionary).to(beTrue())
                    expect(dictionaryValue.source) == LDFlagValueSource.fallback
                }
                it("does not record a flag evaluation event") {
                    _ = testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool)
                    expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 0
                }
            }
        }
    }

    private func observeSpec() {
        describe("observe") {
            var changedFlag: LDChangedFlag!
            var receivedChangedFlag: LDChangedFlag?
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
                testContext.subject.start(config: testContext.config, user: testContext.user)
                changedFlag = LDChangedFlag(key: DarklyServiceMock.FlagKeys.bool, oldValue: false, oldValueSource: .cache, newValue: true, newValueSource: .server)

                testContext.subject.observe(key: DarklyServiceMock.FlagKeys.bool, owner: self, handler: { (change) in
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
            var testContext: TestContext!

            beforeEach {
                testContext = TestContext()
                testContext.subject.start(config: testContext.config, user: testContext.user)
                changedFlags = [DarklyServiceMock.FlagKeys.bool: LDChangedFlag(key: DarklyServiceMock.FlagKeys.bool,
                                                                               oldValue: false,
                                                                               oldValueSource: .cache,
                                                                               newValue: true,
                                                                               newValueSource: .server)]

                testContext.subject.observe(keys: [DarklyServiceMock.FlagKeys.bool], owner: self, handler: { (changes) in
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
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
                testContext.subject.start(config: testContext.config, user: testContext.user)
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
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
                testContext.subject.start(config: testContext.config, user: testContext.user)

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

        describe("observeError") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
                testContext.subject.start(config: testContext.config, user: testContext.user)

                testContext.subject.observeError(owner: self, handler: { (_) in

                })
            }
            it("registers an error observer") {
                expect(testContext.errorNotifierMock.addErrorObserverCallCount) == 1
                expect(testContext.errorObserver).toNot(beNil())
                guard let errorObserver = testContext.errorObserver
                else {
                    return
                }
                expect(errorObserver.owner) === self
                expect(errorObserver.errorHandler).toNot(beNil())
            }
        }

        describe("stopObserving") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
                testContext.subject.start(config: testContext.config, user: testContext.user)

                testContext.subject.stopObserving(owner: self)
            }
            it("unregisters the owner") {
                expect(testContext.changeNotifierMock.removeObserverCallCount) == 1
                expect(testContext.changeNotifierMock.removeObserverReceivedArguments?.owner) === self
                expect(testContext.errorNotifierMock.removeObserversCallCount) == 1
                expect(testContext.errorNotifierMock.removeObserversReceivedOwner) === self
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

    /* The concept of the onSyncCompleteSuccess tests is to configure the flags & mocks to simulate the intended change, prep the callbacks to trigger done() to end the async wait, and then call onFlagSyncComplete with the parameters for the area under test. onFlagSyncComplete will call a flagStore method which has an async closure, and so the test has to trigger that closure to get the correct code to execute in onFlagSyncComplete. Once the async flagStore closure runs for the appropriate update method, the result can be measured in the mocks. While setting up each test is slightly different, measuring the result is largely the same.
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
                newFlags = testContext.user.flagStore.featureFlags.dictionaryValue
                newFlags[DarklyServiceMock.FlagKeys.bool] = newBoolFeatureFlag.dictionaryValue
                testContext.setFlagStoreCallbackToMimicRealFlagStore(newFlags: newFlags.flagCollection!)

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(newFlags, eventType))
                    if testContext.flagStoreMock.replaceStoreCallCount > 0 {
                        testContext.replaceStoreComplete?()
                    }
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
                newFlags = testContext.user.flagStore.featureFlags.dictionaryValue
                newFlags[Constants.newFlagKey] = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.string, useAlternateValue: true).dictionaryValue
                testContext.setFlagStoreCallbackToMimicRealFlagStore(newFlags: newFlags.flagCollection!)

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(newFlags, eventType))
                    if testContext.flagStoreMock.replaceStoreCallCount > 0 {
                        testContext.replaceStoreComplete?()
                    }
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
                newFlags = testContext.user.flagStore.featureFlags.dictionaryValue
                newFlags.removeValue(forKey: DarklyServiceMock.FlagKeys.dictionary)
                testContext.setFlagStoreCallbackToMimicRealFlagStore(newFlags: newFlags.flagCollection!)

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(newFlags, eventType))
                    if testContext.flagStoreMock.replaceStoreCallCount > 0 {
                        testContext.replaceStoreComplete?()
                    }
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
                newFlags = testContext.user.flagStore.featureFlags.dictionaryValue

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(newFlags, eventType))
                    if testContext.flagStoreMock.replaceStoreCallCount > 0 {
                        testContext.replaceStoreComplete?()
                    }
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
                newFlags = oldFlags.dictionaryValue
                newFlags[DarklyServiceMock.FlagKeys.int] = newIntFlag.dictionaryValue
                testContext.setFlagStoreCallbackToMimicRealFlagStore(newFlags: newFlags.flagCollection!)

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(flagUpdateDictionary, .patch))
                    if testContext.flagStoreMock.updateStoreCallCount > 0 {
                        testContext.updateStoreComplete?()
                    }
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
                newFlags = oldFlags.dictionaryValue

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(flagUpdateDictionary, .patch))
                    if testContext.flagStoreMock.updateStoreCallCount > 0 {
                        testContext.updateStoreComplete?()
                    }
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
                newFlags = oldFlags.dictionaryValue
                newFlags.removeValue(forKey: DarklyServiceMock.FlagKeys.int)
                testContext.setFlagStoreCallbackToMimicRealFlagStore(newFlags: newFlags.flagCollection!)

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(flagUpdateDictionary, .delete))
                    if testContext.flagStoreMock.deleteFlagCallCount > 0 {
                        testContext.deleteFlagComplete?()
                    }
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
                newFlags = oldFlags.dictionaryValue

                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done

                    testContext.subject.start(config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.success(flagUpdateDictionary, .delete))
                    if testContext.flagStoreMock.deleteFlagCallCount > 0 {
                        testContext.deleteFlagComplete?()
                    }
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
            beforeEach {
                waitUntil { done in
                    testContext.errorNotifierMock.notifyObserversCallback = {
                        done()
                    }

                    testContext.subject.start(config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.error(.response(HTTPURLResponse(url: testContext.config.baseUrl,
                                                                                 statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                                                 httpVersion: DarklyServiceMock.Constants.httpVersion,
                                                                                 headerFields: nil))))
                }
            }
            it("does not take the client offline") {
                expect(testContext.subject.isOnline) == true
            }
            it("calls the errorNotifier with a .response SynchronizingError") {
                expect(testContext.errorNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.observedError as? SynchronizingError).toNot(beNil())
                guard case .response(let urlResponse)? = testContext.observedError as? SynchronizingError,
                    let httpUrlResponse = urlResponse as? HTTPURLResponse
                else {
                    fail("unexpected error reported")
                    return
                }
                expect(httpUrlResponse.statusCode) == HTTPURLResponse.StatusCodes.internalServerError
            }
        }
        context("there was a request error") {
            beforeEach {
                waitUntil { done in
                    testContext.errorNotifierMock.notifyObserversCallback = {
                        done()
                    }

                    testContext.subject.start(config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.error(.request(DarklyServiceMock.Constants.error)))
                }
            }
            it("does not take the client offline") {
                expect(testContext.subject.isOnline) == true
            }
            it("calls the errorNotifier with a .request SynchronizingError") {
                expect(testContext.errorNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.observedError as? SynchronizingError).toNot(beNil())
                guard case .request(let error as NSError)? = testContext.observedError as? SynchronizingError
                else {
                    fail("unexpected error reported")
                    return
                }
                expect(error.code) == Int(CFNetworkErrors.cfurlErrorResourceUnavailable.rawValue)
            }
        }
        context("there was a data error") {
            beforeEach {
                waitUntil { done in
                    testContext.errorNotifierMock.notifyObserversCallback = {
                        done()
                    }

                    testContext.subject.start(config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.error(.data(DarklyServiceMock.Constants.errorData)))
                }
            }
            it("does not take the client offline") {
                expect(testContext.subject.isOnline) == true
            }
            it("calls the errorNotifier with a .data SynchronizingError") {
                expect(testContext.errorNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.observedError as? SynchronizingError).toNot(beNil())
                guard case .data(let data)? = testContext.observedError as? SynchronizingError,
                    let errorData = data
                else {
                    fail("unexpected error reported")
                    return
                }
                expect(errorData) == DarklyServiceMock.Constants.errorData
            }
        }
        context("there was a client unauthorized error") {
            beforeEach {
                waitUntil { done in
                    testContext.errorNotifierMock.notifyObserversCallback = {
                        done()
                    }

                    testContext.subject.start(config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.error(.response(HTTPURLResponse(url: testContext.config.baseUrl,
                                                                                 statusCode: HTTPURLResponse.StatusCodes.unauthorized,
                                                                                 httpVersion: DarklyServiceMock.Constants.httpVersion,
                                                                                 headerFields: nil))))
                }
            }
            it("takes the client offline") {
                expect(testContext.subject.isOnline) == false
            }
            it("calls the errorNotifier with a .response SynchronizingError") {
                expect(testContext.errorNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.observedError as? SynchronizingError).toNot(beNil())
                guard case .response(let urlResponse)? = testContext.observedError as? SynchronizingError,
                    let httpUrlResponse = urlResponse as? HTTPURLResponse
                else {
                    fail("unexpected error reported")
                    return
                }
                expect(httpUrlResponse.statusCode) == HTTPURLResponse.StatusCodes.unauthorized
            }
        }
        context("there was a non-NSError error") {
            beforeEach {
                waitUntil { done in
                    testContext.errorNotifierMock.notifyObserversCallback = {
                        done()
                    }

                    testContext.subject.start(config: testContext.config, user: testContext.user)

                    testContext.onSyncComplete?(.error(.event(DarklyEventSource.LDEvent.stubNonNSErrorEvent())))
                }
            }
            it("does not take the client offline") {
                expect(testContext.subject.isOnline) == true
            }
            it("calls the errorNotifier with a .event SynchronizingError") {
                expect(testContext.errorNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.observedError as? SynchronizingError).toNot(beNil())
                guard case .event(let event)? = testContext.observedError as? SynchronizingError,
                    let eventSourceEvent = event
                else {
                    fail("unexpected error reported")
                    return
                }
                expect(eventSourceEvent.error is DummyError).to(beTrue())
            }
        }
    }

    private func runModeSpec() {
        var testContext: TestContext!

        describe("didEnterBackground notification") {
            context("after starting client") {
                context("when online") {
                    OperatingSystem.allOperatingSystems.forEach { (os) in
                        context("on \(os)") {
                            context("background updates disabled") {
                                beforeEach {
                                    testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, runMode: .foreground, operatingSystem: os, startClient: true)

                                    NotificationCenter.default.post(name: testContext.environmentReporterMock.backgroundNotification!, object: self)
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
                                    testContext = TestContext(startOnline: true, enableBackgroundUpdates: true, runMode: .foreground, operatingSystem: os, startClient: true)

                                    NotificationCenter.default.post(name: testContext.environmentReporterMock.backgroundNotification!, object: self)
                                }
                                it("leaves the sdk online and reports events") {
                                    expect(testContext.subject.isOnline) == true
                                    expect(testContext.subject.runMode) == LDClientRunMode.background
                                    expect(testContext.eventReporterMock.reportEventsCallCount) == 1
                                    expect(testContext.eventReporterMock.isOnline) == false
                                    expect(testContext.flagSynchronizerMock.isOnline) == os.isBackgroundEnabled
                                    expect(testContext.flagSynchronizerMock.streamingMode) == os.backgroundStreamingMode
                                }
                            }
                        }
                    }
                }
                context("when offline") {
                    beforeEach {
                        testContext = TestContext(startOnline: false, runMode: .foreground, startClient: true)

                        NotificationCenter.default.post(name: testContext.environmentReporterMock.backgroundNotification!, object: self)
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

                    NotificationCenter.default.post(name: testContext.environmentReporterMock.backgroundNotification!, object: self)
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
                OperatingSystem.allOperatingSystems.forEach { (os) in
                    context("on \(os)") {
                        context("when online at foreground notification") {
                            beforeEach {
                                testContext = TestContext(startOnline: true, runMode: .background, operatingSystem: os, startClient: true)

                                NotificationCenter.default.post(name: testContext.environmentReporterMock.foregroundNotification!, object: self)
                            }
                            it("takes the sdk online") {
                                expect(testContext.subject.isOnline) == true
                                expect(testContext.subject.runMode) == LDClientRunMode.foreground
                                expect(testContext.eventReporterMock.isOnline) == true
                                expect(testContext.flagSynchronizerMock.isOnline) == true
                            }
                        }
                        context("when offline at foreground notification") {
                            beforeEach {
                                testContext = TestContext(startOnline: false, runMode: .background, operatingSystem: os)
                                testContext.subject.start(config: testContext.config)

                                NotificationCenter.default.post(name: testContext.environmentReporterMock.foregroundNotification!, object: self)
                            }
                            it("leaves the sdk offline") {
                                expect(testContext.subject.isOnline) == false
                                expect(testContext.subject.runMode) == LDClientRunMode.foreground
                                expect(testContext.eventReporterMock.isOnline) == false
                                expect(testContext.flagSynchronizerMock.isOnline) == false
                            }
                        }
                    }
                }
            }
            context("before starting client") {
                beforeEach {
                    testContext = TestContext(startOnline: true, runMode: .background)

                    NotificationCenter.default.post(name: testContext.environmentReporterMock.foregroundNotification!, object: self)
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
                            context("streaming mode") {
                                beforeEach {
                                    testContext = TestContext(startOnline: true, streamingMode: .streaming, enableBackgroundUpdates: true, runMode: .foreground, operatingSystem: .macOS)
                                    testContext.subject.start(config: testContext.config)

                                    testContext.subject.setRunMode(.background)
                                }
                                it("takes the event reporter offline") {
                                    expect(testContext.eventReporterMock.isOnline) == false
                                }
                                it("sets the flag synchronizer for background streaming online") {
                                    expect(testContext.flagSynchronizerMock.isOnline) == true
                                    expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.streaming
                                }
                            }
                            context("polling mode") {
                                beforeEach {
                                    testContext = TestContext(startOnline: true, streamingMode: .polling, enableBackgroundUpdates: true, runMode: .foreground, operatingSystem: .macOS)
                                    testContext.subject.start(config: testContext.config)

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
                        }
                        context("with background updates disabled") {
                            beforeEach {
                                testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, runMode: .foreground, operatingSystem: .macOS)
                                testContext.subject.start(config: testContext.config)

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
                            testContext.subject.start(config: testContext.config)
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
                            testContext.subject.start(config: testContext.config)
                            NotificationCenter.default.post(name: testContext.environmentReporterMock.backgroundNotification!, object: self)
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
                                testContext.subject.start(config: testContext.config)

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
                                testContext.subject.start(config: testContext.config)

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
                                testContext.subject.start(config: testContext.config)

                                testContext.subject.setRunMode(.background)
                            }
                            it("leaves the event reporter offline") {
                                expect(testContext.eventReporterMock.isOnline) == false
                            }
                            it("configures the flag synchronizer for background streaming offline") {
                                expect(testContext.flagSynchronizerMock.isOnline) == false
                                expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.streaming
                            }
                        }
                        context("with background updates disabled") {
                            beforeEach {
                                testContext = TestContext(startOnline: false, enableBackgroundUpdates: false, runMode: .foreground, operatingSystem: .macOS)
                                testContext.subject.start(config: testContext.config)

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
                            testContext.subject.start(config: testContext.config)
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
                            testContext.subject.start(config: testContext.config)
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
                                testContext.subject.start(config: testContext.config)

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
                                testContext.subject.start(config: testContext.config)

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
            OperatingSystem.allOperatingSystems.forEach { (os) in
                context("when running on \(os)") {
                    beforeEach {
                        testContext = TestContext(startOnline: true, runMode: .foreground, operatingSystem: os)
                    }
                    it("sets the flag synchronizer streaming mode") {
                        expect(testContext.makeFlagSynchronizerStreamingMode) == (os.isStreamingEnabled ? LDStreamingMode.streaming : LDStreamingMode.polling)
                    }
                }
            }
        }
    }

    private func reportEventsSpec() {
        var testContext: TestContext!

        describe("reportEvents") {
            beforeEach {
                testContext = TestContext()

                testContext.subject.reportEvents()
            }
            it("tells the event reporter to report events") {
                expect(testContext.eventReporterMock.reportEventsCallCount) == 1
            }
        }
    }

    private func allFlagValuesSpec() {
        var testContext: TestContext!
        var featureFlagValues: [LDFlagKey: Any]?
        describe("allFlagValues") {
            context("when client was started") {
                var featureFlags: [LDFlagKey: FeatureFlag]!
                beforeEach {
                    testContext = TestContext()
                    testContext.subject.start(config: testContext.config)
                    featureFlags = testContext.subject.user.flagStore.featureFlags

                    featureFlagValues = testContext.subject.allFlagValues
                }
                it("returns a matching dictionary of flag keys and values") {
                    expect(featureFlagValues?.count) == featureFlags.count - 1 //nil is omitted
                    featureFlags.keys.forEach { (flagKey) in
                        expect(AnyComparer.isEqual(featureFlagValues?[flagKey], to: featureFlags[flagKey]?.value)).to(beTrue())
                    }
                }
            }
            context("when client was not started") {
                beforeEach {
                    testContext = TestContext()

                    featureFlagValues = testContext.subject.allFlagValues
                }
                it("returns nil") {
                    expect(featureFlagValues).to(beNil())
                }
            }
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

extension OperatingSystem {
    var backgroundStreamingMode: LDStreamingMode {
        return self == .macOS ? .streaming : .polling
    }
}
