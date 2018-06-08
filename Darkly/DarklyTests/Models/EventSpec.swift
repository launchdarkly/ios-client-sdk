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
        static let eventKey = "EventSpec.Event.Key"
        static let eventData: [String: Any] = ["stubDataKey": "stubDataValue"]
    }

    override func spec() {
        initSpec()
        kindSpec()
        featureEventSpec()
        customEventSpec()
        identifyEventSpec()
        dictionaryValueSpec()
        dictionaryValuesSpec()
        containsSpec()
        eventDictionarySpec()
        equalsSpec()
    }

    func initSpec() {
        describe("init") {
            var user: LDUser!
            var featureFlag: FeatureFlag!
            var event: Event!
            beforeEach {
                user = LDUser.stub()
            }
            context("with optional items") {
                beforeEach {
                    featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
                    event = Event(key: Constants.eventKey, kind: .feature, user: user, value: true, defaultValue: false, featureFlag: featureFlag, data: Constants.eventData)
                }
                it("creates an event with matching data") {
                    expect(event.key) == Constants.eventKey
                    expect(event.kind) == Event.Kind.feature
                    expect(event.creationDate).toNot(beNil())
                    expect(event.user) == user
                    expect(AnyComparer.isEqual(event.value, to: true)).to(beTrue())
                    expect(AnyComparer.isEqual(event.defaultValue, to: false)).to(beTrue())
                    expect(event.featureFlag?.allPropertiesMatch(featureFlag)).to(beTrue())
                    expect(event.data).toNot(beNil())
                    expect(event.data == Constants.eventData).to(beTrue())
                }
            }
            context("without optional items") {
                beforeEach {
                    event = Event(key: Constants.eventKey, kind: .feature, user: user)
                }
                it("creates an event with matching data") {
                    expect(event.key) == Constants.eventKey
                    expect(event.kind) == Event.Kind.feature
                    expect(event.creationDate).toNot(beNil())
                    expect(event.user) == user
                    expect(event.value).to(beNil())
                    expect(event.defaultValue).to(beNil())
                    expect(event.featureFlag).to(beNil())
                    expect(event.data).to(beNil())
                }
            }
        }
    }

    func kindSpec() {
        describe("isAlwaysInlineUserKind") {
            it("returns true when event kind should inline user") {
                for kind in Event.Kind.allKinds {
                    expect(kind.isAlwaysInlineUserKind) == Event.Kind.alwaysInlineUserKinds.contains(kind)
                }
            }
        }
    }

    func featureEventSpec() {
        var user: LDUser!
        var event: Event!
        var featureFlag: FeatureFlag!
        beforeEach {
            featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
            user = LDUser.stub()
        }
        describe("featureEvent") {
            beforeEach {
                event = Event.featureEvent(key: Constants.eventKey, user: user, value: true, defaultValue: false, featureFlag: featureFlag)
            }
            it("creates a flag request event with matching data") {
                expect(event.key) == Constants.eventKey
                expect(event.kind) == Event.Kind.feature
                expect(event.creationDate).toNot(beNil())
                expect(event.user) == user
                expect(AnyComparer.isEqual(event.value, to: true)).to(beTrue())
                expect(AnyComparer.isEqual(event.defaultValue, to: false)).to(beTrue())
                expect(event.featureFlag?.allPropertiesMatch(featureFlag)).to(beTrue())
                expect(event.data).to(beNil())
            }
        }
    }

    func customEventSpec() {
        var user: LDUser!
        var event: Event!
        beforeEach {
            user = LDUser.stub()
        }
        describe("customEvent") {
            beforeEach {
                event = Event.customEvent(key: Constants.eventKey, user: user, data: Constants.eventData)
            }
            it("creates a custom event with matching data") {
                expect(event.key) == Constants.eventKey
                expect(event.kind) == Event.Kind.custom
                expect(event.creationDate).toNot(beNil())
                expect(event.user) == user
                expect(event.value).to(beNil())
                expect(event.defaultValue).to(beNil())
                expect(event.data == Constants.eventData).to(beTrue())
            }
        }
    }

    func identifyEventSpec() {
        var user: LDUser!
        var event: Event!
        beforeEach {
            user = LDUser.stub()
        }
        describe("identifyEvent") {
            beforeEach {
                event = Event.identifyEvent(user: user)
            }
            it("creates an identify event with matching data") {
                expect(event.key) == user.key
                expect(event.kind) == Event.Kind.identify
                expect(event.creationDate).toNot(beNil())
                expect(event.user) == user
                expect(event.value).to(beNil())
                expect(event.defaultValue).to(beNil())
                expect(event.data).to(beNil())
            }
        }
    }

    func dictionaryValueSpec() {
        var config = LDConfig.stub
        let user = LDUser.stub()
        var featureFlag: FeatureFlag!
        var event: Event!
        describe("dictionaryValue") {
            var eventDictionary: [String: Any]!

            context("feature event") {
                beforeEach {
                    featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
                }
                context("without inlining user") {
                    beforeEach {
                        event = Event.featureEvent(key: Constants.eventKey, user: user, value: true, defaultValue: false, featureFlag: featureFlag)
                        config.inlineUserInEvents = false   //Default value, here for clarity
                        eventDictionary = event.dictionaryValue(config: config)
                    }
                    it("creates a dictionary with matching non-user elements") {
                        expect(eventDictionary.eventKey) == Constants.eventKey
                        expect(eventDictionary.eventKind) == .feature
                        expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate)).to(beTrue())
                        expect(AnyComparer.isEqual(eventDictionary.eventValue, to: true)).to(beTrue())
                        expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: false)).to(beTrue())
                        expect(eventDictionary.eventVariation) == featureFlag.variation
                        expect(eventDictionary.eventData).to(beNil())
                    }
                    it("creates a dictionary with the user key only") {
                        expect(eventDictionary.eventUserKey) == user.key
                        expect(eventDictionary.eventUser).to(beNil())
                    }
                }
                context("inlining user") {
                    beforeEach {
                        event = Event.featureEvent(key: Constants.eventKey, user: user, value: true, defaultValue: false, featureFlag: featureFlag)
                        config.inlineUserInEvents = true
                        eventDictionary = event.dictionaryValue(config: config)
                    }
                    it("creates a dictionary with matching non-user elements") {
                        expect(eventDictionary.eventKey) == Constants.eventKey
                        expect(eventDictionary.eventKind) == .feature
                        expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate)).to(beTrue())
                        expect(AnyComparer.isEqual(eventDictionary.eventValue, to: true)).to(beTrue())
                        expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: false)).to(beTrue())
                        expect(eventDictionary.eventVariation) == featureFlag.variation
                        expect(eventDictionary.eventData).to(beNil())
                    }
                    it("creates a dictionary with the full user") {
                        expect(eventDictionary.eventUser).toNot(beNil())
                        if let eventDictionaryUser = eventDictionary.eventUser {
                            expect(eventDictionaryUser.key) == user.key
                            expect(eventDictionaryUser.name) == user.name
                            expect(eventDictionaryUser.firstName) == user.firstName
                            expect(eventDictionaryUser.lastName) == user.lastName
                            expect(eventDictionaryUser.country) == user.country
                            expect(eventDictionaryUser.ipAddress) == user.ipAddress
                            expect(eventDictionaryUser.email) == user.email
                            expect(eventDictionaryUser.avatar) == user.avatar
                            expect(AnyComparer.isEqual(eventDictionaryUser.custom, to: user.custom)).to(beTrue())
                            expect(eventDictionaryUser.device) == user.device
                            expect(eventDictionaryUser.operatingSystem) == user.operatingSystem
                            expect(eventDictionaryUser.isAnonymous) == user.isAnonymous
                            expect(eventDictionaryUser.privateAttributes).to(beNil())
                        }
                        expect(eventDictionary.eventUserKey).to(beNil())
                    }
                }
            }

            context("identify event") {
                beforeEach {
                    event = Event.identifyEvent(user: user)
                }
                it("creates a dictionary with the full user and matching non-user elements") {
                    for inlineUser in [true, false] {
                        config.inlineUserInEvents = inlineUser
                        eventDictionary = event.dictionaryValue(config: config)

                        expect(eventDictionary.eventKey) == user.key
                        expect(eventDictionary.eventKind) == .identify
                        expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate)).to(beTrue())
                        expect(eventDictionary.eventValue).to(beNil())
                        expect(eventDictionary.eventDefaultValue).to(beNil())
                        expect(eventDictionary.eventVariation).to(beNil())
                        expect(eventDictionary.eventData).to(beNil())
                        expect(eventDictionary.eventUser).toNot(beNil())
                        if let eventDictionaryUser = eventDictionary.eventUser {
                            expect(eventDictionaryUser.key) == user.key
                            expect(eventDictionaryUser.name) == user.name
                            expect(eventDictionaryUser.firstName) == user.firstName
                            expect(eventDictionaryUser.lastName) == user.lastName
                            expect(eventDictionaryUser.country) == user.country
                            expect(eventDictionaryUser.ipAddress) == user.ipAddress
                            expect(eventDictionaryUser.email) == user.email
                            expect(eventDictionaryUser.avatar) == user.avatar
                            expect(AnyComparer.isEqual(eventDictionaryUser.custom, to: user.custom)).to(beTrue())
                            expect(eventDictionaryUser.device) == user.device
                            expect(eventDictionaryUser.operatingSystem) == user.operatingSystem
                            expect(eventDictionaryUser.isAnonymous) == user.isAnonymous
                            expect(eventDictionaryUser.privateAttributes).to(beNil())
                        }
                        expect(eventDictionary.eventUserKey).to(beNil())
                    }
                }
            }

            context("custom event") {
                context("without inlining user") {
                    beforeEach {
                        event = Event.customEvent(key: Constants.eventKey, user: user, data: Constants.eventData)
                        config.inlineUserInEvents = false   //Default value, here for clarity
                        eventDictionary = event.dictionaryValue(config: config)
                    }
                    it("creates a dictionary with matching non-user elements") {
                        expect(eventDictionary.eventKey) == Constants.eventKey
                        expect(eventDictionary.eventKind) == .custom
                        expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate)).to(beTrue())
                        expect(AnyComparer.isEqual(eventDictionary.eventData, to: Constants.eventData)).to(beTrue())
                        expect(eventDictionary.eventValue).to(beNil())
                        expect(eventDictionary.eventDefaultValue).to(beNil())
                        expect(eventDictionary.eventVariation).to(beNil())
                    }
                    it("creates a dictionary with the user key only") {
                        expect(eventDictionary.eventUserKey) == user.key
                        expect(eventDictionary.eventUser).to(beNil())
                    }
                }
                context("inlining user") {
                    beforeEach {
                        event = Event.customEvent(key: Constants.eventKey, user: user, data: Constants.eventData)
                        config.inlineUserInEvents = true
                        eventDictionary = event.dictionaryValue(config: config)
                    }
                    it("creates a dictionary with matching non-user elements") {
                        expect(eventDictionary.eventKey) == Constants.eventKey
                        expect(eventDictionary.eventKind) == .custom
                        expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate)).to(beTrue())
                        expect(AnyComparer.isEqual(eventDictionary.eventData, to: Constants.eventData)).to(beTrue())
                        expect(eventDictionary.eventValue).to(beNil())
                        expect(eventDictionary.eventDefaultValue).to(beNil())
                        expect(eventDictionary.eventVariation).to(beNil())
                    }
                    it("creates a dictionary with the full user") {
                        expect(eventDictionary.eventUser).toNot(beNil())
                        if let eventDictionaryUser = eventDictionary.eventUser {
                            expect(eventDictionaryUser.key) == user.key
                            expect(eventDictionaryUser.name) == user.name
                            expect(eventDictionaryUser.firstName) == user.firstName
                            expect(eventDictionaryUser.lastName) == user.lastName
                            expect(eventDictionaryUser.country) == user.country
                            expect(eventDictionaryUser.ipAddress) == user.ipAddress
                            expect(eventDictionaryUser.email) == user.email
                            expect(eventDictionaryUser.avatar) == user.avatar
                            expect(AnyComparer.isEqual(eventDictionaryUser.custom, to: user.custom)).to(beTrue())
                            expect(eventDictionaryUser.device) == user.device
                            expect(eventDictionaryUser.operatingSystem) == user.operatingSystem
                            expect(eventDictionaryUser.isAnonymous) == user.isAnonymous
                            expect(eventDictionaryUser.privateAttributes).to(beNil())
                        }
                        expect(eventDictionary.eventUserKey).to(beNil())
                    }
                }
            }
        }
    }

    func dictionaryValuesSpec() {
        let config = LDConfig.stub
        let user = LDUser.stub()
        describe("dictionaryValues") {
            let events = Event.stubEvents(3, user: user)
            var eventDictionaries: [[String: Any]]!
            beforeEach {
                eventDictionaries = events.dictionaryValues(config: config)
            }
            it("creates an array of event dictionaries with matching elements") {
                expect(eventDictionaries.count) == events.count
                events.forEach { (event) in
                    expect(eventDictionaries.eventDictionary(for: event)).toNot(beNil())
                    guard let eventDictionary = eventDictionaries.eventDictionary(for: event) else { return }
                    expect(eventDictionary.eventKind) == event.kind
                    expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate)).to(beTrue())
                    if event.kind.isAlwaysInlineUserKind {
                        expect(eventDictionary.eventUser).toNot(beNil())
                        if let eventDictionaryUser = eventDictionary.eventUser {
                            expect(eventDictionaryUser.key) == user.key
                            expect(eventDictionaryUser.name) == user.name
                            expect(eventDictionaryUser.firstName) == user.firstName
                            expect(eventDictionaryUser.lastName) == user.lastName
                            expect(eventDictionaryUser.country) == user.country
                            expect(eventDictionaryUser.ipAddress) == user.ipAddress
                            expect(eventDictionaryUser.email) == user.email
                            expect(eventDictionaryUser.avatar) == user.avatar
                            expect(AnyComparer.isEqual(eventDictionaryUser.custom, to: user.custom)).to(beTrue())
                            expect(eventDictionaryUser.device) == user.device
                            expect(eventDictionaryUser.operatingSystem) == user.operatingSystem
                            expect(eventDictionaryUser.isAnonymous) == user.isAnonymous
                            expect(eventDictionaryUser.privateAttributes).to(beNil())
                        }
                        expect(eventDictionary.eventUserKey).to(beNil())
                    } else {
                        expect(eventDictionary.eventUserKey) == user.key
                        expect(eventDictionary.eventUser).to(beNil())
                    }
                    if let eventValue = event.value {
                        expect(AnyComparer.isEqual(eventDictionary.eventValue, to: eventValue)).to(beTrue())
                    } else {
                        expect(eventDictionary.eventValue).to(beNil())
                    }
                    if let eventDefaultValue = event.defaultValue {
                        expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: eventDefaultValue)).to(beTrue())
                    } else {
                        expect(eventDictionary.eventDefaultValue).to(beNil())
                    }
                    if let eventVariation = event.featureFlag?.variation {
                        expect(eventDictionary.eventVariation) == eventVariation
                    } else {
                        expect(eventDictionary.eventVariation).to(beNil())
                    }
                    if let eventData = event.data {
                        expect(eventDictionary.eventData).toNot(beNil())
                        if let eventDictionaryData = eventDictionary.eventData {
                            expect(eventDictionaryData == eventData).to(beTrue())
                        }
                    } else {
                        expect(eventDictionary.eventData).to(beNil())
                    }
                }
            }
        }
    }

    func containsSpec() {
        let config = LDConfig.stub
        let user = LDUser.stub()
        describe("array contains eventDictionary") {
            var eventDictionaries: [[String: Any]]!
            var targetDictionary: [String: Any]!
            beforeEach {
                eventDictionaries = Event.stubEventDictionaries(Constants.eventCapacity, user: user, config: config)
            }
            context("when the event dictionary is in the array") {
                context("at the first item") {
                    beforeEach {
                        targetDictionary = eventDictionaries.first
                    }
                    it("returns true") {
                        expect(eventDictionaries.contains(targetDictionary)) == true
                    }
                }
                context("at a middle item") {
                    beforeEach {
                        targetDictionary = eventDictionaries[eventDictionaries.startIndex.advanced(by: 1)]
                    }
                    it("returns true") {
                        expect(eventDictionaries.contains(targetDictionary)) == true
                    }
                }
                context("at the last item") {
                    beforeEach {
                        targetDictionary = eventDictionaries.last
                    }
                    it("returns true") {
                        expect(eventDictionaries.contains(targetDictionary)) == true
                    }
                }
            }
            context("when the event dictionary is not in the array") {
                beforeEach {
                    targetDictionary = Event.stub(for: .feature, with: user).dictionaryValue(config: config)
                }
                it("returns false") {
                    expect(eventDictionaries.contains(targetDictionary)) == false
                }
            }
            context("when the target dictionary is not an event dictionary") {
                beforeEach {
                    targetDictionary = user.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                }
                it("returns false") {
                    expect(eventDictionaries.contains(targetDictionary)) == false
                }
            }
            context("when the array doesn't contain event dictionaries") {
                beforeEach {
                    eventDictionaries = LDUser.stubUsers(Constants.eventCapacity).map { (user) in
                        user.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                    }
                    targetDictionary = Event.stub(for: .identify, with: user).dictionaryValue(config: config)
                }
                it("returns false") {
                    expect(eventDictionaries.contains(targetDictionary)) == false
                }
            }
        }
    }

    //Dictionary extension methods that extract an event key, or creationDateMillis, and compare them with another dictionary
    func eventDictionarySpec() {
        let config = LDConfig.stub
        let user = LDUser.stub()
        describe("event dictionary") {
            describe("eventKey") {
                var event: Event!
                var eventDictionary: [String: Any]!
                beforeEach {
                    event = Event.stub(for: .custom, with: user)
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

            describe("eventCreationDateMillis") {
                var event: Event!
                var eventDictionary: [String: Any]!
                beforeEach {
                    event = Event.stub(for: .custom, with: user)
                    eventDictionary = event.dictionaryValue(config: config)
                }
                context("when the dictionary contains a creation date") {
                    it("returns the creation date millis") {
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

            describe("matches") {
                var eventDictionary: [String: Any]!
                var otherDictionary: [String: Any]!
                beforeEach {
                    eventDictionary = Event.stub(for: .custom, with: user).dictionaryValue(config: config)
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
        }
    }

    func equalsSpec() {
        let user = LDUser.stub()
        describe("equals") {
            var event1: Event!
            var event2: Event!
            context("on the same event") {
                beforeEach {
                    event1 = Event(key: Constants.eventKey, kind: .feature, user: user, value: true, defaultValue: false, data: Constants.eventData)
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
                    event2 = Event(key: eventKey, kind: .custom, user: LDUser.stub(key: UUID().uuidString), data: Constants.eventData)
                }
                it("returns false") {
                    expect(event1) != event2
                }
            }
            context("when only the keys differ") {
                beforeEach {
                    event1 = Event(key: UUID().uuidString, kind: .feature, user: user, value: true, defaultValue: false, data: Constants.eventData)
                    event2 = Event(key: UUID().uuidString, kind: .feature, user: user, value: true, defaultValue: false, data: Constants.eventData)
                }
                it("returns false") {
                    expect(event1) != event2
                }
            }
            context("on different events") {
                beforeEach {
                    event1 = Event(key: UUID().uuidString, kind: .feature, user: user, value: true, defaultValue: false, data: Constants.eventData)
                    event2 = Event(key: UUID().uuidString, kind: .identify, user: LDUser.stub(key: UUID().uuidString))
                }
                it("returns false") {
                    expect(event1) != event2
                }
            }
        }
    }
}

fileprivate extension Dictionary where Key == String, Value == Any {
    var eventKind: Event.Kind? {
        guard let stringKind = self[Event.CodingKeys.kind.rawValue] as? String else { return nil }
        return Event.Kind(rawValue: stringKind)
    }
    var eventCreationDate: Date? { return Date(millisSince1970: self[Event.CodingKeys.creationDate.rawValue] as? Int64) }
    var eventUserKey: String? { return self[Event.CodingKeys.userKey.rawValue] as? String }
    var eventUser: LDUser? { return LDUser(object: self[Event.CodingKeys.user.rawValue]) }
    var eventValue: Any? { return self[Event.CodingKeys.value.rawValue] }
    var eventDefaultValue: Any? { return self[Event.CodingKeys.defaultValue.rawValue] }
    var eventVariation: Int? { return self[Event.CodingKeys.variation.rawValue] as? Int }
    var eventData: [String: Any]? { return self[Event.CodingKeys.data.rawValue] as? [String: Any] }
}

fileprivate extension Array where Element == [String: Any] {
    func eventDictionary(for event: Event) -> [String: Any]? {
        let selectedDictionaries = self.filter { (eventDictionary) -> Bool in event.key == eventDictionary.eventKey }
        guard selectedDictionaries.count == 1 else { return nil }
        return selectedDictionaries.first
    }
}

extension Event.Kind {
    static var allKinds: [Event.Kind] { return [.feature, .custom, .identify] }
}
