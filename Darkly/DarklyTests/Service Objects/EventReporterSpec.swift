//
//  EventReporterSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 9/26/17.
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
import XCTest
@testable import LaunchDarkly

final class EventReporterSpec: QuickSpec {
    struct Constants {
        static let eventFlushIntervalMillis = 10_000
        static let eventFlushInterval500Millis = 500
        static let defaultValue = false
    }
    
    struct TestContext {
        var eventReporter: EventReporter!
        var config: LDConfig!
        var user: LDUser!
        var serviceMock: DarklyServiceMock!
        var events: [Event]!
        var eventKeys: [String]! {
            return events.flatMap { (event) in event.key }
        }
        var eventKinds: [Event.Kind]! {
            return events.flatMap { (event) in event.kind }
        }
        var lastEventResponseDate: Date?
        var flagKey: LDFlagKey!
        var eventTrackingContext: EventTrackingContext!
        var featureFlag: FeatureFlag!
        var eventStubResponseDate: Date?
        var flagRequestTracker: FlagRequestTracker?

        init(eventCount: Int = 0,
             eventFlushMillis: Int? = nil,
             lastEventResponseDate: Date? = nil,
             stubResponseSuccess: Bool = true,
             stubResponseOnly: Bool = false,
             stubResponseErrorOnly: Bool = false,
             eventStubResponseDate: Date? = nil,
             trackEvents: Bool? = true,
             debugEventsUntilDate: Date? = nil,
             flagRequestTracker: FlagRequestTracker? = nil) {

            config = LDConfig.stub
            config.eventCapacity = Event.Kind.allKinds.count
            config.eventFlushIntervalMillis = eventFlushMillis ?? Constants.eventFlushIntervalMillis

            user = LDUser.stub()

            self.eventStubResponseDate = eventStubResponseDate?.adjustedForHttpUrlHeaderUse
            serviceMock = DarklyServiceMock()
            serviceMock.stubEventResponse(success: stubResponseSuccess, responseOnly: stubResponseOnly, errorOnly: stubResponseErrorOnly, responseDate: self.eventStubResponseDate)

            events = []
            while events.count < eventCount {
                let event = Event.stub(Event.eventKind(for: events.count), with: user)
                events.append(event)
            }

            self.lastEventResponseDate = lastEventResponseDate?.adjustedForHttpUrlHeaderUse
            self.flagRequestTracker = flagRequestTracker
            eventReporter = EventReporter(config: config, service: serviceMock, events: events, lastEventResponseDate: self.lastEventResponseDate, flagRequestTracker: flagRequestTracker)

            flagKey = UUID().uuidString
            if let trackEvents = trackEvents {
                eventTrackingContext = EventTrackingContext(trackEvents: trackEvents)
            }
            if let debugEventsUntilDate = debugEventsUntilDate {
                eventTrackingContext = EventTrackingContext(trackEvents: self.eventTrackingContext?.trackEvents ?? false, debugEventsUntilDate: debugEventsUntilDate)
            }
            featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, eventTrackingContext: eventTrackingContext)
        }

        mutating func recordEvents(_ eventCount: Int, completion: CompletionClosure? = nil) {
            guard eventCount > 0 else {
                completion?()
                return
            }
            let eventRecordingGroup = DispatchGroup()
            for _ in 0..<eventCount {
                let event = Event.stub(Event.eventKind(for: events.count), with: user)
                events.append(event)
                eventRecordingGroup.enter()
                eventReporter.record(event) {
                    eventRecordingGroup.leave()
                }
            }
            eventRecordingGroup.notify(queue: DispatchQueue.main) {
                completion?()
            }
        }
    }
    
    override func spec() {
        initSpec()
        isOnlineSpec()
        changeConfigSpec()
        recordEventSpec()
        recordFlagEvaluationEventsSpec()
        recordSummaryEventSpec()
        resetFlagRequestTrackerSpec()
        reportEventsSpec()
        reportTimerSpec()
    }

    private func initSpec() {
        describe("init") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()

                testContext.eventReporter = EventReporter(config: testContext.config, service: testContext.serviceMock)
            }
            it("starts offline without reporting events") {
                expect(testContext.eventReporter.config) == testContext.config
                expect(testContext.eventReporter.service) === testContext.serviceMock
                expect(testContext.eventReporter.isOnline) == false
                expect(testContext.eventReporter.isReportingActive) == false
                expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
            }
        }
    }

    private func isOnlineSpec() {
        describe("isOnline") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
            }
            context("online to offline") {
                beforeEach {
                    testContext.eventReporter.isOnline = true

                    testContext.eventReporter.isOnline = false
                }
                it("goes offline and stops reporting") {
                    expect(testContext.eventReporter.isOnline) == false
                    expect(testContext.eventReporter.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
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
                        expect(testContext.serviceMock.publishEventDictionariesCallCount) == 1
                        expect(testContext.serviceMock.publishedEventDictionaryKeys) == testContext.eventKeys
                        expect(testContext.eventReporter.eventStore.isEmpty).toEventually(beTrue())  //event processing is asynchronous
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
                        expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
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
                    expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
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
                    expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
                    expect(testContext.eventReporter.eventStoreKeys) == testContext.eventKeys
                }
            }
        }
    }

    private func changeConfigSpec() {
        describe("change config") {
            var config: LDConfig!
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
                config = LDConfig.stub
                config.streamingMode = .polling //using this to verify the config was changed...could be any value different from the setup
            }
            context("while offline") {
                beforeEach {
                    testContext.eventReporter.config = config
                }
                it("changes the config") {
                    expect(testContext.eventReporter.isOnline) == false
                    expect(testContext.eventReporter.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
                    expect(testContext.eventReporter.config.streamingMode) == config.streamingMode
                }
            }
            context("while online") {
                beforeEach {
                    testContext.eventReporter.isOnline = true

                    testContext.eventReporter.config = config
                }
                it("takes the reporter offline and changes the config") {
                    expect(testContext.eventReporter.isOnline) == false
                    expect(testContext.eventReporter.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
                    expect(testContext.eventReporter.config) == config
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

                    waitUntil { done in
                        testContext.recordEvents(Event.Kind.allKinds.count, completion: done) // Stub events, call testContext.eventReporter.recordEvent, and keeps them in testContext.events
                    }
                }
                it("records events up to event capacity") {
                    expect(testContext.eventReporter.isOnline) == false
                    expect(testContext.eventReporter.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
                    expect(testContext.eventReporter.eventStoreKeys) == testContext.eventKeys
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
                    expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
                    expect(testContext.eventReporter.eventStoreKeys) == testContext.eventKeys
                    expect(testContext.eventReporter.eventStoreKeys.contains(extraEvent.key!)) == false
                }
            }
        }
    }

    private func reportEventsSpec() {
        describe("reportEvents") {
            var testContext: TestContext!
            var eventStubResponseDate: Date!
            beforeEach {
                eventStubResponseDate = Date().addingTimeInterval(-TimeInterval.oneSecond)
            }
            context("online") {
                context("success") {
                    context("with events and tracked requests") {
                        beforeEach {
                            //The EventReporter will try to report events if it's started online with events. By starting online without events, then adding them, we "beat the timer" by reporting them right away
                            testContext = TestContext(eventStubResponseDate: eventStubResponseDate)
                            testContext.eventReporter.isOnline = true
                            waitUntil { done in
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count, completion: done)
                            }
                            testContext.flagRequestTracker = FlagRequestTracker.stub()
                            testContext.eventReporter.setFlagRequestTracker(testContext.flagRequestTracker!)

                            waitUntil { done in
                                testContext.eventReporter.reportEvents(completion: done)
                            }
                        }
                        it("reports events and a summary event") {
                            expect(testContext.eventReporter.isOnline) == true
                            expect(testContext.eventReporter.isReportingActive) == true
                            expect(testContext.serviceMock.publishEventDictionariesCallCount) == 1
                            expect(testContext.serviceMock.publishedEventDictionaries?.count) == Event.Kind.nonSummaryKinds.count + 1
                            expect(testContext.serviceMock.publishedEventDictionaryKeys) == testContext.eventKeys //summary events have no key, this verifies non-summary events
                            expect(testContext.serviceMock.publishedEventDictionaryKinds?.contains(.summary)) == true
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
                            expect(testContext.eventReporter.lastEventResponseDate) == testContext.eventStubResponseDate
                            expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                        }
                    }
                    context("with events only") {
                        beforeEach {
                            //The EventReporter will try to report events if it's started online with events. By starting online without events, then adding them, we "beat the timer" by reporting them right away
                            testContext = TestContext(eventStubResponseDate: eventStubResponseDate)
                            testContext.eventReporter.isOnline = true
                            waitUntil { done in
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count, completion: done)
                            }

                            waitUntil { done in
                                testContext.eventReporter.reportEvents(completion: done)
                            }
                        }
                        it("reports events without a summary event") {
                            expect(testContext.eventReporter.isOnline) == true
                            expect(testContext.eventReporter.isReportingActive) == true
                            expect(testContext.serviceMock.publishEventDictionariesCallCount) == 1
                            expect(testContext.serviceMock.publishedEventDictionaries?.count) == Event.Kind.nonSummaryKinds.count
                            expect(testContext.serviceMock.publishedEventDictionaryKeys) == testContext.eventKeys //summary events have no key, this verifies non-summary events
                            expect(testContext.serviceMock.publishedEventDictionaryKinds?.contains(.summary)) == false
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
                            expect(testContext.eventReporter.lastEventResponseDate) == testContext.eventStubResponseDate
                            expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                        }
                    }
                    context("with tracked requests only") {
                        beforeEach {
                            //The EventReporter will try to report events if it's started online with events. By starting online without events, then adding them, we "beat the timer" by reporting them right away
                            testContext = TestContext(eventStubResponseDate: eventStubResponseDate)
                            testContext.eventReporter.isOnline = true
                            testContext.flagRequestTracker = FlagRequestTracker.stub()
                            testContext.eventReporter.setFlagRequestTracker(testContext.flagRequestTracker!)

                            waitUntil { done in
                                testContext.eventReporter.reportEvents(completion: done)
                            }
                        }
                        it("reports only a summary event") {
                            expect(testContext.eventReporter.isOnline) == true
                            expect(testContext.eventReporter.isReportingActive) == true
                            expect(testContext.serviceMock.publishEventDictionariesCallCount) == 1
                            expect(testContext.serviceMock.publishedEventDictionaries?.count) == 1
                            expect(testContext.serviceMock.publishedEventDictionaryKinds?.contains(.summary)) == true
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
                            expect(testContext.eventReporter.lastEventResponseDate) == testContext.eventStubResponseDate
                            expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                        }
                    }
                    context("without events or tracked requests") {
                        beforeEach {
                            testContext = TestContext(eventStubResponseDate: eventStubResponseDate)
                            testContext.eventReporter.isOnline = true
                        }
                        it("does not report events") {
                            expect(testContext.eventReporter.isOnline) == true
                            expect(testContext.eventReporter.isReportingActive) == true
                            expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
                            expect(testContext.eventReporter.lastEventResponseDate).to(beNil())
                            expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                        }
                    }
                }
                context("failure") {
                    context("server error") {
                        beforeEach {
                            testContext = TestContext(stubResponseSuccess: false, eventStubResponseDate: eventStubResponseDate)
                            testContext.eventReporter.isOnline = true
                            waitUntil { done in
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count, completion: done)
                            }
                            testContext.flagRequestTracker = FlagRequestTracker.stub()
                            testContext.eventReporter.setFlagRequestTracker(testContext.flagRequestTracker!)

                            waitUntil { done in
                                testContext.eventReporter.reportEvents(completion: done)
                            }
                        }
                        it("retains reported events after the failure") {
                            expect(testContext.eventReporter.isOnline) == true
                            expect(testContext.eventReporter.isReportingActive) == true
                            expect(testContext.serviceMock.publishEventDictionariesCallCount) == 1
                            expect(testContext.eventReporter.eventStoreKeys) == testContext.eventKeys
                            expect(testContext.eventReporter.eventStoreKinds.contains(.summary)) == true
                            expect(testContext.serviceMock.publishedEventDictionaryKeys) == testContext.eventKeys
                            expect(testContext.serviceMock.publishedEventDictionaryKinds?.contains(.summary)) == true
                            expect(testContext.eventReporter.lastEventResponseDate).to(beNil())
                            expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                        }
                    }
                    context("response only") {
                        beforeEach {
                            testContext = TestContext(stubResponseSuccess: false, stubResponseOnly: true, eventStubResponseDate: eventStubResponseDate)
                            testContext.eventReporter.isOnline = true
                            waitUntil { done in
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count, completion: done)
                            }
                            testContext.flagRequestTracker = FlagRequestTracker.stub()
                            testContext.eventReporter.setFlagRequestTracker(testContext.flagRequestTracker!)

                            waitUntil { done in
                                testContext.eventReporter.reportEvents(completion: done)
                            }
                        }
                        it("retains reported events after the failure") {
                            expect(testContext.eventReporter.isOnline) == true
                            expect(testContext.eventReporter.isReportingActive) == true
                            expect(testContext.serviceMock.publishEventDictionariesCallCount) == 1
                            expect(testContext.eventReporter.eventStoreKeys) == testContext.eventKeys
                            expect(testContext.eventReporter.eventStoreKinds.contains(.summary)) == true
                            expect(testContext.serviceMock.publishedEventDictionaryKeys) == testContext.eventKeys
                            expect(testContext.serviceMock.publishedEventDictionaryKinds?.contains(.summary)) == true
                            expect(testContext.eventReporter.lastEventResponseDate).to(beNil())
                            expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                        }
                    }
                    context("error only") {
                        beforeEach {
                            testContext = TestContext(stubResponseSuccess: false, stubResponseErrorOnly: true, eventStubResponseDate: eventStubResponseDate)
                            testContext.eventReporter.isOnline = true
                            waitUntil { done in
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count, completion: done)
                            }
                            testContext.flagRequestTracker = FlagRequestTracker.stub()
                            testContext.eventReporter.setFlagRequestTracker(testContext.flagRequestTracker!)

                            waitUntil { done in
                                testContext.eventReporter.reportEvents(completion: done)
                            }
                        }
                        it("retains reported events after the failure") {
                            expect(testContext.eventReporter.isOnline) == true
                            expect(testContext.eventReporter.isReportingActive) == true
                            expect(testContext.serviceMock.publishEventDictionariesCallCount) == 1
                            expect(testContext.eventReporter.eventStoreKeys) == testContext.eventKeys
                            expect(testContext.eventReporter.eventStoreKinds.contains(.summary)) == true
                            expect(testContext.serviceMock.publishedEventDictionaryKeys) == testContext.eventKeys
                            expect(testContext.serviceMock.publishedEventDictionaryKinds?.contains(.summary)) == true
                            expect(testContext.eventReporter.lastEventResponseDate).to(beNil())
                            expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                        }
                    }
                }
            }
            context("offline") {
                beforeEach {
                    testContext = TestContext(eventStubResponseDate: eventStubResponseDate)
                    waitUntil { done in
                        testContext.recordEvents(Event.Kind.nonSummaryKinds.count, completion: done)
                    }
                    testContext.flagRequestTracker = FlagRequestTracker.stub()
                    testContext.eventReporter.setFlagRequestTracker(testContext.flagRequestTracker!)

                    waitUntil { done in
                        testContext.eventReporter.reportEvents(completion: done)
                    }
                }
                it("doesn't report events") {
                    expect(testContext.eventReporter.isOnline) == false
                    expect(testContext.eventReporter.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
                    expect(testContext.eventReporter.eventStoreKeys) == testContext.eventKeys
                    expect(testContext.eventReporter.eventStoreKinds.contains(.summary)) == false
                    expect(testContext.eventReporter.lastEventResponseDate).to(beNil())
                    expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == true
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
        context("record feature and debug events") {
            context("when trackEvents is on") {
                beforeEach {
                    testContext = TestContext(trackEvents: true)

                    waitUntil { done in
                        testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                             value: testContext.featureFlag.value!,
                                                                             defaultValue: Constants.defaultValue,
                                                                             featureFlag: testContext.featureFlag,
                                                                             user: testContext.user,
                                                                             completion: done)
                    }
                }
                it("records a feature event") {
                    expect(testContext.eventReporter.eventStore.count) == 1
                    expect(testContext.eventReporter.eventStoreKeys.contains(testContext.flagKey)).to(beTrue())
                    expect(testContext.eventReporter.eventStoreKinds.contains(.feature)).to(beTrue())
                }
            }
            context("when trackEvents is off") {
                beforeEach {
                    testContext = TestContext(trackEvents: false)

                    waitUntil { done in
                        testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                             value: testContext.featureFlag.value!,
                                                                             defaultValue: Constants.defaultValue,
                                                                             featureFlag: testContext.featureFlag,
                                                                             user: testContext.user,
                                                                             completion: done)
                    }
                }
                it("does not record a feature event") {
                    expect(testContext.eventReporter.eventStore).to(beEmpty())
                }
            }
            context("when debugEventsUntilDate exists") {
                context("lastEventResponseDate exists") {
                    context("and debugEventsUntilDate is later") {
                        beforeEach {
                            testContext = TestContext(lastEventResponseDate: Date(), trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(TimeInterval.oneSecond))

                            waitUntil { done in
                                testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey, value: testContext.featureFlag.value!, defaultValue: Constants.defaultValue, featureFlag: testContext.featureFlag, user: testContext.user, completion: done)
                            }
                        }
                        it("records a debug event") {
                            expect(testContext.eventReporter.eventStore.count) == 1
                            expect(testContext.eventReporter.eventStoreKeys.contains(testContext.flagKey)).to(beTrue())
                            expect(testContext.eventReporter.eventStoreKinds.contains(.debug)).to(beTrue())
                        }
                    }
                    context("and debugEventsUntilDate is earlier") {
                        beforeEach {
                            testContext = TestContext(lastEventResponseDate: Date(), trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(-TimeInterval.oneSecond))

                            waitUntil { done in
                                testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey, value: testContext.featureFlag.value!, defaultValue: Constants.defaultValue, featureFlag: testContext.featureFlag, user: testContext.user, completion: done)
                            }
                        }
                        it("does not record a debug event") {
                            expect(testContext.eventReporter.eventStore).to(beEmpty())
                        }
                    }
                }
                context("lastEventResponseDate is nil") {
                    context("and debugEventsUntilDate is later than current time") {
                        beforeEach {
                            testContext = TestContext(lastEventResponseDate: nil, trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(TimeInterval.oneSecond))

                            waitUntil { done in
                                testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey, value: testContext.featureFlag.value!, defaultValue: Constants.defaultValue, featureFlag: testContext.featureFlag, user: testContext.user, completion: done)
                            }
                        }
                        it("records a debug event") {
                            expect(testContext.eventReporter.eventStore.count) == 1
                            expect(testContext.eventReporter.eventStoreKeys.contains(testContext.flagKey)).to(beTrue())
                            expect(testContext.eventReporter.eventStoreKinds.contains(.debug)).to(beTrue())
                        }
                    }
                    context("and debugEventsUntilDate is earlier than current time") {
                        beforeEach {
                            testContext = TestContext(lastEventResponseDate: nil, trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(-TimeInterval.oneSecond))

                            waitUntil { done in
                                testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey, value: testContext.featureFlag.value!, defaultValue: Constants.defaultValue, featureFlag: testContext.featureFlag, user: testContext.user, completion: done)
                            }
                        }
                        it("does not record a debug event") {
                            expect(testContext.eventReporter.eventStore).to(beEmpty())
                        }
                    }
                }
            }
            context("when both trackEvents is true and debugEventsUntilDate is later than lastEventResponseDate") {
                beforeEach {
                    testContext = TestContext(lastEventResponseDate: Date(), trackEvents: true, debugEventsUntilDate: Date().addingTimeInterval(TimeInterval.oneSecond))

                    waitUntil { done in
                        testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey, value: testContext.featureFlag.value!, defaultValue: Constants.defaultValue, featureFlag: testContext.featureFlag, user: testContext.user, completion: done)
                    }
                }
                it("records a feature and debug event") {
                    expect(testContext.eventReporter.eventStore.count == 2).to(beTrue())
                    expect(testContext.eventReporter.eventStoreKeys.filter { (eventKey) in eventKey == testContext.flagKey }.count == 2).to(beTrue())
                    expect(Set(testContext.eventReporter.eventStore.eventKinds)).to(equal(Set([.feature, .debug])))
                }
            }
            context("when debugEventsUntilDate is nil") {
                beforeEach {
                    testContext = TestContext(lastEventResponseDate: Date(), trackEvents: false, debugEventsUntilDate: nil)

                    waitUntil { done in
                        testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey, value: testContext.featureFlag.value!, defaultValue: Constants.defaultValue, featureFlag: testContext.featureFlag, user: testContext.user, completion: done)
                    }
                }
                it("does not record an event") {
                    expect(testContext.eventReporter.eventStore).to(beEmpty())
                }
            }
            context("when eventTrackingContext is nil") {
                beforeEach {
                    testContext = TestContext(trackEvents: nil)

                    waitUntil { done in
                        testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                             value: testContext.featureFlag.value!,
                                                                             defaultValue: Constants.defaultValue,
                                                                             featureFlag: testContext.featureFlag,
                                                                             user: testContext.user,
                                                                             completion: done)
                    }
                }
                it("does not record an event") {
                    expect(testContext.eventReporter.eventStore).to(beEmpty())
                }
            }
        }
    }

    private func trackFlagRequestSpec() {
        context("record summary event") {
            var testContext: TestContext!
            var flagKey: LDFlagKey!
            var featureFlag: FeatureFlag!
            beforeEach {
                testContext = TestContext()
                flagKey = DarklyServiceMock.FlagKeys.dictionary
                featureFlag =  DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey)

                testContext.eventReporter.recordFlagEvaluationEvents(flagKey: flagKey, value: featureFlag.value, defaultValue: featureFlag.value, featureFlag: featureFlag, user: testContext.user)
            }
            it("tracks flag requests") {
                let flagCounter = testContext.eventReporter.flagRequestTracker.flagCounters[flagKey]
                expect(flagCounter).toNot(beNil())
                expect(AnyComparer.isEqual(flagCounter?.defaultValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                expect(flagCounter?.flagValueCounters.count) == 1
                let flagValueCounter = flagCounter?.flagValueCounters.first
                expect(flagValueCounter).toNot(beNil())
                expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                expect(flagValueCounter?.featureFlag) == featureFlag
            }
        }
    }

    private func recordSummaryEventSpec() {
        describe("recordSummaryEvent") {
            var testContext: TestContext!
            context("with tracked requests") {
                beforeEach {
                    testContext = TestContext()
                    testContext.eventReporter.isOnline = true
                    testContext.flagRequestTracker = FlagRequestTracker.stub()  //Delay setting tracked requests to avoid triggering a reportEvents call
                    testContext.eventReporter.setFlagRequestTracker(testContext.flagRequestTracker!)

                    waitUntil { done in
                        testContext.eventReporter.recordSummaryEvent(completion: done)
                    }
                }
                it("records a summary event") {
                    expect(testContext.eventReporter.isOnline) == true
                    expect(testContext.eventReporter.isReportingActive) == true
                    expect(testContext.eventReporter.eventStore.count) == 1
                    expect(testContext.eventReporter.eventStoreKinds.contains(.summary)) == true
                    expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                }
            }
            context("without tracked requests") {
                beforeEach {
                    testContext = TestContext()
                    testContext.eventReporter.isOnline = true

                    waitUntil { done in
                        testContext.eventReporter.recordSummaryEvent(completion: done)
                    }
                }
                it("does not record a summary event") {
                    expect(testContext.eventReporter.isOnline) == true
                    expect(testContext.eventReporter.isReportingActive) == true
                    expect(testContext.eventReporter.eventStore.count) == 0
                    expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                }
            }
        }
    }

    private func resetFlagRequestTrackerSpec() {
        describe("resetFlagRequestTracker") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext(flagRequestTracker: FlagRequestTracker.stub())

                testContext.eventReporter.resetFlagRequestTracker()
            }
            it("resets the flagRequestTracker") {
                expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
            }
        }
    }

    private func reportTimerSpec() {
        describe("report timer fires") {
            var testContext: TestContext!
            context("with events") {
                beforeEach {
                    testContext = TestContext(eventFlushMillis: Constants.eventFlushInterval500Millis)
                    testContext.eventReporter.isOnline = true
                    waitUntil { done in
                        testContext.recordEvents(Event.Kind.allKinds.count, completion: done)
                    }
                }
                it("reports events") {
                    expect(testContext.serviceMock.publishEventDictionariesCallCount).toEventually(equal(1))
                    expect(testContext.serviceMock.publishedEventDictionaries?.count).toEventually(equal(testContext.events.count))
                    expect(testContext.serviceMock.publishedEventDictionaryKeys).toEventually(equal(testContext.eventKeys))
                    expect( testContext.eventReporter.eventStore.isEmpty).toEventually(beTrue())
                }
            }
            context("without events") {
                beforeEach {
                    testContext = TestContext(eventFlushMillis: Constants.eventFlushInterval500Millis)
                    testContext.eventReporter.isOnline = true
                }
                it("doesn't report events") {
                    waitUntil { (done) in
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(Constants.eventFlushInterval500Millis)) {
                            expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
                            done()
                        }
                    }
                }
            }
        }
    }
}

extension EventReporter {
    var eventStoreKeys: [String] {
        return eventStore.flatMap { (eventDictionary) in return eventDictionary.eventKey }
    }
    var eventStoreKinds: [Event.Kind] {
        return eventStore.flatMap { (eventDictionary) in return eventDictionary.eventKind }
    }
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
    static var nonSummaryKinds: [Event.Kind] { return [feature, debug, identify, custom] }
}
