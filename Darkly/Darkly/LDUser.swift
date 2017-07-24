//
//  LDUser.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

public class LDUser {   //TODO: Open instead? Should sdk allow subclassing, or just composition?
    
    fileprivate struct Constants {
        static let keyDevice = "device"
        static let keyOs = "os"
    }
    
    public let key: String
    public var name: String?
    public var firstName: String?
    public var lastName: String?
    public var country: String?
    public var ip: String?
    public var email: String?
    public var avatar: String?
    public var custom: [String: AnyObject]?   //Java sdk only allows string keys, so while this is different than the ios-client, it seems reasonable
    private(set) var lastUpdated: Date  //internal access within the sdk, settable only within LDUser
    public var isAnonymous: Bool
    public var device: String?
    public var os: String?
    
    var featureFlag: LDFeatureFlag?   //internal access, settable only within the sdk
    
    public init(key: String = UUID().uuidString,
                name: String? = nil,
                firstName: String? = nil,
                lastName: String? = nil,
                isAnonymous: Bool = false,
                country: String? = nil,
                ip: String? = nil,
                email: String? = nil,
                avatar: String? = nil,
                custom: [String: AnyObject]? = nil) {
        self.key = key
        self.name = name
        self.firstName = firstName
        self.lastName = lastName
        self.isAnonymous = isAnonymous
        self.country = country
        self.ip = ip
        self.email = email
        self.avatar = avatar
        self.custom = custom
        self.device = custom?[Constants.keyDevice] as? String
        self.os = custom?[Constants.keyOs] as? String
        lastUpdated = Date()
    }
    
    public init(json: [String: AnyObject]) {
        //warning: implement
        key = UUID().uuidString
        isAnonymous = true
        lastUpdated = Date()
    }
    
    public var jsonWithConfig: [String: AnyObject] {
        return [:]
    }
    
    public var jsonWithoutConfig: [String: AnyObject] {
        return [:]
    }

    public func flagExists(key: String) -> Bool {
        return false
    }
    
    public func flagValue(key: String) -> Any? {
        return nil
    }
    
    public class var anonymous: LDUser {
        return LDUser(isAnonymous: true)
    }
}

extension LDUser: Equatable {
    public static func ==(lhs: LDUser, rhs: LDUser) -> Bool {
        return lhs.key == rhs.key
    }
}
