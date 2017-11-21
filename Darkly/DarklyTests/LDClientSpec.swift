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
                    expect(subject.flagSynchronizer.streamingMode) == config.streamingMode
                    expect(subject.flagSynchronizer.pollingInterval) == config.flagPollingInterval(runMode: subject.runMode)
                    expect(subject.eventReporter.config) == config
                }
                it("saves the user") {
                    expect(subject.user) == user
                    expect(subject.service.user) == user
                    expect(subject.flagSynchronizer.service) === subject.service
                    expect(subject.eventReporter.service) === subject.service
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
                    expect(subject.flagSynchronizer.streamingMode) == config.streamingMode
                    expect(subject.flagSynchronizer.pollingInterval) == config.flagPollingInterval(runMode: subject.runMode)
                    expect(subject.eventReporter.config) == config
                }
                it("saves the user") {
                    expect(subject.user) == user
                    expect(subject.service.user) == user
                    expect(subject.flagSynchronizer.service) === subject.service
                    expect(subject.eventReporter.service) === subject.service
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
                    expect(subject.flagSynchronizer.streamingMode) == LDStreamingMode.polling
                    expect(subject.flagSynchronizer.pollingInterval) == config.flagPollingInterval(runMode: .background)
                    expect(subject.eventReporter.config) == config
                }
                it("saves the user") {
                    expect(subject.user) == user
                    expect(subject.service.user) == user
                    expect(subject.flagSynchronizer.service) === subject.service
                    expect(subject.eventReporter.service) === subject.service
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
                    expect(subject.flagSynchronizer.streamingMode) == LDStreamingMode.polling
                    expect(subject.flagSynchronizer.pollingInterval) == config.flagPollingInterval(runMode: .foreground)
                    expect(subject.eventReporter.config) == config
                }
                it("saves the user") {
                    expect(subject.user) == user
                    expect(subject.service.user) == user
                    expect(subject.flagSynchronizer.service) === subject.service
                    expect(subject.eventReporter.service) === subject.service
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
                        expect(subject.eventReporter.config) == newConfig
                    }
                    it("saves the user") {
                        expect(subject.user) == newUser
                        expect(subject.service.user) == newUser
                        expect(subject.flagSynchronizer.service) === subject.service
                        expect(subject.eventReporter.service) === subject.service
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
                        expect(subject.eventReporter.config) == newConfig
                    }
                    it("saves the user") {
                        expect(subject.user) == newUser
                        expect(subject.service.user) == newUser
                        expect(subject.flagSynchronizer.service) === subject.service
                        expect(subject.eventReporter.service) === subject.service
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
                        expect(subject.eventReporter.config) == config
                    }
                    it("saves the user") {
                        expect(subject.user) == user
                        expect(subject.service.user) == user
                        expect(subject.flagSynchronizer.service) === subject.service
                        expect(subject.eventReporter.service) === subject.service
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
                        expect(subject.eventReporter.config) == config
                    }
                    it("saves the user") {
                        expect(subject.user) == user
                        expect(subject.service.user) == user
                        expect(subject.flagSynchronizer.service) === subject.service
                        expect(subject.eventReporter.service) === subject.service
                    }
                }
            }
            context("when called with cached flags for the user") {
                var flags: [String: Any]!
                var mockFlagStore: LDFlagMaintainingMock!
                beforeEach {
                    user = LDFlagCache().stubAndStoreUserFlags(count: 1).first
                    flags = user.flagStore.featureFlags
                    mockFlagStore = user.flagStore as? LDFlagMaintainingMock
                    mockFlagStore?.replaceStore(newFlags: [:], source: .cache)

                    config.startOnline = false
                    subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                }
                it("restores user flags from cache") {
                    expect(mockFlagStore.replaceStoreReceivedArguments?.newFlags == flags).to(beTrue())
                }
            }
        }

        describe("set config") {
            var flagSynchronizerMock: LDFlagSynchronizingMock!
            var eventReporterMock: LDEventReportingMock!
            var setIsOnlineCount: (flagSync: Int, event: Int) = (0, 0)
            beforeEach {
                flagSynchronizerMock = subject.flagSynchronizer as? LDFlagSynchronizingMock
                eventReporterMock = subject.eventReporter as? LDEventReportingMock
            }
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
                beforeEach {
                    config.startOnline = true
                }
                var newConfig: LDConfig!
                context("with run mode set to foreground") {
                    beforeEach {
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
                        expect(subject.flagSynchronizer.streamingMode) == newConfig.streamingMode
                        expect(subject.flagSynchronizer.pollingInterval) == newConfig.flagPollingInterval(runMode: subject.runMode)
                        expect(subject.eventReporter.config) == newConfig
                    }
                    it("leaves the client online") {
                        expect(subject.isOnline) == true
                    }
                }
                context("with run mode set to background") {
                    beforeEach {
                        subject = LDClient.makeClient(with: ClientServiceMockFactory(), runMode: .background)
                        subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                        newConfig = config
                        //change some values and check they're propagated to supporting objects
                        newConfig.baseUrl = Constants.alternateMockUrl
                        newConfig.backgroundPollIntervalMillis += 1
                        newConfig.eventFlushIntervalMillis += 1

                        subject.config = newConfig
                    }
                    it("changes to the new config values") {
                        expect(subject.config) == newConfig
                        expect(subject.service.config) == newConfig
                        expect(subject.flagSynchronizer.streamingMode) == LDStreamingMode.polling
                        expect(subject.flagSynchronizer.pollingInterval) == newConfig.flagPollingInterval(runMode: subject.runMode)
                        expect(subject.eventReporter.config) == newConfig
                    }
                    it("leaves the client online") {
                        expect(subject.isOnline) == true
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
                    expect(subject.flagSynchronizer.streamingMode) == newConfig.streamingMode
                    expect(subject.flagSynchronizer.pollingInterval) == newConfig.flagPollingInterval(runMode: subject.runMode)
                    expect(subject.eventReporter.config) == newConfig
                }
                it("leaves the client offline") {
                    expect(subject.isOnline) == false
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
                    expect(subject.flagSynchronizer.streamingMode) == newConfig.streamingMode
                    expect(subject.flagSynchronizer.pollingInterval) == newConfig.flagPollingInterval(runMode: subject.runMode)
                    expect(subject.eventReporter.config) == newConfig
                }
                it("leaves the client offline") {
                    expect(subject.isOnline) == false
                }
            }
        }

        describe("set user") {
            var newUser: LDUser!
            var mockEventStore: LDEventReportingMock!
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
                    expect(subject.flagSynchronizer.service) === subject.service
                    expect(subject.eventReporter.service) === subject.service
                }
                it("leaves the client online") {
                    expect(subject.isOnline) == true
                    expect(subject.eventReporter.isOnline) == true
                    expect(subject.flagSynchronizer.isOnline) == true
                }
                it("records an identify event") {
                    mockEventStore = subject.eventReporter as? LDEventReportingMock
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
                    expect(subject.flagSynchronizer.service) === subject.service
                    expect(subject.eventReporter.service) === subject.service
                }
                it("leaves the client offline") {
                    expect(subject.isOnline) == false
                    expect(subject.eventReporter.isOnline) == false
                    expect(subject.flagSynchronizer.isOnline) == false
                }
                it("records an identify event") {
                    mockEventStore = subject.eventReporter as? LDEventReportingMock
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
                    expect(subject.flagSynchronizer.service) === subject.service
                    expect(subject.eventReporter.service) === subject.service
                }
                it("leaves the client offline") {
                    expect(subject.isOnline) == false
                    expect(subject.eventReporter.isOnline) == false
                    expect(subject.flagSynchronizer.isOnline) == false
                }
                it("does not record any event") {
                    mockEventStore = subject.eventReporter as? LDEventReportingMock
                    expect(mockEventStore.recordCallCount) == 0
                }
            }
        }

        describe("change isOnline") {
            context("when the client is offline") {
                context("setting online") {
                    beforeEach {
                        subject.start(mobileKey: Constants.mockMobileKey, config: config, user: user)
                        subject.isOnline = false

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
                            expect(subject.flagSynchronizer.streamingMode) == LDStreamingMode.polling
                            expect(subject.flagSynchronizer.pollingInterval) == config.flagPollingInterval(runMode: subject.runMode)
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
                            expect(subject.flagSynchronizer.streamingMode) == LDStreamingMode.polling
                            expect(subject.flagSynchronizer.pollingInterval) == config.flagPollingInterval(runMode: .foreground)
                            expect(subject.eventReporter.isOnline) == subject.isOnline
                        }
                    }
                }
            }
        }

        describe("stop") {
            var mockEventReporter: LDEventReportingMock!
            var event: LDEvent!
            var priorRecordedEvents: Int!
            beforeEach {
                mockEventReporter = subject.eventReporter as? LDEventReportingMock
            }
            context("when started") {
                beforeEach {
                    event = LDEvent.stub(for: .custom, with: user)
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
            var mockEventReporter: LDEventReportingMock!
            var event: LDEvent!
            beforeEach {
                event = LDEvent.stub(for: .custom, with: user)
                mockEventReporter = subject.eventReporter as? LDEventReportingMock
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
    }
}
