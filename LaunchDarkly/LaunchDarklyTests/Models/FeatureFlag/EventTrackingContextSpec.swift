//
//  EventTrackingContextSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 6/12/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class EventTrackingContextSpec: QuickSpec {

    struct Constants {
        static let debugInterval: TimeInterval = 30.0
        static let oneSecond: TimeInterval = 1.0
        static let oneMillisecond: TimeInterval = 0.001
    }

    override func spec() {
        initSpec()
        dictionaryValueSpec()
        shouldCreateDebugEventsSpec()
    }

    private func initSpec() {
        describe("init") {
            var debugEventsUntilDate: Date?
            var eventTrackingContext: EventTrackingContext!
            context("with debugEventsUntilDate") {
                beforeEach {
                    debugEventsUntilDate = Date().addingTimeInterval(Constants.debugInterval)
                }
                it("creates a context with matching values") {
                    [true, false].forEach { (trackEvents) in
                        eventTrackingContext = EventTrackingContext(trackEvents: trackEvents, debugEventsUntilDate: debugEventsUntilDate)

                        expect(eventTrackingContext.trackEvents) == trackEvents
                        expect(eventTrackingContext.debugEventsUntilDate) == debugEventsUntilDate
                    }
                }
            }
            context("without debugEventsUntilDate") {
                it("creates a context with matching values") {
                    [true, false].forEach { (trackEvents) in
                        eventTrackingContext = EventTrackingContext(trackEvents: trackEvents)

                        expect(eventTrackingContext.trackEvents) == trackEvents
                        expect(eventTrackingContext.debugEventsUntilDate).to(beNil())
                    }
                }
            }
        }

        describe("init with dictionary") {
            var eventTrackingDictionary: [String: Any]!
            var eventTrackingContext: EventTrackingContext?
            context("dictionary contains trackEvents") {
                it("creates a context with matching values") {
                    [true, false].forEach { (trackEvents) in
                        eventTrackingDictionary = Dictionary(trackEvents: trackEvents)

                        eventTrackingContext = EventTrackingContext(dictionary: eventTrackingDictionary)

                        expect(eventTrackingContext?.trackEvents) == trackEvents
                        expect(eventTrackingContext?.debugEventsUntilDate).to(beNil())
                    }

                }
            }
            context("dictionary contains debugEventsUntilDate") {
                var debugEventsUntilDate: Date!
                beforeEach {
                    debugEventsUntilDate = Date().addingTimeInterval(Constants.debugInterval)
                }
                context("and trackEvents") {
                    it("creates a context with matching values") {
                        [true, false].forEach { (trackEvents) in
                            eventTrackingDictionary = Dictionary(trackEvents: trackEvents, debugEventsUntilDate: debugEventsUntilDate)

                            eventTrackingContext = EventTrackingContext(dictionary: eventTrackingDictionary)

                            expect(eventTrackingContext?.trackEvents) == trackEvents
                            expect(eventTrackingContext?.debugEventsUntilDate?.isWithin(0.001, of: debugEventsUntilDate)).to(beTrue())
                        }
                    }
                }
                context("without trackEvents") {
                    beforeEach {
                        eventTrackingDictionary = Dictionary(debugEventsUntilDate: debugEventsUntilDate)

                        eventTrackingContext = EventTrackingContext(dictionary: eventTrackingDictionary)
                    }
                    it("returns nil") {
                        expect(eventTrackingContext).to(beNil())
                    }
                }
            }
            context("dictionary omits trackEvents") {
                beforeEach {
                    eventTrackingDictionary = DarklyServiceMock.FlagValues.dictionary

                    eventTrackingContext = EventTrackingContext(dictionary: eventTrackingDictionary)
                }
                it("returns nil") {
                    expect(eventTrackingContext).to(beNil())
                }
            }
        }

        describe("init with object") {
            var object: Any!
            var eventTrackingContext: EventTrackingContext?
            var debugEventsUntilDate: Date!
            context("object is a dictionary containing trackEvents") {
                beforeEach {
                    debugEventsUntilDate = Date().addingTimeInterval(Constants.debugInterval)
                    object = Dictionary(trackEvents: true, debugEventsUntilDate: debugEventsUntilDate)

                    eventTrackingContext = EventTrackingContext(object: object)
                }
                it("creates a context with matching values") {
                    expect(eventTrackingContext?.trackEvents) == true
                    expect(eventTrackingContext?.debugEventsUntilDate?.isWithin(0.001, of: debugEventsUntilDate)).to(beTrue())
                }
            }
            context("object is not a dictionary or does not contain trackEvents") {
                it("returns nil") {
                    DarklyServiceMock.FlagValues.knownFlags.forEach { (object) in
                        eventTrackingContext = EventTrackingContext(object: object)

                        expect(eventTrackingContext).to(beNil())
                    }
                }
            }
            context("object is nil") {
                beforeEach {
                    eventTrackingContext = EventTrackingContext(object: nil)
                }
                it("returns nil") {
                    expect(eventTrackingContext).to(beNil())
                }
            }
        }
    }

    private func dictionaryValueSpec() {
        describe("dictionaryValue") {
            var eventTrackingContext: EventTrackingContext!
            var eventTrackingDictionary: [String: Any]!
            var debugEventsUntilDate: Date!
            context("with debugEventsUntilDate") {
                beforeEach {
                    debugEventsUntilDate = Date().addingTimeInterval(Constants.debugInterval)
                }
                it("contains matching values") {
                    [true, false].forEach { (trackEvents) in
                        eventTrackingContext = EventTrackingContext(trackEvents: trackEvents, debugEventsUntilDate: debugEventsUntilDate)

                        eventTrackingDictionary = eventTrackingContext.dictionaryValue

                        expect(eventTrackingDictionary.trackEvents) == trackEvents
                        expect(Date(millisSince1970: eventTrackingDictionary.debugEventsUntilDate)?.isWithin(0.001, of: debugEventsUntilDate)).to(beTrue())
                    }
                }
            }
            context("without debugEventsUntilDate") {
                it("contains matching values") {
                    [true, false].forEach { (trackEvents) in
                        eventTrackingContext = EventTrackingContext(trackEvents: trackEvents)

                        eventTrackingDictionary = eventTrackingContext.dictionaryValue

                        expect(eventTrackingDictionary.trackEvents) == trackEvents
                        expect(eventTrackingDictionary.debugEventsUntilDate).to(beNil())
                    }
                }
            }
        }
    }

    private func shouldCreateDebugEventsSpec() {
        describe("shouldCreateDebugEventsSpec") {
            var lastEventResponseDate: Date!
            var eventTrackingContext: EventTrackingContext!
            var shouldCreateDebugEvents: Bool!
            context("lastEventResponseDate exists") {
                context("debugEventsUntilDate hasn't passed lastEventResponseDate") {
                    beforeEach {
                        lastEventResponseDate = Date().addingTimeInterval(-Constants.oneSecond)
                        eventTrackingContext = EventTrackingContext(trackEvents: true, debugEventsUntilDate: Date())

                        shouldCreateDebugEvents = eventTrackingContext.shouldCreateDebugEvents(lastEventReportResponseTime: lastEventResponseDate)
                    }
                    it("returns true") {
                        expect(shouldCreateDebugEvents) == true
                    }
                }
                context("debugEventsUntilDate is lastEventResponseDate") {
                    beforeEach {
                        lastEventResponseDate = Date()
                        eventTrackingContext = EventTrackingContext(trackEvents: true, debugEventsUntilDate: lastEventResponseDate)

                        shouldCreateDebugEvents = eventTrackingContext.shouldCreateDebugEvents(lastEventReportResponseTime: lastEventResponseDate)
                    }
                    it("returns true") {
                        expect(shouldCreateDebugEvents) == true
                    }
                }
                context("debugEventsUntilDate has passed lastEventResponseDate") {
                    beforeEach {
                        lastEventResponseDate = Date().addingTimeInterval(+Constants.oneSecond)
                        eventTrackingContext = EventTrackingContext(trackEvents: true, debugEventsUntilDate: Date())

                        shouldCreateDebugEvents = eventTrackingContext.shouldCreateDebugEvents(lastEventReportResponseTime: lastEventResponseDate)
                    }
                    it("returns false") {
                        expect(shouldCreateDebugEvents) == false
                    }
                }
            }
            context("lastEventResponseDate does not exist") {
                context("debugEventsUntilDate hasn't passed system date") {
                    beforeEach {
                        eventTrackingContext = EventTrackingContext(trackEvents: true, debugEventsUntilDate: Date().addingTimeInterval(Constants.oneSecond))

                        shouldCreateDebugEvents = eventTrackingContext.shouldCreateDebugEvents(lastEventReportResponseTime: nil)
                    }
                    it("returns true") {
                        expect(shouldCreateDebugEvents) == true
                    }
                }
                context("debugEventsUntilDate is system date") {
                    beforeEach {
                        //Without creating a SystemDateServiceMock and corresponding service protocol, this is really difficult to test, but the level of accuracy is not crucial. Since the debugEventsUntilDate comes in millisSince1970, setting the debugEventsUntilDate to 1 millisecond beyond the date seems like it will get "close enough" to the current date
                        eventTrackingContext = EventTrackingContext(trackEvents: true, debugEventsUntilDate: Date().addingTimeInterval(Constants.oneMillisecond))

                        shouldCreateDebugEvents = eventTrackingContext.shouldCreateDebugEvents(lastEventReportResponseTime: nil)
                    }
                    it("returns true") {
                        expect(shouldCreateDebugEvents) == true
                    }
                }
                context("debugEventsUntilDate has passed system date") {
                    beforeEach {
                        eventTrackingContext = EventTrackingContext(trackEvents: true, debugEventsUntilDate: Date().addingTimeInterval(-Constants.oneSecond))

                        shouldCreateDebugEvents = eventTrackingContext.shouldCreateDebugEvents(lastEventReportResponseTime: nil)
                    }
                    it("returns false") {
                        expect(shouldCreateDebugEvents) == false
                    }
                }
            }
            context("debugEventsUntilDate doesn't exist") {
                beforeEach {
                    eventTrackingContext = EventTrackingContext(trackEvents: true, debugEventsUntilDate: nil)

                    shouldCreateDebugEvents = eventTrackingContext.shouldCreateDebugEvents(lastEventReportResponseTime: Date())
                }
                it("returns false") {
                    expect(shouldCreateDebugEvents) == false
                }
            }
        }
    }
}

extension Dictionary where Key == String, Value == Any {
    init(trackEvents: Bool? = nil, debugEventsUntilDate: Date? = nil) {
        self.init()
        self[EventTrackingContext.CodingKeys.trackEvents.rawValue] = trackEvents
        self[EventTrackingContext.CodingKeys.debugEventsUntilDate.rawValue] = debugEventsUntilDate?.millisSince1970
    }
}

extension EventTrackingContext {
    static func stub() -> EventTrackingContext {
        return EventTrackingContext(trackEvents: true, debugEventsUntilDate: Date().addingTimeInterval(EventTrackingContextSpec.Constants.debugInterval))
    }
}
