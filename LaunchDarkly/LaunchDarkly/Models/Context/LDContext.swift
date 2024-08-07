import Foundation

/// Enumeration representing various modes of failures when constructing an `LDContext`.
public enum ContextBuilderError: Error {
    /// The provided kind either contains invalid characters, or is the disallowed kind "kind".
    case invalidKind
    /// The `LDMultiContextBuilder` must be used when attempting to build a multi-context.
    case requiresMultiBuilder
    /// The JSON representations for the context was missing the "key" property.
    case emptyKey
    /// Attempted to build a multi-context without providing any contexts.
    case emptyMultiKind
    /// A multi-context cannot contain another multi-context.
    case nestedMultiKind
    /// Attempted to build a multi-context containing 2 or more contexts with the same kind.
    case duplicateKinds
}

/// LDContext is a collection of attributes that can be referenced in flag evaluations and analytics
/// events.
///
/// To create an LDContext of a single kind, such as a user, you may use `LDContextBuilder`.
///
/// To create an LDContext with multiple kinds, use `LDMultiContextBuilder`.
public struct LDContext: Encodable, Equatable {
    static let storedIdKey: String = "ldDeviceIdentifier"

    internal var kind: Kind = .user
    internal var contexts: [LDContext] = []

    // Meta attributes
    fileprivate var name: String?
    fileprivate var anonymous: Bool = false
    internal var privateAttributes: Set<Reference> = []

    fileprivate var key: String?
    fileprivate var canonicalizedKey: String
    internal var attributes: [String: LDValue] = [:]

    // Internal property used to control encoding.
    //
    // Normally we would control this encoding mechanism through the use of userKeys.
    // However, the anonymous redaction mechanism has to vary on a per event basis,
    // and so we cannot affect the entire JSON encoder in this way.
    internal var redactAnonymousAttributes: Bool = false

    fileprivate init(canonicalizedKey: String) {
        self.canonicalizedKey = canonicalizedKey
    }

    internal init(copyFrom: LDContext) {
        kind = copyFrom.kind
        contexts = copyFrom.contexts.map { c in LDContext(copyFrom: c) }
        name = copyFrom.name
        anonymous = copyFrom.anonymous
        privateAttributes = copyFrom.privateAttributes
        key = copyFrom.key
        canonicalizedKey = copyFrom.canonicalizedKey
        attributes = copyFrom.attributes
    }

    init() {
        self.init(canonicalizedKey: LDContext.defaultKey(kind: Kind.user))
        self.key = self.canonicalizedKey
    }

    struct Meta: Codable {
        var privateAttributes: Set<Reference>?
        var redactedAttributes: [String]?

        enum CodingKeys: CodingKey {
            case privateAttributes, redactedAttributes
        }

        var isEmpty: Bool {
            (privateAttributes?.isEmpty ?? true)
            && (redactedAttributes?.isEmpty ?? true)
        }

        init(privateAttributes: Set<Reference>?, redactedAttributes: [String]?) {
            self.privateAttributes = privateAttributes
            self.redactedAttributes = redactedAttributes
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let privateAttributes = try container.decodeIfPresent(Set<Reference>.self, forKey: .privateAttributes)

            self.privateAttributes = privateAttributes
            self.redactedAttributes = []
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            let includePrivateAttributes = encoder.userInfo[UserInfoKeys.includePrivateAttributes] as? Bool ?? false

            if let privateAttributes = privateAttributes, !privateAttributes.isEmpty, includePrivateAttributes {
                let sorted = privateAttributes.sorted { $0.raw() < $1.raw() }
                try container.encodeIfPresent(sorted, forKey: .privateAttributes)
            }

            if let redactedAttributes = redactedAttributes, !redactedAttributes.isEmpty {
                try container.encodeIfPresent(redactedAttributes, forKey: .redactedAttributes)
            }
        }
    }

    class PrivateAttributeLookupNode {
        var reference: Reference?
        var children = SharedDictionary<String, PrivateAttributeLookupNode>()

        init() {
            self.reference = nil
        }

        init(reference: Reference) {
            self.reference = reference
        }
    }

    static private func encodeSingleContext(container: inout KeyedEncodingContainer<DynamicCodingKeys>, context: LDContext, discardKind: Bool, redactAttributes: Bool, allAttributesPrivate: Bool, globalPrivateAttributes: SharedDictionary<String, PrivateAttributeLookupNode>, redactAnonymousAttributes: Bool) throws {
        if !discardKind {
            try container.encodeIfPresent(context.kind.description, forKey: DynamicCodingKeys(string: "kind"))
        }

        try container.encodeIfPresent(context.key, forKey: DynamicCodingKeys(string: "key"))

        let optionalAttributeNames = context.getOptionalAttributeNames()
        var redactedAttributes: [String] = []
        redactedAttributes.reserveCapacity(20)

        let redactAll = allAttributesPrivate || (context.anonymous && redactAnonymousAttributes)

        for key in optionalAttributeNames {
            let reference = Reference(key)
            if let value = context.getValue(reference) {
                if redactAll {
                    redactedAttributes.append(reference.raw())
                    continue
                }

                var path: [String] = []
                path.reserveCapacity(10)
                try LDContext.writeFilterAttribute(context: context, container: &container, parentPath: path, key: key, value: value, redactedAttributes: &redactedAttributes, redactAttributes: redactAttributes, globalPrivateAttributes: globalPrivateAttributes)
            }
        }

        let meta = Meta(privateAttributes: context.privateAttributes, redactedAttributes: redactedAttributes)

        if !meta.isEmpty {
            try container.encodeIfPresent(meta, forKey: DynamicCodingKeys(string: "_meta"))
        }

        if context.anonymous {
            try container.encodeIfPresent(context.anonymous, forKey: DynamicCodingKeys(string: "anonymous"))
        }
    }

    static private func writeFilterAttribute(context: LDContext, container: inout KeyedEncodingContainer<DynamicCodingKeys>, parentPath: [String], key: String, value: LDValue, redactedAttributes: inout [String], redactAttributes: Bool, globalPrivateAttributes: SharedDictionary<String, PrivateAttributeLookupNode>) throws {
        var path = parentPath
        path.append(key.description)

        let (isRedacted, nestedPropertiesAreRedacted) = !redactAttributes ? (false, false) : LDContext.maybeRedact(context: context, parentPath: path, value: value, redactedAttributes: &redactedAttributes, globalPrivateAttributes: globalPrivateAttributes)

        switch value {
        case .object where isRedacted:
            break
        case .object(let objectMap):
            if !nestedPropertiesAreRedacted {
                try container.encode(value, forKey: DynamicCodingKeys(string: key))
                return
            }

            // TODO(mmk): This might be a problem. We might write a sub container even if all the attributes are completely filtered out.
            var subContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: DynamicCodingKeys(string: key))
            for (key, value) in objectMap {
                try writeFilterAttribute(context: context, container: &subContainer, parentPath: path, key: key, value: value, redactedAttributes: &redactedAttributes, redactAttributes: redactAttributes, globalPrivateAttributes: globalPrivateAttributes)
            }
        case _ where !isRedacted:
            try container.encode(value, forKey: DynamicCodingKeys(string: key))
        default:
            break
        }
    }

    static private func maybeRedact(context: LDContext, parentPath: [String], value: LDValue, redactedAttributes: inout [String], globalPrivateAttributes: SharedDictionary<String, PrivateAttributeLookupNode>) -> (Bool, Bool) {
        var (reactedAttrReference, nestedPropertiesAreRedacted) = LDContext.checkGlobalPrivateAttributeReferences(context: context, parentPath: parentPath, globalPrivateAttributes: globalPrivateAttributes)

        if let reactedAttrReference = reactedAttrReference {
            redactedAttributes.append(reactedAttrReference.raw())
            return (true, false)
        }

        var shouldCheckNestedProperties: Bool = false
        if case .object = value {
            shouldCheckNestedProperties = true
        }

        for privateAttribute in context.privateAttributes {
            let depth = privateAttribute.depth()

            if depth < parentPath.count {
                continue
            }

            if !shouldCheckNestedProperties && depth < parentPath.count {
                continue
            }

            var hasMatch = true
            for (index, parentPart) in parentPath.enumerated() {
                if let name = privateAttribute.component(index) {
                    if name != parentPart {
                        hasMatch = false
                        break
                    }

                    continue
                } else {
                    break
                }
            }

            if hasMatch {
                if depth == parentPath.count {
                    redactedAttributes.append(privateAttribute.raw())
                    return (true, false)
                }

                nestedPropertiesAreRedacted = true
            }
        }

        return (false, nestedPropertiesAreRedacted)
    }

    static internal func defaultKey(kind: Kind) -> String {
        // ldDeviceIdentifier is used for users to be compatible with
        // older SDKs
        let storedIdKey = kind.isUser() ? "ldDeviceIdentifier" : "ldGeneratedContextKey:\(kind)"
        if let storedId = UserDefaults.standard.string(forKey: storedIdKey) {
            return storedId
        }

        let key = UUID().uuidString
        UserDefaults.standard.set(key, forKey: storedIdKey)

        return key
    }

    internal struct UserInfoKeys {
        static let includePrivateAttributes = CodingUserInfoKey(rawValue: "LD_includePrivateAttributes")!
        static let redactAttributes = CodingUserInfoKey(rawValue: "LD_redactAttributes")!
        static let allAttributesPrivate = CodingUserInfoKey(rawValue: "LD_allAttributesPrivate")!
        static let globalPrivateAttributes = CodingUserInfoKey(rawValue: "LD_globalPrivateAttributes")!
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)

        let allAttributesPrivate = encoder.userInfo[UserInfoKeys.allAttributesPrivate] as? Bool ?? false
        let globalPrivateAttributes = encoder.userInfo[UserInfoKeys.globalPrivateAttributes] as? [Reference] ?? []
        let redactAttributes = encoder.userInfo[UserInfoKeys.redactAttributes] as? Bool ?? true

        let allPrivate = redactAttributes && allAttributesPrivate
        let globalPrivate = redactAttributes ? globalPrivateAttributes : []
        let globalDictionary = LDContext.makePrivateAttributeLookupData(references: globalPrivate)

        if isMulti() {
            try container.encodeIfPresent(kind.description, forKey: DynamicCodingKeys(string: "kind"))

            for context in contexts {
                var contextContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: DynamicCodingKeys(string: context.kind.description))
                try LDContext.encodeSingleContext(container: &contextContainer, context: context, discardKind: true, redactAttributes: redactAttributes, allAttributesPrivate: allPrivate, globalPrivateAttributes: globalDictionary, redactAnonymousAttributes: redactAnonymousAttributes)
            }
        } else {
            try LDContext.encodeSingleContext(container: &container, context: self, discardKind: false, redactAttributes: redactAttributes, allAttributesPrivate: allPrivate, globalPrivateAttributes: globalDictionary, redactAnonymousAttributes: redactAnonymousAttributes)
        }
    }

    class SharedDictionary<K: Hashable, V> {
        private var dict: [K: V] = Dictionary()
        var isEmpty: Bool {
            dict.isEmpty
        }

        func contains(_ key: K) -> Bool {
            dict.keys.contains(key)
        }

        subscript(key: K) -> V? {
            get { return dict[key] }
            set { dict[key] = newValue }
        }
    }

    static private func makePrivateAttributeLookupData(references: [Reference]) -> SharedDictionary<String, PrivateAttributeLookupNode> {
        let returnValue = SharedDictionary<String, PrivateAttributeLookupNode>()

        for reference in references {
            let parentMap = returnValue

            for index in 0...reference.depth() {
                if let name = reference.component(index) {
                    if !parentMap.contains(name) {
                        let nextNode = PrivateAttributeLookupNode()

                        if index == reference.depth() - 1 {
                            nextNode.reference = reference
                        }

                        parentMap[name] = nextNode
                    }
                }
            }
        }

        return returnValue
    }

    static private func checkGlobalPrivateAttributeReferences(context: LDContext, parentPath: [String], globalPrivateAttributes: SharedDictionary<String, PrivateAttributeLookupNode>) -> (Reference?, Bool) {
        var lookup = globalPrivateAttributes
        if lookup.isEmpty {
            return (nil, false)
        }

        for (index, path) in parentPath.enumerated() {
            if let nextNode = lookup[path] {
                if index == parentPath.count - 1 {
                    let name = (nextNode.reference, nextNode.reference == nil)
                    return name
                } else if !nextNode.children.isEmpty {
                    lookup = nextNode.children
                }
            } else {
                break
            }
        }

        return (nil, false)
    }

    /// FullyQualifiedKey returns a string that describes the entire Context based on Kind and Key values.
    ///
    /// This value is used whenever LaunchDarkly needs a string identifier based on all of the Kind and
    /// Key values in the context; the SDK may use this for caching previously seen contexts, for instance.
    public func fullyQualifiedKey() -> String {
        return canonicalizedKey
    }

    func fullyQualifiedHashedKey() -> String {
        if kind.isUser() {
            return Util.sha256base64(fullyQualifiedKey())
        }

        return Util.sha256base64(fullyQualifiedKey()) + "$"
    }

    internal func contextHash() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.userInfo[UserInfoKeys.redactAttributes] = false

        guard let json = try? encoder.encode(self)
        else { return fullyQualifiedHashedKey() }

        if let jsonStr = String(data: json, encoding: .utf8) {
            return Util.sha256base64(jsonStr)
        }
        return fullyQualifiedHashedKey()
    }

    /// - Returns: true if the `LDContext` is a multi-context; false otherwise.
    public func isMulti() -> Bool {
        return self.kind.isMulti()
    }

    //// - Returns: A hash mapping a context's kind to its key.
    public func contextKeys() -> [String: String] {
        guard isMulti() else {
            return [kind.description: key ?? ""]
        }

        let keys = Dictionary(contexts.map { ($0.kind.description, $0.key ?? "") }) { first, _ in first }
        return keys
    }

    /// Looks up the value of any attribute of the `LDContext`, or a value contained within an
    /// attribute, based on a `Reference`. This includes only attributes that are addressable in evaluations.
    ///
    /// This implements the same behavior that the SDK uses to resolve attribute references during a flag
    /// evaluation. In a context, the `Reference` can represent a simple attribute name-- either a
    /// built-in one like "name" or "key", or a custom attribute that was set by `LDContextBuilder.trySetValue(...)`--
    /// or, it can be a slash-delimited path using a JSON-Pointer-like syntax. See `Reference` for more details.
    ///
    /// For a multi-context, the only supported attribute name is "kind".
    ///
    /// If the value is found, the return value is the attribute value, using the type `LDValue` to
    /// represent a value of any JSON type.
    ///
    /// If there is no such attribute, or if the `Reference` is invalid, the return value is nil.
    public func getValue(_ reference: Reference) -> LDValue? {
        if !reference.isValid() {
            return nil
        }

        guard let component = reference.component(0) else {
            return nil
        }

        if isMulti() {
            if reference.depth() == 1 && component == "kind" {
                return .string(String(kind))
            }

            return nil
        }

        guard var attribute: LDValue = self.getTopLevelAddressableAttributeSingleKind(component) else {
            return nil
        }

        for depth in 1..<reference.depth() {
            guard let name = reference.component(depth) else {
                return nil
            }

            switch attribute {
            case .object(let map):
                if let attr = map[name] {
                    attribute = attr
                } else {
                    return nil
                }
            default:
                return nil
            }
        }

        return attribute
    }

    func getOptionalAttributeNames() -> [String] {
        if isMulti() {
            return []
        }

        var attrs = attributes.keys.map { $0.description }

        if name != nil {
            attrs.append("name")
        }

        return attrs
    }

    func getTopLevelAddressableAttributeSingleKind(_ name: String) -> LDValue? {
        switch name {
        case "kind":
            return .string(String(self.kind))
        case "key":
            return self.key.map { .string($0) }
        case "name":
            return self.name.map { .string($0) }
        case "anonymous":
            return .bool(self.anonymous)
        default:
            return self.attributes[name]
        }
    }
}

extension LDContext: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        switch try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(string: "kind")) {
        case .none:
            if container.contains(DynamicCodingKeys(string: "kind")) {
                throw DecodingError.valueNotFound(
                    String.self,
                    DecodingError.Context(
                        codingPath: [DynamicCodingKeys(string: "kind")],
                        debugDescription: "Kind cannot be null"
                    )
                )
            }

            let values = try decoder.container(keyedBy: UserCodingKeys.self)

            let key = try values.decode(String.self, forKey: .key)
            var contextBuilder = LDContextBuilder(key: key)
            contextBuilder.allowEmptyKey = true

            let custom = try values.decodeIfPresent([String: LDValue].self, forKey: .custom) ?? [:]
            custom.forEach { contextBuilder.trySetValue($0.key, $0.value) }

            if let name = try values.decodeIfPresent(String.self, forKey: .name) {
                contextBuilder.name(name)
            }
            if let firstName = try values.decodeIfPresent(String.self, forKey: .firstName) {
                contextBuilder.trySetValue("firstName", .string(firstName))
            }
            if let lastName = try values.decodeIfPresent(String.self, forKey: .lastName) {
                contextBuilder.trySetValue("lastName", .string(lastName))
            }
            if let country = try values.decodeIfPresent(String.self, forKey: .country) {
                contextBuilder.trySetValue("country", .string(country))
            }
            if let ip = try values.decodeIfPresent(String.self, forKey: .ip) {
                contextBuilder.trySetValue("ip", .string(ip))
            }
            if let email = try values.decodeIfPresent(String.self, forKey: .email) {
                contextBuilder.trySetValue("email", .string(email))
            }
            if let avatar = try values.decodeIfPresent(String.self, forKey: .avatar) {
                contextBuilder.trySetValue("avatar", .string(avatar))
            }

            let isAnonymous = try values.decodeIfPresent(Bool.self, forKey: .isAnonymous) ?? false
            contextBuilder.anonymous(isAnonymous)

            let privateAttributeNames = try values.decodeIfPresent([String].self, forKey: .privateAttributeNames) ?? []
            privateAttributeNames.forEach { contextBuilder.addPrivateAttribute(Reference($0)) }

            self = try contextBuilder.build().get()
        case .some("multi"):
            let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
            var multiContextBuilder = LDMultiContextBuilder()

            for key in container.allKeys {
                if key.stringValue == "kind" {
                    continue
                }

                let contextContainer = try container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: DynamicCodingKeys(string: key.stringValue))
                multiContextBuilder.addContext(try LDContext.decodeSingleContext(container: contextContainer, kind: key.stringValue))
            }

            self = try multiContextBuilder.build().get()
        case .some(""):
            throw DecodingError.valueNotFound(
                String.self,
                DecodingError.Context(
                    codingPath: [DynamicCodingKeys(string: "kind")],
                    debugDescription: "Kind cannot be empty"
                )
            )
        case .some(let kind):
            let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
            self = try LDContext.decodeSingleContext(container: container, kind: kind)
        }
    }

    static private func decodeSingleContext(container: KeyedDecodingContainer<DynamicCodingKeys>, kind: String) throws -> LDContext {
        let key = try container.decode(String.self, forKey: DynamicCodingKeys(string: "key"))

        var contextBuilder = LDContextBuilder(key: key)
        contextBuilder.kind(kind)

        for key in container.allKeys {
            switch key.stringValue {
            case "key":
                continue
            case "_meta":
                if let meta = try container.decodeIfPresent(LDContext.Meta.self, forKey: DynamicCodingKeys(string: "_meta")) {
                    if let privateAttributes = meta.privateAttributes {
                        privateAttributes.forEach { contextBuilder.addPrivateAttribute($0) }
                    }
                }

            default:
                if let value = try container.decodeIfPresent(LDValue.self, forKey: DynamicCodingKeys(string: key.stringValue)) {
                    contextBuilder.trySetValue(key.stringValue, value)
                }
            }
        }

        return try contextBuilder.build().get()
    }

    // This CodingKey implementation allows us to dynamically access fields in
    // any JSON payload without having to pre-define the possible keys.
    private struct DynamicCodingKeys: CodingKey {
        // Protocol required implementations
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }

        // Convenience method since we don't want to unwrap everywhere
        init(string: String) {
            self.stringValue = string
        }
    }

    enum UserCodingKeys: String, CodingKey {
        case key, name, firstName, lastName, country, ip, email, avatar, custom, isAnonymous = "anonymous", privateAttributeNames
    }
}

extension LDContext: TypeIdentifying {}

enum LDContextBuilderKey {
    case generateKey
    case key(String)
}

/// Contains methods for building a single kind `LDContext` with a specified key, defaulting to kind
/// "user".
///
/// You may use these methods to set additional attributes and/or change the kind before calling
/// `LDContextBuilder.build()`. If you do not change any values, the defaults for the `LDContext` are that its
/// kind is "user", its key is set to whatever value you passed to `LDContextBuilder.init(key:)`, its anonymous attribute
/// is false, and it has no values for any other attributes.
///
/// To define a multi-context, see `LDMultiContextBuilder`.
public struct LDContextBuilder {
    private var kind: String = Kind.user.description

    // Meta attributes
    private var name: String?
    private var anonymous: Bool = false
    private var privateAttributes: Set<Reference> = []

    private var key: LDContextBuilderKey
    private var attributes: [String: LDValue] = [:]

    // Contexts that were deserialized from implicit user formats
    // are allowed to have empty string keys. Otherwise, key is
    // never allowed to be empty.
    fileprivate var allowEmptyKey: Bool = false

    /// Create a new LDContextBuilder.
    ///
    /// By default, this builder will create an anonymous LDContext
    /// with a generated key. This key will be cached locally and
    /// reused for the same context kind.
    ///
    /// If `LDContextBuilder.key` is called, a key will no longer be
    /// generated and the anonymous status will match the value
    /// provided by `LDContextBuilder.anonymous` or false by default.
    public init() {
        self.key = .generateKey
    }

    /// Create a new LDContextBuilder with the provided `key`.
    public init(key: String) {
        self.key = .key(key)
    }

    /// Sets the LDContext's kind attribute.
    ///
    /// Every LDContext has a kind. Setting it to an empty string is equivalent to the default kind
    /// of "user". This value is case-sensitive. Validation rules are as follows:
    ///
    /// - It may only contain letters, numbers, and the characters ".", "_", and "-".
    /// - It cannot equal the literal string "kind".
    /// - It cannot equal "multi".
    ///
    /// If the value is invalid, you will receive an error when `LDContextBuilder.build()` is called.
    public mutating func kind(_ kind: String) {
        self.kind = kind
    }

    /// Sets the LDContext's key attribute.
    ///
    /// Every LDContext has a key, which is always a string. There are no restrictions on its value.
    /// It may be an empty string.
    ///
    /// The key attribute can be referenced by flag rules, flag target lists, and segments.
    public mutating func key(_ key: String) {
        self.key = .key(key)
    }

    /// Sets the LDContext's name attribute.
    ///
    /// This attribute is optional. It has the following special rules:
    ///
    /// - Unlike most other attributes, it is always a string if it is specified.
    /// - The LaunchDarkly dashboard treats this attribute as the preferred display name for users.
    public mutating func name(_ name: String) {
        self.name = name
    }

    /// Sets the value of any attribute for the Context except for private attributes.
    ///
    /// This method uses the `LDValue` type to represent a value of any JSON type: null,
    /// boolean, number, string, array, or object. For all attribute names that do not have special
    /// meaning to LaunchDarkly, you may use any of those types. Values of different JSON types are
    /// always treated as different values: for instance, null, false, and the empty string "" are
    /// not the same, and the number 1 is not the same as the string "1".
    ///
    /// The following attribute names have special restrictions on their value types, and any value
    /// of an unsupported type will be ignored (leaving the attribute unchanged):
    ///
    /// - "kind", "key": Must be a string. See `LDContextBuilder.kind(_:)` and `LDContextBuilder.key(_:)`.
    ///
    /// - "name": Must be a string or null. See `LDContextBuilder.name(_:)`.
    ///
    /// - "anonymous": Must be a boolean. See `LDContextBuilder.anonymous(_:)`.
    ///
    /// Values that are JSON arrays or objects have special behavior when referenced in
    /// flag/segment rules.
    ///
    /// A value of `LDValue.null` is equivalent to removing any current non-default value
    /// of the attribute. Null is not a valid attribute value in the LaunchDarkly model; any
    /// expressions in feature flags that reference an attribute with a null value will behave as
    /// if the attribute did not exist.
    ///
    /// This method returns true for success, or false if the parameters
    /// violated one of the restrictions described above (for instance,
    /// attempting to set "key" to a value that was not a string).
    @discardableResult
    public mutating func trySetValue(_ name: String, _ value: LDValue) -> Bool {
        switch (name, value) {
        case ("", _):
            return false
        case ("kind", .string(let val)):
            self.kind(val)
        case ("kind", _):
            return false
        case ("key", .string(let val)):
            self.key(val)
        case ("key", _):
            return false
        case ("name", .string(let val)):
            self.name(val)
        case ("name", _):
            return false
        case ("anonymous", .bool(let val)):
            self.anonymous(val)
        case ("anonymous", _):
            return false
        case (_, .null):
            self.attributes.removeValue(forKey: name)
        case (_, _):
            self.attributes.updateValue(value, forKey: name)
        }

        return true
    }

    /// Sets whether the LDContext is only intended for flag evaluations and should not be indexed by
    /// LaunchDarkly.
    ///
    /// The default value is false. False means that this LDContext represents an entity such as a
    /// user that you want to be able to see on the LaunchDarkly dashboard.
    ///
    /// Setting anonymous to true excludes this LDContext from the database that is used by the
    /// dashboard. It does not exclude it from analytics event data, so it is not the same as
    /// making attributes private; all non-private attributes will still be included in events and
    /// data export.
    ///
    /// This value is also addressable in evaluations as the attribute name "anonymous". It is
    /// always treated as a boolean true or false in evaluations.
    public mutating func anonymous(_ anonymous: Bool) {
        self.anonymous = anonymous
    }

    /// Provide a reference to designate any number of LDContext attributes as private: that is,
    /// their values will not be sent to LaunchDarkly.
    ///
    /// This action only affects analytics events that involve this particular `LDContext`. To mark some (or all)
    /// Context attributes as private for all contexts, use the overall event configuration for the SDK.
    ///
    /// In this example, firstName is marked as private, but lastName is not:
    ///
    /// ```swift
    /// var builder = LDContextBuilder(key: "my-key")
    /// builder.kind("org")
    /// builder.trySetValue("firstName", "Pierre")
    /// builder.trySetValue("lastName", "Menard")
    /// builder.addPrivate(Reference("firstName"))
    ///
    /// let context = try builder.build().get()
    /// ```
    ///
    /// The attributes "kind", "key", and "anonymous" cannot be made private.
    ///
    /// This is a metadata property, rather than an attribute that can be addressed in evaluations: that is,
    /// a rule clause that references the attribute name "private" will not use this value, but instead will
    /// use whatever value (if any) you have set for that name with `trySetValue(...)`.
    ///
    /// # Designating an entire attribute as private
    ///
    /// If the parameter is an attribute name such as "email" that does not start with a '/' character, the
    /// entire attribute is private.
    ///
    /// # Designating a property within a JSON object as private
    ///
    /// If the parameter starts with a '/' character, it is interpreted as a slash-delimited path to a
    /// property within a JSON object. The first path component is an attribute name, and each following
    /// component is a property name.
    ///
    /// For instance, suppose that the attribute "address" had the following JSON object value:
    /// {"street": {"line1": "abc", "line2": "def"}, "city": "ghi"}
    ///
    ///   - Calling either addPrivateAttribute(Reference("address")) or addPrivateAddress(Reference("/address")) would
    ///     cause the entire "address" attribute to be private.
    ///   - Calling addPrivateAttribute("/address/street") would cause the "street" property to be private, so that
    ///     only {"city": "ghi"} is included in analytics.
    ///   - Calling addPrivateAttribute("/address/street/line2") would cause only "line2" within "street" to be private,
    ///     so that {"street": {"line1": "abc"}, "city": "ghi"} is included in analytics.
    ///
    /// This syntax deliberately resembles JSON Pointer, but other JSON Pointer features such as array
    /// indexing are not supported.
    ///
    /// If an attribute's actual name starts with a '/' character, you must use the same escaping syntax as
    /// JSON Pointer: replace "~" with "~0", and "/" with "~1".
    public mutating func addPrivateAttribute(_ reference: Reference) {
        self.privateAttributes.insert(reference)
    }

    /// Remove any reference provided through `addPrivateAttribute(_:)`. If the reference was
    /// added more than once, this method will remove all instances of it.
    public mutating func removePrivateAttribute(_ reference: Reference) {
        self.privateAttributes.remove(reference)
    }

    /// Creates a LDContext from the current LDContextBuilder properties.
    ///
    /// The LDContext is immutable and will not be affected by any subsequent actions on the
    /// LDContextBuilder.
    ///
    /// It is possible to specify invalid attributes for a LDContextBuilder, such as an empty key.
    /// In those situations, this method returns a Result.failure
    public func build() -> Result<LDContext, ContextBuilderError> {
        guard let kind = Kind(self.kind) else {
            return Result.failure(.invalidKind)
        }

        if kind.isMulti() {
            return Result.failure(.requiresMultiBuilder)
        }

        var contextKey = ""
        var anonymous = self.anonymous
        switch self.key {
        case let .key(key):
            contextKey = key
        case .generateKey:
            contextKey = LDContext.defaultKey(kind: kind)
            anonymous = true
        }

        if !allowEmptyKey && contextKey.isEmpty {
            return Result.failure(.emptyKey)
        }

        var context = LDContext(canonicalizedKey: canonicalizeKeyForKind(kind: kind, key: contextKey, omitUserKind: true))
        context.kind = kind
        context.contexts = []
        context.name = self.name
        context.anonymous = anonymous
        context.privateAttributes = self.privateAttributes
        context.key = contextKey
        context.attributes = self.attributes

        return Result.success(context)
    }
}

extension LDContextBuilder: TypeIdentifying { }

/// Contains method for building a multi-context.
///
/// Use this type if you need to construct a LDContext that has multiple kind values, each with its
/// own nested LDContext. To define a single-kind context, use `LDContextBuilder` instead.
///
/// Obtain an instance of LDMultiContextBuilder by calling `LDMultiContextBuilder.init()`; then, call
/// `LDMultiContextBuilder.addContext(_:)` to specify the nested LDContext for each kind.
/// LDMultiContextBuilder setters return a reference the same builder, so they can be chained
/// together.
public struct LDMultiContextBuilder {
    private var contexts: [LDContext] = []

    /// Create a new LDMultiContextBuilder with the provided `key`.
    public init() {}

    /// Adds a nested context for a specific kind to a LDMultiContextBuilder.
    ///
    /// It is invalid to add more than one context with the same Kind. This error is detected when
    /// you call `LDMultiContextBuilder.build()`.
    ///
    /// Adding a multi-kind context behaves the same as if each single-kind context was added individually.
    public mutating func addContext(_ context: LDContext) {
        if context.isMulti() {
            contexts.append(contentsOf: context.contexts)
            return
        }

        contexts.append(context)
    }

    /// Creates a LDContext from the current properties.
    ///
    /// The LDContext is immutable and will not be affected by any subsequent actions on the
    /// LDMultiContextBuilder.
    ///
    /// It is possible for a LDMultiContextBuilder to represent an invalid state. In those
    /// situations, a Result.failure will be returned.
    ///
    /// If only one context kind was added to the builder, `build` returns a single-kind context rather
    /// than a multi-context.
    public func build() -> Result<LDContext, ContextBuilderError> {
        if contexts.isEmpty {
            return Result.failure(.emptyMultiKind)
        }

        if contexts.count == 1 {
            return Result.success(contexts[0])
        }

        let uniqueKinds = Set(contexts.map { context in context.kind })
        if uniqueKinds.count != contexts.count {
            return Result.failure(.duplicateKinds)
        }

        let sortedContexts = contexts.sorted { $0.kind < $1.kind }
        let canonicalizedKey = sortedContexts.map { context in
            return canonicalizeKeyForKind(kind: context.kind, key: context.key ?? "", omitUserKind: false)
        }.joined(separator: ":")

        var context = LDContext(canonicalizedKey: canonicalizedKey)
        context.kind = .multi
        context.contexts = sortedContexts

        return Result.success(context)
    }
}

func canonicalizeKeyForKind(kind: Kind, key: String, omitUserKind: Bool) -> String {
    if omitUserKind && kind.isUser() {
        return key
    }

    let encoding = key.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""

    return "\(kind):\(encoding)"
}
