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
        //TODO: Device & OS should be set automatically if not presented in the custom dictionary
        self.device = custom?[CodingKeys.device.rawValue] as? String
        self.operatingSystem = custom?[CodingKeys.operatingSystem.rawValue] as? String
        self.privateAttributes = privateAttributes
        lastUpdated = Date()
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

        flagStore = LDFlagStore(featureFlags: userDictionary[CodingKeys.config.rawValue] as? [String: Any], flagValueSource: .cache)
    }

    func dictionaryValue(includeFlagConfig: Bool, includePrivateAttributes includePrivate: Bool, config: LDConfig) -> [String: Any] {
        var dictionary = [String: Any]()
        var redactedAttributes = [String]()
        let combinedPrivateAttributes = config.allUserAttributesPrivate ? LDUser.privatizableAttributes : (privateAttributes ?? []) + (config.privateUserAttributes ?? [])

        dictionary[CodingKeys.key.rawValue] = key

        (dictionary, redactedAttributes) = store(value: name, in: dictionary, for: CodingKeys.name.rawValue, includePrivate: includePrivate, privateAttributes: combinedPrivateAttributes, redactedAttributes: redactedAttributes)
        (dictionary, redactedAttributes) = store(value: firstName, in: dictionary, for: CodingKeys.firstName.rawValue, includePrivate: includePrivate, privateAttributes: combinedPrivateAttributes, redactedAttributes: redactedAttributes)
        (dictionary, redactedAttributes) = store(value: lastName, in: dictionary, for: CodingKeys.lastName.rawValue, includePrivate: includePrivate, privateAttributes: combinedPrivateAttributes, redactedAttributes: redactedAttributes)
        (dictionary, redactedAttributes) = store(value: country, in: dictionary, for: CodingKeys.country.rawValue, includePrivate: includePrivate, privateAttributes: combinedPrivateAttributes, redactedAttributes: redactedAttributes)
        (dictionary, redactedAttributes) = store(value: email, in: dictionary, for: CodingKeys.email.rawValue, includePrivate: includePrivate, privateAttributes: combinedPrivateAttributes, redactedAttributes: redactedAttributes)
        (dictionary, redactedAttributes) = store(value: ipAddress, in: dictionary, for: CodingKeys.ipAddress.rawValue, includePrivate: includePrivate, privateAttributes: combinedPrivateAttributes, redactedAttributes: redactedAttributes)
        (dictionary, redactedAttributes) = store(value: avatar, in: dictionary, for: CodingKeys.avatar.rawValue, includePrivate: includePrivate, privateAttributes: combinedPrivateAttributes, redactedAttributes: redactedAttributes)

        let customDictionary: [String: Any]?
        (customDictionary, redactedAttributes) = self.customDictionary(from: (custom, device, operatingSystem), includePrivate: includePrivate, privateAttributes: combinedPrivateAttributes, redactedAttributes: redactedAttributes)
        dictionary[CodingKeys.custom.rawValue] = customDictionary

        if !includePrivate && !redactedAttributes.isEmpty {
            let redactedAttributeSet: Set<String> = Set(redactedAttributes)
            dictionary[CodingKeys.privateAttributes.rawValue] = redactedAttributeSet.sorted
        }

        dictionary[CodingKeys.isAnonymous.rawValue] = isAnonymous
        dictionary[CodingKeys.lastUpdated.rawValue] = DateFormatter.ldDateFormatter.string(from: lastUpdated)

        if includeFlagConfig {
            dictionary[CodingKeys.config.rawValue] = flagStore.featureFlags
        }

        return dictionary
    }

    //swiftlint:disable:next function_parameter_count
    private func store(value: Any?, in dictionary: [String: Any], for attribute: String, includePrivate: Bool, privateAttributes: [String], redactedAttributes: [String]) -> ([String: Any], [String]) {
        guard let value = value else { return (dictionary, redactedAttributes) }
        if !includePrivate && privateAttributes.contains(attribute) {
            var redactedAttributes = redactedAttributes
            redactedAttributes.append(attribute)
            return (dictionary, redactedAttributes)
        }
        var dictionary = dictionary
        dictionary[attribute] = value
        return (dictionary, redactedAttributes)
    }

    private func customDictionary(from customElements: (custom: [String: Any]?, device: String?, operatingSystem: String?), includePrivate: Bool, privateAttributes: [String], redactedAttributes: [String]) -> ([String: Any]?, [String]) {
        var customDictionary = [String: Any]()
        var redactedAttributes = redactedAttributes
        let device = customElements.device
        let operatingSystem = customElements.operatingSystem

        if !includePrivate && privateAttributes.contains(CodingKeys.custom.rawValue) {
            if var custom = customElements.custom, !custom.isEmpty {
                custom.removeValue(forKey: CodingKeys.device.rawValue)
                custom.removeValue(forKey: CodingKeys.operatingSystem.rawValue)
                if !custom.isEmpty {
                    redactedAttributes.append(CodingKeys.custom.rawValue)
                }
            }
        } else {
            if let custom = customElements.custom, !custom.isEmpty {
                custom.keys.forEach { (customAttribute) in
                    if !includePrivate && privateAttributes.contains(customAttribute) && custom[customAttribute] != nil {
                        redactedAttributes.append(customAttribute)
                    } else {
                        customDictionary[customAttribute] = custom[customAttribute]
                    }
                }
            }
        }

        customDictionary[CodingKeys.device.rawValue] = device
        customDictionary[CodingKeys.operatingSystem.rawValue] = operatingSystem

        return (customDictionary.isEmpty ? nil : customDictionary, redactedAttributes)
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
                          isAnonymous: decoder.decodeBool(forKey: LDUser.CodingKeys.isAnonymous.rawValue),
                          privateAttributes: decoder.decodeObject(forKey: LDUser.CodingKeys.privateAttributes.rawValue) as? [String]
        )
        user.device = decoder.decodeObject(forKey: LDUser.CodingKeys.device.rawValue) as? String
        user.operatingSystem = decoder.decodeObject(forKey: LDUser.CodingKeys.operatingSystem.rawValue) as? String
        user.lastUpdated = decoder.decodeObject(forKey: LDUser.CodingKeys.lastUpdated.rawValue) as? Date ?? Date()
        let wrappedFlags = decoder.decodeObject(forKey: LDUser.CodingKeys.config.rawValue) as? [String: Any]
        let flags = wrappedFlags?[Keys.featureFlags] as? [String: Any]
        user.flagStore = LDFlagStore(featureFlags: flags, flagValueSource: .cache)
        self.init(user: user)
    }

    class func configureKeyedArchiversToHandleVersion2_3_0AndOlderUserCacheFormat() {
        NSKeyedUnarchiver.setClass(LDUserWrapper.self, forClassName: "LDUserModel")
        NSKeyedArchiver.setClassName("LDUserModel", for: LDUserWrapper.self)
    }
}
