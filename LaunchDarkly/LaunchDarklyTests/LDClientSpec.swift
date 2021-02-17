//
//  LDClientSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
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
            subject.serviceFactory as? ClientServiceMockFactory
        }
        var serviceMock: DarklyServiceMock! {
            subject.service as? DarklyServiceMock
        }
        var featureFlagCachingMock: FeatureFlagCachingMock! {
            subject.flagCache as? FeatureFlagCachingMock
        }
        var cacheConvertingMock: CacheConvertingMock! {
            subject.cacheConverter as? CacheConvertingMock
        }
        var flagStoreMock: FlagMaintainingMock! {
            subject.flagStore as? FlagMaintainingMock
        }
        var flagSynchronizerMock: LDFlagSynchronizingMock! {
            subject.flagSynchronizer as? LDFlagSynchronizingMock
        }
        var eventReporterMock: EventReportingMock! {
            subject.eventReporter as? EventReportingMock
        }
        var changeNotifierMock: FlagChangeNotifyingMock! {
            subject.flagChangeNotifier as? FlagChangeNotifyingMock
        }
        var errorNotifierMock: ErrorNotifyingMock! {
            subject.errorNotifier as? ErrorNotifyingMock
        }
        var environmentReporterMock: EnvironmentReportingMock! {
            subject.environmentReporter as? EnvironmentReportingMock
        }
        // makeFlagSynchronizer getters
        var makeFlagSynchronizerStreamingMode: LDStreamingMode? {
            serviceFactoryMock.makeFlagSynchronizerReceivedParameters?.streamingMode
        }
        var makeFlagSynchronizerPollingInterval: TimeInterval? {
            serviceFactoryMock.makeFlagSynchronizerReceivedParameters?.pollingInterval
        }
        var makeFlagSynchronizerService: DarklyServiceProvider? {
            serviceFactoryMock.makeFlagSynchronizerReceivedParameters?.service
        }
        var observedError: Error? {
            errorNotifierMock.notifyObserversReceivedError
        }
        var onSyncComplete: FlagSyncCompleteClosure? {
            serviceFactoryMock.onFlagSyncComplete
        }
        var recordedEvent: LaunchDarkly.Event? {
            eventReporterMock.recordReceivedEvent
        }
        // user flags
        var oldFlags: [LDFlagKey: FeatureFlag]!
        // throttler
        var throttlerMock: ThrottlingMock? {
            subject.throttler as? ThrottlingMock
        }

        init(newUser: LDUser? = nil,
             noUser: Bool = false,
             newConfig: LDConfig? = nil,
             startOnline: Bool = false,
             streamingMode: LDStreamingMode = .streaming,
             enableBackgroundUpdates: Bool = true,
             runMode: LDClientRunMode = .foreground,
             operatingSystem: OperatingSystem? = nil,
             autoAliasingOptOut: Bool = true,
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
            config.autoAliasingOptOut = autoAliasingOptOut
            user = newUser ?? LDUser.stub()
            let stubFlags = FlagMaintainingMock(flags: FlagMaintainingMock.stubFlags(includeNullValue: true, includeVersions: true))
            clientServiceFactory.makeFlagStoreReturnValue = stubFlags
            oldFlags = stubFlags.featureFlags

            let flagNotifier = (ClientServiceFactory().makeFlagChangeNotifier() as! FlagChangeNotifier)
            
            LDClient.start(serviceFactory: clientServiceFactory, config: config, user: noUser ? nil : user, flagCache: clientServiceFactory.makeFeatureFlagCache(), flagNotifier: flagNotifier) {
                self.startCompletion(runMode: runMode, completion: completion)
            }
            flagNotifier.notifyObservers(flagStore: stubFlags, oldFlags: self.oldFlags)
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
             autoAliasingOptOut: Bool = true,
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
            config.autoAliasingOptOut = autoAliasingOptOut
            user = newUser ?? LDUser.stub()
            let stubFlags = FlagMaintainingMock(flags: FlagMaintainingMock.stubFlags(includeNullValue: true, includeVersions: true))
            clientServiceFactory.makeFlagStoreReturnValue = stubFlags
            oldFlags = stubFlags.featureFlags

            let flagNotifier = (ClientServiceFactory().makeFlagChangeNotifier() as! FlagChangeNotifier)
            
            LDClient.start(serviceFactory: clientServiceFactory, config: config, user: noUser ? nil : user, startWaitSeconds: timeOut, flagCache: clientServiceFactory.makeFeatureFlagCache(), flagNotifier: flagNotifier) { timedOut in
                self.startCompletion(runMode: runMode, timedOut: timedOut, timeOutCompletion: timeOutCompletion)
            }
            if !forceTimeout {
                flagNotifier.notifyObservers(flagStore: stubFlags, oldFlags: self.oldFlags)
            }
        }

        func startCompletion(runMode: LDClientRunMode, timedOut: Bool = false, completion: (() -> Void)? = nil, timeOutCompletion: ((_ timedOut: Bool) -> Void)? = nil) {
            subject = LDClient.get()

            if runMode == .background {
                subject.setRunMode(.background)
            }
            completion?()
            timeOutCompletion?(timedOut)
        }
    }

    override func spec() {
        startSpec()
        startWithTimeoutSpec()
        moveToBackgroundSpec()
        identifySpec()
        setOnlineSpec()
        closeSpec()
        trackEventSpec()
        variationSpec()
        observeSpec()
        onSyncCompleteSpec()
        runModeSpec()
        streamingModeSpec()
        flushSpec()
        allFlagsSpec()
        connectionInformationSpec()
        variationDetailSpec()
        aliasingSpec()
    }

    private func aliasingSpec() {
        describe("aliasing") {
            var ctx: TestContext!

            context("automatic aliasing from anonymous to user") {
                beforeEach {
                    waitUntil { done in 
                        ctx = TestContext(newUser: LDUser(isAnonymous: true), autoAliasingOptOut: false, completion: done)
                    }
                    let notAnonymous = LDUser(key: "something", isAnonymous: false)
                    waitUntil { done in 
                        ctx.subject.internalIdentify(newUser: notAnonymous, completion: done)
                    }
                }

                it("records an alias and identify event") {
                    // init, identify, and alias event
                    expect(ctx.eventReporterMock.recordCallCount) == 3
                    expect(ctx.recordedEvent?.kind) == .alias
                }
            }

            context("automatic aliasing from user to user") {
                beforeEach {
                    waitUntil { done in 
                        ctx = TestContext(newUser: LDUser(isAnonymous: false), completion: done)
                    }
                    let notAnonymous = LDUser(key: "something", isAnonymous: false)
                    waitUntil { done in 
                        ctx.subject.internalIdentify(newUser: notAnonymous, completion: done)
                    }
                }

                it("doesnt record an alias event") {
                    // init and identify event
                    expect(ctx.eventReporterMock.recordCallCount) == 2
                    expect(ctx.recordedEvent?.kind) == .identify
                }
            }

            context("automatic aliasing from anonymous to anonymous") {
                beforeEach {
                    waitUntil { done in 
                        ctx = TestContext(newUser: LDUser(isAnonymous: false), completion: done)
                    }
                    let notAnonymous = LDUser(key: "something", isAnonymous: false)
                    waitUntil { done in 
                        ctx.subject.internalIdentify(newUser: notAnonymous, completion: done)
                    }
                }

                it("doesnt record an alias event") {
                    // init and identify event
                    expect(ctx.eventReporterMock.recordCallCount) == 2
                    expect(ctx.recordedEvent?.kind) == .identify
                }
            }
        }
    }

    private func startSpec() {
        describe("start") {
            var testContext: TestContext!

            context("when configured to start online") {
                beforeEach {
                    waitUntil(timeout: .seconds(10)) { done in
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
                it("starts in foreground") {
                    expect(testContext.subject.runMode) == .foreground
                }
            }
            context("when configured to start offline") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(completion: done)
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
                it("starts in foreground") {
                    expect(testContext.subject.runMode) == .foreground
                }
            }
            context("when called without user") {
                context("after setting user") {
                    beforeEach {
                        waitUntil { done in
                            testContext = TestContext(noUser: true, startOnline: true, completion: done)
                        }

                        waitUntil { done in
                            testContext.subject.internalIdentify(newUser: testContext.user, completion: done)
                            testContext.subject.flagChangeNotifier.notifyObservers(flagStore: testContext.flagStoreMock, oldFlags: testContext.oldFlags)
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
                        testContext = TestContext(completion: done)
                    }
                    testContext.featureFlagCachingMock.retrieveFeatureFlagsReturnValue = testContext.flagStoreMock.featureFlags
                    retrievedFlags = testContext.flagStoreMock.featureFlags
                    waitUntil { done in
                        testContext.subject.internalIdentify(newUser: testContext.user, completion: done)
                    }
                }
                it("checks the flag cache for the user and environment") {
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 2 //called on init and subsequent identify
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                }
                it("restores user flags from cache") {
                    expect(testContext.flagStoreMock.replaceStoreReceivedArguments?.newFlags.flagCollection) == retrievedFlags
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
                        testContext = TestContext(completion: done)
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
                    waitUntil(timeout: .seconds(15)) { done in
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
                    waitUntil(timeout: .seconds(10)) { done in
                        testContext = TestContext(startOnline: true, timeOut: 2.0, forceTimeout: true) { timedOut in
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
                    waitUntil(timeout: .seconds(15)) { done in
                        testContext = TestContext(timeOut: 10) { timedOut in
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
                            testContext.subject.internalIdentify(newUser: testContext.user, completion: done)
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
                            testContext = TestContext(noUser: true, timeOut: 3) { timedOut in
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
                        testContext = TestContext(timeOut: 10) { timedOut in
                            expect(timedOut) == true
                            done()
                        }
                    }
                    testContext.featureFlagCachingMock.retrieveFeatureFlagsReturnValue = testContext.flagStoreMock.featureFlags
                    retrievedFlags = testContext.flagStoreMock.featureFlags
                    waitUntil { done in
                        testContext.subject.internalIdentify(newUser: testContext.user, completion: done)
                    }
                }
                it("checks the flag cache for the user and environment") {
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 2 //called on init and subsequent identify
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                }
                it("restores user flags from cache") {
                    expect(testContext.flagStoreMock.replaceStoreReceivedArguments?.newFlags.flagCollection) == retrievedFlags
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
                        testContext = TestContext(timeOut: 10) { timedOut in
                            expect(timedOut) == true
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

    func moveToBackgroundSpec() {
        describe("moveToBackground") {
            var testContext: TestContext!
            context("when configured to allow background updates") {
                OperatingSystem.allOperatingSystems.forEach { os in
                    context("on \(os)") {
                        beforeEach {
                            waitUntil { done in
                                testContext = TestContext(startOnline: true, operatingSystem: os, completion: done)
                            }
                            testContext.subject.setRunMode(.background)
                        }
                        it("takes the client and service objects online when background enabled") {
                            expect(testContext.subject.isOnline) == true
                            expect(testContext.subject.flagSynchronizer.isOnline) == os.isBackgroundEnabled
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
            context("when configured to not allow background updates") {
                OperatingSystem.allOperatingSystems.forEach { os in
                    context("on \(os)") {
                        beforeEach {
                            waitUntil { done in
                                testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, operatingSystem: os, completion: done)
                            }
                            testContext.subject.setRunMode(.background)
                        }
                        it("leaves the client and service objects offline") {
                            expect(testContext.subject.isOnline) == true
                            expect(testContext.subject.flagSynchronizer.isOnline) == false
                            expect(testContext.subject.eventReporter.isOnline) == true
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
        }
    }

    private func identifySpec() {
        var testContext: TestContext!

        describe("identify") {
            var newUser: LDUser!
            var stubFlags: FlagMaintainingMock!
            context("when the client is online") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(startOnline: true, completion: done)
                    }
                    testContext.featureFlagCachingMock.reset()
                    testContext.cacheConvertingMock.reset()
                    
                    newUser = LDUser.stub()
                    waitUntil(timeout: .seconds(5)) { done in
                        testContext.subject.internalIdentify(newUser: newUser, completion: done)
                        testContext.subject.flagChangeNotifier.notifyObservers(flagStore: testContext.flagStoreMock, oldFlags: testContext.oldFlags)
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
                        testContext = TestContext(completion: done)
                    }
                    testContext.featureFlagCachingMock.reset()
                    testContext.cacheConvertingMock.reset()

                    newUser = LDUser.stub()
                    waitUntil { done in
                        testContext.subject.internalIdentify(newUser: newUser, completion: done)
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
                        testContext = TestContext(completion: done)
                    }
                    testContext.featureFlagCachingMock.reset()
                    newUser = LDUser.stub()
                    stubFlags = FlagMaintainingMock(flags: FlagMaintainingMock.stubFlags(includeNullValue: true, includeVersions: true))

                    testContext.featureFlagCachingMock.retrieveFeatureFlagsReturnValue = stubFlags.featureFlags
                    testContext.cacheConvertingMock.reset()

                    waitUntil { done in
                        testContext.subject.internalIdentify(newUser: newUser, completion: done)
                    }
                }
                it("restores the cached users feature flags") {
                    expect(testContext.subject.user) == newUser
                    expect(testContext.flagStoreMock.replaceStoreCallCount) == 1
                    expect(testContext.flagStoreMock.replaceStoreReceivedArguments?.newFlags.flagCollection) == stubFlags?.featureFlags
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
                            testContext = TestContext(completion: done)
                        }

                        waitUntil { done in
                            testContext.subject.setOnline(true) {
                                done()
                            }
                            testContext.subject.flagChangeNotifier.notifyObservers(flagStore: testContext.flagStoreMock, oldFlags: testContext.oldFlags)
                        }
                    }
                    it("sets the client and service objects online") {
                        expect(testContext.throttlerMock?.runThrottledCallCount) == 1
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
                        expect(testContext.throttlerMock?.runThrottledCallCount) == 0
                        expect(testContext.subject.isOnline) == false
                        expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                        expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                    }
                }
            }
            context("when the client runs in the background") {
                OperatingSystem.allOperatingSystems.forEach { os in
                    context("on \(os)") {
                        context("while configured to enable background updates") {
                            context("and setting online") {
                                var targetRunThrottledCalls: Int!
                                beforeEach {
                                    waitUntil { done in
                                        testContext = TestContext(runMode: .background, operatingSystem: os, completion: done)
                                    }
                                    targetRunThrottledCalls = os.isBackgroundEnabled ? 1 : 0
                                    waitUntil(timeout: .seconds(10)) { done in
                                        testContext.subject.setService(ClientServiceMockFactory().makeDarklyServiceProvider(config: testContext.subject.config, user: testContext.subject.user))
                                        testContext.subject.setOnline(true, completion: done)
                                        testContext.subject.flagChangeNotifier.notifyObservers(flagStore: testContext.flagStoreMock, oldFlags: testContext.oldFlags)
                                    }
                                }
                                it("takes the client and service objects online") {
                                    expect(testContext.throttlerMock?.runThrottledCallCount) == targetRunThrottledCalls
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
                                    expect(testContext.throttlerMock?.runThrottledCallCount) == 0
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
                    expect(testContext.throttlerMock?.runThrottledCallCount) == 0
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
            context("when started") {
                beforeEach {
                    priorRecordedEvents = 0
                }
                context("and online") {
                    beforeEach {
                        waitUntil { done in
                            testContext = TestContext(startOnline: true, completion: done)
                        }
                        event = Event.stub(.custom, with: testContext.user)
                        priorRecordedEvents = testContext.eventReporterMock.recordCallCount

                        testContext.subject.close()
                    }
                    it("takes the client offline") {
                        expect(testContext.subject.isOnline) == false
                    }
                    it("stops recording events") {
                        expect(try testContext.subject.track(key: event.key!)).toNot(throwError())
                        expect(testContext.eventReporterMock.recordCallCount) == priorRecordedEvents
                    }
                    it("flushes the event reporter") {
                        expect(testContext.eventReporterMock.flushCallCount) == 1
                    }
                }
                context("and offline") {
                    beforeEach {
                        waitUntil { done in
                            testContext = TestContext(completion: done)
                        }
                        event = Event.stub(.custom, with: testContext.user)
                        priorRecordedEvents = testContext.eventReporterMock.recordCallCount

                        testContext.subject.close()
                    }
                    it("leaves the client offline") {
                        expect(testContext.subject.isOnline) == false
                    }
                    it("stops recording events") {
                        expect(try testContext.subject.track(key: event.key!)).toNot(throwError())
                        expect(testContext.eventReporterMock.recordCallCount) == priorRecordedEvents
                    }
                    it("flushes the event reporter") {
                        expect(testContext.eventReporterMock.flushCallCount) == 1
                    }
                }
            }
            context("when already stopped") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(completion: done)
                    }
                    event = Event.stub(.custom, with: testContext.user)
                    testContext.subject.close()
                    priorRecordedEvents = testContext.eventReporterMock.recordCallCount

                    testContext.subject.close()
                }
                it("leaves the client offline") {
                    expect(testContext.subject.isOnline) == false
                }
                it("stops recording events") {
                    expect(try testContext.subject.track(key: event.key!)).toNot(throwError())
                    expect(testContext.eventReporterMock.recordCallCount) == priorRecordedEvents
                }
                it("flushes the event reporter") {
                    expect(testContext.eventReporterMock.flushCallCount) == 1
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
                    try! testContext.subject.track(key: event.key!, data: event.data)
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

                    try! testContext.subject.track(key: event.key!, data: event.data)
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
                context("non-Optional default value") {
                    it("returns the flag value") {
                        //The casts in the expect() calls allow the compiler to determine which variation method to use. This test calls the non-Optional variation method
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool) as Bool) == DarklyServiceMock.FlagValues.bool
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.int, defaultValue: DefaultFlagValues.int) as Int) == DarklyServiceMock.FlagValues.int
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.double, defaultValue: DefaultFlagValues.double) as Double) == DarklyServiceMock.FlagValues.double
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.string, defaultValue: DefaultFlagValues.string) as String) == DarklyServiceMock.FlagValues.string
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.array, defaultValue: DefaultFlagValues.array) == DarklyServiceMock.FlagValues.array).to(beTrue())
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, defaultValue: DefaultFlagValues.dictionary) as [String: Any]
                            == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                    }
                    it("records a flag evaluation event") {
                        _ = testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == DarklyServiceMock.FlagKeys.bool
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DarklyServiceMock.FlagValues.bool)).to(beTrue())
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag) == testContext.flagStoreMock.featureFlags[DarklyServiceMock.FlagKeys.bool]
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
                context("Optional default value") {
                    it("returns the flag value") {
                        //The casts in the expect() calls allow the compiler to determine which variation method to use. This test calls the Optional variation method
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool as Bool?)) == DarklyServiceMock.FlagValues.bool
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.int, defaultValue: DefaultFlagValues.int  as Int?)) == DarklyServiceMock.FlagValues.int
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.double, defaultValue: DefaultFlagValues.double as Double?)) == DarklyServiceMock.FlagValues.double
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.string, defaultValue: DefaultFlagValues.string as String?)) == DarklyServiceMock.FlagValues.string
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.array, defaultValue: DefaultFlagValues.array as Array?) == DarklyServiceMock.FlagValues.array).to(beTrue())
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, defaultValue: DefaultFlagValues.dictionary as [String: Any]?)
                            == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                    }
                    it("records a flag evaluation event") {
                        //The cast in the variation call directs the compiler to the Optional variation method
                        _ = testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool as Bool?)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == DarklyServiceMock.FlagKeys.bool
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DarklyServiceMock.FlagValues.bool)).to(beTrue())
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag) == testContext.flagStoreMock.featureFlags[DarklyServiceMock.FlagKeys.bool]
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
                context("No default value") {
                    it("returns the flag value") {
                        //The casts in the expect() calls allow the compiler to determine the return type.
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: nil as Bool?)) == DarklyServiceMock.FlagValues.bool
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.int, defaultValue: nil  as Int?)) == DarklyServiceMock.FlagValues.int
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.double, defaultValue: nil as Double?)) == DarklyServiceMock.FlagValues.double
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.string, defaultValue: nil as String?)) == DarklyServiceMock.FlagValues.string
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.array, defaultValue: nil as Array?) == DarklyServiceMock.FlagValues.array).to(beTrue())
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, defaultValue: nil as [String: Any]?)
                            == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                    }
                    it("records a flag evaluation event") {
                        //The cast in the variation call allows the compiler to determine the return type
                        _ = testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: nil as Bool?)
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
                context("non-Optional default value") {
                    it("returns the default value") {
                        //The casts in the expect() calls allow the compiler to determine which variation method to use. This test calls the non-Optional variation method
                        expect(testContext.subject.variation(forKey: BadFlagKeys.bool, defaultValue: DefaultFlagValues.bool) as Bool) == DefaultFlagValues.bool
                        expect(testContext.subject.variation(forKey: BadFlagKeys.int, defaultValue: DefaultFlagValues.int) as Int) == DefaultFlagValues.int
                        expect(testContext.subject.variation(forKey: BadFlagKeys.double, defaultValue: DefaultFlagValues.double) as Double) == DefaultFlagValues.double
                        expect(testContext.subject.variation(forKey: BadFlagKeys.string, defaultValue: DefaultFlagValues.string) as String) == DefaultFlagValues.string
                        expect(testContext.subject.variation(forKey: BadFlagKeys.array, defaultValue: DefaultFlagValues.array) == DefaultFlagValues.array).to(beTrue())
                        expect(testContext.subject.variation(forKey: BadFlagKeys.dictionary, defaultValue: DefaultFlagValues.dictionary) as [String: Any] == DefaultFlagValues.dictionary).to(beTrue())
                    }
                    it("records a flag evaluation event") {
                        _ = testContext.subject.variation(forKey: BadFlagKeys.bool, defaultValue: DefaultFlagValues.bool)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == BadFlagKeys.bool
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
                context("Optional default value") {
                    it("returns the default value") {
                        //The casts in the expect() calls allow the compiler to determine which variation method to use. This test calls the non-Optional variation method
                        expect(testContext.subject.variation(forKey: BadFlagKeys.bool, defaultValue: DefaultFlagValues.bool as Bool?)) == DefaultFlagValues.bool
                        expect(testContext.subject.variation(forKey: BadFlagKeys.int, defaultValue: DefaultFlagValues.int as Int?)) == DefaultFlagValues.int
                        expect(testContext.subject.variation(forKey: BadFlagKeys.double, defaultValue: DefaultFlagValues.double as Double?)) == DefaultFlagValues.double
                        expect(testContext.subject.variation(forKey: BadFlagKeys.string, defaultValue: DefaultFlagValues.string as String?)) == DefaultFlagValues.string
                        expect(testContext.subject.variation(forKey: BadFlagKeys.array, defaultValue: DefaultFlagValues.array as Array?) == DefaultFlagValues.array).to(beTrue())
                        expect(testContext.subject.variation(forKey: BadFlagKeys.dictionary, defaultValue: DefaultFlagValues.dictionary as [String: Any]?) == DefaultFlagValues.dictionary).to(beTrue())
                    }
                    it("records a flag evaluation event") {
                        //The cast in the variation call directs the compiler to the Optional variation method
                        _ = testContext.subject.variation(forKey: BadFlagKeys.bool, defaultValue: DefaultFlagValues.bool as Bool?)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == BadFlagKeys.bool
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
                context("no default value") {
                    it("returns nil") {
                        //The casts in the expect() calls allow the compiler to determine which variation method to use. This test calls the non-Optional variation method
                        expect(testContext.subject.variation(forKey: BadFlagKeys.bool, defaultValue: nil as Bool?)).to(beNil())
                        expect(testContext.subject.variation(forKey: BadFlagKeys.int, defaultValue: nil as Int?)).to(beNil())
                        expect(testContext.subject.variation(forKey: BadFlagKeys.double, defaultValue: nil as Double?)).to(beNil())
                        expect(testContext.subject.variation(forKey: BadFlagKeys.string, defaultValue: nil as String?)).to(beNil())
                        expect(testContext.subject.variation(forKey: BadFlagKeys.array, defaultValue: nil as [Any]?)).to(beNil())
                        expect(testContext.subject.variation(forKey: BadFlagKeys.dictionary, defaultValue: nil as [String: Any]?)).to(beNil())
                    }
                    it("records a flag evaluation event") {
                        //The cast in the variation call directs the compiler to the Optional variation method
                        _ = testContext.subject.variation(forKey: BadFlagKeys.bool, defaultValue: nil as Bool?)
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
            let mockNotifier = ClientServiceMockFactory().makeFlagChangeNotifier() as! FlagChangeNotifyingMock
            var receivedChangedFlag: Bool = false
            var testContext: TestContext!
            beforeEach {
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }
                
                testContext.subject.flagChangeNotifier = mockNotifier
                testContext.subject.observe(key: "test-key", owner: self, handler: { _ in
                    receivedChangedFlag = true
                })
            }
            it("registers a single flag observer") {
                let receivedObserver = mockNotifier.addFlagChangeObserverReceivedObserver
                expect(mockNotifier.addFlagChangeObserverCallCount) == 1
                expect(receivedObserver?.flagKeys) == ["test-key"]
                expect(receivedObserver?.owner) === self
                receivedObserver?.flagChangeHandler?(LDChangedFlag(key: "", oldValue: nil, newValue: nil))
                expect(receivedChangedFlag) == true
            }
        }

        describe("observeKeys") {
            let mockNotifier = ClientServiceMockFactory().makeFlagChangeNotifier() as! FlagChangeNotifyingMock
            var receivedChangedFlags: Bool = false
            var testContext: TestContext!

            beforeEach {
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }
                    
                testContext.subject.flagChangeNotifier = mockNotifier
                testContext.subject.observe(keys: ["test-key"], owner: self, handler: { _ in
                    receivedChangedFlags = true
                })
            }
            it("registers a multiple flag observer") {
                let receivedObserver = mockNotifier.addFlagChangeObserverReceivedObserver
                expect(mockNotifier.addFlagChangeObserverCallCount) == 1
                expect(receivedObserver?.flagKeys) == ["test-key"]
                expect(receivedObserver?.owner) === self
                let changedFlags = ["test-key": LDChangedFlag(key: "", oldValue: nil, newValue: nil)]
                receivedObserver?.flagCollectionChangeHandler?(changedFlags)
                expect(receivedChangedFlags) == true
            }
        }

        describe("observeAll") {
            let mockNotifier = ClientServiceMockFactory().makeFlagChangeNotifier() as! FlagChangeNotifyingMock
            var receivedChangedFlags: Bool = false
            var testContext: TestContext!

            beforeEach {
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }
                
                testContext.subject.flagChangeNotifier = mockNotifier
                testContext.subject.observeAll(owner: self, handler: { _ in
                    receivedChangedFlags = true
                })
            }
            it("registers a collection flag observer") {
                let receivedObserver = mockNotifier.addFlagChangeObserverReceivedObserver
                expect(mockNotifier.addFlagChangeObserverCallCount) == 1
                expect(receivedObserver?.flagKeys) == LDFlagKey.anyKey
                expect(receivedObserver?.owner) === self
                let changedFlags = ["test-key": LDChangedFlag(key: "", oldValue: nil, newValue: nil)]
                receivedObserver?.flagCollectionChangeHandler?(changedFlags)
                expect(receivedChangedFlags) == true
            }
        }

        describe("observeFlagsUnchanged") {
            let mockNotifier = ClientServiceMockFactory().makeFlagChangeNotifier() as! FlagChangeNotifyingMock
            var receivedFlagsUnchanged: Bool = false
            var testContext: TestContext!
            beforeEach {
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }
                
                testContext.subject.flagChangeNotifier = mockNotifier
                testContext.subject.observeFlagsUnchanged(owner: self, handler: {
                    receivedFlagsUnchanged = true
                })
            }
            it("registers a flags unchanged observer") {
                let receivedObserver = mockNotifier.addFlagsUnchangedObserverReceivedObserver
                expect(mockNotifier.addFlagsUnchangedObserverCallCount) == 1
                expect(receivedObserver?.owner) === self
                receivedObserver?.flagsUnchangedHandler()
                expect(receivedFlagsUnchanged) == true
            }
        }
        
        describe("observeConnectionModeChanged") {
            var testContext: TestContext!
            let mockNotifier = ClientServiceMockFactory().makeFlagChangeNotifier() as! FlagChangeNotifyingMock
            var receivedConnectionModeChanged: Bool = false
            beforeEach {
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }

                testContext.subject.flagChangeNotifier = mockNotifier
                testContext.subject.observeCurrentConnectionMode(owner: self, handler: { _ in
                    receivedConnectionModeChanged = true
                })
            }
            it("registers a ConnectionModeChanged observer") {
                let receivedObserver = mockNotifier.addConnectionModeChangedObserverReceivedObserver
                expect(mockNotifier.addConnectionModeChangedObserverCallCount) == 1
                expect(receivedObserver?.owner) === self
                receivedObserver?.connectionModeChangedHandler?(ConnectionInformation.ConnectionMode.offline)
                expect(receivedConnectionModeChanged) == true
            }
        }

        describe("observeError") {
            var testContext: TestContext!
            var receivedError: Bool = false
            beforeEach {
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }

                testContext.subject.observeError(owner: self, handler: { _ in
                    receivedError = true
                })
            }
            it("registers an error observer") {
                expect(testContext.errorNotifierMock.addErrorObserverCallCount) == 1
                expect(testContext.errorNotifierMock.addErrorObserverReceivedObserver?.owner) === self
                testContext.errorNotifierMock.addErrorObserverReceivedObserver?.errorHandler?(ErrorMock())
                expect(receivedError) == true
            }
        }

        describe("stopObserving") {
            let mockFlagNotifier = ClientServiceMockFactory().makeFlagChangeNotifier() as! FlagChangeNotifyingMock
            var testContext: TestContext!
            beforeEach {
                waitUntil { done in
                    testContext = TestContext(completion: done)
                }
                
                testContext.subject.flagChangeNotifier = mockFlagNotifier
                testContext.subject.stopObserving(owner: self)
            }
            it("unregisters the owner") {
                expect(mockFlagNotifier.removeObserverCallCount) == 1
                expect(mockFlagNotifier.removeObserverReceivedOwner) === self
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

    private func onSyncCompleteSuccessReplacingFlagsSpec(streamingMode: LDStreamingMode, eventType: FlagUpdateType? = nil) {
        var testContext: TestContext!
        var newFlags: [LDFlagKey: FeatureFlag]!
        var updateDate: Date!

        beforeEach {
            waitUntil { done in
                testContext = TestContext(startOnline: true, completion: done)
            }
            testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()

            newFlags = testContext.flagStoreMock.featureFlags
            newFlags[Constants.newFlagKey] = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.string, useAlternateValue: true)

            waitUntil { done in
                testContext.changeNotifierMock.notifyObserversCallback = done
                updateDate = Date()
                testContext.onSyncComplete?(.success(newFlags, eventType))
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
            expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.flagStore.featureFlags) == testContext.flagStoreMock.featureFlags
            expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == testContext.oldFlags).to(beTrue())
        }
    }

    func onSyncCompleteStreamingPatchSpec() {
        var testContext: TestContext!
        var flagUpdateDictionary: [String: Any]!
        var updateDate: Date!
        beforeEach {
            waitUntil { done in
                testContext = TestContext(startOnline: true, completion: done)
            }
            testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
            waitUntil { done in
                testContext.flagStoreMock.replaceStore(newFlags: testContext.oldFlags, completion: done)
            }
            flagUpdateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                           value: DarklyServiceMock.FlagValues.int + 1,
                                                                           variation: DarklyServiceMock.Constants.variation + 1,
                                                                           version: DarklyServiceMock.Constants.version + 1)

            waitUntil { done in
                testContext.changeNotifierMock.notifyObserversCallback = done
                updateDate = Date()
                testContext.onSyncComplete?(.success(flagUpdateDictionary, .patch))
            }
        }
        it("updates the flag store") {
            expect(testContext.flagStoreMock.updateStoreCallCount) == 1
            expect(testContext.flagStoreMock.updateStoreReceivedArguments?.updateDictionary == flagUpdateDictionary).to(beTrue())
        }
        it("caches the updated flags") {
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 1
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.featureFlags) == testContext.flagStoreMock.featureFlags
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.user) == testContext.user
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated.isWithin(Constants.updateThreshold, of: updateDate)) == true
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .async
        }
        it("informs the flag change notifier of the changed flag") {
            expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
            expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.flagStore.featureFlags) == testContext.flagStoreMock.featureFlags
            expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == testContext.oldFlags).to(beTrue())
        }
    }

    func onSyncCompleteDeleteFlagSpec() {
        var testContext: TestContext!
        var flagUpdateDictionary: [String: Any]!
        var updateDate: Date!

        beforeEach {
            waitUntil { done in
                testContext = TestContext(startOnline: true, completion: done)
            }
            testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
            waitUntil { done in
                testContext.flagStoreMock.replaceStore(newFlags: testContext.oldFlags, completion: done)
            }
            flagUpdateDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version + 1)

            waitUntil { done in
                testContext.changeNotifierMock.notifyObserversCallback = done
                updateDate = Date()
                testContext.onSyncComplete?(.success(flagUpdateDictionary, .delete))
            }
        }
        it("updates the flag store") {
            expect(testContext.flagStoreMock.deleteFlagCallCount) == 1
            expect(testContext.flagStoreMock.deleteFlagReceivedArguments?.deleteDictionary == flagUpdateDictionary).to(beTrue())
        }
        it("caches the updated flags") {
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 1
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.featureFlags) == testContext.flagStoreMock.featureFlags
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.user) == testContext.user
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated.isWithin(Constants.updateThreshold, of: updateDate)) == true
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .async
        }
        it("informs the flag change notifier of the changed flag") {
            expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
            expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.flagStore.featureFlags) == testContext.flagStoreMock.featureFlags
            expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == testContext.oldFlags).to(beTrue())
        }
    }

    func onSyncCompleteErrorSpec() {
        func runTest(_ ctx: String, _ err: SynchronizingError, testError: @escaping ((SynchronizingError) -> Void)) {
            var testContext: TestContext!
            context(ctx) {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(startOnline: true) {
                            testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                            testContext.errorNotifierMock.notifyObserversCallback = done
                            testContext.onSyncComplete?(.error(err))
                        }
                    }
                }
                it("takes the client offline when unauthed") {
                    expect(testContext.subject.isOnline) == !err.isClientUnauthorized
                }
                it("does not cache the users flags") {
                    expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 0
                }
                it("does not call the flag change notifier") {
                    expect(testContext.changeNotifierMock.notifyObserversCallCount) == 0
                }
                it("informs the error notifier") {
                    expect(testContext.errorNotifierMock.notifyObserversCallCount) == 1
                    expect(testContext.observedError).to(beAnInstanceOf(SynchronizingError.self))
                    if let err = testContext.observedError as? SynchronizingError { testError(err) }
                }
            }
        }

        let serverError = HTTPURLResponse(url: DarklyServiceMock.Constants.mockBaseUrl,
                                          statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                          httpVersion: DarklyServiceMock.Constants.httpVersion,
                                          headerFields: nil)
        runTest("there was an internal server error", .response(serverError)) { error in
            if case .response(let urlResponse as HTTPURLResponse) = error {
                expect(urlResponse).to(beIdenticalTo(serverError))
            } else { fail("Incorrect error given to error notifier") }
        }

        let unauthedError = HTTPURLResponse(url: DarklyServiceMock.Constants.mockBaseUrl,
                                            statusCode: HTTPURLResponse.StatusCodes.unauthorized,
                                            httpVersion: DarklyServiceMock.Constants.httpVersion,
                                            headerFields: nil)
        runTest("there was a client unauthorized error", .response(unauthedError)) { error in
            if case .response(let urlResponse as HTTPURLResponse) = error {
                expect(urlResponse).to(beIdenticalTo(unauthedError))
            } else { fail("Incorrect error given to error notifier") }
        }
        runTest("there was a request error", .request(DarklyServiceMock.Constants.error)) { error in
            if case .request(let nsError as NSError) = error {
                expect(nsError).to(beIdenticalTo(DarklyServiceMock.Constants.error))
            } else { fail("Incorrect error given to error notifier") }
        }
        runTest("there was a data error", .data(DarklyServiceMock.Constants.errorData)) { error in
            if case .data(let data) = error {
                expect(data) == DarklyServiceMock.Constants.errorData
            } else { fail("Incorrect error given to error notifier") }
        }
        runTest("there was a non-NSError error", .streamError(DummyError())) { error in
            if case .streamError(let dummy) = error {
                expect(dummy is DummyError).to(beTrue())
            } else { fail("Incorrect error given to error notifier") }
        }
    }

    private func runModeSpec() {
        var testContext: TestContext!

        describe("didEnterBackground notification") {
            context("after starting client") {
                context("when online") {
                    OperatingSystem.allOperatingSystems.forEach { os in
                        context("on \(os)") {
                            context("background updates disabled") {
                                beforeEach {
                                    waitUntil { done in
                                        testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, operatingSystem: os, completion: done)
                                    }
                                    NotificationCenter.default.post(name: testContext.environmentReporterMock.backgroundNotification!, object: self)
                                    expect(testContext.subject.runMode).toEventually(equal(LDClientRunMode.background))
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
                                        testContext = TestContext(startOnline: true, operatingSystem: os, completion: done)
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
                        testContext = TestContext()

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
                OperatingSystem.allOperatingSystems.forEach { os in
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
                                testContext = TestContext(runMode: .background, operatingSystem: os)

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
                                        testContext = TestContext(startOnline: true, operatingSystem: .macOS, completion: done)
                                    }
                                    testContext.subject.setRunMode(.background)
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
                                        testContext = TestContext(startOnline: true, streamingMode: .polling, operatingSystem: .macOS, completion: done)
                                    }
                                    testContext.subject.setRunMode(.background)
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
                                    testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, operatingSystem: .macOS, completion: done)
                                }
                                testContext.subject.setRunMode(.background)
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
                                testContext = TestContext(startOnline: true, operatingSystem: .macOS, completion: done)
                            }
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
                            waitUntil { done in
                                testContext = TestContext(startOnline: true, runMode: .background, operatingSystem: .macOS, completion: done)
                            }
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
                                waitUntil { done in
                                    testContext = TestContext(startOnline: true, runMode: .background, operatingSystem: .macOS, completion: done)
                                }
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
                                waitUntil { done in
                                    testContext = TestContext(startOnline: true, streamingMode: .polling, runMode: .background, operatingSystem: .macOS, completion: done)
                                }
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
                                waitUntil { done in
                                    testContext = TestContext(operatingSystem: .macOS, completion: done)
                                }
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
                                waitUntil { done in
                                    testContext = TestContext(enableBackgroundUpdates: false, operatingSystem: .macOS, completion: done)
                                }
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
                            waitUntil { done in
                                testContext = TestContext(operatingSystem: .macOS, completion: done)
                            }
                                
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
                            waitUntil { done in
                                testContext = TestContext(runMode: .background, operatingSystem: .macOS, completion: done)
                            }
                                
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
                                waitUntil { done in
                                    testContext = TestContext(runMode: .background, operatingSystem: .macOS, completion: done)
                                }
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
                                waitUntil { done in
                                    testContext = TestContext(streamingMode: .polling, runMode: .background, operatingSystem: .macOS, completion: done)
                                }
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
            OperatingSystem.allOperatingSystems.forEach { os in
                context("when running on \(os)") {
                    beforeEach {
                        waitUntil { done in
                            testContext = TestContext(startOnline: true, operatingSystem: os, completion: done)
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
    }

    private func allFlagsSpec() {
        var testContext: TestContext!
        var featureFlagValues: [LDFlagKey: Any]?
        describe("allFlags") {
            context("when client was started") {
                var featureFlags: [LDFlagKey: FeatureFlag]!
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(completion: done)
                    }
                    featureFlags = testContext.subject.flagStore.featureFlags
                    featureFlagValues = testContext.subject.allFlags
                }
                it("returns a matching dictionary of flag keys and values") {
                    expect(featureFlagValues?.count) == featureFlags.count - 1 //nil is omitted
                    featureFlags.keys.forEach { flagKey in
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
                        testContext = TestContext(startOnline: true, completion: done)
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
                        testContext = TestContext(startOnline: true, runMode: .background, completion: done)
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
                    testContext = TestContext()
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
                        testContext = TestContext(startOnline: true, completion: done)
                    }
                }
                it("returns FLAG_NOT_FOUND") {
                    let detail = testContext.subject.variationDetail(forKey: BadFlagKeys.bool, defaultValue: DefaultFlagValues.bool).reason
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
        self == .macOS ? .streaming : .polling
    }
}

private class ErrorMock: Error { }

extension CacheConvertingMock {
    func reset() {
        convertCacheDataCallCount = 0
        convertCacheDataReceivedArguments = nil
    }
}
