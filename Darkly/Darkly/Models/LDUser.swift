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
        case key, name, firstName, lastName, country, ipAddress = "ip", email, avatar, custom, isAnonymous = "anonymous", device, operatingSystem = "os", lastUpdated = "updatedAt", config, privateAttributes = "privateAttrs"
    }

    public static var privatizableAttributes: [String] {
        return [CodingKeys.name.rawValue, CodingKeys.firstName.rawValue, CodingKeys.lastName.rawValue, CodingKeys.country.rawValue, CodingKeys.ipAddress.rawValue, CodingKeys.email.rawValue, CodingKeys.avatar.rawValue, CodingKeys.custom.rawValue]
    }
    static var sdkSetAttributes: [String] { return [CodingKeys.device.rawValue, CodingKeys.operatingSystem.rawValue] }

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
    public var privateAttributes: [String]?
    
    internal fileprivate(set) var lastUpdated: Date
    internal var flagStore: FlagMaintaining = FlagStore()
    
    public init(key: String? = nil,
                name: String? = nil,
                firstName: String? = nil,
                lastName: String? = nil,
                country: String? = nil,
                ipAddress: String? = nil,
                email: String? = nil,
                avatar: String? = nil,
                custom: [String: Any]? = nil,
                isAnonymous: Bool? = nil,
                privateAttributes: [String]? = nil) {
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
        self.device = custom?[CodingKeys.device.rawValue] as? String ?? UIDevice.current.model
        self.operatingSystem = custom?[CodingKeys.operatingSystem.rawValue] as? String ?? UIDevice.current.systemVersion
        self.privateAttributes = privateAttributes
        lastUpdated = Date()
        Log.debug(typeName(and: #function) + "user: \(self)")
    }
    
    public init(userDictionary: [String: Any]) {
        key = userDictionary[CodingKeys.key.rawValue] as? String ?? LDUser.defaultKey
        isAnonymous = userDictionary[CodingKeys.isAnonymous.rawValue] as? Bool ?? false
        lastUpdated = (userDictionary[CodingKeys.lastUpdated.rawValue] as? String)?.dateValue ?? Date()

        name = userDictionary[CodingKeys.name.rawValue] as? String
        firstName = userDictionary[CodingKeys.firstName.rawValue] as? String
        lastName = userDictionary[CodingKeys.lastName.rawValue] as? String
        country = userDictionary[CodingKeys.country.rawValue] as? String
        ipAddress = userDictionary[CodingKeys.ipAddress.rawValue] as? String
        email = userDictionary[CodingKeys.email.rawValue] as? String
        avatar = userDictionary[CodingKeys.avatar.rawValue] as? String
        privateAttributes = userDictionary[CodingKeys.privateAttributes.rawValue] as? [String]

        custom = userDictionary[CodingKeys.custom.rawValue] as? [String: Any]
        device = custom?[CodingKeys.device.rawValue] as? String
        operatingSystem = custom?[CodingKeys.operatingSystem.rawValue] as? String

        flagStore = FlagStore(featureFlagDictionary: userDictionary[CodingKeys.config.rawValue] as? [String: Any], flagValueSource: .cache)
        Log.debug(typeName(and: #function) + "user: \(self)")
    }

    //swiftlint:disable:next cyclomatic_complexity
    func value(for attribute: String) -> Any? {
        switch attribute {
        case CodingKeys.key.rawValue: return key
        case CodingKeys.lastUpdated.rawValue: return lastUpdated
        case CodingKeys.isAnonymous.rawValue: return isAnonymous
        case CodingKeys.name.rawValue: return name
        case CodingKeys.firstName.rawValue: return firstName
        case CodingKeys.lastName.rawValue: return lastName
        case CodingKeys.country.rawValue: return country
        case CodingKeys.ipAddress.rawValue: return ipAddress
        case CodingKeys.email.rawValue: return email
        case CodingKeys.avatar.rawValue: return avatar
        case CodingKeys.custom.rawValue: return custom
        case CodingKeys.device.rawValue: return device
        case CodingKeys.operatingSystem.rawValue: return operatingSystem
        case CodingKeys.config.rawValue: return flagStore.featureFlags
        case CodingKeys.privateAttributes.rawValue: return privateAttributes
        default: return nil
        }
    }
    var customWithoutSdkSetAttributes: [String: Any]? { return custom?.filter { (key, _) in !LDUser.sdkSetAttributes.contains(key) } }

    func dictionaryValue(includeFlagConfig: Bool, includePrivateAttributes includePrivate: Bool, config: LDConfig) -> [String: Any] {
        var dictionary = [String: Any]()
        var redactedAttributes = [String]()
        let combinedPrivateAttributes = config.allUserAttributesPrivate ? LDUser.privatizableAttributes
            : (privateAttributes ?? []) + (config.privateUserAttributes ?? [])

        dictionary[CodingKeys.key.rawValue] = key

        let optionalAttributes = LDUser.privatizableAttributes.filter { (attribute) in attribute != CodingKeys.custom.rawValue }
        optionalAttributes.forEach { (attribute) in
            let value = self.value(for: attribute)
            if !includePrivate && combinedPrivateAttributes.isPrivate(attribute) && value != nil {
                redactedAttributes.append(attribute)
            } else {
                dictionary[attribute] = value
            }
        }

        var customDictionary = [String: Any]()
        if !includePrivate && combinedPrivateAttributes.isPrivate(CodingKeys.custom.rawValue) && !customWithoutSdkSetAttributes.isNilOrEmpty {
            redactedAttributes.append(CodingKeys.custom.rawValue)
        } else {
            if let custom = customWithoutSdkSetAttributes, !custom.isEmpty {
                custom.keys.forEach { (customAttribute) in
                    if !includePrivate && combinedPrivateAttributes.isPrivate(customAttribute) && custom[customAttribute] != nil {
                        redactedAttributes.append(customAttribute)
                    } else {
                        customDictionary[customAttribute] = custom[customAttribute]
                    }
                }
            }
        }
        customDictionary[CodingKeys.device.rawValue] = device
        customDictionary[CodingKeys.operatingSystem.rawValue] = operatingSystem
        dictionary[CodingKeys.custom.rawValue] = customDictionary.isEmpty ? nil : customDictionary

        if !includePrivate && !redactedAttributes.isEmpty {
            let redactedAttributeSet: Set<String> = Set(redactedAttributes)
            dictionary[CodingKeys.privateAttributes.rawValue] = redactedAttributeSet.sorted()
        }

        dictionary[CodingKeys.isAnonymous.rawValue] = isAnonymous
        dictionary[CodingKeys.lastUpdated.rawValue] = DateFormatter.ldDateFormatter.string(from: lastUpdated)

        if includeFlagConfig {
            dictionary[CodingKeys.config.rawValue] = flagStore.featureFlags
        }

        return dictionary
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
        return key
    }
}

extension LDUser: Equatable {
    public static func == (lhs: LDUser, rhs: LDUser) -> Bool {
        return lhs.key == rhs.key
    }
}

extension DateFormatter {
    class var ldDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }
}

extension Date {
    var stringValue: String { return DateFormatter.ldDateFormatter.string(from: self) }

    //When a date is converted to JSON, the resulting string is not as precise as the original date (only to the nearest .001s)
    //By converting the date to json, then back into a date, the result can be compared with any date re-inflated from json
    var stringEquivalentDate: Date { return stringValue.dateValue }
}

extension String {
    var dateValue: Date { return DateFormatter.ldDateFormatter.date(from: self) ?? Date() }
}

extension Array where Element == String {
    fileprivate func isPrivate(_ attribute: String) -> Bool {
        return contains(attribute)
    }
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
        encoder.encode(wrapped.privateAttributes, forKey: LDUser.CodingKeys.privateAttributes.rawValue)
        encoder.encode([Keys.featureFlags: wrapped.flagStore.featureFlags.dictionaryValue(exciseNil: true)], forKey: LDUser.CodingKeys.config.rawValue)
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
                          isAnonymous: decoder.decodeBool(forKey: LDUser.CodingKeys.isAnonymous.rawValue),
                          privateAttributes: decoder.decodeObject(forKey: LDUser.CodingKeys.privateAttributes.rawValue) as? [String]
        )
        user.device = decoder.decodeObject(forKey: LDUser.CodingKeys.device.rawValue) as? String
        user.operatingSystem = decoder.decodeObject(forKey: LDUser.CodingKeys.operatingSystem.rawValue) as? String
        user.lastUpdated = decoder.decodeObject(forKey: LDUser.CodingKeys.lastUpdated.rawValue) as? Date ?? Date()
        let wrappedFlags = decoder.decodeObject(forKey: LDUser.CodingKeys.config.rawValue) as? [String: Any]
        user.flagStore = FlagStore(featureFlagDictionary: wrappedFlags?[Keys.featureFlags] as? [String: Any], flagValueSource: .cache)
        self.init(user: user)
    }

    class func configureKeyedArchiversToHandleVersion2_3_0AndOlderUserCacheFormat() {
        NSKeyedUnarchiver.setClass(LDUserWrapper.self, forClassName: "LDUserModel")
        NSKeyedArchiver.setClassName("LDUserModel", for: LDUserWrapper.self)
    }
}

extension LDUser: TypeIdentifying { }
