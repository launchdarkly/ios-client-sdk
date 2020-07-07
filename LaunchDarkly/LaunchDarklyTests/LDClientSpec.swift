//
//  LDClientSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
import LDSwiftEventSource
@testable import LaunchDarkly

final class LDClientSpec: QuickSpec {
    struct Constants {
        fileprivate static let alternateMockUrl = URL(string: "https://dummy.alternate.com")!
        fileprivate static let alternateMockMobileKey = "alternateMockMobileKey"

        fileprivate static let newFlagKey = "LDClientSpec.newFlagKey"
        fileprivate static let newFlagValue = "LDClientSpec.newFlagValue"

        fileprivate static let updateThreshold: TimeInterval = 0.05
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

    class TestContext {
        var config: LDConfig!
        var user: LDUser!
        var subject: LDClient!
        // mock getters based on setting up the user & subject
        var serviceFactoryMock: ClientServiceMockFactory! {
            return subject.serviceFactory as? ClientServiceMockFactory
        }
        var serviceMock: DarklyServiceMock! {
            return subject.service as? DarklyServiceMock
        }
        var featureFlagCachingMock: FeatureFlagCachingMock! {
            return subject.flagCache as? FeatureFlagCachingMock
        }
        var cacheConvertingMock: CacheConvertingMock! {
            return subject.cacheConverter as? CacheConvertingMock
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
        var connectionModeChangedCallCount = 0
        var connectionModeChangedObserver: ConnectionModeChangedObserver? {
            return changeNotifierMock?.addConnectionModeChangedObserverReceivedObserver
        }
        var flagsUnchangedHandler: LDFlagsUnchangedHandler? {
            return flagsUnchangedObserver?.flagsUnchangedHandler
        }
        var connectionModeChangedHandler: LDConnectionModeChangedHandler? {
            return connectionModeChangedObserver?.connectionModeChangedHandler
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
            eventReporterMock.recordReceivedEvent
        }
        // user flags
        var oldFlags: [LDFlagKey: FeatureFlag]!
        // throttler
        var throttlerMock: ThrottlingMock? {
            return subject.throttler as? ThrottlingMock
        }

        init(newUser: LDUser? = nil,
             noUser: Bool = false,
             newConfig: LDConfig? = nil,
             startOnline: Bool = false,
             streamingMode: LDStreamingMode = .streaming,
             enableBackgroundUpdates: Bool = true,
             runMode: LDClientRunMode = .foreground,
             operatingSystem: OperatingSystem? = nil,
             completion: (() -> Void)? = nil) {

            let clientServiceFactory = ClientServiceMockFactory()
            if let operatingSystem = operatingSystem {
                clientServiceFactory.makeEnvironmentReporterReturnValue.operatingSystem = operatingSystem
            }

            config = newConfig ?? LDConfig.stub(mobileKey: LDConfig.Constants.mockMobileKey, environmentReporter: clientServiceFactory.makeEnvironmentReporterReturnValue)
            config.startOnline = startOnline
            config.streamingMode = streamingMode
            config.enableBackgroundUpdates = enableBackgroundUpdates
            config.eventFlushInterval = 300.0   //5 min...don't want this to trigger
            user = newUser ?? LDUser.stub()
            oldFlags = user.flagStore.featureFlags

            let flagNotifier = (ClientServiceFactory().makeFlagChangeNotifier() as! FlagChangeNotifier)
            
            LDClient.start(serviceFactory: clientServiceFactory, config: config, startUser: noUser ? nil : user, flagCache: clientServiceFactory.makeFeatureFlagCache(), flagNotifier: flagNotifier) {
                    self.startCompletion(runMode: runMode, completion: completion)
            }
            flagNotifier.notifyObservers(user: self.user, oldFlags: self.oldFlags)
        }
        
        init(newUser: LDUser? = nil,
             noUser: Bool = false,
             newConfig: LDConfig? = nil,
             startOnline: Bool = false,
             streamingMode: LDStreamingMode = .streaming,
             enableBackgroundUpdates: Bool = true,
             runMode: LDClientRunMode = .foreground,
             operatingSystem: OperatingSystem? = nil,
             timeOut: TimeInterval,
             forceTimeout: Bool = false,
             timeOutCompletion: ((_ timedOut: Bool) -> Void)? = nil) {

            let clientServiceFactory = ClientServiceMockFactory()
            if let operatingSystem = operatingSystem {
                clientServiceFactory.makeEnvironmentReporterReturnValue.operatingSystem = operatingSystem
            }

            config = newConfig ?? LDConfig.stub(mobileKey: LDConfig.Constants.mockMobileKey, environmentReporter: clientServiceFactory.makeEnvironmentReporterReturnValue)
            config.startOnline = startOnline
            config.streamingMode = streamingMode
            config.enableBackgroundUpdates = enableBackgroundUpdates
            config.eventFlushInterval = 300.0   //5 min...don't want this to trigger
            user = newUser ?? LDUser.stub()
            oldFlags = user.flagStore.featureFlags

            let flagNotifier = (ClientServiceFactory().makeFlagChangeNotifier() as! FlagChangeNotifier)
            
            LDClient.start(serviceFactory: clientServiceFactory, config: config, startUser: noUser ? nil : user, startWaitSeconds: timeOut, flagCache: clientServiceFactory.makeFeatureFlagCache(), flagNotifier: flagNotifier) { timedOut in
                self.startCompletion(runMode: runMode, timedOut: timedOut, timeOutCompletion: timeOutCompletion)
            }
            if !forceTimeout {
                flagNotifier.notifyObservers(user: self.user, oldFlags: self.oldFlags)
            }
        }

        func startCompletion(runMode: LDClientRunMode, timedOut: Bool = false, completion: (() -> Void)? = nil, timeOutCompletion: ((_ timedOut: Bool) -> Void)? = nil) {
            subject = LDClient.get()
            setFlagStoreCallbackToMimicRealFlagStore()

            if runMode == .background {
                subject.setRunMode(.background)
                DispatchQueue(label: "StartCompletionBackground").asyncAfter(deadline: .now() + 0.2) {
                    completion?()
                    timeOutCompletion?(timedOut)
                }
            } else {
                completion?()
                timeOutCompletion?(timedOut)
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
    }

    override func spec() {
        startSpec()
        startWithTimeoutSpec()
        setUserSpec()
        setOnlineSpec()
        closeSpec()
        trackEventSpec()
        variationSpec()
        observeSpec()
        onSyncCompleteSpec()
        runModeSpec()
        streamingModeSpec()
        flushSpec()
        allFlagValuesSpec()
        connectionInformationSpec()
        variationDetailSpec()
    }

    private func startSpec() {
        describe("start") {
            var testContext: TestContext!

            context("when configured to start online") {
                beforeEach {
                    waitUntil(timeout: 10) { done in
                        testContext = TestContext(startOnline: true, completion: done)
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
                it("uncaches the new users flags") {
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                }
                it("records an identify event") {
                    expect(testContext.eventReporterMock.recordCallCount) == 1
                    expect(testContext.recordedEvent?.kind) == .identify
                    expect(testContext.recordedEvent?.key) == testContext.user.key
                }
                it("converts cached data") {
                    expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                }
            }
            context("when configured to start offline") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(startOnline: false, completion: done)
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
                it("uncaches the new users flags") {
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                }
                it("records an identify event") {
                    expect(testContext.eventReporterMock.recordCallCount) == 1
                    expect(testContext.recordedEvent?.kind) == .identify
                    expect(testContext.recordedEvent?.key) == testContext.user.key
                }
                it("converts cached data") {
                    expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                }
            }
            context("when configured to allow background updates and running in background mode") {
                OperatingSystem.allOperatingSystems.forEach { (os) in
                    context("on \(os)") {
                        beforeEach {
                            waitUntil { done in
                                testContext = TestContext(startOnline: true, runMode: .background, operatingSystem: os, completion: done)
                            }
                            waitUntil(timeout: 10) { done in
                                testContext.subject.setService(ClientServiceMockFactory().makeDarklyServiceProvider(config: testContext.subject.config, user: testContext.subject.user))
                                testContext.subject.setOnline(true, completion: done)
                                testContext.subject.flagChangeNotifier.notifyObservers(user: testContext.user, oldFlags: testContext.oldFlags)
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
                        it("uncaches the new users flags") {
                            expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                            expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                            expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                        }
                        it("records an identify event") {
                            expect(testContext.eventReporterMock.recordCallCount) == 1
                            expect(testContext.recordedEvent?.kind) == .identify
                            expect(testContext.recordedEvent?.key) == testContext.user.key
                        }
                        it("converts cached data") {
                            expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                            expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                            expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                        }
                    }
                }
            }
            context("when configured to not allow background updates and running in background mode") {
                OperatingSystem.allOperatingSystems.forEach { (os) in
                    context("on \(os)") {
                        beforeEach {
                            waitUntil { done in
                                testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, runMode: .background, operatingSystem: os, completion: done)
                            }
                            waitUntil(timeout: 10) { done in
                                testContext.subject.setOnline(true, completion: done)
                                testContext.subject.flagChangeNotifier.notifyObservers(user: testContext.user, oldFlags: testContext.oldFlags)
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
                        it("uncaches the new users flags") {
                            expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                            expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                            expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                        }
                        it("records an identify event") {
                            expect(testContext.eventReporterMock.recordCallCount) == 1
                            expect(testContext.recordedEvent?.kind) == .identify
                            expect(testContext.recordedEvent?.key) == testContext.user.key
                        }
                        it("converts cached data") {
                            expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                            expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                            expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                        }
                    }
                }
            }
            context("when called without user") {
                context("after setting user") {
                    beforeEach {
                        waitUntil { done in
                            testContext = TestContext(noUser: true, startOnline: true, completion: done)
                        }

                        waitUntil { done in
                            testContext.subject.internalIdentify(newUser: testContext.user, testing: true, completion: done)
                            DispatchQueue(label: "AfterSettingUser").asyncAfter(deadline: .now() + 0.2) {
                                testContext.subject.flagChangeNotifier.notifyObservers(user: testContext.user, oldFlags: testContext.oldFlags)
                            }
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
                    it("uncaches the new users flags") {
                        expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 2 //called on init and subsequent identify
                        expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                        expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                    }
                    it("records an identify event") {
                        expect(testContext.eventReporterMock.recordCallCount) == 2 //both start and internalIdentify
                        expect(testContext.recordedEvent?.kind) == .identify
                        expect(testContext.recordedEvent?.key) == testContext.user.key
                    }
                    it("converts cached data") {
                        expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 2 //Both start and internalIdentify
                        expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                        expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                    }
                }
                context("without setting user") {
                    beforeEach {
                        waitUntil { done in
                            testContext = TestContext(noUser: true, startOnline: true, completion: done)
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
                    it("uncaches the new users flags") {
                        expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                        expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                        expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                    }
                    it("records an identify event") {
                        expect(testContext.eventReporterMock.recordCallCount) == 1
                        expect(testContext.recordedEvent?.kind) == .identify
                        expect(testContext.recordedEvent?.key) == testContext.user.key
                    }
                    it("converts cached data") {
                        expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                        expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                        expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                    }
                }
            }
            context("when called with cached flags for the user and environment") {
                var retrievedFlags: [LDFlagKey: FeatureFlag]!
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(startOnline: false, completion: done)
                    }
                    testContext.featureFlagCachingMock.retrieveFeatureFlagsReturnValue = testContext.user.flagStore.featureFlags
                    retrievedFlags = testContext.user.flagStore.featureFlags
                    testContext.flagStoreMock.featureFlags = [:]
                    waitUntil { done in
                        testContext.subject.internalIdentify(newUser: testContext.user, testing: true, completion: done)
                    }
                }
                it("checks the flag cache for the user and environment") {
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 2 //called on init and subsequent identify
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                }
                it("restores user flags from cache") {
                    expect(testContext.flagStoreMock.replaceStoreReceivedArguments?.newFlags?.flagCollection) == retrievedFlags
                }
                it("converts cached data") {
                    expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 2 // both start and identify
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                }
            }
            context("when called without cached flags for the user") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(startOnline: false) {
                            testContext.flagStoreMock.featureFlags = [:]
                            done()
                        }
                    }
                }
                it("checks the flag cache for the user and environment") {
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                }
                it("does not restore user flags from cache") {
                    expect(testContext.flagStoreMock.replaceStoreCallCount) == 0
                }
                it("converts cached data") {
                    expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                }
            }
        }
    }

    private func startWithTimeoutSpec() {
        describe("startWithTimeout") {
            var testContext: TestContext!
            
            context("when configured to start online") {
                beforeEach {
                    waitUntil(timeout: 15) { done in
                        testContext = TestContext(startOnline: true, timeOut: 10) { timedOut in
                            expect(timedOut) == false
                            done()
                        }
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
                it("uncaches the new users flags") {
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                }
                it("records an identify event") {
                    expect(testContext.eventReporterMock.recordCallCount) == 1
                    expect(testContext.recordedEvent?.kind) == .identify
                    expect(testContext.recordedEvent?.key) == testContext.user.key
                }
                it("converts cached data") {
                    expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                }
            }
            context("when configured to start online") {
                beforeEach {
                    waitUntil(timeout: 10) { done in
                        testContext = TestContext(startOnline: true, timeOut: 3.0, forceTimeout: true) { timedOut in
                            expect(timedOut) == true
                            done()
                        }
                    }
                }
                it("times out properly") {
                    expect(testContext.subject.isOnline) == true
                }
            }
            context("when configured to start offline") {
                beforeEach {
                    waitUntil(timeout: 15) { done in
                        testContext = TestContext(startOnline: false, timeOut: 10) { timedOut in
                            expect(timedOut) == true
                            done()
                        }
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
                it("uncaches the new users flags") {
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                }
                it("records an identify event") {
                    expect(testContext.eventReporterMock.recordCallCount) == 1
                    expect(testContext.recordedEvent?.kind) == .identify
                    expect(testContext.recordedEvent?.key) == testContext.user.key
                }
                it("converts cached data") {
                    expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                }
            }
            context("when configured to allow background updates and running in background mode") {
                OperatingSystem.allOperatingSystems.forEach { (os) in
                    context("on \(os)") {
                        beforeEach {
                            waitUntil(timeout: 15) { done in
                                testContext = TestContext(startOnline: true, runMode: .background, operatingSystem: os, timeOut: 10) { timedOut in
                                    expect(timedOut) == false
                                    done()
                                }
                            }
                            waitUntil(timeout: 10) { done in
                                testContext.subject.setService(ClientServiceMockFactory().makeDarklyServiceProvider(config: testContext.subject.config, user: testContext.subject.user))
                                testContext.subject.setOnline(true, completion: done)
                                testContext.subject.flagChangeNotifier.notifyObservers(user: testContext.user, oldFlags: testContext.oldFlags)
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
                        it("uncaches the new users flags") {
                            expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                            expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                            expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                        }
                        it("records an identify event") {
                            expect(testContext.eventReporterMock.recordCallCount) == 1
                            expect(testContext.recordedEvent?.kind) == .identify
                            expect(testContext.recordedEvent?.key) == testContext.user.key
                        }
                        it("converts cached data") {
                            expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                            expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                            expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                        }
                    }
                }
            }
            context("when configured to not allow background updates and running in background mode") {
                OperatingSystem.allOperatingSystems.forEach { (os) in
                    context("on \(os)") {
                        beforeEach {
                            waitUntil { done in
                                testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, runMode: .background, operatingSystem: os, timeOut: 10) { timedOut in
                                    expect(timedOut) == false
                                    done()
                                }
                            }
                            waitUntil(timeout: 10) { done in
                                testContext.subject.setOnline(true, completion: done)
                                testContext.subject.flagChangeNotifier.notifyObservers(user: testContext.user, oldFlags: testContext.oldFlags)
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
                        it("uncaches the new users flags") {
                            expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                            expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                            expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                        }
                        it("records an identify event") {
                            expect(testContext.eventReporterMock.recordCallCount) == 1
                            expect(testContext.recordedEvent?.kind) == .identify
                            expect(testContext.recordedEvent?.key) == testContext.user.key
                        }
                        it("converts cached data") {
                            expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                            expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                            expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                        }
                    }
                }
            }
            context("when called without user") {
                context("after setting user") {
                    beforeEach {
                        waitUntil { done in
                            testContext = TestContext(noUser: true, timeOut: 3) { timedOut in
                                expect(timedOut) == true
                                done()
                            }
                        }
                        
                        waitUntil { done in
                            testContext.subject.internalIdentify(newUser: testContext.user, testing: true, completion: done)
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
                    it("uncaches the new users flags") {
                        expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 2 //called on init and subsequent identify
                        expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                        expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                    }
                    it("records an identify event") {
                        expect(testContext.eventReporterMock.recordCallCount) == 2 // both start and identify
                        expect(testContext.recordedEvent?.kind) == .identify
                        expect(testContext.recordedEvent?.key) == testContext.user.key
                    }
                    it("converts cached data") {
                        expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 2
                        expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                        expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                    }
                }
                context("without setting user") {
                    beforeEach {
                        waitUntil { done in
                            testContext = TestContext(noUser: true, startOnline: false, timeOut: 3) { timedOut in
                                expect(timedOut) == true
                                done()
                            }
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
                    it("uncaches the new users flags") {
                        expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                        expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                        expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                    }
                    it("records an identify event") {
                        expect(testContext.eventReporterMock.recordCallCount) == 1
                        expect(testContext.recordedEvent?.kind) == .identify
                        expect(testContext.recordedEvent?.key) == testContext.user.key
                    }
                    it("converts cached data") {
                        expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                        expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                        expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                    }
                }
            }
            context("when called with cached flags for the user and environment") {
                var retrievedFlags: [LDFlagKey: FeatureFlag]!
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(startOnline: false, timeOut: 10) { timedOut in
                            expect(timedOut) == true
                            done()
                        }
                    }
                    testContext.featureFlagCachingMock.retrieveFeatureFlagsReturnValue = testContext.user.flagStore.featureFlags
                    retrievedFlags = testContext.user.flagStore.featureFlags
                    testContext.flagStoreMock.featureFlags = [:]
                    waitUntil { done in
                        testContext.subject.internalIdentify(newUser: testContext.user, testing: true, completion: done)
                    }
                }
                it("checks the flag cache for the user and environment") {
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 2 //called on init and subsequent identify
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                }
                it("restores user flags from cache") {
                    expect(testContext.flagStoreMock.replaceStoreReceivedArguments?.newFlags?.flagCollection) == retrievedFlags
                }
                it("converts cached data") {
                    expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 2 // both start and internalIdentify
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                }
            }
            context("when called without cached flags for the user") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(startOnline: false, timeOut: 10) { timedOut in
                            expect(timedOut) == true
                            done()
                        }
                    }
                    testContext.flagStoreMock.featureFlags = [:]
                }
                it("checks the flag cache for the user and environment") {
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                }
                it("does not restore user flags from cache") {
                    expect(testContext.flagStoreMock.replaceStoreCallCount) == 0
                }
                it("converts cached data") {
                    expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                }
            }
        }
    }

    private func setUserSpec() {
        var testContext: TestContext!

        describe("set user") {
            var newUser: LDUser!
            context("when the client is online") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(startOnline: true, completion: done)
                    }
                    testContext.featureFlagCachingMock.reset()
                    testContext.cacheConvertingMock.reset()
                    
                    newUser = LDUser.stub()
                    waitUntil(timeout: 5.0) { done in
                        testContext.subject.internalIdentify(newUser: newUser, testing: true, completion: done)
                        DispatchQueue(label: "WhenTheClientIsOnline").asyncAfter(deadline: .now() + 0.2) {
                            testContext.subject.flagChangeNotifier.notifyObservers(user: testContext.user, oldFlags: testContext.oldFlags)
                        }
                    }
                }
                it("changes to the new user") {
                    expect(testContext.subject.user) == newUser
                    expect(testContext.subject.service.user) == newUser
                    expect(testContext.serviceMock.clearFlagResponseCacheCallCount) == 1
                    expect(testContext.makeFlagSynchronizerService?.user) == newUser
                    expect(testContext.subject.eventReporter.service.user) == newUser
                }
                it("leaves the client online") {
                    expect(testContext.subject.isOnline) == true
                    expect(testContext.subject.eventReporter.isOnline) == true
                    expect(testContext.subject.flagSynchronizer.isOnline) == true
                }
                it("uncaches the new users flags") {
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == newUser.key
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                }
                it("records identify and summary events") {
                    expect(testContext.eventReporterMock.recordReceivedEvent?.kind == .identify).to(beTrue())
                }
                it("converts cached data") {
                    expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == newUser
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                }
            }
            context("when the client is offline") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(startOnline: false, completion: done)
                    }
                    testContext.featureFlagCachingMock.reset()
                    testContext.cacheConvertingMock.reset()

                    newUser = LDUser.stub()
                    waitUntil { done in
                        testContext.subject.internalIdentify(newUser: newUser, testing: true, completion: done)
                    }
                }
                it("changes to the new user") {
                    expect(testContext.subject.user) == newUser
                    expect(testContext.subject.service.user) == newUser
                    expect(testContext.serviceMock.clearFlagResponseCacheCallCount) == 1
                    expect(testContext.makeFlagSynchronizerService?.user) == newUser
                    expect(testContext.subject.eventReporter.service.user) == newUser
                }
                it("leaves the client offline") {
                    expect(testContext.subject.isOnline) == false
                    expect(testContext.subject.eventReporter.isOnline) == false
                    expect(testContext.subject.flagSynchronizer.isOnline) == false
                }
                it("uncaches the new users flags") {
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == newUser.key
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                }
                it("records identify and summary events") {
                    expect(testContext.eventReporterMock.recordReceivedEvent?.kind == .identify).to(beTrue())
                }
                it("converts cached data") {
                    expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == newUser
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                }
            }
            context("when the new user has cached feature flags") {
                beforeEach {
                    //offline makes no request to update flags...
                    waitUntil { done in
                        testContext = TestContext(startOnline: false, completion: done)
                    }
                    testContext.featureFlagCachingMock.reset()
                    newUser = LDUser.stub()
                    testContext.featureFlagCachingMock.retrieveFeatureFlagsReturnValue = newUser.featureFlags
                    testContext.cacheConvertingMock.reset()

                    waitUntil { done in
                        testContext.subject.internalIdentify(newUser: newUser, testing: true, completion: done)
                    }
                }
                it("restores the cached users feature flags") {
                    expect(testContext.subject.user) == newUser
                    expect(newUser.flagStoreMock.replaceStoreCallCount) == 1
                    expect(newUser.flagStoreMock.replaceStoreReceivedArguments?.newFlags?.flagCollection) == newUser.featureFlags
                }
                it("converts cached data") {
                    expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == newUser
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                }
            }
        }
    }

    private func setOnlineSpec() {
        describe("setOnline") {
            var testContext: TestContext!

            context("when the client is offline") {
                context("setting online") {
                    beforeEach {
                        waitUntil { done in
                            testContext = TestContext(startOnline: false, completion: done)
                        }

                        waitUntil { done in
                            testContext.subject.setOnline(true) {
                                done()
                            }
                            testContext.subject.flagChangeNotifier.notifyObservers(user: testContext.user, oldFlags: testContext.oldFlags)
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
                        waitUntil { done in
                            testContext = TestContext(startOnline: true, completion: done)
                        }

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
            context("when the client runs in the background") {
                OperatingSystem.allOperatingSystems.forEach { (os) in
                    context("on \(os)") {
                        context("while configured to enable background updates") {
                            context("and setting online") {
                                var targetRunThrottledCalls: Int!
                                beforeEach {
                                    waitUntil { done in
                                        testContext = TestContext(runMode: .background, operatingSystem: os, completion: done)
                                    }
                                    targetRunThrottledCalls = os.isBackgroundEnabled ? 1 : 0
                                    waitUntil(timeout: 10) { done in
                                        testContext.subject.setService(ClientServiceMockFactory().makeDarklyServiceProvider(config: testContext.subject.config, user: testContext.subject.user))
                                        testContext.subject.setOnline(true, completion: done)
                                        testContext.subject.flagChangeNotifier.notifyObservers(user: testContext.user, oldFlags: testContext.oldFlags)
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
                                waitUntil { done in
                                    testContext = TestContext(enableBackgroundUpdates: false, runMode: .background, operatingSystem: os, completion: done)
                                }
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
                    waitUntil { done in
                        testContext = TestContext(newConfig: LDConfig(mobileKey: ""), completion: done)
                    }
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

    private func closeSpec() {
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
                        priorRecordedEvents = testContext.eventReporterMock.recordCallCount

                        testContext.subject.close()
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
                        priorRecordedEvents = testContext.eventReporterMock.recordCallCount

                        testContext.subject.close()
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
            context("when already stopped") {
                beforeEach {
                    testContext.subject.close()
                    priorRecordedEvents = testContext.eventReporterMock.recordCallCount

                    testContext.subject.close()
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
                    //swiftlint:disable:next force_try
                    try! testContext.subject.trackEvent(key: event.key!, data: event.data)
                }
                it("records a custom event") {
                    expect(testContext.eventReporterMock.recordReceivedEvent?.key) == event.key
                    expect(testContext.eventReporterMock.recordReceivedEvent?.user) == event.user
                    expect(testContext.eventReporterMock.recordReceivedEvent?.data).toNot(beNil())
                    expect(AnyComparer.isEqual(testContext.eventReporterMock.recordReceivedEvent?.data, to: event.data)).to(beTrue())
                }
            }
            context("when client was stopped") {
                var priorRecordedEvents: Int!
                beforeEach {
                    testContext.subject.close()
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
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }
            }
            context("flag store contains the requested value") {
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
        }
    }

    private func observeSpec() {
        describe("observe") {
            var changedFlag: LDChangedFlag!
            var receivedChangedFlag: LDChangedFlag?
            var testContext: TestContext!
            beforeEach {
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }
                
                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                changedFlag = LDChangedFlag(key: DarklyServiceMock.FlagKeys.bool, oldValue: false, newValue: true)

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
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }
                    
                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                changedFlags = [DarklyServiceMock.FlagKeys.bool: LDChangedFlag(key: DarklyServiceMock.FlagKeys.bool,
                                                                               oldValue: false,
                                                                               newValue: true)]

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
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }
                
                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                changedFlags = [DarklyServiceMock.FlagKeys.bool: LDChangedFlag(key: DarklyServiceMock.FlagKeys.bool,
                                                                               oldValue: false,
                                                                               newValue: true)]

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
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }
                
                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()

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
        
        describe("observeConnectionModeChanged") {
            var testContext: TestContext!
            beforeEach {
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }
                
                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                
                testContext.subject.observeCurrentConnectionMode(owner: self, handler: {_ in
                    testContext.connectionModeChangedCallCount += 1
                })
            }
            it("registers a ConnectionModeChanged observer") {
                expect(testContext.changeNotifierMock.addConnectionModeChangedObserverCallCount) == 1
                expect(testContext.connectionModeChangedObserver?.owner) === self
                expect(testContext.connectionModeChangedHandler).toNot(beNil())
                testContext.connectionModeChangedHandler?(ConnectionInformation.ConnectionMode.offline)
                expect(testContext.connectionModeChangedCallCount) == 1
            }
        }

        describe("observeError") {
            var testContext: TestContext!
            beforeEach {
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }
                
                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()

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
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }
                
                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()

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
    private func onSyncCompleteSuccessReplacingFlagsSpec(streamingMode: LDStreamingMode, eventType: FlagUpdateType? = nil) {
        var testContext: TestContext!
        var newFlags: [LDFlagKey: FeatureFlag]!
        var eventType: FlagUpdateType?
        var updateDate: Date!

        beforeEach {
            waitUntil { done in
                testContext = TestContext(startOnline: true, completion: done)
            }
            eventType = streamingMode == .streaming ? eventType : nil
            waitUntil { done in
                testContext.subject.internalIdentify(newUser: testContext.user, testing: true, completion: done)
                DispatchQueue(label: "OnSyncCompleteSuccessReplacingFlags").asyncAfter(deadline: .now() + 0.2) {
                    testContext.subject.flagChangeNotifier.notifyObservers(user: testContext.user, oldFlags: testContext.oldFlags)
                }
            }
        }

        context("flags have different values") {
            beforeEach {
                let newBoolFeatureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, useAlternateValue: true)
                newFlags = testContext.user.flagStore.featureFlags
                newFlags[DarklyServiceMock.FlagKeys.bool] = newBoolFeatureFlag
                testContext.setFlagStoreCallbackToMimicRealFlagStore(newFlags: newFlags)

                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done
                    updateDate = Date()

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
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 1
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.featureFlags) == newFlags
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.user) == testContext.user
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated.isWithin(Constants.updateThreshold, of: updateDate)) == true
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .async
            }
            it("informs the flag change notifier of the changed flags") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == testContext.oldFlags).to(beTrue())
            }
        }
        context("a flag was added") {
            beforeEach {
                newFlags = testContext.user.flagStore.featureFlags
                newFlags[Constants.newFlagKey] = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.string, useAlternateValue: true)
                testContext.setFlagStoreCallbackToMimicRealFlagStore(newFlags: newFlags)
                
                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done
                    updateDate = Date()

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
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 1
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.featureFlags) == newFlags
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.user) == testContext.user
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated.isWithin(Constants.updateThreshold, of: updateDate)) == true
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .async
            }
            it("informs the flag change notifier of the changed flags") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == testContext.oldFlags).to(beTrue())
            }
        }
        context("a flag was removed") {
            beforeEach {
                newFlags = testContext.user.flagStore.featureFlags
                newFlags.removeValue(forKey: DarklyServiceMock.FlagKeys.dictionary)
                testContext.setFlagStoreCallbackToMimicRealFlagStore(newFlags: newFlags)

                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done
                    updateDate = Date()

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
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 1
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.featureFlags) == newFlags
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.user) == testContext.user
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated.isWithin(Constants.updateThreshold, of: updateDate)) == true
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .async
            }
            it("informs the flag change notifier of the changed flags") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == testContext.oldFlags).to(beTrue())
            }
        }
        context("there were no changes to the flags") {
            beforeEach {
                newFlags = testContext.user.flagStore.featureFlags

                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done
                    updateDate = Date()

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
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 1
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.featureFlags) == newFlags
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.user) == testContext.user
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated.isWithin(Constants.updateThreshold, of: updateDate)) == true
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .async
            }
            it("informs the flag change notifier of the unchanged flags") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == testContext.oldFlags).to(beTrue())
            }
        }
    }

    func onSyncCompleteStreamingPatchSpec() {
        var testContext: TestContext!
        var flagUpdateDictionary: [String: Any]!
        var oldFlags: [LDFlagKey: FeatureFlag]!
        var newFlags: [LDFlagKey: FeatureFlag]!
        var updateDate: Date!

        beforeEach {
            waitUntil { done in
                testContext = TestContext(startOnline: true, completion: done)
            }
            waitUntil { done in
                testContext.subject.internalIdentify(newUser: testContext.user, testing: true, completion: done)
                DispatchQueue(label: "OnSyncCompleteStreamingPatch").asyncAfter(deadline: .now() + 0.2) {
                    testContext.subject.flagChangeNotifier.notifyObservers(user: testContext.user, oldFlags: testContext.oldFlags)
                }
            }
        }

        context("update changes flags") {
            beforeEach {
                oldFlags = testContext.flagStoreMock.featureFlags
                flagUpdateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                               value: DarklyServiceMock.FlagValues.int + 1,
                                                                               variation: DarklyServiceMock.Constants.variation + 1,
                                                                               version: DarklyServiceMock.Constants.version + 1)
                let newIntFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.int, useAlternateValue: true)
                newFlags = oldFlags
                newFlags[DarklyServiceMock.FlagKeys.int] = newIntFlag
                testContext.setFlagStoreCallbackToMimicRealFlagStore(newFlags: newFlags)

                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done
                    updateDate = Date()

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
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 1
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.featureFlags) == newFlags
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.user) == testContext.user
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated.isWithin(Constants.updateThreshold, of: updateDate)) == true
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .async
            }
            it("informs the flag change notifier of the changed flag") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == oldFlags).to(beTrue())
            }
        }
        context("update does not change flags") {
            beforeEach {
                oldFlags = testContext.flagStoreMock.featureFlags
                flagUpdateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                               value: DarklyServiceMock.FlagValues.int + 1,
                                                                               variation: DarklyServiceMock.Constants.variation,
                                                                               version: DarklyServiceMock.Constants.version)
                newFlags = oldFlags

                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done
                    updateDate = Date()

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
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 1
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.featureFlags) == newFlags
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.user) == testContext.user
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated.isWithin(Constants.updateThreshold, of: updateDate)) == true
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .async
            }
            it("informs the flag change notifier of the unchanged flag") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == oldFlags).to(beTrue())
            }
        }
    }

    func onSyncCompleteDeleteFlagSpec() {
        var testContext: TestContext!
        var flagUpdateDictionary: [String: Any]!
        var oldFlags: [LDFlagKey: FeatureFlag]!
        var newFlags: [LDFlagKey: FeatureFlag]!
        var updateDate: Date!

        beforeEach {
            waitUntil { done in
                testContext = TestContext(startOnline: true, completion: done)
            }
            waitUntil { done in
                testContext.subject.internalIdentify(newUser: testContext.user, testing: true, completion: done)
                DispatchQueue(label: "OnSyncCompleteDelete").asyncAfter(deadline: .now() + 0.2) {
                    testContext.subject.flagChangeNotifier.notifyObservers(user: testContext.user, oldFlags: testContext.oldFlags)
                }
            }
        }

        context("delete changes flags") {
            beforeEach {
                oldFlags = testContext.flagStoreMock.featureFlags
                flagUpdateDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version + 1)
                newFlags = oldFlags
                newFlags.removeValue(forKey: DarklyServiceMock.FlagKeys.int)
                testContext.setFlagStoreCallbackToMimicRealFlagStore(newFlags: newFlags)

                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done
                    updateDate = Date()

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
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 1
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.featureFlags) == newFlags
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.user) == testContext.user
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated.isWithin(Constants.updateThreshold, of: updateDate)) == true
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .async
            }
            it("informs the flag change notifier of the changed flag") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == oldFlags).to(beTrue())
            }
        }
        context("delete does not change flags") {
            beforeEach {
                oldFlags = testContext.flagStoreMock.featureFlags
                flagUpdateDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version)

                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                waitUntil { done in
                    testContext.changeNotifierMock.notifyObserversCallback = done
                    updateDate = Date()

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
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 1
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.featureFlags) == oldFlags
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.user) == testContext.user
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated.isWithin(Constants.updateThreshold, of: updateDate)) == true
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .async
            }
            it("informs the flag change notifier of the unchanged flag") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.user) == testContext.user
                expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == oldFlags).to(beTrue())
            }
        }
    }

    func onSyncCompleteErrorSpec() {
        var testContext: TestContext!
        beforeEach {
            waitUntil { done in
                testContext = TestContext(startOnline: true, completion: done)
            }
        }

        context("there was an internal server error") {
            beforeEach {
                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                waitUntil { done in
                    testContext.errorNotifierMock.notifyObserversCallback = {
                        done()
                    }

                    testContext.onSyncComplete?(.error(.response(HTTPURLResponse(url: testContext.config.baseUrl,
                                                                                 statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                                                 httpVersion: DarklyServiceMock.Constants.httpVersion,
                                                                                 headerFields: nil))))
                }
            }
            it("does not take the client offline") {
                expect(testContext.subject.isOnline) == true
            }
            it("does not cache the users flags") {
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 0
            }
            it("does not call the flag change notifier") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 0
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
                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                waitUntil { done in
                    testContext.errorNotifierMock.notifyObserversCallback = {
                        done()
                    }

                    testContext.onSyncComplete?(.error(.request(DarklyServiceMock.Constants.error)))
                }
            }
            it("does not take the client offline") {
                expect(testContext.subject.isOnline) == true
            }
            it("does not cache the users flags") {
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 0
            }
            it("does not call the flag change notifier") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 0
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
                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                waitUntil { done in
                    testContext.errorNotifierMock.notifyObserversCallback = {
                        done()
                    }

                    testContext.onSyncComplete?(.error(.data(DarklyServiceMock.Constants.errorData)))
                }
            }
            it("does not take the client offline") {
                expect(testContext.subject.isOnline) == true
            }
            it("does not cache the users flags") {
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 0
            }
            it("does not call the flag change notifier") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 0
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
                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                waitUntil { done in
                    testContext.errorNotifierMock.notifyObserversCallback = {
                        done()
                    }

                    testContext.onSyncComplete?(.error(.response(HTTPURLResponse(url: testContext.config.baseUrl,
                                                                                 statusCode: HTTPURLResponse.StatusCodes.unauthorized,
                                                                                 httpVersion: DarklyServiceMock.Constants.httpVersion,
                                                                                 headerFields: nil))))
                }
            }
            it("takes the client offline") {
                expect(testContext.subject.isOnline) == false
            }
            it("does not cache the users flags") {
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 0
            }
            it("does not call the flag change notifier") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 0
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
                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                waitUntil { done in
                    testContext.errorNotifierMock.notifyObserversCallback = {
                        done()
                    }

                    testContext.onSyncComplete?(.error(.streamError(DummyError())))
                }
            }
            it("does not take the client offline") {
                expect(testContext.subject.isOnline) == true
            }
            it("does not cache the users flags") {
                expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 0
            }
            it("does not call the flag change notifier") {
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 0
            }
            it("calls the errorNotifier with a .streamError SynchronizingError") {
                expect(testContext.errorNotifierMock.notifyObserversCallCount) == 1
                expect(testContext.observedError as? SynchronizingError).toNot(beNil())
                guard case .streamError(let error)? = testContext.observedError as? SynchronizingError
                else {
                    fail("unexpected error reported")
                    return
                }
                expect(error is DummyError).to(beTrue())
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
                                    waitUntil { done in
                                        testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, runMode: .foreground, operatingSystem: os, completion: done)
                                    }

                                    waitUntil { done in
                                        NotificationCenter.default.post(name: testContext.environmentReporterMock.backgroundNotification!, object: self)
                                        DispatchQueue(label: "BackgroundUpdatesDisabled").asyncAfter(deadline: .now() + 0.2, execute: done)
                                    }
                                }
                                it("takes the sdk offline") {
                                    expect(testContext.subject.isOnline) == true
                                    expect(testContext.subject.runMode) == LDClientRunMode.background
                                    expect(testContext.eventReporterMock.isOnline) == true
                                    expect(testContext.flagSynchronizerMock.isOnline) == false
                                }
                            }
                            context("background updates enabled") {
                                beforeEach {
                                    waitUntil { done in
                                        testContext = TestContext(startOnline: true, enableBackgroundUpdates: true, runMode: .foreground, operatingSystem: os, completion: done)
                                    }

                                    waitUntil { done in
                                        NotificationCenter.default.post(name: testContext.environmentReporterMock.backgroundNotification!, object: self)
                                        DispatchQueue(label: "BackgroundUpdatesEnabled").asyncAfter(deadline: .now() + 0.2, execute: done)
                                    }
                                }
                                it("leaves the sdk online") {
                                    expect(testContext.subject.isOnline) == true
                                    expect(testContext.subject.runMode) == LDClientRunMode.background
                                    expect(testContext.eventReporterMock.isOnline) == true
                                    expect(testContext.flagSynchronizerMock.isOnline) == os.isBackgroundEnabled
                                    expect(testContext.flagSynchronizerMock.streamingMode) == os.backgroundStreamingMode
                                }
                            }
                        }
                    }
                }
                context("when offline") {
                    beforeEach {
                        testContext = TestContext(startOnline: false, runMode: .foreground)

                        NotificationCenter.default.post(name: testContext.environmentReporterMock.backgroundNotification!, object: self)
                    }
                    it("leaves the sdk offline") {
                        expect(testContext.subject.isOnline) == false
                        expect(testContext.subject.runMode) == LDClientRunMode.background
                        expect(testContext.eventReporterMock.isOnline) == false
                        expect(testContext.flagSynchronizerMock.isOnline) == false
                    }
                }
            }
        }

        describe("willEnterForeground notification") {
            context("after starting client") {
                OperatingSystem.allOperatingSystems.forEach { (os) in
                    context("on \(os)") {
                        context("when online at foreground notification") {
                            beforeEach {
                                waitUntil { done in
                                    testContext = TestContext(startOnline: true, runMode: .background, operatingSystem: os, completion: done)
                                }

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
        }

        describe("change run mode on macOS") {
            context("while online") {
                context("and running in the foreground") {
                    context("set background") {
                        context("with background updates enabled") {
                            context("streaming mode") {
                                beforeEach {
                                    waitUntil { done in
                                        testContext = TestContext(startOnline: true, streamingMode: .streaming, enableBackgroundUpdates: true, runMode: .foreground, operatingSystem: .macOS, completion: done)
                                    }

                                    waitUntil { done in
                                        testContext.subject.setRunMode(.background)
                                        DispatchQueue(label: "BackgroundEnableStreamingMode").asyncAfter(deadline: .now() + 0.2, execute: done)
                                    }
                                }
                                it("leaves the event reporter online") {
                                    expect(testContext.eventReporterMock.isOnline) == true
                                }
                                it("sets the flag synchronizer for background streaming online") {
                                    expect(testContext.flagSynchronizerMock.isOnline) == true
                                    expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.streaming
                                }
                            }
                            context("polling mode") {
                                beforeEach {
                                    waitUntil { done in
                                        testContext = TestContext(startOnline: true, streamingMode: .polling, enableBackgroundUpdates: true, runMode: .foreground, operatingSystem: .macOS, completion: done)
                                    }
                                    waitUntil { done in
                                        testContext.subject.setRunMode(.background)
                                        DispatchQueue(label: "BackgroundEnabledPollingMode").asyncAfter(deadline: .now() + 0.2, execute: done)
                                    }
                                }
                                it("leaves the event reporter online") {
                                    expect(testContext.eventReporterMock.isOnline) == true
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
                                waitUntil { done in
                                    testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, runMode: .foreground, operatingSystem: .macOS, completion: done)
                                }

                                waitUntil { done in
                                    testContext.subject.setRunMode(.background)
                                    DispatchQueue(label: "BackgroundDisabled").asyncAfter(deadline: .now() + 0.2, execute: done)
                                }
                            }
                            it("leaves the event reporter online") {
                                expect(testContext.eventReporterMock.isOnline) == true
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
                            waitUntil { done in
                                testContext = TestContext(startOnline: true, runMode: .foreground, operatingSystem: .macOS, completion: done)
                            }
                            eventReporterIsOnlineSetCount = testContext.eventReporterMock.isOnlineSetCount
                            flagSynchronizerIsOnlineSetCount = testContext.flagSynchronizerMock.isOnlineSetCount
                            makeFlagSynchronizerCallCount = testContext.serviceFactoryMock.makeFlagSynchronizerCallCount

                            waitUntil { done in
                                testContext.subject.setRunMode(.foreground)
                                DispatchQueue(label: "SetForeground").asyncAfter(deadline: .now() + 0.2, execute: done)
                            }
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
                            waitUntil { done in
                                testContext = TestContext(startOnline: true, enableBackgroundUpdates: true, runMode: .background, operatingSystem: .macOS, completion: done)
                            }
                            
                            NotificationCenter.default.post(name: testContext.environmentReporterMock.backgroundNotification!, object: self)
                            eventReporterIsOnlineSetCount = testContext.eventReporterMock.isOnlineSetCount
                            flagSynchronizerIsOnlineSetCount = testContext.flagSynchronizerMock.isOnlineSetCount
                            makeFlagSynchronizerCallCount = testContext.serviceFactoryMock.makeFlagSynchronizerCallCount

                            waitUntil { done in
                                testContext.subject.setRunMode(.background)
                                DispatchQueue(label: "RunningInTheBackgroundSetBackground").asyncAfter(deadline: .now() + 0.2, execute: done)
                            }
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
                                waitUntil { done in
                                    testContext = TestContext(startOnline: true, streamingMode: .streaming, runMode: .background, operatingSystem: .macOS, completion: done)
                                }

                                waitUntil { done in
                                    testContext.subject.setRunMode(.foreground)
                                    DispatchQueue(label: "SetForegroundStreamingMode").asyncAfter(deadline: .now() + 0.2, execute: done)
                                }
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
                                waitUntil { done in
                                    testContext = TestContext(startOnline: true, streamingMode: .polling, runMode: .background, operatingSystem: .macOS, completion: done)
                                }

                                waitUntil { done in
                                    testContext.subject.setRunMode(.foreground)
                                    DispatchQueue(label: "SetForegroundPollingMode").asyncAfter(deadline: .now() + 0.2, execute: done)
                                }
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
                                waitUntil { done in
                                    testContext = TestContext(startOnline: false, enableBackgroundUpdates: true, runMode: .foreground, operatingSystem: .macOS, completion: done)
                                }

                                waitUntil { done in
                                    testContext.subject.setRunMode(.background)
                                    DispatchQueue(label: "SetBackgroundWithBackgroundEnabled").asyncAfter(deadline: .now() + 0.2, execute: done)
                                }
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
                                waitUntil { done in
                                    testContext = TestContext(startOnline: false, enableBackgroundUpdates: false, runMode: .foreground, operatingSystem: .macOS, completion: done)
                                }

                                waitUntil { done in
                                    testContext.subject.setRunMode(.background)
                                    DispatchQueue(label: "SetBackgroundWithBackgroundDisabled").asyncAfter(deadline: .now() + 0.2, execute: done)
                                }
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
                            waitUntil { done in
                                testContext = TestContext(startOnline: false, runMode: .foreground, operatingSystem: .macOS, completion: done)
                            }
                                
                            eventReporterIsOnlineSetCount = testContext.eventReporterMock.isOnlineSetCount
                            flagSynchronizerIsOnlineSetCount = testContext.flagSynchronizerMock.isOnlineSetCount
                            makeFlagSynchronizerCallCount = testContext.serviceFactoryMock.makeFlagSynchronizerCallCount

                            waitUntil { done in
                                testContext.subject.setRunMode(.foreground)
                                DispatchQueue(label: "SetForegroundNoChange").asyncAfter(deadline: .now() + 0.2, execute: done)
                            }
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
                            waitUntil { done in
                                testContext = TestContext(startOnline: false, runMode: .background, operatingSystem: .macOS, completion: done)
                            }
                                
                            eventReporterIsOnlineSetCount = testContext.eventReporterMock.isOnlineSetCount
                            flagSynchronizerIsOnlineSetCount = testContext.flagSynchronizerMock.isOnlineSetCount
                            makeFlagSynchronizerCallCount = testContext.serviceFactoryMock.makeFlagSynchronizerCallCount

                            waitUntil { done in
                                testContext.subject.setRunMode(.background)
                                DispatchQueue(label: "SetBackground").asyncAfter(deadline: .now() + 0.2, execute: done)
                            }
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
                                waitUntil { done in
                                    testContext = TestContext(startOnline: false, streamingMode: .streaming, runMode: .background, operatingSystem: .macOS, completion: done)
                                }

                                waitUntil { done in
                                    testContext.subject.setRunMode(.foreground)
                                    DispatchQueue(label: "StreamingMode").asyncAfter(deadline: .now() + 0.2, execute: done)
                                }
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
                                waitUntil { done in
                                    testContext = TestContext(startOnline: false, streamingMode: .polling, runMode: .background, operatingSystem: .macOS, completion: done)
                                }

                                waitUntil { done in
                                    testContext.subject.setRunMode(.foreground)
                                    DispatchQueue(label: "ForegroundPollingMode").asyncAfter(deadline: .now() + 0.2, execute: done)
                                }
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
                        waitUntil { done in
                            testContext = TestContext(startOnline: true, runMode: .foreground, operatingSystem: os, completion: done)
                        }
                    }
                    it("sets the flag synchronizer streaming mode") {
                        expect(testContext.makeFlagSynchronizerStreamingMode) == (os.isStreamingEnabled ? LDStreamingMode.streaming : LDStreamingMode.polling)
                    }
                }
            }
        }
    }

    private func flushSpec() {
        var testContext: TestContext!

        describe("flush") {
            beforeEach {
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }
                testContext.subject.flush()
            }
            it("tells the event reporter to report events") {
                expect(testContext.eventReporterMock.flushCallCount) == 1
            }
        }
        
        describe("flush when closing") {
           beforeEach {
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }
               testContext.subject.close()
           }
           it("tells the event reporter to report events") {
               expect(testContext.eventReporterMock.flushCallCount) == 1
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
                    waitUntil { done in
                        testContext = TestContext(completion: done)
                    }
                    featureFlags = testContext.subject.user.flagStore.featureFlags
                    featureFlagValues = testContext.subject.allFlags
                }
                it("returns a matching dictionary of flag keys and values") {
                    expect(featureFlagValues?.count) == featureFlags.count - 1 //nil is omitted
                    featureFlags.keys.forEach { (flagKey) in
                        expect(AnyComparer.isEqual(featureFlagValues?[flagKey], to: featureFlags[flagKey]?.value)).to(beTrue())
                    }
                }
            }
        }
    }
    
    private func connectionInformationSpec() {
        var testContext: TestContext!
        
        describe("ConnectionInformation") {
            context("when client was started in foreground") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(startOnline: true, streamingMode: .streaming, runMode: .foreground, completion: done)
                    }
                }
                it("returns a ConnectionInformation object with currentConnectionMode.establishingStreamingConnection") {
                    expect(testContext.subject.isOnline) == true
                    expect(testContext.subject.connectionInformation.currentConnectionMode).to(equal(.establishingStreamingConnection))
                }
                it("returns a String from toString") {
                    expect(testContext.subject.connectionInformation.description).to(beAKindOf(String.self))
                }
            }
            context("when client was started in background") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(startOnline: true, streamingMode: .streaming, runMode: .background, completion: done)
                    }
                }
                it("returns a ConnectionInformation object with currentConnectionMode.offline") {
                    expect(testContext.subject.connectionInformation.currentConnectionMode).to(equal(.offline))
                }
                it("returns a String from toString") {
                    expect(testContext.subject.connectionInformation.description).to(beAKindOf(String.self))
                }
            }
            context("when offline and client started") {
                beforeEach {
                    testContext = TestContext(startOnline: false)
                }
                it("leaves the sdk offline") {
                    expect(testContext.subject.isOnline) == false
                    expect(testContext.eventReporterMock.isOnline) == false
                    expect(testContext.flagSynchronizerMock.isOnline) == false
                    expect(testContext.subject.connectionInformation.currentConnectionMode).to(equal(.offline))
                }
            }
            context("when client was not started") {
                beforeEach {
                    testContext = TestContext()
                }
                it("returns nil") {
                    expect(testContext.subject.connectionInformation.currentConnectionMode).to(equal(.offline))
                }
            }
        }
    }
    
    private func variationDetailSpec() {
        var testContext: TestContext!
        
        describe("variationDetail") {
            context("when client was started and flag key doesn't exist") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(startOnline: true, streamingMode: .streaming, runMode: .foreground, completion: done)
                    }
                }
                it("returns FLAG_NOT_FOUND") {
                    let detail = testContext.subject.variationDetail(forKey: BadFlagKeys.bool, fallback: DefaultFlagValues.bool).reason
                    if let errorKind = detail?["errorKind"] as? String {
                        expect(errorKind) == "FLAG_NOT_FOUND"
                    }
                }
            }
        }
    }
}

extension FeatureFlagCachingMock {
    func reset() {
        retrieveFeatureFlagsCallCount = 0
        retrieveFeatureFlagsReceivedArguments = nil
        retrieveFeatureFlagsReturnValue = nil
        storeFeatureFlagsCallCount = 0
        storeFeatureFlagsReceivedArguments = nil
    }
}

extension OperatingSystem {
    var backgroundStreamingMode: LDStreamingMode {
        return self == .macOS ? .streaming : .polling
    }
}

extension LDUser {
    var flagStoreMock: FlagMaintainingMock {
        return flagStore as! FlagMaintainingMock
    }
}

extension CacheConvertingMock {
    func reset() {
        convertCacheDataCallCount = 0
        convertCacheDataReceivedArguments = nil
    }
}

extension LDConfig {
    func copyReplacingMobileKey(_ mobileKey: MobileKey) -> LDConfig {
        var newConfig = LDConfig(mobileKey: mobileKey)
        newConfig.baseUrl = baseUrl
        newConfig.eventsUrl = eventsUrl
        newConfig.streamUrl = streamUrl
        newConfig.eventCapacity = eventCapacity
        newConfig.connectionTimeout = connectionTimeout
        newConfig.eventFlushInterval = eventFlushInterval
        newConfig.flagPollingInterval = flagPollingInterval
        newConfig.backgroundFlagPollingInterval = backgroundFlagPollingInterval
        newConfig.streamingMode = streamingMode
        newConfig.enableBackgroundUpdates = enableBackgroundUpdates
        newConfig.startOnline = startOnline
        newConfig.allUserAttributesPrivate = allUserAttributesPrivate
        newConfig.privateUserAttributes = privateUserAttributes
        newConfig.useReport = useReport
        newConfig.inlineUserInEvents = inlineUserInEvents
        newConfig.isDebugMode = isDebugMode

        return newConfig
    }
}
