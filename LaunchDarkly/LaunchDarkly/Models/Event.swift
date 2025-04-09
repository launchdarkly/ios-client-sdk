import Foundation

private protocol SubEvent {
    func encode(to encoder: Encoder, container: KeyedEncodingContainer<Event.CodingKeys>) throws
}

class Event: Encodable {
    enum CodingKeys: String, CodingKey {
        case key, previousKey, kind, creationDate, context, contextKeys, value, defaultValue = "default", variation, version,
             data, startDate, endDate, features, reason, metricValue, contextKind, previousContextKind
    }

    enum Kind: String {
        case feature, debug, identify, custom, summary

        static var allKinds: [Kind] {
            [feature, debug, identify, custom, summary]
        }
    }

    let kind: Kind

    fileprivate init(kind: Kind) {
        self.kind = kind
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind.rawValue, forKey: .kind)
        switch self.kind {
        case .custom: try (self as? CustomEvent)?.encode(to: encoder, container: container)
        case .debug, .feature: try (self as? FeatureEvent)?.encode(to: encoder, container: container)
        case .identify: try (self as? IdentifyEvent)?.encode(to: encoder, container: container)
        case .summary: try (self as? SummaryEvent)?.encode(to: encoder, container: container)
        }
    }
}

class CustomEvent: Event, SubEvent {
    let key: String
    let context: LDContext
    let data: LDValue
    let metricValue: Double?
    let creationDate: Date

    init(key: String, context: LDContext, data: LDValue = nil, metricValue: Double? = nil, creationDate: Date = Date()) {
        self.key = key
        self.context = context
        self.data = data
        self.metricValue = metricValue
        self.creationDate = creationDate
        super.init(kind: Event.Kind.custom)
    }

    fileprivate func encode(to encoder: Encoder, container: KeyedEncodingContainer<Event.CodingKeys>) throws {
        var container = container
        try container.encode(key, forKey: .key)
        try container.encode(context, forKey: .context)

        if data != .null {
            try container.encode(data, forKey: .data)
        }
        try container.encodeIfPresent(metricValue, forKey: .metricValue)
        try container.encode(creationDate, forKey: .creationDate)
    }
}

class FeatureEvent: Event, SubEvent {
    let key: String
    let context: LDContext
    let value: LDValue
    let defaultValue: LDValue
    let featureFlag: FeatureFlag?
    let includeReason: Bool
    let creationDate: Date

    init(key: String, context: LDContext, value: LDValue, defaultValue: LDValue, featureFlag: FeatureFlag?, includeReason: Bool, isDebug: Bool, creationDate: Date = Date()) {
        self.key = key
        self.value = value
        self.defaultValue = defaultValue
        self.featureFlag = featureFlag
        self.includeReason = includeReason
        self.creationDate = creationDate

        if isDebug {
            self.context = context
            super.init(kind: .debug)
        } else {
            var newContext = LDContext(copyFrom: context)
            newContext.redactAnonymousAttributes = true
            self.context = newContext
            super.init(kind: .feature)
        }
    }

    fileprivate func encode(to encoder: Encoder, container: KeyedEncodingContainer<Event.CodingKeys>) throws {
        var container = container
        try container.encode(key, forKey: .key)
        try container.encode(context, forKey: .context)
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
    let context: LDContext
    let creationDate: Date

    init(context: LDContext, creationDate: Date = Date()) {
        self.context = context
        self.creationDate = creationDate
        super.init(kind: .identify)
    }

    fileprivate func encode(to encoder: Encoder, container: KeyedEncodingContainer<Event.CodingKeys>) throws {
        var container = container
        try container.encode(context.fullyQualifiedKey(), forKey: .key)
        try container.encode(context, forKey: .context)
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
