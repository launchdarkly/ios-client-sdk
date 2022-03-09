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
        let serviceFactoryMock = ClientServiceMockFactory()
        // mock getters based on setting up the user & subject
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
        var environmentReporterMock: EnvironmentReportingMock! {
            subject.environmentReporter as? EnvironmentReportingMock
        }
        var makeFlagSynchronizerStreamingMode: LDStreamingMode? {
            serviceFactoryMock.makeFlagSynchronizerReceivedParameters?.streamingMode
        }
        var makeFlagSynchronizerPollingInterval: TimeInterval? {
            serviceFactoryMock.makeFlagSynchronizerReceivedParameters?.pollingInterval
        }
        var makeFlagSynchronizerService: DarklyServiceProvider? {
            serviceFactoryMock.makeFlagSynchronizerReceivedParameters?.service
        }
        var onSyncComplete: FlagSyncCompleteClosure? {
            serviceFactoryMock.onFlagSyncComplete
        }
        var recordedEvent: LaunchDarkly.Event? {
            eventReporterMock.recordReceivedEvent
        }
        var throttlerMock: ThrottlingMock? {
            subject.throttler as? ThrottlingMock
        }

        private(set) var cachedFlags: [String: [String: [LDFlagKey: FeatureFlag]]] = [:]

        init(newConfig: LDConfig? = nil,
             startOnline: Bool = false,
             streamingMode: LDStreamingMode = .streaming,
             enableBackgroundUpdates: Bool = true,
             operatingSystem: OperatingSystem? = nil,
             autoAliasingOptOut: Bool = true) {

            if let operatingSystem = operatingSystem {
                serviceFactoryMock.makeEnvironmentReporterReturnValue.operatingSystem = operatingSystem
            }
            serviceFactoryMock.makeFlagChangeNotifierReturnValue = FlagChangeNotifier()

            let flagCache = serviceFactoryMock.makeFeatureFlagCacheReturnValue
            flagCache.retrieveFeatureFlagsCallback = {
                let received = flagCache.retrieveFeatureFlagsReceivedArguments!
                flagCache.retrieveFeatureFlagsReturnValue = self.cachedFlags[received.mobileKey]?[received.userKey]
            }

            config = newConfig ?? LDConfig.stub(mobileKey: LDConfig.Constants.mockMobileKey, environmentReporter: serviceFactoryMock.makeEnvironmentReporterReturnValue)
            config.startOnline = startOnline
            config.streamingMode = streamingMode
            config.enableBackgroundUpdates = enableBackgroundUpdates
            config.eventFlushInterval = 300.0   // 5 min...don't want this to trigger
            config.autoAliasingOptOut = autoAliasingOptOut

            user = LDUser.stub()
        }

        func withUser(_ user: LDUser?) -> TestContext {
            self.user = user
            return self
        }

        func withCached(flags: [LDFlagKey: FeatureFlag]?) -> TestContext {
            withCached(userKey: user.key, flags: flags)
        }

        func withCached(userKey: String, flags: [LDFlagKey: FeatureFlag]?) -> TestContext {
            var forEnv = cachedFlags[config.mobileKey] ?? [:]
            forEnv[userKey] = flags
            cachedFlags[config.mobileKey] = forEnv
            return self
        }

        func start(runMode: LDClientRunMode = .foreground, completion: (() -> Void)? = nil) {
            LDClient.start(serviceFactory: serviceFactoryMock, config: config, user: user) {
                self.subject = LDClient.get()
                if runMode == .background {
                    self.subject.setRunMode(.background)
                }
                completion?()
            }
            subject = LDClient.get()
        }

        func start(runMode: LDClientRunMode = .foreground, timeOut: TimeInterval, timeOutCompletion: ((_ timedOut: Bool) -> Void)? = nil) {
            LDClient.start(serviceFactory: serviceFactoryMock, config: config, user: user, startWaitSeconds: timeOut) { timedOut in
                self.subject = LDClient.get()
                if runMode == .background {
                    self.subject.setRunMode(.background)
                }
                timeOutCompletion?(timedOut)
            }
            subject = LDClient.get()
        }
    }

    override func spec() {
        startSpec()
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
        isInitializedSpec()
    }

    private func aliasingSpec() {
        let anonUser = LDUser(key: "unknown", isAnonymous: true)
        let knownUser = LDUser(key: "known", isAnonymous: false)
        describe("aliasing") {
            var ctx: TestContext!
            beforeEach {
                ctx = TestContext(autoAliasingOptOut: false)
            }
            context("automatic aliasing from anonymous to user") {
                beforeEach {
                    ctx.withUser(anonUser).start()
                    ctx.subject.internalIdentify(newUser: knownUser)
                }
                it("records an alias and identify event") {
                    // init, identify, and alias event
                    expect(ctx.eventReporterMock.recordCallCount) == 3
                    expect(ctx.recordedEvent?.kind) == .alias
                }
            }
            context("automatic aliasing from user to user") {
                beforeEach {
                    ctx.withUser(knownUser).start()
                    ctx.subject.internalIdentify(newUser: knownUser)
                }
                it("doesnt record an alias event") {
                    // init and identify event
                    expect(ctx.eventReporterMock.recordCallCount) == 2
                    expect(ctx.recordedEvent?.kind) == .identify
                }
            }
            context("automatic aliasing from anonymous to anonymous") {
                beforeEach {
                    ctx.withUser(anonUser).start()
                    ctx.subject.internalIdentify(newUser: anonUser)
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
            startSpec(withTimeout: false)
        }
        describe("startWithTimeout") {
            startSpec(withTimeout: true)
        }
        describe("startCompletions") {
            startCompletionSpec()
        }
    }

    private func startSpec(withTimeout: Bool) {
        var testContext: TestContext!

        context("when configured to start online") {
            beforeEach {
                testContext = TestContext(startOnline: true)
                withTimeout ? testContext.start(timeOut: 10.0) : testContext.start()
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
                expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.config) == testContext.config
            }
            it("saves the user") {
                expect(testContext.subject.user) == testContext.user
                expect(testContext.subject.service.user) == testContext.user
                expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                    expect(makeFlagSynchronizerReceivedParameters.service) === testContext.subject.service
                }
                expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.user) == testContext.user
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
                testContext = TestContext()
                withTimeout ? testContext.start(timeOut: 10.0) : testContext.start()
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
                expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.config) == testContext.config
            }
            it("saves the user") {
                expect(testContext.subject.user) == testContext.user
                expect(testContext.subject.service.user) == testContext.user
                expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                    expect(makeFlagSynchronizerReceivedParameters.service) === testContext.subject.service
                }
                expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.user) == testContext.user
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
                    testContext = TestContext(startOnline: true).withUser(nil)
                    withTimeout ? testContext.start(timeOut: 10.0) : testContext.start()

                    testContext.user = LDUser.stub()
                    testContext.subject.internalIdentify(newUser: testContext.user)
                }
                it("saves the config") {
                    expect(testContext.subject.config) == testContext.config
                    expect(testContext.subject.service.config) == testContext.config
                    expect(testContext.makeFlagSynchronizerStreamingMode) == testContext.config.streamingMode
                    expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
                    expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.config) == testContext.config
                }
                it("saves the user") {
                    expect(testContext.subject.user) == testContext.user
                    expect(testContext.subject.service.user) == testContext.user
                    expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service.user) == testContext.user
                    }
                    expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.user) == testContext.user
                }
                it("uncaches the new users flags") {
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 2 // called on init and subsequent identify
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                }
                it("records an identify event") {
                    expect(testContext.eventReporterMock.recordCallCount) == 2 // both start and internalIdentify
                    expect(testContext.recordedEvent?.kind) == .identify
                    expect(testContext.recordedEvent?.key) == testContext.user.key
                }
                it("converts cached data") {
                    expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 2 // Both start and internalIdentify
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                }
            }
            context("without setting user") {
                beforeEach {
                    testContext = TestContext(startOnline: true).withUser(nil)
                    withTimeout ? testContext.start(timeOut: 10.0) : testContext.start()
                }
                it("saves the config") {
                    expect(testContext.subject.config) == testContext.config
                    expect(testContext.subject.service.config) == testContext.config
                    expect(testContext.makeFlagSynchronizerStreamingMode) == testContext.config.streamingMode
                    expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
                    expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.config) == testContext.config
                }
                it("uses anonymous user") {
                    expect(testContext.subject.user.key) == LDUser.defaultKey(environmentReporter: testContext.environmentReporterMock)
                    expect(testContext.subject.user.isAnonymous).to(beTrue())
                    expect(testContext.subject.service.user) == testContext.subject.user
                    expect(testContext.makeFlagSynchronizerService?.user) == testContext.subject.user
                    expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.user) == testContext.subject.user
                }
                it("uncaches the new users flags") {
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.subject.user.key
                    expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                }
                it("records an identify event") {
                    expect(testContext.eventReporterMock.recordCallCount) == 1
                    expect(testContext.recordedEvent?.kind) == .identify
                    expect(testContext.recordedEvent?.key) == testContext.subject.user.key
                }
                it("converts cached data") {
                    expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.subject.user
                    expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
                }
            }
        }
        context("when called with cached flags for the user and environment") {
            beforeEach {
                testContext = TestContext().withCached(flags: FlagMaintainingMock.stubFlags())
                withTimeout ? testContext.start(timeOut: 10.0) : testContext.start()
            }
            it("checks the flag cache for the user and environment") {
                expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsCallCount) == 1
                expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                expect(testContext.featureFlagCachingMock.retrieveFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
            }
            it("restores user flags from cache") {
                expect(testContext.flagStoreMock.replaceStoreReceivedArguments?.newFlags.flagCollection) == FlagMaintainingMock.stubFlags()
            }
            it("converts cached data") {
                expect(testContext.cacheConvertingMock.convertCacheDataCallCount) == 1
                expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.user) == testContext.user
                expect(testContext.cacheConvertingMock.convertCacheDataReceivedArguments?.config) == testContext.config
            }
        }
        context("when called without cached flags for the user") {
            beforeEach {
                testContext = TestContext()
                withTimeout ? testContext.start(timeOut: 10.0) : testContext.start()
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

    func startCompletionSpec() {
        var testContext: TestContext!
        var completed = false
        var didTimeOut: Bool? = nil
        var startTime: Date!
        var completeTime: Date!

        let startCompletion = { completed = true }
        func startTimeoutCompletion(_ done: (() -> Void)? = nil) -> (Bool) -> Void {
            { timedOut in
                completeTime = Date()
                didTimeOut = timedOut
                completed = true
                done?()
            }
        }

        beforeEach {
            completed = false
            didTimeOut = nil
            startTime = nil
            completeTime = nil
        }

        context("when configured to start offline") {
            beforeEach {
                testContext = TestContext()
            }
            it("completes immediately without timeout") {
                testContext.start(completion: startCompletion)
                expect(completed) == true
            }
            it("completes immediately with timeout") {
                testContext.start(timeOut: 5.0, timeOutCompletion: startTimeoutCompletion())
                expect(completed) == true
                expect(didTimeOut) == true
            }
        }
        context("when configured to start online") {
            beforeEach {
                testContext = TestContext(startOnline: true)
            }
            context("without receiving flags") {
                for withCached in [false, true] {
                    context(withCached ? "with cached flags" : "") {
                        beforeEach {
                            if withCached {
                                _ = testContext.withCached(flags: FlagMaintainingMock.stubFlags())
                            }
                        }
                        it("does not complete without timeout") {
                            testContext.start(completion: startCompletion)
                            Thread.sleep(forTimeInterval: 1.0)
                            expect(completed) == false
                        }
                        it("completes in timed out state with timeout") {
                            waitUntil(timeout: .seconds(5)) { done in
                                startTime = Date()
                                testContext.start(timeOut: 1.0, timeOutCompletion: startTimeoutCompletion(done))
                            }
                            expect(completed) == true
                            expect(didTimeOut) == true
                            // Should not have occured immediately
                            expect(completeTime.timeIntervalSince(startTime)) >= 1.0

                            // Test that already timed out completion is not called when sync completes
                            completed = false
                            testContext.onSyncComplete?(.success([:], nil))
                            testContext.onSyncComplete?(.success([:], .ping))
                            testContext.onSyncComplete?(.success([:], .put))
                            Thread.sleep(forTimeInterval: 1.0)
                            expect(completed) == false
                        }
                    }
                }
            }
            for eventType in [nil, FlagUpdateType.ping, FlagUpdateType.put] {
                context("after receiving flags as " + (eventType?.rawValue ?? "poll")) {
                    it("does complete without timeout") {
                        testContext.start(completion: startCompletion)
                        testContext.onSyncComplete?(.success([:], eventType))
                        expect(completed).toEventually(beTrue(), timeout: DispatchTimeInterval.seconds(2))
                    }
                    it("does complete with timeout") {
                        waitUntil(timeout: .seconds(3)) { done in
                            testContext.start(timeOut: 5.0, timeOutCompletion: startTimeoutCompletion(done))
                            testContext.onSyncComplete?(.success([:], eventType))
                        }
                        expect(completed).toEventually(beTrue(), timeout: DispatchTimeInterval.seconds(2))
                        expect(didTimeOut) == false
                    }
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
                            testContext = TestContext(startOnline: true, operatingSystem: os)
                            testContext.start()
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
                            expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.config) == testContext.config
                        }
                        it("saves the user") {
                            expect(testContext.subject.user) == testContext.user
                            expect(testContext.subject.service.user) == testContext.user
                            expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                            if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                                expect(makeFlagSynchronizerReceivedParameters.service) === testContext.subject.service
                            }
                            expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.user) == testContext.user
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
                            testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, operatingSystem: os)
                            testContext.start()
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
                            expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.config) == testContext.config
                        }
                        it("saves the user") {
                            expect(testContext.subject.user) == testContext.user
                            expect(testContext.subject.service.user) == testContext.user
                            expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                            if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                                expect(makeFlagSynchronizerReceivedParameters.service.user) == testContext.user
                            }
                            expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.user) == testContext.user
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
            context("when the client is online") {
                beforeEach {
                    testContext = TestContext(startOnline: true)
                    testContext.start()
                    testContext.featureFlagCachingMock.reset()
                    testContext.cacheConvertingMock.reset()
                    
                    newUser = LDUser.stub()
                    testContext.subject.internalIdentify(newUser: newUser)
                }
                it("changes to the new user") {
                    expect(testContext.subject.user) == newUser
                    expect(testContext.subject.service.user) == newUser
                    expect(testContext.serviceMock.clearFlagResponseCacheCallCount) == 1
                    expect(testContext.makeFlagSynchronizerService?.user) == newUser
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
                    testContext = TestContext()
                    testContext.start()
                    testContext.featureFlagCachingMock.reset()
                    testContext.cacheConvertingMock.reset()

                    newUser = LDUser.stub()
                    testContext.subject.internalIdentify(newUser: newUser)
                }
                it("changes to the new user") {
                    expect(testContext.subject.user) == newUser
                    expect(testContext.subject.service.user) == newUser
                    expect(testContext.serviceMock.clearFlagResponseCacheCallCount) == 1
                    expect(testContext.makeFlagSynchronizerService?.user) == newUser
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
                let stubFlags = FlagMaintainingMock.stubFlags()
                beforeEach {
                    newUser = LDUser.stub()
                    testContext = TestContext().withCached(userKey: newUser.key, flags: stubFlags)
                    testContext.start()
                    testContext.featureFlagCachingMock.reset()
                    testContext.cacheConvertingMock.reset()

                    testContext.subject.internalIdentify(newUser: newUser)
                }
                it("restores the cached users feature flags") {
                    expect(testContext.subject.user) == newUser
                    expect(testContext.flagStoreMock.replaceStoreCallCount) == 1
                    expect(testContext.flagStoreMock.replaceStoreReceivedArguments?.newFlags.flagCollection) == stubFlags
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
                            testContext = TestContext()
                            testContext.start {
                                testContext.subject.setOnline(true)
                                done()
                            }
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
                        testContext = TestContext(startOnline: true)
                        testContext.start()

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
                                        testContext = TestContext(operatingSystem: os)
                                        testContext.start(runMode: .background, completion: done)
                                    }
                                    targetRunThrottledCalls = os.isBackgroundEnabled ? 1 : 0
                                    testContext.subject.setOnline(true)
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
                                    testContext = TestContext(enableBackgroundUpdates: false, operatingSystem: os)
                                    testContext.start(runMode: .background, completion: done)
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
                        testContext = TestContext(newConfig: LDConfig(mobileKey: ""))
                        testContext.start(completion: done)
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
                        testContext = TestContext(startOnline: true)
                        testContext.start()
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
                        testContext = TestContext()
                        testContext.start()
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
                    testContext = TestContext()
                    testContext.start()
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
                testContext.start()
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
                    testContext = TestContext()
                    testContext.start(completion: done)
                }
            }
            context("flag store contains the requested value") {
                beforeEach {
                    waitUntil { done in
                        testContext.flagStoreMock.replaceStore(newFlags: FlagMaintainingMock.stubFlags(), completion: done)
                    }
                }
                context("non-Optional default value") {
                    it("returns the flag value") {
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)) == DarklyServiceMock.FlagValues.bool
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.int, defaultValue: DefaultFlagValues.int)) == DarklyServiceMock.FlagValues.int
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.double, defaultValue: DefaultFlagValues.double)) == DarklyServiceMock.FlagValues.double
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.string, defaultValue: DefaultFlagValues.string)) == DarklyServiceMock.FlagValues.string
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.array, defaultValue: DefaultFlagValues.array) == DarklyServiceMock.FlagValues.array).to(beTrue())
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, defaultValue: DefaultFlagValues.dictionary)
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
            }
            context("flag store does not contain the requested value") {
                context("non-Optional default value") {
                    it("returns the default value") {
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)) == DefaultFlagValues.bool
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.int, defaultValue: DefaultFlagValues.int)) == DefaultFlagValues.int
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.double, defaultValue: DefaultFlagValues.double)) == DefaultFlagValues.double
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.string, defaultValue: DefaultFlagValues.string)) == DefaultFlagValues.string
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.array, defaultValue: DefaultFlagValues.array) == DefaultFlagValues.array).to(beTrue())
                        expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, defaultValue: DefaultFlagValues.dictionary) == DefaultFlagValues.dictionary).to(beTrue())
                    }
                    it("records a flag evaluation event") {
                        _ = testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == DarklyServiceMock.FlagKeys.bool
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(AnyComparer.isEqual(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue, to: DefaultFlagValues.bool)).to(beTrue())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.user) == testContext.user
                    }
                }
            }
        }
    }

    private func observeSpec() {
        var testContext: TestContext!
        var mockNotifier: FlagChangeNotifyingMock!
        var callCount: Int = 0
        describe("observe") {
            beforeEach {
                testContext = TestContext()
                testContext.start()
                mockNotifier = FlagChangeNotifyingMock()
                testContext.subject.flagChangeNotifier = mockNotifier
                callCount = 0
            }
            it("observe") {
                testContext.subject.observe(key: "test-key", owner: self) { _ in callCount += 1 }
                let receivedObserver = mockNotifier.addFlagChangeObserverReceivedObserver
                expect(mockNotifier.addFlagChangeObserverCallCount) == 1
                expect(receivedObserver?.flagKeys) == ["test-key"]
                expect(receivedObserver?.owner) === self
                receivedObserver?.flagChangeHandler?(LDChangedFlag(key: "", oldValue: nil, newValue: nil))
                expect(callCount) == 1
            }
            it("observeKeys") {
                testContext.subject.observe(keys: ["test-key"], owner: self) { _ in callCount += 1 }
                let receivedObserver = mockNotifier.addFlagChangeObserverReceivedObserver
                expect(mockNotifier.addFlagChangeObserverCallCount) == 1
                expect(receivedObserver?.flagKeys) == ["test-key"]
                expect(receivedObserver?.owner) === self
                let changedFlags = ["test-key": LDChangedFlag(key: "", oldValue: nil, newValue: nil)]
                receivedObserver?.flagCollectionChangeHandler?(changedFlags)
                expect(callCount) == 1
            }
            it("observeAll") {
                testContext.subject.observeAll(owner: self) { _ in callCount += 1 }
                let receivedObserver = mockNotifier.addFlagChangeObserverReceivedObserver
                expect(mockNotifier.addFlagChangeObserverCallCount) == 1
                expect(receivedObserver?.flagKeys) == LDFlagKey.anyKey
                expect(receivedObserver?.owner) === self
                let changedFlags = ["test-key": LDChangedFlag(key: "", oldValue: nil, newValue: nil)]
                receivedObserver?.flagCollectionChangeHandler?(changedFlags)
                expect(callCount) == 1
            }
            it("observeFlagsUnchanged") {
                testContext.subject.observeFlagsUnchanged(owner: self) { callCount += 1 }
                let receivedObserver = mockNotifier.addFlagsUnchangedObserverReceivedObserver
                expect(mockNotifier.addFlagsUnchangedObserverCallCount) == 1
                expect(receivedObserver?.owner) === self
                receivedObserver?.flagsUnchangedHandler()
                expect(callCount) == 1
            }
            it("observeConnectionModeChanged") {
                testContext.subject.observeCurrentConnectionMode(owner: self) { _ in callCount += 1 }
                let receivedObserver = mockNotifier.addConnectionModeChangedObserverReceivedObserver
                expect(mockNotifier.addConnectionModeChangedObserverCallCount) == 1
                expect(receivedObserver?.owner) === self
                receivedObserver?.connectionModeChangedHandler(ConnectionInformation.ConnectionMode.offline)
                expect(callCount) == 1
            }
            it("stopObserving") {
                testContext.subject.stopObserving(owner: self)
                expect(mockNotifier.removeObserverCallCount) == 1
                expect(mockNotifier.removeObserverReceivedOwner) === self
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
            testContext = TestContext(startOnline: true)
            testContext.start()
            testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()

            newFlags = FlagMaintainingMock.stubFlags()
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
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated).to(beCloseTo(updateDate, within: Constants.updateThreshold))
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .async
        }
        it("informs the flag change notifier of the changed flags") {
            expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
            expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.newFlags) == testContext.flagStoreMock.featureFlags
            expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == testContext.cachedFlags).to(beTrue())
        }
    }

    func onSyncCompleteStreamingPatchSpec() {
        var testContext: TestContext!
        var flagUpdateDictionary: [String: Any]!
        var updateDate: Date!
        let stubFlags = FlagMaintainingMock.stubFlags()
        beforeEach {
            testContext = TestContext(startOnline: true).withCached(flags: stubFlags)
            testContext.start()
            testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
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
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated).to(beCloseTo(updateDate, within: Constants.updateThreshold))
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .async
        }
        it("informs the flag change notifier of the changed flag") {
            expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
            expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.newFlags) == testContext.flagStoreMock.featureFlags
            expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == stubFlags).to(beTrue())
        }
    }

    func onSyncCompleteDeleteFlagSpec() {
        var testContext: TestContext!
        var flagUpdateDictionary: [String: Any]!
        var updateDate: Date!
        let stubFlags = FlagMaintainingMock.stubFlags()
        beforeEach {
            testContext = TestContext(startOnline: true).withCached(flags: stubFlags)
            testContext.start()
            testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
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
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated).to(beCloseTo(updateDate, within: Constants.updateThreshold))
            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .async
        }
        it("informs the flag change notifier of the changed flag") {
            expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
            expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.newFlags) == testContext.flagStoreMock.featureFlags
            expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == stubFlags).to(beTrue())
        }
    }

    func onSyncCompleteErrorSpec() {
        func runTest(_ ctx: String,
                     _ err: SynchronizingError,
                     testError: @escaping ((ConnectionInformation.LastConnectionFailureReason) -> Void)) {
            var testContext: TestContext!
            context(ctx) {
                beforeEach {
                    testContext = TestContext(startOnline: true)
                    testContext.start()
                    testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                    testContext.onSyncComplete?(.error(err))
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
                it("Updates the connection information") {
                    expect(testContext.subject.getConnectionInformation().lastFailedConnection).to(beCloseTo(Date(), within: 5.0))
                    testError(testContext.subject.getConnectionInformation().lastConnectionFailureReason)
                }
            }
        }

        let serverError = HTTPURLResponse(url: DarklyServiceMock.Constants.mockBaseUrl,
                                          statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                          httpVersion: DarklyServiceMock.Constants.httpVersion,
                                          headerFields: nil)
        runTest("there was an internal server error", .response(serverError)) { error in
            if case .httpError(let errCode) = error {
                expect(errCode) == 500
            } else { fail("Incorrect error in connection information") }
        }

        let unauthedError = HTTPURLResponse(url: DarklyServiceMock.Constants.mockBaseUrl,
                                            statusCode: HTTPURLResponse.StatusCodes.unauthorized,
                                            httpVersion: DarklyServiceMock.Constants.httpVersion,
                                            headerFields: nil)
        runTest("there was a client unauthorized error", .response(unauthedError)) { error in
            if case .unauthorized = error {
            } else { fail("Incorrect error in connection information") }
        }
        runTest("there was a request error", .request(DarklyServiceMock.Constants.error)) { error in
            if case .unknownError = error {
            } else { fail("Incorrect error in connection information") }
        }
        runTest("there was a data error", .data(DarklyServiceMock.Constants.errorData)) { _ in }
        runTest("there was a non-NSError error", .streamError(DummyError())) { _ in }
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
                                    testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, operatingSystem: os)
                                    testContext.start()
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
                                    testContext = TestContext(startOnline: true, operatingSystem: os)
                                    testContext.start()

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
                        testContext.start()
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
                                testContext = TestContext(startOnline: true, operatingSystem: os)
                                testContext.start(runMode: .background)
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
                                testContext = TestContext(operatingSystem: os)
                                testContext.start(runMode: .background)

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
                                    testContext = TestContext(startOnline: true, operatingSystem: .macOS)
                                    testContext.start()
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
                                    testContext = TestContext(startOnline: true, streamingMode: .polling, operatingSystem: .macOS)
                                    testContext.start()
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
                                testContext = TestContext(startOnline: true, enableBackgroundUpdates: false, operatingSystem: .macOS)
                                testContext.start()
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
                            testContext = TestContext(startOnline: true, operatingSystem: .macOS)
                            testContext.start()
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
                            testContext = TestContext(startOnline: true, operatingSystem: .macOS)
                            testContext.start()
                            testContext.subject.setRunMode(.background)
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
                                testContext = TestContext(startOnline: true, operatingSystem: .macOS)
                                testContext.start(runMode: .background)
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
                                testContext = TestContext(startOnline: true, streamingMode: .polling, operatingSystem: .macOS)
                                testContext.start(runMode: .background)
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
                                    testContext = TestContext(operatingSystem: .macOS)
                                    testContext.start(completion: done)
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
                                    testContext = TestContext(enableBackgroundUpdates: false, operatingSystem: .macOS)
                                    testContext.start(completion: done)
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
                                testContext = TestContext(operatingSystem: .macOS)
                                testContext.start(completion: done)
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
                                testContext = TestContext(operatingSystem: .macOS)
                                testContext.start(runMode: .background, completion: done)
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
                                    testContext = TestContext(operatingSystem: .macOS)
                                    testContext.start(runMode: .background, completion: done)
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
                                    testContext = TestContext(streamingMode: .polling, operatingSystem: .macOS)
                                    testContext.start(runMode: .background, completion: done)
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
                it("on \(os) sets the flag synchronizer streaming mode") {
                    testContext = TestContext(startOnline: true, operatingSystem: os)
                    testContext.start()
                    expect(testContext.makeFlagSynchronizerStreamingMode) == (os.isStreamingEnabled ? LDStreamingMode.streaming : LDStreamingMode.polling)
                }
            }
        }
    }

    private func flushSpec() {
        describe("flush") {
            it("tells the event reporter to report events") {
                let testContext = TestContext()
                testContext.start()
                testContext.subject.flush()
                expect(testContext.eventReporterMock.flushCallCount) == 1
            }
        }
    }

    private func allFlagsSpec() {
        let stubFlags = FlagMaintainingMock.stubFlags()
        var testContext: TestContext!
        describe("allFlags") {
            beforeEach {
                testContext = TestContext().withCached(flags: stubFlags)
                testContext.start()
            }
            it("returns all non-null flag values from store") {
                expect(AnyComparer.isEqual(testContext.subject.allFlags, to: stubFlags.compactMapValues { $0.value })).to(beTrue())
            }
            it("returns nil when client is closed") {
                testContext.subject.close()
                expect(testContext.subject.allFlags).to(beNil())
            }
        }
    }
    
    private func connectionInformationSpec() {
        var testContext: TestContext!
        
        describe("ConnectionInformation") {
            context("when client was started in foreground") {
                beforeEach {
                    testContext = TestContext(startOnline: true)
                    testContext.start()
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
                    testContext = TestContext(startOnline: true, enableBackgroundUpdates: false)
                    testContext.start()
                    testContext.subject.setRunMode(.background)
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
                    testContext.start()
                }
                it("leaves the sdk offline") {
                    expect(testContext.subject.isOnline) == false
                    expect(testContext.eventReporterMock.isOnline) == false
                    expect(testContext.flagSynchronizerMock.isOnline) == false
                    expect(testContext.subject.connectionInformation.currentConnectionMode).to(equal(.offline))
                }
            }
        }
    }
    
    private func variationDetailSpec() {
        describe("variationDetail") {
            context("when client was started and flag key doesn't exist") {
                it("returns FLAG_NOT_FOUND") {
                    let testContext = TestContext()
                    testContext.start()
                    let detail = testContext.subject.variationDetail(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool).reason
                    if let errorKind = detail?["errorKind"] as? String {
                        expect(errorKind) == "FLAG_NOT_FOUND"
                    }
                }
            }
        }
    }

    private func isInitializedSpec() {
        var testContext: TestContext!

        describe("isInitialized") {
            context("when client was started but no flag update") {
                beforeEach {
                    testContext = TestContext(startOnline: true)
                    testContext.start()
                }
                it("returns false") {
                    expect(testContext.subject.isInitialized) == false
                }
                it("and then stopped returns false") {
                    testContext.subject.close()
                    expect(testContext.subject.isInitialized) == false
                }
            }
            context("when client was started offline") {
                beforeEach {
                    testContext = TestContext()
                    testContext.start()
                }
                it("returns true") {
                    expect(testContext.subject.isInitialized) == true
                }
                it("and then stopped returns false") {
                    testContext.subject.close()
                    expect(testContext.subject.isInitialized) == false
                }
            }
            for eventType in [nil, FlagUpdateType.ping, FlagUpdateType.put] {
                context("when client was started and after receiving flags as " + (eventType?.rawValue ?? "poll")) {
                    beforeEach {
                        testContext = TestContext(startOnline: true)
                        testContext.start()
                        testContext.onSyncComplete?(.success([:], eventType))
                    }
                    it("returns true") {
                        expect(testContext.subject.isInitialized).toEventually(beTrue(), timeout: DispatchTimeInterval.seconds(2))
                    }
                    it("and then stopped returns false") {
                        testContext.subject.close()
                        expect(testContext.subject.isInitialized) == false
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
