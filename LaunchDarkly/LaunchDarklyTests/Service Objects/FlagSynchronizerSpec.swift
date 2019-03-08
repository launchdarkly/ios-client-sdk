//
//  FlagSynchronizerSpec.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 9/20/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
import DarklyEventSource
@testable import LaunchDarkly

final class FlagSynchronizerSpec: QuickSpec {
    struct Constants {
        fileprivate static let pollingInterval: TimeInterval = 1
        fileprivate static let waitMillis: Int = 500
    }

    struct TestContext {
        var config: LDConfig!
        var user: LDUser!
        var flagStoreMock: FlagMaintainingMock! {
            return user.flagStore as? FlagMaintainingMock
        }
        var serviceMock: DarklyServiceMock!
        var eventSourceMock: DarklyStreamingProviderMock? {
            return serviceMock.createdEventSource
        }
        var flagSynchronizer: FlagSynchronizer!
        var syncErrorEvent: DarklyEventSource.LDEvent?
        var onSyncCompleteCallCount = 0

        init(streamingMode: LDStreamingMode, useReport: Bool, onSyncComplete: FlagSyncCompleteClosure? = nil) {
            config = LDConfig.stub
            user = LDUser.stub()
            serviceMock = DarklyServiceMock()
            flagSynchronizer = FlagSynchronizer(streamingMode: streamingMode,
                                                pollingInterval: Constants.pollingInterval,
                                                useReport: useReport,
                                                service: serviceMock,
                                                onSyncComplete: onSyncComplete)
        }

        private func isStreamingActive(online: Bool, streamingMode: LDStreamingMode) -> Bool {
            return online && (streamingMode == .streaming)
        }
        private func isPollingActive(online: Bool, streamingMode: LDStreamingMode) -> Bool {
            return online && (streamingMode == .polling)
        }

        fileprivate func synchronizerState(synchronizerOnline isOnline: Bool,
                                           streamingMode: LDStreamingMode,
                                           flagRequests: Int,
                                           streamCreated: Bool,
                                           streamOpened: Bool? = nil,
                                           streamClosed: Bool? = nil) -> ToMatchResult {
            var messages = [String]()

            //synchronizer state
            if flagSynchronizer.isOnline != isOnline {
                messages.append("isOnline equals \(flagSynchronizer.isOnline)")
            }
            if flagSynchronizer.streamingMode != streamingMode {
                messages.append("streamingMode equals \(flagSynchronizer.streamingMode)")
            }
            if flagSynchronizer.streamingActive != isStreamingActive(online: isOnline, streamingMode: streamingMode) {
                messages.append("streamingActive equals \(flagSynchronizer.streamingActive)")
            }
            if flagSynchronizer.pollingActive != isPollingActive(online: isOnline, streamingMode: streamingMode) {
                messages.append("pollingActive equals \(flagSynchronizer.pollingActive)")
            }

            //flag requests
            if serviceMock.getFeatureFlagsCallCount != flagRequests {
                messages.append("flag requests equals \(serviceMock.getFeatureFlagsCallCount)")
            }

            messages.append(contentsOf: eventSourceStateVerificationMessages(streamCreated: streamCreated, streamOpened: streamOpened, streamClosed: streamClosed))

            return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
        }

        private func eventSourceStateVerificationMessages(streamCreated: Bool, streamOpened: Bool? = nil, streamClosed: Bool? = nil) -> [String] {
            var messages = [String]()
            //event source
            switch streamCreated {
            case true:
                if let eventSource = eventSourceMock {
                    if let streamOpened = streamOpened {
                        if eventSource.openCallCount != (streamOpened ? 1 : 0) {
                            messages.append("stream opened call count equals \(eventSource.openCallCount)")
                        }
                    }
                    if let streamClosed = streamClosed {
                        if eventSource.closeCallCount != (streamClosed ? 1 : 0) {
                            messages.append("stream closed call count equals \(eventSource.closeCallCount)")
                        }
                    }
                } else {
                    messages.append("event stream not created")
                }
            case false:
                if eventSourceMock != nil {
                    messages.append("mock service created event source is not nil")
                }
                if streamClosed != nil {
                    messages.append("stream closed is not nil (this is an incorrect test)")
                }
            }
            return messages
        }
    }

    override func spec() {
        initSpec()
        changeIsOnlineSpec()
        streamingEventSpec()
        pollingTimerFiresSpec()
        flagRequestSpec()
    }

    func initSpec() {
        describe("init") {
            var testContext: TestContext!

            beforeEach {
                testContext = TestContext(streamingMode: .streaming, useReport: false)
            }
            context("streaming mode") {
                context("get flag requests") {
                    it("starts up streaming offline using get flag requests") {
                        expect({ testContext.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: false) }).to(match())
                        expect(testContext.flagSynchronizer.pollingInterval) == Constants.pollingInterval
                        expect(testContext.flagSynchronizer.useReport) == false
                    }
                }
                context("report flag requests") {
                    beforeEach {
                        testContext = TestContext(streamingMode: .streaming, useReport: true)
                    }
                    it("starts up streaming offline using report flag requests") {
                        expect({ testContext.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: false) }).to(match())
                        expect(testContext.flagSynchronizer.pollingInterval) == Constants.pollingInterval
                        expect(testContext.flagSynchronizer.useReport) == true
                    }
                }
            }
            context("polling mode") {
                afterEach {
                    testContext.flagSynchronizer.isOnline = false
                }
                context("get flag requests") {
                    beforeEach {
                        testContext = TestContext(streamingMode: .polling, useReport: false)
                    }
                    it("starts up polling offline using get flag requests") {
                        expect({ testContext.synchronizerState(synchronizerOnline: false, streamingMode: .polling, flagRequests: 0, streamCreated: false) }).to(match())
                        expect(testContext.flagSynchronizer.pollingInterval) == Constants.pollingInterval
                        expect(testContext.flagSynchronizer.useReport) == false
                    }
                }
                context("report flag requests") {
                    beforeEach {
                        testContext = TestContext(streamingMode: .polling, useReport: true)
                    }
                    it("starts up polling offline using report flag requests") {
                        expect({ testContext.synchronizerState(synchronizerOnline: false, streamingMode: .polling, flagRequests: 0, streamCreated: false) }).to(match())
                        expect(testContext.flagSynchronizer.pollingInterval) == Constants.pollingInterval
                        expect(testContext.flagSynchronizer.useReport) == true
                    }
                }
            }
        }
    }

    func changeIsOnlineSpec() {
        describe("change isOnline") {
            var testContext: TestContext!

            beforeEach {
                testContext = TestContext(streamingMode: .streaming, useReport: false)
            }
            context("online to offline") {
                context("streaming") {
                    beforeEach {
                        testContext.flagSynchronizer.isOnline = true

                        testContext.flagSynchronizer.isOnline = false
                    }
                    it("stops streaming") {
                        expect({ testContext.synchronizerState(synchronizerOnline: false,
                                                               streamingMode: .streaming,
                                                               flagRequests: 0,
                                                               streamCreated: true,
                                                               streamOpened: true,
                                                               streamClosed: true) }).to(match())
                    }
                }
                context("polling") {
                    beforeEach {
                        testContext = TestContext(streamingMode: .polling, useReport: false)
                        testContext.flagSynchronizer.isOnline = true

                        testContext.flagSynchronizer.isOnline = false
                    }
                    it("stops polling") {
                        expect({ testContext.synchronizerState(synchronizerOnline: false, streamingMode: .polling, flagRequests: 1, streamCreated: false) }).to(match())
                    }
                }
            }
            context("offline to online") {
                context("streaming") {
                    beforeEach {
                        testContext.flagSynchronizer.isOnline = true
                    }
                    it("starts streaming") {
                        //streaming expects a ping on successful connection that triggers a flag request. No ping means no flag requests
                        expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                               streamingMode: .streaming,
                                                               flagRequests: 0,
                                                               streamCreated: true,
                                                               streamOpened: true,
                                                               streamClosed: false) }).to(match())
                        expect(testContext.eventSourceMock?.onMessageEventCallCount) == 1
                        expect(testContext.eventSourceMock?.onMessageEventReceivedHandler).toNot(beNil())
                        expect(testContext.eventSourceMock?.onErrorEventCallCount) == 1
                        expect(testContext.eventSourceMock?.onErrorEventReceivedHandler).toNot(beNil())
                    }
                }
                context("polling") {
                    beforeEach {
                        testContext = TestContext(streamingMode: .polling, useReport: false)

                        testContext.flagSynchronizer.isOnline = true
                    }
                    afterEach {
                        testContext.flagSynchronizer.isOnline = false
                    }
                    it("starts polling") {
                        //polling starts by requesting flags
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .polling, flagRequests: 1, streamCreated: false) }).to(match())
                    }
                }
            }
            context("online to online") {
                context("streaming") {
                    beforeEach {
                        testContext.flagSynchronizer.isOnline = true

                        testContext.flagSynchronizer.isOnline = true
                    }
                    it("does not stop streaming") {
                        expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                               streamingMode: .streaming,
                                                               flagRequests: 0,
                                                               streamCreated: true,
                                                               streamOpened: true,
                                                               streamClosed: false) }).to(match())
                        expect(testContext.eventSourceMock?.onMessageEventCallCount) == 1
                        expect(testContext.eventSourceMock?.onErrorEventCallCount) == 1
                    }
                }
                context("polling") {
                    beforeEach {
                        testContext = TestContext(streamingMode: .polling, useReport: false)
                        testContext.flagSynchronizer.isOnline = true

                        testContext.flagSynchronizer.isOnline = true
                    }
                    afterEach {
                        testContext.flagSynchronizer.isOnline = false
                    }
                    it("does not stop polling") {
                        // setting the same value shouldn't make another flag request
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .polling, flagRequests: 1, streamCreated: false) }).to(match())
                    }
                }
            }
            context("offline to offline") {
                context("streaming") {
                    beforeEach {
                        testContext.flagSynchronizer.isOnline = false
                    }
                    it("does not start streaming") {
                        expect({ testContext.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: false) }).to(match())
                    }
                }
                context("polling") {
                    beforeEach {
                        testContext = TestContext(streamingMode: .polling, useReport: false)

                        testContext.flagSynchronizer.isOnline = false
                    }
                    it("does not start polling") {
                        expect({ testContext.synchronizerState(synchronizerOnline: false, streamingMode: .polling, flagRequests: 0, streamCreated: false) }).to(match())
                    }
                }
            }
        }
    }

    func streamingEventSpec() {
        describe("streaming events") {
            streamingPingEventSpec()
            streamingPutEventSpec()
            streamingPatchEventSpec()
            streamingDeleteEventSpec()
            streamingOtherEventSpec()
            streamingProcessingSpec()
        }
    }

    func streamingPingEventSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext(streamingMode: .streaming, useReport: false)
        }

        context("ping") {
            context("success") {
                var newFlags: [String: FeatureFlag]?
                var streamingEvent: DarklyEventSource.LDEvent.EventType?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .success(let flags, let streamEvent) = result {
                                (newFlags, streamingEvent) = (flags.flagCollection, streamEvent)
                            }
                            done()
                        })
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok)
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendPing()
                    }
                }
                it("requests flags and calls onSyncComplete with the new flags and streaming event") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 1,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(newFlags == DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false)).to(beTrue())
                    expect(streamingEvent) == .ping
                }
            }
            context("bad data") {
                var synchronizingError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { (result) in
                            if case let .error(syncError) = result {
                                synchronizingError = syncError
                            }
                            done()
                        })
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok, badData: true)
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendPing()
                    }
                }
                it("requests flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 1,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(synchronizingError == .data(DarklyServiceMock.Constants.errorData)).to(beTrue())
                }
            }
            context("failure response") {
                var urlResponse: URLResponse?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { (result) in
                            if case let .error(syncError) = result, case .response(let syncErrorResponse) = syncError {
                                urlResponse = syncErrorResponse
                            }
                            done()
                        })
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.internalServerError, responseOnly: true)
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendPing()
                    }
                }
                it("requests flags and calls onSyncComplete with a response error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 1,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(urlResponse).toNot(beNil())
                    if let urlResponse = urlResponse {
                        expect(urlResponse.httpStatusCode) == HTTPURLResponse.StatusCodes.internalServerError
                    }
                }
            }
            context("failure error") {
                var synchronizingError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { (result) in
                            if case let .error(syncError) = result {
                                synchronizingError = syncError
                            }
                            done()
                        })
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.internalServerError, errorOnly: true)
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendPing()
                    }
                }
                it("requests flags and calls onSyncComplete with a request error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 1,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(synchronizingError == .request(DarklyServiceMock.Constants.error)).to(beTrue())
                }
            }
        }
    }

    func streamingPutEventSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext(streamingMode: .streaming, useReport: false)
        }

        context("put") {
            context("success") {
                var newFlags: [String: FeatureFlag]?
                var streamingEvent: DarklyEventSource.LDEvent.EventType?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .success(let flags, let streamEvent) = result {
                                (newFlags, streamingEvent) = (flags.flagCollection, streamEvent)
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendPut()
                    }
                }
                it("does not request flags and calls onSyncComplete with new flags and put event type") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(newFlags == DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false)).to(beTrue())
                    expect(streamingEvent) == .put
                }
            }
            context("bad data") {
                var syncError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .error(let error) = result {
                                syncError = error
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendEvent(DarklyEventSource.LDEvent.stubPutEvent(data: DarklyServiceMock.Constants.jsonErrorString))
                    }
                }
                it("does not request flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(syncError == .data(DarklyServiceMock.Constants.errorData)).to(beTrue())
                }
            }
            context("missing data") {
                var syncError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .error(let error) = result {
                                syncError = error
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendEvent(DarklyEventSource.LDEvent.stubPutEvent(data: nil))
                    }
                }
                it("does not request flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(syncError == .data(nil)).to(beTrue())
                }
            }
        }
    }

    func streamingPatchEventSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext(streamingMode: .streaming, useReport: false)
        }

        context("patch") {
            context("success") {
                var flagDictionary: [String: Any]?
                var streamingEvent: DarklyEventSource.LDEvent.EventType?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .success(let patch, let streamEvent) = result {
                                (flagDictionary, streamingEvent) = (patch, streamEvent)
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendPatch()
                    }
                }
                it("does not request flags and calls onSyncComplete with new flags and put event type") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(flagDictionary == FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                     value: DarklyServiceMock.FlagValues.int + 1,
                                                                                     variation: DarklyServiceMock.Constants.variation + 1,
                                                                                     version: DarklyServiceMock.Constants.version + 1)).to(beTrue())
                    expect(streamingEvent) == .patch
                }
            }
            context("bad data") {
                var syncError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .error(let error) = result {
                                syncError = error
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendEvent(DarklyEventSource.LDEvent.stubPatchEvent(data: DarklyServiceMock.Constants.jsonErrorString))
                    }
                }
                it("does not request flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(syncError == .data(DarklyServiceMock.Constants.errorData)).to(beTrue())
                }
            }
            context("missing data") {
                var syncError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .error(let error) = result {
                                syncError = error
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendEvent(DarklyEventSource.LDEvent.stubPatchEvent(data: nil))
                    }
                }
                it("does not request flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(syncError == .data(nil)).to(beTrue())
                }
            }
        }
    }

    func streamingDeleteEventSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext(streamingMode: .streaming, useReport: false)
        }

        context("delete") {
            context("success") {
                var flagDictionary: [String: Any]?
                var streamingEvent: DarklyEventSource.LDEvent.EventType?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .success(let delete, let streamEvent) = result {
                                (flagDictionary, streamingEvent) = (delete, streamEvent)
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendDelete()
                    }
                }
                it("does not request flags and calls onSyncComplete with new flags and put event type") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(flagDictionary == FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version + 1)).to(beTrue())
                    expect(streamingEvent) == .delete
                }
            }
            context("bad data") {
                var syncError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .error(let error) = result {
                                syncError = error
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendEvent(DarklyEventSource.LDEvent.stubDeleteEvent(data: DarklyServiceMock.Constants.jsonErrorString))
                    }
                }
                it("does not request flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(syncError == .data(DarklyServiceMock.Constants.errorData)).to(beTrue())
                }
            }
            context("missing data") {
                var syncError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .error(let error) = result {
                                syncError = error
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendEvent(DarklyEventSource.LDEvent.stubDeleteEvent(data: nil))
                    }
                }
                it("does not request flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(syncError == .data(nil)).to(beTrue())
                }
            }
        }
    }

    func streamingOtherEventSpec() {
        context("other events") {
            var testContext: TestContext!

            beforeEach {
                testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { (_) in
                    testContext.onSyncCompleteCallCount += 1
                })
            }
            context("error event") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { (syncResult) in
                            if case .error(let errorResult) = syncResult, case .event(let errorEvent) = errorResult {
                                testContext.syncErrorEvent = errorEvent
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendEvent(LDEvent.stubErrorEvent())
                    }
                }
                it("does not request flags & reports the error via onSyncComplete") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(testContext.syncErrorEvent).toNot(beNil())
                    expect(testContext.syncErrorEvent?.isUnauthorized).to(beFalse())
                }
            }
            context("unauthorized error event") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { (syncResult) in
                            if case .error(let errorResult) = syncResult, case .event(let errorEvent) = errorResult {
                                testContext.syncErrorEvent = errorEvent
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendEvent(LDEvent.stubUnauthorizedEvent())
                    }
                }
                it("does not request flags & reports the error via onSyncComplete") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(testContext.syncErrorEvent).toNot(beNil())
                    expect(testContext.syncErrorEvent?.isUnauthorized).to(beTrue())
                }
            }
            context("heartbeat") {
                beforeEach {
                    testContext.flagSynchronizer.isOnline = true

                    testContext.eventSourceMock?.sendHeartbeat()
                }
                it("does not request flags or report sync complete") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(testContext.onSyncCompleteCallCount) == 0
                }
            }
            context("null event") {
                beforeEach {
                    testContext.flagSynchronizer.isOnline = true

                    testContext.eventSourceMock?.sendNullEvent()
                }
                it("does not request flags or report sync complete") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(testContext.onSyncCompleteCallCount) == 0
                }
            }
            context("connecting event") {
                beforeEach {
                    testContext.flagSynchronizer.isOnline = true

                    testContext.eventSourceMock?.sendEvent(LDEvent.stubReadyStateEvent(eventState: kEventStateConnecting))
                }
                it("does not request flags or report sync complete") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(testContext.onSyncCompleteCallCount) == 0
                }
            }
            context("open event") {
                beforeEach {
                    testContext.flagSynchronizer.isOnline = true

                    testContext.eventSourceMock?.sendEvent(LDEvent.stubReadyStateEvent(eventState: kEventStateOpen))
                }
                it("does not request flags or report sync complete") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(testContext.onSyncCompleteCallCount) == 0
                }
            }
            context("closed event") {
                beforeEach {
                    testContext.flagSynchronizer.isOnline = true

                    testContext.eventSourceMock?.sendEvent(LDEvent.stubReadyStateEvent(eventState: kEventStateClosed))
                }
                it("does not request flags") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(testContext.onSyncCompleteCallCount) == 0
                }
            }
            context("non NSError event") {
                var syncErrorEvent: DarklyEventSource.LDEvent?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { (syncResult) in
                            if case .error(let errorResult) = syncResult,
                               case .event(let errorEvent) = errorResult {
                                syncErrorEvent = errorEvent
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.eventSourceMock?.sendEvent(LDEvent.stubNonNSErrorEvent())
                    }
                }
                it("does not request flags & reports the error via onSyncComplete") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(syncErrorEvent).toNot(beNil())
                    expect(syncErrorEvent?.isUnauthorized).to(beFalse())
                }
            }
        }
    }

    private func streamingProcessingSpec() {
        var testContext: TestContext!
        var syncError: SynchronizingError?
        var event: DarklyEventSource.LDEvent!

        context("event reported while offline") {
            beforeEach {
                event = DarklyEventSource.LDEvent.stubPutEvent(data: DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false, includeVariations: true, includeVersions: true)
                    .dictionaryValue
                    .jsonString)
                waitUntil { done in
                    testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                        if case .error(let errorResult) = result {
                            syncError = errorResult
                        }
                        done()
                    })

                    testContext.flagSynchronizer.testProcessEvent(event)
                }
            }
            it("reports offline") {
                expect(syncError == .isOffline).to(beTrue())
            }
        }
        context("event reported while polling") {
            beforeEach {
                event = DarklyEventSource.LDEvent.stubPutEvent(data: DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false, includeVariations: true, includeVersions: true)
                    .dictionaryValue
                    .jsonString)
                waitUntil { done in
                    testContext = TestContext(streamingMode: .polling, useReport: false, onSyncComplete: { _ in
                        done()
                    })
                    testContext.flagSynchronizer.isOnline = true
                }
                waitUntil { done in
                    testContext.flagSynchronizer.onSyncComplete = { result in
                        if case .error(let errorResult) = result {
                            syncError = errorResult
                        }
                        done()
                    }

                    testContext.flagSynchronizer.testProcessEvent(event)
                }
            }
            afterEach {
                testContext.flagSynchronizer.isOnline = false
            }
            it("reports an event error") {
                expect(syncError == .event(event)).to(beTrue())
            }
        }
        context("event reported while streaming inactive") {
            beforeEach {
                event = DarklyEventSource.LDEvent.stubPutEvent(data: DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false, includeVariations: true, includeVersions: true)
                    .dictionaryValue
                    .jsonString)
                waitUntil { done in
                    testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                        if case .error(let errorResult) = result {
                            syncError = errorResult
                        }
                        done()
                    })
                    testContext.flagSynchronizer.isOnline = true
                    testContext.flagSynchronizer.testEventSource = nil

                    testContext.flagSynchronizer.testProcessEvent(event)
                }
            }
            it("reports offline") {
                expect(syncError == .isOffline).to(beTrue())
            }
        }
    }

    func pollingTimerFiresSpec() {
        describe("polling timer fires") {
            context("one second interval") {
                var testContext: TestContext!
                var newFlags: [String: FeatureFlag]?
                var streamingEvent: DarklyEventSource.LDEvent.EventType?
                beforeEach {
                    testContext = TestContext(streamingMode: .polling, useReport: false)
                    testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok)
                    testContext.flagSynchronizer.isOnline = true

                    waitUntil(timeout: 2) { done in
                        //In polling mode, the flagSynchronizer makes a flag request when set online right away. To verify the timer this test waits the polling interval (1s) for a second flag request
                        testContext.flagSynchronizer.onSyncComplete = { (result) in
                            if case .success(let flags, let streamEvent) = result {
                                (newFlags, streamingEvent) = (flags.flagCollection, streamEvent)
                            }
                            done()
                        }
                    }
                }
                afterEach {
                    testContext.flagSynchronizer.isOnline = false
                }
                it("makes a flag request and calls onSyncComplete with no streaming event") {
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 2
                    expect(newFlags == DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false, includeVariations: true, includeVersions: true)).to(beTrue())
                    expect(streamingEvent).to(beNil())
                }
                //This particular test causes a retain cycle between the FlagSynchronizer and something else. By removing onSyncComplete, the closure is no longer called after the test is complete.
                afterEach {
                    testContext.flagSynchronizer.onSyncComplete = nil
                }
            }
        }
    }

    func flagRequestSpec() {
        describe("flag request") {
            var testContext: TestContext!
            context("using get method") {
                context("success") {
                    beforeEach {
                        waitUntil { done in
                            testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { _ in
                                done()
                            })
                            testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok)
                            testContext.flagSynchronizer.isOnline = true

                            testContext.eventSourceMock?.sendPing()
                        }
                    }
                    it("requests flags using a get request exactly one time") {
                        expect(testContext.serviceMock.getFeatureFlagsCallCount) == 1
                        expect(testContext.serviceMock.getFeatureFlagsUseReportCalledValue.first) == false
                    }
                }
                context("failure") {
                    context("with a non-retry status code") {
                        it("requests flags using a get request exactly one time") {
                            for statusCode in HTTPURLResponse.StatusCodes.nonRetry {
                                waitUntil { done in
                                    testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { _ in
                                        done()
                                    })
                                    testContext.serviceMock.stubFlagResponse(statusCode: statusCode)
                                    testContext.flagSynchronizer.isOnline = true

                                    testContext.eventSourceMock?.sendPing()
                                }

                                expect(testContext.serviceMock.getFeatureFlagsCallCount) == 1
                                expect(testContext.serviceMock.getFeatureFlagsUseReportCalledValue.first) == false
                            }
                        }
                    }
                    context("with a retry status code") {
                        it("requests flags using a get request exactly one time") {
                            for statusCode in HTTPURLResponse.StatusCodes.retry {
                                waitUntil { done in
                                    testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { _ in
                                        done()
                                    })
                                    testContext.serviceMock.stubFlagResponse(statusCode: statusCode)
                                    testContext.flagSynchronizer.isOnline = true

                                    testContext.eventSourceMock?.sendPing()
                                }

                                expect(testContext.serviceMock.getFeatureFlagsCallCount) == 1
                                expect(testContext.serviceMock.getFeatureFlagsUseReportCalledValue.first) == false
                            }
                        }
                    }
                }
            }
            context("using report method") {
                context("success") {
                    beforeEach {
                        waitUntil { done in
                            testContext = TestContext(streamingMode: .streaming, useReport: true, onSyncComplete: { _ in
                                done()
                            })
                            testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok)
                            testContext.flagSynchronizer.isOnline = true

                            testContext.eventSourceMock?.sendPing()
                        }
                    }
                    it("requests flags using a get request exactly one time") {
                        expect(testContext.serviceMock.getFeatureFlagsCallCount) == 1
                        expect(testContext.serviceMock.getFeatureFlagsUseReportCalledValue.first) == true
                    }
                }
                context("failure") {
                    context("with a non-retry status code") {
                        it("requests flags using a get request exactly one time") {
                            for statusCode in HTTPURLResponse.StatusCodes.nonRetry {
                                waitUntil { done in
                                    testContext = TestContext(streamingMode: .streaming, useReport: true, onSyncComplete: { _ in
                                        done()
                                    })
                                    testContext.serviceMock.stubFlagResponse(statusCode: statusCode)
                                    testContext.flagSynchronizer.isOnline = true

                                    testContext.eventSourceMock?.sendPing()
                                }

                                expect(testContext.serviceMock.getFeatureFlagsCallCount) == 1
                                expect(testContext.serviceMock.getFeatureFlagsUseReportCalledValue.first) == true
                            }
                        }
                    }
                    context("with a retry status code") {
                        it("requests flags using a report request exactly one time, followed by a get request exactly one time") {
                            for statusCode in HTTPURLResponse.StatusCodes.retry {
                                waitUntil { done in
                                    testContext = TestContext(streamingMode: .streaming, useReport: true, onSyncComplete: { _ in
                                        done()
                                    })
                                    testContext.serviceMock.stubFlagResponse(statusCode: statusCode)
                                    testContext.flagSynchronizer.isOnline = true

                                    testContext.eventSourceMock?.sendPing()
                                }

                                expect(testContext.serviceMock.getFeatureFlagsCallCount) == 2
                                expect(testContext.serviceMock.getFeatureFlagsUseReportCalledValue.first) == true
                                expect(testContext.serviceMock.getFeatureFlagsUseReportCalledValue.last) == false
                            }
                        }
                    }
                }
            }
        }
        describe("makeFlagRequest") {
            var testContext: TestContext!
            //This test completes the test suite on makeFlagRequest by validating the method bails out if it's called and the synchronizer is offline. While that shouldn't happen, there are 2 code paths that don't directly verify the SDK is online before calling the method, so it seems a wise precaution to validate that the method does bailout. Other tests exercise the rest of the method.
            context("offline") {
                var synchronizingError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { (result) in
                            if case .error(let syncError) = result {
                                synchronizingError = syncError
                            }
                            done()
                        })
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok)

                        testContext.flagSynchronizer.testMakeFlagRequest()
                    }
                }
                it("does not request flags and calls onSyncComplete with an isOffline error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: false) }).to(match())
                    expect(synchronizingError) == SynchronizingError.isOffline
                }
            }
        }
    }
}

extension SynchronizingError: Equatable {
    public static func == (lhs: SynchronizingError, rhs: SynchronizingError) -> Bool {
        switch (lhs, rhs) {
        case (.isOffline, .isOffline):
            return true
        case let (.data(left), .data(right)):
            return left == right
        case let (.response(left), .response(right)):
            guard let leftResponse = left as? HTTPURLResponse, let rightResponse = right as? HTTPURLResponse
            else {
                return left == nil && right == nil
            }
            return leftResponse.url == rightResponse.url && leftResponse.statusCode == rightResponse.statusCode
        case let (.request(left), .request(right)):
            let leftError = left as NSError
            let rightError = right as NSError
            return leftError.domain == rightError.domain && leftError.code == rightError.code
        case let (.event(left), .event(right)):
            return left == right
        default:
            return false
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
