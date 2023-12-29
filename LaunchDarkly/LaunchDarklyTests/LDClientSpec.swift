import Foundation
import Quick
import Nimble
import LDSwiftEventSource
@testable import LaunchDarkly

final class LDClientSpec: QuickSpec {
    struct Constants {
        fileprivate static let alternateMockUrl = URL(string: "https://dummy.alternate.com")!
        fileprivate static let alternateMockMobileKey = "alternateMockMobileKey"

        fileprivate static let updateThreshold: TimeInterval = 0.05
    }

    struct DefaultFlagValues {
        static let bool = false
        static let int = 5
        static let double = 2.71828
        static let string = "default string value"
        static let array: LDValue = [-1, -2]
        static let dictionary: LDValue = ["sub-flag-x": true, "sub-flag-y": 1, "sub-flag-z": 42.42]
    }

    class TestContext {
        var config: LDConfig!
        var context: LDContext!
        var subject: LDClient!
        let serviceFactoryMock = ClientServiceMockFactory()
        // mock getters based on setting up the context & subject
        var serviceMock: DarklyServiceMock! {
            subject.service as? DarklyServiceMock
        }
        var featureFlagCachingMock: FeatureFlagCachingMock! {
            subject.flagCache as? FeatureFlagCachingMock
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
             enableBackgroundUpdates: Bool = true) {
            serviceFactoryMock.makeFlagChangeNotifierReturnValue = FlagChangeNotifier()

            serviceFactoryMock.makeFeatureFlagCacheCallback = {
                let mobileKey = self.serviceFactoryMock.makeFeatureFlagCacheReceivedParameters!.mobileKey
                let mockCache = FeatureFlagCachingMock()
                mockCache.getCachedDataCallback = {
                    mockCache.getCachedDataReturnValue = (items: StoredItems(items: self.cachedFlags[mobileKey]?[mockCache.getCachedDataReceivedCacheKey!] ?? [:]), etag: nil)
                }
                self.serviceFactoryMock.makeFeatureFlagCacheReturnValue = mockCache
            }

            config = newConfig ?? LDConfig.stub(mobileKey: LDConfig.Constants.mockMobileKey, autoEnvAttributes: .disabled, isDebugBuild: false)
            config.startOnline = startOnline
            config.streamingMode = streamingMode
            config.enableBackgroundUpdates = enableBackgroundUpdates
            config.eventFlushInterval = 300.0   // 5 min...don't want this to trigger

            context = LDContext.stub()
        }

        func withContext(_ context: LDContext?) -> TestContext {
            self.context = context
            return self
        }

        func withCached(flags: [LDFlagKey: FeatureFlag]?) -> TestContext {
            withCached(contextKey: context.contextHash(), flags: flags)
        }

        func withCached(contextKey: String, flags: [LDFlagKey: FeatureFlag]?) -> TestContext {
            var forEnv = cachedFlags[config.mobileKey] ?? [:]
            forEnv[contextKey] = flags
            cachedFlags[config.mobileKey] = forEnv
            return self
        }

        func start(runMode: LDClientRunMode = .foreground, completion: (() -> Void)? = nil) {
            LDClient.start(serviceFactory: serviceFactoryMock, config: config, context: context) {
                self.subject = LDClient.get()
                if runMode == .background {
                    self.subject.setRunMode(.background)
                }
                completion?()
            }
            subject = LDClient.get()
        }

        func start(runMode: LDClientRunMode = .foreground, timeOut: TimeInterval, timeOutCompletion: ((_ timedOut: Bool) -> Void)? = nil) {
            LDClient.start(serviceFactory: serviceFactoryMock, config: config, context: context, startWaitSeconds: timeOut) { timedOut in
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
        isInitializedSpec()
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

        context("when we opt into auto environment attributes") {
            it("modifies the initial context") {
                let context = LDContext.stub()

                var testContext = TestContext(startOnline: true)
                testContext.config.autoEnvAttributes = true
                testContext = testContext.withContext(context)
                testContext.start()

                expect(context.contextKeys().count) < testContext.subject!.context.contextKeys().count

                let kinds = testContext.subject.service.context.contextKeys().keys

                expect(kinds.contains(AutoEnvContextModifier.ldDeviceKind)) == true
                expect(kinds.contains(AutoEnvContextModifier.ldApplicationKind)) == true
            }
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
            it("saves the context") {
                expect(testContext.subject.context) == testContext.context
                expect(testContext.subject.service.context) == testContext.context
                expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                    expect(makeFlagSynchronizerReceivedParameters.service) === testContext.subject.service
                }
                expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.context) == testContext.context
            }
            it("uncaches the new contexts flags") {
                expect(testContext.featureFlagCachingMock.getCachedDataCallCount) == 1
                expect(testContext.featureFlagCachingMock.getCachedDataReceivedCacheKey) == testContext.context.contextHash()
            }
            it("records an identify event") {
                expect(testContext.eventReporterMock.recordCallCount) == 1
                expect((testContext.recordedEvent as? IdentifyEvent)?.context) == testContext.context
            }
            it("converts cached data") {
                expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataCallCount) == 1
                expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataReceivedArguments?.maxCachedContexts) == testContext.config.maxCachedContexts
                expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataReceivedArguments?.keysToConvert) == [testContext.config.mobileKey]
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
            it("saves the context") {
                expect(testContext.subject.context) == testContext.context
                expect(testContext.subject.service.context) == testContext.context
                expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                    expect(makeFlagSynchronizerReceivedParameters.service) === testContext.subject.service
                }
                expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.context) == testContext.context
            }
            it("uncaches the new contexts flags") {
                expect(testContext.featureFlagCachingMock.getCachedDataCallCount) == 1
                expect(testContext.featureFlagCachingMock.getCachedDataReceivedCacheKey) == testContext.context.contextHash()
            }
            it("records an identify event") {
                expect(testContext.eventReporterMock.recordCallCount) == 1
                expect((testContext.recordedEvent as? IdentifyEvent)?.context) == testContext.context
            }
            it("converts cached data") {
                expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataCallCount) == 1
                expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataReceivedArguments?.maxCachedContexts) == testContext.config.maxCachedContexts
                expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataReceivedArguments?.keysToConvert) == [testContext.config.mobileKey]
            }
            it("starts in foreground") {
                expect(testContext.subject.runMode) == .foreground
            }
        }
        context("when called without context") {
            context("after setting context") {
                beforeEach {
                    testContext = TestContext(startOnline: true).withContext(nil)
                    withTimeout ? testContext.start(timeOut: 10.0) : testContext.start()

                    testContext.context = LDContext.stub()
                    testContext.subject.internalIdentify(newContext: testContext.context)
                }
                it("saves the config") {
                    expect(testContext.subject.config) == testContext.config
                    expect(testContext.subject.service.config) == testContext.config
                    expect(testContext.makeFlagSynchronizerStreamingMode) == testContext.config.streamingMode
                    expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
                    expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.config) == testContext.config
                }
                it("saves the context") {
                    expect(testContext.subject.context) == testContext.context
                    expect(testContext.subject.service.context) == testContext.context
                    expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service.context) == testContext.context
                    }
                    expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.context) == testContext.context
                }
                it("uncaches the new contexts flags") {
                    expect(testContext.featureFlagCachingMock.getCachedDataCallCount) == 2 // called on init and subsequent identify
                    expect(testContext.featureFlagCachingMock.getCachedDataReceivedCacheKey) == testContext.context.contextHash()
                }
                it("records an identify event") {
                    expect(testContext.eventReporterMock.recordCallCount) == 2 // both start and internalIdentify
                    expect((testContext.recordedEvent as? IdentifyEvent)?.context) == testContext.context
                }
                it("converts cached data") {
                    expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataCallCount) == 1
                    expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataReceivedArguments?.maxCachedContexts) == testContext.config.maxCachedContexts
                    expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataReceivedArguments?.keysToConvert) == [testContext.config.mobileKey]
                }
            }
            context("without setting context") {
                beforeEach {
                    testContext = TestContext(startOnline: true).withContext(nil)
                    withTimeout ? testContext.start(timeOut: 10.0) : testContext.start()
                }
                it("saves the config") {
                    expect(testContext.subject.config) == testContext.config
                    expect(testContext.subject.service.config) == testContext.config
                    expect(testContext.makeFlagSynchronizerStreamingMode) == testContext.config.streamingMode
                    expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
                    expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.config) == testContext.config
                }
                it("uses anonymous context") {
                    expect(testContext.subject.context.fullyQualifiedKey()) == LDContext.defaultKey(kind: testContext.subject.context.kind)
                    expect(testContext.subject.service.context) == testContext.subject.context
                    expect(testContext.makeFlagSynchronizerService?.context) == testContext.subject.context
                    expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.context) == testContext.subject.context
                }
                it("uncaches the new contexts flags") {
                    expect(testContext.featureFlagCachingMock.getCachedDataCallCount) == 1
                    expect(testContext.featureFlagCachingMock.getCachedDataReceivedCacheKey) == testContext.subject.context.contextHash()
                }
                it("records an identify event") {
                    expect(testContext.eventReporterMock.recordCallCount) == 1
                    expect((testContext.recordedEvent as? IdentifyEvent)?.context) == testContext.subject.context
                }
                it("converts cached data") {
                    expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataCallCount) == 1
                    expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataReceivedArguments?.maxCachedContexts) == testContext.config.maxCachedContexts
                    expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataReceivedArguments?.keysToConvert) == [testContext.config.mobileKey]
                }
            }
        }
        it("when called with cached flags for the context and environment") {
            let cachedFlags = ["test-flag": StorageItem.item(FeatureFlag(flagKey: "test-flag"))]
            let testContext = TestContext().withCached(flags: cachedFlags.featureFlags)
            withTimeout ? testContext.start(timeOut: 10.0) : testContext.start()

            expect(testContext.featureFlagCachingMock.getCachedDataCallCount) == 1
            expect(testContext.featureFlagCachingMock.getCachedDataReceivedCacheKey) == testContext.context.contextHash()

            expect(testContext.flagStoreMock.replaceStoreReceivedNewFlags) == cachedFlags

            expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataCallCount) == 1
            expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataReceivedArguments?.maxCachedContexts) == testContext.config.maxCachedContexts
            expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataReceivedArguments?.keysToConvert) == [testContext.config.mobileKey]
        }
        it("when called without cached flags for the context") {
            let testContext = TestContext()
            withTimeout ? testContext.start(timeOut: 10.0) : testContext.start()

            expect(testContext.featureFlagCachingMock.getCachedDataCallCount) == 1
            expect(testContext.featureFlagCachingMock.getCachedDataReceivedCacheKey) == testContext.context.contextHash()

            expect(testContext.flagStoreMock.replaceStoreCallCount) == 0

            expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataCallCount) == 1
            expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataReceivedArguments?.maxCachedContexts) == testContext.config.maxCachedContexts
            expect(testContext.serviceFactoryMock.makeCacheConverterReturnValue.convertCacheDataReceivedArguments?.keysToConvert) == [testContext.config.mobileKey]
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
            it("completes immediately without timeout") {
                testContext = TestContext()
                testContext.start(completion: startCompletion)
                expect(completed) == true
            }
            it("completes immediately with timeout") {
                testContext = TestContext()
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
                                _ = testContext.withCached(flags: FlagMaintainingMock.stubStoredItems().featureFlags)
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
                            testContext.onSyncComplete?(.flagCollection((FeatureFlagCollection([:]), nil)))
                            Thread.sleep(forTimeInterval: 1.0)
                            expect(completed) == false
                        }
                    }
                }
            }
            context("after receiving flags") {
                it("does complete without timeout") {
                    testContext.start(completion: startCompletion)
                    testContext.onSyncComplete?(.flagCollection((FeatureFlagCollection([:]), nil)))
                    expect(completed).toEventually(beTrue(), timeout: DispatchTimeInterval.seconds(2))
                }
                it("does complete with timeout") {
                    waitUntil(timeout: .seconds(3)) { done in
                        testContext.start(timeOut: 5.0, timeOutCompletion: startTimeoutCompletion(done))
                        testContext.onSyncComplete?(.flagCollection((FeatureFlagCollection([:]), nil)))
                    }
                    expect(completed).toEventually(beTrue(), timeout: DispatchTimeInterval.seconds(2))
                    expect(didTimeOut) == false
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
                            testContext = TestContext(startOnline: true)
                            testContext.start()
                            testContext.subject.setRunMode(.background)
                        }
                        it("takes the client and service objects online when background enabled") {
                            expect(testContext.subject.isOnline) == true

                            // TODO(os-tests): We need to expand this to the other OSs
                            if os == .iOS && os == SystemCapabilities.operatingSystem {
                                expect(testContext.subject.flagSynchronizer.isOnline) == os.isBackgroundEnabled
                            }
                            expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                        }
                        it("saves the config") {
                            expect(testContext.subject.service.config) == testContext.config
                            // TODO(os-tests): We need to expand this to the other OSs
                            if os == .iOS && os == SystemCapabilities.operatingSystem {
                                expect(testContext.makeFlagSynchronizerStreamingMode) == os.backgroundStreamingMode
                            }
                            expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: .background)
                            expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.config) == testContext.config
                        }
                        it("saves the context") {
                            expect(testContext.subject.context) == testContext.context
                            expect(testContext.subject.service.context) == testContext.context
                            expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                            if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                                expect(makeFlagSynchronizerReceivedParameters.service) === testContext.subject.service
                            }
                            expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.context) == testContext.context
                        }
                        it("uncaches the new contexts flags") {
                            expect(testContext.featureFlagCachingMock.getCachedDataCallCount) == 1
                            expect(testContext.featureFlagCachingMock.getCachedDataReceivedCacheKey) == testContext.context.contextHash()
                        }
                        it("records an identify event") {
                            expect(testContext.eventReporterMock.recordCallCount) == 1
                            expect((testContext.recordedEvent as? IdentifyEvent)?.context) == testContext.context
                        }
                    }
                }
            }
            context("when configured to not allow background updates") {
                OperatingSystem.allOperatingSystems.forEach { os in
                    context("on \(os)") {
                        beforeEach {
                            testContext = TestContext(startOnline: true, enableBackgroundUpdates: false)
                            testContext.start()
                            testContext.subject.setRunMode(.background)
                        }
                        it("leaves the client and service objects offline") {
                            expect(testContext.subject.isOnline) == true
                            expect(testContext.subject.flagSynchronizer.isOnline) == false
                            expect(testContext.subject.eventReporter.isOnline) == true
                        }
                        it("saves the config") {
                            expect(testContext.subject.service.config) == testContext.config
                            expect(testContext.makeFlagSynchronizerStreamingMode) == LDStreamingMode.polling
                            expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: .background)
                            expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.config) == testContext.config
                        }
                        it("saves the context") {
                            expect(testContext.subject.context) == testContext.context
                            expect(testContext.subject.service.context) == testContext.context
                            expect(testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                            if let makeFlagSynchronizerReceivedParameters = testContext.serviceFactoryMock.makeFlagSynchronizerReceivedParameters {
                                expect(makeFlagSynchronizerReceivedParameters.service.context) == testContext.context
                            }
                            expect(testContext.serviceFactoryMock.makeEventReporterReceivedService?.context) == testContext.context
                        }
                        it("uncaches the new contexts flags") {
                            expect(testContext.featureFlagCachingMock.getCachedDataCallCount) == 1
                            expect(testContext.featureFlagCachingMock.getCachedDataReceivedCacheKey) == testContext.context.contextHash()
                        }
                        it("records an identify event") {
                            expect(testContext.eventReporterMock.recordCallCount) == 1
                            expect((testContext.recordedEvent as? IdentifyEvent)?.context) == testContext.context
                        }
                    }
                }
            }
        }
    }

    private func identifySpec() {
        describe("identify") {
            it("when the client is online") {
                let testContext = TestContext(startOnline: true)
                testContext.start()
                testContext.featureFlagCachingMock.reset()

                let newContext = LDContext.stub()
                testContext.subject.internalIdentify(newContext: newContext)

                expect(testContext.subject.context) == newContext
                expect(testContext.subject.service.context) == newContext
                expect(testContext.serviceMock.clearFlagResponseCacheCallCount) == 2
                expect(testContext.makeFlagSynchronizerService?.context) == newContext

                expect(testContext.subject.isOnline) == true
                expect(testContext.subject.eventReporter.isOnline) == true
                expect(testContext.subject.flagSynchronizer.isOnline) == true

                expect(testContext.featureFlagCachingMock.getCachedDataCallCount) == 1
                expect(testContext.featureFlagCachingMock.getCachedDataReceivedCacheKey) == newContext.contextHash()

                expect(testContext.eventReporterMock.recordReceivedEvent?.kind == .identify).to(beTrue())
            }
            it("when the client is offline") {
                let testContext = TestContext()
                testContext.start()
                testContext.featureFlagCachingMock.reset()

                let newContext = LDContext.stub()
                testContext.subject.internalIdentify(newContext: newContext)

                expect(testContext.subject.context) == newContext
                expect(testContext.subject.service.context) == newContext
                expect(testContext.serviceMock.clearFlagResponseCacheCallCount) == 2
                expect(testContext.makeFlagSynchronizerService?.context) == newContext

                expect(testContext.subject.isOnline) == false
                expect(testContext.subject.eventReporter.isOnline) == false
                expect(testContext.subject.flagSynchronizer.isOnline) == false

                expect(testContext.featureFlagCachingMock.getCachedDataCallCount) == 1
                expect(testContext.featureFlagCachingMock.getCachedDataReceivedCacheKey) == newContext.contextHash()

                expect(testContext.eventReporterMock.recordReceivedEvent?.kind == .identify).to(beTrue())
            }
            it("when the new context has cached feature flags") {
                let stubFlags = FlagMaintainingMock.stubStoredItems()
                let newContext = LDContext.stub()
                let testContext = TestContext().withCached(contextKey: newContext.contextHash(), flags: stubFlags.featureFlags)
                testContext.start()
                testContext.featureFlagCachingMock.reset()

                testContext.subject.internalIdentify(newContext: newContext)

                expect(testContext.subject.context) == newContext
                expect(testContext.flagStoreMock.replaceStoreCallCount) == 1
                expect(testContext.flagStoreMock.replaceStoreReceivedNewFlags) == stubFlags
            }

            it("when we have opted into auto environment attributes") {
                let testContext = TestContext(startOnline: true)
                testContext.config.autoEnvAttributes = true
                testContext.start()
                testContext.featureFlagCachingMock.reset()

                let newContext = LDContext.stub()
                testContext.subject.internalIdentify(newContext: newContext)

                expect(newContext.contextKeys().count) < testContext.subject.service.context.contextKeys().count

                let kinds = testContext.subject.service.context.contextKeys().keys

                expect(kinds.contains(AutoEnvContextModifier.ldDeviceKind)) == true
                expect(kinds.contains(AutoEnvContextModifier.ldApplicationKind)) == true
            }

            it("only triggered if context is different") {
                let testContext = TestContext(startOnline: true)
                testContext.start()
                testContext.featureFlagCachingMock.reset()

                testContext.subject.internalIdentify(newContext: testContext.context)
                testContext.subject.internalIdentify(newContext: testContext.context)
                testContext.subject.internalIdentify(newContext: testContext.context)
                testContext.subject.internalIdentify(newContext: testContext.context)

                expect(testContext.flagStoreMock.replaceStoreCallCount) == 0
                expect(testContext.makeFlagSynchronizerService?.context) == testContext.context

                expect(testContext.subject.isOnline) == true
                expect(testContext.subject.eventReporter.isOnline) == true
                expect(testContext.subject.flagSynchronizer.isOnline) == true
                expect(testContext.eventReporterMock.recordReceivedEvent?.kind == .identify).to(beTrue())
            }
        }
    }

    private func setOnlineSpec() {
        describe("setOnline") {
            it("set online when the client is offline") {
                let testContext = TestContext()
                waitUntil { done in
                    testContext.start {
                        testContext.subject.setOnline(true)
                        done()
                    }
                }

                expect(testContext.throttlerMock?.runThrottledCallCount) == 1
                expect(testContext.subject.isOnline) == true
                expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
            }
            it("set offline when the client is online") {
                let testContext = TestContext(startOnline: true)
                testContext.start()
                testContext.throttlerMock?.runThrottledCallCount = 0
                testContext.subject.setOnline(false)

                expect(testContext.throttlerMock?.runThrottledCallCount) == 0
                expect(testContext.subject.isOnline) == false
                expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
            }
            context("set online when the client runs in the background") {
                OperatingSystem.allOperatingSystems.forEach { os in
                    context("on \(os)") {
                        it("while configured to enable background updates") {
                            let testContext = TestContext()
                            waitUntil { testContext.start(runMode: .background, completion: $0) }
                            testContext.subject.setOnline(true)

                            expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline

                            // TODO(os-tests): We need to expand this to the other OSs
                            if os == .iOS && os == SystemCapabilities.operatingSystem {
                                expect(testContext.throttlerMock?.runThrottledCallCount) == (os.isBackgroundEnabled ? 1 : 0)
                                expect(testContext.subject.isOnline) == os.isBackgroundEnabled
                                expect(testContext.makeFlagSynchronizerStreamingMode) == os.backgroundStreamingMode
                            }

                            expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: testContext.subject.runMode)
                            expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
                        }
                        it("while configured to disable background updates") {
                            let testContext = TestContext(enableBackgroundUpdates: false)
                            waitUntil { testContext.start(runMode: .background, completion: $0) }
                            testContext.subject.setOnline(true)

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
            it("set online when the mobile key is empty") {
                let testContext = TestContext(newConfig: LDConfig(mobileKey: "", autoEnvAttributes: .disabled))
                waitUntil { testContext.start(completion: $0) }
                testContext.subject.setOnline(true)

                expect(testContext.throttlerMock?.runThrottledCallCount) == 0
                expect(testContext.subject.isOnline) == false
                expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                expect(testContext.subject.eventReporter.isOnline) == testContext.subject.isOnline
            }
        }
    }

    private func closeSpec() {
        describe("stop") {
            it("when started and online") {
                let testContext = TestContext(startOnline: true)
                testContext.start()
                testContext.subject.close()

                expect(testContext.subject.isOnline) == false
                expect(testContext.eventReporterMock.flushCallCount) == 1
            }
            it("when started and offline") {
                let testContext = TestContext()
                testContext.start()
                testContext.subject.close()

                expect(testContext.subject.isOnline) == false
                expect(testContext.eventReporterMock.flushCallCount) == 1
            }
            it("when already stopped") {
                let testContext = TestContext()
                testContext.start()
                testContext.subject.close()
                testContext.subject.close()

                expect(testContext.subject.isOnline) == false
                expect(testContext.eventReporterMock.flushCallCount) == 1
            }
        }
    }

    private func trackEventSpec() {
        describe("track event") {
            it("records a custom event") {
                let testContext = TestContext()
                testContext.start()
                testContext.subject.track(key: "customEvent", data: "abc", metricValue: 5.0)
                let receivedEvent = testContext.eventReporterMock.recordReceivedEvent as? CustomEvent
                expect(receivedEvent?.key) == "customEvent"
                expect(receivedEvent?.context) == testContext.context
                expect(receivedEvent?.data) == "abc"
                expect(receivedEvent?.metricValue) == 5.0
            }
            context("does not record when client was stopped") {
                let testContext = TestContext()
                testContext.start()
                testContext.subject.close()
                let priorRecordedEvents = testContext.eventReporterMock.recordCallCount
                testContext.subject.track(key: "abc")
                expect(testContext.eventReporterMock.recordCallCount) == priorRecordedEvents
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
                    testContext.flagStoreMock.replaceStore(newStoredItems: FlagMaintainingMock.stubStoredItems())
                }
                context("non-Optional default value") {
                    it("returns the flag value") {
                        expect(.bool(testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool))) == DarklyServiceMock.FlagValues.bool
                        expect(.number(Double(testContext.subject.intVariation(forKey: DarklyServiceMock.FlagKeys.int, defaultValue: DefaultFlagValues.int)))) == DarklyServiceMock.FlagValues.int
                        expect(.number(testContext.subject.doubleVariation(forKey: DarklyServiceMock.FlagKeys.double, defaultValue: DefaultFlagValues.double))) == DarklyServiceMock.FlagValues.double
                        expect(.string(testContext.subject.stringVariation(forKey: DarklyServiceMock.FlagKeys.string, defaultValue: DefaultFlagValues.string))) == DarklyServiceMock.FlagValues.string
                        expect(testContext.subject.jsonVariation(forKey: DarklyServiceMock.FlagKeys.array, defaultValue: DefaultFlagValues.array)) == DarklyServiceMock.FlagValues.array
                        expect(testContext.subject.jsonVariation(forKey: DarklyServiceMock.FlagKeys.dictionary, defaultValue: DefaultFlagValues.dictionary)) == DarklyServiceMock.FlagValues.dictionary
                    }
                    it("records a flag evaluation event") {
                        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == DarklyServiceMock.FlagKeys.bool
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value) == DarklyServiceMock.FlagValues.bool
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue) == .bool(DefaultFlagValues.bool)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag) == testContext.flagStoreMock.storedItems.featureFlags[DarklyServiceMock.FlagKeys.bool]
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.context) == testContext.context
                    }
                }
            }
            context("flag store does not contain the requested value") {
                context("non-Optional default value") {
                    it("returns the default value") {
                        expect(testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)) == DefaultFlagValues.bool
                        expect(testContext.subject.intVariation(forKey: DarklyServiceMock.FlagKeys.int, defaultValue: DefaultFlagValues.int)) == DefaultFlagValues.int
                        expect(testContext.subject.doubleVariation(forKey: DarklyServiceMock.FlagKeys.double, defaultValue: DefaultFlagValues.double)) == DefaultFlagValues.double
                        expect(testContext.subject.stringVariation(forKey: DarklyServiceMock.FlagKeys.string, defaultValue: DefaultFlagValues.string)) == DefaultFlagValues.string
                        expect(testContext.subject.jsonVariation(forKey: DarklyServiceMock.FlagKeys.array, defaultValue: DefaultFlagValues.array)) == DefaultFlagValues.array
                        expect(testContext.subject.jsonVariation(forKey: DarklyServiceMock.FlagKeys.dictionary, defaultValue: DefaultFlagValues.dictionary)) == DefaultFlagValues.dictionary
                    }
                    it("records a flag evaluation event") {
                        _ = testContext.subject.boolVariation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsCallCount) == 1
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.flagKey) == DarklyServiceMock.FlagKeys.bool
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.value) == .bool(DefaultFlagValues.bool)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.defaultValue) == .bool(DefaultFlagValues.bool)
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.featureFlag).to(beNil())
                        expect(testContext.eventReporterMock.recordFlagEvaluationEventsReceivedArguments?.context) == testContext.context
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
        it("flag collection") {
            self.onSyncCompleteSuccessReplacingFlagsSpec()
        }
        it("streaming patch") {
            self.onSyncCompleteStreamingPatchSpec()
        }
        it("streaming delete") {
            self.onSyncCompleteDeleteFlagSpec()
        }
    }

    private func onSyncCompleteSuccessReplacingFlagsSpec() {
        let testContext = TestContext(startOnline: true)
        testContext.start()
        testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()

        let newStoredItems = ["flag1": StorageItem.item(FeatureFlag(flagKey: "flag1"))]
        var updateDate: Date!
        waitUntil { done in
            testContext.changeNotifierMock.notifyObserversCallback = done
            updateDate = Date()
            testContext.onSyncComplete?(.flagCollection((FeatureFlagCollection(newStoredItems.featureFlags), nil)))
        }

        expect(testContext.flagStoreMock.replaceStoreCallCount) == 1
        expect(testContext.flagStoreMock.replaceStoreReceivedNewFlags) == newStoredItems

        expect(testContext.featureFlagCachingMock.saveCachedDataCallCount) == 1
        expect(testContext.featureFlagCachingMock.saveCachedDataReceivedArguments?.storedItems) == newStoredItems
        expect(testContext.featureFlagCachingMock.saveCachedDataReceivedArguments?.cacheKey) == testContext.context.contextHash()
        expect(testContext.featureFlagCachingMock.saveCachedDataReceivedArguments?.lastUpdated).to(beCloseTo(updateDate, within: Constants.updateThreshold))

        expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
        expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.newFlags) == testContext.flagStoreMock.storedItems.featureFlags
        expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags) == [:]
    }

    func onSyncCompleteStreamingPatchSpec() {
        let stubFlags = FlagMaintainingMock.stubStoredItems()
        let testContext = TestContext(startOnline: true).withCached(flags: stubFlags.featureFlags)
        testContext.start()
        testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
        let updateFlag = FeatureFlag(flagKey: "abc")

        var updateDate: Date!
        waitUntil { done in
            testContext.changeNotifierMock.notifyObserversCallback = done
            updateDate = Date()
            testContext.onSyncComplete?(.patch(updateFlag))
        }

        expect(testContext.flagStoreMock.updateStoreCallCount) == 1
        expect(testContext.flagStoreMock.updateStoreReceivedUpdatedFlag) == updateFlag

        expect(testContext.featureFlagCachingMock.saveCachedDataCallCount) == 1
        expect(testContext.featureFlagCachingMock.saveCachedDataReceivedArguments?.storedItems) == testContext.flagStoreMock.storedItems
        expect(testContext.featureFlagCachingMock.saveCachedDataReceivedArguments?.cacheKey) == testContext.context.contextHash()
        expect(testContext.featureFlagCachingMock.saveCachedDataReceivedArguments?.lastUpdated).to(beCloseTo(updateDate, within: Constants.updateThreshold))

        expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
        expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.newFlags) == testContext.flagStoreMock.storedItems.featureFlags
        expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == stubFlags.featureFlags).to(beTrue())
    }

    func onSyncCompleteDeleteFlagSpec() {
        let stubFlags = FlagMaintainingMock.stubStoredItems()
        let testContext = TestContext(startOnline: true).withCached(flags: stubFlags.featureFlags)
        testContext.start()
        testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
        let deleteResponse = DeleteResponse(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version + 1)

        var updateDate: Date!
        waitUntil { done in
            testContext.changeNotifierMock.notifyObserversCallback = done
            updateDate = Date()
            testContext.onSyncComplete?(.delete(deleteResponse))
        }

        expect(testContext.flagStoreMock.deleteFlagCallCount) == 1
        expect(testContext.flagStoreMock.deleteFlagReceivedDeleteResponse) == deleteResponse

        expect(testContext.featureFlagCachingMock.saveCachedDataCallCount) == 1
        expect(testContext.featureFlagCachingMock.saveCachedDataReceivedArguments?.storedItems.featureFlags) == testContext.flagStoreMock.storedItems.featureFlags
        expect(testContext.featureFlagCachingMock.saveCachedDataReceivedArguments?.cacheKey) == testContext.context.contextHash()
        expect(testContext.featureFlagCachingMock.saveCachedDataReceivedArguments?.lastUpdated).to(beCloseTo(updateDate, within: Constants.updateThreshold))

        expect(testContext.changeNotifierMock.notifyObserversCallCount) == 1
        expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.newFlags) == testContext.flagStoreMock.storedItems.featureFlags
        expect(testContext.changeNotifierMock.notifyObserversReceivedArguments?.oldFlags == stubFlags.featureFlags).to(beTrue())
    }

    func onSyncCompleteErrorSpec() {
        func runTest(_ ctx: String,
                     _ err: SynchronizingError,
                     testError: @escaping ((ConnectionInformation.LastConnectionFailureReason) -> Void)) {
            it(ctx) {
                let testContext = TestContext(startOnline: true)
                testContext.start()
                testContext.subject.flagChangeNotifier = ClientServiceMockFactory().makeFlagChangeNotifier()
                testContext.onSyncComplete?(.error(err))

                expect(testContext.subject.isOnline) == !err.isClientUnauthorized
                expect(testContext.featureFlagCachingMock.saveCachedDataCallCount) == 0
                expect(testContext.changeNotifierMock.notifyObserversCallCount) == 0
                expect(testContext.subject.getConnectionInformation().lastFailedConnection).to(beCloseTo(Date(), within: 5.0))
                testError(testContext.subject.getConnectionInformation().lastConnectionFailureReason)
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
        describe("didEnterBackground notification") {
            context("after starting client") {
                context("when online") {
                    OperatingSystem.allOperatingSystems.forEach { os in
                        context("on \(os)") {
                            it("background updates disabled") {
                                let testContext = TestContext(startOnline: true, enableBackgroundUpdates: false)
                                testContext.start()
                                NotificationCenter.default.post(name: SystemCapabilities.backgroundNotification!, object: self)
                                expect(testContext.subject.runMode).toEventually(equal(LDClientRunMode.background))

                                expect(testContext.subject.isOnline) == true
                                expect(testContext.subject.runMode) == LDClientRunMode.background
                                expect(testContext.eventReporterMock.isOnline) == true
                                expect(testContext.flagSynchronizerMock.isOnline) == false
                            }
                            it("background updates enabled") {
                                let testContext = TestContext(startOnline: true)
                                testContext.start()

                                waitUntil { done in
                                    NotificationCenter.default.post(name: SystemCapabilities.backgroundNotification!, object: self)
                                    DispatchQueue(label: "BackgroundUpdatesEnabled").asyncAfter(deadline: .now() + 0.2, execute: done)
                                }

                                expect(testContext.subject.isOnline) == true
                                expect(testContext.subject.runMode) == LDClientRunMode.background
                                expect(testContext.eventReporterMock.isOnline) == true

                                // TODO(os-tests): We need to expand this to the other OSs
                                if os == .iOS && os == SystemCapabilities.operatingSystem {
                                    expect(testContext.flagSynchronizerMock.isOnline) == os.isBackgroundEnabled
                                    expect(testContext.flagSynchronizerMock.streamingMode) == os.backgroundStreamingMode
                                }
                            }
                        }
                    }
                }
                it("when offline") {
                    let testContext = TestContext()
                    testContext.start()
                    NotificationCenter.default.post(name: SystemCapabilities.backgroundNotification!, object: self)

                    expect(testContext.subject.isOnline) == false
                    expect(testContext.subject.runMode) == LDClientRunMode.background
                    expect(testContext.eventReporterMock.isOnline) == false
                    expect(testContext.flagSynchronizerMock.isOnline) == false
                }
            }
        }

        describe("willEnterForeground notification") {
            context("after starting client") {
                OperatingSystem.allOperatingSystems.forEach { os in
                    context("on \(os)") {
                        it("when online at foreground notification") {
                            let testContext = TestContext(startOnline: true)
                            testContext.start(runMode: .background)
                            NotificationCenter.default.post(name: SystemCapabilities.foregroundNotification!, object: self)

                            expect(testContext.subject.isOnline) == true
                            expect(testContext.subject.runMode) == LDClientRunMode.foreground
                            expect(testContext.eventReporterMock.isOnline) == true
                            expect(testContext.flagSynchronizerMock.isOnline) == true
                        }
                        it("when offline at foreground notification") {
                            let testContext = TestContext()
                            testContext.start(runMode: .background)
                            NotificationCenter.default.post(name: SystemCapabilities.foregroundNotification!, object: self)

                            expect(testContext.subject.isOnline) == false
                            expect(testContext.subject.runMode) == LDClientRunMode.foreground
                            expect(testContext.eventReporterMock.isOnline) == false
                            expect(testContext.flagSynchronizerMock.isOnline) == false
                        }
                    }
                }
            }
        }

        // TODO(os-tests): These tests won't actually run until we support macos targets
        #if os(OSX)
        describe("change run mode on macOS") {
            context("while online") {
                context("and running in the foreground") {
                    context("set background") {
                        context("with background updates enabled") {
                            it("streaming mode") {
                                let testContext = TestContext(startOnline: true)
                                testContext.start()
                                testContext.subject.setRunMode(.background)

                                expect(testContext.eventReporterMock.isOnline) == true
                                expect(testContext.flagSynchronizerMock.isOnline) == true
                                expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.streaming
                            }
                            it("polling mode") {
                                let testContext = TestContext(startOnline: true, streamingMode: .polling)
                                testContext.start()
                                testContext.subject.setRunMode(.background)

                                expect(testContext.eventReporterMock.isOnline) == true
                                expect(testContext.flagSynchronizerMock.isOnline) == true
                                expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.polling
                                expect(testContext.flagSynchronizerMock.pollingInterval) == testContext.config.flagPollingInterval(runMode: .background)
                            }
                        }
                        it("with background updates disabled") {
                            let testContext = TestContext(startOnline: true, enableBackgroundUpdates: false)
                            testContext.start()
                            testContext.subject.setRunMode(.background)

                            expect(testContext.eventReporterMock.isOnline) == true
                            expect(testContext.flagSynchronizerMock.isOnline) == false
                            expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.polling
                            expect(testContext.flagSynchronizerMock.pollingInterval) == testContext.config.flagPollingInterval(runMode: .background)
                        }
                    }
                    it("set foreground") {
                        let testContext = TestContext(startOnline: true)
                        testContext.start()
                        let eventReporterIsOnlineSetCount = testContext.eventReporterMock.isOnlineSetCount
                        let flagSynchronizerIsOnlineSetCount = testContext.flagSynchronizerMock.isOnlineSetCount
                        let makeFlagSynchronizerCallCount = testContext.serviceFactoryMock.makeFlagSynchronizerCallCount
                        testContext.subject.setRunMode(.foreground)

                        expect(testContext.eventReporterMock.isOnline) == true
                        expect(testContext.eventReporterMock.isOnlineSetCount) == eventReporterIsOnlineSetCount
                        expect(testContext.flagSynchronizerMock.isOnline) == true
                        expect(testContext.flagSynchronizerMock.isOnlineSetCount) == flagSynchronizerIsOnlineSetCount
                        expect(testContext.serviceFactoryMock.makeFlagSynchronizerCallCount) == makeFlagSynchronizerCallCount
                    }
                }
                context("and running in the background") {
                    it("set background") {
                        let testContext = TestContext(startOnline: true)
                        testContext.start()
                        testContext.subject.setRunMode(.background)
                        let eventReporterIsOnlineSetCount = testContext.eventReporterMock.isOnlineSetCount
                        let flagSynchronizerIsOnlineSetCount = testContext.flagSynchronizerMock.isOnlineSetCount
                        let makeFlagSynchronizerCallCount = testContext.serviceFactoryMock.makeFlagSynchronizerCallCount
                        testContext.subject.setRunMode(.background)

                        expect(testContext.eventReporterMock.isOnline) == true
                        expect(testContext.eventReporterMock.isOnlineSetCount) == eventReporterIsOnlineSetCount
                        expect(testContext.flagSynchronizerMock.isOnline) == true
                        expect(testContext.flagSynchronizerMock.isOnlineSetCount) == flagSynchronizerIsOnlineSetCount
                        expect(testContext.serviceFactoryMock.makeFlagSynchronizerCallCount) == makeFlagSynchronizerCallCount
                    }
                    context("set foreground") {
                        it("streaming mode") {
                            let testContext = TestContext(startOnline: true)
                            testContext.start(runMode: .background)
                            testContext.subject.setRunMode(.foreground)

                            expect(testContext.eventReporterMock.isOnline) == true
                            expect(testContext.flagSynchronizerMock.isOnline) == true
                            expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.streaming
                        }
                        it("polling mode") {
                            let testContext = TestContext(startOnline: true, streamingMode: .polling)
                            testContext.start(runMode: .background)
                            testContext.subject.setRunMode(.foreground)

                            expect(testContext.eventReporterMock.isOnline) == true
                            expect(testContext.flagSynchronizerMock.isOnline) == true
                            expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.polling
                            expect(testContext.flagSynchronizerMock.pollingInterval) == testContext.config.flagPollingInterval(runMode: .foreground)
                        }
                    }
                }
            }
            context("while offline") {
                context("and running in the foreground") {
                    context("set background") {
                        it("with background updates enabled") {
                            let testContext = TestContext()
                            waitUntil { testContext.start(completion: $0) }

                            testContext.subject.setRunMode(.background)

                            expect(testContext.eventReporterMock.isOnline) == false
                            expect(testContext.flagSynchronizerMock.isOnline) == false
                            expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.streaming
                        }
                        it("with background updates disabled") {
                            let testContext = TestContext(enableBackgroundUpdates: false)
                            waitUntil { testContext.start(completion: $0) }

                            testContext.subject.setRunMode(.background)

                            expect(testContext.eventReporterMock.isOnline) == false
                            expect(testContext.flagSynchronizerMock.isOnline) == false
                            expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.polling
                            expect(testContext.flagSynchronizerMock.pollingInterval) == testContext.config.flagPollingInterval(runMode: .background)
                        }
                    }
                    it("set foreground") {
                        let testContext = TestContext()
                        waitUntil { testContext.start(completion: $0) }

                        let eventReporterIsOnlineSetCount = testContext.eventReporterMock.isOnlineSetCount
                        let flagSynchronizerIsOnlineSetCount = testContext.flagSynchronizerMock.isOnlineSetCount
                        let makeFlagSynchronizerCallCount = testContext.serviceFactoryMock.makeFlagSynchronizerCallCount
                        testContext.subject.setRunMode(.foreground)

                        expect(testContext.eventReporterMock.isOnline) == false
                        expect(testContext.eventReporterMock.isOnlineSetCount) == eventReporterIsOnlineSetCount
                        expect(testContext.flagSynchronizerMock.isOnline) == false
                        expect(testContext.flagSynchronizerMock.isOnlineSetCount) == flagSynchronizerIsOnlineSetCount
                        expect(testContext.serviceFactoryMock.makeFlagSynchronizerCallCount) == makeFlagSynchronizerCallCount
                    }
                }
                context("and running in the background") {
                    it("set background") {
                        let testContext = TestContext()
                        waitUntil { testContext.start(runMode: .background, completion: $0) }

                        let eventReporterIsOnlineSetCount = testContext.eventReporterMock.isOnlineSetCount
                        let flagSynchronizerIsOnlineSetCount = testContext.flagSynchronizerMock.isOnlineSetCount
                        let makeFlagSynchronizerCallCount = testContext.serviceFactoryMock.makeFlagSynchronizerCallCount
                        testContext.subject.setRunMode(.background)

                        expect(testContext.eventReporterMock.isOnline) == false
                        expect(testContext.eventReporterMock.isOnlineSetCount) == eventReporterIsOnlineSetCount
                        expect(testContext.flagSynchronizerMock.isOnline) == false
                        expect(testContext.flagSynchronizerMock.isOnlineSetCount) == flagSynchronizerIsOnlineSetCount
                        expect(testContext.serviceFactoryMock.makeFlagSynchronizerCallCount) == makeFlagSynchronizerCallCount
                    }
                    context("set foreground") {
                        it("streaming mode") {
                            let testContext = TestContext()
                            waitUntil { testContext.start(runMode: .background, completion: $0) }

                            testContext.subject.setRunMode(.foreground)

                            expect(testContext.eventReporterMock.isOnline) == false
                            expect(testContext.flagSynchronizerMock.isOnline) == false
                            expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.streaming
                        }
                        it("polling mode") {
                            let testContext = TestContext(streamingMode: .polling)
                            waitUntil { testContext.start(runMode: .background, completion: $0) }

                            testContext.subject.setRunMode(.foreground)

                            expect(testContext.eventReporterMock.isOnline) == false
                            expect(testContext.flagSynchronizerMock.isOnline) == false
                            expect(testContext.flagSynchronizerMock.streamingMode) == LDStreamingMode.polling
                            expect(testContext.flagSynchronizerMock.pollingInterval) == testContext.config.flagPollingInterval(runMode: .foreground)
                        }
                    }
                }
            }
        }
        #endif
    }

    private func streamingModeSpec() {
        var testContext: TestContext!

        describe("flag synchronizer streaming mode") {
            OperatingSystem.allOperatingSystems.forEach { os in
                it("on \(os) sets the flag synchronizer streaming mode") {
                    // TODO(os-tests): We need to expand this to the other OSs
                    if os == .watchOS {
                        return
                    }

                    testContext = TestContext(startOnline: true)
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
        let stubFlags = FlagMaintainingMock.stubStoredItems()
        describe("allFlags") {
            it("returns all non-null flag values from store") {
                let testContext = TestContext().withCached(flags: stubFlags.featureFlags)
                testContext.start()
                expect(testContext.subject.allFlags) == stubFlags.featureFlags.compactMapValues { $0.value }
            }
            it("returns nil when client is closed") {
                let testContext = TestContext().withCached(flags: stubFlags.featureFlags)
                testContext.start()
                testContext.subject.close()
                expect(testContext.subject.allFlags).to(beNil())
            }
        }
    }

    private func connectionInformationSpec() {
        describe("ConnectionInformation") {
            it("when client was started in foreground") {
                let testContext = TestContext(startOnline: true)
                testContext.start()
                expect(testContext.subject.isOnline) == true
                expect(testContext.subject.connectionInformation.currentConnectionMode).to(equal(.establishingStreamingConnection))
            }
            it("when client was started in background") {
                let testContext = TestContext(startOnline: true, enableBackgroundUpdates: false)
                testContext.start()
                testContext.subject.setRunMode(.background)
                expect(testContext.subject.connectionInformation.currentConnectionMode).to(equal(.offline))
            }
            it("client started offline") {
                let testContext = TestContext()
                testContext.start()
                expect(testContext.subject.connectionInformation.currentConnectionMode).to(equal(.offline))
            }
        }
    }

    private func variationDetailSpec() {
        describe("variationDetail") {
            it("when flag doesn't exist") {
                let testContext = TestContext()
                testContext.start()
                let detail = testContext.subject.boolVariationDetail(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultFlagValues.bool).reason
                if let errorKind = detail?["errorKind"] {
                    expect(errorKind) == "FLAG_NOT_FOUND"
                }
            }
        }
    }

    private func isInitializedSpec() {
        describe("isInitialized") {
            it("when client was started but no flag update") {
                let testContext = TestContext(startOnline: true)
                testContext.start()

                expect(testContext.subject.isInitialized) == false

                testContext.subject.close()
                expect(testContext.subject.isInitialized) == false
            }
            it("when client was started offline") {
                let testContext = TestContext()
                testContext.start()

                expect(testContext.subject.isInitialized) == true

                testContext.subject.close()
                expect(testContext.subject.isInitialized) == false
            }
            it("when client was started and after receiving flags") {
                let testContext = TestContext(startOnline: true)
                testContext.start()
                testContext.onSyncComplete?(.flagCollection((FeatureFlagCollection([:]), nil)))

                expect(testContext.subject.isInitialized).toEventually(beTrue(), timeout: DispatchTimeInterval.seconds(2))

                testContext.subject.close()
                expect(testContext.subject.isInitialized) == false
            }
        }
    }
}

extension FeatureFlagCachingMock {
    func reset() {
        getCachedDataCallCount = 0
        getCachedDataReceivedCacheKey = nil
        getCachedDataReturnValue = nil
        saveCachedDataCallCount = 0
        saveCachedDataReceivedArguments = nil
    }
}

extension OperatingSystem {
    var backgroundStreamingMode: LDStreamingMode {
        self == .macOS ? .streaming : .polling
    }
}

private class ErrorMock: Error { }
