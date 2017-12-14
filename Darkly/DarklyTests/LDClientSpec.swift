//
//  LDClientSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 11/13/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
@testable import Darkly

final class LDClientSpec: QuickSpec {
    struct Constants {
        fileprivate static let mockMobileKey = "mockMobileKey"
        fileprivate static let alternateMockUrl = URL(string: "https://dummy.alternate.com")!
    }

    override func spec() {
        var subject: LDClient!
        var user: LDUser!
        var config: LDConfig!
        var mockFactory: ClientServiceMockFactory! { return subject.serviceFactory as? ClientServiceMockFactory }

        beforeEach {
            subject = LDClient.makeClient(with: ClientServiceMockFactory())

            config = LDConfig.stub
            config.startOnline = false
            config.eventFlushIntervalMillis = 300_000   //5 min...don't want this to trigger

            user = LDUser.stub()
        }

        describe("start") {
            context("when configured to start online") {
                beforeEach {
                    config.startOnline = true

                    subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                }
                it("takes the client and service objects online") {
                    expect(subject.isOnline) == true
                    expect(subject.flagSynchronizer.isOnline) == subject.isOnline
                    expect(subject.eventReporter.isOnline) == subject.isOnline
                }
                it("saves the config") {
                    expect(subject.config) == config
                    expect(subject.service.config) == config
                    expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.streamingMode) == config.streamingMode
                        expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == config.flagPollingInterval(runMode: subject.runMode)
                    }
                    expect(subject.eventReporter.config) == config
                }
                it("saves the user") {
                    expect(subject.user) == user
                    expect(subject.service.user) == user
                    expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service) === subject.service
                    }
                    expect(subject.eventReporter.service.user) == user
                }
            }
            context("when configured to start offline") {
                beforeEach {
                    subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                }
                it("leaves the client and service objects offline") {
                    expect(subject.isOnline) == false
                    expect(subject.flagSynchronizer.isOnline) == subject.isOnline
                    expect(subject.eventReporter.isOnline) == subject.isOnline
                }
                it("saves the config") {
                    expect(subject.config) == config
                    expect(subject.service.config) == config
                    expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.streamingMode) == config.streamingMode
                        expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == config.flagPollingInterval(runMode: subject.runMode)
                    }
                    expect(subject.eventReporter.config) == config
                }
                it("saves the user") {
                    expect(subject.user) == user
                    expect(subject.service.user) == user
                    expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service) === subject.service
                    }
                    expect(subject.eventReporter.service.user) == user
                }
            }
            context("when configured to allow background updates and running in background mode") {
                beforeEach {
                    subject = LDClient.makeClient(with: ClientServiceMockFactory(), runMode: .background)
                    config.startOnline = true

                    subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                }
                it("takes the client and service objects online") {
                    expect(subject.isOnline) == true
                    expect(subject.flagSynchronizer.isOnline) == subject.isOnline
                    expect(subject.eventReporter.isOnline) == subject.isOnline
                }
                it("saves the config") {
                    expect(subject.config) == config
                    expect(subject.service.config) == config
                    expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.streamingMode) == LDStreamingMode.polling
                        expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == config.flagPollingInterval(runMode: .background)
                    }
                    expect(subject.eventReporter.config) == config
                }
                it("saves the user") {
                    expect(subject.user) == user
                    expect(subject.service.user) == user
                    expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service) === subject.service
                    }
                    expect(subject.eventReporter.service.user) == user
                }
            }
            context("when configured to not allow background updates and running in background mode") {
                beforeEach {
                    subject = LDClient.makeClient(with: ClientServiceMockFactory(), runMode: .background)
                    config.startOnline = true
                    config.enableBackgroundUpdates = false

                    subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                }
                it("leaves the client and service objects offline") {
                    expect(subject.isOnline) == false
                    expect(subject.flagSynchronizer.isOnline) == subject.isOnline
                    expect(subject.eventReporter.isOnline) == subject.isOnline
                }
                it("saves the config") {
                    expect(subject.config) == config
                    expect(subject.service.config) == config
                    expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.streamingMode) == LDStreamingMode.polling
                        expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == config.flagPollingInterval(runMode: .foreground)
                    }
                    expect(subject.eventReporter.config) == config
                }
                it("saves the user") {
                    expect(subject.user) == user
                    expect(subject.service.user) == user
                    expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service.user) == user
                    }
                    expect(subject.eventReporter.service.user) == user
                }
            }
            context("when called more than once") {
                var newConfig: LDConfig!
                var newUser: LDUser!
                context("while online") {
                    beforeEach {
                        config.startOnline = true
                        subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)

                        newConfig = subject.config
                        newConfig.baseUrl = Constants.alternateMockUrl

                        newUser = LDUser.stub()

                        subject.start(mobileKey: Constants.mockMobileKey, config: newConfig, user: newUser)
                    }
                    it("takes the client and service objects online") {
                        expect(subject.isOnline) == true
                        expect(subject.flagSynchronizer.isOnline) == subject.isOnline
                        expect(subject.eventReporter.isOnline) == subject.isOnline
                    }
                    it("saves the config") {
                        expect(subject.config) == newConfig
                        expect(subject.service.config) == newConfig
                        expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.streamingMode) == newConfig.streamingMode
                            expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == newConfig.flagPollingInterval(runMode: subject.runMode)
                        }
                        expect(subject.eventReporter.config) == newConfig
                    }
                    it("saves the user") {
                        expect(subject.user) == newUser
                        expect(subject.service.user) == newUser
                        expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.service.user) == newUser
                        }
                        expect(subject.eventReporter.service.user) == newUser
                    }
                }
                context("while offline") {
                    beforeEach {
                        config.startOnline = false
                        subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)

                        newConfig = subject.config
                        newConfig.baseUrl = Constants.alternateMockUrl

                        newUser = LDUser.stub()

                        subject.start(mobileKey: Constants.mockMobileKey, config: newConfig, user: newUser)
                    }
                    it("leaves the client and service objects offline") {
                        expect(subject.isOnline) == false
                        expect(subject.flagSynchronizer.isOnline) == subject.isOnline
                        expect(subject.eventReporter.isOnline) == subject.isOnline
                    }
                    it("saves the config") {
                        expect(subject.config) == newConfig
                        expect(subject.service.config) == newConfig
                        expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.streamingMode) == newConfig.streamingMode
                            expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == newConfig.flagPollingInterval(runMode: subject.runMode)
                        }
                        expect(subject.eventReporter.config) == newConfig
                    }
                    it("saves the user") {
                        expect(subject.user) == newUser
                        expect(subject.service.user) == newUser
                        expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.service.user) == newUser
                        }
                        expect(subject.eventReporter.service.user) == newUser
                    }
                }
            }
            context("when called without config or user") {
                context("after setting config and user") {
                    beforeEach {
                        subject.config = config
                        subject.user = user
                        subject.start(mobileKey: Constants.mockMobileKey)
                    }
                    it("saves the config") {
                        expect(subject.config) == config
                        expect(subject.service.config) == config
                        expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.streamingMode) == config.streamingMode
                            expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == config.flagPollingInterval(runMode: subject.runMode)
                        }
                        expect(subject.eventReporter.config) == config
                    }
                    it("saves the user") {
                        expect(subject.user) == user
                        expect(subject.service.user) == user
                        expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.service.user) == user
                        }
                        expect(subject.eventReporter.service.user) == user
                    }
                }
                context("without setting config or user") {
                    beforeEach {
                        subject.start(mobileKey: Constants.mockMobileKey)
                        config = subject.config
                        user = subject.user
                    }
                    it("saves the config") {
                        expect(subject.config) == config
                        expect(subject.service.config) == config
                        expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.streamingMode) == config.streamingMode
                            expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == config.flagPollingInterval(runMode: subject.runMode)
                        }
                        expect(subject.eventReporter.config) == config
                    }
                    it("saves the user") {
                        expect(subject.user) == user
                        expect(subject.service.user) == user
                        expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.service.user) == user
                        }
                        expect(subject.eventReporter.service.user) == user
                    }
                }
            }
            context("when called with cached flags for the user") {
                var serviceFactory: ClientServiceMockFactory!
                var flags: UserFlags!
                var mockUserFlagCache: UserFlagCachingMock!
                var mockFlagStore: LDFlagMaintainingMock!
                beforeEach {
                    serviceFactory = ClientServiceMockFactory()
                    mockUserFlagCache = serviceFactory.userFlagCache
                    flags = UserFlags(user: user)
                    mockUserFlagCache.retrieveFlagsReturnValue = flags
                    subject = LDClient.makeClient(with: serviceFactory)
                    mockFlagStore = user.flagStore as? LDFlagMaintainingMock
                    mockFlagStore.featureFlags = [:]

                    config.startOnline = false
                    subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                }
                it("checks the user flag cache for the user") {
                    expect(mockUserFlagCache.retrieveFlagsCallCount) == 1
                    expect(mockUserFlagCache.retrieveFlagsReceivedUser) == user
                }
                it("restores user flags from cache") {
                    expect(mockFlagStore.replaceStoreReceivedArguments?.newFlags.isNilOrEmpty).toNot(beTrue())
                    expect(mockFlagStore.replaceStoreReceivedArguments?.newFlags == flags.flags).to(beTrue())
                }
            }
            context("when called without cached flags for the user") {
                var serviceFactory: ClientServiceMockFactory!
                var mockUserFlagCache: UserFlagCachingMock!
                var mockFlagStore: LDFlagMaintainingMock!
                beforeEach {
                    serviceFactory = ClientServiceMockFactory()
                    mockUserFlagCache = serviceFactory.userFlagCache
                    subject = LDClient.makeClient(with: serviceFactory)
                    mockFlagStore = user.flagStore as? LDFlagMaintainingMock
                    mockFlagStore.featureFlags = [:]

                    config.startOnline = false
                    subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                }
                it("checks the user flag cache for the user") {
                    expect(mockUserFlagCache.retrieveFlagsCallCount) == 1
                    expect(mockUserFlagCache.retrieveFlagsReceivedUser) == user
                }
                it("does not restore user flags from cache") {
                    expect(mockFlagStore.replaceStoreCallCount) == 0
                }
            }
        }

        describe("set config") {
            var flagSynchronizerMock: LDFlagSynchronizingMock! { return subject.flagSynchronizer as? LDFlagSynchronizingMock }
            var eventReporterMock: LDEventReportingMock! { return subject.eventReporter as? LDEventReportingMock }
            var setIsOnlineCount: (flagSync: Int, event: Int) = (0, 0)
            context("when config values are the same") {
                beforeEach {
                    subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                    setIsOnlineCount = (flagSynchronizerMock.isOnlineSetCount, eventReporterMock.isOnlineSetCount)

                    subject.config = config
                }
                it("retains the config") {
                    expect(subject.config) == config
                }
                it("doesn't try to change service object isOnline state") {
                    expect(flagSynchronizerMock.isOnlineSetCount) == setIsOnlineCount.flagSync
                    expect(eventReporterMock.isOnlineSetCount) == setIsOnlineCount.event
                }
            }
            context("when config values differ") {
                var newConfig: LDConfig!
                beforeEach {
                    config.startOnline = true

                    newConfig = config
                    //change some values and check they're propagated to supporting objects
                    newConfig.baseUrl = Constants.alternateMockUrl
                    newConfig.pollIntervalMillis += 1
                    newConfig.eventFlushIntervalMillis += 1
                }
                context("with run mode set to foreground") {
                    beforeEach {
                        subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)

                        subject.config = newConfig
                    }
                    it("changes to the new config values") {
                        expect(subject.config) == newConfig
                        expect(subject.service.config) == newConfig
                        expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.streamingMode) == newConfig.streamingMode
                            expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == newConfig.flagPollingInterval(runMode: subject.runMode)
                        }
                        expect(subject.eventReporter.config) == newConfig
                    }
                    it("leaves the client online") {
                        expect(subject.isOnline) == true
                        expect(flagSynchronizerMock.isOnline) == subject.isOnline
                        expect(eventReporterMock.isOnline) == subject.isOnline
                    }
                }
                context("with run mode set to background") {
                    beforeEach {
                        subject = LDClient.makeClient(with: ClientServiceMockFactory(), runMode: .background)
                        subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)

                        subject.config = newConfig
                    }
                    it("changes to the new config values") {
                        expect(subject.config) == newConfig
                        expect(subject.service.config) == newConfig
                        expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                        if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                            expect(makeFlagSynchronizerReceivedParameters.streamingMode) == LDStreamingMode.polling
                            expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == newConfig.flagPollingInterval(runMode: subject.runMode)
                        }
                        expect(subject.eventReporter.config) == newConfig
                    }
                    it("leaves the client online") {
                        expect(subject.isOnline) == true
                        expect(flagSynchronizerMock.isOnline) == subject.isOnline
                        expect(eventReporterMock.isOnline) == subject.isOnline
                    }
                }
            }
            context("when the client is offline") {
                var newConfig: LDConfig!
                beforeEach {
                    config.startOnline = false
                    subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)

                    newConfig = config
                    //change some values and check they're propagated to supporting objects
                    newConfig.baseUrl = Constants.alternateMockUrl
                    newConfig.pollIntervalMillis += 1
                    newConfig.eventFlushIntervalMillis += 1

                    subject.config = newConfig
                }
                it("changes to the new config values") {
                    expect(subject.config) == newConfig
                    expect(subject.service.config) == newConfig
                    expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.streamingMode) == newConfig.streamingMode
                        expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == newConfig.flagPollingInterval(runMode: subject.runMode)
                    }
                    expect(subject.eventReporter.config) == newConfig
                }
                it("leaves the client offline") {
                    expect(subject.isOnline) == false
                    expect(flagSynchronizerMock.isOnline) == subject.isOnline
                    expect(eventReporterMock.isOnline) == subject.isOnline
                }
            }
            context("when the client is not started") {
                var newConfig: LDConfig!
                beforeEach {
                    newConfig = subject.config
                    //change some values and check they're propagated to supporting objects
                    newConfig.baseUrl = Constants.alternateMockUrl
                    newConfig.pollIntervalMillis += 1
                    newConfig.eventFlushIntervalMillis += 1

                    subject.config = newConfig
                }
                it("changes to the new config values") {
                    expect(subject.config) == newConfig
                    expect(subject.service.config) == newConfig
                    expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.streamingMode) == newConfig.streamingMode
                        expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == newConfig.flagPollingInterval(runMode: subject.runMode)
                    }
                    expect(subject.eventReporter.config) == newConfig
                }
                it("leaves the client offline") {
                    expect(subject.isOnline) == false
                    expect(flagSynchronizerMock.isOnline) == subject.isOnline
                    expect(eventReporterMock.isOnline) == subject.isOnline
                }
            }
        }

        describe("set user") {
            var newUser: LDUser!
            var mockEventStore: LDEventReportingMock! { return subject.eventReporter as? LDEventReportingMock }
            context("when the client is online") {
                beforeEach {
                    config.startOnline = true
                    subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)

                    newUser = LDUser.stub()
                    subject.user = newUser
                }
                it("changes to the new user") {
                    expect(subject.user) == newUser
                    expect(subject.service.user) == newUser
                    expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service.user) == newUser
                    }
                    expect(subject.eventReporter.service.user) == newUser
                }
                it("leaves the client online") {
                    expect(subject.isOnline) == true
                    expect(subject.eventReporter.isOnline) == true
                    expect(subject.flagSynchronizer.isOnline) == true
                }
                it("records an identify event") {
                    expect(mockEventStore.recordReceivedArguments?.event.kind == .identify).to(beTrue())
                }
            }
            context("when the client is offline") {
                beforeEach {
                    config.startOnline = false
                    subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)

                    newUser = LDUser.stub()
                    subject.user = newUser
                }
                it("changes to the new user") {
                    expect(subject.user) == newUser
                    expect(subject.service.user) == newUser
                    expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service.user) == newUser
                    }
                    expect(subject.eventReporter.service.user) == newUser
                }
                it("leaves the client offline") {
                    expect(subject.isOnline) == false
                    expect(subject.eventReporter.isOnline) == false
                    expect(subject.flagSynchronizer.isOnline) == false
                }
                it("records an identify event") {
                    expect(mockEventStore.recordReceivedArguments?.event.kind == .identify).to(beTrue())
                }
            }
            context("when the client is not started") {
                beforeEach {
                    newUser = LDUser.stub()
                    subject.user = newUser
                }
                it("changes to the new user") {
                    expect(subject.user) == newUser
                    expect(subject.service.user) == newUser
                    expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                    if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                        expect(makeFlagSynchronizerReceivedParameters.service.user) == newUser
                    }
                    expect(subject.eventReporter.service.user) == newUser
                }
                it("leaves the client offline") {
                    expect(subject.isOnline) == false
                    expect(subject.eventReporter.isOnline) == false
                    expect(subject.flagSynchronizer.isOnline) == false
                }
                it("does not record any event") {
                    expect(mockEventStore.recordCallCount) == 0
                }
            }
        }

        describe("change isOnline") {
            context("when the client is offline") {
                context("setting online") {
                    beforeEach {
                        subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)

                        subject.isOnline = true
                    }
                    it("sets the client and service objects online") {
                        expect(subject.isOnline) == true
                        expect(subject.flagSynchronizer.isOnline) == subject.isOnline
                        expect(subject.eventReporter.isOnline) == subject.isOnline
                    }
                }
            }
            context("when the client is online") {
                context("setting offline") {
                    beforeEach {
                        config.startOnline = true
                        subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)

                        subject.isOnline = false
                    }
                    it("takes the client and service objects offline") {
                        expect(subject.isOnline) == false
                        expect(subject.flagSynchronizer.isOnline) == subject.isOnline
                        expect(subject.eventReporter.isOnline) == subject.isOnline
                    }
                }
            }
            context("when the client has not been started") {
                beforeEach {
                    subject.isOnline = true
                }
                it("leaves the client and service objects offline") {
                    expect(subject.isOnline) == false
                    expect(subject.flagSynchronizer.isOnline) == subject.isOnline
                    expect(subject.eventReporter.isOnline) == subject.isOnline
                }
            }
            context("when the client runs in the background") {
                beforeEach {
                    subject = LDClient.makeClient(with: ClientServiceMockFactory(), runMode: .background)
                }
                context("while configured to enable background updates") {
                    beforeEach {
                        subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                    }
                    context("and setting online") {
                        beforeEach {
                            subject.isOnline = true
                        }
                        it("takes the client and service objects online") {
                            expect(subject.isOnline) == true
                            expect(subject.flagSynchronizer.isOnline) == subject.isOnline
                            expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                            if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                                expect(makeFlagSynchronizerReceivedParameters.streamingMode) == LDStreamingMode.polling
                                expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == config.flagPollingInterval(runMode: subject.runMode)
                            }
                            expect(subject.eventReporter.isOnline) == subject.isOnline
                        }
                    }
                }
                context("while configured to disable background updates") {
                    beforeEach {
                        config.enableBackgroundUpdates = false
                        subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                    }
                    context("and setting online") {
                        beforeEach {
                            subject.isOnline = true
                        }
                        it("leaves the client and service objects offline") {
                            expect(subject.isOnline) == false
                            expect(subject.flagSynchronizer.isOnline) == subject.isOnline
                            expect(mockFactory.makeFlagSynchronizerReceivedParameters).toNot(beNil())
                            if let makeFlagSynchronizerReceivedParameters = mockFactory.makeFlagSynchronizerReceivedParameters {
                                expect(makeFlagSynchronizerReceivedParameters.streamingMode) == LDStreamingMode.polling
                                expect(makeFlagSynchronizerReceivedParameters.pollingInterval) == config.flagPollingInterval(runMode: .foreground)
                            }

                            expect(subject.eventReporter.isOnline) == subject.isOnline
                        }
                    }
                }
            }
        }

        describe("stop") {
            var mockEventReporter: LDEventReportingMock! { return subject.eventReporter as? LDEventReportingMock }
            var event: LDEvent!
            var priorRecordedEvents: Int!
            beforeEach {
                event = LDEvent.stub(for: .custom, with: user)
            }
            context("when started") {
                beforeEach {
                    priorRecordedEvents = 0
                }
                context("and online") {
                    beforeEach {
                        config.startOnline = true
                        subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                        priorRecordedEvents = mockEventReporter.recordCallCount

                        subject.stop()
                    }
                    it("takes the client offline") {
                        expect(subject.isOnline) == false
                    }
                    it("stops recording events") {
                        subject.trackEvent(key: event.key)
                        expect(mockEventReporter.recordCallCount) == priorRecordedEvents
                    }
                }
                context("and offline") {
                    beforeEach {
                        config.startOnline = false
                        subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                        priorRecordedEvents = mockEventReporter.recordCallCount

                        subject.stop()
                    }
                    it("leaves the client offline") {
                        expect(subject.isOnline) == false
                    }
                    it("stops recording events") {
                        subject.trackEvent(key: event.key)
                        expect(mockEventReporter.recordCallCount) == priorRecordedEvents
                    }
                }
            }
            context("when not yet started") {
                beforeEach {
                    subject.stop()
                }
                it("leaves the client offline") {
                    expect(subject.isOnline) == false
                }
                it("does not record events") {
                    subject.trackEvent(key: event.key)
                    expect(mockEventReporter.recordCallCount) == 0
                }
            }
            context("when already stopped") {
                beforeEach {
                    config.startOnline = false
                    subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                    subject.stop()
                    priorRecordedEvents = mockEventReporter.recordCallCount

                    subject.stop()
                }
                it("leaves the client offline") {
                    expect(subject.isOnline) == false
                }
                it("stops recording events") {
                    subject.trackEvent(key: event.key)
                    expect(mockEventReporter.recordCallCount) == priorRecordedEvents
                }
            }
        }

        describe("track event") {
            var mockEventReporter: LDEventReportingMock! { return  subject.eventReporter as? LDEventReportingMock }
            var event: LDEvent!
            beforeEach {
                event = LDEvent.stub(for: .custom, with: user)
            }
            context("when client was started") {
                beforeEach {
                    subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)

                    subject.trackEvent(key: event.key, data: event.data)
                }
                it("records a custom event") {
                    expect(mockEventReporter.recordReceivedArguments?.event.key) == event.key
                    expect(mockEventReporter.recordReceivedArguments?.event.user) == event.user
                    expect(mockEventReporter.recordReceivedArguments?.event.data).toNot(beNil())
                    expect(mockEventReporter.recordReceivedArguments?.event.data == event.data).to(beTrue())
                }
            }
            context("when client was not started") {
                beforeEach {
                    subject.trackEvent(key: event.key, data: event.data)
                }
                it("does not record any events") {
                    expect(mockEventReporter.recordCallCount) == 0
                }
            }
            context("when client was stopped") {
                var priorRecordedEvents: Int!
                beforeEach {
                    subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                    subject.stop()
                    priorRecordedEvents = mockEventReporter.recordCallCount

                    subject.trackEvent(key: event.key, data: event.data)
                }
                it("does not record any more events") {
                    expect(mockEventReporter.recordCallCount) == priorRecordedEvents
                }
            }
        }

        //TODO: When implementing background mode, verify switching background modes affects the service objects

        //TODO: When the notification engine is installed, verify that an update to feature flags results in a notification of flags changed
    }
}
