import Foundation

func userType(_ user: LDUser) -> String { 
    return user.isAnonymous ? "anonymousUser" : "user" 
}

struct Event: Encodable {
    enum CodingKeys: String, CodingKey {
        case key, previousKey, kind, creationDate, user, userKey, 
             value, defaultValue = "default", variation, version, 
             data, startDate, endDate, features, reason, metricValue,
             // for aliasing
             contextKind, previousContextKind
    }

    enum Kind: String {
        case feature, debug, identify, custom, summary, alias

        static var allKinds: [Kind] {
            [feature, debug, identify, custom, summary, alias]
        }
        
        var isAlwaysInlineUserKind: Bool {
            [.identify, .debug].contains(self)
        }
        
        var isAlwaysIncludeValueKinds: Bool {
            [.feature, .debug].contains(self)
        }

        var needsContextKind: Bool { 
            [.feature, .custom].contains(self)
        }
    }

    let kind: Kind
    let key: String?
    let previousKey: String?
    let creationDate: Date?
    let user: LDUser?
    let value: LDValue
    let defaultValue: LDValue
    let featureFlag: FeatureFlag?
    let data: LDValue
    let flagRequestTracker: FlagRequestTracker?
    let endDate: Date?
    let includeReason: Bool
    let metricValue: Double?
    let contextKind: String?
    let previousContextKind: String?

    init(kind: Kind = .custom,
         key: String? = nil,
         previousKey: String? = nil,
         contextKind: String? = nil,
         previousContextKind: String? = nil,
         user: LDUser? = nil,
         value: LDValue = .null,
         defaultValue: LDValue = .null,
         featureFlag: FeatureFlag? = nil,
         data: LDValue = .null,
         flagRequestTracker: FlagRequestTracker? = nil,
         endDate: Date? = nil,
         includeReason: Bool = false,
         metricValue: Double? = nil) {
        self.kind = kind
        self.key = key
        self.previousKey = previousKey
        self.creationDate = kind == .summary ? nil : Date()
        self.user = user
        self.value = value
        self.defaultValue = defaultValue
        self.featureFlag = featureFlag
        self.data = data
        self.flagRequestTracker = flagRequestTracker
        self.endDate = endDate
        self.includeReason = includeReason
        self.metricValue = metricValue
        self.contextKind = contextKind
        self.previousContextKind = previousContextKind
    }

    // swiftlint:disable:next function_parameter_count
    static func featureEvent(key: String, value: LDValue, defaultValue: LDValue, featureFlag: FeatureFlag?, user: LDUser, includeReason: Bool) -> Event {
        Log.debug(typeName(and: #function) + "key: \(key), value: \(value), defaultValue: \(defaultValue), includeReason: \(includeReason), featureFlag: \(String(describing: featureFlag))")
        return Event(kind: .feature, key: key, user: user, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason)
    }

    // swiftlint:disable:next function_parameter_count
    static func debugEvent(key: String, value: LDValue, defaultValue: LDValue, featureFlag: FeatureFlag, user: LDUser, includeReason: Bool) -> Event {
        Log.debug(typeName(and: #function) + "key: \(key), value: \(value), defaultValue: \(defaultValue), includeReason: \(includeReason), featureFlag: \(String(describing: featureFlag))")
        return Event(kind: .debug, key: key, user: user, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason)
    }

    static func customEvent(key: String, user: LDUser, data: LDValue, metricValue: Double? = nil) -> Event {
        Log.debug(typeName(and: #function) + "key: " + key + ", data: \(data), metricValue: \(String(describing: metricValue))")
        return Event(kind: .custom, key: key, user: user, data: data, metricValue: metricValue)
    }

    static func identifyEvent(user: LDUser) -> Event {
        Log.debug(typeName(and: #function) + "key: " + user.key)
        return Event(kind: .identify, key: user.key, user: user)
    }

    static func summaryEvent(flagRequestTracker: FlagRequestTracker, endDate: Date = Date()) -> Event? {
        Log.debug(typeName(and: #function))
        guard flagRequestTracker.hasLoggedRequests
        else { return nil }
        return Event(kind: .summary, flagRequestTracker: flagRequestTracker, endDate: endDate)
    }

    static func aliasEvent(newUser new: LDUser, oldUser old: LDUser) -> Event {
        Log.debug("\(typeName(and: #function)) key: \(new.key), previousKey: \(old.key)")
        return Event(kind: .alias, key: new.key, previousKey: old.key, contextKind: userType(new), previousContextKind: userType(old))
    }

    struct UserInfoKeys {
        static let inlineUserInEvents = CodingUserInfoKey(rawValue: "LD_inlineUserInEvents")!
    }

    func encode(to encoder: Encoder) throws {
        let inlineUserInEvents = encoder.userInfo[UserInfoKeys.inlineUserInEvents] as? Bool ?? false

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind.rawValue, forKey: .kind)
        try container.encodeIfPresent(key, forKey: .key)
        try container.encodeIfPresent(previousKey, forKey: .previousKey)
        try container.encodeIfPresent(creationDate, forKey: .creationDate)
        if kind.isAlwaysInlineUserKind || inlineUserInEvents {
            try container.encodeIfPresent(user, forKey: .user)
        } else {
            try container.encodeIfPresent(user?.key, forKey: .userKey)
        }
        if kind.isAlwaysIncludeValueKinds {
            try container.encode(value, forKey: .value)
            try container.encode(defaultValue, forKey: .defaultValue)
        }
        try container.encodeIfPresent(featureFlag?.variation, forKey: .variation)
        try container.encodeIfPresent(featureFlag?.versionForEvents, forKey: .version)
        if data != .null {
            try container.encode(data, forKey: .data)
        }
        if let flagRequestTracker = flagRequestTracker {
            try container.encode(flagRequestTracker.startDate, forKey: .startDate)
            try container.encode(flagRequestTracker.flagCounters, forKey: .features)
        }
        try container.encodeIfPresent(endDate, forKey: .endDate)
        if let reason = includeReason || featureFlag?.trackReason ?? false ? featureFlag?.reason : nil {
            try container.encode(LDValue.fromAny(reason), forKey: .reason)
        }
        try container.encodeIfPresent(metricValue, forKey: .metricValue)
        if kind.needsContextKind && (user?.isAnonymous == true) {
            try container.encode("anonymousUser", forKey: .contextKind)
        }
        if kind == .alias {
            try container.encodeIfPresent(self.contextKind, forKey: .contextKind)
            try container.encodeIfPresent(self.previousContextKind, forKey: .previousContextKind)
        }
    }
}

extension Event: TypeIdentifying { }
