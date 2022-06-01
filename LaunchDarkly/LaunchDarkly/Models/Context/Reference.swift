import Foundation

enum ReferenceError: Codable, Equatable, Error {
    case empty
    case doubleSlash
    case invalidEscapeSequence

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        switch try container.decode(String.self) {
        case "empy":
            self = .empty
        case "doubleSlash":
            self = .doubleSlash
        default:
            self = .invalidEscapeSequence
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
}

extension ReferenceError: CustomStringConvertible {
    var description: String {
        switch self {
        case .empty: return "empty"
        case .doubleSlash: return "doubleSlash"
        case .invalidEscapeSequence: return "invalidEscapeSequence"
        }
    }
}

public struct Reference: Codable, Equatable, Hashable {
    private var error: ReferenceError?
    private var rawPath: String
    private var components: [Component] = []

    static func unescapePath(_ part: String) -> Result<String, ReferenceError> {
        if !part.contains("~") {
            return Result.success(part)
        }

        var output = ""
        var index = part.startIndex

        while index < part.endIndex {
            if part[index] != "~" {
                output.append(part[index])
                index = part.index(after: index)
                continue
            }

            index = part.index(after: index)
            if index == part.endIndex {
                return Result.failure(.invalidEscapeSequence)
            }

            switch part[index] {
            case "0":
                output.append("~")
            case "1":
                output.append("/")
            default:
                return Result.failure(.invalidEscapeSequence)
            }

            index = part.index(after: index)
        }

        return Result.success(output)
    }

    public init(_ value: String) {
        rawPath = value

        if value.isEmpty || value == "/" {
            error = .empty
            return
        }

        if value.prefix(1) != "/" {
            components = [Component(name: value, value: nil)]
            return
        }

        var referenceComponents: [Component] = []
        let parts = value.components(separatedBy: "/")
        for (index, part) in parts.enumerated() {
            if index == 0 {
                // We can ignore the first match since we know we had a leading slash.
                continue
            }

            // We must have had a double slash
            if part.isEmpty {
                error = .doubleSlash
                return
            }

            let result = Reference.unescapePath(part)
            switch result {
            case .success(let unescapedPath):
                referenceComponents.append(Component(name: unescapedPath, value: Int(part)))
            case .failure(let err):
                error = err
                return
            }
        }

        components = referenceComponents
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let reference = try container.decode(String.self)
        self = Reference(reference)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawPath)
    }

    public func isValid() -> Bool {
        return error == nil
    }

    internal func getError() -> ReferenceError? {
        return error
    }

    public func depth() -> Int {
        return components.count
    }

    internal func raw() -> String {
        return rawPath
    }

    public func component(_ index: Int) -> (String, Int?)? {
        if index >= self.depth() {
            return nil
        }

        let component = self.components[index]
        return (component.name, component.value)
    }
}

private struct Component: Codable, Equatable, Hashable {
    fileprivate let name: String
    fileprivate let value: Int?

    init(name: String, value: Int?) {
        self.name = name
        self.value = value
    }
}
