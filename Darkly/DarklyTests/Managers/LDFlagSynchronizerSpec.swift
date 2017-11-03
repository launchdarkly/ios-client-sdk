//
//  LDFlagSynchronizerSpec.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 9/20/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
import OHHTTPStubs
import DarklyEventSource
@testable import Darkly

//swiftlint:disable function_body_length
final class LDFlagSynchronizerSpec: QuickSpec {
    var subject: LDFlagSynchronizer!
    let mockMobileKey = "mockMobileKey"
    var config: LDConfig!
    var mockUser: LDUser!
    var mockService: DarklyServiceMock!
    var mockStore: LDFlagMaintainingMock!
    override func spec() {
        beforeEach {
            self.config = LDConfig.stub
            self.mockUser = LDUser()
            self.mockService = DarklyServiceMock()
            self.mockStore = LDFlagMaintainingMock()
        }
        describe("init") {
            context("configured offline-streaming") {
                beforeEach {
                    self.createSynchronizer(online: false, streamingMode: .streaming)

                }
                it("starts up offline") {
                    expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: false) }).to(match())
                }
            }
            context("configured offline-polling") {
                beforeEach {
                    self.createSynchronizer(online: false, streamingMode: .polling)
                }
                it("starts up offline") {
                    expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .polling, flagRequests: 0, streamCreated: false) }).to(match())
                }
            }
            context("configured online-streaming") {
                beforeEach {
                    self.createSynchronizer(online: true, streamingMode: .streaming)
                }
                it("starts up online streaming") {
                    expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                }
            }
            context("configured online-polling") {
                beforeEach {
                    self.createSynchronizer(online: true, streamingMode: .polling)
                }
                it("starts up online polling") {
                    expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .polling, flagRequests: 1, streamCreated: false) }).to(match())
                }
            }
        }
        
        describe("change isOnline") {
            context("online to offline") {
                context("streaming") {
                    beforeEach {
                        self.createSynchronizer(online: true, streamingMode: .streaming)
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())

                        self.subject.isOnline = false
                    }
                    it("stops streaming") {
                        expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: true) }).to(match())
                    }
                }
                context("polling") {
                    beforeEach {
                        self.createSynchronizer(online: true, streamingMode: .polling)
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .polling, flagRequests: 1, streamCreated: false) }).to(match())

                        self.subject.isOnline = false
                    }
                    it("stops polling") {
                        expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .polling, flagRequests: 1, streamCreated: false) }).to(match())
                    }
                }
            }
            context("offline to online") {
                context("streaming") {
                    beforeEach {
                        self.createSynchronizer(online: false, streamingMode: .streaming)
                        expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: false) }).to(match())

                        self.subject.isOnline = true
                    }
                    it("starts streaming") {
                        //streaming expects a ping on successful connection that triggers a flag request
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                    }
                }
                context("polling") {
                    beforeEach {
                        self.createSynchronizer(online: false, streamingMode: .polling)
                        expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .polling, flagRequests: 0, streamCreated: false) }).to(match())

                        self.subject.isOnline = true
                    }
                    it("starts polling") {
                        //polling starts by requesting flags
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .polling, flagRequests: 1, streamCreated: false) }).to(match())
                    }
                }
            }
            context("online to online") {
                context("streaming") {
                    beforeEach {
                        self.createSynchronizer(online: true, streamingMode: .streaming)
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())

                        self.subject.isOnline = true
                    }
                    it("does not stop streaming") {
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                    }
                }
                context("polling") {
                    beforeEach {
                        self.createSynchronizer(online: true, streamingMode: .polling)
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .polling, flagRequests: 1, streamCreated: false) }).to(match())

                        self.subject.isOnline = true
                    }
                    it("does not stop polling") {
                        // setting the same value shouldn't make another flag request
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .polling, flagRequests: 1, streamCreated: false) }).to(match())
                    }
                }
            }
            context("offline to offline") {
                context("streaming") {
                    beforeEach {
                        self.createSynchronizer(online: false, streamingMode: .streaming)
                        expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: false) }).to(match())

                        self.subject.isOnline = false
                    }
                    it("does not start streaming") {
                        expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: false) }).to(match())
                    }
                }
                context("polling") {
                    beforeEach {
                        self.createSynchronizer(online: false, streamingMode: .polling)
                        expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .polling, flagRequests: 0, streamCreated: false) }).to(match())

                        self.subject.isOnline = false
                    }
                    it("does not start polling") {
                        expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .polling, flagRequests: 0, streamCreated: false) }).to(match())
                    }
                }
            }
        }
        
        describe("change streaming mode") {
            context("streaming to polling") {
                context("online") {
                    beforeEach {
                        self.createSynchronizer(online: true, streamingMode: .streaming)
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())

                        self.subject.streamingMode = .polling
                    }
                    it("stops streaming & starts polling") {
                        //polling starts by requesting flags
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .polling, flagRequests: 1, streamCreated: true, streamClosed: true) }).to(match())
                    }
                }
                context("offline") {
                    beforeEach {
                        self.createSynchronizer(online: false, streamingMode: .streaming)
                        expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: false) }).to(match())

                        self.subject.streamingMode = .polling
                    }
                    it("remains offline & changes to polling mode") {
                        expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .polling, flagRequests: 0, streamCreated: false) }).to(match())
                    }
                }
            }
            context("polling to streaming") {
                context("online") {
                    beforeEach {
                        self.createSynchronizer(online: true, streamingMode: .polling)
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .polling, flagRequests: 1, streamCreated: false) }).to(match())

                        self.subject.streamingMode = .streaming
                    }
                    it("stops polling & starts streaming") {
                        //polling starts by requesting flags, streaming expects a ping so no additional flag request
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
                    }
                }
                context("offline") {
                    beforeEach {
                        self.createSynchronizer(online: false, streamingMode: .polling)
                        expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .polling, flagRequests: 0, streamCreated: false) }).to(match())

                        self.subject.streamingMode = .streaming
                    }
                    it("remains offline & changes to streaming mode") {
                        expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: false) }).to(match())
                    }
                }
            }
        }

        describe("streaming events") {
            context("ping") {
                context("success") {
                    beforeEach {
                        self.mockService.stubFlagResponse(success: true)
                        self.createSynchronizer(online: true, streamingMode: .streaming)
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())

                        self.mockService.createdEventSource?.sendPing()
                    }
                    it("requests flags & updates flag store") {
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
                        expect(self.mockStore.replaceStoreCallCount) == 1
                        expect(self.mockStore.replaceStoreReceivedArguments?.newFlags).toNot(beNil())
                    }
                }
                context("bad data") {
                    beforeEach {
                        self.mockService.stubFlagResponse(success: true, badData: true)
                        self.createSynchronizer(online: true, streamingMode: .streaming)
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())

                        self.mockService.createdEventSource?.sendPing()
                    }
                    it("requests flags & does not update flag store") {
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
                        expect(self.mockStore.replaceStoreCallCount) == 0
                        expect(self.mockStore.replaceStoreReceivedArguments?.newFlags).to(beNil())
                    }
                }
                context("failure response") {
                    beforeEach {
                        self.mockService.stubFlagResponse(success: false, responseOnly: true)
                        self.createSynchronizer(online: true, streamingMode: .streaming)
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())

                        self.mockService.createdEventSource?.sendPing()
                    }
                    it("requests flags & does not update flag store") {
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
                        expect(self.mockStore.replaceStoreCallCount) == 0
                        expect(self.mockStore.replaceStoreReceivedArguments?.newFlags).to(beNil())
                    }
                }
                context("failure error") {
                    beforeEach {
                        self.mockService.stubFlagResponse(success: false, errorOnly: true)
                        self.createSynchronizer(online: true, streamingMode: .streaming)
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())

                        self.mockService.createdEventSource?.sendPing()
                    }
                    it("requests flags & does not update flag store") {
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
                        expect(self.mockStore.replaceStoreCallCount) == 0
                        expect(self.mockStore.replaceStoreReceivedArguments?.newFlags).to(beNil())
                    }
                }
            }
            context("heartbeat") {
                beforeEach {
                    self.mockService.stubFlagRequest(success: true)
                    self.createSynchronizer(online: true, streamingMode: .streaming)
                    expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())

                    self.mockService.createdEventSource?.sendHeartbeat()
                }
                it("does not request flags") {
                    expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                }
            }
            context("null event") {
                beforeEach {
                    self.mockService.stubFlagRequest(success: true)
                    self.createSynchronizer(online: true, streamingMode: .streaming)
                    expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())

                    self.mockService.createdEventSource?.sendNullEvent()
                }
                it("does not request flags") {
                    expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                }
            }
        }

        describe("polling timer fires") {
            beforeEach {
                self.createSynchronizer(online: true, streamingMode: .polling)
                expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .polling, flagRequests: 1, streamCreated: false) }).to(match())
            }
            it("makes a flag request") {
                expect(self.mockService.getFeatureFlagsCallCount).toEventually(equal(2), timeout: 2)
            }
        }

        afterEach {
            OHHTTPStubs.removeAllStubs()
        }
    }
    
    private func isStreamingActive(online: Bool, streamingMode: LDStreamingMode) -> Bool { return online && (streamingMode == .streaming) }
    private func isPollingActive(online: Bool, streamingMode: LDStreamingMode) -> Bool { return online && (streamingMode == .polling) }

    private func createSynchronizer(online: Bool, streamingMode: LDStreamingMode) {
        self.config.launchOnline = online
        self.config.streamingMode = streamingMode
        self.subject = LDFlagSynchronizer(mobileKey: self.mockMobileKey, config: self.config, user: self.mockUser, service: self.mockService, store: self.mockStore)
    }
    
    private func synchronizerState(synchronizerOnline isOnline: Bool, streamingMode: LDStreamingMode, flagRequests: Int, streamCreated: Bool, streamClosed: Bool? = nil) -> ToMatchResult {
        var messages = [String]()

        //synchronizer state
        if self.subject.isOnline != isOnline { messages.append("isOnline equals \(self.subject.isOnline)") }
        if self.subject.streamingMode != streamingMode { messages.append("streamingMode equals \(self.subject.streamingMode)") }
        if self.subject.streamingActive != isStreamingActive(online: isOnline, streamingMode: streamingMode) { messages.append("streamingActive equals \(self.subject.streamingActive)") }
        if self.subject.pollingActive != isPollingActive(online: isOnline, streamingMode: streamingMode) { messages.append("pollingActive equals \(self.subject.pollingActive)") }

        //flag requests
        if self.mockService.getFeatureFlagsCallCount != flagRequests { messages.append("flag requests equals \(self.mockService.getFeatureFlagsCallCount)") }

        messages.append(contentsOf: eventSourceStateVerificationMessages(streamCreated: streamCreated, streamClosed: streamClosed))

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    private func eventSourceStateVerificationMessages(streamCreated: Bool, streamClosed: Bool? = nil) -> [String] {
        var messages = [String]()
        //event source
        switch streamCreated {
        case true:
            if let eventSource = self.mockService.createdEventSource {
                if let streamClosed = streamClosed {
                    if eventSource.closeCallCount != (streamClosed ? 1 : 0) { messages.append("stream closed call count equals \(eventSource.closeCallCount)") }
                }
            } else {
                messages.append("event stream not created")
            }
        case false:
            if self.mockService.createdEventSource != nil { messages.append("mock service created event source is not nil") }
            if streamClosed != nil { messages.append("stream closed is not nil (this is an incorrect test)") }
        }
        return messages
    }
}
