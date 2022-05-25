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
public struct LDContext {
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

    mutating func secondary(_ secondary: String) {
        self.secondary = secondary
    }

    mutating func transient(_ transient: Bool) {
        self.transient = transient
    }

    mutating func addPrivateAttribute(_ reference: Reference) {
        self.privateAttributes.append(reference)
    }

    mutating func removePrivateAttribute(_ reference: Reference) {
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

        // TODO(mmk) If we are converting legacy users to newer user contexts,
        // then the key is allowed to be empty. Otherwise, it cannot be. So we
        // need to hook up that condition still.
        if self.key?.isEmpty ?? true {
            return Result.failure(.emptyKey)
        }

        var context = LDContext(canonicalizedKey: canonicalizeKeyForKind(kind: kind, key: self.key!, omitUserKind: true))
        context.kind = kind
        context.contexts = []
        context.name = self.name
        context.transient = self.transient
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
