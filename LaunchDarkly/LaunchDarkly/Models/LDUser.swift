import Foundation

typealias UserKey = String  // use for identifying semantics for strings, particularly in dictionaries

/**
 LDUser allows clients to collect information about users in order to refine the feature flag values sent to the SDK. For example, the client app may launch with the SDK defined anonymous user. As the user works with the client app, information may be collected as needed and sent to LaunchDarkly. The client app controls the information collected, which LaunchDarkly does not use except as the client directs to refine feature flags. Client apps should follow [Apple's Privacy Policy](apple.com/legal/privacy) when collecting user information.
 The SDK caches last known feature flags for use on app startup to provide continuity with the last app run. Provided the LDClient is online and can establish a connection with LaunchDarkly servers, cached information will only be used a very short time. Once the latest feature flags arrive at the SDK, the SDK no longer uses cached feature flags. The SDK retains feature flags on the last 5 client defined users. The SDK will retain feature flags until they are overwritten by a different user's feature flags, or until the user removes the app from the device.
 The SDK does not cache user information collected, except for the user key. The user key is used to identify the cached feature flags for that user. Client app developers should use caution not to use sensitive user information as the user-key.
 */
public struct LDUser {

    /// String keys associated with LDUser properties.
    public enum CodingKeys: String, CodingKey {
        /// Key names match the corresponding LDUser property
        case key, name, firstName, lastName, country, ipAddress = "ip", email, avatar, custom, isAnonymous = "anonymous", device, operatingSystem = "os", config, privateAttributes = "privateAttrs", secondary
    }

    static let optionalAttributes = UserAttribute.BuiltIn.allBuiltIns.filter { $0.name != "key" && $0.name != "anonymous"}

    static let storedIdKey: String = "ldDeviceIdentifier"

    /// Client app defined string that uniquely identifies the user. If the client app does not define a key, the SDK will assign an identifier associated with the anonymous user. The key cannot be made private.
    public var key: String
    /// The secondary key for the user. See the [documentation](https://docs.launchdarkly.com/home/flags/targeting-users#percentage-rollouts) for more information on it's use for percentage rollout bucketing.
    public var secondary: String?
    /// Client app defined name for the user. (Default: nil)
    public var name: String?
    /// Client app defined first name for the user. (Default: nil)
    public var firstName: String?
    /// Client app defined last name for the user. (Default: nil)
    public var lastName: String?
    /// Client app defined country for the user. (Default: nil)
    public var country: String?
    /// Client app defined ipAddress for the user. (Default: nil)
    public var ipAddress: String?
    /// Client app defined email address for the user. (Default: nil)
    public var email: String?
    /// Client app defined avatar for the user. (Default: nil)
    public var avatar: String?
    /// Client app defined dictionary for the user. The client app may declare top level dictionary items as private. If the client app defines custom as private, the SDK considers the dictionary private except for device & operatingSystem (which cannot be made private). See `privateAttributes` for details. (Default: nil)
    public var custom: [String: Any]
    /// Client app defined isAnonymous for the user. If the client app does not define isAnonymous, the SDK will use the `key` to set this attribute. isAnonymous cannot be made private. (Default: true)
    public var isAnonymous: Bool

    /**
     Client app defined privateAttributes for the user.
     The SDK will not include private attribute values in analytics events, but private attribute names will be sent.
     This attribute is ignored if `LDConfig.allUserAttributesPrivate` is true. Combined with `LDConfig.privateUserAttributes`. The SDK considers attributes appearing in either list as private. Client apps may define attributes found in `privatizableAttributes` and top level `custom` dictionary keys here. (Default: nil)
     See Also: `LDConfig.allUserAttributesPrivate` and `LDConfig.privateUserAttributes`.
    */
    public var privateAttributes: [UserAttribute]

    /// An NSObject wrapper for the Swift LDUser struct. Intended for use in mixed apps when Swift code needs to pass a user into an Objective-C method.
    public var objcLdUser: ObjcLDUser { ObjcLDUser(self) }

    /**
     Initializer to create a LDUser. Client configurable attributes each have an optional parameter to facilitate setting user information into the LDUser. The SDK will automatically set `key`, `device`, `operatingSystem`, and `isAnonymous` attributes if the client does not provide them. The SDK embeds `device` and `operatingSystem` into the `custom` dictionary for transmission to LaunchDarkly.
     - parameter key: String that uniquely identifies the user. If the client app does not define a key, the SDK will assign an identifier associated with the anonymous user.
     - parameter name: Client app defined name for the user. (Default: nil)
     - parameter firstName: Client app defined first name for the user. (Default: nil)
     - parameter lastName: Client app defined last name for the user. (Default: nil)
     - parameter country: Client app defined country for the user. (Default: nil)
     - parameter ipAddress: Client app defined ipAddress for the user. (Default: nil)
     - parameter email: Client app defined email address for the user. (Default: nil)
     - parameter avatar: Client app defined avatar for the user. (Default: nil)
     - parameter custom: Client app defined dictionary for the user. The client app may declare top level dictionary items as private. If the client app defines custom as private, the SDK considers the dictionary private except for device & operatingSystem (which cannot be made private). See `privateAttributes` for details. (Default: nil)
     - parameter isAnonymous: Client app defined isAnonymous for the user. If the client app does not define isAnonymous, the SDK will use the `key` to set this attribute. (Default: nil)
     - parameter device: Client app defined device for the user. The SDK will determine the device automatically, however the client app can override the value. The SDK will insert the device into the `custom` dictionary. (Default: nil)
     - parameter operatingSystem: Client app defined operatingSystem for the user. The SDK will determine the operatingSystem automatically, however the client app can override the value. The SDK will insert the operatingSystem into the `custom` dictionary. (Default: nil)
     - parameter privateAttributes: Client app defined privateAttributes for the user. (Default: nil)
     - parameter secondary: Secondary attribute value. (Default: nil)
     */
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
                privateAttributes: [UserAttribute]? = nil,
                secondary: String? = nil) {
        let environmentReporter = EnvironmentReporter()
        let selectedKey = key ?? LDUser.defaultKey(environmentReporter: environmentReporter)
        self.key = selectedKey
        self.secondary = secondary
        self.name = name
        self.firstName = firstName
        self.lastName = lastName
        self.country = country
        self.ipAddress = ipAddress
        self.email = email
        self.avatar = avatar
        self.isAnonymous = isAnonymous ?? (selectedKey == LDUser.defaultKey(environmentReporter: environmentReporter))
        self.custom = custom ?? [:]
        self.custom.merge([CodingKeys.device.rawValue: environmentReporter.deviceModel,
                           CodingKeys.operatingSystem.rawValue: environmentReporter.systemVersion]) { lhs, _ in lhs }
        self.privateAttributes = privateAttributes ?? []
        Log.debug(typeName(and: #function) + "user: \(self)")
    }

    /**
     Internal initializer that accepts an environment reporter, used for testing
    */
    init(environmentReporter: EnvironmentReporting) {
        self.init(key: LDUser.defaultKey(environmentReporter: environmentReporter),
                  custom: [CodingKeys.device.rawValue: environmentReporter.deviceModel,
                           CodingKeys.operatingSystem.rawValue: environmentReporter.systemVersion],
                  isAnonymous: true)
    }

    private func value(for attribute: UserAttribute) -> Any? {
        if let builtInGetter = attribute.builtInGetter {
            return builtInGetter(self)
        }
        return custom[attribute.name]
    }

    /// Dictionary with LDUser attribute keys and values, with options to include feature flags and private attributes. LDConfig object used to help resolving what attributes should be private.
    /// - parameter includePrivateAttributes: Controls whether the resulting dictionary includes private attributes
    /// - parameter config: Provides supporting information for defining private attributes
    func dictionaryValue(includePrivateAttributes includePrivate: Bool, config: LDConfig) -> [String: Any] {
        let allPrivate = !includePrivate && config.allUserAttributesPrivate
        let privateAttributeNames = includePrivate ? [] : (privateAttributes + config.privateUserAttributes).map { $0.name }

        var dictionary: [String: Any] = [:]
        var redactedAttributes: [String] = []

        dictionary[CodingKeys.key.rawValue] = key
        dictionary[CodingKeys.isAnonymous.rawValue] = isAnonymous

        LDUser.optionalAttributes.forEach { attribute in
            if let value = self.value(for: attribute) {
                if allPrivate || privateAttributeNames.contains(attribute.name) {
                    redactedAttributes.append(attribute.name)
                } else {
                    dictionary[attribute.name] = value
                }
            }
        }

        var customDictionary: [String: Any] = [:]
        custom.forEach { attrName, attrVal in
            if allPrivate || privateAttributeNames.contains(attrName) {
                redactedAttributes.append(attrName)
            } else {
                customDictionary[attrName] = attrVal
            }
        }
        dictionary[CodingKeys.custom.rawValue] = customDictionary.isEmpty ? nil : customDictionary

        if !redactedAttributes.isEmpty {
            dictionary[CodingKeys.privateAttributes.rawValue] = Set(redactedAttributes).sorted()
        }

        return dictionary
    }

    /// Default key is the LDUser.key the SDK provides when any intializer is called without defining the key. The key should be constant with respect to the client app installation on a specific device. (The key may change if the client app is uninstalled and then reinstalled on the same device.)
    /// - parameter environmentReporter: The environmentReporter provides selected information that varies between OS regarding how it's determined
    static func defaultKey(environmentReporter: EnvironmentReporting) -> String {
        // For iOS & tvOS, this should be UIDevice.current.identifierForVendor.UUIDString
        // For macOS & watchOS, this should be a UUID that the sdk creates and stores so that the value returned here should be always the same
        if let vendorUUID = environmentReporter.vendorUUID {
            return vendorUUID
        }
        if let storedId = UserDefaults.standard.string(forKey: storedIdKey) {
            return storedId
        }
        let key = UUID().uuidString
        UserDefaults.standard.set(key, forKey: storedIdKey)
        return key
    }
}

extension LDUser: Equatable {
    /// Compares users by comparing their user keys only, to allow the client app to collect user information over time
    public static func == (lhs: LDUser, rhs: LDUser) -> Bool {
        lhs.key == rhs.key
    }
}

/// Class providing ObjC interoperability with the LDUser struct
@objc final class LDUserWrapper: NSObject {
    let wrapped: LDUser

    init(user: LDUser) {
        wrapped = user
        super.init()
    }
}

extension LDUserWrapper {
    struct Keys {
        fileprivate static let featureFlags = "featuresJsonDictionary"
    }
}

extension LDUser: TypeIdentifying { }

#if DEBUG
    extension LDUser {
        // Compares all user properties. Excludes the composed FlagStore, which contains the users feature flags
        func isEqual(to otherUser: LDUser) -> Bool {
            key == otherUser.key
                && secondary == otherUser.secondary
                && name == otherUser.name
                && firstName == otherUser.firstName
                && lastName == otherUser.lastName
                && country == otherUser.country
                && ipAddress == otherUser.ipAddress
                && email == otherUser.email
                && avatar == otherUser.avatar
                && AnyComparer.isEqual(custom, to: otherUser.custom)
                && isAnonymous == otherUser.isAnonymous
                && privateAttributes == otherUser.privateAttributes
        }
    }
#endif
