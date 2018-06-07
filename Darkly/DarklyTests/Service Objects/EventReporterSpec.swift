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
    }
    
    var subject: EventReporter!
    var user: LDUser!
    var mockService: DarklyServiceMock!
    var mockEvents: [Event]!

    private func setupReporter(withEvents eventCount: Int = 0, eventFlushMillis: Int? = nil) {
        var config = LDConfig.stub
        config.eventCapacity = Constants.eventCapacity
        config.eventFlushIntervalMillis = eventFlushMillis ?? Constants.eventFlushIntervalMillis

        user = LDUser.stub()
        
        subject = EventReporter(config: config, service: mockService)
        waitUntil { done in
            self.recordEvents(eventCount, completion: done)
        }
    }
    
    override func spec() {
        beforeEach {
            self.mockService = DarklyServiceMock()
            self.mockService.stubEventResponse(success: true)
            self.mockEvents = []
        }
        describe("init") {
            context("without events") {
                beforeEach {
                    self.setupReporter()
                }
                it("starts offline without reporting events") {
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0) }).to(match())
                }
            }
        }

        describe("isOnline") {
            context("online to offline") {
                beforeEach {
                    self.setupReporter()
                    self.subject.isOnline = true

                    self.subject.isOnline = false
                }
                it("goes offline and stops reporting") {
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0) }).to(match())
                }
            }
            context("offline to online") {
                context("with events") {
                    beforeEach {
                        self.setupReporter(withEvents: Constants.eventCapacity)

                        self.subject.isOnline = true
                    }
                    it("goes online and starts reporting") {
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 1, publishedEvents: self.mockEvents) }).to(match())
                        expect(self.subject.eventStore.isEmpty).toEventually(beTrue())  //event processing is asynchronous
                    }
                }
                context("without events") {
                    beforeEach {
                        self.setupReporter()
                        self.subject.isOnline = true
                    }
                    it("goes online and starts reporting") {
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())
                    }
                }
            }
            context("online to online") {
                beforeEach {
                    self.setupReporter()
                    self.subject.isOnline = true

                    self.subject.isOnline = true
                }
                it("stays online and continues reporting") {
                    expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())
                }
            }
            context("offline to offline") {
                beforeEach {
                    self.setupReporter(withEvents: Constants.eventCapacity)

                    self.subject.isOnline = false
                }
                it("stays offline and does not start reporting") {
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0, recordedEvents: self.mockEvents) }).to(match())
                }
            }
        }

        describe("change config") {
            var config: LDConfig!
            beforeEach {
                self.setupReporter()
                config = LDConfig.stub
                config.streamingMode = .polling //using this to verify the config was changed...could be any value different from the setup
            }
            context("while offline") {
                beforeEach {
                    self.subject.config = config
                }
                it("changes the config") {
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0) }).to(match())
                    expect(self.subject.config.streamingMode) == config.streamingMode
                }
            }
            context("while online") {
                beforeEach {
                    self.subject.isOnline = true

                    self.subject.config = config
                }
                it("takes the reporter offline and changes the config") {
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0) }).to(match())
                    expect(self.subject.config.streamingMode) == config.streamingMode
                }
            }
        }

        describe("recordEvent") {
            context("event store empty") {
                beforeEach {
                    self.setupReporter()   //side-effect is mockEvents is also reset...do this before creating events

                    waitUntil { done in
                        self.recordEvents(Constants.eventCapacity, completion: done)
                    }
                }
                it("records events up to event capacity") {
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0) }).to(match())
                    let eventStoreKeys = self.subject.eventStore.flatMap { (eventDictionary) in eventDictionary[Event.CodingKeys.key.rawValue] as? String }
                    let mockEventKeys = self.mockEvents.map { (event) in event.key }
                    expect(eventStoreKeys) == mockEventKeys
                }
            }
            context("event store full") {
                var extraEvent: Event!
                beforeEach {
                    self.setupReporter(withEvents: Constants.eventCapacity)
                    extraEvent = Event.stub(for: .feature, with: self.user)

                    self.subject.record(extraEvent)
                }
                it("doesn't record any more events") {
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0, recordedEvents: self.mockEvents) }).to(match())
                    let eventStoreKeys = self.subject.eventStore.flatMap { (eventDictionary) in eventDictionary[Event.CodingKeys.key.rawValue] as? String }
                    expect(eventStoreKeys.contains(extraEvent.key)) == false
                }
            }
        }
        
        describe("reportEvents") {
            context("online") {
                context("success") {
                    beforeEach {
                        //The EventReporter will try to report events if it's started online with events. By starting online without events, then adding them, we "beat the timer" by reporting them right away
                        self.setupReporter()
                        self.subject.isOnline = true

                        waitUntil { done in
                            self.recordEvents(Constants.eventCapacity, completion: done)
                        }

                        self.subject.reportEvents()
                    }
                    it("reports events") {
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 1, publishedEvents: self.mockEvents) }).to(match())
                        expect(self.subject.eventStore.isEmpty).toEventually(beTrue())  //event processing is async
                    }
                }
                context("failure") {
                    beforeEach {
                        self.mockService.stubEventResponse(success: false)
                        self.setupReporter()
                        self.subject.isOnline = true

                        waitUntil { done in
                            self.recordEvents(Constants.eventCapacity, completion: done)
                        }

                        self.subject.reportEvents()
                    }
                    it("reports events") {
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 1, recordedEvents: self.mockEvents, publishedEvents: self.mockEvents) }).to(match())
                    }
                }
                context("failure - response only") {
                    beforeEach {
                        self.mockService.stubEventResponse(success: false, responseOnly: true)
                        self.setupReporter()
                        self.subject.isOnline = true

                        waitUntil { done in
                            self.recordEvents(Constants.eventCapacity, completion: done)
                        }

                        self.subject.reportEvents()
                    }
                    it("reports events") {
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 1, recordedEvents: self.mockEvents, publishedEvents: self.mockEvents) }).to(match())
                    }
                }
                context("failure - error only") {
                    beforeEach {
                        self.mockService.stubEventResponse(success: false, errorOnly: true)
                        self.setupReporter()
                        self.subject.isOnline = true

                        waitUntil { done in
                            self.recordEvents(Constants.eventCapacity, completion: done)
                        }

                        self.subject.reportEvents()
                    }
                    it("reports events") {
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 1, recordedEvents: self.mockEvents, publishedEvents: self.mockEvents) }).to(match())
                    }
                }
            }
            context("offline") {
                beforeEach {
                    self.setupReporter(withEvents: Constants.eventCapacity)

                    self.subject.reportEvents()
                }
                it("doesn't report events") {
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0, recordedEvents: self.mockEvents) }).to(match())
                }
            }
        }
        
        describe("report timer fires") {
            context("with events") {
                beforeEach {
                    self.setupReporter(eventFlushMillis: Constants.eventFlushInterval500Millis)
                    self.subject.isOnline = true

                    waitUntil { done in
                        self.recordEvents(Constants.eventCapacity, completion: done)
                    }
                }
                it("reports events") {
                    expect(self.mockService.publishEventDictionariesCallCount).toEventually(equal(1))
                    expect(self.mockService.publishedEventDictionaries?.count).toEventually(equal(self.mockEvents.count))
                    expect(self.mockService.publishedEventDictionaryKeys).toEventually(equal(self.mockEvents.map { (event) in event.key }))
                    expect(self.subject.eventStore.isEmpty).toEventually(beTrue())
                }
            }
            context("without events") {
                beforeEach {
                    self.setupReporter(eventFlushMillis: Constants.eventFlushInterval500Millis)
                    self.subject.isOnline = true
                }
                it("doesn't report events") {
                    waitUntil { (done) in
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(Constants.eventFlushInterval500Millis)) {
                            expect(self.mockService.publishEventDictionariesCallCount) == 0
                            done()
                        }
                    }
                }
            }
        }
    }
    
    private func recordEvents(_ eventCount: Int, completion: CompletionClosure? = nil) {
        guard eventCount > 0 else {
            completion?()
            return
        }
        while mockEvents.count < eventCount {
            let event = Event.stub(for: Event.eventType(for: mockEvents.count), with: self.user)
            mockEvents.append(event)
            subject.record(event, completion: mockEvents.count == eventCount ? completion : nil)
        }
    }
    
    private func reporterState(isOnline: Bool, isReporting: Bool, reportTries: Int, recordedEvents: [Event]? = nil, publishedEvents: [Event]? = nil) -> ToMatchResult {
        var messages = [String]()
        if self.subject.isOnline != isOnline { messages.append("isOnline equals \(self.subject.isOnline)") }
        if self.subject.isReportingActive != isReporting { messages.append("isReportingActive equals \(self.subject.isReportingActive)") }
        if self.mockService.publishEventDictionariesCallCount != reportTries { messages.append("reportTries equals \(self.mockService.publishEventDictionariesCallCount)") }
        if let recordedEvents = recordedEvents {
            if !self.subject.eventStore.matches(events: recordedEvents) {
                messages.append("recorded events don't match"
                    + (self.subject.eventStore.count != recordedEvents.count ? " (count mismatch eventStore=\(self.subject.eventStore.count) recordedEvents=\(recordedEvents.count)"
                        : "") )
            }
        }
        if let publishedEvents = publishedEvents {
            if let serviceEventDictionaries = self.mockService.publishedEventDictionaries {
                if !serviceEventDictionaries.matches(events: publishedEvents) {
                    messages.append("published events don't match"
                        + (serviceEventDictionaries.count != publishedEvents.count
                            ? " (count mismatch servicePublishedEvents=\(serviceEventDictionaries.count) publishedEvents=\(publishedEvents.count)"
                            : "") ) }
            } else {
                messages.append("published events is nil")
            }
        }
        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }
}

extension Event {
    static func stub(for eventType: Kind, with user: LDUser) -> Event {
        switch eventType {
        case .feature:
            let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, includeVariation: true, includeVersion: true)
            return Event.featureEvent(key: UUID().uuidString, user: user, value: true, defaultValue: false, featureFlag: featureFlag)
        case .identify: return Event.identifyEvent(user: user)
        case .custom: return Event.customEvent(key: UUID().uuidString, user: user, data: ["custom": UUID().uuidString])
        }
    }
    
    static func stubEvents(_ eventCount: Int, user: LDUser) -> [Event] {
        var eventStubs = [Event]()
        while eventStubs.count < eventCount {
            eventStubs.append(Event.stub(for: Event.eventType(for: eventStubs.count), with: user))
        }
        return eventStubs
    }

    static func eventType(for count: Int) -> Kind {
        let types: [Kind] = [.feature, .identify, .custom]
        return types[count % types.count]
    }

    static func stubEventDictionaries(_ eventCount: Int, user: LDUser, config: LDConfig) -> [[String: Any]] {
        let eventStubs = stubEvents(eventCount, user: user)
        return eventStubs.map { (event) in event.dictionaryValue(config: config) }
    }

    func matches(eventDictionary: [String: Any]?) -> Bool {
        guard let eventDictionary = eventDictionary,
            let eventDictionaryKey = eventDictionary.eventKey,
            let eventDictionaryCreationDateMillis = eventDictionary.eventCreationDateMillis
            else { return false }
        return key == eventDictionaryKey && creationDate.millisSince1970 == eventDictionaryCreationDateMillis
    }
}

extension Event.Kind {
    static var random: Event.Kind {
        let types: [Event.Kind] = [.feature, .identify, .custom]
        let index = Int(arc4random_uniform(2))
        return types[index]
    }
}

extension Array where Element == Event {
    func matches(eventDictionaries: [[String: Any]]) -> Bool {
        guard self.count == eventDictionaries.count else { return false }
        for index in self.indices {
            if !self[index].matches(eventDictionary: eventDictionaries[index]) { return false }
        }
        return true
    }
}

extension Array where Element == [String: Any] {
    func matches(events: [Event]) -> Bool {
        guard self.count == events.count else { return false }
        for index in self.indices {
            if !events[index].matches(eventDictionary: self[index]) { return false }
        }
        return true
    }
}
