//
//  EventSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 10/19/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
@testable import LaunchDarkly

final class EventSpec: QuickSpec {
    struct Constants {
        static let eventCapacity = 3
    }

    override func spec() {
        let key = "mockEventKey"
        let kind = Event.Kind.feature
        let config = LDConfig.stub
        let userStub = LDUser.stub()
        let value = true
        let defaultValue = false
        let data: [String: Any] = ["stubDataKey": "stubDataValue"]
        var subject: Event!
        describe("init") {
            context("with optional items") {
                beforeEach {
                    subject = Event(key: key, kind: kind, user: userStub, value: value, defaultValue: defaultValue, data: data)
                }
                it("creates an event with matching data") {
                    expect(subject.key) == key
                    expect(subject.kind) == kind
                    expect(subject.creationDate).toNot(beNil())
                    expect(subject.user) == userStub
                    expect(AnyComparer.isEqual(subject.value, to: value)).to(beTrue())
                    expect(AnyComparer.isEqual(subject.defaultValue, to: defaultValue)).to(beTrue())
                    expect(subject.data).toNot(beNil())
                    expect(subject.data == data).to(beTrue())
                }
            }
            context("without optional items") {
                beforeEach {
                    subject = Event(key: key, kind: kind, user: userStub)
                }
                it("creates an event with matching data") {
                    expect(subject.key) == key
                    expect(subject.kind) == kind
                    expect(subject.creationDate).toNot(beNil())
                    expect(subject.user) == userStub
                    expect(subject.value).to(beNil())
                    expect(subject.defaultValue).to(beNil())
                    expect(subject.data).to(beNil())
                }
            }
        }
        describe("featureEvent") {
            beforeEach {
                subject = Event.featureEvent(key: key, user: userStub, value: value, defaultValue: defaultValue)
            }
            it("creates a flag request event with matching data") {
                expect(subject.key) == key
                expect(subject.kind) == Event.Kind.feature
                expect(subject.creationDate).toNot(beNil())
                expect(subject.user) == userStub
                expect(AnyComparer.isEqual(subject.value, to: value)).to(beTrue())
                expect(AnyComparer.isEqual(subject.defaultValue, to: defaultValue)).to(beTrue())
                expect(subject.data).to(beNil())
            }
        }
        describe("customEvent") {
            beforeEach {
                subject = Event.customEvent(key: key, user: userStub, data: data)
            }
            it("creates a custom event with matching data") {
                expect(subject.key) == key
                expect(subject.kind) == Event.Kind.custom
                expect(subject.creationDate).toNot(beNil())
                expect(subject.user) == userStub
                expect(subject.value).to(beNil())
                expect(subject.defaultValue).to(beNil())
                expect(subject.data).toNot(beNil())
                expect(subject.data == data).to(beTrue())
            }
        }
        describe("identifyEvent") {
            beforeEach {
                subject = Event.identifyEvent(user: userStub)
            }
            it("creates an identify event with matching data") {
                expect(subject.key) == userStub.key
                expect(subject.kind) == Event.Kind.identify
                expect(subject.creationDate).toNot(beNil())
                expect(subject.user) == userStub
                expect(subject.value).to(beNil())
                expect(subject.defaultValue).to(beNil())
                expect(subject.data).to(beNil())
            }
        }
        describe("dictionaryValue") {
            var eventDictionary: [String: Any]!
            context("with optional items") {
                beforeEach {
                    subject = Event(key: key, kind: kind, user: userStub, value: value, defaultValue: defaultValue, data: data)
                    eventDictionary = subject.dictionaryValue(config: config)
                }
                it("creates a dictionary with matching elements") {
                    expect(eventDictionary[Event.CodingKeys.key.rawValue] as? String) == key
                    expect(eventDictionary[Event.CodingKeys.kind.rawValue] as? String) == kind.rawValue
                    expect(eventDictionary[Event.CodingKeys.creationDate.rawValue] as? Int64) == subject.creationDate.millisSince1970
                    expect(eventDictionary[Event.CodingKeys.user.rawValue] as? [String: Any]).toNot(beNil())
                    if let encodedUser = eventDictionary[Event.CodingKeys.user.rawValue] as? [String: Any] {
                        expect(encodedUser == userStub.dictionaryValueWithAllAttributes(includeFlagConfig: false)).to(beTrue())
                    }
                    expect(eventDictionary[Event.CodingKeys.value.rawValue] as? Bool) == Bool(value)
                    expect(eventDictionary[Event.CodingKeys.defaultValue.rawValue] as? Bool) == Bool(defaultValue)
                    expect(eventDictionary[Event.CodingKeys.data.rawValue] as? [String: Any]).toNot(beNil())
                    if let encodedData = eventDictionary[Event.CodingKeys.data.rawValue] as? [String: Any] {
                        expect(encodedData == data).to(beTrue())
                    }
                }
            }
            context("without optional items") {
                beforeEach {
                    subject = Event(key: key, kind: kind, user: userStub)
                    eventDictionary = subject.dictionaryValue(config: config)
                }
                it("creates a dictionary with matching elements omitting null values") {
                    expect(eventDictionary[Event.CodingKeys.key.rawValue] as? String) == key
                    expect(eventDictionary[Event.CodingKeys.kind.rawValue] as? String) == kind.rawValue
                    expect(eventDictionary[Event.CodingKeys.creationDate.rawValue] as? Int64) == subject.creationDate.millisSince1970
                    expect(eventDictionary[Event.CodingKeys.user.rawValue] as? [String: Any]).toNot(beNil())
                    if let encodedUser = eventDictionary[Event.CodingKeys.user.rawValue] as? [String: Any] {
                        expect(encodedUser == userStub.dictionaryValueWithAllAttributes(includeFlagConfig: false)).to(beTrue())
                    }
                    expect(eventDictionary[Event.CodingKeys.value.rawValue]).to(beNil())
                    expect(eventDictionary[Event.CodingKeys.defaultValue.rawValue]).to(beNil())
                    expect(eventDictionary[Event.CodingKeys.data.rawValue]).to(beNil())
                }
            }
        }
        describe("dictionaryValues") {
            let events = Event.stubEvents(3, user: userStub)
            var eventDictionaries: [[String: Any]]!
            beforeEach {
                eventDictionaries = events.dictionaryValues(config: config)
            }
            it("creates an array of event dictionaries with matching elements") {
                expect(eventDictionaries.count) == events.count
                events.forEach { (event) in
                    let encodedEvent = eventDictionaries.filter { (eventDictionary) -> Bool in event.key == eventDictionary[Event.CodingKeys.key.rawValue] as? String }
                        .first
                    expect(encodedEvent).toNot(beNil())
                    guard let foundEvent = encodedEvent else { return }
                    expect(foundEvent[Event.CodingKeys.kind.rawValue] as? String) == event.kind.rawValue
                    expect(foundEvent[Event.CodingKeys.creationDate.rawValue] as? Int64) == event.creationDate.millisSince1970
                    expect(foundEvent[Event.CodingKeys.user.rawValue] as? [String: Any]).toNot(beNil())
                    if let encodedUser = foundEvent[Event.CodingKeys.user.rawValue] as? [String: Any] {
                        expect(encodedUser == userStub.dictionaryValueWithAllAttributes(includeFlagConfig: false)).to(beTrue())
                    }
                    if let eventValue = event.value {
                        expect(foundEvent[Event.CodingKeys.value.rawValue] as? Bool) == eventValue as? Bool
                    } else {
                        expect(foundEvent[Event.CodingKeys.value.rawValue]).to(beNil())
                    }
                    if let eventDefaultValue = event.defaultValue {
                        expect(foundEvent[Event.CodingKeys.defaultValue.rawValue] as? Bool) == eventDefaultValue as? Bool
                    } else {
                        expect(foundEvent[Event.CodingKeys.defaultValue.rawValue]).to(beNil())
                    }
                    if let eventData = event.data {
                        expect(foundEvent[Event.CodingKeys.data.rawValue] as? [String: Any]).toNot(beNil())
                        if let encodedData = foundEvent[Event.CodingKeys.data.rawValue] as? [String: Any] {
                            expect(encodedData == eventData).to(beTrue())
                        }
                    } else {
                        expect(foundEvent[Event.CodingKeys.data.rawValue]).to(beNil())
                    }
                }
            }
        }

        describe("array contains eventDictionary") {
            var eventDictionaries: [[String: Any]]!
            var targetDictionary: [String: Any]!
            beforeEach {
                eventDictionaries = Event.stubEventDictionaries(Constants.eventCapacity, user: userStub, config: config)
            }
            context("when the event dictionary is in the array") {
                context("at the first item") {
                    beforeEach {
                        targetDictionary = eventDictionaries.first
                    }
                    it("returns true") {
                        expect(eventDictionaries.contains(eventDictionary: targetDictionary)) == true
                    }
                }
                context("at a middle item") {
                    beforeEach {
                        targetDictionary = eventDictionaries[eventDictionaries.startIndex.advanced(by: 1)]
                    }
                    it("returns true") {
                        expect(eventDictionaries.contains(eventDictionary: targetDictionary)) == true
                    }
                }
                context("at the last item") {
                    beforeEach {
                        targetDictionary = eventDictionaries.last
                    }
                    it("returns true") {
                        expect(eventDictionaries.contains(eventDictionary: targetDictionary)) == true
                    }
                }
            }
            context("when the event dictionary is not in the array") {
                beforeEach {
                    targetDictionary = Event.stub(for: .feature, with: userStub).dictionaryValue(config: config)
                }
                it("returns false") {
                    expect(eventDictionaries.contains(eventDictionary: targetDictionary)) == false
                }
            }
            context("when the target dictionary is not an event dictionary") {
                beforeEach {
                    targetDictionary = userStub.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                }
                it("returns false") {
                    expect(eventDictionaries.contains(eventDictionary: targetDictionary)) == false
                }
            }
            context("when the array doesn't contain event dictionaries") {
                beforeEach {
                    eventDictionaries = LDUser.stubUsers(Constants.eventCapacity).map { (user) in
                        user.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                    }
                    targetDictionary = Event.stub(for: .identify, with: userStub).dictionaryValue(config: config)
                }
                it("returns false") {
                    expect(eventDictionaries.contains(eventDictionary: targetDictionary)) == false
                }
            }
        }

        describe("event dictionary eventKey") {
            var event: Event!
            var eventDictionary: [String: Any]!
            beforeEach {
                event = Event.stub(for: .custom, with: userStub)
                eventDictionary = event.dictionaryValue(config: config)
            }
            context("when the dictionary contains a key") {
                it("returns the key") {
                    expect(eventDictionary.eventKey) == event.key
                }
            }
            context("when the dictionary does not contain a key") {
                beforeEach {
                    eventDictionary.removeValue(forKey: Event.CodingKeys.key.rawValue)
                }
                it("returns nil") {
                    expect(eventDictionary.eventKey).to(beNil())
                }
            }
        }

        describe("event dictionary eventCreationDateMillis") {
            var event: Event!
            var eventDictionary: [String: Any]!
            beforeEach {
                event = Event.stub(for: .custom, with: userStub)
                eventDictionary = event.dictionaryValue(config: config)
            }
            context("when the dictionary contains a creation date") {
                it("returns the key") {
                    expect(eventDictionary.eventCreationDateMillis) == event.creationDate.millisSince1970
                }
            }
            context("when the dictionary does not contain a creation date") {
                beforeEach {
                    eventDictionary.removeValue(forKey: Event.CodingKeys.creationDate.rawValue)
                }
                it("returns nil") {
                    expect(eventDictionary.eventCreationDateMillis).to(beNil())
                }
            }
        }

        describe("event dictionary matches other event dictionary") {
            var eventDictionary: [String: Any]!
            var otherDictionary: [String: Any]!
            beforeEach {
                eventDictionary = Event.stub(for: .custom, with: userStub).dictionaryValue(config: config)
                otherDictionary = eventDictionary
            }
            context("when keys and creationDateMillis are equal") {
                it("returns true") {
                    expect(eventDictionary.matches(eventDictionary: otherDictionary)) == true
                }
            }
            context("when keys differ") {
                beforeEach {
                    otherDictionary[Event.CodingKeys.key.rawValue] = otherDictionary.eventKey! + "dummy"
                }
                it("returns false") {
                    expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                }
            }
            context("when creationDateMillis differ") {
                beforeEach {
                    otherDictionary[Event.CodingKeys.creationDate.rawValue] = otherDictionary.eventCreationDateMillis! + 1
                }
                it("returns false") {
                    expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                }
            }
            context("when dictionary key is nil") {
                beforeEach {
                    eventDictionary.removeValue(forKey: Event.CodingKeys.key.rawValue)
                }
                it("returns false") {
                    expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                }
            }
            context("when other dictionary key is nil") {
                beforeEach {
                    otherDictionary.removeValue(forKey: Event.CodingKeys.key.rawValue)
                }
                it("returns false") {
                    expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                }
            }
            context("when dictionary creationDateMillis is nil") {
                beforeEach {
                    eventDictionary.removeValue(forKey: Event.CodingKeys.creationDate.rawValue)
                }
                it("returns false") {
                    expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                }
            }
            context("when other dictionary creationDateMillis is nil") {
                beforeEach {
                    otherDictionary.removeValue(forKey: Event.CodingKeys.creationDate.rawValue)
                }
                it("returns false") {
                    expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                }
            }
        }

        describe("equals") {
            var event1: Event!
            var event2: Event!
            context("on the same event") {
                beforeEach {
                    event1 = Event(key: key, kind: kind, user: userStub, value: value, defaultValue: defaultValue, data: data)
                    event2 = event1
                }
                it("returns true") {
                    expect(event1) == event2
                }
            }
            context("when only the keys match") {
                let eventKey = UUID().uuidString
                beforeEach {
                    event1 = Event(key: eventKey, kind: .feature, user: LDUser.stub(key: UUID().uuidString), value: true, defaultValue: false)
                    event2 = Event(key: eventKey, kind: .custom, user: LDUser.stub(key: UUID().uuidString), data: data)
                }
                it("returns false") {
                    expect(event1) != event2
                }
            }
            context("when only the keys differ") {
                beforeEach {
                    event1 = Event(key: UUID().uuidString, kind: kind, user: userStub, value: value, defaultValue: defaultValue, data: data)
                    event2 = Event(key: UUID().uuidString, kind: kind, user: userStub, value: value, defaultValue: defaultValue, data: data)
                }
                it("returns false") {
                    expect(event1) != event2
                }
            }
            context("on different events") {
                beforeEach {
                    event1 = Event(key: UUID().uuidString, kind: .feature, user: userStub, value: value, defaultValue: defaultValue, data: data)
                    event2 = Event(key: UUID().uuidString, kind: .identify, user: LDUser.stub(key: UUID().uuidString))
                }
                it("returns false") {
                    expect(event1) != event2
                }
            }
        }
    }
}
