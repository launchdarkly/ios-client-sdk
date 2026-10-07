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
             store: EventStore? = nil,
             eventCapacity: Int = Event.Kind.allKinds.count,
             eventPersistence: EventPersistence = .immediate,
             commitQueue: DispatchQueue = DispatchQueue(label: "com.launchdarkly.tests.EventReporter.commitQueue")) {

            config = LDConfig.stub
            config.eventCapacity = eventCapacity
            // The durable behaviour is what most of these are about, so it is the default here even though an
            // application has to ask for it.
            config.eventPersistence = eventPersistence
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
            eventReporter = EventReporter(service: serviceMock, onSyncComplete: onSyncComplete,
                                          store: self.store, commitQueue: commitQueue)
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

        /// Commits everything accepted so far and returns its wire representation.
        func committedEvents() -> [LDValue] {
            eventReporter.commitRecordedEvents()
            return store.pendingEventPayloads().compactMap { try? JSONDecoder().decode(LDValue.self, from: $0) }
        }

        /// The events recorded so far, in the JSON they encode to, for comparison with `committedEvents()`.
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
        unserializableEventSpec()
        reportTimerSpec()
        durabilitySpec()
        commitSpec()
        flushReportingOutcomeSpec()
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
                    expect(testContext.committedEvents()) == testContext.recordedEventsAsJSON()
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
                    expect(testContext.committedEvents()) == testContext.recordedEventsAsJSON()
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
                    expect(testContext.committedEvents()) == testContext.recordedEventsAsJSON()
                }
                it("records a dropped event to diagnosticCache") {
                    expect(testContext.diagnosticCache.incrementDroppedEventCountCallCount) == 1
                }
            }
        }
    }

    /// An event holding a NaN or infinite number cannot be serialized by either encoder. It is dropped, and
    /// the events beside it and after it are still delivered.
    private func unserializableEventSpec() {
        describe("unserializable events") {
            var serviceMock: DarklyServiceMock!
            var ldContext: LDContext!
            var reporter: EventReporter!
            var store: EventStore!

            func makeReporter(encoding: EventReporter.Encoding) -> EventReporter {
                var config = LDConfig.stub
                config.eventCapacity = 8
                ldContext = LDContext.stub()
                serviceMock = DarklyServiceMock()
                serviceMock.config = config
                serviceMock.stubEventResponse(success: true)
                store = EventStore.temporary(capacity: config.eventCapacity)
                return EventReporter(service: serviceMock, onSyncComplete: nil, store: store, encoding: encoding)
            }

            afterEach {
                reporter?.isOnline = false
            }

            for encoding in [EventReporter.Encoding.codable, .handWritten] {
                context("\(encoding): when an event holds a non-finite metric") {
                    beforeEach {
                        reporter = makeReporter(encoding: encoding)
                        reporter.isOnline = true
                    }
                    it("drops the poisoned batch and delivers a later event") {
                        waitUntil { done in
                            reporter.record(CustomEvent(key: "poison", context: ldContext, metricValue: .nan))
                            reporter.flush(completion: done)
                        }
                        expect(serviceMock.publishEventDataCallCount) == 0
                        expect(store.pendingEventCount) == 0

                        waitUntil { done in
                            reporter.record(CustomEvent(key: "after-poison", context: ldContext, metricValue: 1.0))
                            reporter.flush(completion: done)
                        }
                        expect(serviceMock.publishEventDataCallCount) == 1
                        let published = try JSONDecoder().decode(LDValue.self, from: serviceMock.publishedEventData!)
                        valueIsArray(published) { events in
                            expect(events.count) == 1
                            valueIsObject(events[0]) { body in
                                expect(body["key"]) == "after-poison"
                            }
                        }
                    }
                }

                context("\(encoding): when an event holds a non-finite metric beside a valid event") {
                    beforeEach {
                        reporter = makeReporter(encoding: encoding)
                        reporter.isOnline = true
                    }
                    it("drops only the poisoned event") {
                        waitUntil { done in
                            reporter.record(CustomEvent(key: "poison", context: ldContext, metricValue: .nan))
                            reporter.record(CustomEvent(key: "kept", context: ldContext, metricValue: 1.0))
                            reporter.flush(completion: done)
                        }
                        expect(serviceMock.publishEventDataCallCount) == 1
                        let published = try JSONDecoder().decode(LDValue.self, from: serviceMock.publishedEventData!)
                        valueIsArray(published) { events in
                            expect(events.count) == 1
                            valueIsObject(events[0]) { body in
                                expect(body["key"]) == "kept"
                            }
                        }
                    }
                }

                context("\(encoding): when an event holds a non-finite summary beside a valid event") {
                    beforeEach {
                        reporter = makeReporter(encoding: encoding)
                        reporter.isOnline = true
                    }
                    it("drops only the poisoned summary") {
                        waitUntil { done in
                            reporter.recordFlagEvaluationEvents(flagKey: "poison-flag",
                                                                value: .number(.nan),
                                                                defaultValue: .number(0),
                                                                featureFlag: nil,
                                                                context: ldContext,
                                                                includeReason: false)
                            reporter.record(IdentifyEvent(context: ldContext))
                            reporter.flush(completion: done)
                        }
                        expect(serviceMock.publishEventDataCallCount) == 1
                        let published = try JSONDecoder().decode(LDValue.self, from: serviceMock.publishedEventData!)
                        valueIsArray(published) { events in
                            expect(events.count) == 1
                            valueIsObject(events[0]) { body in
                                expect(body["kind"]) == "identify"
                            }
                        }
                    }
                }

                context("\(encoding): when an event holds a non-finite summary value") {
                    beforeEach {
                        reporter = makeReporter(encoding: encoding)
                        reporter.isOnline = true
                    }
                    it("drops the poisoned summary and delivers a later one") {
                        waitUntil { done in
                            reporter.recordFlagEvaluationEvents(flagKey: "poison-flag",
                                                                value: .number(.nan),
                                                                defaultValue: .number(0),
                                                                featureFlag: nil,
                                                                context: ldContext,
                                                                includeReason: false)
                            reporter.flush(completion: done)
                        }
                        expect(serviceMock.publishEventDataCallCount) == 0
                        expect(store.pendingEventCount) == 0
                        expect(reporter.contextSummarizer.hasLoggedRequests) == false

                        waitUntil { done in
                            reporter.recordFlagEvaluationEvents(flagKey: "after-poison",
                                                                value: .bool(true),
                                                                defaultValue: .bool(false),
                                                                featureFlag: nil,
                                                                context: ldContext,
                                                                includeReason: false)
                            reporter.flush(completion: done)
                        }
                        expect(serviceMock.publishEventDataCallCount) == 1
                        let published = try JSONDecoder().decode(LDValue.self, from: serviceMock.publishedEventData!)
                        valueIsArray(published) { events in
                            expect(events.count) == 1
                            valueIsObject(events[0]) { body in
                                expect(body["kind"]) == "summary"
                                valueIsObject(body["features"]) { features in
                                    expect(features["after-poison"]).toNot(beNil())
                                }
                            }
                        }
                    }
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
                    context("non-retriable response") {
                        beforeEach {
                            waitUntil(timeout: .seconds(10)) { syncComplete in
                                testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                let unauthorized = HTTPURLResponse(url: testContext.serviceMock.config.eventsUrl,
                                                                   statusCode: HTTPURLResponse.StatusCodes.unauthorized,
                                                                   httpVersion: DarklyServiceMock.Constants.httpVersion,
                                                                   headerFields: nil)
                                testContext.serviceMock.stubbedEventResponse = (nil, unauthorized, nil, nil)
                                testContext.eventReporter.isOnline = true
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                                testContext.eventReporter.flush(completion: nil)
                            }
                        }
                        it("drops events and stops reporting") {
                            expect(testContext.serviceMock.publishEventDataCallCount) == 1
                            expect(testContext.store.pendingEventCount).toEventually(equal(0))
                            expect(testContext.eventReporter.isOnline).to(beFalse())
                            expect(testContext.eventReporter.isReportingActive).to(beFalse())
                            if case let .response(error) = testContext.syncResult {
                                expect((error as? HTTPURLResponse)?.statusCode) == HTTPURLResponse.StatusCodes.unauthorized
                            } else {
                                fail("Expected response error result for event send")
                            }
                        }
                        it("can be brought back online") {
                            testContext.eventReporter.isOnline = true
                            expect(testContext.eventReporter.isOnline).to(beTrue())
                            expect(testContext.eventReporter.isReportingActive).to(beTrue())
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
                it("doesn't report events, but persists them") {
                    expect(testContext.eventReporter.isOnline) == false
                    expect(testContext.eventReporter.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 0
                    expect(testContext.eventReporter.lastEventResponseDate) == Date.distantPast

                    // Being offline delays delivery, not durability: a flush is a commit point, so the recorded events and
                    // the evaluations counted so far are on disk even though nothing can be sent.
                    let pending = testContext.committedEvents()
                    expect(pending.dropLast().map { $0 }) == testContext.recordedEventsAsJSON()
                    expect(pending.last?.kindField) == "summary"
                    expect(testContext.eventReporter.contextSummarizer.hasLoggedRequests) == false
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
            it("counts an evaluation the summarizer turns away as dropped, and still keeps its full event") {
                var config = LDConfig.stub
                config.eventCapacity = 2
                let service = DarklyServiceMock()
                service.config = config
                let diagnosticCache = DiagnosticCachingMock()
                service.diagnosticCache = diagnosticCache
                let store = EventStore.temporary(capacity: config.eventCapacity)
                defer { store.deleteEverything() }
                let reporter = EventReporter(service: service, onSyncComplete: nil, store: store)
                let untracked = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: false)
                let tracked = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: true)

                // Capacity bounds the number of contexts counted as well as the number of events held.
                for key in ["a", "b"] {
                    reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: untracked, context: LDContext.stub(key: key), includeReason: false)
                }
                expect(diagnosticCache.incrementDroppedEventCountCallCount) == 0

                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: tracked, context: LDContext.stub(key: "c"), includeReason: false)

                expect(diagnosticCache.incrementDroppedEventCountCallCount) == 1
                expect(reporter.contextSummarizer.getSummaries().count) == 2
                reporter.commitRecordedEvents()
                expect(recordedEvents(store).compactMap { $0.kindField }) == ["feature", "summary", "summary"]
            }
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
                expect(expectedEvents(reporter.pendingEventsForTesting)) == expectedEvents([expected])
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
                expect(expectedEvents(reporter.pendingEventsForTesting)) == expectedEvents([expected])
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
                expect(expectedEvents(reporter.pendingEventsForTesting)) == expectedEvents([expectedFeature, expectedDebug])
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

                let held = expectedEvents(reporter.pendingEventsForTesting)
                expect(held.count) == 20
                expect(held.filter { $0.kindField == "feature" }.count) == 10
                expect(held.filter { $0.kindField == "debug" }.count) == 10
                expect(recordedEvents(store)).to(beEmpty())
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
            context("on later intervals") {
                beforeEach {
                    testContext = TestContext(eventFlushInterval: Constants.eventFlushIntervalHalfSecond)
                    testContext.eventReporter.isOnline = true
                    testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                }
                it("publishes events recorded after the first fire") {
                    expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1))
                    testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                    expect(testContext.serviceMock.publishEventDataCallCount)
                        .toEventually(equal(2), timeout: .seconds(2))
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

            it("still writes a tracked event when the write is not on the caller's thread") {
                testContext = TestContext(eventPersistence: .deferred)

                testContext.eventReporter.record(CustomEvent(key: "fatal-error", context: testContext.context, data: ["message": "boom"]))

                // The promise is weaker by exactly one scheduling hop: the event reaches the disk, just not before
                // recording it returned.
                expect(eventsLeftOnDisk().compactMap { $0.kindField }).toEventually(equal(["custom"]))
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

                expect(eventsLeftOnDisk().compactMap { $0.kindField }) == ["custom", "summary"]
            }

            it("persists feature and summary events synchronously on flush") {
                testContext = TestContext(lastEventResponseDate: Date())
                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: true)

                // The deliberate trade: an evaluation does not pay for a write, so it is only staged until something
                // else commits it.
                testContext.eventReporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: testContext.context, includeReason: false)
                expect(eventsLeftOnDisk()).to(beEmpty())

                testContext.eventReporter.flush(completion: nil)
                expect(eventsLeftOnDisk().compactMap { $0.kindField }) == ["feature", "summary"]
            }

            it("does not write on the main thread when a flag is evaluated there") {
                // Suspended for the length of the evaluations, so that a write this thread was going to cause is a
                // write that cannot happen: an evaluation is expected to be a memory operation, and the thread
                // evaluating is usually this one.
                let commits = DispatchQueue(label: "com.launchdarkly.tests.suspended")
                commits.suspend()
                testContext = TestContext(lastEventResponseDate: Date(),
                                          store: EventStore.temporary(capacity: .max),
                                          eventCapacity: .max,
                                          commitQueue: commits)

                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: true)
                expect(Thread.isMainThread) == true
                // Far past the pending threshold, so one coalesced commit is waiting.
                for _ in 0..<400 {
                    testContext.eventReporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: testContext.context, includeReason: false)
                }

                expect(eventsLeftOnDisk()).to(beEmpty())

                commits.resume()

                expect(eventsLeftOnDisk().compactMap { $0.kindField }.filter { $0 == "feature" }.count)
                    .toEventually(equal(400))
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

            it("does not send a batch again when a delivery is asked for while one is in flight") {
                testContext = TestContext()
                testContext.recordEvents(1)
                testContext.eventReporter.isOnline = true
                // The response is held back, so the first delivery stays in flight and its batch stays on disk --
                // the window in which a second delivery would find that batch and send it again.
                testContext.serviceMock.holdsEventCompletions = true

                var firstFinished = false
                testContext.eventReporter.flush { firstFinished = true }
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1))

                var secondFinished = false
                testContext.eventReporter.flush { secondFinished = true }
                // Nothing more goes out while the first delivery is unanswered.
                Thread.sleep(forTimeInterval: 0.3)
                expect(testContext.serviceMock.publishEventDataCallCount) == 1

                testContext.serviceMock.holdsEventCompletions = false
                testContext.serviceMock.releaseHeldEventCompletions()

                // The second caller is answered by the pass that runs once the first delivery is done. It finds an
                // empty store, so the batch is sent once in total.
                expect(firstFinished).toEventually(beTrue())
                expect(secondFinished).toEventually(beTrue())
                expect(testContext.serviceMock.publishEventDataCallCount) == 1
                expect(testContext.store.pendingEventCount) == 0
            }
        }
    }

    private func commitSpec() {
        describe("committing held events") {
            var testContext: TestContext!
            afterEach {
                testContext?.cleanUp()
                testContext = nil
            }

            it("leaves held events for the delivery to encode when they are not persisted") {
                let commits = DispatchQueue(label: "com.launchdarkly.tests.commits")
                testContext = TestContext(lastEventResponseDate: Date(),
                                          store: EventStore.temporary(capacity: .max, persistEvents: false),
                                          eventCapacity: .max,
                                          eventPersistence: .disabled,
                                          commitQueue: commits)
                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: true)

                // Past the pending threshold and then a commit point: either would commit where events are persisted.
                for _ in 0..<100 {
                    testContext.eventReporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: testContext.context, includeReason: false)
                }
                testContext.eventReporter.record(CustomEvent(key: "custom", context: testContext.context))
                testContext.eventReporter.flush(completion: nil)
                commits.sync { }

                // Encoding them early would buy nothing, since a commit here writes nothing to disk.
                expect(testContext.store.pendingEventCount) == 0

                testContext.eventReporter.isOnline = true
                waitUntil { done in
                    testContext.eventReporter.flush(completion: done)
                }
                let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                valueIsArray(published) { events in
                    expect(events.compactMap { $0.kindField }.filter { $0 == "feature" }.count) == 100
                    expect(events.compactMap { $0.kindField }.filter { $0 != "feature" }) == ["custom", "summary"]
                }
            }

            it("commits an evaluation's counter together with its full event") {
                testContext = TestContext(lastEventResponseDate: Date(),
                                          store: EventStore.temporary(capacity: .max),
                                          eventCapacity: .max)
                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: true)
                let reporter = testContext.eventReporter!
                let context = testContext.context!

                let recorded = DispatchSemaphore(value: 0)
                DispatchQueue.global().async {
                    for _ in 0..<2_000 {
                        reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: false)
                    }
                    recorded.signal()
                }
                while recorded.wait(timeout: .now()) == .timedOut {
                    reporter.commitRecordedEvents()
                }
                reporter.commitRecordedEvents()

                // A commit stages its run and then its summary, so each summary has to count exactly the feature
                // events since the one before it; a commit that caught an evaluation half recorded would not.
                var featuresSinceSummary = 0
                var summaries = 0
                for event in recordedEvents(testContext.store) {
                    switch event.kindField {
                    case "feature":
                        featuresSinceSummary += 1
                    case "summary":
                        summaries += 1
                        expect(summaryCount(event)) == featuresSinceSummary
                        featuresSinceSummary = 0
                    default:
                        break
                    }
                }
                expect(featuresSinceSummary) == 0
                expect(summaries) > 1
            }

            it("counts a run toward capacity while it is being encoded") {
                var config = LDConfig.stub
                config.eventCapacity = 1
                config.eventPersistence = .deferred
                let serviceMock = DarklyServiceMock()
                serviceMock.config = config
                let diagnosticCache = DiagnosticCachingMock()
                serviceMock.diagnosticCache = diagnosticCache
                let store = EventStore.temporary(capacity: config.eventCapacity)
                defer { store.deleteEverything() }
                let commits = DispatchQueue(label: "com.launchdarkly.tests.suspended")
                commits.suspend()
                defer { commits.resume() }
                let reporter = EventReporter(service: serviceMock, onSyncComplete: nil, store: store, encoding: .codable, commitQueue: commits)

                let slow = EncodingGate(key: "slow", context: LDContext.stub())
                reporter.record(slow)
                let committed = DispatchSemaphore(value: 0)
                DispatchQueue.global().async {
                    reporter.commitRecordedEvents()
                    committed.signal()
                }
                expect(slow.started.wait(timeout: .now() + 5)) == .success

                // Neither held nor staged at this moment, the slow event is only in the commit encoding it.
                reporter.record(CustomEvent(key: "late", context: LDContext.stub()))

                slow.proceed.signal()
                expect(committed.wait(timeout: .now() + 5)) == .success
                reporter.commitRecordedEvents()

                expect(store.pendingEventCount) == 1
                expect(diagnosticCache.incrementDroppedEventCountCallCount) == 1
            }

            it("does not close a batch partway through another commit's run") {
                var config = LDConfig.stub
                config.eventPersistence = .deferred
                let serviceMock = DarklyServiceMock()
                serviceMock.config = config
                serviceMock.stubEventResponse(success: true)
                let inner = EventStore.temporary(capacity: config.eventCapacity)
                defer { inner.deleteEverything() }
                let store = ClosingHookStore(inner)
                let commits = DispatchQueue(label: "com.launchdarkly.tests.suspended")
                commits.suspend()
                defer { commits.resume() }
                let reporter = EventReporter(service: serviceMock, onSyncComplete: nil, store: store, encoding: .codable, commitQueue: commits)

                let slow = EncodingGate(key: "slow", context: LDContext.stub())
                let competingCommit = DispatchSemaphore(value: 0)
                store.beforeClosing = {
                    reporter.record(CustomEvent(key: "first", context: LDContext.stub()))
                    reporter.record(slow)
                    DispatchQueue.global().async {
                        reporter.commitRecordedEvents()
                        competingCommit.signal()
                    }
                    // Long enough for an unguarded commit to stage "first" and block encoding "slow".
                    _ = slow.started.wait(timeout: .now() + 0.5)
                }
                store.afterClosing = { slow.proceed.signal() }

                reporter.isOnline = true
                waitUntil(timeout: .seconds(10)) { done in
                    reporter.flushReportingOutcome { _ in done() }
                }
                expect(competingCommit.wait(timeout: .now() + 5)) == .success

                for keys in store.closedKeys {
                    expect(keys.contains("first")) == keys.contains("slow")
                }
                let rest = inner.closeBatch().flatMap { inner.body(of: $0) }.map(customKeys) ?? []
                expect(rest) == ["first", "slow"]
            }
        }
    }

    private func flushReportingOutcomeSpec() {
        describe("flush reporting outcome") {
            var testContext: TestContext!
            afterEach {
                testContext.cleanUp()
            }

            it("reports true when there is nothing to deliver") {
                testContext = TestContext()
                testContext.eventReporter.isOnline = true
                var delivered: Bool?
                waitUntil { done in
                    testContext.eventReporter.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == true
            }

            it("reports false while offline") {
                testContext = TestContext()
                testContext.recordEvents(1)
                var delivered: Bool?
                waitUntil { done in
                    testContext.eventReporter.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 0
            }

            it("reports true when LaunchDarkly accepts the batch") {
                testContext = TestContext()
                testContext.recordEvents(1)
                testContext.eventReporter.isOnline = true
                var delivered: Bool?
                waitUntil { done in
                    testContext.eventReporter.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == true
                expect(testContext.store.pendingEventCount) == 0
            }

            it("reports false when a retryable failure leaves the batch on disk") {
                testContext = TestContext(stubResponseSuccess: false)
                testContext.recordEvents(1)
                testContext.eventReporter.isOnline = true
                var delivered: Bool?
                waitUntil(timeout: .seconds(10)) { done in
                    testContext.eventReporter.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == false
                expect(testContext.store.pendingBatches().count) == 1
            }

            it("reports true to a waiter when the in-flight delivery is permanently refused") {
                testContext = TestContext()
                let unauthorized = HTTPURLResponse(url: testContext.serviceMock.config.eventsUrl,
                                                   statusCode: HTTPURLResponse.StatusCodes.unauthorized,
                                                   httpVersion: DarklyServiceMock.Constants.httpVersion,
                                                   headerFields: nil)
                testContext.serviceMock.stubbedEventResponse = (nil, unauthorized, nil, nil)
                testContext.recordEvents(1)
                testContext.eventReporter.isOnline = true
                testContext.serviceMock.holdsEventCompletions = true

                testContext.eventReporter.flushReportingOutcome { _ in }
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1))

                var delivered: Bool?
                testContext.eventReporter.flushReportingOutcome { result in delivered = result }
                Thread.sleep(forTimeInterval: 0.2)
                expect(delivered).to(beNil())

                testContext.serviceMock.holdsEventCompletions = false
                testContext.serviceMock.releaseHeldEventCompletions()

                expect(delivered).toEventually(beTrue())
                expect(testContext.eventReporter.isOnline) == false
                expect(testContext.store.pendingEventCount) == 0
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

/// How many evaluations a summary event counts, across all of its flags and variations.
private func summaryCount(_ summary: LDValue) -> Int {
    guard case .object(let fields) = summary, case .object(let features)? = fields["features"]
    else { return 0 }
    var total = 0
    for case .object(let flag) in features.values {
        guard case .array(let counters)? = flag["counters"] else { continue }
        for case .object(let counter) in counters {
            if case .number(let count)? = counter["count"] {
                total += Int(count)
            }
        }
    }
    return total
}

/// A custom event whose encoding waits to be let through, so a test can act while a commit is encoding it.
private final class EncodingGate: CustomEvent {
    let started = DispatchSemaphore(value: 0)
    let proceed = DispatchSemaphore(value: 0)

    override func encode(to encoder: Encoder) throws {
        started.signal()
        _ = proceed.wait(timeout: .now() + 5)
        try super.encode(to: encoder)
    }
}

/// A store that runs a hook on either side of closing a batch, and remembers the custom event keys of each batch closed.
private final class ClosingHookStore: EventStoring {
    let inner: EventStoring
    var beforeClosing: (() -> Void)?
    var afterClosing: (() -> Void)?
    private(set) var closedKeys: [[String]] = []

    init(_ inner: EventStoring) {
        self.inner = inner
    }

    var pendingEventCount: Int { inner.pendingEventCount }
    var isPersisting: Bool { inner.isPersisting }
    func stage(_ encodedEvent: Data, bypassingCapacity: Bool) -> Bool { inner.stage(encodedEvent, bypassingCapacity: bypassingCapacity) }
    func reserve(_ events: Int) { inner.reserve(events) }
    func stageReserved(_ encodedEvent: Data) -> Bool { inner.stageReserved(encodedEvent) }
    func releaseReservations() { inner.releaseReservations() }
    func commit() { inner.commit() }
    func pendingBatches() -> [EventBatch] { inner.pendingBatches() }
    func body(of batch: EventBatch) -> Data? { inner.body(of: batch) }
    func remove(_ batch: EventBatch) { inner.remove(batch) }
    func recoverInterruptedLog() { inner.recoverInterruptedLog() }

    func closeBatch() -> EventBatch? {
        let before = beforeClosing
        beforeClosing = nil
        before?()
        let batch = inner.closeBatch()
        if let batch, let body = inner.body(of: batch) {
            closedKeys.append(customKeys(body))
        }
        let after = afterClosing
        afterClosing = nil
        after?()
        return batch
    }
}

private func customKeys(_ body: Data) -> [String] {
    guard case .array(let events)? = try? JSONDecoder().decode(LDValue.self, from: body)
    else { return [] }
    return events.compactMap { event in
        guard event.kindField == "custom", case .object(let fields) = event, case .string(let key) = fields["key"]
        else { return nil }
        return key
    }
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
