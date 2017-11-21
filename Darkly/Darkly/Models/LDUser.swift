//
//  LDUser.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/11/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

public struct LDUser {
    
    enum CodingKeys: String, CodingKey {
        case key, name, firstName, lastName, country, ipAddress = "ip", email, avatar, custom, isAnonymous = "anonymous", device, operatingSystem = "os", lastUpdated = "updatedAt", config
    }

    public var key: String
    public var name: String?
    public var firstName: String?
    public var lastName: String?
    public var country: String?
    public var ipAddress: String?
    public var email: String?
    public var avatar: String?
    public var custom: [String: Any]?
    public var isAnonymous: Bool
    public var device: String?
    public var operatingSystem: String?
    
    internal fileprivate(set) var lastUpdated: Date
    internal var flagStore: LDFlagMaintaining = LDFlagStore()
    
    public init(key: String? = nil,
                name: String? = nil,
                firstName: String? = nil,
                lastName: String? = nil,
                country: String? = nil,
                ipAddress: String? = nil,
                email: String? = nil,
                avatar: String? = nil,
                custom: [String: Any]? = nil,
                isAnonymous: Bool? = nil) {
        let selectedKey = key ?? LDUser.defaultKey
        self.key = selectedKey
        self.name = name
        self.firstName = firstName
        self.lastName = lastName
        self.country = country
        self.ipAddress = ipAddress
        self.email = email
        self.avatar = avatar
        self.custom = custom
        self.isAnonymous = isAnonymous ?? (selectedKey == LDUser.defaultKey)
        self.device = custom?[CodingKeys.device.rawValue] as? String
        self.operatingSystem = custom?[CodingKeys.operatingSystem.rawValue] as? String
        lastUpdated = Date()
    }
    
    public init(jsonDictionary: [String: Any]) {
        key = jsonDictionary[CodingKeys.key.rawValue] as? String ?? LDUser.defaultKey
        isAnonymous = jsonDictionary[CodingKeys.isAnonymous.rawValue] as? Bool ?? false
        lastUpdated = (jsonDictionary[CodingKeys.lastUpdated.rawValue] as? String)?.userDate ?? Date()

        name = jsonDictionary[CodingKeys.name.rawValue] as? String
        firstName = jsonDictionary[CodingKeys.firstName.rawValue] as? String
        lastName = jsonDictionary[CodingKeys.lastName.rawValue] as? String
        country = jsonDictionary[CodingKeys.country.rawValue] as? String
        ipAddress = jsonDictionary[CodingKeys.ipAddress.rawValue] as? String
        email = jsonDictionary[CodingKeys.email.rawValue] as? String
        avatar = jsonDictionary[CodingKeys.avatar.rawValue] as? String

        custom = jsonDictionary[CodingKeys.custom.rawValue] as? [String: Any]
        device = custom?[CodingKeys.device.rawValue] as? String
        operatingSystem = custom?[CodingKeys.operatingSystem.rawValue] as? String

        flagStore.replaceStore(newFlags: jsonDictionary[CodingKeys.config.rawValue] as? [String: Any], source: .cache)
    }
    
    public var jsonDictionaryWithConfig: [String: Any] {
        var json = jsonDictionaryWithoutConfig
        json[CodingKeys.config.rawValue] = flagStore.featureFlags
        return json
    }

    public var jsonDictionaryWithoutConfig: [String: Any] {
        var json = [String: Any]()
        json[CodingKeys.key.rawValue] = key
        json[CodingKeys.name.rawValue] = name
        json[CodingKeys.firstName.rawValue] = firstName
        json[CodingKeys.lastName.rawValue] = lastName
        json[CodingKeys.country.rawValue] = country
        json[CodingKeys.ipAddress.rawValue] = ipAddress
        json[CodingKeys.email.rawValue] = email
        json[CodingKeys.avatar.rawValue] = avatar

        var encodedCustom = custom ?? [String: Any]()
        encodedCustom[CodingKeys.device.rawValue] = device
        encodedCustom[CodingKeys.operatingSystem.rawValue] = operatingSystem
        if !encodedCustom.isEmpty {
            json[CodingKeys.custom.rawValue] = custom
        }

        json[CodingKeys.isAnonymous.rawValue] = isAnonymous
        json[CodingKeys.lastUpdated.rawValue] = DateFormatter.ldUserFormatter.string(from: lastUpdated)

        return json
    }

    //For iOS & tvOS, this should be UIDevice.current.identifierForVendor.UUIDString
    //For macOS & watchOS, this should be a UUID that the sdk creates and stores so that the value returned here should be always the same
    static var defaultKey: String {
        #if os(iOS) || os(tvOS)
            return UIDevice.current.identifierForVendor?.uuidString ?? UserDefaults.standard.installationKey
        #else
            return UserDefaults.standard.installationKey
        #endif
    }
}

extension UserDefaults {
    struct Keys {
        fileprivate static let deviceIdentifier = "ldDeviceIdentifier"
    }

    var installationKey: String {
        if let key = self.string(forKey: Keys.deviceIdentifier) { return key }

        let key = UUID().uuidString
        self.set(key, forKey: Keys.deviceIdentifier)
        self.synchronize()
        return key
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

extension Date {
    var jsonDate: String { return DateFormatter.ldUserFormatter.string(from: self) }
}

extension String {
    var userDate: Date { return DateFormatter.ldUserFormatter.date(from: self) ?? Date() }
}

@objc final class LDUserWrapper: NSObject {
    let wrapped: LDUser

    init(user: LDUser) {
        wrapped = user
        super.init()
    }
}

extension LDUserWrapper: NSCoding {
    struct Keys {
        fileprivate static let featureFlags = "featuresJsonDictionary"
    }

    func encode(with encoder: NSCoder) {
        encoder.encode(wrapped.key, forKey: LDUser.CodingKeys.key.rawValue)
        encoder.encode(wrapped.name, forKey: LDUser.CodingKeys.name.rawValue)
        encoder.encode(wrapped.firstName, forKey: LDUser.CodingKeys.firstName.rawValue)
        encoder.encode(wrapped.lastName, forKey: LDUser.CodingKeys.lastName.rawValue)
        encoder.encode(wrapped.country, forKey: LDUser.CodingKeys.country.rawValue)
        encoder.encode(wrapped.ipAddress, forKey: LDUser.CodingKeys.ipAddress.rawValue)
        encoder.encode(wrapped.email, forKey: LDUser.CodingKeys.email.rawValue)
        encoder.encode(wrapped.avatar, forKey: LDUser.CodingKeys.avatar.rawValue)
        encoder.encode(wrapped.custom, forKey: LDUser.CodingKeys.custom.rawValue)
        encoder.encode(wrapped.isAnonymous, forKey: LDUser.CodingKeys.isAnonymous.rawValue)
        encoder.encode(wrapped.device, forKey: LDUser.CodingKeys.device.rawValue)
        encoder.encode(wrapped.operatingSystem, forKey: LDUser.CodingKeys.operatingSystem.rawValue)
        encoder.encode(wrapped.lastUpdated, forKey: LDUser.CodingKeys.lastUpdated.rawValue)
        encoder.encode([Keys.featureFlags: wrapped.flagStore.featureFlags], forKey: LDUser.CodingKeys.config.rawValue)
    }

    public convenience init?(coder decoder: NSCoder) {
        var user = LDUser(key: decoder.decodeObject(forKey: LDUser.CodingKeys.key.rawValue) as? String,
                          name: decoder.decodeObject(forKey: LDUser.CodingKeys.name.rawValue) as? String,
                          firstName: decoder.decodeObject(forKey: LDUser.CodingKeys.firstName.rawValue) as? String,
                          lastName: decoder.decodeObject(forKey: LDUser.CodingKeys.lastName.rawValue) as? String,
                          country: decoder.decodeObject(forKey: LDUser.CodingKeys.country.rawValue) as? String,
                          ipAddress: decoder.decodeObject(forKey: LDUser.CodingKeys.ipAddress.rawValue) as? String,
                          email: decoder.decodeObject(forKey: LDUser.CodingKeys.email.rawValue) as? String,
                          avatar: decoder.decodeObject(forKey: LDUser.CodingKeys.avatar.rawValue) as? String,
                          custom: decoder.decodeObject(forKey: LDUser.CodingKeys.custom.rawValue) as? [String: Any],
                          isAnonymous: decoder.decodeBool(forKey: LDUser.CodingKeys.isAnonymous.rawValue)
        )
        user.device = decoder.decodeObject(forKey: LDUser.CodingKeys.device.rawValue) as? String
        user.operatingSystem = decoder.decodeObject(forKey: LDUser.CodingKeys.operatingSystem.rawValue) as? String
        user.lastUpdated = decoder.decodeObject(forKey: LDUser.CodingKeys.lastUpdated.rawValue) as? Date ?? Date()
        let wrappedFlags = decoder.decodeObject(forKey: LDUser.CodingKeys.config.rawValue) as? [String: Any]
        let flags = wrappedFlags?[Keys.featureFlags] as? [String: Any]
        user.flagStore.replaceStore(newFlags: flags, source: .cache)
        self.init(user: user)
    }

    class func configureKeyedArchiversToHandleVersion2_3_0AndOlderUserCacheFormat() {
        NSKeyedUnarchiver.setClass(LDUserWrapper.self, forClassName: "LDUserModel")
        NSKeyedArchiver.setClassName("LDUserModel", for: LDUserWrapper.self)
    }
}
