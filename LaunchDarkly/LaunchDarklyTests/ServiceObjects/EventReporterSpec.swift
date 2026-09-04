import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class EventReporterSpec: QuickSpec {
    struct Constants {
        static let eventFlushInterval: TimeInterval = 10.0
        static let eventFlushIntervalHalfSecond: TimeInterval = 0.5
    }

    struct TestContext {
        var eventReporter: EventReporter!
        var config: LDConfig!
        var context: LDContext!
        var serviceMock: DarklyServiceMock!
        var store: EventStore!
        var events: [Event] = []
        var lastEventResponseDate: Date
        var eventStubResponseDate: Date?
        var syncResult: SynchronizingError? = nil
        var diagnosticCache: DiagnosticCachingMock

        init(eventCount: Int = 0,
             eventFlushInterval: TimeInterval? = nil,
             lastEventResponseDate: Date = Date.distantPast,
             stubResponseSuccess: Bool = true,
             stubResponseOnly: Bool = false,
             stubResponseErrorOnly: Bool = false,
             eventStubResponseDate: Date? = nil,
             onSyncComplete: EventSyncCompleteClosure? = nil,
             store: EventStore? = nil) {

            config = LDConfig.stub
            config.eventCapacity = Event.Kind.allKinds.count
            config.eventFlushInterval = eventFlushInterval ?? Constants.eventFlushInterval

            context = LDContext.stub()

            self.eventStubResponseDate = eventStubResponseDate?.adjustedForHttpUrlHeaderUse
            serviceMock = DarklyServiceMock()
            serviceMock.config = config
            serviceMock.stubEventResponse(success: stubResponseSuccess, responseOnly: stubResponseOnly, errorOnly: stubResponseErrorOnly, responseDate: self.eventStubResponseDate)

            diagnosticCache = DiagnosticCachingMock()
            serviceMock.diagnosticCache = diagnosticCache

            self.lastEventResponseDate = lastEventResponseDate.adjustedForHttpUrlHeaderUse
            self.store = store ?? EventStore.temporary(capacity: config.eventCapacity)
            eventReporter = EventReporter(service: serviceMock, onSyncComplete: onSyncComplete, store: self.store)
            (0..<eventCount).forEach {
                let event = Event.stub(Event.eventKind(for: $0), with: context!)
                events.append(event)
                eventReporter.record(event)
            }
            eventReporter.setLastEventResponseDate(self.lastEventResponseDate)
        }

        mutating func recordEvents(_ eventCount: Int) {
            for _ in 0..<eventCount {
                let event = Event.stub(Event.eventKind(for: events.count), with: context)
                events.append(event)
                eventReporter.record(event)
            }
        }

        /// The events the reporter is holding on disk, as the JSON it would send.
        ///
        /// Recorded events are serialized on the way in rather than kept as objects, so what the reporter is holding is
        /// asserted against the wire format the events encode to.
        func pendingEvents() -> [LDValue] {
            store.pendingEventPayloads().compactMap { try? JSONDecoder().decode(LDValue.self, from: $0) }
        }

        /// The events recorded so far, in the JSON they encode to, for comparison with `pendingEvents()`.
        func recordedEventsAsJSON() -> [LDValue] {
            events.compactMap { encodeToLDValue($0) }
        }

        func cleanUp() {
            eventReporter.isOnline = false
            store.deleteEverything()
        }
    }

    override func spec() {
        initSpec()
        isOnlineSpec()
        recordEventSpec()
        testRecordFlagEvaluationEvents()
        reportEventsSpec()
        reportTimerSpec()
        durabilitySpec()
    }

    private func initSpec() {
        describe("init") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
                testContext.eventReporter = EventReporter(service: testContext.serviceMock, onSyncComplete: { _ in }, store: testContext.store)
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
                testContext.cleanUp()
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
                    expect(testContext.pendingEvents()) == testContext.recordedEventsAsJSON()
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
                    expect(testContext.pendingEvents()) == testContext.recordedEventsAsJSON()
                }
                it("does not record a dropped event to diagnosticCache") {
                    expect(testContext.diagnosticCache.incrementDroppedEventCountCallCount) == 0
                }
            }
            context("event store full") {
                var extraEvent: Event!
                beforeEach {
                    testContext = TestContext(eventCount: Event.Kind.allKinds.count)
                    extraEvent = Event.stub(.feature, with: testContext.context)

                    testContext.eventReporter.record(extraEvent)
                }
                it("doesn't record any more events") {
                    expect(testContext.eventReporter.isOnline) == false
                    expect(testContext.eventReporter.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    expect(testContext.pendingEvents()) == testContext.recordedEventsAsJSON()
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
                testContext.cleanUp()
            }
            let erOnline = {
                expect(testContext.eventReporter.isOnline) == true
                expect(testContext.eventReporter.isReportingActive) == true
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
                                // Track some flag evaluations to populate the contextSummarizer
                                testContext.eventReporter.recordFlagEvaluationEvents(
                                    flagKey: "test-flag",
                                    value: .bool(true),
                                    defaultValue: .bool(false),
                                    featureFlag: nil,
                                    context: testContext.context,
                                    includeReason: false
                                )
                                testContext.eventReporter.flush(completion: nil)
                            }
                        }
                        it("reports events and a summary event") {
                            erOnline()
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
                            expect(testContext.store.pendingEventCount) == 0
                            expect(testContext.eventReporter.lastEventResponseDate) == testContext.eventStubResponseDate
                            expect(testContext.eventReporter.contextSummarizer.hasLoggedRequests) == false
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
                            erOnline()
                            expect(testContext.serviceMock.publishEventDataCallCount) == 1
                            let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                            expect(published) == encodeToLDValue(testContext.events)
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 1
                            expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch) == testContext.events.count
                            expect(testContext.store.pendingEventCount) == 0
                            expect(testContext.eventReporter.lastEventResponseDate) == testContext.eventStubResponseDate
                            expect(testContext.eventReporter.contextSummarizer.hasLoggedRequests) == false
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
                                // Track some flag evaluations to populate the contextSummarizer
                                testContext.eventReporter.recordFlagEvaluationEvents(
                                    flagKey: "test-flag",
                                    value: .bool(true),
                                    defaultValue: .bool(false),
                                    featureFlag: nil,
                                    context: testContext.context,
                                    includeReason: false
                                )
                                testContext.eventReporter.flush(completion: nil)
                            }
                        }
                        it("reports only a summary event") {
                            erOnline()
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
                            expect(testContext.store.pendingEventCount) == 0
                            expect(testContext.eventReporter.lastEventResponseDate) == testContext.eventStubResponseDate
                            expect(testContext.eventReporter.contextSummarizer.hasLoggedRequests) == false
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
                            erOnline()
                            expect(testContext.serviceMock.publishEventDataCallCount) == 0
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 0
                            expect(testContext.store.pendingEventCount) == 0
                            expect(testContext.eventReporter.lastEventResponseDate) == Date.distantPast
                            expect(testContext.eventReporter.contextSummarizer.hasLoggedRequests) == false
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
                                // Track some flag evaluations to populate the contextSummarizer
                                testContext.eventReporter.recordFlagEvaluationEvents(
                                    flagKey: "test-flag",
                                    value: .bool(true),
                                    defaultValue: .bool(false),
                                    featureFlag: nil,
                                    context: testContext.context,
                                    includeReason: false
                                )
                                testContext.eventReporter.flush(completion: nil)
                            }
                        }
                        it("keeps the events to retry after the failure") {
                            erOnline()
                            expect(testContext.serviceMock.publishEventDataCallCount) == 2 // 1 retry attempt
                            // The events are not lost by a failed delivery; they stay in the log, summary included.
                            expect(testContext.store.pendingEventCount) == testContext.events.count + 1
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
                            expect(testContext.eventReporter.lastEventResponseDate) == Date.distantPast
                            expect(testContext.eventReporter.contextSummarizer.hasLoggedRequests) == false
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
                                // Track some flag evaluations to populate the contextSummarizer
                                testContext.eventReporter.recordFlagEvaluationEvents(
                                    flagKey: "test-flag",
                                    value: .bool(true),
                                    defaultValue: .bool(false),
                                    featureFlag: nil,
                                    context: testContext.context,
                                    includeReason: false
                                )
                                testContext.eventReporter.flush(completion: nil)
                            }
                        }
                        it("keeps the events to retry after the failure") {
                            erOnline()
                            expect(testContext.serviceMock.publishEventDataCallCount) == 2 // 1 retry attempt
                            // The events are not lost by a failed delivery; they stay in the log, summary included.
                            expect(testContext.store.pendingEventCount) == testContext.events.count + 1
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
                            expect(testContext.eventReporter.lastEventResponseDate) == Date.distantPast
                            expect(testContext.eventReporter.contextSummarizer.hasLoggedRequests) == false
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
                                // Track some flag evaluations to populate the contextSummarizer
                                testContext.eventReporter.recordFlagEvaluationEvents(
                                    flagKey: "test-flag",
                                    value: .bool(true),
                                    defaultValue: .bool(false),
                                    featureFlag: nil,
                                    context: testContext.context,
                                    includeReason: false
                                )
                                testContext.eventReporter.flush(completion: nil)
                            }
                        }
                        it("keeps the events to retry after the failure") {
                            erOnline()
                            expect(testContext.serviceMock.publishEventDataCallCount) == 2 // 1 retry attempt
                            // The events are not lost by a failed delivery; they stay in the log, summary included.
                            expect(testContext.store.pendingEventCount) == testContext.events.count + 1
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
                            expect(testContext.eventReporter.lastEventResponseDate) == Date.distantPast
                            expect(testContext.eventReporter.contextSummarizer.hasLoggedRequests) == false
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
                        // Track some flag evaluations to populate the contextSummarizer
                        testContext.eventReporter.recordFlagEvaluationEvents(
                            flagKey: "test-flag",
                            value: .bool(true),
                            defaultValue: .bool(false),
                            featureFlag: nil,
                            context: testContext.context,
                            includeReason: false
                        )
                        testContext.eventReporter.flush(completion: nil)
                    }
                }
                it("doesn't report events") {
                    expect(testContext.eventReporter.isOnline) == false
                    expect(testContext.eventReporter.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 0
                    expect(testContext.pendingEvents()) == testContext.recordedEventsAsJSON()
                    expect(testContext.eventReporter.lastEventResponseDate) == Date.distantPast
                    expect(testContext.eventReporter.contextSummarizer.hasLoggedRequests) == true
                    guard case .isOffline = testContext.syncResult
                    else {
                        fail("Expected error .isOffline result for event send")
                        return
                    }
                }
            }
        }
    }

    func testRecordFlagEvaluationEvents() {
        let context = LDContext.stub()
        let serviceMock = DarklyServiceMock()

        /// A reporter writing to a store of its own, and that store, so a test can read back what was recorded.
        func makeReporter() -> (EventReporter, EventStore) {
            let store = EventStore.temporary()
            return (EventReporter(service: serviceMock, onSyncComplete: nil, store: store), store)
        }

        describe("recordFlagEvaluationEvents") {
            it("unknown flag") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: nil, context: context, includeReason: true)
                expect(recordedEvents(store)).to(beEmpty())
                expect(reporter.contextSummarizer.hasLoggedRequests) == true
                let summaries = reporter.contextSummarizer.getSummaries()
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: nil, version: nil)]?.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: nil, version: nil)]?.value) == "a"
            }
            it("untracked flag") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: false)
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: true)
                expect(recordedEvents(store)).to(beEmpty())
                expect(reporter.contextSummarizer.hasLoggedRequests) == true
                let summaries = reporter.contextSummarizer.getSummaries()
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.value) == "a"
            }
            it("tracked flag") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: true)
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: true)
                let expected = FeatureEvent(key: "flag-key", context: context, value: "a", defaultValue: "b", featureFlag: flag, includeReason: true, isDebug: false)
                expect(recordedEvents(store)) == expectedEvents([expected])
                expect(reporter.contextSummarizer.hasLoggedRequests) == true
                let summaries = reporter.contextSummarizer.getSummaries()
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.value) == "a"
            }
            it("debug until past date") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(-1.0))
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: true)
                expect(recordedEvents(store)).to(beEmpty())
                expect(reporter.contextSummarizer.hasLoggedRequests) == true
                let summaries = reporter.contextSummarizer.getSummaries()
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.value) == "a"
            }
            it("debug until future date") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(3.0))
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: false)
                let expected = FeatureEvent(key: "flag-key", context: context, value: "a", defaultValue: "b", featureFlag: flag, includeReason: false, isDebug: true)
                expect(recordedEvents(store)) == expectedEvents([expected])
                expect(reporter.contextSummarizer.hasLoggedRequests) == true
                let summaries = reporter.contextSummarizer.getSummaries()
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.value) == "a"
            }
            it("debug until future date earlier than service date") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                reporter.setLastEventResponseDate(Date().addingTimeInterval(10.0))
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(3.0))
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: true)
                expect(recordedEvents(store)).to(beEmpty())
                expect(reporter.contextSummarizer.hasLoggedRequests) == true
                let summaries = reporter.contextSummarizer.getSummaries()
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.value) == "a"
            }
            it("tracked flag and debug date in future") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                reporter.setLastEventResponseDate(Date().addingTimeInterval(-3.0))
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: true, debugEventsUntilDate: Date())
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: false)
                let expectedFeature = FeatureEvent(key: "flag-key", context: context, value: "a", defaultValue: "b", featureFlag: flag, includeReason: false, isDebug: false)
                let expectedDebug = FeatureEvent(key: "flag-key", context: context, value: "a", defaultValue: "b", featureFlag: flag, includeReason: false, isDebug: true)
                expect(recordedEvents(store)) == expectedEvents([expectedFeature, expectedDebug])
                expect(reporter.contextSummarizer.hasLoggedRequests) == true
                let summaries = reporter.contextSummarizer.getSummaries()
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.value) == "a"
            }
            it("records events concurrently") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                reporter.setLastEventResponseDate(Date())
                let flag = FeatureFlag(flagKey: "unused", trackEvents: true, debugEventsUntilDate: Date().addingTimeInterval(3.0))

                let counter = DispatchSemaphore(value: 0)
                DispatchQueue.concurrentPerform(iterations: 10) { _ in
                    reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: false)
                    counter.signal()
                }
                (0..<10).forEach { _ in counter.wait() }

                let recorded = recordedEvents(store)
                expect(recorded.count) == 20
                expect(recorded.filter { $0.kindField == "feature" }.count) == 10
                expect(recorded.filter { $0.kindField == "debug" }.count) == 10
                expect(reporter.contextSummarizer.hasLoggedRequests) == true
                let summaries = reporter.contextSummarizer.getSummaries()
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: nil, version: nil)]?.count) == 10
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: nil, version: nil)]?.value) == "a"
            }
        }
    }

    private func reportTimerSpec() {
        describe("report timer fires") {
            var testContext: TestContext!
            afterEach {
                testContext.cleanUp()
            }
            context("with events") {
                beforeEach {
                    testContext = TestContext(eventFlushInterval: Constants.eventFlushIntervalHalfSecond)
                    testContext.eventReporter.isOnline = true
                    testContext.recordEvents(Event.Kind.allKinds.count)
                }
                it("reports events") {
                    expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1))
                    expect(testContext.store.pendingEventCount).toEventually(equal(0))
                    expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount).toEventually(equal(1))
                    expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch).toEventually(equal(testContext.events.count))
                    let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                    valueIsArray(published) { valueArray in
                        expect(valueArray.count) == testContext.events.count
                        expect(valueArray) == testContext.events.map { encodeToLDValue($0) }
                    }
                }
            }
            it("without events") {
                testContext = TestContext(eventFlushInterval: Constants.eventFlushIntervalHalfSecond)
                testContext.eventReporter.isOnline = true

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

extension EventReporterSpec {
    /// What the SDK is able to report after the process it was recording in is gone.
    ///
    /// These are written against a second store reading the same directory, which is what the next run of the
    /// application amounts to: it sees the bytes that reached the disk and nothing that was still in memory.
    private func durabilitySpec() {
        describe("surviving the process") {
            var testContext: TestContext!
            afterEach {
                testContext.cleanUp()
            }

            /// The events the next run of the application would find.
            func eventsLeftOnDisk() -> [LDValue] {
                let reader = EventStore(directory: testContext.store.directory, capacity: 100, logger: .disabled)
                return reader.pendingEventPayloads().compactMap { try? JSONDecoder().decode(LDValue.self, from: $0) }
            }

            it("has written a tracked event by the time recording it returns") {
                testContext = TestContext()

                // The sequence that loses events today: something is tracked and the process ends immediately after.
                testContext.eventReporter.record(CustomEvent(key: "fatal-error", context: testContext.context, data: ["message": "boom"]))

                let onDisk = eventsLeftOnDisk()
                expect(onDisk.count) == 1
                expect(onDisk.first?.kindField) == "custom"
            }

            it("has written the evaluations that came before a tracked event") {
                // A response date of its own, because the distant past that a fresh context defaults to also satisfies
                // the debug window comparison and would add a debug event to what is asserted below.
                testContext = TestContext(lastEventResponseDate: Date())
                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: false)

                // An untracked flag is only ever reported as a summary, so this is the case where the exposure exists
                // nowhere but in memory until something forces it out.
                testContext.eventReporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: testContext.context, includeReason: false)
                testContext.eventReporter.record(CustomEvent(key: "fatal-error", context: testContext.context, data: nil))

                expect(eventsLeftOnDisk().compactMap { $0.kindField }) == ["summary", "custom"]
            }

            it("has not yet written an evaluation on its own") {
                testContext = TestContext(lastEventResponseDate: Date())
                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: true)

                // The deliberate trade: an evaluation does not pay for a write, so it is only staged until something
                // else commits it.
                testContext.eventReporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: testContext.context, includeReason: false)
                expect(eventsLeftOnDisk()).to(beEmpty())

                testContext.eventReporter.commitRecordedEvents()
                expect(eventsLeftOnDisk().compactMap { $0.kindField }) == ["feature", "summary"]
            }

            it("does not write on the main thread when a flag is evaluated there") {
                // Suspended for the length of the evaluations, so that a write this thread was going to cause is a
                // write that cannot happen: an evaluation is expected to be a memory operation, and the thread
                // evaluating is usually this one.
                let commits = DispatchQueue(label: "com.launchdarkly.tests.suspended")
                commits.suspend()
                testContext = TestContext(lastEventResponseDate: Date(), store: EventStore.temporary(capacity: .max, commitQueue: commits))

                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: true)
                expect(Thread.isMainThread) == true
                // Far past the staging threshold, so the buffer filled several times over.
                for _ in 0..<400 {
                    testContext.eventReporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: testContext.context, includeReason: false)
                }

                expect(eventsLeftOnDisk()).to(beEmpty())

                commits.resume()

                expect(eventsLeftOnDisk().count).toEventually(equal(400))
            }

            it("reports the events a previous run left behind") {
                testContext = TestContext()
                testContext.recordEvents(2)
                testContext.eventReporter.commitRecordedEvents()

                // Nothing delivered them and nothing closed the log, as would be the case had the process died here.
                let recovered = EventStore(directory: testContext.store.directory, capacity: 100, logger: .disabled)
                let nextRun = EventReporter(service: testContext.serviceMock, onSyncComplete: nil, store: recovered)
                nextRun.isOnline = true

                waitUntil { done in
                    nextRun.flush(completion: done)
                }

                expect(testContext.serviceMock.publishEventDataCallCount) == 1
                let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                valueIsArray(published) { events in
                    expect(events.count) == 2
                }
                expect(recovered.pendingEventCount) == 0
                nextRun.isOnline = false
            }

            it("delivers what a previous run left behind as soon as it is online, without waiting for a report interval") {
                testContext = TestContext()
                testContext.recordEvents(2)
                testContext.eventReporter.commitRecordedEvents()

                let recovered = EventStore(directory: testContext.store.directory, capacity: 100, logger: .disabled)
                let nextRun = EventReporter(service: testContext.serviceMock, onSyncComplete: nil, store: recovered)

                // Nothing asks for a flush, and the report interval is several times longer than this waits, so the
                // only thing that can deliver these is the reporter coming online.
                nextRun.isOnline = true

                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1))
                expect(recovered.pendingEventCount).toEventually(equal(0))
                nextRun.isOnline = false
            }

            it("does not bring a delivery forward when a previous run left nothing behind") {
                testContext = TestContext()

                testContext.eventReporter.isOnline = true

                // Coming online is not itself a reason to send: an ordinary start has nothing waiting, and the events
                // this run records keep to the report interval.
                testContext.recordEvents(1)
                Thread.sleep(forTimeInterval: 0.2)
                expect(testContext.serviceMock.publishEventDataCallCount) == 0
            }

            it("delivers a batch a failed run left behind under the same payload id") {
                testContext = TestContext(stubResponseSuccess: false)
                testContext.recordEvents(1)

                waitUntil(timeout: .seconds(10)) { done in
                    testContext.eventReporter.isOnline = true
                    testContext.eventReporter.flush(completion: done)
                }

                let kept = testContext.store.pendingBatches()
                expect(kept.count) == 1

                // A payload LaunchDarkly may have already seen is retried under the identifier it was first sent with,
                // which is how the events are not counted twice.
                let payloadIds = Set(testContext.serviceMock.publishedPayloadIds)
                expect(payloadIds.count) == 1
                expect(payloadIds.first) == kept.first?.payloadId
            }
        }
    }
}

/// The events a store is holding, as JSON with `creationDate` dropped.
///
/// Dropping the timestamp is what lets an expectation be written as the event the SDK should have produced, rather than
/// as a list of whichever fields the test remembered to check: the recorded event and the expected one are constructed
/// moments apart and differ only in when they were made.
private func recordedEvents(_ store: EventStore) -> [LDValue] {
    store.pendingEventPayloads()
        .compactMap { try? JSONDecoder().decode(LDValue.self, from: $0) }
        .map(withoutCreationDate)
}

private func expectedEvents(_ events: [Event]) -> [LDValue] {
    events.compactMap { encodeToLDValue($0) }.map(withoutCreationDate)
}

private func withoutCreationDate(_ value: LDValue) -> LDValue {
    guard case .object(var fields) = value
    else { return value }
    fields["creationDate"] = nil
    return .object(fields)
}

private extension LDValue {
    var kindField: String? {
        guard case .object(let fields) = self, case .string(let kind) = fields["kind"]
        else { return nil }
        return kind
    }
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
