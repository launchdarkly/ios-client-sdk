import Foundation

public class UserAttribute: Equatable, Hashable {

    public struct BuiltIn {
        public static let key = UserAttribute("key") { $0.key }
        public static let secondaryKey = UserAttribute("secondary") { $0.secondary }
        // swiftlint:disable:next identifier_name
        public static let ip = UserAttribute("ip") { $0.ipAddress }
        public static let email = UserAttribute("email") { $0.email }
        public static let name = UserAttribute("name") { $0.name }
        public static let avatar = UserAttribute("avatar") { $0.avatar }
        public static let firstName = UserAttribute("firstName") { $0.firstName }
        public static let lastName = UserAttribute("lastName") { $0.lastName }
        public static let country = UserAttribute("country") { $0.country }
        public static let anonymous = UserAttribute("anonymous") { $0.isAnonymous }

        static let allBuiltIns = [key, secondaryKey, ip, email, name, avatar, firstName, lastName, country, anonymous]
    }

    static var builtInMap = { return BuiltIn.allBuiltIns.reduce(into: [:]) { $0[$1.name] = $1 } }()

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
