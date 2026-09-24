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
             onSyncComplete: EventSyncCompleteClosure? = nil) {

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
            eventReporter = EventReporter(service: serviceMock, onSyncComplete: onSyncComplete)
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
    }

    override func spec() {
        initSpec()
        isOnlineSpec()
        recordEventSpec()
        testRecordFlagEvaluationEvents()
        reportEventsSpec()
        unserializableEventSpec()
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
                    extraEvent = Event.stub(.feature, with: testContext.context)

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

    /// Matching the Android recovery tests: a run that cannot be serialized is dropped, and the next
    /// flush still delivers. The shipping encoder writes non-finite numbers as JSON null, so the
    /// public `track(metricValue: .nan)` path does not fail encode; `JSONEncoder` does, which is how
    /// these tests force the failure the Android Gson path sees for `Double.NaN`.
    private func unserializableEventSpec() {
        describe("unserializable events") {
            var serviceMock: DarklyServiceMock!
            var ldContext: LDContext!
            var reporter: EventReporter!

            func makeReporter(encoding: EventReporter.Encoding) -> EventReporter {
                var config = LDConfig.stub
                config.eventCapacity = 8
                ldContext = LDContext.stub()
                serviceMock = DarklyServiceMock()
                serviceMock.config = config
                serviceMock.stubEventResponse(success: true)
                return EventReporter(service: serviceMock, onSyncComplete: nil, encoding: encoding)
            }

            afterEach {
                reporter?.isOnline = false
            }

            context("when JSONEncoder rejects a non-finite metric") {
                beforeEach {
                    reporter = makeReporter(encoding: .codable)
                    reporter.isOnline = true
                }
                it("drops the poisoned batch and delivers a later event") {
                    waitUntil { done in
                        reporter.record(CustomEvent(key: "poison", context: ldContext, metricValue: .nan))
                        reporter.flush(completion: done)
                    }
                    expect(serviceMock.publishEventDataCallCount) == 0
                    expect(reporter.eventStore.isEmpty) == true

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

            context("when JSONEncoder rejects a non-finite metric beside a valid event") {
                beforeEach {
                    reporter = makeReporter(encoding: .codable)
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

            context("when JSONEncoder rejects a non-finite summary beside a valid event") {
                beforeEach {
                    reporter = makeReporter(encoding: .codable)
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

            context("when JSONEncoder rejects a non-finite summary value") {
                beforeEach {
                    reporter = makeReporter(encoding: .codable)
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
                    expect(reporter.eventStore.isEmpty) == true
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

            context("when the shipping encoder sees a non-finite metric") {
                beforeEach {
                    reporter = makeReporter(encoding: .handWritten)
                    reporter.isOnline = true
                }
                it("serializes the event and still delivers later events") {
                    waitUntil { done in
                        reporter.record(CustomEvent(key: "poison", context: ldContext, metricValue: .nan))
                        reporter.flush(completion: done)
                    }
                    expect(serviceMock.publishEventDataCallCount) == 1

                    waitUntil { done in
                        reporter.record(CustomEvent(key: "after-poison", context: ldContext, metricValue: 1.0))
                        reporter.flush(completion: done)
                    }
                    expect(serviceMock.publishEventDataCallCount) == 2
                    let published = try JSONDecoder().decode(LDValue.self, from: serviceMock.publishedEventData!)
                    valueIsArray(published) { events in
                        expect(events.count) == 1
                        valueIsObject(events[0]) { body in
                            expect(body["key"]) == "after-poison"
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
                testContext.eventReporter.isOnline = false
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
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
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
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
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
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
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
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
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
                        it("drops events after the failure") {
                            erOnline()
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
                        it("drops events after the failure") {
                            erOnline()
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
                        it("drops events events after the failure") {
                            erOnline()
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
                    expect(testContext.eventReporter.eventStore) == testContext.events
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
        describe("recordFlagEvaluationEvents") {
            it("unknown flag") {
                let reporter = EventReporter(service: serviceMock, onSyncComplete: nil)
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: nil, context: context, includeReason: true)
                expect(reporter.eventStore.count) == 0
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
                let reporter = EventReporter(service: serviceMock, onSyncComplete: nil)
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: false)
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: true)
                expect(reporter.eventStore.count) == 0
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
                let reporter = EventReporter(service: serviceMock, onSyncComplete: nil)
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: true)
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: true)
                expect(reporter.eventStore.count) == 1
                expect((reporter.eventStore[0] as? FeatureEvent)?.kind) == .feature
                expect((reporter.eventStore[0] as? FeatureEvent)?.key) == "flag-key"
                expect((reporter.eventStore[0] as? FeatureEvent)?.context.contextHash()) == context.contextHash()
                expect((reporter.eventStore[0] as? FeatureEvent)?.value) == "a"
                expect((reporter.eventStore[0] as? FeatureEvent)?.defaultValue) == "b"
                expect((reporter.eventStore[0] as? FeatureEvent)?.featureFlag) == flag
                expect((reporter.eventStore[0] as? FeatureEvent)?.includeReason) == true
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
                let reporter = EventReporter(service: serviceMock, onSyncComplete: nil)
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(-1.0))
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: true)
                expect(reporter.eventStore.count) == 0
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
                let reporter = EventReporter(service: serviceMock, onSyncComplete: nil)
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(3.0))
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: false)
                expect(reporter.eventStore.count) == 1
                expect((reporter.eventStore[0] as? FeatureEvent)?.kind) == .debug
                expect((reporter.eventStore[0] as? FeatureEvent)?.key) == "flag-key"
                expect((reporter.eventStore[0] as? FeatureEvent)?.context) == context
                expect((reporter.eventStore[0] as? FeatureEvent)?.value) == "a"
                expect((reporter.eventStore[0] as? FeatureEvent)?.defaultValue) == "b"
                expect((reporter.eventStore[0] as? FeatureEvent)?.featureFlag) == flag
                expect((reporter.eventStore[0] as? FeatureEvent)?.includeReason) == false
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
                let reporter = EventReporter(service: serviceMock, onSyncComplete: nil)
                reporter.setLastEventResponseDate(Date().addingTimeInterval(10.0))
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(3.0))
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: true)
                expect(reporter.eventStore.count) == 0
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
                let reporter = EventReporter(service: serviceMock, onSyncComplete: nil)
                reporter.setLastEventResponseDate(Date().addingTimeInterval(-3.0))
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: true, debugEventsUntilDate: Date())
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: false)
                expect(reporter.eventStore.count) == 2
                let featureEvent = reporter.eventStore.first { $0.kind == .feature } as? FeatureEvent
                let debugEvent = reporter.eventStore.first { $0.kind == .debug } as? FeatureEvent
                expect(featureEvent?.kind) == .feature
                expect(featureEvent?.key) == "flag-key"
                expect(featureEvent?.context.contextHash()) == context.contextHash()
                expect(featureEvent?.value) == "a"
                expect(featureEvent?.defaultValue) == "b"
                expect(featureEvent?.featureFlag) == flag
                expect(featureEvent?.includeReason) == false
                expect(debugEvent?.kind) == .debug
                expect(debugEvent?.key) == "flag-key"
                expect(debugEvent?.context) == context
                expect(debugEvent?.value) == "a"
                expect(debugEvent?.defaultValue) == "b"
                expect(debugEvent?.featureFlag) == flag
                expect(debugEvent?.includeReason) == false
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
                let reporter = EventReporter(service: serviceMock, onSyncComplete: nil)
                reporter.setLastEventResponseDate(Date())
                let flag = FeatureFlag(flagKey: "unused", trackEvents: true, debugEventsUntilDate: Date().addingTimeInterval(3.0))

                let counter = DispatchSemaphore(value: 0)
                DispatchQueue.concurrentPerform(iterations: 10) { _ in
                    reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: false)
                    counter.signal()
                }
                (0..<10).forEach { _ in counter.wait() }

                expect(reporter.eventStore.count) == 20
                expect(reporter.eventStore.filter { $0.kind == .feature }.count) == 10
                expect(reporter.eventStore.filter { $0.kind == .debug }.count) == 10
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
