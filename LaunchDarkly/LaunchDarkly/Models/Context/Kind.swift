import Foundation

public enum Kind: Codable, Equatable, Hashable {
    case user
    case multi
    case custom(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        switch try container.decode(String.self) {
        case "user":
            self = .user
        case "multi":
            self = .multi
        case let custom:
            self = .custom(custom)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }

    internal func isMulti() -> Bool {
        self == .multi || self == .custom("multi")
    }

    internal func isUser() -> Bool {
        self == .user || self == .custom("user") || self == .custom("")
    }

    private static func isValid(_ description: String) -> Bool {
        description.onlyContainsCharset(Util.validKindCharacterSet)
    }
}

extension Kind: Comparable {
    public static func < (lhs: Kind, rhs: Kind) -> Bool {
        lhs.description < rhs.description
    }

    public static func == (lhs: Kind, rhs: Kind) -> Bool {
        lhs.description == rhs.description
    }
}

extension Kind: LosslessStringConvertible {
    public init?(_ description: String) {
        switch description {
        case "kind":
            return nil
        case  "multi":
            self = .multi
        case  "", "user":
            self = .user
        default:
            if !Kind.isValid(description) {
                return nil
            }

            self = .custom(description)
        }
    }
}

extension Kind: CustomStringConvertible {
    public var description: String {
        switch self {
        case .user:
            return "user"
        case .multi:
            return "multi"
        case let .custom(val):
            return val
        }
    }
}
