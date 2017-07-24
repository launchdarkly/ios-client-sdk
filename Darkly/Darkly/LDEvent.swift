//
//  LDEvent.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/11/17.
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

enum EventType {
    case feature, identify, custom
}

class LDEvent { //sdk internal, not publically accessible
    let key: String
    let kind: EventType
    let creationDate: Date
    let data: [String: AnyObject]?
    let user: LDUser?
    let value: AnyObject?
    let defaultValue: AnyObject?
    
    init(key: String = UUID().uuidString, kind: EventType = .custom, data: [String: AnyObject]? = nil, value: AnyObject? = nil, defaultValue: AnyObject? = nil, user: LDUser? = nil) {
        self.key = key
        self.kind = kind
        self.creationDate = Date()
        self.data = data
        self.user = user
        self.value = value
        self.defaultValue = defaultValue
    }
    
    class func featureEvent(key: String, value: AnyObject, defaultValue: AnyObject, user: LDUser) -> LDEvent {
        return LDEvent(key: key, kind: .feature, value: value, defaultValue: defaultValue, user: user)
    }
    
    class func customEvent(key: String, data: [String: AnyObject], user: LDUser) -> LDEvent {
        return LDEvent(key: key, kind: .feature, data: data, user: user)
    }
    
    class func identifyEvent() -> LDEvent {
        return LDEvent()
    }
}
