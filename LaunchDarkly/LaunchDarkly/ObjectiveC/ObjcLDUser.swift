import Foundation

/**
 LDUser allows clients to collect information about users in order to refine the feature flag values sent to the SDK. For example, the client app may launch with the SDK defined anonymous user. As the user works with the client app, information may be collected as needed and sent to LaunchDarkly. The client app controls the information collected, which LaunchDarkly does not use except as the client directs to refine feature flags. Client apps should follow [Apple's Privacy Policy](apple.com/legal/privacy) when collecting user information.

 The SDK caches last known feature flags for use on app startup to provide continuity with the last app run. Provided the LDClient is online and can establish a connection with LaunchDarkly servers, cached information will only be used a very short time. Once the latest feature flags arrive at the SDK, the SDK no longer uses cached feature flags. The SDK retains feature flags on the last 5 client defined users. The SDK will retain feature flags until they are overwritten by a different user's feature flags, or until the user removes the app from the device.

 The SDK does not cache user information collected, except for the user key. The user key is used to identify the cached feature flags for that user. Client app developers should use caution not to use sensitive user information as the user-key.
 */
@objc (LDUser)
public final class ObjcLDUser: NSObject {
    var user: LDUser

    /// LDUser secondary attribute used to make `secondary` private
    @objc public class var attributeSecondary: String { "secondary" }
    /// LDUser name attribute used to make `name` private
    @objc public class var attributeName: String { "name" }
    /// LDUser firstName attribute used to make `firstName` private
    @objc public class var attributeFirstName: String { "firstName" }
    /// LDUser lastName attribute used to make `lastName` private
    @objc public class var attributeLastName: String { "lastName" }
    /// LDUser country attribute used to make `country` private
    @objc public class var attributeCountry: String { "country" }
    /// LDUser ipAddress attribute used to make `ipAddress` private
    @objc public class var attributeIPAddress: String { "ip" }
    /// LDUser email attribute used to make `email` private
    @objc public class var attributeEmail: String { "email" }
    /// LDUser avatar attribute used to make `avatar` private
    @objc public class var attributeAvatar: String { "avatar" }

    /// Client app defined string that uniquely identifies the user. If the client app does not define a key, the SDK will assign an identifier associated with the anonymous user. The key cannot be made private.
    @objc public var key: String {
        return user.key
    }
    /// The secondary key for the user. Read the [documentation](https://docs.launchdarkly.com/home/flags/rollouts) for more information on it's use for percentage rollout bucketing.
    @objc public var secondary: String? {
        get { user.secondary }
        set { user.secondary = newValue }
    }
    /// Client app defined name for the user. (Default: nil)
    @objc public var name: String? {
        get { user.name }
        set { user.name = newValue }
    }
    /// Client app defined first name for the user. (Default: nil)
    @objc public var firstName: String? {
        get { user.firstName }
        set { user.firstName = newValue }
    }
    /// Client app defined last name for the user. (Default: nil)
    @objc public var lastName: String? {
        get { user.lastName }
        set { user.lastName = newValue }
    }
    /// Client app defined country for the user. (Default: nil)
    @objc public var country: String? {
        get { user.country }
        set { user.country = newValue }
    }
    /// Client app defined ipAddress for the user. (Default: nil)
    @objc public var ipAddress: String? {
        get { user.ipAddress }
        set { user.ipAddress = newValue }
    }
    /// Client app defined email address for the user. (Default: nil)
    @objc public var email: String? {
        get { user.email }
        set { user.email = newValue }
    }
    /// Client app defined avatar for the user. (Default: nil)
    @objc public var avatar: String? {
        get { user.avatar }
        set { user.avatar = newValue }
    }
    /// Client app defined dictionary for the user. The client app may declare top level dictionary items as private. See `privateAttributes` for details.
    @objc public var custom: [String: ObjcLDValue] {
        get { user.custom.mapValues { ObjcLDValue(wrappedValue: $0) } }
        set { user.custom = newValue.mapValues { $0.wrappedValue } }
    }
    /// Client app defined isAnonymous for the user. If the client app does not define isAnonymous, the SDK will use the `key` to set this attribute. isAnonymous cannot be made private. (Default: YES)
    @objc public var isAnonymous: Bool {
        get { user.isAnonymous }
        set { user.isAnonymous = newValue }
    }

    /**
     Client app defined privateAttributes for the user.

     The SDK will not include private attribute values in analytics events, but private attribute names will be sent.

     This attribute is ignored if `ObjcLDConfig.allUserAttributesPrivate` is YES. Combined with `ObjcLDConfig.privateUserAttributes`. The SDK considers attributes appearing in either list as private. Client apps may define most built-in attributes and all top level `custom` dictionary keys here. (Default: `[]`])

     See Also: `ObjcLDConfig.allUserAttributesPrivate` and `ObjcLDConfig.privateUserAttributes`.

     */
    @objc public var privateAttributes: [String] {
        get { user.privateAttributes.map { $0.name } }
        set { user.privateAttributes = newValue.map { UserAttribute.forName($0) } }
    }

    /**
     Initializer to create a LDUser. Client configurable attributes are set to their default value. The SDK will automatically set `key`, `device`, `operatingSystem`, and `isAnonymous` attributes. The SDK embeds `device` and `operatingSystem` into the `custom` dictionary for transmission to LaunchDarkly.
     */
    @objc override public init() {
        user = LDUser()
    }

    /**
     Initializer to create a LDUser with a specific key. Other client configurable attributes are set to their default value. The SDK will automatically set `key`, `device`, `operatingSystem`, and `isAnonymous` attributes. The SDK embeds `device` and `operatingSystem` into the `custom` dictionary for transmission to LaunchDarkly.

     - parameter key: String that uniquely identifies the user. If the client app does not define a key, the SDK will assign an identifier associated with the anonymous user.
     */
    @objc public init(key: String) {
        user = LDUser(key: key)
    }

    // Initializer to wrap the Swift LDUser into ObjcLDUser for use in Objective-C apps.
    init(_ user: LDUser) {
        self.user = user
    }

    /// Compares users by comparing their user keys only, to allow the client app to collect user information over time
    @objc public func isEqual(object: Any) -> Bool {
        guard let otherUser = object as? ObjcLDUser
        else { return false }
        return user == otherUser.user
    }
}
