//
//  LDEventReporterSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 9/26/17.
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
import XCTest
@testable import Darkly

final class LDEventReporterSpec: QuickSpec {
    struct Constants {
        static let eventCapacity = 3
        static let eventFlushIntervalMillis = 10_000
        static let eventFlushInterval500Millis = 500
    }
    
    var subject: LDEventReporter!
    let mockMobileKey = "mockMobileKey"
    var config: LDConfig!
    var user: LDUser!
    var mockService: DarklyServiceMock!
    var mockEvents: [LDEvent]!

    private func setupReporter(online: Bool, withEvents eventCount: Int = 0, eventFlushMillis: Int? = nil) {
        config = LDConfig.stub
        config.eventCapacity = Constants.eventCapacity
        config.eventFlushIntervalMillis = eventFlushMillis ?? Constants.eventFlushIntervalMillis
        config.launchOnline = online
        
        user = LDUser()
        
        mockEvents = LDEvent.stubEvents(eventCount, user: user)
        
        subject = LDEventReporter(mobileKey: mockMobileKey, config: config, events: mockEvents, service: mockService)
    }
    
    //swiftlint:disable:next function_body_length
    override func spec() {
        beforeEach {
            self.mockService = DarklyServiceMock()
            self.mockService.stubEventResponse(success: true)
        }
        describe("init") {
            context("online - no events") {
                beforeEach {
                    self.setupReporter(online: true)
                }
                it("starts online without reporting events") {
                    expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())
                }
            }
            context("online - events") {
                beforeEach {
                    self.setupReporter(online: true, withEvents: Constants.eventCapacity)
                }
                it("starts online and reports events") {
                    expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 1) }).to(match())
                }
            }
            context("offline - no events") {
                beforeEach {
                    self.setupReporter(online: false)
                }
                it("starts offline without reporting events") {
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0) }).to(match())
                }
            }
            context("offline - events") {
                beforeEach {
                    self.setupReporter(online: false, withEvents: Constants.eventCapacity)
                }
                it("starts offline without reporting events") {
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0, recordedEvents: self.mockEvents) }).to(match())
                }
            }
        }
        describe("isOnline") {
            context("online to offline") {
                beforeEach {
                    self.setupReporter(online: true)
                    expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())

                    self.subject.isOnline = false
                }
                it("goes offline and stops reporting") {
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0) }).to(match())
                }
            }
            context("offline to online") {
                beforeEach {
                    self.setupReporter(online: false, withEvents: Constants.eventCapacity)
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0, recordedEvents: self.mockEvents) }).to(match())

                    self.subject.isOnline = true
                }
                it("goes online and starts reporting") {
                    expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 1, publishedEvents: self.mockEvents) }).to(match())
                    expect(self.subject.eventStore.isEmpty).toEventually(beTrue())  //event processing is asynchronous
                }
            }
            context("online to online") {
                beforeEach {
                    self.setupReporter(online: true)
                    expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())

                    self.subject.isOnline = true
                }
                it("stays online and continues reporting") {
                    expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())
                }
            }
            context("offline to offline") {
                beforeEach {
                    self.setupReporter(online: false, withEvents: Constants.eventCapacity)
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0, recordedEvents: self.mockEvents) }).to(match())

                    self.subject.isOnline = false
                }
                it("stays offline and does not start reporting") {
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0, recordedEvents: self.mockEvents) }).to(match())
                }
            }
        }

        describe("recordEvent") {
            context("event store empty") {
                beforeEach {
                    self.setupReporter(online: false)   //side-effect is mockEvents is also reset...do this before creating events
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0) }).to(match())

                    self.recordEvents(Constants.eventCapacity)
                }
                it("records events up to event capacity") {
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0) }).to(match())
                    expect(self.subject.eventStore).toEventually(equal(self.mockEvents))    //recordEvent is asynchronous
                }
            }
            context("event store full") {
                var extraEvent: LDEvent!
                beforeEach {
                    self.setupReporter(online: false, withEvents: Constants.eventCapacity)

                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0, recordedEvents: self.mockEvents) }).to(match())

                    extraEvent = LDEvent.stub(for: .identify, with: self.user)
                    self.subject.record(extraEvent)
                }
                it("doesn't record any more events") {
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0, recordedEvents: self.mockEvents) }).to(match())
                    expect(self.subject.eventStore.contains(extraEvent)) == false
                }
            }
        }
        
        describe("reportEvents") {
            context("online") {
                context("success") {
                    beforeEach {
                        //The LDEventReporter will try to report events if it's started online with events. By starting online without events, then adding them, we "beat the timer" by reporting them right away
                        self.setupReporter(online: true)
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())

                        self.recordEvents(Constants.eventCapacity)
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())
                        expect(self.subject.eventStore).toEventually(equal(self.mockEvents))    //recordEvent is async

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
                        self.setupReporter(online: true)
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())

                        self.recordEvents(Constants.eventCapacity)
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())
                        expect(self.subject.eventStore).toEventually(equal(self.mockEvents))    //recordEvent is async

                        self.subject.reportEvents()
                    }
                    it("reports events") {
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 1, recordedEvents: self.mockEvents, publishedEvents: self.mockEvents) }).to(match())
                    }
                }
                context("failure - response only") {
                    beforeEach {
                        self.mockService.stubEventResponse(success: false, responseOnly: true)
                        self.setupReporter(online: true)
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())

                        self.recordEvents(Constants.eventCapacity)
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())
                        expect(self.subject.eventStore).toEventually(equal(self.mockEvents))    //recordEvent is async

                        self.subject.reportEvents()
                    }
                    it("reports events") {
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 1, recordedEvents: self.mockEvents, publishedEvents: self.mockEvents) }).to(match())
                    }
                }
                context("failure - error only") {
                    beforeEach {
                        self.mockService.stubEventResponse(success: false, errorOnly: true)
                        self.setupReporter(online: true)
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())

                        self.recordEvents(Constants.eventCapacity)
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())
                        expect(self.subject.eventStore).toEventually(equal(self.mockEvents))    //recordEvent is async

                        self.subject.reportEvents()
                    }
                    it("reports events") {
                        expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 1, recordedEvents: self.mockEvents, publishedEvents: self.mockEvents) }).to(match())
                    }
                }
            }
            context("offline") {
                beforeEach {
                    self.setupReporter(online: false, withEvents: Constants.eventCapacity)
                    expect({ self.reporterState(isOnline: false, isReporting: false, reportTries: 0, recordedEvents: self.mockEvents) }).to(match())

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
                    self.setupReporter(online: true, eventFlushMillis: Constants.eventFlushInterval500Millis)
                    expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())

                    self.recordEvents(Constants.eventCapacity)
                    expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0) }).to(match())
                    expect(self.subject.eventStore).toEventually(equal(self.mockEvents))    //recordEvent is async
                }
                it("reports events") {
                    expect(self.mockService.publishEventsCallCount).toEventually(equal(1))
                    expect(self.mockService.publishedEvents).toEventually(equal(self.mockEvents))
                    expect(self.subject.eventStore.isEmpty).toEventually(beTrue())
                }
            }
            context("without events") {
                beforeEach {
                    self.setupReporter(online: true, eventFlushMillis: Constants.eventFlushInterval500Millis)
                    expect({ self.reporterState(isOnline: true, isReporting: true, reportTries: 0, recordedEvents: []) }).to(match())
                }
                it("doesn't report events") {
                    waitUntil { (done) in
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(Constants.eventFlushInterval500Millis)) {
                            expect(self.mockService.publishEventsCallCount) == 0
                            done()
                        }
                    }
                }
            }
        }
    }
    
    private func recordEvents(_ eventCount: Int) {
        while self.mockEvents.count < eventCount {
            let event = LDEvent.stub(for: LDEvent.eventType(for: mockEvents.count), with: self.user)
            self.mockEvents.append(event)
            self.subject.record(event)
        }
    }
    
    private func reporterState(isOnline: Bool, isReporting: Bool, reportTries: Int, recordedEvents: [LDEvent]? = nil, publishedEvents: [LDEvent]? = nil) -> ToMatchResult {
        var messages = [String]()
        if self.subject.isOnline != isOnline { messages.append("isOnline equals \(self.subject.isOnline)") }
        if self.subject.isReportingActive != isReporting { messages.append("isReportingActive equals \(self.subject.isReportingActive)") }
        if self.mockService.publishEventsCallCount != reportTries { messages.append("reportTries equals \(self.mockService.publishEventsCallCount)") }
        if let recordedEvents = recordedEvents {
            if self.subject.eventStore != recordedEvents { messages.append("recorded events don't match") }
        }
        if let publishedEvents = publishedEvents {
            if let serviceEvents = self.mockService.publishedEvents {
                if serviceEvents != publishedEvents { messages.append("published events don't match") }
            } else {
                messages.append("published events is nil")
            }
        }
        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }
}

extension LDEvent {
    static func stub(for eventType: LDEventType, with user: LDUser) -> LDEvent {
        switch eventType {
        case .feature: return LDEvent.featureEvent(key: UUID().uuidString, user: user, value: true, defaultValue: false)
        case .identify: return LDEvent.identifyEvent(key: UUID().uuidString, user: user)
        case .custom: return LDEvent.customEvent(key: UUID().uuidString, user: user, data: ["custom": UUID().uuidString])
        }
    }
    
    static func stubEvents(_ eventCount: Int, user: LDUser) -> [LDEvent] {
        var mockEvents = [LDEvent]()
        while mockEvents.count < eventCount {
            mockEvents.append(LDEvent.stub(for: LDEvent.eventType(for: mockEvents.count), with: user))
        }
        return mockEvents
    }

    static func eventType(for count: Int) -> LDEventType {
        let types: [LDEventType] = [.feature, .identify, .custom]
        return types[count % types.count]
    }
}

extension LDEventType {
    static var random: LDEventType {
        let types: [LDEventType] = [.feature, .identify, .custom]
        let index = Int(arc4random_uniform(2))
        return types[index]
    }
}
