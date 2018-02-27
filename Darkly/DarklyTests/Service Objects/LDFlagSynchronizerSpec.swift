//
//  LDFlagSynchronizerSpec.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 9/20/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
import DarklyEventSource
@testable import Darkly

final class LDFlagSynchronizerSpec: QuickSpec {
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
        var subject: LDFlagSynchronizer!

        init(streamingMode: LDStreamingMode, useReport: Bool, onSyncComplete: SyncCompleteClosure? = nil) {
            config = LDConfig.stub
            user = LDUser.stub()
            serviceMock = DarklyServiceMock()
            subject = LDFlagSynchronizer(streamingMode: streamingMode, pollingInterval: Constants.pollingInterval, useReport: useReport, service: serviceMock, onSyncComplete: onSyncComplete)
        }

        private func isStreamingActive(online: Bool, streamingMode: LDStreamingMode) -> Bool { return online && (streamingMode == .streaming) }
        private func isPollingActive(online: Bool, streamingMode: LDStreamingMode) -> Bool { return online && (streamingMode == .polling) }

        fileprivate func synchronizerState(synchronizerOnline isOnline: Bool, streamingMode: LDStreamingMode, flagRequests: Int, streamCreated: Bool, streamClosed: Bool? = nil) -> ToMatchResult {
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
                if let eventSource = serviceMock.createdEventSource {
                    if let streamClosed = streamClosed {
                        if eventSource.closeCallCount != (streamClosed ? 1 : 0) { messages.append("stream closed call count equals \(eventSource.closeCallCount)") }
                    }
                } else {
                    messages.append("event stream not created")
                }
            case false:
                if serviceMock.createdEventSource != nil { messages.append("mock service created event source is not nil") }
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
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext(streamingMode: .streaming, useReport: false)
        }
        describe("init") {
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
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext(streamingMode: .streaming, useReport: false)
        }

        describe("change isOnline") {
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
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext(streamingMode: .streaming, useReport: false)
        }

        describe("streaming events") {
            context("ping") {
                context("success") {
                    var newFlags: [String: FeatureFlag]?
                    beforeEach {
                        waitUntil { done in
                            testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { result in
                                if case .success(let flags, _) = result { newFlags = flags.flagCollection }
                                done()
                            })
                            testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok)
                            testContext.subject.isOnline = true

                            testContext.serviceMock.createdEventSource?.sendPing()
                        }
                    }
                    it("requests flags & calls the onSync closure with the new flags") {
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
                        expect(newFlags == DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true)).to(beTrue())
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

                            testContext.serviceMock.createdEventSource?.sendPing()
                        }
                    }
                    it("requests flags, does not update flag store, and calls the onError closure with a data error") {
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
                        expect(synchronizingError == .data(DarklyServiceMock.Constants.errorData)).to(beTrue())
                        expect(testContext.flagStoreMock.replaceStoreCallCount) == 0
                        expect(testContext.flagStoreMock.replaceStoreReceivedArguments?.newFlags).to(beNil())
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

                            testContext.serviceMock.createdEventSource?.sendPing()
                        }
                    }
                    it("requests flags & does not update flag store") {
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
                        expect(urlResponse).toNot(beNil())
                        if let urlResponse = urlResponse {
                            expect(urlResponse.httpStatusCode) == HTTPURLResponse.StatusCodes.internalServerError
                        }
                        expect(testContext.flagStoreMock.replaceStoreCallCount) == 0
                        expect(testContext.flagStoreMock.replaceStoreReceivedArguments?.newFlags).to(beNil())
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

                            testContext.serviceMock.createdEventSource?.sendPing()
                        }
                    }
                    it("requests flags & does not update flag store") {
                        expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 1, streamCreated: true, streamClosed: false) }).to(match())
                        expect(synchronizingError == .request(DarklyServiceMock.Constants.error)).to(beTrue())
                        expect(testContext.flagStoreMock.replaceStoreCallCount) == 0
                        expect(testContext.flagStoreMock.replaceStoreReceivedArguments?.newFlags).to(beNil())
                    }
                }
            }
            context("heartbeat") {
                beforeEach {
                    testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok, useReport: false)
                    testContext.subject.isOnline = true

                    testContext.serviceMock.createdEventSource?.sendHeartbeat()
                }
                it("does not request flags") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                }
            }
            context("null event") {
                beforeEach {
                    testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok, useReport: false)
                    testContext.subject.isOnline = true

                    testContext.serviceMock.createdEventSource?.sendNullEvent()
                }
                it("does not request flags") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                }
            }
            context("open event") {
                beforeEach {
                    testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok, useReport: false)
                    testContext.subject.isOnline = true

                    testContext.serviceMock.createdEventSource?.sendOpenEvent()
                }
                it("does not request flags") {
                    expect({ testContext.synchronizerState(synchronizerOnline: true, streamingMode: .streaming, flagRequests: 0, streamCreated: true, streamClosed: false) }).to(match())
                }
            }
        }
    }

    func pollingTimerFiresSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext(streamingMode: .streaming, useReport: false)
        }

        describe("polling timer fires") {
            beforeEach {
                testContext = TestContext(streamingMode: .polling, useReport: false)
                testContext.subject.isOnline = true
            }
            it("makes a flag request") {
                expect(testContext.serviceMock.getFeatureFlagsCallCount).toEventually(equal(2), timeout: 2)
            }
        }
    }

    func flagRequestSpec() {
        var testContext: TestContext!

        describe("flag request") {
            context("using get method") {
                context("success") {
                    beforeEach {
                        waitUntil { done in
                            testContext = TestContext(streamingMode: .streaming, useReport: false, onSyncComplete: { _ in
                                done()
                            })
                            testContext.serviceMock.stubFlagResponse(statusCode: HTTPURLResponse.StatusCodes.ok)
                            testContext.subject.isOnline = true

                            testContext.serviceMock.createdEventSource?.sendPing()
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

                                    testContext.serviceMock.createdEventSource?.sendPing()
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

                                    testContext.serviceMock.createdEventSource?.sendPing()
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

                            testContext.serviceMock.createdEventSource?.sendPing()
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

                                    testContext.serviceMock.createdEventSource?.sendPing()
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

                                    testContext.serviceMock.createdEventSource?.sendPing()
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
