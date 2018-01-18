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
    
    @objc public class var privatizableAttributes: [String] { return LDUser.privatizableAttributes }
    @objc public class var attributeName: String { return LDUser.CodingKeys.name.rawValue }
    @objc public class var attributeFirstName: String { return LDUser.CodingKeys.firstName.rawValue }
    @objc public class var attributeLastName: String { return LDUser.CodingKeys.lastName.rawValue }
    @objc public class var attributeCountry: String { return LDUser.CodingKeys.country.rawValue }
    @objc public class var attributeIPAddress: String { return LDUser.CodingKeys.ipAddress.rawValue }
    @objc public class var attributeEmail: String { return LDUser.CodingKeys.email.rawValue }
    @objc public class var attributeAvatar: String { return LDUser.CodingKeys.avatar.rawValue }
    @objc public class var attributeCustom: String { return LDUser.CodingKeys.custom.rawValue }

    @objc public var key: String { return user.key }
    @objc public var name: String? {
        get { return user.name }
        set { user.name = newValue }
    }
    @objc public var firstName: String? {
        get { return user.firstName }
        set { user.firstName = newValue }
    }
    @objc public var lastName: String? {
        get { return user.lastName }
        set { user.lastName = newValue }
    }
    @objc public var country: String? {
        get { return user.country }
        set { user.country = newValue }
    }
    @objc public var ipAddress: String? {
        get { return user.ipAddress }
        set { user.ipAddress = newValue }
    }
    @objc public var email: String? {
        get { return user.email }
        set { user.email = newValue }
    }
    @objc public var avatar: String? {
        get { return user.avatar }
        set { user.avatar = newValue }
    }
    @objc public var custom: [String: Any]? {
        get { return user.custom }
        set { user.custom = newValue }
    }
    @objc public var isAnonymous: Bool {
        get { return user.isAnonymous }
        set { user.isAnonymous = newValue }
    }
    @objc public var device: String? {
        get { return user.device }
        set { user.device = newValue }
    }
    @objc public var operatingSystem: String? {
        get { return user.operatingSystem }
        set { user.operatingSystem = newValue }
    }
    @objc public var privateAttributes: [String]? {
        get { return user.privateAttributes }
        set { user.privateAttributes = newValue }
    }

    @objc public override init() { user = LDUser() }
    @objc public init(key: String) { user = LDUser(key: key) }
    init(_ user: LDUser) { self.user = user }

    @objc public func isEqual(object: Any) -> Bool {
        guard let otherUser = object as? ObjcLDUser else { return false }
        return user == otherUser.user
    }
}
