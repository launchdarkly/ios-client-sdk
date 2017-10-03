//
//  LDUser.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

public struct LDUser {   //Public access means an app will have to compose its user type with an LDUser. The compiler will not allow subclassing.
    
    enum CodingKeys: String, CodingKey {
        case key, name, firstName, lastName, country, ipAddress = "ip", email, avatar, custom, isAnonymous, device, operatingSystem = "os", lastUpdated, config
    }

    public var key: String
    public var name: String?
    public var firstName: String?
    public var lastName: String?
    public var country: String?
    public var ipAddress: String?
    public var email: String?
    public var avatar: String?
    public var custom: [String: Encodable]?
    public var isAnonymous: Bool
    public var device: String?
    public var operatingSystem: String?
    
    internal private(set) var lastUpdated: Date
    internal var flagStore = LDFlagStore()
    
    public init(key: String? = nil,
                name: String? = nil,
                firstName: String? = nil,
                lastName: String? = nil,
                isAnonymous: Bool = false,
                country: String? = nil,
                ipAddress: String? = nil,
                email: String? = nil,
                avatar: String? = nil,
                custom: [String: Encodable]? = nil) {
        self.key = key ?? LDUser.defaultKey
        self.name = name
        self.firstName = firstName
        self.lastName = lastName
        self.isAnonymous = isAnonymous
        self.country = country
        self.ipAddress = ipAddress
        self.email = email
        self.avatar = avatar
        self.custom = custom
        self.device = custom?[CodingKeys.device.rawValue] as? String
        self.operatingSystem = custom?[CodingKeys.operatingSystem.rawValue] as? String
        lastUpdated = Date()
    }
    
    public init(jsonDictionary: [String: Encodable]) {
        key = jsonDictionary[CodingKeys.key.rawValue] as? String ?? LDUser.defaultKey
        isAnonymous = jsonDictionary[CodingKeys.isAnonymous.rawValue] as? Bool ?? false
        if let jsonLastUpdated = jsonDictionary[CodingKeys.lastUpdated.rawValue] as? String {
            lastUpdated = DateFormatter.ldUserFormatter.date(from: jsonLastUpdated) ?? Date()
        } else {
            lastUpdated = Date()
        }

        name = jsonDictionary[CodingKeys.name.rawValue] as? String
        firstName = jsonDictionary[CodingKeys.firstName.rawValue] as? String
        lastName = jsonDictionary[CodingKeys.lastName.rawValue] as? String
        country = jsonDictionary[CodingKeys.country.rawValue] as? String
        ipAddress = jsonDictionary[CodingKeys.ipAddress.rawValue] as? String
        email = jsonDictionary[CodingKeys.email.rawValue] as? String
        avatar = jsonDictionary[CodingKeys.avatar.rawValue] as? String

        custom = jsonDictionary[CodingKeys.custom.rawValue] as? [String: Encodable]
        device = custom?[CodingKeys.device.rawValue] as? String
        operatingSystem = custom?[CodingKeys.operatingSystem.rawValue] as? String

        flagStore.replaceStore(newFlags: jsonDictionary[CodingKeys.config.rawValue] as? [String: Encodable], source: .cache)
    }
    
    public var jsonDictionaryWithConfig: [String: Encodable] {
        var json = jsonDictionaryWithoutConfig
        json[CodingKeys.config.rawValue] = (try? flagStore.toJsonDictionary()) ?? [:]
        return json
    }

    public var jsonDictionaryWithoutConfig: [String: Encodable] {
        var json = [String: Encodable]()
        json[CodingKeys.key.rawValue] = key
        json[CodingKeys.name.rawValue] = name
        json[CodingKeys.firstName.rawValue] = firstName
        json[CodingKeys.lastName.rawValue] = lastName
        json[CodingKeys.country.rawValue] = country
        json[CodingKeys.ipAddress.rawValue] = ipAddress
        json[CodingKeys.email.rawValue] = email
        json[CodingKeys.avatar.rawValue] = avatar

        var encodedCustom = custom ?? [String: Encodable]()
        encodedCustom[CodingKeys.device.rawValue] = device
        encodedCustom[CodingKeys.operatingSystem.rawValue] = operatingSystem
        if !encodedCustom.isEmpty {
            json[CodingKeys.custom.rawValue] = custom
        }

        json[CodingKeys.isAnonymous.rawValue] = isAnonymous
        json[CodingKeys.lastUpdated.rawValue] = DateFormatter.ldUserFormatter.string(from: lastUpdated)

        return json
    }

    public func merge(with otherUser: LDUser) -> LDUser {
        var mergedUser = self

        mergedUser.key = otherUser.key
        mergedUser.name = otherUser.name.isNilOrEmpty ? mergedUser.name : otherUser.name
        mergedUser.firstName = otherUser.firstName.isNilOrEmpty ? mergedUser.firstName : otherUser.firstName
        mergedUser.lastName = otherUser.lastName.isNilOrEmpty ? mergedUser.lastName : otherUser.lastName
        mergedUser.country = otherUser.country.isNilOrEmpty ? mergedUser.country : otherUser.country
        mergedUser.ipAddress = otherUser.ipAddress.isNilOrEmpty ? mergedUser.ipAddress : otherUser.ipAddress
        mergedUser.email = otherUser.email.isNilOrEmpty ? mergedUser.email : otherUser.email
        mergedUser.avatar = otherUser.avatar.isNilOrEmpty ? mergedUser.avatar : otherUser.avatar
        mergedUser.custom = otherUser.custom.isNilOrEmpty ? mergedUser.custom : otherUser.custom
        mergedUser.device = otherUser.device.isNilOrEmpty ? mergedUser.device : otherUser.device
        mergedUser.operatingSystem = otherUser.operatingSystem.isNilOrEmpty ? mergedUser.operatingSystem : otherUser.operatingSystem
        mergedUser.isAnonymous = otherUser.isAnonymous
        mergedUser.lastUpdated = Date()

        return mergedUser
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

extension DateFormatter {
    class var ldUserFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }
}
