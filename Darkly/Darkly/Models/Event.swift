//
//  Event.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

struct Event { //sdk internal, not publically accessible
    enum CodingKeys: String, CodingKey {
        case key, kind, creationDate, user, value, defaultValue = "default", data
    }

    enum Kind: String {
        case feature, identify, custom

        static var alwaysInlineUserKinds: [Kind] { return [identify] }
        var isAlwaysInlineUserKind: Bool { return Kind.alwaysInlineUserKinds.contains(self) }
    }

    let key: String
    let kind: Kind
    let creationDate: Date
    let user: LDUser
    let value: Any?
    let defaultValue: Any?
    let data: [String: Any]?

    init(key: String, kind: Kind = .custom, user: LDUser, value: Any? = nil, defaultValue: Any? = nil, data: [String: Any]? = nil) {
        self.key = key
        self.kind = kind
        self.creationDate = Date()
        self.user = user
        self.value = value
        self.defaultValue = defaultValue
        self.data = data
    }

    static func featureEvent(key: String, user: LDUser, value: Any?, defaultValue: Any?) -> Event {
        Log.debug(typeName(and: #function) + "key: " + key + ", value: \(String(describing: value)), " + "fallback: \(String(describing: defaultValue))")
        return Event(key: key, kind: .feature, user: user, value: value, defaultValue: defaultValue)
    }

    static func customEvent(key: String, user: LDUser, data: [String: Any]? = nil) -> Event {
        Log.debug(typeName(and: #function) + "key: " + key + ", data: \(String(describing: data))")
        return Event(key: key, kind: .custom, user: user, data: data)
    }

    static func identifyEvent(user: LDUser) -> Event {
        Log.debug(typeName(and: #function) + "key: " + user.key)
        return Event(key: user.key, kind: .identify, user: user)
    }

    func dictionaryValue(config: LDConfig) -> [String: Any] {
        var eventDictionary = [String: Any]()
        eventDictionary[CodingKeys.key.rawValue] = key
        eventDictionary[CodingKeys.kind.rawValue] = kind.rawValue
        eventDictionary[CodingKeys.creationDate.rawValue] = creationDate.millisSince1970
        eventDictionary[CodingKeys.user.rawValue] = user.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: false, config: config)
        eventDictionary[CodingKeys.value.rawValue] = value
        eventDictionary[CodingKeys.defaultValue.rawValue] = defaultValue
        eventDictionary[CodingKeys.data.rawValue] = data

        return eventDictionary
    }
}

extension Array where Element == Event {
    func dictionaryValues(config: LDConfig) -> [[String: Any]] {
        return self.map { (event) in event.dictionaryValue(config: config) }
    }
}

extension Array where Element == [String: Any] {
    var jsonData: Data? {
        guard JSONSerialization.isValidJSONObject(self) else { return nil }
        return try? JSONSerialization.data(withJSONObject: self, options: [])
    }

    func contains(_ eventDictionary: [String: Any]) -> Bool {
        return !self.filter { (testDictionary) in testDictionary.matches(eventDictionary: eventDictionary) }.isEmpty
    }
}

extension Dictionary where Key == String, Value == Any {
    var eventKey: String? { return self[Event.CodingKeys.key.rawValue] as? String }
    var eventCreationDateMillis: Int64? { return self[Event.CodingKeys.creationDate.rawValue] as? Int64 }

    func matches(eventDictionary other: [String: Any]) -> Bool {
        guard let key = eventKey, let creationDateMillis = eventCreationDateMillis,
            let otherKey = other.eventKey, let otherCreationDateMillis = other.eventCreationDateMillis
        else { return false }
        return key == otherKey && creationDateMillis == otherCreationDateMillis
    }
}

extension Event: Equatable {
    static func == (lhs: Event, rhs: Event) -> Bool { return lhs.key == rhs.key && lhs.creationDate == rhs.creationDate }
}

extension Event: TypeIdentifying { }
