import Foundation

/// An enumeration describing the individual failure conditions which may occur when constructing a `Reference`.
public enum ReferenceError: Codable, Equatable, Error {
    /// empty means that you tried to create a `Reference` from an empty string, or a string that consisted only of a
    /// slash.
    ///
    /// For details of the attribute reference syntax, see `Reference`.
    case empty

    /// doubleSlash means that an attribute reference contained a double slash or trailing slash causing one path
    /// component to be empty, such as "/a//b" or "/a/b/".
    ///
    /// For details of the attribute reference syntax, see `Reference`.
    case doubleSlash

    /// invalidEscapeSequence means that an attribute reference contained contained a "~" character that was not
    /// followed by "0" or "1".
    ///
    /// For details of the attribute reference syntax, see `Reference`.
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
    public var description: String {
        switch self {
        case .empty: return "empty"
        case .doubleSlash: return "doubleSlash"
        case .invalidEscapeSequence: return "invalidEscapeSequence"
        }
    }
}

/// Represents an attribute name or path expression identifying a value within a Context.
///
/// This can be used to retrieve a value with `LDContext.getValue(_:)`, or to identify an attribute or
/// nested value that should be considered private with
/// `LDContextBuilder.addPrivateAttribute(_:)` (the SDK configuration can also have a list of
/// private attribute references).
///
/// This is represented as a separate type, rather than just a string, so that validation and parsing can
/// be done ahead of time if an attribute reference will be used repeatedly later (such as in flag
/// evaluations).
///
/// If the string starts with '/', then this is treated as a slash-delimited path reference where the
/// first component is the name of an attribute, and subsequent components are the names of nested JSON
/// object properties. In this syntax, the escape sequences "~0" and "~1" represent '~' and '/'
/// respectively within a path component.
///
/// If the string does not start with '/', then it is treated as the literal name of an attribute.
///
/// For instance, if the JSON representation of a context is as follows--
///
/// ```json
/// {
///   "kind": "user",
///   "key": "123",
///   "name": "xyz",
///   "address": {
///     "street": "99 Main St.",
///     "city": "Westview"
///   },
///   "a/b": "ok"
/// }
/// ```
///
/// -- then
///
/// - Reference("name") or Reference("/name") would refer to the value "xyz"
/// - Reference("/address/street") would refer to the value "99 Main St."
/// - Reference("a/b") or Reference("/a~1b") would refer to the value "ok"
public struct Reference: Codable {
    private var error: ReferenceError?
    private var rawPath: String
    private var components: [String] = []

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

    /// Construct a new Reference.
    ///
    /// This constructor always returns a Reference that preserves the original string, even if
    /// validation fails, so that serializing the Reference to JSON will produce the original
    /// string.
    public init(_ value: String) {
        rawPath = value

        if value.isEmpty || value == "/" {
            error = .empty
            return
        }

        if value.prefix(1) != "/" {
            components = [value]
            return
        }

        var referenceComponents: [String] = []
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
                referenceComponents.append(unescapedPath)
            case .failure(let err):
                error = err
                return
            }
        }

        components = referenceComponents
    }

    private init() {
        rawPath = ""
        components = []
        error = nil
    }

    public init(literal value: String) {
        if value.isEmpty {
            self.init(value)
            return
        }

        self.init()
        let str = value.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")
        self.rawPath = str
        self.components = [value]
        self.error = nil
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

    /// Returns whether or not the reference provided is valid.
    public func isValid() -> Bool {
        return error == nil
    }

    /// If the reference is invalid, this method will return an error description; otherwise, it
    /// will return an empty string.
    public func getError() -> ReferenceError? {
        return error
    }

    internal func depth() -> Int {
        return components.count
    }

    /// Returns raw string that was passed into constructor.
    public func raw() -> String {
        return rawPath
    }

    internal func component(_ index: Int) -> String? {
        if index >= self.depth() {
            return nil
        }

        return self.components[index]
    }
}

extension Reference: Equatable {
    public static func == (lhs: Reference, rhs: Reference) -> Bool {
        return lhs.error == rhs.error && lhs.components == rhs.components
    }
}

extension Reference: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(error)
        hasher.combine(components)
    }
}
