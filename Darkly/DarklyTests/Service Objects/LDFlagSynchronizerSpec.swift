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

final class LDFlagSynchronizerSpec: QuickSpec {
    struct Constants {
        fileprivate static let mockMobileKey = "mockMobileKey"
        fileprivate static let pollingInterval: TimeInterval = 1
        fileprivate static let waitMillis: Int = 500
    }

    var subject: LDFlagSynchronizer!
    var mockService: DarklyServiceMock!

    override func spec() {
        var config: LDConfig!
        var mockUser: LDUser!
        var mockStore: LDFlagMaintainingMock! { return mockUser.flagStore as? LDFlagMaintainingMock }

        beforeEach {
            config = LDConfig.stub
            mockUser = LDUser.stub()
            self.mockService = DarklyServiceMock()
            self.subject = LDFlagSynchronizer(streamingMode: .streaming, pollingInterval: Constants.pollingInterval, service: self.mockService, onSyncComplete: nil)
        }
        describe("init") {
            it("starts up streaming offline") {
                expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: false) }).to(match())
                expect(self.subject.pollingInterval) == Constants.pollingInterval
            }
        }
        
        describe("change isOnline") {
            context("online to offline") {
                context("streaming") {
                    beforeEach {
                        self.subject.isOnline = true

                        self.subject.isOnline = false
                    }
                    it("stops streaming") {
                        expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: true) }).to(match())
                    }
                }
                context("polling") {
                    beforeEach {
                        self.subject = LDFlagSynchronizer(streamingMode: .polling, pollingInterval: Constants.pollingInterval, service: self.mockService, onSyncComplete: nil)
                        self.subject.isOnline = true

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
                        self.subject.isOnline = true
                    }
                    it("starts streaming") {
                        //streaming expects a ping on successful connection that triggers a flag request. No ping means no flag requests
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                    }
                }
                context("polling") {
                    beforeEach {
                        self.subject = LDFlagSynchronizer(streamingMode: .polling, pollingInterval: Constants.pollingInterval, service: self.mockService, onSyncComplete: nil)

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
                        self.subject.isOnline = true

                        self.subject.isOnline = true
                    }
                    it("does not stop streaming") {
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                    }
                }
                context("polling") {
                    beforeEach {
                        self.subject = LDFlagSynchronizer(streamingMode: .polling, pollingInterval: Constants.pollingInterval, service: self.mockService, onSyncComplete: nil)
                        self.subject.isOnline = true

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
                        self.subject.isOnline = false
                    }
                    it("does not start streaming") {
                        expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: false) }).to(match())
                    }
                }
                context("polling") {
                    beforeEach {
                        self.subject = LDFlagSynchronizer(streamingMode: .polling, pollingInterval: Constants.pollingInterval, service: self.mockService, onSyncComplete: nil)

                        self.subject.isOnline = false
                    }
                    it("does not start polling") {
                        expect({ self.synchronizerState(synchronizerOnline: false, streamingMode: .polling, flagRequests: 0, streamCreated: false) }).to(match())
                    }
                }
            }
        }
        
        describe("streaming events") {
            context("ping") {
                context("success") {
                    var newFlags: [String: Any]?
                    beforeEach {
                        self.mockService.stubFlagResponse(success: true)
                        waitUntil { done in
                            self.subject = LDFlagSynchronizer(streamingMode: .streaming, pollingInterval: Constants.pollingInterval, service: self.mockService) { result in
                                if case let .success(flags) = result { newFlags = flags }
                                done()
                            }
                            self.subject.isOnline = true

                            self.mockService.createdEventSource?.sendPing()
                        }
                    }
                    it("requests flags & calls the onSync closure with the new flags") {
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
                        expect(newFlags == DarklyServiceMock.Constants.featureFlags).to(beTrue())
                    }
                }
                context("bad data") {
                    var synchronizingError: SynchronizingError?
                    beforeEach {
                        self.mockService.stubFlagResponse(success: true, badData: true)
                        waitUntil { done in
                            self.subject = LDFlagSynchronizer(streamingMode: .streaming, pollingInterval: Constants.pollingInterval, service: self.mockService) { (result) in
                                if case let .error(syncError) = result { synchronizingError = syncError }
                                done()
                            }
                            self.subject.isOnline = true

                            self.mockService.createdEventSource?.sendPing()
                        }
                    }
                    it("requests flags, does not update flag store, and calls the onError closure with a data error") {
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
                        expect(synchronizingError == .data(DarklyServiceMock.Constants.errorData)).to(beTrue())
                        expect(mockStore.replaceStoreCallCount) == 0
                        expect(mockStore.replaceStoreReceivedArguments?.newFlags).to(beNil())
                    }
                }
                context("failure response") {
                    var synchronizingError: SynchronizingError?
                    beforeEach {
                        self.mockService.stubFlagResponse(success: false, responseOnly: true)
                        waitUntil { done in
                            self.subject = LDFlagSynchronizer(streamingMode: .streaming, pollingInterval: Constants.pollingInterval, service: self.mockService) { (result) in
                                if case let .error(syncError) = result { synchronizingError = syncError }
                                done()
                            }
                            self.subject.isOnline = true

                            self.mockService.createdEventSource?.sendPing()
                        }
                    }
                    it("requests flags & does not update flag store") {
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
                        expect(synchronizingError == .response(self.mockService.errorFlagHTTPURLResponse)).to(beTrue())
                        expect(mockStore.replaceStoreCallCount) == 0
                        expect(mockStore.replaceStoreReceivedArguments?.newFlags).to(beNil())
                    }
                }
                context("failure error") {
                    var synchronizingError: SynchronizingError?
                    beforeEach {
                        self.mockService.stubFlagResponse(success: false, errorOnly: true)
                        waitUntil { done in
                            self.subject = LDFlagSynchronizer(streamingMode: .streaming, pollingInterval: Constants.pollingInterval, service: self.mockService) { (result) in
                                if case let .error(syncError) = result { synchronizingError = syncError }
                                done()
                            }
                            self.subject.isOnline = true

                            self.mockService.createdEventSource?.sendPing()
                        }
                    }
                    it("requests flags & does not update flag store") {
                        expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
                        expect(synchronizingError == .request(DarklyServiceMock.Constants.error)).to(beTrue())
                        expect(mockStore.replaceStoreCallCount) == 0
                        expect(mockStore.replaceStoreReceivedArguments?.newFlags).to(beNil())
                    }
                }
            }
            context("heartbeat") {
                beforeEach {
                    self.mockService.stubFlagRequest(success: true)
                    self.subject.isOnline = true

                    self.mockService.createdEventSource?.sendHeartbeat()
                }
                it("does not request flags") {
                    expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                }
            }
            context("null event") {
                beforeEach {
                    self.mockService.stubFlagRequest(success: true)
                    self.subject.isOnline = true

                    self.mockService.createdEventSource?.sendNullEvent()
                }
                it("does not request flags") {
                    expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                }
            }
            context("open event") {
                beforeEach {
                    self.mockService.stubFlagRequest(success: true)
                    self.subject.isOnline = true

                    self.mockService.createdEventSource?.sendOpenEvent()
                }
                it("does not request flags") {
                    expect({ self.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                }
            }
        }

        describe("polling timer fires") {
            beforeEach {
                self.subject = LDFlagSynchronizer(streamingMode: .polling, pollingInterval: Constants.pollingInterval, service: self.mockService, onSyncComplete: nil)
                self.subject.isOnline = true
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

    private func synchronizerState(synchronizerOnline isOnline: Bool, streamingMode: LDStreamingMode, flagRequests: Int, streamCreated: Bool, streamClosed: Bool? = nil) -> ToMatchResult {
        var messages = [String]()

        //synchronizer state
        if subject.isOnline != isOnline { messages.append("isOnline equals \(subject.isOnline)") }
        if subject.streamingMode != streamingMode { messages.append("streamingMode equals \(subject.streamingMode)") }
        if subject.streamingActive != isStreamingActive(online: isOnline, streamingMode: streamingMode) { messages.append("streamingActive equals \(subject.streamingActive)") }
        if subject.pollingActive != isPollingActive(online: isOnline, streamingMode: streamingMode) { messages.append("pollingActive equals \(subject.pollingActive)") }

        //flag requests
        if mockService.getFeatureFlagsCallCount != flagRequests { messages.append("flag requests equals \(mockService.getFeatureFlagsCallCount)") }

        messages.append(contentsOf: eventSourceStateVerificationMessages(streamCreated: streamCreated, streamClosed: streamClosed))

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }

    private func eventSourceStateVerificationMessages(streamCreated: Bool, streamClosed: Bool? = nil) -> [String] {
        var messages = [String]()
        //event source
        switch streamCreated {
        case true:
            if let eventSource = mockService.createdEventSource {
                if let streamClosed = streamClosed {
                    if eventSource.closeCallCount != (streamClosed ? 1 : 0) { messages.append("stream closed call count equals \(eventSource.closeCallCount)") }
                }
            } else {
                messages.append("event stream not created")
            }
        case false:
            if mockService.createdEventSource != nil { messages.append("mock service created event source is not nil") }
            if streamClosed != nil { messages.append("stream closed is not nil (this is an incorrect test)") }
        }
        return messages
    }
}

extension SynchronizingError {
    static func == (lhs: SynchronizingError, rhs: SynchronizingError) -> Bool {
        switch (lhs, rhs) {
        case let (.data(left), .data(right)): return left == right
        case let (.response(left), .response(right)):
            guard let leftResponse = left as? HTTPURLResponse, let rightResponse = right as? HTTPURLResponse else {
                return left == nil && right == nil
            }
            return leftResponse.url == rightResponse.url && leftResponse.statusCode == rightResponse.statusCode
        case let (.request(left), .request(right)):
            let leftError = left as NSError
            let rightError = right as NSError
            return leftError.domain == rightError.domain && leftError.code == rightError.code
        default: return false
        }
    }
}

extension Optional where Wrapped == SynchronizingError {
    static func == (lhs: SynchronizingError?, rhs: SynchronizingError?) -> Bool {
        switch (lhs, rhs) {
        case let (.some(left), .some(right)):
            return left == right
        case (.none, .none):
            return true
        default: return false
        }
    }
}
