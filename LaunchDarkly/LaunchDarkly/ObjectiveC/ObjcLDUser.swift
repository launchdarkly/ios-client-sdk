//
//  LDUserObject.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 9/7/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

/**
 LDUser allows clients to collect information about users in order to refine the feature flag values sent to the SDK. For example, the client app may launch with the SDK defined anonymous user. As the user works with the client app, information may be collected as needed and sent to LaunchDarkly. The client app controls the information collected, which LaunchDarkly does not use except as the client directs to refine feature flags. Client apps should follow [Apple's Privacy Policy](apple.com/legal/privacy) when collecting user information.

 The SDK caches last known feature flags for use on app startup to provide continuity with the last app run. Provided the LDClient is online and can establish a connection with LaunchDarkly servers, cached information will only be used a very short time. Once the latest feature flags arrive at the SDK, the SDK no longer uses cached feature flags. The SDK retains feature flags on the last 5 client defined users. The SDK will retain feature flags until they are overwritten by a different user's feature flags, or until the user removes the app from the device.

 The SDK does not cache user information collected, except for the user key. The user key is used to identify the cached feature flags for that user. Client app developers should use caution not to use sensitive user information as the user-key.
 */
@objc (LDUser)
public final class ObjcLDUser: NSObject {
    var user: LDUser
    
    /**
     LDUser attributes that can be marked private.

     The SDK will not include private attribute values in analytics events, but private attribute names will be sent.

     See Also: `ObjcLDConfig.allUserAttributesPrivate`, `ObjcLDConfig.privateUserAttributes`, and `privateAttributes`.
     */
    @objc public class var privatizableAttributes: [String] {
        return LDUser.privatizableAttributes
    }
    ///LDUser name attribute used to make `name` private
    @objc public class var attributeName: String {
        return LDUser.CodingKeys.name.rawValue
    }
    ///LDUser firstName attribute used to make `firstName` private
    @objc public class var attributeFirstName: String {
        return LDUser.CodingKeys.firstName.rawValue
    }
    ///LDUser lastName attribute used to make `lastName` private
    @objc public class var attributeLastName: String {
        return LDUser.CodingKeys.lastName.rawValue
    }
    ///LDUser country attribute used to make `country` private
    @objc public class var attributeCountry: String {
        return LDUser.CodingKeys.country.rawValue
    }
    ///LDUser ipAddress attribute used to make `ipAddress` private
    @objc public class var attributeIPAddress: String {
        return LDUser.CodingKeys.ipAddress.rawValue
    }
    ///LDUser email attribute used to make `email` private
    @objc public class var attributeEmail: String {
        return LDUser.CodingKeys.email.rawValue
    }
    ///LDUser avatar attribute used to make `avatar` private
    @objc public class var attributeAvatar: String {
        return LDUser.CodingKeys.avatar.rawValue
    }
    ///LDUser custom attribute used to make `custom` private
    @objc public class var attributeCustom: String {
        return LDUser.CodingKeys.custom.rawValue
    }

    ///Client app defined string that uniquely identifies the user. If the client app does not define a key, the SDK will assign an identifier associated with the anonymous user. The key cannot be made private.
    @objc public var key: String {
        return user.key
    }
    ///Client app defined name for the user. (Default: nil)
    @objc public var name: String? {
        get {
            return user.name
        }
        set {
            user.name = newValue
        }
    }
    ///Client app defined first name for the user. (Default: nil)
    @objc public var firstName: String? {
        get {
            return user.firstName
        }
        set {
            user.firstName = newValue
        }
    }
    ///Client app defined last name for the user. (Default: nil)
    @objc public var lastName: String? {
        get {
            return user.lastName
        }
        set {
            user.lastName = newValue
        }
    }
    ///Client app defined country for the user. (Default: nil)
    @objc public var country: String? {
        get {
            return user.country
        }
        set {
            user.country = newValue
        }
    }
    ///Client app defined ipAddress for the user. (Default: nil)
    @objc public var ipAddress: String? {
        get {
            return user.ipAddress
        }
        set {
            user.ipAddress = newValue
        }
    }
    ///Client app defined email address for the user. (Default: nil)
    @objc public var email: String? {
        get {
            return user.email
        }
        set {
            user.email = newValue
        }
    }
    ///Client app defined avatar for the user. (Default: nil)
    @objc public var avatar: String? {
        get {
            return user.avatar
        }
        set {
            user.avatar = newValue
        }
    }
    ///Client app defined dictionary for the user. The client app may declare top level dictionary items as private. If the client app defines custom as private, the SDK considers the dictionary private except for device & operatingSystem (which cannot be made private). See `privateAttributes` for details. (Default: nil)
    @objc public var custom: [String: Any]? {
        get {
            return user.custom
        }
        set {
            user.custom = newValue
        }
    }
    ///Client app defined isAnonymous for the user. If the client app does not define isAnonymous, the SDK will use the `key` to set this attribute. isAnonymous cannot be made private. (Default: YES)
    @objc public var isAnonymous: Bool {
        get {
            return user.isAnonymous
        }
        set {
            user.isAnonymous = newValue
        }
    }
    ///Client app defined device for the user. The SDK will determine the device automatically, however the client app can override the value. The SDK will insert the device into the `custom` dictionary. The device cannot be made private. (Default: the system identified device)
    @objc public var device: String? {
        get {
            return user.device
        }
        set {
            user.device = newValue
        }
    }
    ///Client app defined operatingSystem for the user. The SDK will determine the operatingSystem automatically, however the client app can override the value. The SDK will insert the operatingSystem into the `custom` dictionary. The operatingSystem cannot be made private. (Default: the system identified operating system)
    @objc public var operatingSystem: String? {
        get {
            return user.operatingSystem
        }
        set {
            user.operatingSystem = newValue
        }
    }
    /**
     Client app defined privateAttributes for the user.

     The SDK will not include private attribute values in analytics events, but private attribute names will be sent.

     This attribute is ignored if `ObjcLDConfig.allUserAttributesPrivate` is YES. Combined with `ObjcLDConfig.privateUserAttributes`. The SDK considers attributes appearing in either list as private. Client apps may define attributes found in `privatizableAttributes` and top level `custom` dictionary keys here. (Default: nil)

     See Also: `ObjcLDConfig.allUserAttributesPrivate` and `ObjcLDConfig.privateUserAttributes`.

     */
    @objc public var privateAttributes: [String]? {
        get {
            return user.privateAttributes
        }
        set {
            user.privateAttributes = newValue
        }
    }

    /**
     Initializer to create a LDUser. Client configurable attributes are set to their default value. The SDK will automatically set `key`, `device`, `operatingSystem`, and `isAnonymous` attributes. The SDK embeds `device` and `operatingSystem` into the `custom` dictionary for transmission to LaunchDarkly.
     */
    @objc public override init() {
        user = LDUser()
    }

    /**
     Initializer to create a LDUser with a specific key. Other client configurable attributes are set to their default value. The SDK will automatically set `key`, `device`, `operatingSystem`, and `isAnonymous` attributes. The SDK embeds `device` and `operatingSystem` into the `custom` dictionary for transmission to LaunchDarkly.

     - parameter key: String that uniquely identifies the user. If the client app does not define a key, the SDK will assign an identifier associated with the anonymous user.
     */
    @objc public init(key: String) {
        user = LDUser(key: key)
    }

    //Initializer to wrap the Swift LDUser into ObjcLDUser for use in Objective-C apps.
    init(_ user: LDUser) {
        self.user = user
    }

    /**
     Failable Initializer that takes any object and attempts to create a LDUser from the object. If the object is a NSDictionary, constructs the LDUser via -[LDUser initWithUserDictionary:]

     - parameter object: Any object. The initializer will attempt to convert the object into a NSDictionary and construct the LDUser
     */
    @objc public init?(object: Any?) {
        guard let userDictionary = object as? [String: Any]
        else {
            return nil
        }
        self.user = LDUser(userDictionary: userDictionary)
    }

    /**
     Initializer that takes a NSDictionary and creates a LDUser from the contents. Uses any keys present to define corresponding attribute values. Initializes attributes not present in the dictionary to their default value. The initializer attempts to set `device` and `operatingSystem` from corresponding values embedded in `custom`. The initializer attempts to set feature flags from values set in `config`.

     - parameter userDictionary: NSDictionary with LDUser attribute keys and values.
     */
    @objc public init(userDictionary: [String: Any]) {
        self.user = LDUser(userDictionary: userDictionary)
    }

    ///Compares users by comparing their user keys only, to allow the client app to collect user information over time
    @objc public func isEqual(object: Any) -> Bool {
        guard let otherUser = object as? ObjcLDUser
        else {
            return false
        }
        return user == otherUser.user
    }
}
