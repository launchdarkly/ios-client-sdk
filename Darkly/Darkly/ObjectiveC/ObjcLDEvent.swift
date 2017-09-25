//
//  ObjcLDEvent.swift
//  Darkly
//
//  Created by Mark Pokorny on 9/12/17.
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

@objc(LDEvent)
public final class ObjcLDEvent: NSObject {
    let event: LDEvent
    
    public var key: String { return event.key }
    public var data: [String: Any]? { return event.data }
    public var user: ObjcLDUser? {
        guard let eventUser = event.user else { return nil }
        return ObjcLDUser(eventUser)
    }
    
    init(_ event: LDEvent) {
        self.event = event
    }
}
