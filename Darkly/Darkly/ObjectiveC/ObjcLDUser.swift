//
//  LDUserObject.swift
//  Darkly
//
//  Created by Mark Pokorny on 9/7/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

@objc (LDUser)
public final class ObjcLDUser: NSObject {
    var user: LDUser
    
    @objc public var key: String { return user.key }
    @objc public var firstName: String? {
        get { return user.firstName }
        set { user.firstName = newValue }
    }
    
    @objc public var lastName: String? {
        get { return user.lastName }
        set { user.lastName = newValue }
    }
    
    @objc public var email: String? {
        get { return user.email }
        set { user.email = newValue }
    }

    @objc public var customArray: [String: Any]? {
        get { return user.custom }
        set { user.custom = newValue }
    }
    
    @objc public override init() { user = LDUser() }
    @objc public init(key: String) { user = LDUser(key: key) }
    init(_ user: LDUser) { self.user = user }
}
