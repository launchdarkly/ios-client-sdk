import Foundation

/**
 Represents a built-in or custom attribute name supported by `LDUser`.

 This abstraction helps to distinguish attribute names from other `String` values.

 For a more complete description of user attributes and how they can be referenced in feature flag rules, see the
 reference guides [Setting user attributes](https://docs.launchdarkly.com/home/users/attributes) and
 [Targeting users](https://docs.launchdarkly.com/home/flags/targeting-users).
 */
public class UserAttribute: Equatable, Hashable {

    /**
     Instances for built in attributes.
     */
    public struct BuiltIn {
        /// Represents the user key attribute.
        public static let key = UserAttribute("key") { $0.key }
        /// Represents the secondary key attribute.
        public static let secondaryKey = UserAttribute("secondary") { $0.secondary }
        /// Represents the IP address attribute.
        public static let ip = UserAttribute("ip") { $0.ipAddress } // swiftlint:disable:this identifier_name
        /// Represents the email address attribute.
        public static let email = UserAttribute("email") { $0.email }
        /// Represents the full name attribute.
        public static let name = UserAttribute("name") { $0.name }
        /// Represents the avatar attribute.
        public static let avatar = UserAttribute("avatar") { $0.avatar }
        /// Represents the first name attribute.
        public static let firstName = UserAttribute("firstName") { $0.firstName }
        /// Represents the last name attribute.
        public static let lastName = UserAttribute("lastName") { $0.lastName }
        /// Represents the country attribute.
        public static let country = UserAttribute("country") { $0.country }
        /// Represents the anonymous attribute.
        public static let anonymous = UserAttribute("anonymous") { $0.isAnonymous }

        static let allBuiltIns = [key, secondaryKey, ip, email, name, avatar, firstName, lastName, country, anonymous]
    }

    static var builtInMap = { return BuiltIn.allBuiltIns.reduce(into: [:]) { $0[$1.name] = $1 } }()

    /**
     Returns a `UserAttribute` instance for the specified atttribute name.

     For built-in attributes, the same instances are always reused and `isBuiltIn` will be `true`. For custom
     attributes, a new instance is created and `isBuiltIn` will be `false`.

     - parameter name: the attribute name
     - returns: a `UserAttribute`
     */
    public static func forName(_ name: String) -> UserAttribute {
        if let builtIn = builtInMap[name] {
            return builtIn
        }
        return UserAttribute(name)
    }

    let name: String
    let builtInGetter: ((LDUser) -> Any?)?

    init(_ name: String, builtInGetter: ((LDUser) -> Any?)? = nil) {
        self.name = name
        self.builtInGetter = builtInGetter
    }

    /// Whether the attribute is built-in rather than custom.
    public var isBuiltIn: Bool { builtInGetter != nil }

    public static func == (lhs: UserAttribute, rhs: UserAttribute) -> Bool {
        if lhs.isBuiltIn || rhs.isBuiltIn {
            return lhs === rhs
        }
        return lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
