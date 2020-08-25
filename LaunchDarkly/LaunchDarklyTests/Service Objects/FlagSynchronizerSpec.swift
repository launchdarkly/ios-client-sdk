//
//  FlagSynchronizerSpec.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
import LDSwiftEventSource
@testable import LaunchDarkly

final class FlagSynchronizerSpec: QuickSpec {
    struct Constants {
        fileprivate static let pollingInterval: TimeInterval = 1
        fileprivate static let waitMillis: Int = 500
    }

    struct TestContext {
        var config: LDConfig!
        var user: LDUser!
        var serviceMock: DarklyServiceMock!
        var eventSourceMock: DarklyStreamingProviderMock? {
            serviceMock.createdEventSource
        }
        var providedEventHandler: EventHandler? {
            serviceMock.createEventSourceReceivedHandler
        }
        var providedErrorHandler: ConnectionErrorHandler? {
            serviceMock.createEventSourceReceivedConnectionErrorHandler
        }
        var flagSynchronizer: FlagSynchronizer!
        var onSyncCompleteCallCount = 0
        var diagnosticCacheMock: DiagnosticCachingMock

        init(streamingMode: LDStreamingMode, useReport: Bool, onSyncComplete: FlagSyncCompleteClosure? = nil) {
            config = LDConfig.stub
            user = LDUser.stub()
            serviceMock = DarklyServiceMock()
            diagnosticCacheMock = DiagnosticCachingMock()
            serviceMock.diagnosticCache = diagnosticCacheMock
            flagSynchronizer = FlagSynchronizer(streamingMode: streamingMode,
                                                pollingInterval: Constants.pollingInterval,
                                                useReport: useReport,
                                                service: serviceMock,
                                                onSyncComplete: onSyncComplete)
        }

        private func isStreamingActive(online: Bool, streamingMode: LDStreamingMode) -> Bool {
            online && (streamingMode == .streaming)
        }
        private func isPollingActive(online: Bool, streamingMode: LDStreamingMode) -> Bool {
            online && (streamingMode == .polling)
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

            let expectedStreamCreate = streamCreated ? 1 : 0
            if serviceMock.createEventSourceCallCount != expectedStreamCreate {
                messages.append("stream create call count equals \(serviceMock.createEventSourceCallCount), expected \(expectedStreamCreate)")
            }

            if let streamOpened = streamOpened {
                let expectedStreamOpened = streamOpened ? 1 : 0
                if eventSourceMock?.startCallCount != expectedStreamOpened {
                    messages.append("stream start call count equals \(String(describing: eventSourceMock?.startCallCount)), expected \(expectedStreamOpened)")
                }
            }

            if let streamClosed = streamClosed {
                if eventSourceMock?.stopCallCount != (streamClosed ? 1 : 0) {
                    messages.append("stream closed call count equals \(eventSourceMock?.stopCallCount ?? 0), expected \(streamClosed ? 1 : 0)")
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
                        expect(testContext.serviceMock.createEventSourceCallCount) == 1
                        expect(testContext.eventSourceMock!.startCallCount) == 1
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
                        expect(testContext.serviceMock.createEventSourceCallCount) == 1
                        expect(testContext.eventSourceMock!.startCallCount) == 1
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
                var streamingEvent: FlagUpdateType?
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
                        testContext.providedEventHandler!.sendPing()
                    }
                }
                it("requests flags and calls onSyncComplete with the new flags and streaming event") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 1,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(newFlags) == DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false)
                    expect(streamingEvent) == .ping
                }
            }
            context("bad data") {
                var synchronizingError: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case let .error(syncError) = result {
                                synchronizingError = syncError
                            }
                            done()
                        })
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok, badData: true)
                        testContext.flagSynchronizer.isOnline = true

                        testContext.providedEventHandler!.sendPing()
                    }
                }
                it("requests flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 1,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    guard case .data(DarklyServiceMock.Constants.errorData) = synchronizingError
                    else {
                        fail("Unexpected error for bad data: \(String(describing: synchronizingError))")
                        return
                    }
                }
            }
            context("failure response") {
                var urlResponse: URLResponse?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case let .error(syncError) = result, case .response(let syncErrorResponse) = syncError {
                                urlResponse = syncErrorResponse
                            }
                            done()
                        })
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.internalServerError, responseOnly: true)
                        testContext.flagSynchronizer.isOnline = true

                        testContext.providedEventHandler!.sendPing()
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
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case let .error(syncError) = result {
                                synchronizingError = syncError
                            }
                            done()
                        })
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.internalServerError, errorOnly: true)
                        testContext.flagSynchronizer.isOnline = true

                        testContext.providedEventHandler!.sendPing()
                    }
                }
                it("requests flags and calls onSyncComplete with a request error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 1,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    guard case let .request(error) = synchronizingError,
                          DarklyServiceMock.Constants.error == error as NSError
                    else {
                        fail("Unexpected error for failure: \(String(describing: synchronizingError))")
                        return
                    }
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
                var streamingEvent: FlagUpdateType?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .success(let flags, let streamEvent) = result {
                                (newFlags, streamingEvent) = (flags.flagCollection, streamEvent)
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.providedEventHandler!.sendPut()
                    }
                }
                it("does not request flags and calls onSyncComplete with new flags and put event type") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(newFlags) == DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false)
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

                        testContext.providedEventHandler!.send(event: .put, string: DarklyServiceMock.Constants.jsonErrorString)
                    }
                }
                it("does not request flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    guard case .data(DarklyServiceMock.Constants.errorData) = syncError
                    else {
                        fail("Unexpected error for bad data: \(String(describing: syncError))")
                        return
                    }
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
                var streamingEvent: FlagUpdateType?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .success(let patch, let streamEvent) = result {
                                (flagDictionary, streamingEvent) = (patch, streamEvent)
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.providedEventHandler!.sendPatch()
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

                        testContext.providedEventHandler!.send(event: .patch, string: DarklyServiceMock.Constants.jsonErrorString)
                    }
                }
                it("does not request flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    guard case .data(DarklyServiceMock.Constants.errorData) = syncError
                    else {
                        fail("Unexpected error for bad data: \(String(describing: syncError))")
                        return
                    }
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
                var streamingEvent: FlagUpdateType?
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                            if case .success(let delete, let streamEvent) = result {
                                (flagDictionary, streamingEvent) = (delete, streamEvent)
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.providedEventHandler!.sendDelete()
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

                        testContext.providedEventHandler!.send(event: .delete, string: DarklyServiceMock.Constants.jsonErrorString)
                    }
                }
                it("does not request flags and calls onSyncComplete with a data error") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    guard case .data(DarklyServiceMock.Constants.errorData) = syncError
                    else {
                        fail("Unexpected error for bad data: \(String(describing: syncError))")
                        return
                    }
                }
            }
        }
    }

    func streamingOtherEventSpec() {
        var syncError: SynchronizingError?

        context("other events") {
            var testContext: TestContext!

            beforeEach {
                testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { _ in
                    testContext.onSyncCompleteCallCount += 1
                })
            }
            context("error event") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { syncResult in
                            if case .error(let errorResult) = syncResult {
                                syncError = errorResult
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.providedEventHandler!.sendServerError()
                    }
                }
                it("does not request flags & reports the error via onSyncComplete") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(syncError).toNot(beNil())
                    expect(syncError?.isClientUnauthorized).to(beFalse())
                    guard case .streamError = syncError
                    else {
                        fail("Expected stream error")
                        return
                    }
                }
                it("does not record stream init diagnostic") {
                    expect(testContext.diagnosticCacheMock.addStreamInitCallCount) == 0
                    expect(testContext.diagnosticCacheMock.addStreamInitReceivedStreamInit).to(beNil())
                }
            }
            context("eventSourceErrorHandler error event") {
                var returnedAction: ConnectionErrorAction!
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { syncResult in
                            if case .error(let errorResult) = syncResult {
                                syncError = errorResult
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true
                        returnedAction = testContext.providedErrorHandler!(UnsuccessfulResponseError(responseCode: 418))
                    }
                }
                it("does not request flags & reports the error via onSyncComplete") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(syncError).toNot(beNil())
                    expect(syncError?.isClientUnauthorized).to(beFalse())
                    guard case .streamError = syncError
                    else {
                        fail("Expected stream error")
                        return
                    }
                }
                it("does not record stream init diagnostic") {
                    expect(returnedAction) == .shutdown
                    expect(testContext.diagnosticCacheMock.addStreamInitCallCount) == 1
                    if let receivedStreamInit = testContext.diagnosticCacheMock.addStreamInitReceivedStreamInit {
                        expect(receivedStreamInit.timestamp) >= Date().millisSince1970 - 1_000
                        expect(receivedStreamInit.timestamp) <= Date().millisSince1970
                        expect(receivedStreamInit.durationMillis) <= 1_000
                        expect(receivedStreamInit.durationMillis) >= 0
                        expect(receivedStreamInit.failed) == true
                    } else {
                        fail("expected to receive stream init")
                    }
                }
            }
            context("unauthorized error event") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { syncResult in
                            if case .error(let errorResult) = syncResult {
                                syncError = errorResult
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.providedEventHandler!.sendUnauthorizedError()
                    }
                }
                it("does not request flags & reports the error via onSyncComplete") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true,
                                                           streamingMode: .streaming,
                                                           flagRequests: 0,
                                                           streamCreated: true,
                                                           streamOpened: true,
                                                           streamClosed: false) }).to(match())
                    expect(syncError).toNot(beNil())
                    expect(syncError?.isClientUnauthorized).to(beTrue())
                    guard case .streamError = syncError
                    else {
                        fail("Expected stream error")
                        return
                    }
                }
                it("does not record stream init diagnostic") {
                    expect(testContext.diagnosticCacheMock.addStreamInitCallCount) == 0
                    expect(testContext.diagnosticCacheMock.addStreamInitReceivedStreamInit).to(beNil())
                }
            }
            context("heartbeat") {
                beforeEach {
                    testContext.flagSynchronizer.isOnline = true

                    testContext.providedEventHandler!.onComment(comment: "")
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
                it("does not record stream init diagnostic") {
                    expect(testContext.diagnosticCacheMock.addStreamInitCallCount) == 0
                    expect(testContext.diagnosticCacheMock.addStreamInitReceivedStreamInit).to(beNil())
                }
            }
            context("comment") {
                beforeEach {
                    testContext.flagSynchronizer.isOnline = true

                    testContext.providedEventHandler!.onComment(comment: "foo")
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
                it("does not record stream init diagnostic") {
                    expect(testContext.diagnosticCacheMock.addStreamInitCallCount) == 0
                    expect(testContext.diagnosticCacheMock.addStreamInitReceivedStreamInit).to(beNil())
                }
            }
            context("open event") {
                beforeEach {
                    testContext.flagSynchronizer.isOnline = true

                    testContext.providedEventHandler!.onOpened()
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
                it("records stream init diagnostic") {
                    expect(testContext.diagnosticCacheMock.addStreamInitCallCount) == 1
                    if let receivedStreamInit = testContext.diagnosticCacheMock.addStreamInitReceivedStreamInit {
                        expect(receivedStreamInit.timestamp) >= Date().millisSince1970 - 1_000
                        expect(receivedStreamInit.timestamp) <= Date().millisSince1970
                        expect(receivedStreamInit.durationMillis) <= 1_000
                        expect(receivedStreamInit.durationMillis) >= 0
                        expect(receivedStreamInit.failed) == false
                    } else {
                        fail("expected to receive stream init")
                    }
                }
            }
            context("closed event") {
                beforeEach {
                    testContext.flagSynchronizer.isOnline = true

                    testContext.providedEventHandler!.onClosed()
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
                it("does not record stream init diagnostic") {
                    expect(testContext.diagnosticCacheMock.addStreamInitCallCount) == 0
                    expect(testContext.diagnosticCacheMock.addStreamInitReceivedStreamInit).to(beNil())
                }
            }
            context("non NSError event") {
                var syncErrorEvent: SynchronizingError?
                beforeEach {
                    waitUntil { done in
                    testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { syncResult in
                            if case .error(let errorResult) = syncResult {
                                syncErrorEvent = errorResult
                            }
                            done()
                        })
                        testContext.flagSynchronizer.isOnline = true

                        testContext.providedEventHandler!.sendNonResponseError()
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
                    expect(syncErrorEvent?.isClientUnauthorized).to(beFalse())
                    guard case .streamError = syncErrorEvent
                    else {
                        fail("Expected stream error")
                        return
                    }
                }
                it("does not record stream init diagnostic") {
                    expect(testContext.diagnosticCacheMock.addStreamInitCallCount) == 0
                    expect(testContext.diagnosticCacheMock.addStreamInitReceivedStreamInit).to(beNil())
                }
            }
        }
    }

    private func streamingProcessingSpec() {
        var testContext: TestContext!
        var syncError: SynchronizingError?

        context("event reported while offline") {
            beforeEach {
                let data = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false,
                                                                        includeVariations: true,
                                                                        includeVersions: true)
                            .dictionaryValue
                            .jsonString!
                waitUntil { done in
                    testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                        if case .error(let errorResult) = result {
                            syncError = errorResult
                        }
                        done()
                    })

                    testContext.flagSynchronizer.testStreamOnMessage(event: FlagUpdateType.put.rawValue,
                                                                     messageEvent: MessageEvent(data: data))
                }
            }
            it("reports offline") {
                guard case .isOffline = syncError
                else {
                    fail("Expected syncError to be .isOffline, was: \(String(describing: syncError))")
                    return
                }
            }
        }
        context("event reported while polling") {
            beforeEach {
                let data = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false,
                                                                        includeVariations: true,
                                                                        includeVersions: true)
                            .dictionaryValue
                            .jsonString!
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

                    testContext.flagSynchronizer.testStreamOnMessage(event: FlagUpdateType.put.rawValue,
                                                                     messageEvent: MessageEvent(data: data))
                }
            }
            afterEach {
                testContext.flagSynchronizer.isOnline = false
            }
            it("reports an event error") {
                guard case .streamEventWhilePolling = syncError
                else {
                    fail("Expected syncError to be .streamEventWhilePolling, was: \(String(describing: syncError))")
                    return
                }
            }
        }
        context("event reported while streaming inactive") {
            beforeEach {
                let data = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false,
                                                                        includeVariations: true,
                                                                        includeVersions: true)
                                                                            .dictionaryValue
                                                                            .jsonString!
                waitUntil { done in
                    testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                        if case .error(let errorResult) = result {
                            syncError = errorResult
                        }
                        done()
                    })
                    testContext.flagSynchronizer.isOnline = true
                    testContext.flagSynchronizer.testEventSource = nil
                    testContext.flagSynchronizer.testStreamOnMessage(event: FlagUpdateType.put.rawValue,
                                                                     messageEvent: MessageEvent(data: data))
                }
            }
            it("reports offline") {
                guard case .isOffline = syncError
                else {
                    fail("Expected syncError to be .isOffline, was: \(String(describing: syncError))")
                    return
                }
            }
        }
    }

    func pollingTimerFiresSpec() {
        describe("polling timer fires") {
            context("one second interval") {
                var testContext: TestContext!
                var newFlags: [String: FeatureFlag]?
                var streamingEvent: FlagUpdateType?
                beforeEach {
                    testContext = TestContext(streamingMode: .polling, useReport: false)
                    testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok)
                    testContext.flagSynchronizer.isOnline = true

                    waitUntil(timeout: 2) { done in
                        //In polling mode, the flagSynchronizer makes a flag request when set online right away. To verify the timer this test waits the polling interval (1s) for a second flag request
                        testContext.flagSynchronizer.onSyncComplete = { result in
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

                            testContext.providedEventHandler!.sendPing()
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

                                    testContext.providedEventHandler!.sendPing()
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

                                    testContext.providedEventHandler!.sendPing()
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

                            testContext.providedEventHandler!.sendPing()
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

                                    testContext.providedEventHandler!.sendPing()
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

                                    testContext.providedEventHandler!.sendPing()
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
                        testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
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
                    guard case .isOffline = synchronizingError
                    else {
                        fail("Expected syncError to be .isOffline, was: \(String(describing: synchronizingError))")
                        return
                    }
                }
            }
        }
    }
}
