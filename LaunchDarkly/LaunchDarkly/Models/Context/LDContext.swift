import Foundation

public enum ContextBuilderError: Error {
    case invalidKind
    case requiresMultiBuilder
    case emptyKey
    case emptyMultiKind
    case nestedMultiKind
    case duplicateKinds
}

/// TKTK
public struct LDContext: Encodable {
    internal var kind: Kind = .user
    fileprivate var contexts: [LDContext] = []

    // Meta attributes
    fileprivate var name: String?
    fileprivate var transient: Bool = false
    fileprivate var secondary: String?
    internal var privateAttributes: [Reference] = []

    fileprivate var key: String?
    fileprivate var canonicalizedKey: String
    internal var attributes: [String: LDValue] = [:]

    fileprivate init(canonicalizedKey: String) {
        self.canonicalizedKey = canonicalizedKey
    }

    public struct Meta: Codable {
        public var secondary: String?
        public var privateAttributes: [Reference]?

        enum CodingKeys: CodingKey {
            case secondary, privateAttributes
        }

        public var isEmpty: Bool {
            secondary == nil && (privateAttributes?.isEmpty ?? true)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(secondary, forKey: .secondary)

            if let privateAttributes = privateAttributes, !privateAttributes.isEmpty {
                try container.encodeIfPresent(privateAttributes, forKey: .privateAttributes)
            }
        }
    }

    static private func encodeSingleContext(container: inout KeyedEncodingContainer<DynamicCodingKeys>, context: LDContext, discardKind: Bool) throws {
        if !discardKind {
            try container.encodeIfPresent(context.kind.description, forKey: DynamicCodingKeys(string: "kind"))
        }

        try container.encodeIfPresent(context.key, forKey: DynamicCodingKeys(string: "key"))
        try container.encodeIfPresent(context.name, forKey: DynamicCodingKeys(string: "name"))

        let meta = Meta(secondary:  context.secondary, privateAttributes: context.privateAttributes)

        if !meta.isEmpty {
            try container.encodeIfPresent(meta, forKey: DynamicCodingKeys(string: "_meta"))
        }

        if !context.attributes.isEmpty {
            try context.attributes.forEach {
                try container.encodeIfPresent($0.value, forKey: DynamicCodingKeys(string: $0.key))
            }
        }

        if context.transient {
            try container.encodeIfPresent(context.transient, forKey: DynamicCodingKeys(string: "transient"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)

        if isMulti() {
            try container.encodeIfPresent(kind.description, forKey: DynamicCodingKeys(string: "kind"))

            for context in contexts {
                var contextContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: DynamicCodingKeys(string: context.kind.description))
                try LDContext.encodeSingleContext(container: &contextContainer, context: context, discardKind: true)
            }
        } else {
            try LDContext.encodeSingleContext(container: &container, context: self, discardKind: false)
        }
    }

    /// TKTK
    public func fullyQualifiedKey() -> String {
        return canonicalizedKey
    }

    /// TKTK
    public func isMulti() -> Bool {
        return self.kind.isMulti()
    }

    /// TKTK
    public func getValue(_ reference: Reference) -> LDValue? {
        if !reference.isValid() {
            return nil
        }

        guard let (component, _) = reference.component(0) else {
            return nil
        }

        if isMulti() {
            if reference.depth() == 1 && component == "kind" {
                return .string(String(kind))
            }

            Log.debug(typeName(and: #function) + ": Cannot get non-kind attribute from multi-kind context")
            return nil
        }

        guard var attribute: LDValue = self.getTopLevelAddressableAttributeSingleKind(component) else {
            return nil
        }

        for depth in 1..<reference.depth() {
            guard let (name, index) = reference.component(depth) else {
                return nil
            }

            if let idx = index {
                switch attribute {
                case .array(let array):
                    if idx < array.count {
                        attribute = array[idx]
                    } else {
                        return nil
                    }
                    continue
                default:
                    return nil
                }
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

    func getTopLevelAddressableAttributeSingleKind(_ name: String) -> LDValue? {
        switch name {
        case "kind":
            return .string(String(self.kind))
        case "key":
            return self.key.map { .string($0) }
        case "name":
            return self.name.map { .string($0) }
        case "transient":
            return .bool(self.transient)
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

            let custom = try values.decodeIfPresent([String: LDValue].self, forKey: .custom) ?? [:]
            custom.forEach { contextBuilder.trySetValue($0.key, $0.value) }

            let isAnonymous = try values.decodeIfPresent(Bool.self, forKey: .isAnonymous) ?? false
            contextBuilder.transient(isAnonymous)

            let privateAttributeNames = try values.decodeIfPresent([String].self, forKey: .privateAttributeNames) ?? []
            privateAttributeNames.forEach { contextBuilder.addPrivateAttribute(Reference($0)) }

            if let secondary = try values.decodeIfPresent(String.self, forKey: .secondary) {
                contextBuilder.secondary(secondary)
            }

            self = try contextBuilder.build().get()
        case .some("multi"):
            let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
            var multiContextBuilder = LDMultiContextBuilder()

            for key in container.allKeys  {
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
                    if let secondary = meta.secondary {
                        contextBuilder.secondary(secondary)
                    }

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
        case key, name, firstName, lastName, country, ip, email, avatar, custom, isAnonymous = "anonymous", device, operatingSystem = "os", config, privateAttributeNames, secondary
    }
}

extension LDContext: TypeIdentifying {}

/// TKTK
public struct LDContextBuilder {
    private var kind: String = Kind.user.description

    // Meta attributes
    private var name: String?
    private var transient: Bool = false
    private var secondary: String?
    private var privateAttributes: [Reference] = []

    private var key: String?
    private var attributes: [String: LDValue] = [:]

    // Contexts that were deserialized from implicit user formats
    // are allowed to have empty string keys. Otherwise, key is
    // never allowed to be empty.
    fileprivate var allowEmptyKey: Bool = false

    /// TKTK
    public init(key: String) {
        self.key = key
    }

    /// TKTK
    public mutating func kind(_ kind: String) {
        self.kind = kind
    }

    /// TKTK
    public mutating func key(_ key: String) {
        self.key = key
    }

    /// TKTK
    public mutating func name(_ name: String) {
        self.name = name
    }

    /// TKTK
    @discardableResult
    public mutating func trySetValue(_ name: String, _ value: LDValue) -> Bool {
        switch (name, value) {
        case ("", _):
            Log.debug(typeName(and: #function) + ": Provided attribute is empty. Ignoring.")
            return false
        case ("kind", .string(kind)):
            self.kind(kind)
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
        case ("transient", .bool(let val)):
            self.transient(val)
        case ("transient", _):
            return false
        case ("secondary", .string(let val)):
            self.secondary(val)
        case ("secondary", _):
            return false
        case ("privateAttributeNames", _):
            Log.debug(typeName(and: #function) + ": The privateAttributeNames property has been replaced with privateAttributes. Refusing to set a property named privateAttributeNames.")
            return false
        case ("anonymous", _):
            Log.debug(typeName(and: #function) + ": The anonymous property has been replaced with transient. Refusing to set a property named anonymous.")
            return false
        case (_, .null):
            self.attributes.removeValue(forKey: name)
            return false
        case (_, _):
            self.attributes.updateValue(value, forKey: name)
            return false
        }

        return true
    }

    /// TKTK
    public mutating func secondary(_ secondary: String) {
        self.secondary = secondary
    }

    /// TKTK
    public mutating func transient(_ transient: Bool) {
        self.transient = transient
    }

    /// TKTK
    public mutating func addPrivateAttribute(_ reference: Reference) {
        self.privateAttributes.append(reference)
    }

    /// TKTK
    public mutating func removePrivateAttribute(_ reference: Reference) {
        self.privateAttributes.removeAll { $0 == reference }
    }

    /// TKTK
    public func build() -> Result<LDContext, ContextBuilderError> {
        guard let kind = Kind(self.kind) else {
            return Result.failure(.invalidKind)
        }

        if kind.isMulti() {
            return Result.failure(.requiresMultiBuilder)
        }

        if !allowEmptyKey && self.key?.isEmpty ?? true {
            return Result.failure(.emptyKey)
        }

        var context = LDContext(canonicalizedKey: canonicalizeKeyForKind(kind: kind, key: self.key!, omitUserKind: true))
        context.kind = kind
        context.contexts = []
        context.name = self.name
        context.transient = self.transient
        context.secondary = self.secondary
        context.privateAttributes = self.privateAttributes
        context.key = self.key
        context.attributes = self.attributes

        return Result.success(context)
    }
}

extension LDContextBuilder: TypeIdentifying { }

/// TKTK
public struct LDMultiContextBuilder {
    private var contexts: [LDContext] = []

    /// TKTK
    public init() {}

    /// TKTK
    public mutating func addContext(_ context: LDContext) {
        contexts.append(context)
    }

    /// TKTK
    public func build() -> Result<LDContext, ContextBuilderError> {
        if contexts.isEmpty {
            return Result.failure(.emptyMultiKind)
        }

        if contexts.contains(where: { $0.isMulti() }) {
            return Result.failure(.nestedMultiKind)
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
