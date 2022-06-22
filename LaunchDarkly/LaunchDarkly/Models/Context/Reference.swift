import Foundation

public enum ReferenceError: Codable, Equatable, Error {
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
/// object properties (or, if they are numeric, the indices of JSON array elements). In this syntax, the
/// escape sequences "~0" and "~1" represent '~' and '/' respectively within a path component.
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
///   "groups": [ "p", "q" ],
///   "a/b": "ok"
/// }
/// ```
///
/// -- then
///
/// - Reference("name") or Reference("/name") would refer to the value "xyz"
/// - Reference("/address/street") would refer to the value "99 Main St."
/// - Reference("/groups/0") would refer to the value "p"
/// - Reference("a/b") or Reference("/a~1b") would refer to the value "ok"
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
    internal func raw() -> String {
        return rawPath
    }

    /// Retrieves a single path component from the attribute reference.
    ///
    /// For a simple attribute reference such as "name" with no leading slash,
    /// if index is zero, `component` returns the attribute name and None.
    ///
    /// For an attribute reference with a leading slash, if index is less than
    /// `Reference.depth()`, `component` returns the path component as a string
    /// for its first value. The second value is an `Int?` that is the integer
    /// value of that string if applicable, or None if the string does not
    /// represent an integer; this is used to implement a "find a value by
    /// index within a JSON array" behavior similar to JSON Pointer.
    ///
    /// If index is out of range, it returns None.
    ///
    /// ```
    /// Reference("a").component(0);      // returns ("a", nil)
    /// Reference("/a/b").component(1);   // returns ("b", nil)
    /// Reference("/a/3").component(1);   // returns ("3", 3)
    /// ```
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
