//
//  LDConfigSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 11/10/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
@testable import Darkly

final class LDConfigSpec: QuickSpec {
    struct Constants {
        fileprivate static let alternateMockUrl = URL(string: "https://dummy.alternate.com")!
    }

    override func spec() {
        var subject: LDConfig!

        describe("flagPollingInterval") {
            var effectivePollingInterval: TimeInterval!
            beforeEach {
                subject = LDConfig()
            }

            context("when running in foreground mode") {
                context("polling interval above the minimum") {
                    beforeEach {
                        subject.pollIntervalMillis = subject.minima.pollingIntervalMillis + 1

                        effectivePollingInterval = subject.flagPollingInterval(runMode: .foreground)
                    }
                    it("returns pollIntervalMillis") {
                        expect(effectivePollingInterval) == subject.flagPollInterval
                    }
                }
                context("polling interval at the minimum") {
                    beforeEach {
                        subject.pollIntervalMillis = subject.minima.pollingIntervalMillis

                        effectivePollingInterval = subject.flagPollingInterval(runMode: .foreground)
                    }
                    it("returns pollIntervalMillis") {
                        expect(effectivePollingInterval) == subject.flagPollInterval
                    }
                }
                context("polling interval below the minimum") {
                    beforeEach {
                        subject.pollIntervalMillis = subject.minima.pollingIntervalMillis - 1

                        effectivePollingInterval = subject.flagPollingInterval(runMode: .foreground)
                    }
                    it("returns Minima.pollIntervalMillis") {
                        expect(effectivePollingInterval) == subject.minima.pollingIntervalMillis.timeInterval
                    }
                }
            }
            context("when running in background mode") {
                context("polling interval above the minimum") {
                    beforeEach {
                        subject.backgroundPollIntervalMillis = subject.minima.backgroundPollIntervalMillis + 1
                        
                        effectivePollingInterval = subject.flagPollingInterval(runMode: .background)
                    }
                    it("returns backgroundPollIntervalMillis") {
                        expect(effectivePollingInterval) == subject.backgroundFlagPollInterval
                    }
                }
                context("polling interval at the minimum") {
                    beforeEach {
                        subject.backgroundPollIntervalMillis = subject.minima.backgroundPollIntervalMillis
                        
                        effectivePollingInterval = subject.flagPollingInterval(runMode: .background)
                    }
                    it("returns backgroundPollIntervalMillis") {
                        expect(effectivePollingInterval) == subject.backgroundFlagPollInterval
                    }
                }
                context("polling interval below the minimum") {
                    beforeEach {
                        subject.backgroundPollIntervalMillis = subject.minima.backgroundPollIntervalMillis - 1
                        
                        effectivePollingInterval = subject.flagPollingInterval(runMode: .background)
                    }
                    it("returns Minima.backgroundPollIntervalMillis") {
                        expect(effectivePollingInterval) == subject.minima.backgroundPollIntervalMillis.timeInterval
                    }
                }
            }
        }

        describe("==") {
            var otherConfig: LDConfig!
            beforeEach {
                subject = LDConfig.stub
            }
            context("when settable values are all the same") {
                beforeEach {
                    otherConfig = subject
                }
                it("returns true") {
                    expect(subject) == otherConfig
                }
            }
            context("when the base URLs differ") {
                beforeEach {
                    otherConfig = subject
                    otherConfig.baseUrl = Constants.alternateMockUrl
                }
                it("returns false") {
                    expect(subject) != otherConfig
                }
            }
            context("when the event URLs differ") {
                beforeEach {
                    otherConfig = subject
                    otherConfig.eventsUrl = Constants.alternateMockUrl
                }
                it("returns false") {
                    expect(subject) != otherConfig
                }
            }
            context("when the stream URLs differ") {
                beforeEach {
                    otherConfig = subject
                    otherConfig.streamUrl = Constants.alternateMockUrl
                }
                it("returns false") {
                    expect(subject) != otherConfig
                }
            }
            context("when the connection timeouts differ") {
                beforeEach {
                    otherConfig = subject
                    otherConfig.connectionTimeoutMillis = subject.connectionTimeoutMillis + 1
                }
                it("returns false") {
                    expect(subject) != otherConfig
                }
            }
            context("when the event flush intervals differ") {
                beforeEach {
                    otherConfig = subject
                    otherConfig.eventFlushIntervalMillis = subject.eventFlushIntervalMillis + 1
                }
                it("returns false") {
                    expect(subject) != otherConfig
                }
            }
            context("when the poll intervals differ") {
                beforeEach {
                    otherConfig = subject
                    otherConfig.pollIntervalMillis = subject.pollIntervalMillis + 1
                }
                it("returns false") {
                    expect(subject) != otherConfig
                }
            }
            context("when the background poll intervals differ") {
                beforeEach {
                    otherConfig = subject
                    otherConfig.backgroundPollIntervalMillis = subject.backgroundPollIntervalMillis + 1
                }
                it("returns false") {
                    expect(subject) != otherConfig
                }
            }
            context("when the streaming modes differ") {
                beforeEach {
                    otherConfig = subject
                    otherConfig.streamingMode = subject.streamingMode == .streaming ? .polling : .streaming
                }
                it("returns false") {
                    expect(subject) != otherConfig
                }
            }
            context("when enable background updates differ") {
                beforeEach {
                    otherConfig = subject
                    otherConfig.enableBackgroundUpdates = !subject.enableBackgroundUpdates
                }
                it("returns false") {
                    expect(subject) != otherConfig
                }
            }
            context("when start online differs") {
                beforeEach {
                    otherConfig = subject
                    otherConfig.startOnline = !subject.startOnline
                }
                it("returns false") {
                    expect(subject) != otherConfig
                }
            }
            context("when debug modes differ") {
                beforeEach {
                    otherConfig = subject
                    otherConfig.isDebugMode = !subject.isDebugMode
                }
                it("returns false") {
                    expect(subject) != otherConfig
                }
            }
        }
    }
}
