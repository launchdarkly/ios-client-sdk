//
//  LDEvent.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

enum LDEventType: String {
    case feature, identify, custom
}

struct LDEvent { //sdk internal, not publically accessible
    enum CodingKeys: String, CodingKey {
        case key, kind, creationDate, user, value, defaultValue = "default", data
    }

    let key: String
    let kind: LDEventType
    let creationDate: Date
    let user: LDUser
    let value: LDFlagValue?
    let defaultValue: LDFlagValue?
    let data: [String: Any]?

    init(key: String, kind: LDEventType = .custom, user: LDUser, value: LDFlagValue? = nil, defaultValue: LDFlagValue? = nil, data: [String: Any]? = nil) {
        self.key = key
        self.kind = kind
        self.creationDate = Date()
        self.user = user
        self.value = value
        self.defaultValue = defaultValue
        self.data = data
    }

    static func featureEvent(key: String, user: LDUser, value: LDFlagValue, defaultValue: LDFlagValue) -> LDEvent {
        return LDEvent(key: key, kind: .feature, user: user, value: value, defaultValue: defaultValue)
    }

    static func customEvent(key: String, user: LDUser, data: [String: Any]? = nil) -> LDEvent {
        return LDEvent(key: key, kind: .custom, user: user, data: data)
    }

    static func identifyEvent(key: String, user: LDUser) -> LDEvent {
        return LDEvent(key: key, kind: .identify, user: user)
    }

    var jsonDictionary: [String: Any] {
        var json = [String: Any]()
        json[CodingKeys.key.rawValue] = key
        json[CodingKeys.kind.rawValue] = kind.rawValue
        json[CodingKeys.creationDate.rawValue] = creationDate.millisSince1970
        json[CodingKeys.user.rawValue] = user.jsonDictionaryWithoutConfig
        json[CodingKeys.value.rawValue] = value?.baseValue
        json[CodingKeys.defaultValue.rawValue] = defaultValue?.baseValue
        json[CodingKeys.data.rawValue] = data

        return json
    }

    var jsonData: Data? {
        return jsonDictionary.jsonData
    }
}

extension Array where Element == LDEvent {
    var jsonArray: [[String: Any]] { return self.map { (event) in event.jsonDictionary } }

    var jsonData: Data? {
        guard JSONSerialization.isValidJSONObject(self) else { return nil }
        return try? JSONSerialization.data(withJSONObject: self.jsonArray, options: [])
    }

    mutating func remove(_ event: LDEvent) {
        guard let index = self.index(where: {(element) in element == event}) else { return }
        self.remove(at: index)
    }
}

extension LDEvent: Equatable {
    static func == (lhs: LDEvent, rhs: LDEvent) -> Bool { return lhs.key == rhs.key && lhs.creationDate == rhs.creationDate }
}
