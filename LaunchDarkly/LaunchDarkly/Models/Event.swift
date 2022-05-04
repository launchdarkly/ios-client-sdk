import Foundation

private protocol SubEvent {
    func encode(to encoder: Encoder, container: KeyedEncodingContainer<Event.CodingKeys>) throws
}

class Event: Encodable {
    enum CodingKeys: String, CodingKey {
        case key, previousKey, kind, creationDate, user, userKey, value, defaultValue = "default", variation, version,
             data, startDate, endDate, features, reason, metricValue, contextKind, previousContextKind
    }

    enum Kind: String {
        case feature, debug, identify, custom, summary, alias

        static var allKinds: [Kind] {
            [feature, debug, identify, custom, summary, alias]
        }
    }

    let kind: Kind

    fileprivate init(kind: Kind) {
        self.kind = kind
    }

    struct UserInfoKeys {
        static let inlineUserInEvents = CodingUserInfoKey(rawValue: "LD_inlineUserInEvents")!
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind.rawValue, forKey: .kind)
        switch self.kind {
        case .alias: try (self as? AliasEvent)?.encode(to: encoder, container: container)
        case .custom: try (self as? CustomEvent)?.encode(to: encoder, container: container)
        case .debug, .feature: try (self as? FeatureEvent)?.encode(to: encoder, container: container)
        case .identify: try (self as? IdentifyEvent)?.encode(to: encoder, container: container)
        case .summary: try (self as? SummaryEvent)?.encode(to: encoder, container: container)
        }
    }
}

class AliasEvent: Event, SubEvent {
    let key: String
    let previousKey: String
    let contextKind: String
    let previousContextKind: String
    let creationDate: Date

    init(key: String, previousKey: String, contextKind: String, previousContextKind: String, creationDate: Date = Date()) {
        self.key = key
        self.previousKey = previousKey
        self.contextKind = contextKind
        self.previousContextKind = previousContextKind
        self.creationDate = creationDate
        super.init(kind: .alias)
    }

    fileprivate func encode(to encoder: Encoder, container: KeyedEncodingContainer<Event.CodingKeys>) throws {
        var container = container
        try container.encode(key, forKey: .key)
        try container.encode(previousKey, forKey: .previousKey)
        try container.encode(contextKind, forKey: .contextKind)
        try container.encode(previousContextKind, forKey: .previousContextKind)
        try container.encode(creationDate, forKey: .creationDate)
    }
}

class CustomEvent: Event, SubEvent {
    let key: String
    let user: LDUser
    let data: LDValue
    let metricValue: Double?
    let creationDate: Date

    init(key: String, user: LDUser, data: LDValue = nil, metricValue: Double? = nil, creationDate: Date = Date()) {
        self.key = key
        self.user = user
        self.data = data
        self.metricValue = metricValue
        self.creationDate = creationDate
        super.init(kind: Event.Kind.custom)
    }

    fileprivate func encode(to encoder: Encoder, container: KeyedEncodingContainer<Event.CodingKeys>) throws {
        var container = container
        try container.encode(key, forKey: .key)
        if encoder.userInfo[Event.UserInfoKeys.inlineUserInEvents] as? Bool ?? false {
            try container.encode(user, forKey: .user)
        } else {
            try container.encode(user.key, forKey: .userKey)
        }
        if user.isAnonymous == true {
            try container.encode("anonymousUser", forKey: .contextKind)
        }
        if data != .null {
            try container.encode(data, forKey: .data)
        }
        try container.encodeIfPresent(metricValue, forKey: .metricValue)
        try container.encode(creationDate, forKey: .creationDate)
    }
}

class FeatureEvent: Event, SubEvent {
    let key: String
    let user: LDUser
    let value: LDValue
    let defaultValue: LDValue
    let featureFlag: FeatureFlag?
    let includeReason: Bool
    let creationDate: Date

    init(key: String, user: LDUser, value: LDValue, defaultValue: LDValue, featureFlag: FeatureFlag?, includeReason: Bool, isDebug: Bool, creationDate: Date = Date()) {
        self.key = key
        self.value = value
        self.defaultValue = defaultValue
        self.featureFlag = featureFlag
        self.user = user
        self.includeReason = includeReason
        self.creationDate = creationDate
        super.init(kind: isDebug ? .debug : .feature)
    }

    fileprivate func encode(to encoder: Encoder, container: KeyedEncodingContainer<Event.CodingKeys>) throws {
        var container = container
        try container.encode(key, forKey: .key)
        if kind == .debug || encoder.userInfo[Event.UserInfoKeys.inlineUserInEvents] as? Bool ?? false {
            try container.encode(user, forKey: .user)
        } else {
            try container.encode(user.key, forKey: .userKey)
        }
        if kind == .feature && user.isAnonymous == true {
            try container.encode("anonymousUser", forKey: .contextKind)
        }
        try container.encodeIfPresent(featureFlag?.variation, forKey: .variation)
        try container.encodeIfPresent(featureFlag?.versionForEvents, forKey: .version)
        try container.encode(value, forKey: .value)
        try container.encode(defaultValue, forKey: .defaultValue)
        if let reason = includeReason || featureFlag?.trackReason ?? false ? featureFlag?.reason : nil {
            try container.encode(reason, forKey: .reason)
        }
        try container.encode(creationDate, forKey: .creationDate)
    }
}

class IdentifyEvent: Event, SubEvent {
    let user: LDUser
    let creationDate: Date

    init(user: LDUser, creationDate: Date = Date()) {
        self.user = user
        self.creationDate = creationDate
        super.init(kind: .identify)
    }

    fileprivate func encode(to encoder: Encoder, container: KeyedEncodingContainer<Event.CodingKeys>) throws {
        var container = container
        try container.encode(user.key, forKey: .key)
        try container.encode(user, forKey: .user)
        try container.encode(creationDate, forKey: .creationDate)
    }
}

class SummaryEvent: Event, SubEvent {
    let flagRequestTracker: FlagRequestTracker
    let endDate: Date

    init(flagRequestTracker: FlagRequestTracker, endDate: Date = Date()) {
        self.flagRequestTracker = flagRequestTracker
        self.endDate = endDate
        super.init(kind: .summary)
    }

    fileprivate func encode(to encoder: Encoder, container: KeyedEncodingContainer<Event.CodingKeys>) throws {
        var container = container
        try container.encode(flagRequestTracker.startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(flagRequestTracker.flagCounters, forKey: .features)
    }
}
