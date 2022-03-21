import Foundation
import Quick
import Nimble
import XCTest
@testable import LaunchDarkly

final class EventReporterSpec: QuickSpec {
    struct Constants {
        static let eventFlushInterval: TimeInterval = 10.0
        static let eventFlushIntervalHalfSecond: TimeInterval = 0.5
        static let defaultValue: LDValue = false
    }

    struct TestContext {
        var eventReporter: EventReporter!
        var config: LDConfig!
        var user: LDUser!
        var serviceMock: DarklyServiceMock!
        var events: [Event] = []
        var lastEventResponseDate: Date?
        var flagKey: LDFlagKey!
        var featureFlag: FeatureFlag!
        var featureFlagWithReason: FeatureFlag!
        var featureFlagWithReasonAndTrackReason: FeatureFlag!
        var eventStubResponseDate: Date?
        var flagRequestTracker: FlagRequestTracker? { eventReporter.flagRequestTracker }
        var syncResult: SynchronizingError? = nil
        var diagnosticCache: DiagnosticCachingMock

        init(eventCount: Int = 0,
             eventFlushInterval: TimeInterval? = nil,
             lastEventResponseDate: Date? = nil,
             stubResponseSuccess: Bool = true,
             stubResponseOnly: Bool = false,
             stubResponseErrorOnly: Bool = false,
             eventStubResponseDate: Date? = nil,
             trackEvents: Bool? = true,
             debugEventsUntilDate: Date? = nil,
             onSyncComplete: EventSyncCompleteClosure? = nil) {

            config = LDConfig.stub
            config.eventCapacity = Event.Kind.allKinds.count
            config.eventFlushInterval = eventFlushInterval ?? Constants.eventFlushInterval

            user = LDUser.stub()

            self.eventStubResponseDate = eventStubResponseDate?.adjustedForHttpUrlHeaderUse
            serviceMock = DarklyServiceMock()
            serviceMock.config = config
            serviceMock.stubEventResponse(success: stubResponseSuccess, responseOnly: stubResponseOnly, errorOnly: stubResponseErrorOnly, responseDate: self.eventStubResponseDate)

            diagnosticCache = DiagnosticCachingMock()
            serviceMock.diagnosticCache = diagnosticCache

            self.lastEventResponseDate = lastEventResponseDate?.adjustedForHttpUrlHeaderUse
            eventReporter = EventReporter(service: serviceMock, onSyncComplete: onSyncComplete)
            (0..<eventCount).forEach {
                let event = Event.stub(Event.eventKind(for: $0), with: user!)
                events.append(event)
                eventReporter.record(event)
            }
            eventReporter.setLastEventResponseDate(self.lastEventResponseDate)

            flagKey = UUID().uuidString
            featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, trackEvents: trackEvents, debugEventsUntilDate: debugEventsUntilDate)
            featureFlagWithReason = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, trackEvents: trackEvents, debugEventsUntilDate: debugEventsUntilDate, includeEvaluationReason: true)
            featureFlagWithReasonAndTrackReason = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, trackEvents: trackEvents, debugEventsUntilDate: debugEventsUntilDate, includeEvaluationReason: true, includeTrackReason: true)
        }

        mutating func recordEvents(_ eventCount: Int) {
            for _ in 0..<eventCount {
                let event = Event.stub(Event.eventKind(for: events.count), with: user)
                events.append(event)
                eventReporter.record(event)
            }
        }

        func flagCounter(for key: LDFlagKey) -> FlagCounter? {
            flagRequestTracker?.flagCounters[key]
        }

        func flagValueCounter(for key: LDFlagKey, and featureFlag: FeatureFlag?) -> CounterValue? {
            flagCounter(for: key)?.flagValueCounters[CounterKey(variation: featureFlag?.variation, version: featureFlag?.versionForEvents)]
        }
    }

    override func spec() {
        initSpec()
        isOnlineSpec()
        recordEventSpec()
        recordFlagEvaluationEventsSpec()
        reportEventsSpec()
        reportTimerSpec()
    }

    private func initSpec() {
        describe("init") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
                testContext.eventReporter = EventReporter(service: testContext.serviceMock) { _ in }
            }
            it("starts offline without reporting events") {
                expect(testContext.eventReporter.service) === testContext.serviceMock
                expect(testContext.eventReporter.isOnline) == false
                expect(testContext.eventReporter.isReportingActive) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 0
            }
        }
    }

    private func isOnlineSpec() {
        describe("isOnline") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
            }
            afterEach {
                testContext.eventReporter.isOnline = false
            }
            context("online to offline") {
                beforeEach {
                    testContext.eventReporter.isOnline = true

                    testContext.eventReporter.isOnline = false
                }
                it("goes offline and stops reporting") {
                    expect(testContext.eventReporter.isOnline) == false
                    expect(testContext.eventReporter.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                }
            }
            context("offline to online") {
                context("with events") {
                    beforeEach {
                        testContext = TestContext(eventCount: Event.Kind.allKinds.count)

                        testContext.eventReporter.isOnline = true
                    }
                    it("goes online and starts reporting") {
                        expect(testContext.eventReporter.isOnline) == true
                        expect(testContext.eventReporter.isReportingActive) == true
                        expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    }
                }
                context("without events") {
                    beforeEach {
                        testContext = TestContext()

                        testContext.eventReporter.isOnline = true
                    }
                    it("goes online and starts reporting") {
                        expect(testContext.eventReporter.isOnline) == true
                        expect(testContext.eventReporter.isReportingActive) == true
                        expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    }
                }
            }
            context("online to online") {
                beforeEach {
                    testContext = TestContext()
                    testContext.eventReporter.isOnline = true

                    testContext.eventReporter.isOnline = true
                }
                it("stays online and continues reporting") {
                    expect(testContext.eventReporter.isOnline) == true
                    expect(testContext.eventReporter.isReportingActive) == true
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                }
            }
            context("offline to offline") {
                beforeEach {
                    testContext = TestContext(eventCount: Event.Kind.allKinds.count)

                    testContext.eventReporter.isOnline = false
                }
                it("stays offline and does not start reporting") {
                    expect(testContext.eventReporter.isOnline) == false
                    expect(testContext.eventReporter.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    expect(testContext.eventReporter.eventStore) == testContext.events
                }
            }
        }
    }

    private func recordEventSpec() {
        describe("recordEvent") {
            var testContext: TestContext!
            context("event store empty") {
                beforeEach {
                    testContext = TestContext()
                    testContext.recordEvents(Event.Kind.allKinds.count) // Stub events, call testContext.eventReporter.recordEvent, and keeps them in testContext.events
                }
                it("records events up to event capacity") {
                    expect(testContext.eventReporter.isOnline) == false
                    expect(testContext.eventReporter.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    expect(testContext.eventReporter.eventStore) == testContext.events
                }
                it("does not record a dropped event to diagnosticCache") {
                    expect(testContext.diagnosticCache.incrementDroppedEventCountCallCount) == 0
                }
            }
            context("event store full") {
                var extraEvent: Event!
                beforeEach {
                    testContext = TestContext(eventCount: Event.Kind.allKinds.count)
                    extraEvent = Event.stub(.feature, with: testContext.user)

                    testContext.eventReporter.record(extraEvent)
                }
                it("doesn't record any more events") {
                    expect(testContext.eventReporter.isOnline) == false
                    expect(testContext.eventReporter.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    expect(testContext.eventReporter.eventStore) == testContext.events
                }
                it("records a dropped event to diagnosticCache") {
                    expect(testContext.diagnosticCache.incrementDroppedEventCountCallCount) == 1
                }
            }
        }
    }

    private func reportEventsSpec() {
        describe("reportEvents") {
            var testContext: TestContext!
            var eventStubResponseDate: Date!
            beforeEach {
                eventStubResponseDate = Date().addingTimeInterval(-TimeInterval(3))
            }
            afterEach {
                testContext.eventReporter.isOnline = false
            }
            context("online") {
                context("success") {
                    context("with events and tracked requests") {
                        beforeEach {
                            waitUntil { syncComplete in
                                testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventReporter.isOnline = true
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                                testContext.eventReporter.setFlagRequestTracker(FlagRequestTracker.stub())
                                testContext.eventReporter.flush(completion: nil)
                            }
                        }
                        it("reports events and a summary event") {
                            expect(testContext.eventReporter.isOnline) == true
                            expect(testContext.eventReporter.isReportingActive) == true
                            expect(testContext.serviceMock.publishEventDataCallCount) == 1
                            let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                            valueIsArray(published) { valueArray in
                                expect(valueArray.count) == testContext.events.count + 1
                                expect(Array(valueArray.prefix(testContext.events.count))) == testContext.events.map { encodeToLDValue($0) }
                                valueIsObject(valueArray[testContext.events.count]) { summaryObject in
                                    expect(summaryObject["kind"]) == "summary"
                                }
                            }
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 1
                            expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch) == Event.Kind.nonSummaryKinds.count + 1
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
                            expect(testContext.eventReporter.lastEventResponseDate) == testContext.eventStubResponseDate
                            expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                            expect(testContext.syncResult).to(beNil())
                        }
                    }
                    context("with events only") {
                        beforeEach {
                            waitUntil { syncComplete in
                                testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventReporter.isOnline = true
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                                testContext.eventReporter.flush(completion: nil)
                            }
                        }
                        it("reports events without a summary event") {
                            expect(testContext.eventReporter.isOnline) == true
                            expect(testContext.eventReporter.isReportingActive) == true
                            expect(testContext.serviceMock.publishEventDataCallCount) == 1
                            let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                            expect(published) == encodeToLDValue(testContext.events)
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 1
                            expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch) == Event.Kind.nonSummaryKinds.count
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
                            expect(testContext.eventReporter.lastEventResponseDate) == testContext.eventStubResponseDate
                            expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                            expect(testContext.syncResult).to(beNil())
                        }
                    }
                    context("with tracked requests only") {
                        beforeEach {
                            waitUntil { syncComplete in
                                testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventReporter.isOnline = true
                                testContext.eventReporter.setFlagRequestTracker(FlagRequestTracker.stub())
                                testContext.eventReporter.flush(completion: nil)
                            }
                        }
                        it("reports only a summary event") {
                            expect(testContext.eventReporter.isOnline) == true
                            expect(testContext.eventReporter.isReportingActive) == true
                            expect(testContext.serviceMock.publishEventDataCallCount) == 1
                            let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                            valueIsArray(published) { valueArray in
                                expect(valueArray.count) == 1
                                valueIsObject(valueArray[0]) { summaryObject in
                                    expect(summaryObject["kind"]) == "summary"
                                }
                            }
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 1
                            expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch) == 1
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
                            expect(testContext.eventReporter.lastEventResponseDate) == testContext.eventStubResponseDate
                            expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                            expect(testContext.syncResult).to(beNil())
                        }
                    }
                    context("without events or tracked requests") {
                        beforeEach {
                            waitUntil { syncComplete in
                                testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventReporter.isOnline = true
                                testContext.eventReporter.flush(completion: nil)
                            }
                        }
                        it("does not report events") {
                            expect(testContext.eventReporter.isOnline) == true
                            expect(testContext.eventReporter.isReportingActive) == true
                            expect(testContext.serviceMock.publishEventDataCallCount) == 0
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 0
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
                            expect(testContext.eventReporter.lastEventResponseDate).to(beNil())
                            expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                            expect(testContext.syncResult).to(beNil())
                        }
                    }
                }
                context("failure") {
                    context("server error") {
                        beforeEach {
                            waitUntil(timeout: .seconds(10)) { syncComplete in
                                testContext = TestContext(stubResponseSuccess: false, eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventReporter.isOnline = true
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                                testContext.eventReporter.setFlagRequestTracker(FlagRequestTracker.stub())
                                testContext.eventReporter.flush(completion: nil)
                            }
                        }
                        it("drops events after the failure") {
                            expect(testContext.eventReporter.isOnline) == true
                            expect(testContext.eventReporter.isReportingActive) == true
                            expect(testContext.serviceMock.publishEventDataCallCount) == 2 // 1 retry attempt
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
                            let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                            valueIsArray(published) { valueArray in
                                expect(valueArray.count) == testContext.events.count + 1
                                expect(Array(valueArray.prefix(testContext.events.count))) == testContext.events.map { encodeToLDValue($0) }
                                valueIsObject(valueArray[testContext.events.count]) { summaryObject in
                                    expect(summaryObject["kind"]) == "summary"
                                }
                            }
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 1
                            expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch) == Event.Kind.nonSummaryKinds.count + 1
                            expect(testContext.eventReporter.lastEventResponseDate).to(beNil())
                            expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                            guard case let .request(error) = testContext.syncResult
                            else {
                                fail("Expected error result for event send")
                                return
                            }
                            expect(error as NSError?) == DarklyServiceMock.Constants.error
                        }
                    }
                    context("response only") {
                        beforeEach {
                            waitUntil(timeout: .seconds(10)) { syncComplete in
                                testContext = TestContext(stubResponseSuccess: false, stubResponseOnly: true, eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventReporter.isOnline = true
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                                testContext.eventReporter.setFlagRequestTracker(FlagRequestTracker.stub())
                                testContext.eventReporter.flush(completion: nil)
                            }
                        }
                        it("drops events after the failure") {
                            expect(testContext.eventReporter.isOnline) == true
                            expect(testContext.eventReporter.isReportingActive) == true
                            expect(testContext.serviceMock.publishEventDataCallCount) == 2 // 1 retry attempt
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
                            let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                            valueIsArray(published) { valueArray in
                                expect(valueArray.count) == testContext.events.count + 1
                                expect(Array(valueArray.prefix(testContext.events.count))) == testContext.events.map { encodeToLDValue($0) }
                                valueIsObject(valueArray[testContext.events.count]) { summaryObject in
                                    expect(summaryObject["kind"]) == "summary"
                                }
                            }
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 1
                            expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch) == Event.Kind.nonSummaryKinds.count + 1
                            expect(testContext.eventReporter.lastEventResponseDate).to(beNil())
                            expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                            let expectedError = testContext.serviceMock.errorEventHTTPURLResponse
                            guard case let .response(error) = testContext.syncResult
                            else {
                                fail("Expected error result for event send")
                                return
                            }
                            let httpError = error as? HTTPURLResponse
                            expect(httpError?.url) == expectedError?.url
                            expect(httpError?.statusCode) == expectedError?.statusCode
                        }
                    }
                    context("error only") {
                        beforeEach {
                            waitUntil(timeout: .seconds(10)) { syncComplete in
                                testContext = TestContext(stubResponseSuccess: false, stubResponseErrorOnly: true, eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventReporter.isOnline = true
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                                testContext.eventReporter.setFlagRequestTracker(FlagRequestTracker.stub())
                                testContext.eventReporter.flush(completion: nil)
                            }
                        }
                        it("drops events events after the failure") {
                            expect(testContext.eventReporter.isOnline) == true
                            expect(testContext.eventReporter.isReportingActive) == true
                            expect(testContext.serviceMock.publishEventDataCallCount) == 2 // 1 retry attempt
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
                            let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                            valueIsArray(published) { valueArray in
                                expect(valueArray.count) == testContext.events.count + 1
                                expect(Array(valueArray.prefix(testContext.events.count))) == testContext.events.map { encodeToLDValue($0) }
                                valueIsObject(valueArray[testContext.events.count]) { summaryObject in
                                    expect(summaryObject["kind"]) == "summary"
                                }
                            }
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 1
                            expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch) == Event.Kind.nonSummaryKinds.count + 1
                            expect(testContext.eventReporter.lastEventResponseDate).to(beNil())
                            expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                            guard case let .request(error) = testContext.syncResult
                            else {
                                fail("Expected error result for event send")
                                return
                            }
                            expect(error as NSError?) == DarklyServiceMock.Constants.error
                        }
                    }
                }
            }
            context("offline") {
                beforeEach {
                    waitUntil { syncComplete in
                        testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                            testContext.syncResult = result
                            syncComplete()
                        })
                        testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                        testContext.eventReporter.setFlagRequestTracker(FlagRequestTracker.stub())
                        testContext.eventReporter.flush(completion: nil)
                    }
                }
                it("doesn't report events") {
                    expect(testContext.eventReporter.isOnline) == false
                    expect(testContext.eventReporter.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 0
                    expect(testContext.eventReporter.eventStore) == testContext.events
                    expect(testContext.eventReporter.lastEventResponseDate).to(beNil())
                    expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == true
                    guard case .isOffline = testContext.syncResult
                    else {
                        fail("Expected error .isOffline result for event send")
                        return
                    }
                }
            }
        }
    }

    private func recordFlagEvaluationEventsSpec() {
        describe("recordFlagEvaluationEvents") {
            recordFeatureAndDebugEventsSpec()
            trackFlagRequestSpec()
        }
    }

    private func recordFeatureAndDebugEventsSpec() {
        var testContext: TestContext!
        let summarizesRequest = { it("summarizes the flag request") {
            let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
            expect(flagValueCounter?.value) == LDValue.fromAny(testContext.featureFlag.value)
            expect(flagValueCounter?.count) == 1
        }}
        context("record feature and debug events") {
            context("when trackEvents is on and a reason is present") {
                beforeEach {
                    testContext = TestContext(trackEvents: true)
                    testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                         value: LDValue.fromAny(testContext.featureFlag.value),
                                                                         defaultValue: Constants.defaultValue,
                                                                         featureFlag: testContext.featureFlagWithReason,
                                                                         user: testContext.user,
                                                                         includeReason: true)
                }
                it("records a feature event") {
                    expect(testContext.eventReporter.eventStore.count) == 1
                    expect((testContext.eventReporter.eventStore[0] as? FeatureEvent)?.kind) == .feature
                    expect((testContext.eventReporter.eventStore[0] as? FeatureEvent)?.key) == testContext.flagKey
                }
                summarizesRequest()
            }
            context("when a reason is present and reason is false but trackReason is true") {
                beforeEach {
                    testContext = TestContext(trackEvents: true)
                    testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                         value: LDValue.fromAny(testContext.featureFlag.value),
                                                                         defaultValue: Constants.defaultValue,
                                                                         featureFlag: testContext.featureFlagWithReasonAndTrackReason,
                                                                         user: testContext.user,
                                                                         includeReason: false)
                }
                it("records a feature event") {
                    expect(testContext.eventReporter.eventStore.count) == 1
                    expect((testContext.eventReporter.eventStore[0] as? FeatureEvent)?.kind) == .feature
                    expect((testContext.eventReporter.eventStore[0] as? FeatureEvent)?.key) == testContext.flagKey
                }
                summarizesRequest()
            }
            context("when trackEvents is off") {
                beforeEach {
                    testContext = TestContext(trackEvents: false)
                    testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                         value: LDValue.fromAny(testContext.featureFlag.value),
                                                                         defaultValue: Constants.defaultValue,
                                                                         featureFlag: testContext.featureFlag,
                                                                         user: testContext.user,
                                                                         includeReason: false)
                }
                it("does not record a feature event") {
                    expect(testContext.eventReporter.eventStore).to(beEmpty())
                }
                summarizesRequest()
            }
            context("when debugEventsUntilDate exists") {
                context("lastEventResponseDate exists") {
                    context("and debugEventsUntilDate is later") {
                        beforeEach {
                            testContext = TestContext(lastEventResponseDate: Date(), trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(TimeInterval.oneSecond))
                            testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                                 value: LDValue.fromAny(testContext.featureFlag.value),
                                                                                 defaultValue: Constants.defaultValue,
                                                                                 featureFlag: testContext.featureFlag,
                                                                                 user: testContext.user,
                                                                                 includeReason: false)
                        }
                        it("records a debug event") {
                            expect(testContext.eventReporter.eventStore.count) == 1
                            expect((testContext.eventReporter.eventStore[0] as? FeatureEvent)?.kind) == .debug
                            expect((testContext.eventReporter.eventStore[0] as? FeatureEvent)?.key) == testContext.flagKey
                        }
                        it("tracks the flag request") {
                            let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                            expect(flagValueCounter?.value) == LDValue.fromAny(testContext.featureFlag.value)
                            expect(flagValueCounter?.count) == 1
                        }
                    }
                    context("and debugEventsUntilDate is earlier") {
                        beforeEach {
                            testContext = TestContext(lastEventResponseDate: Date(), trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(-TimeInterval.oneSecond))
                            testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                                 value: LDValue.fromAny(testContext.featureFlag.value),
                                                                                 defaultValue: Constants.defaultValue,
                                                                                 featureFlag: testContext.featureFlag,
                                                                                 user: testContext.user,
                                                                                 includeReason: false)
                        }
                        it("does not record a debug event") {
                            expect(testContext.eventReporter.eventStore).to(beEmpty())
                        }
                        summarizesRequest()
                    }
                }
                context("lastEventResponseDate is nil") {
                    context("and debugEventsUntilDate is later than current time") {
                        beforeEach {
                            testContext = TestContext(lastEventResponseDate: nil, trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(TimeInterval.oneSecond))
                            testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                                 value: LDValue.fromAny(testContext.featureFlag.value),
                                                                                 defaultValue: Constants.defaultValue,
                                                                                 featureFlag: testContext.featureFlag,
                                                                                 user: testContext.user,
                                                                                 includeReason: false)
                        }
                        it("records a debug event") {
                            expect(testContext.eventReporter.eventStore.count) == 1
                            expect((testContext.eventReporter.eventStore[0] as? FeatureEvent)?.kind) == .debug
                            expect((testContext.eventReporter.eventStore[0] as? FeatureEvent)?.key) == testContext.flagKey
                        }
                        summarizesRequest()
                    }
                    context("and debugEventsUntilDate is earlier than current time") {
                        beforeEach {
                            testContext = TestContext(lastEventResponseDate: nil, trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(-TimeInterval.oneSecond))
                            testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                                 value: LDValue.fromAny(testContext.featureFlag.value),
                                                                                 defaultValue: Constants.defaultValue,
                                                                                 featureFlag: testContext.featureFlag,
                                                                                 user: testContext.user,
                                                                                 includeReason: false)
                        }
                        it("does not record a debug event") {
                            expect(testContext.eventReporter.eventStore).to(beEmpty())
                        }
                        summarizesRequest()
                    }
                }
            }
            context("when both trackEvents is true and debugEventsUntilDate is later than lastEventResponseDate") {
                beforeEach {
                    testContext = TestContext(lastEventResponseDate: Date(), trackEvents: true, debugEventsUntilDate: Date().addingTimeInterval(TimeInterval.oneSecond))
                    testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                         value: LDValue.fromAny(testContext.featureFlag.value),
                                                                         defaultValue: Constants.defaultValue,
                                                                         featureFlag: testContext.featureFlag,
                                                                         user: testContext.user,
                                                                         includeReason: false)
                }
                it("records a feature and debug event") {
                    expect(testContext.eventReporter.eventStore.count == 2).to(beTrue())
                    let features = testContext.eventReporter.eventStore.compactMap { $0 as? FeatureEvent }
                    expect(features.allSatisfy { $0.key == testContext.flagKey }).to(beTrue())
                    expect(features.map { $0.kind }).to(contain([.feature, .debug]))
                }
                summarizesRequest()
            }
            context("when both trackEvents is true, debugEventsUntilDate is later than lastEventResponseDate, reason is false, and track reason is true") {
                beforeEach {
                    testContext = TestContext(lastEventResponseDate: Date(), trackEvents: true, debugEventsUntilDate: Date().addingTimeInterval(TimeInterval.oneSecond))
                    testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                         value: LDValue.fromAny(testContext.featureFlag.value),
                                                                         defaultValue: Constants.defaultValue,
                                                                         featureFlag: testContext.featureFlagWithReasonAndTrackReason,
                                                                         user: testContext.user,
                                                                         includeReason: false)
                }
                it("records a feature and debug event") {
                    expect(testContext.eventReporter.eventStore.count == 2).to(beTrue())
                    let features = testContext.eventReporter.eventStore.compactMap { $0 as? FeatureEvent }
                    expect(features.allSatisfy { $0.key == testContext.flagKey }).to(beTrue())
                    expect(features.map { $0.kind }).to(contain([.feature, .debug]))
                }
                summarizesRequest()
            }
            context("when debugEventsUntilDate is nil") {
                beforeEach {
                    testContext = TestContext(lastEventResponseDate: Date(), trackEvents: false, debugEventsUntilDate: nil)
                    testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                         value: LDValue.fromAny(testContext.featureFlag.value),
                                                                         defaultValue: Constants.defaultValue,
                                                                         featureFlag: testContext.featureFlag,
                                                                         user: testContext.user,
                                                                         includeReason: false)
                }
                it("does not record an event") {
                    expect(testContext.eventReporter.eventStore).to(beEmpty())
                }
                summarizesRequest()
            }
            context("when eventTrackingContext is nil") {
                beforeEach {
                    testContext = TestContext(trackEvents: nil)
                    testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                         value: LDValue.fromAny(testContext.featureFlag.value),
                                                                         defaultValue: Constants.defaultValue,
                                                                         featureFlag: testContext.featureFlag,
                                                                         user: testContext.user,
                                                                         includeReason: false)
                }
                it("does not record an event") {
                    expect(testContext.eventReporter.eventStore).to(beEmpty())
                }
                summarizesRequest()
            }
            context("when multiple flag requests are made") {
                context("serially") {
                    beforeEach {
                        testContext = TestContext(trackEvents: false)
                        for _ in 1...3 {
                            testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                                 value: LDValue.fromAny(testContext.featureFlag.value),
                                                                                 defaultValue: Constants.defaultValue,
                                                                                 featureFlag: testContext.featureFlag,
                                                                                 user: testContext.user,
                                                                                 includeReason: false)
                        }
                    }
                    it("tracks the flag request") {
                        let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                        expect(flagValueCounter?.value) == LDValue.fromAny(testContext.featureFlag.value)
                        expect(flagValueCounter?.count) == 3
                    }
                }
                context("concurrently") {
                    let requestQueue = DispatchQueue(label: "com.launchdarkly.test.eventReporterSpec.flagRequestTracking.concurrent", qos: .userInitiated, attributes: .concurrent)
                    var recordFlagEvaluationCompletionCallCount = 0
                    var recordFlagEvaluationCompletion: (() -> Void)!
                    beforeEach {
                        testContext = TestContext(trackEvents: false)

                        waitUntil { done in
                            recordFlagEvaluationCompletion = {
                                DispatchQueue.main.async {
                                    recordFlagEvaluationCompletionCallCount += 1
                                    if recordFlagEvaluationCompletionCallCount == 5 {
                                        done()
                                    }
                                }
                            }
                            let fireTime = DispatchTime.now() + 0.1
                            for _ in 1...5 {
                                requestQueue.asyncAfter(deadline: fireTime) {
                                    testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                                         value: LDValue.fromAny(testContext.featureFlag.value),
                                                                                         defaultValue: Constants.defaultValue,
                                                                                         featureFlag: testContext.featureFlag,
                                                                                         user: testContext.user,
                                                                                         includeReason: false)
                                    recordFlagEvaluationCompletion()
                                }
                            }
                        }
                    }
                    it("tracks the flag request") {
                        let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                        expect(flagValueCounter?.value) == LDValue.fromAny(testContext.featureFlag.value)
                        expect(flagValueCounter?.count) == 5
                    }
                }
            }
        }
    }

    private func trackFlagRequestSpec() {
        context("record summary event") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
                testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                     value: LDValue.fromAny(testContext.featureFlag.value),
                                                                     defaultValue: LDValue.fromAny(testContext.featureFlag.value),
                                                                     featureFlag: testContext.featureFlag,
                                                                     user: testContext.user,
                                                                     includeReason: false)
            }
            it("tracks flag requests") {
                let flagCounter = testContext.flagCounter(for: testContext.flagKey)
                expect(flagCounter?.defaultValue) == LDValue.fromAny(testContext.featureFlag.value)
                expect(flagCounter?.flagValueCounters.count) == 1

                let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                expect(flagValueCounter?.value) == LDValue.fromAny(testContext.featureFlag.value)
                expect(flagValueCounter?.count) == 1
            }
        }
    }

    private func reportTimerSpec() {
        describe("report timer fires") {
            var testContext: TestContext!
            afterEach {
                testContext.eventReporter.isOnline = false
            }
            context("with events") {
                beforeEach {
                    testContext = TestContext(eventFlushInterval: Constants.eventFlushIntervalHalfSecond)
                    testContext.eventReporter.isOnline = true
                    testContext.recordEvents(Event.Kind.allKinds.count)
                }
                it("reports events") {
                    expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1))
                    expect(testContext.eventReporter.eventStore.isEmpty).toEventually(beTrue())
                    expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount).toEventually(equal(1))
                    expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch).toEventually(equal(testContext.events.count))
                    let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                    valueIsArray(published) { valueArray in
                        expect(valueArray.count) == testContext.events.count
                        expect(valueArray) == testContext.events.map { encodeToLDValue($0) }
                    }
                }
            }
            context("without events") {
                beforeEach {
                    testContext = TestContext(eventFlushInterval: Constants.eventFlushIntervalHalfSecond)
                    testContext.eventReporter.isOnline = true
                }
                it("doesn't report events") {
                    waitUntil { done in
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Constants.eventFlushIntervalHalfSecond) {
                            expect(testContext.serviceMock.publishEventDataCallCount) == 0
                            done()
                        }
                    }
                }
            }
        }
    }
}

extension EventReporter {
    var eventStoreKinds: [Event.Kind] { eventStore.compactMap { $0.kind } }
}

extension TimeInterval {
    static let oneSecond: TimeInterval = 1.0
}

private extension Date {
    var adjustedForHttpUrlHeaderUse: Date {
        let headerDateFormatter = DateFormatter.httpUrlHeaderFormatter
        let dateString = headerDateFormatter.string(from: self)
        return headerDateFormatter.date(from: dateString) ?? self
    }
}

extension Event.Kind {
    static var nonSummaryKinds: [Event.Kind] {
        [feature, debug, identify, custom]
    }
}
