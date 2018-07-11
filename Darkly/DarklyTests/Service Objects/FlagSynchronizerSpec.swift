//
//  FlagSynchronizerSpec.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 9/20/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
import DarklyEventSource
@testable import Darkly

final class FlagSynchronizerSpec: QuickSpec {
    struct Constants {
        fileprivate static let mockMobileKey = "mockMobileKey"
        fileprivate static let pollingInterval: TimeInterval = 1
        fileprivate static let waitMillis: Int = 500
    }

    struct TestContext {
        var config: LDConfig!
        var user: LDUser!
        var flagStoreMock: FlagMaintainingMock! { return user.flagStore as? FlagMaintainingMock }
        var serviceMock: DarklyServiceMock!
        var eventSourceMock: DarklyStreamingProviderMock? { return serviceMock.createdEventSource }
        var subject: FlagSynchronizer!
        var syncErrorEvent: DarklyEventSource.LDEvent?
        var onSyncCompleteCallCount = 0

        init(streamingMode: LDStreamingMode, useReport: Bool, onSyncComplete: SyncCompleteClosure? = nil) {
            config = LDConfig.stub
            user = LDUser.stub()
            serviceMock = DarklyServiceMock()
            subject = FlagSynchronizer(streamingMode: streamingMode, pollingInterval: Constants.pollingInterval, useReport: useReport, service: serviceMock, onSyncComplete: onSyncComplete)
        }

        private func isStreamingActive(online: Bool, streamingMode: LDStreamingMode) -> Bool { return online && (streamingMode == .streaming) }
        private func isPollingActive(online: Bool, streamingMode: LDStreamingMode) -> Bool { return online && (streamingMode == .polling) }

        fileprivate func synchronizerState(synchronizerOnline isOnline: Bool,
                                           streamingMode: LDStreamingMode,
                                           flagRequests: Int,
                                           streamCreated: Bool,
                                           streamClosed: Bool? = nil) -> ToMatchResult {
            var messages = [String]()

            //synchronizer state
            if subject.isOnline != isOnline { messages.append("isOnline equals \(subject.isOnline)") }
            if subject.streamingMode != streamingMode { messages.append("streamingMode equals \(subject.streamingMode)") }
            if subject.streamingActive != isStreamingActive(online: isOnline, streamingMode: streamingMode) { messages.append("streamingActive equals \(subject.streamingActive)") }
            if subject.pollingActive != isPollingActive(online: isOnline, streamingMode: streamingMode) { messages.append("pollingActive equals \(subject.pollingActive)") }

            //flag requests
            if serviceMock.getFeatureFlagsCallCount != flagRequests { messages.append("flag requests equals \(serviceMock.getFeatureFlagsCallCount)") }

            messages.append(contentsOf: eventSourceStateVerificationMessages(streamCreated: streamCreated, streamClosed: streamClosed))

            return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
        }

        private func eventSourceStateVerificationMessages(streamCreated: Bool, streamClosed: Bool? = nil) -> [String] {
            var messages = [String]()
            //event source
            switch streamCreated {
            case true:
                if let eventSource = eventSourceMock {
                    if let streamClosed = streamClosed {
                        if eventSource.closeCallCount != (streamClosed ? 1 : 0) { messages.append("stream closed call count equals \(eventSource.closeCallCount)") }
                    }
                } else {
                    messages.append("event stream not created")
                }
            case false:
                if eventSourceMock != nil { messages.append("mock service created event source is not nil") }
                if streamClosed != nil { messages.append("stream closed is not nil (this is an incorrect test)") }
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
                        expect(testContext.subject.pollingInterval) == Constants.pollingInterval
                        expect(testContext.subject.useReport) == false
                    }
                }
                context("report flag requests") {
                    beforeEach {
                        testContext = TestContext(streamingMode: .streaming, useReport: true)
                    }
                    it("starts up streaming offline using report flag requests") {
                        expect({ testContext.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: false) }).to(match())
                        expect(testContext.subject.pollingInterval) == Constants.pollingInterval
                        expect(testContext.subject.useReport) == true
                    }
                }
            }
            context("polling mode") {
                context("get flag requests") {
                    beforeEach {
                        testContext = TestContext(streamingMode: .polling, useReport: false)
                    }
                    it("starts up polling offline using get flag requests") {
                        expect({ testContext.synchronizerState(synchronizerOnline: false, streamingMode: .polling, flagRequests: 0, streamCreated: false) }).to(match())
                        expect(testContext.subject.pollingInterval) == Constants.pollingInterval
                        expect(testContext.subject.useReport) == false
                    }
                }
                context("report flag requests") {
                    beforeEach {
                        testContext = TestContext(streamingMode: .polling, useReport: true)
                    }
                    it("starts up polling offline using report flag requests") {
                        expect({ testContext.synchronizerState(synchronizerOnline: false, streamingMode: .polling, flagRequests: 0, streamCreated: false) }).to(match())
                        expect(testContext.subject.pollingInterval) == Constants.pollingInterval
                        expect(testContext.subject.useReport) == true
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
                        testContext.subject.isOnline = true

                        testContext.subject.isOnline = false
                    }
                    it("stops streaming") {
                        expect({ testContext.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: true) }).to(match())
                    }
                }
                context("polling") {
                    beforeEach {
                        testContext = TestContext(streamingMode: .polling, useReport: false)
                        testContext.subject.isOnline = true

                        testContext.subject.isOnline = false
                    }
                    it("stops polling") {
                        expect({ testContext.synchronizerState(synchronizerOnline: false, streamingMode: .polling, flagRequests: 1, streamCreated: false) }).to(match())
                    }
                }
            }
            context("offline to online") {
                context("streaming") {
                    beforeEach {
                        testContext.subject.isOnline = true
                    }
                    it("starts streaming") {
                        //streaming expects a ping on successful connection that triggers a flag request. No ping means no flag requests
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                        expect(testContext.eventSourceMock?.onMessageEventCallCount) == 1
                        expect(testContext.eventSourceMock?.onMessageEventReceivedHandler).toNot(beNil())
                        expect(testContext.eventSourceMock?.onErrorEventCallCount) == 1
                        expect(testContext.eventSourceMock?.onErrorEventReceivedHandler).toNot(beNil())
                    }
                }
                context("polling") {
                    beforeEach {
                        testContext = TestContext(streamingMode: .polling, useReport: false)

                        testContext.subject.isOnline = true
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
                        testContext.subject.isOnline = true

                        testContext.subject.isOnline = true
                    }
                    it("does not stop streaming") {
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                        expect(testContext.eventSourceMock?.onMessageEventCallCount) == 1
                        expect(testContext.eventSourceMock?.onErrorEventCallCount) == 1
                    }
                }
                context("polling") {
                    beforeEach {
                        testContext = TestContext(streamingMode: .polling, useReport: false)
                        testContext.subject.isOnline = true

                        testContext.subject.isOnline = true
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
                        testContext.subject.isOnline = false
                    }
                    it("does not start streaming") {
                        expect({ testContext.synchronizerState(synchronizerOnline: false, streamingMode: .streaming, flagRequests: 0, streamCreated: false) }).to(match())
                    }
                }
                context("polling") {
                    beforeEach {
                        testContext = TestContext(streamingMode: .polling, useReport: false)

                        testContext.subject.isOnline = false
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
                                if case .error(let errorResult) = syncResult, case .event(let errorEvent) = errorResult { testContext.syncErrorEvent = errorEvent }
                                done()
                            })
                            testContext.subject.isOnline = true

                            testContext.eventSourceMock?.sendEvent(LDEvent.stubErrorEvent())
                        }
                    }
                    it("does not request flags & reports the error via onSyncComplete") {
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                        expect(testContext.syncErrorEvent).toNot(beNil())
                        expect(testContext.syncErrorEvent?.isUnauthorized).to(beFalse())
                    }
                }
                context("unauthorized error event") {
                    beforeEach {
                        waitUntil { done in
                            testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { (syncResult) in
                                if case .error(let errorResult) = syncResult, case .event(let errorEvent) = errorResult { testContext.syncErrorEvent = errorEvent }
                                done()
                            })
                            testContext.subject.isOnline = true

                            testContext.eventSourceMock?.sendEvent(LDEvent.stubUnauthorizedEvent())
                        }
                    }
                    it("does not request flags & reports the error via onSyncComplete") {
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                        expect(testContext.syncErrorEvent).toNot(beNil())
                        expect(testContext.syncErrorEvent?.isUnauthorized).to(beTrue())
                    }
                }
                context("heartbeat") {
                    beforeEach {
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendHeartbeat()
                    }
                    it("does not request flags or report sync complete") {
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                        expect(testContext.onSyncCompleteCallCount) == 0
                    }
                }
                context("null event") {
                    beforeEach {
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendNullEvent()
                    }
                    it("does not request flags or report sync complete") {
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                        expect(testContext.onSyncCompleteCallCount) == 0
                    }
                }
                context("connecting event") {
                    beforeEach {
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendEvent(LDEvent.stubReadyStateEvent(eventState: kEventStateConnecting))
                    }
                    it("does not request flags or report sync complete") {
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                        expect(testContext.onSyncCompleteCallCount) == 0
                    }
                }
                context("open event") {
                    beforeEach {
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendEvent(LDEvent.stubReadyStateEvent(eventState: kEventStateOpen))
                    }
                    it("does not request flags or report sync complete") {
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                        expect(testContext.onSyncCompleteCallCount) == 0
                    }
                }
                context("closed event") {
                    beforeEach {
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendEvent(LDEvent.stubReadyStateEvent(eventState: kEventStateClosed))
                    }
                    it("does not request flags") {
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                        expect(testContext.onSyncCompleteCallCount) == 0
                    }
                }
                context("non NSError event") {
                    var syncErrorEvent: DarklyEventSource.LDEvent?
                    beforeEach {
                        waitUntil { done in
                            testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { (syncResult) in
                                if case .error(let errorResult) = syncResult, case .event(let errorEvent) = errorResult { syncErrorEvent = errorEvent }
                                done()
                            })
                            testContext.subject.isOnline = true

                            testContext.eventSourceMock?.sendEvent(LDEvent.stubNonNSErrorEvent())
                        }
                    }
                    it("does not request flags & reports the error via onSyncComplete") {
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                        expect(syncErrorEvent).toNot(beNil())
                        expect(syncErrorEvent?.isUnauthorized).to(beFalse())
                    }
                }
            }
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
                            if case .success(let flags, let streamEvent) = result { (newFlags, streamingEvent) = (flags.flagCollection, streamEvent) }
                            done()
                        })
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok)
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendPing()
                    }
                }
                it("requests flags and calls onSyncComplete with the new flags and streaming event") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
                    expect(newFlags == DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true)).to(beTrue())
                    expect(streamingEvent) == .ping
                }
            }
            context("bad data") {
                var synchronizingError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { (result) in
                            if case let .error(syncError) = result { synchronizingError = syncError }
                            done()
                        })
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok, badData: true)
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendPing()
                    }
                }
                it("requests flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
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
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendPing()
                    }
                }
                it("requests flags and calls onSyncComplete with a response error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
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
                            if case let .error(syncError) = result { synchronizingError = syncError }
                            done()
                        })
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.internalServerError, errorOnly: true)
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendPing()
                    }
                }
                it("requests flags and calls onSyncComplete with a request error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
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
                            if case .success(let flags, let streamEvent) = result { (newFlags, streamingEvent) = (flags.flagCollection, streamEvent) }
                            done()
                        })
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendPut()
                    }
                }
                it("does not request flags and calls onSyncComplete with new flags and put event type") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                    expect(newFlags == DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true)).to(beTrue())
                    expect(streamingEvent) == .put
                }
            }
            context("bad data") {
                var syncError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .error(let error) = result { syncError = error }
                            done()
                        })
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendEvent(DarklyEventSource.LDEvent.stubPutEvent(data: DarklyServiceMock.Constants.jsonErrorString))
                    }
                }
                it("does not request flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                    expect(syncError == .data(DarklyServiceMock.Constants.errorData)).to(beTrue())
                }
            }
            context("missing data") {
                var syncError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .error(let error) = result { syncError = error }
                            done()
                        })
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendEvent(DarklyEventSource.LDEvent.stubPutEvent(data: nil))
                    }
                }
                it("does not request flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
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
                            if case .success(let patch, let streamEvent) = result { (flagDictionary, streamingEvent) = (patch, streamEvent) }
                            done()
                        })
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendPatch()
                    }
                }
                it("does not request flags and calls onSyncComplete with new flags and put event type") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                    expect(flagDictionary == FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int, value: DarklyServiceMock.FlagValues.int + 1, version: DarklyServiceMock.Constants.version + 1)).to(beTrue())
                    expect(streamingEvent) == .patch
                }
            }
            context("bad data") {
                var syncError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .error(let error) = result { syncError = error }
                            done()
                        })
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendEvent(DarklyEventSource.LDEvent.stubPatchEvent(data: DarklyServiceMock.Constants.jsonErrorString))
                    }
                }
                it("does not request flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                    expect(syncError == .data(DarklyServiceMock.Constants.errorData)).to(beTrue())
                }
            }
            context("missing data") {
                var syncError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .error(let error) = result { syncError = error }
                            done()
                        })
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendEvent(DarklyEventSource.LDEvent.stubPatchEvent(data: nil))
                    }
                }
                it("does not request flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
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
                            if case .success(let delete, let streamEvent) = result { (flagDictionary, streamingEvent) = (delete, streamEvent) }
                            done()
                        })
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendDelete()
                    }
                }
                it("does not request flags and calls onSyncComplete with new flags and put event type") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                    expect(flagDictionary == FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version + 1)).to(beTrue())
                    expect(streamingEvent) == .delete
                }
            }
            context("bad data") {
                var syncError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .error(let error) = result { syncError = error }
                            done()
                        })
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendEvent(DarklyEventSource.LDEvent.stubDeleteEvent(data: DarklyServiceMock.Constants.jsonErrorString))
                    }
                }
                it("does not request flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                    expect(syncError == .data(DarklyServiceMock.Constants.errorData)).to(beTrue())
                }
            }
            context("missing data") {
                var syncError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .error(let error) = result { syncError = error }
                            done()
                        })
                        testContext.subject.isOnline = true

                        testContext.eventSourceMock?.sendEvent(DarklyEventSource.LDEvent.stubDeleteEvent(data: nil))
                    }
                }
                it("does not request flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                    expect(syncError == .data(nil)).to(beTrue())
                }
            }
        }
    }

    func pollingTimerFiresSpec() {
        describe("polling timer fires") {
            context("one second interval") {
                var testContext: TestContext?
                var newFlags: [String: FeatureFlag]?
                var streamingEvent: DarklyEventSource.LDEvent.EventType?
                beforeEach {
                    testContext = TestContext(streamingMode: .polling, useReport: false)
                    testContext?.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok)
                    testContext?.subject.isOnline = true

                    waitUntil(timeout: 2) { done in
                        //In polling mode, the flagSynchronizer makes a flag request when set online right away. To verify the timer this test waits the polling interval (1s) for a second flag request
                        testContext?.subject.onSyncComplete = { (result) in
                            if case .success(let flags, let streamEvent) = result {
                                (newFlags, streamingEvent) = (flags.flagCollection, streamEvent)
                            }
                            done()
                        }
                    }
                }
                it("makes a flag request and calls onSyncComplete with no streaming event") {
                    expect(testContext?.serviceMock.getFeatureFlagsCallCount) == 2
                    expect(newFlags == DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true)).to(beTrue())
                    expect(streamingEvent).to(beNil())
                }
                //This particular test causes a retain cycle between the FlagSynchronizer and something else. By removing onSyncComplete, the closure is no longer called after the test is complete.
                afterEach {
                    testContext?.subject.onSyncComplete = nil
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
                            testContext.subject.isOnline = true

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
                                    testContext.subject.isOnline = true

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
                                    testContext.subject.isOnline = true

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
                            testContext.subject.isOnline = true

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
                                    testContext.subject.isOnline = true

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
                                    testContext.subject.isOnline = true

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
