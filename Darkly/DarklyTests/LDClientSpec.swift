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
        var subject: LDClient!
        var user: LDUser!
        var config: LDConfig!
        // mock getters based on setting up the user & subject
        var serviceFactoryMock: ClientServiceMockFactory! { return subject.serviceFactory as? ClientServiceMockFactory }
        var flagCacheMock: UserFlagCachingMock! { return serviceFactoryMock.userFlagCache }
        var flagStoreMock: FlagMaintainingMock! { return user.flagStore as? FlagMaintainingMock }
        var flagSynchronizerMock: LDFlagSynchronizingMock! { return subject.flagSynchronizer as? LDFlagSynchronizingMock }
        var eventReporterMock: LDEventReportingMock! { return subject.eventReporter as? LDEventReportingMock }
        var changeNotifierMock: FlagChangeNotifyingMock! { return subject.flagChangeNotifier as? FlagChangeNotifyingMock }
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
        // user flags
        var oldFlags: [LDFlagKey: FeatureFlag]!
        var oldFlagSource: LDFlagValueSource!

        init(startOnline: Bool = false, runMode: LDClientRunMode = .foreground) {
            config = LDConfig.stub
            config.startOnline = startOnline
            config.eventFlushIntervalMillis = 300_000   //5 min...don't want this to trigger

            user = LDUser.stub()
            oldFlags = user.flagStore.featureFlags
            oldFlagSource = user.flagStore.flagValueSource

            subject = LDClient.makeClient(with: ClientServiceMockFactory(), runMode: runMode)
            self.setFlagStoreCallbackToMimicRealFlagStore()
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
                    expect(testContext.makeFlagSynchronizerStreamingMode) == LDStreamingMode.polling
                    expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: .foreground)
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
                            testContext.subject.isOnline = true
                        }
                        it("leaves the client and service objects offline") {
                            expect(testContext.subject.isOnline) == false
                            expect(testContext.subject.flagSynchronizer.isOnline) == testContext.subject.isOnline
                            expect(testContext.makeFlagSynchronizerStreamingMode) == LDStreamingMode.polling
                            expect(testContext.makeFlagSynchronizerPollingInterval) == testContext.config.flagPollingInterval(runMode: .foreground)

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
                    expect(testContext.subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: DefaultFlagValues.dictionary) == DarklyServiceMock.FlagValues.dictionary)
                        .to(beTrue())
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
                    expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.bool, fallback: DefaultFlagValues.bool)
                        == (DarklyServiceMock.FlagValues.bool, LDFlagValueSource.server)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.int, fallback: DefaultFlagValues.int)
                        == (DarklyServiceMock.FlagValues.int, LDFlagValueSource.server)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.double, fallback: DefaultFlagValues.double)
                        == (DarklyServiceMock.FlagValues.double, LDFlagValueSource.server)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.string, fallback: DefaultFlagValues.string)
                        == (DarklyServiceMock.FlagValues.string, LDFlagValueSource.server)).to(beTrue())
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
                    expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.double, fallback: DefaultFlagValues.double)
                        == (DefaultFlagValues.double, LDFlagValueSource.fallback)).to(beTrue())
                    expect(testContext.subject.variationAndSource(forKey: BadFlagKeys.string, fallback: DefaultFlagValues.string)
                        == (DefaultFlagValues.string, LDFlagValueSource.fallback)).to(beTrue())
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
            var receivedChangedFlag: LDChangedFlag?

            beforeEach {
                testContext.subject.start(mobileKey: Constants.mockMobileKey, config: testContext.config, user: testContext.user)
                changedFlag = LDChangedFlag(key: DarklyServiceMock.FlagKeys.bool, oldValue: false, oldValueSource: .cache, newValue: true, newValueSource: .server)

                testContext.subject.observe(DarklyServiceMock.FlagKeys.bool, owner: self, observer: { (change) in
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

                testContext.subject.observe([DarklyServiceMock.FlagKeys.bool], owner: self, observer: { (changes) in
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

                testContext.subject.observeAll(owner: self, observer: { (changes) in
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

    func onSyncCompleteSpec() {
        describe("on sync complete") {
            onSyncCompleteSuccessSpec()
            onSyncCompleteErrorSpec()
        }
    }

    func onSyncCompleteSuccessSpec() {
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
    func onSyncCompleteSuccessReplacingFlagsSpec(streamingMode: LDStreamingMode, eventType: DarklyEventSource.LDEvent.EventType? = nil) {
        var testContext: TestContext!
        var newFlags: [LDFlagKey: Any]!
        var eventType: DarklyEventSource.LDEvent.EventType?

        beforeEach {
            testContext = TestContext(startOnline: true)
            eventType = streamingMode == .streaming ? eventType : nil
        }

        context("flags have different values") {
            beforeEach {
                let newBoolFeatureFlag = FeatureFlag(value: !DarklyServiceMock.FlagValues.bool, version: DarklyServiceMock.Constants.version + 1)
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
                newFlags[Constants.newFlagKey] = FeatureFlag(value: Constants.newFlagValue, version: 1).dictionaryValue(exciseNil: false)
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
                                                                               version: DarklyServiceMock.Constants.version + 1)
                let newIntFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.int + 1, version: DarklyServiceMock.Constants.version + 1)
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
}
