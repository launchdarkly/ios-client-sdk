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

//TODO: There is a name conflict with LDEventSource, which has a LDEvent
struct LDarklyEvent { //sdk internal, not publically accessible
    let key: String
    let kind: LDEventType
    let creationDate: Date
    let data: [String: Any]?
    let user: LDUser?
    let value: Any?
    let defaultValue: Any?
    
    init(key: String = UUID().uuidString, kind: LDEventType = .custom, data: [String: Any]? = nil, value: Any? = nil, defaultValue: Any? = nil, user: LDUser? = nil) {
        self.key = key
        self.kind = kind
        self.creationDate = Date()
        self.data = data
        self.user = user
        self.value = value
        self.defaultValue = defaultValue
    }
    
    static func featureEvent(key: String, value: Any, defaultValue: Any, user: LDUser) -> LDarklyEvent {
        return LDarklyEvent(key: key, kind: .feature, value: value, defaultValue: defaultValue, user: user)
    }
    
    static func customEvent(key: String, data: [String: Any], user: LDUser) -> LDarklyEvent {
        return LDarklyEvent(key: key, kind: .feature, data: data, user: user)
    }
    
    static func identifyEvent() -> LDarklyEvent {
        return LDarklyEvent()
    }
}

extension Int {
    init(date: Date) {
        self = Int(floor(date.timeIntervalSince1970 * 1000))
    }
}

extension Dictionary where Key: StringProtocol {
    init(event: LDarklyEvent) {
        self = [:]
    }
}

extension LDarklyEvent: Equatable {
    static func == (lhs: LDarklyEvent, rhs: LDarklyEvent) -> Bool { return lhs.key == rhs.key }
}

protocol LDEventProtocol {
    var ldEvent: LDarklyEvent { get }
}

extension LDarklyEvent: LDEventProtocol {
    var ldEvent: LDarklyEvent { return self }
}

extension Array where Element: LDEventProtocol {
    mutating func removeEvent(_ event: LDarklyEvent) {
        guard let index = self.index(where: {(element) in element.ldEvent == event}) else { return }
        self.remove(at: index)
    }
}
