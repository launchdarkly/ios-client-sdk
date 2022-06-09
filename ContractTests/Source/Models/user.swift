import Foundation
import LaunchDarkly

extension LDUser: Decodable {

    /// String keys associated with LDUser properties.
    public enum CodingKeys: String, CodingKey {
        /// Key names match the corresponding LDUser property
        case key, name, firstName, lastName, country, ipAddress = "ip", email, avatar, custom, isAnonymous = "anonymous", privateAttributes = "privateAttributeNames", secondary
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()

        key = try values.decodeIfPresent(String.self, forKey: .key) ?? ""
        name = try values.decodeIfPresent(String.self, forKey: .name)
        firstName = try values.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try values.decodeIfPresent(String.self, forKey: .lastName)
        country = try values.decodeIfPresent(String.self, forKey: .country)
        ipAddress = try values.decodeIfPresent(String.self, forKey: .ipAddress)
        email = try values.decodeIfPresent(String.self, forKey: .email)
        avatar = try values.decodeIfPresent(String.self, forKey: .avatar)
        custom = try values.decodeIfPresent([String: LDValue].self, forKey: .custom) ?? [:]
        isAnonymous = try values.decodeIfPresent(Bool.self, forKey: .isAnonymous) ?? false
        _ = try values.decodeIfPresent([String].self, forKey: .privateAttributes)
        privateAttributes = (try values.decodeIfPresent([String].self, forKey: .privateAttributes) ?? []).map { UserAttribute.forName($0) }
        secondary = try values.decodeIfPresent(String.self, forKey: .secondary)
    }
}
