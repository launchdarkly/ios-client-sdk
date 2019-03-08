//
//  EventReporterSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 9/26/17.
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
import XCTest
@testable import LaunchDarkly

final class EventReporterSpec: QuickSpec {
    struct Constants {
        static let eventFlushInterval: TimeInterval = 10.0
        static let eventFlushIntervalHalfSecond: TimeInterval = 0.5
        static let defaultValue = false
    }
    
    struct TestContext {
        var eventReporter: EventReporter!
        var config: LDConfig!
        var user: LDUser!
        var serviceMock: DarklyServiceMock!
        var events: [Event]!
        var eventKeys: [String]! {
            return events.compactMap { (event) in
                event.key
            }
        }
        var eventKinds: [Event.Kind]! {
            return events.compactMap { (event) in
                event.kind
            }
        }
        var lastEventResponseDate: Date?
        var flagKey: LDFlagKey!
        var eventTrackingContext: EventTrackingContext!
        var featureFlag: FeatureFlag!
        var eventStubResponseDate: Date?
        var flagRequestTracker: FlagRequestTracker?
        var reportersTracker: FlagRequestTracker? {
            return eventReporter.flagRequestTracker
        }
        var flagRequestCount: Int
        var syncResult: EventSyncResult? = nil

        init(eventCount: Int = 0,
             eventFlushInterval: TimeInterval? = nil,
             flagRequestCount: Int = 1,
             lastEventResponseDate: Date? = nil,
             stubResponseSuccess: Bool = true,
             stubResponseOnly: Bool = false,
             stubResponseErrorOnly: Bool = false,
             eventStubResponseDate: Date? = nil,
             trackEvents: Bool? = true,
             debugEventsUntilDate: Date? = nil,
             flagRequestTracker: FlagRequestTracker? = nil,
             onSyncComplete: EventSyncCompleteClosure? = nil) {

            config = LDConfig.stub
            config.eventCapacity = Event.Kind.allKinds.count
            config.eventFlushInterval = eventFlushInterval ?? Constants.eventFlushInterval

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
            eventReporter = EventReporter(config: config,
                                          service: serviceMock,
                                          events: events,
                                          lastEventResponseDate: self.lastEventResponseDate,
                                          flagRequestTracker: flagRequestTracker,
                                          onSyncComplete: onSyncComplete)

            flagKey = UUID().uuidString
            if let trackEvents = trackEvents {
                eventTrackingContext = EventTrackingContext(trackEvents: trackEvents)
            }
            if let debugEventsUntilDate = debugEventsUntilDate {
                eventTrackingContext = EventTrackingContext(trackEvents: self.eventTrackingContext?.trackEvents ?? false, debugEventsUntilDate: debugEventsUntilDate)
            }
            featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, eventTrackingContext: eventTrackingContext)
            self.flagRequestCount = flagRequestCount
        }

        mutating func recordEvents(_ eventCount: Int, completion: CompletionClosure? = nil) {
            guard eventCount > 0
            else {
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

        mutating func addEvents(_ eventCount: Int) {
            for _ in 0..<eventCount {
                let event = Event.stub(Event.eventKind(for: events.count), with: user)
                events.append(event)
            }
            eventReporter?.add(events)
        }

        func flagCounter(for key: LDFlagKey) -> FlagCounter? {
            return reportersTracker?.flagCounters[key]
        }

        func flagValueCounter(for key: LDFlagKey, and featureFlag: FeatureFlag?) -> FlagValueCounter? {
            return flagCounter(for: key)?.flagValueCounters.flagValueCounter(for: featureFlag)
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
        eventKeysSpec()
    }

    private func initSpec() {
        describe("init") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()

                testContext.eventReporter = EventReporter(config: testContext.config, service: testContext.serviceMock) { (_) in

                }
            }
            it("starts offline without reporting events") {
                expect(testContext.eventReporter.config) == testContext.config
                expect(testContext.eventReporter.service) === testContext.serviceMock
                expect(testContext.eventReporter.isOnline) == false
                expect(testContext.eventReporter.isReportingActive) == false
                expect(testContext.eventReporter.testOnSyncComplete).toNot(beNil())
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
                        expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
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
            afterEach {
                testContext.eventReporter.isOnline = false
            }
            context("online") {
                context("success") {
                    context("with events and tracked requests") {
                        beforeEach {
                            //The EventReporter will try to report events if it's started online with events. By starting online without events, then adding them, we "beat the timer" by reporting them right away
                            waitUntil { syncComplete in
                                testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { (result) in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventReporter.isOnline = true
                                testContext.addEvents(Event.Kind.nonSummaryKinds.count)
                                testContext.flagRequestTracker = FlagRequestTracker.stub()
                                testContext.eventReporter.setFlagRequestTracker(testContext.flagRequestTracker!)

                                testContext.eventReporter.reportEvents()
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
                            expect(testContext.syncResult) == .success(testContext.serviceMock.publishedEventDictionaries!)
                        }
                    }
                    context("with events only") {
                        beforeEach {
                            //The EventReporter will try to report events if it's started online with events. By starting online without events, then adding them, we "beat the timer" by reporting them right away
                            waitUntil { syncComplete in
                                testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { (result) in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventReporter.isOnline = true
                                testContext.addEvents(Event.Kind.nonSummaryKinds.count)

                                testContext.eventReporter.reportEvents()
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
                            expect(testContext.syncResult) == .success(testContext.serviceMock.publishedEventDictionaries!)
                        }
                    }
                    context("with tracked requests only") {
                        beforeEach {
                            //The EventReporter will try to report events if it's started online with events. By starting online without events, then adding them, we "beat the timer" by reporting them right away
                            waitUntil { syncComplete in
                                testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { (result) in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventReporter.isOnline = true
                                testContext.flagRequestTracker = FlagRequestTracker.stub()
                                testContext.eventReporter.setFlagRequestTracker(testContext.flagRequestTracker!)

                                testContext.eventReporter.reportEvents()
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
                            expect(testContext.syncResult) == .success(testContext.serviceMock.publishedEventDictionaries!)
                        }
                    }
                    context("without events or tracked requests") {
                        beforeEach {
                            waitUntil { syncComplete in
                                testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { (result) in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventReporter.isOnline = true

                                testContext.eventReporter.reportEvents()
                            }
                        }
                        it("does not report events") {
                            expect(testContext.eventReporter.isOnline) == true
                            expect(testContext.eventReporter.isReportingActive) == true
                            expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
                            expect(testContext.eventReporter.eventStore.isEmpty) == true
                            expect(testContext.eventReporter.lastEventResponseDate).to(beNil())
                            expect(testContext.eventReporter.flagRequestTracker.hasLoggedRequests) == false
                            expect(testContext.syncResult) == .success([[String: Any]]())
                        }
                    }
                }
                context("failure") {
                    context("server error") {
                        beforeEach {
                            waitUntil { syncComplete in
                                testContext = TestContext(stubResponseSuccess: false, eventStubResponseDate: eventStubResponseDate, onSyncComplete: { (result) in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventReporter.isOnline = true
                                testContext.addEvents(Event.Kind.nonSummaryKinds.count)
                                testContext.flagRequestTracker = FlagRequestTracker.stub()
                                testContext.eventReporter.setFlagRequestTracker(testContext.flagRequestTracker!)

                                testContext.eventReporter.reportEvents()
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
                            expect(testContext.syncResult) == .error(.request(DarklyServiceMock.Constants.error))
                        }
                    }
                    context("response only") {
                        beforeEach {
                            waitUntil { syncComplete in
                                testContext = TestContext(stubResponseSuccess: false, stubResponseOnly: true, eventStubResponseDate: eventStubResponseDate, onSyncComplete: { (result) in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventReporter.isOnline = true
                                testContext.addEvents(Event.Kind.nonSummaryKinds.count)
                                testContext.flagRequestTracker = FlagRequestTracker.stub()
                                testContext.eventReporter.setFlagRequestTracker(testContext.flagRequestTracker!)

                                testContext.eventReporter.reportEvents()
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
                            expect(testContext.syncResult) == .error(.response(testContext.serviceMock.errorEventHTTPURLResponse))
                        }
                    }
                    context("error only") {
                        beforeEach {
                            waitUntil { syncComplete in
                                testContext = TestContext(stubResponseSuccess: false, stubResponseErrorOnly: true, eventStubResponseDate: eventStubResponseDate, onSyncComplete: { (result) in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventReporter.isOnline = true
                                testContext.addEvents(Event.Kind.nonSummaryKinds.count)
                                testContext.flagRequestTracker = FlagRequestTracker.stub()
                                testContext.eventReporter.setFlagRequestTracker(testContext.flagRequestTracker!)

                                testContext.eventReporter.reportEvents()
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
                            expect(testContext.syncResult) == .error(.request(DarklyServiceMock.Constants.error))
                        }
                    }
                }
            }
            context("offline") {
                beforeEach {
                    waitUntil { syncComplete in
                        testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { (result) in
                            testContext.syncResult = result
                            syncComplete()
                        })
                        testContext.addEvents(Event.Kind.nonSummaryKinds.count)
                        testContext.flagRequestTracker = FlagRequestTracker.stub()
                        testContext.eventReporter.setFlagRequestTracker(testContext.flagRequestTracker!)

                        testContext.eventReporter.reportEvents()
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
                    expect(testContext.syncResult) == .error(.isOffline)
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
                it("tracks the flag request") {
                    let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                    expect(flagValueCounter).toNot(beNil())
                    expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: testContext.featureFlag.value)).to(beTrue())
                    expect(flagValueCounter?.featureFlag) == testContext.featureFlag
                    expect(flagValueCounter?.isKnown) == true
                    expect(flagValueCounter?.count) == 1
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
                it("tracks the flag request") {
                    let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                    expect(flagValueCounter).toNot(beNil())
                    expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: testContext.featureFlag.value)).to(beTrue())
                    expect(flagValueCounter?.featureFlag) == testContext.featureFlag
                    expect(flagValueCounter?.isKnown) == true
                    expect(flagValueCounter?.count) == 1
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
                        it("tracks the flag request") {
                            let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                            expect(flagValueCounter).toNot(beNil())
                            expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: testContext.featureFlag.value)).to(beTrue())
                            expect(flagValueCounter?.featureFlag) == testContext.featureFlag
                            expect(flagValueCounter?.isKnown) == true
                            expect(flagValueCounter?.count) == 1
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
                        it("tracks the flag request") {
                            let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                            expect(flagValueCounter).toNot(beNil())
                            expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: testContext.featureFlag.value)).to(beTrue())
                            expect(flagValueCounter?.featureFlag) == testContext.featureFlag
                            expect(flagValueCounter?.isKnown) == true
                            expect(flagValueCounter?.count) == 1
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
                        it("tracks the flag request") {
                            let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                            expect(flagValueCounter).toNot(beNil())
                            expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: testContext.featureFlag.value)).to(beTrue())
                            expect(flagValueCounter?.featureFlag) == testContext.featureFlag
                            expect(flagValueCounter?.isKnown) == true
                            expect(flagValueCounter?.count) == 1
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
                        it("tracks the flag request") {
                            let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                            expect(flagValueCounter).toNot(beNil())
                            expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: testContext.featureFlag.value)).to(beTrue())
                            expect(flagValueCounter?.featureFlag) == testContext.featureFlag
                            expect(flagValueCounter?.isKnown) == true
                            expect(flagValueCounter?.count) == 1
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
                    expect(testContext.eventReporter.eventStoreKeys.filter { (eventKey) in
                        eventKey == testContext.flagKey
                        }.count == 2).to(beTrue())
                    expect(Set(testContext.eventReporter.eventStore.eventKinds)).to(equal(Set([.feature, .debug])))
                }
                it("tracks the flag request") {
                    let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                    expect(flagValueCounter).toNot(beNil())
                    expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: testContext.featureFlag.value)).to(beTrue())
                    expect(flagValueCounter?.featureFlag) == testContext.featureFlag
                    expect(flagValueCounter?.isKnown) == true
                    expect(flagValueCounter?.count) == 1
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
                it("tracks the flag request") {
                    let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                    expect(flagValueCounter).toNot(beNil())
                    expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: testContext.featureFlag.value)).to(beTrue())
                    expect(flagValueCounter?.featureFlag) == testContext.featureFlag
                    expect(flagValueCounter?.isKnown) == true
                    expect(flagValueCounter?.count) == 1
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
                it("tracks the flag request") {
                    let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                    expect(flagValueCounter).toNot(beNil())
                    expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: testContext.featureFlag.value)).to(beTrue())
                    expect(flagValueCounter?.featureFlag) == testContext.featureFlag
                    expect(flagValueCounter?.isKnown) == true
                    expect(flagValueCounter?.count) == 1
                }
            }
            context("when multiple flag requests are made") {
                context("serially") {
                    beforeEach {
                        testContext = TestContext(flagRequestCount: 3, trackEvents: false)

                        waitUntil { done in
                            for index in 1...testContext.flagRequestCount {
                                testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                                     value: testContext.featureFlag.value!,
                                                                                     defaultValue: Constants.defaultValue,
                                                                                     featureFlag: testContext.featureFlag,
                                                                                     user: testContext.user,
                                                                                     completion: index == testContext.flagRequestCount ? done : nil)
                            }
                        }
                    }
                    it("tracks the flag request") {
                        let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                        expect(flagValueCounter).toNot(beNil())
                        expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: testContext.featureFlag.value)).to(beTrue())
                        expect(flagValueCounter?.featureFlag) == testContext.featureFlag
                        expect(flagValueCounter?.isKnown) == true
                        expect(flagValueCounter?.count) == testContext.flagRequestCount
                    }
                }
                context("concurrently") {
                    let requestQueue = DispatchQueue(label: "com.launchdarkly.test.eventReporterSpec.flagRequestTracking.concurrent", qos: .userInitiated, attributes: .concurrent)
                    var recordFlagEvaluationCompletionCallCount = 0
                    var recordFlagEvaluationCompletion: (() -> Void)!
                    beforeEach {
                        testContext = TestContext(flagRequestCount: 5, trackEvents: false)

                        waitUntil { done in
                            recordFlagEvaluationCompletion = {
                                DispatchQueue.main.async {
                                    recordFlagEvaluationCompletionCallCount += 1
                                    if recordFlagEvaluationCompletionCallCount == testContext.flagRequestCount {
                                        done()
                                    }
                                }
                            }
                            let fireTime = DispatchTime.now() + 0.1
                            for _ in 1...testContext.flagRequestCount {
                                requestQueue.asyncAfter(deadline: fireTime) {
                                    testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey,
                                                                                         value: testContext.featureFlag.value!,
                                                                                         defaultValue: Constants.defaultValue,
                                                                                         featureFlag: testContext.featureFlag,
                                                                                         user: testContext.user,
                                                                                         completion: recordFlagEvaluationCompletion)
                                }
                            }
                        }
                    }
                    it("tracks the flag request") {
                        let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                        expect(flagValueCounter).toNot(beNil())
                        expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: testContext.featureFlag.value)).to(beTrue())
                        expect(flagValueCounter?.featureFlag) == testContext.featureFlag
                        expect(flagValueCounter?.isKnown) == true
                        expect(flagValueCounter?.count) == testContext.flagRequestCount
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

                waitUntil { done in
                    testContext.eventReporter.recordFlagEvaluationEvents(flagKey: testContext.flagKey, value: testContext.featureFlag.value, defaultValue: testContext.featureFlag.value, featureFlag: testContext.featureFlag, user: testContext.user, completion: done)
                }
            }
            it("tracks flag requests") {
                let flagCounter = testContext.flagCounter(for: testContext.flagKey)
                expect(flagCounter).toNot(beNil())
                expect(AnyComparer.isEqual(flagCounter?.defaultValue, to: testContext.featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                expect(flagCounter?.flagValueCounters.count) == 1

                let flagValueCounter = testContext.flagValueCounter(for: testContext.flagKey, and: testContext.featureFlag)
                expect(flagValueCounter).toNot(beNil())
                expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: testContext.featureFlag.value)).to(beTrue())
                expect(flagValueCounter?.featureFlag) == testContext.featureFlag
                expect(flagValueCounter?.isKnown) == true
                expect(flagValueCounter?.count) == testContext.flagRequestCount
            }
        }
    }

    private func recordSummaryEventSpec() {
        describe("recordSummaryEvent") {
            var testContext: TestContext!
            afterEach {
                testContext.eventReporter.isOnline = false
            }
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
            afterEach {
                testContext.eventReporter.isOnline = false
            }
            context("with events") {
                beforeEach {
                    testContext = TestContext(eventFlushInterval: Constants.eventFlushIntervalHalfSecond)
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
                    testContext = TestContext(eventFlushInterval: Constants.eventFlushIntervalHalfSecond)
                    testContext.eventReporter.isOnline = true
                }
                it("doesn't report events") {
                    waitUntil { (done) in
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Constants.eventFlushIntervalHalfSecond) {
                            expect(testContext.serviceMock.publishEventDictionariesCallCount) == 0
                            done()
                        }
                    }
                }
            }
        }
    }

    private func eventKeysSpec() {
        describe("eventKeys") {
            var testContext: TestContext!
            var eventKeys: String!
            context("when events exist") {
                beforeEach {
                    testContext = TestContext(eventCount: Event.Kind.allKinds.count)

                    eventKeys = testContext.eventReporter.eventStore.eventKeys
                }
                it("creates a list of keys that match the event keys") {
                    expect(eventKeys.isEmpty).to(beFalse())
                    expect(eventKeys.components(separatedBy: ", ").count) == Event.Kind.allKinds.count - 1  //summary events don't have a key
                    testContext.eventKeys.forEach { (eventKey) in
                        expect(eventKeys.contains(eventKey)).to(beTrue())
                    }
                }
            }
            context("when events do not exist") {
                beforeEach {
                    testContext = TestContext()

                    eventKeys = testContext.eventReporter.eventStore.eventKeys
                }
                it("returns an empty string") {
                    expect(eventKeys.isEmpty).to(beTrue())
                }
            }
        }
    }
}

extension EventReporter {
    var eventStoreKeys: [String] {
        return eventStore.compactMap { (eventDictionary) in
            return eventDictionary.eventKey
        }
    }
    var eventStoreKinds: [Event.Kind] {
        return eventStore.compactMap { (eventDictionary) in
            return eventDictionary.eventKind
        }
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
    static var nonSummaryKinds: [Event.Kind] {
        return [feature, debug, identify, custom]
    }
}

extension EventSyncResult: Equatable {
    public static func == (_ lhs: EventSyncResult, _ rhs: EventSyncResult) -> Bool {
        switch (lhs, rhs) {
        case (.success(let left), .success(let right)):
            return left == right
        case (.error(let left), .error(let right)):
            return left == right
        default: return false
        }
    }
}

extension Optional where Wrapped == EventSyncResult {
    public static func == (_ lhs: EventSyncResult?, _ rhs: EventSyncResult?) -> Bool {
        switch (lhs, rhs) {
        case (.some(let left), .some(let right)):
            return left == right
        case (.none, .none):
            return true
        default: return false
        }
    }
}

extension Array where Element == [String: Any] {
    static func == (_ lhs: [[String: Any]], _ rhs: [[String: Any]]) -> Bool {
        guard lhs.count == rhs.count
        else {
            return false
        }
        return lhs.filter { (leftEvent) in
            !rhs.contains(leftEvent)
        }.isEmpty
    }
}
