//
//  LDUser.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

public struct LDUser {   //Public access means an app will have to compose its user type with an LDUser. The compiler will not allow subclassing.
    
    fileprivate struct Constants {
        static let keyDevice = "device"
        static let keyOs = "os"
    }
    
    public let key: String
    public var name: String?
    public var firstName: String?
    public var lastName: String?
    public var country: String?
    // swiftlint:disable:next identifier_name
    public var ip: String?
    public var email: String?
    public var avatar: String?
    public var custom: [String: Any]?
    public var isAnonymous: Bool
    public var device: String?
    // swiftlint:disable:next identifier_name
    public var os: String?
    
    internal private(set) var lastUpdated: Date
    internal var featureFlags = [String: LDFeatureFlag]()   //TODO: Should these be here, somewhere else, or their own object?
    
    public init(key: String? = nil,
                name: String? = nil,
                firstName: String? = nil,
                lastName: String? = nil,
                isAnonymous: Bool = false,
                country: String? = nil,
                // swiftlint:disable:next identifier_name
                ip: String? = nil,
                email: String? = nil,
                avatar: String? = nil,
                custom: [String: AnyObject]? = nil) {
        self.key = key ?? LDUser.defaultKey
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
    
    public func flagValue(key: String) -> LDFlagValue? {
        return nil
    }
    
    //Converts user.featureFlags into a flag dictionary
    internal var allFlags: [String: LDFlagValue] {
        return [:]
    }
    
    public static var anonymous: LDUser {
        return LDUser(isAnonymous: true)
    }
    
    //For iOS & tvOS, this should be UIDevice.current.identifierForVendor.UUIDString
    //For macOS & watchOS, this should be a UUID that the sdk creates and stores so that the value returned here should be always the same
    private static var defaultKey: String {
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString    //TODO: Instead of a new UUID here, add a UUID that is retained and used for any LDUser created without a key. That feels like an extension on UserDefaults.
        //TODO: Apple docs says `identifierForVendor` might be nil early in the startup sequence. They recommend trying again later. That will prove a little difficult since the sdk doesn't control when it's instantiated.
    }
}

extension LDUser: Equatable {
    public static func == (lhs: LDUser, rhs: LDUser) -> Bool {
        return lhs.key == rhs.key
    }
}
