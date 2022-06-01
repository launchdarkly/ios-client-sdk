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
public struct LDContext: Encodable, Equatable {
    static let storedIdKey: String = "ldDeviceIdentifier"

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

    init(environmentReporting: EnvironmentReporting) {
        self.init(canonicalizedKey: LDContext.defaultKey(environmentReporting: environmentReporting))
    }

    public struct Meta: Codable {
        public var secondary: String?
        public var privateAttributes: [Reference]?
        public var redactedAttributes: [String]?

        enum CodingKeys: CodingKey {
            case secondary, privateAttributes, redactedAttributes
        }

        public var isEmpty: Bool {
            secondary == nil
            && (privateAttributes?.isEmpty ?? true)
            && (redactedAttributes?.isEmpty ?? true)
        }

        init(secondary: String?, privateAttributes: [Reference]?, redactedAttributes: [String]?) {
            self.secondary = secondary
            self.privateAttributes = privateAttributes
            self.redactedAttributes = redactedAttributes
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            let secondary = try container.decodeIfPresent(String.self, forKey: .secondary)
            let privateAttributes = try container.decodeIfPresent([Reference].self, forKey: .privateAttributes)

            self.secondary = secondary
            self.privateAttributes = privateAttributes
            self.redactedAttributes = []
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(secondary, forKey: .secondary)

            if let privateAttributes = privateAttributes, !privateAttributes.isEmpty {
                try container.encodeIfPresent(privateAttributes, forKey: .privateAttributes)
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

    static private func encodeSingleContext(container: inout KeyedEncodingContainer<DynamicCodingKeys>, context: LDContext, discardKind: Bool, includePrivateAttributes: Bool, allAttributesPrivate: Bool, globalPrivateAttributes: SharedDictionary<String, PrivateAttributeLookupNode>) throws {
        if !discardKind {
            try container.encodeIfPresent(context.kind.description, forKey: DynamicCodingKeys(string: "kind"))
        }

        try container.encodeIfPresent(context.key, forKey: DynamicCodingKeys(string: "key"))

        let optionalAttributeNames = context.getOptionalAttributeNames()
        var redactedAttributes: [String] = []
        redactedAttributes.reserveCapacity(20)

        for key in optionalAttributeNames {
            let reference = Reference(key)
            if let value = context.getValue(reference) {
                if allAttributesPrivate {
                    redactedAttributes.append(reference.raw())
                    continue
                }

                var path: [String] = []
                path.reserveCapacity(10)
                try LDContext.writeFilterAttribute(context: context, container: &container, parentPath: path, key: key, value: value, redactedAttributes: &redactedAttributes, includePrivateAttributes: includePrivateAttributes, globalPrivateAttributes: globalPrivateAttributes)
            }
        }

        let meta = Meta(secondary: context.secondary, privateAttributes: context.privateAttributes, redactedAttributes: redactedAttributes)

        if !meta.isEmpty {
            try container.encodeIfPresent(meta, forKey: DynamicCodingKeys(string: "_meta"))
        }

        if context.transient {
            try container.encodeIfPresent(context.transient, forKey: DynamicCodingKeys(string: "transient"))
        }
    }

    static private func writeFilterAttribute(context: LDContext, container: inout KeyedEncodingContainer<DynamicCodingKeys>, parentPath: [String], key: String, value: LDValue, redactedAttributes: inout [String], includePrivateAttributes: Bool, globalPrivateAttributes: SharedDictionary<String, PrivateAttributeLookupNode>) throws {
        var path = parentPath
        path.append(key.description)

        let (isReacted, nestedPropertiesAreRedacted) = includePrivateAttributes ? (false, false) : LDContext.maybeRedact(context: context, parentPath: path, value: value, redactedAttributes: &redactedAttributes, globalPrivateAttributes: globalPrivateAttributes)

        switch value {
        case .object(_) where isReacted:
            break
        case .object(let objectMap):
            if !nestedPropertiesAreRedacted {
                try container.encode(value, forKey: DynamicCodingKeys(string: key))
                return
            }

            // TODO(mmk): This might be a problem. We might write a sub container even if all the attributes are completely filtered out.
            var subContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: DynamicCodingKeys(string: key))
            for (key, value) in objectMap {
                try writeFilterAttribute(context: context, container: &subContainer, parentPath: path, key: key, value: value, redactedAttributes: &redactedAttributes, includePrivateAttributes: includePrivateAttributes, globalPrivateAttributes: globalPrivateAttributes)
            }
        case _ where !isReacted:
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
        if case .object(_) = value {
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
                if let (name, _) = privateAttribute.component(index) {
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

    internal struct UserInfoKeys {
        // TODO(mmk): Everywhere we use DynamicCodingKey, we should CodingUserInfoKey
        static let includePrivateAttributes = CodingUserInfoKey(rawValue: "LD_includePrivateAttributes")!
        static let allAttributesPrivate = CodingUserInfoKey(rawValue: "LD_allAttributesPrivate")!
        static let globalPrivateAttributes = CodingUserInfoKey(rawValue: "LD_globalPrivateAttributes")!
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)

        let includePrivateAttributes = encoder.userInfo[UserInfoKeys.includePrivateAttributes] as? Bool ?? false
        let allAttributesPrivate = encoder.userInfo[UserInfoKeys.allAttributesPrivate] as? Bool ?? false
        let globalPrivateAttributes = encoder.userInfo[UserInfoKeys.globalPrivateAttributes] as? [Reference] ?? []

        let allPrivate = !includePrivateAttributes && allAttributesPrivate
        let globalPrivate = includePrivateAttributes ? [] : globalPrivateAttributes
        let globalDictionary = LDContext.makePrivateAttributeLookupData(references: globalPrivate)

        if isMulti() {
            try container.encodeIfPresent(kind.description, forKey: DynamicCodingKeys(string: "kind"))

            for context in contexts {
                var contextContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: DynamicCodingKeys(string: context.kind.description))
                try LDContext.encodeSingleContext(container: &contextContainer, context: context, discardKind: true, includePrivateAttributes: includePrivateAttributes, allAttributesPrivate: allPrivate, globalPrivateAttributes: globalDictionary)
            }
        } else {
            try LDContext.encodeSingleContext(container: &container, context: self, discardKind: false, includePrivateAttributes: includePrivateAttributes, allAttributesPrivate: allPrivate, globalPrivateAttributes: globalDictionary)
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
                if let (name, _) = reference.component(index) {
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

    /// TKTK
    public func fullyQualifiedKey() -> String {
        return canonicalizedKey
    }

    /// TKTK
    public func isMulti() -> Bool {
        return self.kind.isMulti()
    }

    public func contextKeys() -> [String: String] {
        guard isMulti() else {
            return [kind.description: key ?? ""]
        }

        let keys = Dictionary(contexts.map { ($0.kind.description, $0.key ?? "") }) { first, _ in first }
        return keys
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
        case "transient":
            return .bool(self.transient)
        default:
            return self.attributes[name]
        }
    }

    /// Default key is the LDContext.key the SDK provides when any intializer is called without defining the key. The key should be constant with respect to the client app installation on a specific device. (The key may change if the client app is uninstalled and then reinstalled on the same device.)
    /// - parameter environmentReporter: The environmentReporter provides selected information that varies between OS regarding how it's determined
    static func defaultKey(environmentReporting: EnvironmentReporting) -> String {
        // For iOS & tvOS, this should be UIDevice.current.identifierForVendor.UUIDString
        // For macOS & watchOS, this should be a UUID that the sdk creates and stores so that the value returned here should be always the same
        if let vendorUUID = environmentReporting.vendorUUID {
            return vendorUUID
        }

        if let storedId = UserDefaults.standard.string(forKey: storedIdKey) {
            return storedId
        }

        let key = UUID().uuidString
        UserDefaults.standard.set(key, forKey: storedIdKey)

        return key
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
