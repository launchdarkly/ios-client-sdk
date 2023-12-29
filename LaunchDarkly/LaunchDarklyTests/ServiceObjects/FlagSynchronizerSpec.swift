import Foundation
import Quick
import Nimble
import LDSwiftEventSource
@testable import LaunchDarkly

final class FlagSynchronizerSpec: QuickSpec {
    struct Constants {
        fileprivate static let pollingInterval: TimeInterval = 1
    }

    struct TestContext {
        var serviceMock: DarklyServiceMock!
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
            serviceMock = DarklyServiceMock()
            diagnosticCacheMock = DiagnosticCachingMock()
            serviceMock.diagnosticCache = diagnosticCacheMock
            flagSynchronizer = FlagSynchronizer(streamingMode: streamingMode,
                                                pollingInterval: Constants.pollingInterval,
                                                useReport: useReport,
                                                service: serviceMock,
                                                onSyncComplete: onSyncComplete)
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
            it("starts up streaming offline using get flag requests") {
                let testContext = TestContext(streamingMode: .streaming, useReport: false)

                expect(testContext.flagSynchronizer.pollingInterval) == Constants.pollingInterval
                expect(testContext.flagSynchronizer.useReport) == false

                expect(testContext.flagSynchronizer.isOnline) == false
                expect(testContext.flagSynchronizer.streamingMode) == .streaming
                expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                expect(testContext.serviceMock.createEventSourceCallCount) == 0
            }
            it("starts up streaming offline using report flag requests") {
                let testContext = TestContext(streamingMode: .streaming, useReport: true)

                expect(testContext.flagSynchronizer.pollingInterval) == Constants.pollingInterval
                expect(testContext.flagSynchronizer.useReport) == true

                expect(testContext.flagSynchronizer.isOnline) == false
                expect(testContext.flagSynchronizer.streamingMode) == .streaming
                expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                expect(testContext.serviceMock.createEventSourceCallCount) == 0
            }
            it("starts up polling offline using get flag requests") {
                let testContext = TestContext(streamingMode: .polling, useReport: false)

                expect(testContext.flagSynchronizer.pollingInterval) == Constants.pollingInterval
                expect(testContext.flagSynchronizer.useReport) == false

                expect(testContext.flagSynchronizer.isOnline) == false
                expect(testContext.flagSynchronizer.streamingMode) == .polling
                expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                expect(testContext.serviceMock.createEventSourceCallCount) == 0
            }
            it("starts up polling offline using report flag requests") {
                let testContext = TestContext(streamingMode: .polling, useReport: true)

                expect(testContext.flagSynchronizer.pollingInterval) == Constants.pollingInterval
                expect(testContext.flagSynchronizer.useReport) == true

                expect(testContext.flagSynchronizer.isOnline) == false
                expect(testContext.flagSynchronizer.streamingMode) == .polling
                expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                expect(testContext.serviceMock.createEventSourceCallCount) == 0
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
                it("stops streaming") {
                    testContext.flagSynchronizer.isOnline = true
                    testContext.flagSynchronizer.isOnline = false

                    expect(testContext.flagSynchronizer.isOnline) == false
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 1
                }
                it("stops polling") {
                    testContext = TestContext(streamingMode: .polling, useReport: false)
                    testContext.flagSynchronizer.isOnline = true
                    testContext.flagSynchronizer.isOnline = false

                    expect(testContext.flagSynchronizer.isOnline) == false
                    expect(testContext.flagSynchronizer.streamingMode) == .polling
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 1
                    expect(testContext.serviceMock.createEventSourceCallCount) == 0
                }
            }
            context("offline to online") {
                it("starts streaming") {
                    testContext.flagSynchronizer.isOnline = true

                    // streaming expects a ping on successful connection that triggers a flag request. No ping means no flag requests
                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0
                }
                it("starts polling") {
                    testContext = TestContext(streamingMode: .polling, useReport: false)
                    testContext.flagSynchronizer.isOnline = true

                    // polling starts by requesting flags
                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .polling
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 1
                    expect(testContext.serviceMock.createEventSourceCallCount) == 0

                    testContext.flagSynchronizer.isOnline = false
                }
            }
            context("online to online") {
                it("does not stop streaming") {
                    testContext.flagSynchronizer.isOnline = true
                    testContext.flagSynchronizer.isOnline = true

                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0
                }
                it("does not stop polling") {
                    testContext = TestContext(streamingMode: .polling, useReport: false)
                    testContext.flagSynchronizer.isOnline = true
                    testContext.flagSynchronizer.isOnline = true

                    // setting the same value shouldn't make another flag request
                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .polling
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 1
                    expect(testContext.serviceMock.createEventSourceCallCount) == 0

                    testContext.flagSynchronizer.isOnline = false
                }
            }
            context("offline to offline") {
                it("does not start streaming") {
                    testContext.flagSynchronizer.isOnline = false
                    expect(testContext.flagSynchronizer.isOnline) == false
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 0
                }
                it("does not start polling") {
                    testContext = TestContext(streamingMode: .polling, useReport: false)
                    testContext.flagSynchronizer.isOnline = false

                    expect(testContext.flagSynchronizer.isOnline) == false
                    expect(testContext.flagSynchronizer.streamingMode) == .polling
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 0
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
        context("ping") {
            context("success") {
                var syncResult: FlagSyncResult?
                it("requests flags and calls onSyncComplete with the new flags and streaming event") {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false) { result in
                            syncResult = result
                            done()
                        }
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok)
                        testContext.flagSynchronizer.isOnline = true
                        testContext.providedEventHandler!.sendPing()
                    }

                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 1
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

                    guard case let .flagCollection((flagCollection, _)) = syncResult
                    else { return fail("Expected flag collection sync result") }
                    expect(flagCollection.flags) == DarklyServiceMock.Constants.stubFeatureFlags()
                }
            }
            context("bad data") {
                var synchronizingError: SynchronizingError?
                it("requests flags and calls onSyncComplete with a data error") {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false) { result in
                            if case let .error(syncError) = result {
                                synchronizingError = syncError
                            }
                            done()
                        }
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok, badData: true)
                        testContext.flagSynchronizer.isOnline = true

                        testContext.providedEventHandler!.sendPing()
                    }

                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 1
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

                    guard case .data(DarklyServiceMock.Constants.errorData) = synchronizingError
                    else {
                        return fail("Unexpected error for bad data: \(String(describing: synchronizingError))")
                    }
                }
            }
            context("failure response") {
                var urlResponse: URLResponse?
                it("requests flags and calls onSyncComplete with a response error") {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false) { result in
                            if case let .error(syncError) = result, case .response(let syncErrorResponse) = syncError {
                                urlResponse = syncErrorResponse
                            }
                            done()
                        }
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.internalServerError, responseOnly: true)
                        testContext.flagSynchronizer.isOnline = true

                        testContext.providedEventHandler!.sendPing()
                    }

                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 1
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

                    expect(urlResponse).toNot(beNil())
                    if let urlResponse = urlResponse {
                        expect(urlResponse.httpStatusCode) == HTTPURLResponse.StatusCodes.internalServerError
                    }
                }
            }
            context("failure error") {
                var synchronizingError: SynchronizingError?
                it("requests flags and calls onSyncComplete with a request error") {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false) { result in
                            if case let .error(syncError) = result {
                                synchronizingError = syncError
                            }
                            done()
                        }
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.internalServerError, errorOnly: true)
                        testContext.flagSynchronizer.isOnline = true

                        testContext.providedEventHandler!.sendPing()
                    }

                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 1
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

                    guard case let .request(error) = synchronizingError,
                          DarklyServiceMock.Constants.error == error as NSError
                    else {
                        return fail("Unexpected error for failure: \(String(describing: synchronizingError))")
                    }
                }
            }
        }
    }

    func streamingPutEventSpec() {
        var testContext: TestContext!
        var syncResult: FlagSyncResult?
        context("put") {
            context("success") {
                it("does not request flags and calls onSyncComplete with new flags and put event type") {
                    let putData = "{\"flagKey\": {\"value\": 123}}"
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false) {
                            syncResult = $0
                            done()
                        }
                        testContext.flagSynchronizer.isOnline = true
                        testContext.providedEventHandler!.send(event: "put", string: putData)
                    }

                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

                    guard case let .flagCollection((flagCollection, _)) = syncResult
                    else { return fail("Expected flag collection sync result") }
                    expect(flagCollection.flags.count) == 1
                    expect(flagCollection.flags["flagKey"]) == FeatureFlag(flagKey: "flagKey", value: 123)
                }
            }
            context("bad data") {
                it("does not request flags and calls onSyncComplete with a data error") {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false) {
                            syncResult = $0
                            done()
                        }
                        testContext.flagSynchronizer.isOnline = true
                        testContext.providedEventHandler!.send(event: "put", string: DarklyServiceMock.Constants.jsonErrorString)
                    }

                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

                    guard case .error(.data(DarklyServiceMock.Constants.errorData)) = syncResult
                    else {
                        return fail("Unexpected error for bad data: \(String(describing: syncResult))")
                    }
                }
            }
        }
    }

    func streamingPatchEventSpec() {
        var testContext: TestContext!
        var syncResult: FlagSyncResult?
        context("patch") {
            context("success") {
                it("does not request flags and calls onSyncComplete with new flags and put event type") {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false) {
                            syncResult = $0
                            done()
                        }
                        testContext.flagSynchronizer.isOnline = true

                        testContext.providedEventHandler!.send(event: "patch", string: "{\"key\": \"abc\"}")
                    }

                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

                    guard case let .patch(flag) = syncResult
                    else { return fail("Expected patch sync result") }
                    expect(flag.flagKey) == "abc"
                }
            }
            context("bad data") {
                var syncError: SynchronizingError?
                it("does not request flags and calls onSyncComplete with a data error") {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false) { result in
                            if case .error(let error) = result {
                                syncError = error
                            }
                            done()
                        }
                        testContext.flagSynchronizer.isOnline = true
                        testContext.providedEventHandler!.send(event: "patch", string: DarklyServiceMock.Constants.jsonErrorString)
                    }

                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

                    guard case .data(DarklyServiceMock.Constants.errorData) = syncError
                    else {
                        return fail("Unexpected error for bad data: \(String(describing: syncError))")
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
                var syncResult: FlagSyncResult?
                it("does not request flags and calls onSyncComplete with new flags and put event type") {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false) {
                            syncResult = $0
                            done()
                        }
                        testContext.flagSynchronizer.isOnline = true
                        let deleteData = "{\"key\": \"\(DarklyServiceMock.FlagKeys.int)\", \"version\": \(DarklyServiceMock.Constants.version + 1)}"
                        testContext.providedEventHandler!.send(event: "delete", string: deleteData)
                    }

                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

                    guard case let .delete(deleteResponse) = syncResult
                    else { return fail("expected delete dictionary sync result") }
                    expect(deleteResponse.key) == DarklyServiceMock.FlagKeys.int
                    expect(deleteResponse.version) == DarklyServiceMock.Constants.version + 1
                }
            }
            context("bad data") {
                var syncError: SynchronizingError?
                it("does not request flags and calls onSyncComplete with a data error") {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false) { result in
                            if case .error(let error) = result {
                                syncError = error
                            }
                            done()
                        }
                        testContext.flagSynchronizer.isOnline = true
                        testContext.providedEventHandler!.send(event: "delete", string: DarklyServiceMock.Constants.jsonErrorString)
                    }

                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

                    guard case .data(DarklyServiceMock.Constants.errorData) = syncError
                    else {
                        return fail("Unexpected error for bad data: \(String(describing: syncError))")
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
                testContext = TestContext(streamingMode: .streaming, useReport: false) { _ in
                    testContext.onSyncCompleteCallCount += 1
                }
            }
            context("error event") {
                beforeEach {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false) { syncResult in
                            if case .error(let errorResult) = syncResult {
                                syncError = errorResult
                            }
                            done()
                        }
                        testContext.flagSynchronizer.isOnline = true
                        testContext.providedEventHandler!.sendServerError()
                    }
                }
                it("does not request flags & reports the error via onSyncComplete") {
                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

                    expect(syncError).toNot(beNil())
                    expect(syncError?.isClientUnauthorized).to(beFalse())
                    guard case .streamError = syncError
                    else {
                        return fail("Expected stream error")
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
                        testContext = TestContext(streamingMode: .streaming, useReport: false) { syncResult in
                            if case .error(let errorResult) = syncResult {
                                syncError = errorResult
                            }
                            done()
                        }
                        testContext.flagSynchronizer.isOnline = true
                        returnedAction = testContext.providedErrorHandler!(UnsuccessfulResponseError(responseCode: 418))
                    }
                }
                it("does not request flags & reports the error via onSyncComplete") {
                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

                    expect(syncError).toNot(beNil())
                    expect(syncError?.isClientUnauthorized).to(beFalse())
                    guard case .streamError = syncError
                    else {
                        return fail("Expected stream error")
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
                        testContext = TestContext(streamingMode: .streaming, useReport: false) { syncResult in
                            if case .error(let errorResult) = syncResult {
                                syncError = errorResult
                            }
                            done()
                        }
                        testContext.flagSynchronizer.isOnline = true
                        testContext.providedEventHandler!.sendUnauthorizedError()
                    }
                }
                it("does not request flags & reports the error via onSyncComplete") {
                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

                    expect(syncError).toNot(beNil())
                    expect(syncError?.isClientUnauthorized).to(beTrue())
                    guard case .streamError = syncError
                    else {
                        return fail("Expected stream error")
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
                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

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
                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

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
                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

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
                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

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
                    testContext = TestContext(streamingMode: .streaming, useReport: false) { syncResult in
                            if case .error(let errorResult) = syncResult {
                                syncErrorEvent = errorResult
                            }
                            done()
                        }
                        testContext.flagSynchronizer.isOnline = true
                        testContext.providedEventHandler!.sendNonResponseError()
                    }
                }
                it("does not request flags & reports the error via onSyncComplete") {
                    expect(testContext.flagSynchronizer.isOnline) == true
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.startCallCount) == 1
                    expect(testContext.serviceMock.createdEventSource?.stopCallCount) == 0

                    expect(syncErrorEvent).toNot(beNil())
                    expect(syncErrorEvent?.isClientUnauthorized).to(beFalse())
                    guard case .streamError = syncErrorEvent
                    else {
                        return fail("Expected stream error")
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

        let data = "{\"flag1\": {}}"

        context("event reported while offline") {
            it("reports offline") {
                waitUntil { done in
                    testContext = TestContext(streamingMode: .streaming, useReport: false) { result in
                        if case .error(let errorResult) = result {
                            syncError = errorResult
                        }
                        done()
                    }
                    testContext.flagSynchronizer.testStreamOnMessage(event: "put", messageEvent: MessageEvent(data: data))
                }

                guard case .isOffline = syncError
                else {
                    return fail("Expected syncError to be .isOffline, was: \(String(describing: syncError))")
                }
            }
        }
        context("event reported while polling") {
            it("reports an event error") {
                waitUntil { done in
                    testContext = TestContext(streamingMode: .polling, useReport: false) { _ in done() }
                    testContext.flagSynchronizer.isOnline = true
                }
                waitUntil { done in
                    testContext.flagSynchronizer.onSyncComplete = { result in
                        if case .error(let errorResult) = result {
                            syncError = errorResult
                        }
                        done()
                    }

                    testContext.flagSynchronizer.testStreamOnMessage(event: "put", messageEvent: MessageEvent(data: data))
                }

                guard case .streamEventWhilePolling = syncError
                else {
                    return fail("Expected syncError to be .streamEventWhilePolling, was: \(String(describing: syncError))")
                }

                testContext.flagSynchronizer.isOnline = false
            }
        }
        context("event reported while streaming inactive") {
            it("reports offline") {
                waitUntil { done in
                    testContext = TestContext(streamingMode: .streaming, useReport: false) { result in
                        if case .error(let errorResult) = result {
                            syncError = errorResult
                        }
                        done()
                    }
                    testContext.flagSynchronizer.isOnline = true
                    testContext.flagSynchronizer.testEventSource = nil
                    testContext.flagSynchronizer.testStreamOnMessage(event: "put", messageEvent: MessageEvent(data: data))
                }

                guard case .isOffline = syncError
                else {
                    return fail("Expected syncError to be .isOffline, was: \(String(describing: syncError))")
                }
            }
        }
    }

    func pollingTimerFiresSpec() {
        var syncResult: FlagSyncResult?
        describe("polling timer fires") {
            context("one second interval") {
                var testContext: TestContext!
                beforeEach {
                    testContext = TestContext(streamingMode: .polling, useReport: false)
                    testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok)
                    testContext.flagSynchronizer.isOnline = true

                    waitUntil(timeout: .seconds(2)) { done in
                        // In polling mode, the flagSynchronizer makes a flag request when set online right away. To verify the timer this test waits the polling interval (1s) for a second flag request
                        testContext.flagSynchronizer.onSyncComplete = { result in
                            syncResult = result
                            done()
                        }
                    }
                }
                afterEach {
                    testContext.flagSynchronizer.isOnline = false
                }
                it("makes a flag request and calls onSyncComplete with no streaming event") {
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 2
                    guard case let .flagCollection((flagCollection, _)) = syncResult
                    else { return fail("Expected flag collection sync result") }
                    expect(flagCollection.flags) == DarklyServiceMock.Constants.stubFeatureFlags()
                }
                // This particular test causes a retain cycle between the FlagSynchronizer and something else. By removing onSyncComplete, the closure is no longer called after the test is complete.
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
                    it("requests flags using a get request exactly one time") {
                        waitUntil { done in
                            testContext = TestContext(streamingMode: .streaming, useReport: false) { _ in done() }
                            testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok)
                            testContext.flagSynchronizer.isOnline = true

                            testContext.providedEventHandler!.sendPing()
                        }

                        expect(testContext.serviceMock.getFeatureFlagsCallCount) == 1
                        expect(testContext.serviceMock.getFeatureFlagsUseReportCalledValue.first) == false
                    }
                }
                context("failure") {
                    context("with a non-retry status code") {
                        it("requests flags using a get request exactly one time") {
                            for statusCode in HTTPURLResponse.StatusCodes.nonRetry {
                                waitUntil { done in
                                    testContext = TestContext(streamingMode: .streaming, useReport: false) { _ in done() }
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
                                    testContext = TestContext(streamingMode: .streaming, useReport: false) { _ in done() }
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
                    it("requests flags using a get request exactly one time") {
                        waitUntil { done in
                            testContext = TestContext(streamingMode: .streaming, useReport: true) { _ in done() }
                            testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok)
                            testContext.flagSynchronizer.isOnline = true

                            testContext.providedEventHandler!.sendPing()
                        }

                        expect(testContext.serviceMock.getFeatureFlagsCallCount) == 1
                        expect(testContext.serviceMock.getFeatureFlagsUseReportCalledValue.first) == true
                    }
                }
                context("failure") {
                    context("with a non-retry status code") {
                        it("requests flags using a get request exactly one time") {
                            for statusCode in HTTPURLResponse.StatusCodes.nonRetry {
                                waitUntil { done in
                                    testContext = TestContext(streamingMode: .streaming, useReport: true) { _ in done() }
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
                                    testContext = TestContext(streamingMode: .streaming, useReport: true) { _ in done() }
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
            // This test completes the test suite on makeFlagRequest by validating the method bails out if it's called and the synchronizer is offline. While that shouldn't happen, there are 2 code paths that don't directly verify the SDK is online before calling the method, so it seems a wise precaution to validate that the method does bailout. Other tests exercise the rest of the method.
            context("offline") {
                var synchronizingError: SynchronizingError?
                it("does not request flags and calls onSyncComplete with an isOffline error") {
                    waitUntil { done in
                        testContext = TestContext(streamingMode: .streaming, useReport: false) { result in
                            if case .error(let syncError) = result {
                                synchronizingError = syncError
                            }
                            done()
                        }
                        testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok)

                        testContext.flagSynchronizer.testMakeFlagRequest()
                    }

                    expect(testContext.flagSynchronizer.isOnline) == false
                    expect(testContext.flagSynchronizer.streamingMode) == .streaming
                    expect(testContext.serviceMock.getFeatureFlagsCallCount) == 0
                    expect(testContext.serviceMock.createEventSourceCallCount) == 0

                    guard case .isOffline = synchronizingError
                    else {
                        return fail("Expected syncError to be .isOffline, was: \(String(describing: synchronizingError))")
                    }
                }
            }
        }
    }
}

extension DeleteResponse: Equatable {
    public static func == (lhs: DeleteResponse, rhs: DeleteResponse) -> Bool {
        lhs.key == rhs.key && lhs.version == rhs.version
    }
}
