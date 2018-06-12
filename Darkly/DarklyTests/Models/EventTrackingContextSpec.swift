//
//  EventTrackingContextSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 6/12/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import Darkly

final class EventTrackingContextSpec: QuickSpec {

    override func spec() {
        initSpec()
        dictionaryValueSpec()
    }

    private func initSpec() {
        describe("init") {
            var eventTrackingContext: EventTrackingContext!
            it("creates a context with matching values") {
                [true, false].forEach { (trackEvents) in
                    eventTrackingContext = EventTrackingContext(trackEvents: trackEvents)

                    expect(eventTrackingContext.trackEvents) == trackEvents
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
            context("object is a dictionary containing trackEvents") {
                beforeEach {
                    object = Dictionary(trackEvents: true)

                    eventTrackingContext = EventTrackingContext(object: object)
                }
                it("creates a context with matching values") {
                    expect(eventTrackingContext?.trackEvents) == true
                }
            }
            context("object is not a dictionary or does not contain trackEvents") {
                it("returns nil") {
                    DarklyServiceMock.FlagValues.all.forEach { (object) in
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
            it("contains matching values") {
                [true, false].forEach { (trackEvents) in
                    eventTrackingContext = EventTrackingContext(trackEvents: trackEvents)

                    eventTrackingDictionary = eventTrackingContext.dictionaryValue

                    expect(eventTrackingDictionary.trackEvents) == trackEvents
                }
            }
        }
    }
}

extension Dictionary where Key == String, Value == Any {
    init(trackEvents: Bool) {
        self.init()
        self[EventTrackingContext.CodingKeys.trackEvents.rawValue] = trackEvents
    }
}
