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
        static let eventCapacity = 3
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
        var flagKey: LDFlagKey!
        var eventTrackingContext: EventTrackingContext!
        var featureFlag: FeatureFlag!

        init(eventCount: Int = 0, eventFlushMillis: Int? = nil, stubResponseSuccess: Bool = true, stubResponseOnly: Bool = false, stubResponseErrorOnly: Bool = false, trackEvents: Bool? = true) {
            config = LDConfig.stub
            config.eventCapacity = Constants.eventCapacity
            config.eventFlushIntervalMillis = eventFlushMillis ?? Constants.eventFlushIntervalMillis

            user = LDUser.stub()

            serviceMock = DarklyServiceMock()
            serviceMock.stubEventResponse(success: stubResponseSuccess, responseOnly: stubResponseOnly, errorOnly: stubResponseErrorOnly)

            events = []
            while events.count < eventCount {
                let event = Event.stub(Event.eventKind(for: events.count), with: user)
                events.append(event)
            }

            eventReporter = EventReporter(config: config, service: serviceMock, events: events)

            flagKey = UUID().uuidString
            if let trackEvents = trackEvents {
                eventTrackingContext = EventTrackingContext(trackEvents: trackEvents)
            }
            featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, eventTrackingContext: eventTrackingContext)
        }

        mutating func recordEvents(_ eventCount: Int, completion: CompletionClosure? = nil) {
            guard eventCount > 0 else {
                completion?()
                return
            }
            while events.count < eventCount {
                let event = Event.stub(Event.eventKind(for: events.count), with: user)
                events.append(event)
                eventReporter.record(event, completion: events.count == eventCount ? completion : nil)
            }
        }
    }
    
    override func spec() {
        initSpec()
        isOnlineSpec()
        changeConfigSpec()
        recordEventSpec()
        reportEventsSpec()
        recordFlagEvalutaionEventsSpec()
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
                        testContext = TestContext(eventCount: Constants.eventCapacity)

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
                    testContext = TestContext(eventCount: Constants.eventCapacity)

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
                        testContext.recordEvents(Constants.eventCapacity, completion: done) // Stub events, call testContext.eventReporter.recordEvent, and keeps them in testContext.events
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
                    testContext = TestContext(eventCount: Constants.eventCapacity)
                    extraEvent = Event.stub(.feature, with: testContext.user)

                    testContext.eventReporter.record(extraEvent)
                }
                it("doesn't record any more events") {
                    expect(testContext.eventReporter.isOnline) == false
                    expect(testContext.eventReporter.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
                    expect(testContext.eventReporter.eventStoreKeys) == testContext.eventKeys
                    expect(testContext.eventReporter.eventStoreKeys.contains(extraEvent.key)) == false
                }
            }
        }
    }

    private func reportEventsSpec() {
        describe("reportEvents") {
            var testContext: TestContext!
            context("online") {
                context("success") {
                    beforeEach {
                        //The EventReporter will try to report events if it's started online with events. By starting online without events, then adding them, we "beat the timer" by reporting them right away
                        testContext = TestContext()
                        testContext.eventReporter.isOnline = true
                        waitUntil { done in
                            testContext.recordEvents(Constants.eventCapacity, completion: done)
                        }

                        testContext.eventReporter.reportEvents()
                    }
                    it("reports events") {
                        expect(testContext.eventReporter.isOnline) == true
                        expect(testContext.eventReporter.isReportingActive) == true
                        expect(testContext.serviceMock.publishEventDictionariesCallCount) == 1
                        expect(testContext.serviceMock.publishedEventDictionaryKeys) == testContext.eventKeys
                        expect(testContext.eventReporter.eventStore.isEmpty).toEventually(beTrue())  //event processing is async
                    }
                }
                context("failure") {
                    beforeEach {
                        testContext = TestContext(stubResponseSuccess: false)
                        testContext.eventReporter.isOnline = true
                        waitUntil { done in
                            testContext.recordEvents(Constants.eventCapacity, completion: done)
                        }

                        testContext.eventReporter.reportEvents()
                    }
                    it("retains reported events after the failure") {
                        expect(testContext.eventReporter.isOnline) == true
                        expect(testContext.eventReporter.isReportingActive) == true
                        expect(testContext.serviceMock.publishEventDictionariesCallCount) == 1
                        expect(testContext.eventReporter.eventStoreKeys) == testContext.eventKeys
                        expect(testContext.serviceMock.publishedEventDictionaryKeys) == testContext.eventKeys
                    }
                }
                context("failure - response only") {
                    beforeEach {
                        testContext = TestContext(stubResponseSuccess: false, stubResponseOnly: true)
                        testContext.eventReporter.isOnline = true
                        waitUntil { done in
                            testContext.recordEvents(Constants.eventCapacity, completion: done)
                        }

                        testContext.eventReporter.reportEvents()
                    }
                    it("retains reported events after the failure") {
                        expect(testContext.eventReporter.isOnline) == true
                        expect(testContext.eventReporter.isReportingActive) == true
                        expect(testContext.serviceMock.publishEventDictionariesCallCount) == 1
                        expect(testContext.eventReporter.eventStoreKeys) == testContext.eventKeys
                        expect(testContext.serviceMock.publishedEventDictionaryKeys) == testContext.eventKeys
                    }
                }
                context("failure - error only") {
                    beforeEach {
                        testContext = TestContext(stubResponseSuccess: false, stubResponseErrorOnly: true)
                        testContext.eventReporter.isOnline = true
                        waitUntil { done in
                            testContext.recordEvents(Constants.eventCapacity, completion: done)
                        }

                        testContext.eventReporter.reportEvents()
                    }
                    it("retains reported events after the failure") {
                        expect(testContext.eventReporter.isOnline) == true
                        expect(testContext.eventReporter.isReportingActive) == true
                        expect(testContext.serviceMock.publishEventDictionariesCallCount) == 1
                        expect(testContext.eventReporter.eventStoreKeys) == testContext.eventKeys
                        expect(testContext.serviceMock.publishedEventDictionaryKeys) == testContext.eventKeys
                    }
                }
            }
            context("offline") {
                beforeEach {
                    testContext = TestContext(eventCount: Constants.eventCapacity)

                    testContext.eventReporter.reportEvents()
                }
                it("doesn't report events") {
                    expect(testContext.eventReporter.isOnline) == false
                    expect(testContext.eventReporter.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
                    expect(testContext.eventReporter.eventStoreKeys) == testContext.eventKeys
                }
            }
        }
    }

    private func recordFlagEvalutaionEventsSpec() {
        var testContext: TestContext!
        describe("recordFlagEvaluationEvents") {
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
                    expect(testContext.eventReporter.eventStoreKeys.contains(testContext.flagKey)).to(beTrue())
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
                    expect(testContext.eventReporter.eventStoreKeys.contains(testContext.flagKey)).to(beFalse())
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
                it("does not record a feature event") {
                    expect(testContext.eventReporter.eventStoreKeys.contains(testContext.flagKey)).to(beFalse())
                }
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
                        testContext.recordEvents(Constants.eventCapacity, completion: done)
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
}
