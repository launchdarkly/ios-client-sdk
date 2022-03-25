import Foundation

struct FeatureFlag: Codable {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case flagKey = "key", value, variation, version, flagVersion, trackEvents, debugEventsUntilDate, reason, trackReason
    }

    let flagKey: LDFlagKey
    let value: Any?
    let variation: Int?
    /// The "environment" version. It changes whenever any feature flag in the environment changes. Used for version comparisons for streaming patch and delete.
    let version: Int?
    /// The feature flag version. It changes whenever this feature flag changes. Used for event reporting only. Server json lists this as "flagVersion". Event json lists this as "version".
    let flagVersion: Int?
    let trackEvents: Bool
    let debugEventsUntilDate: Date?
    let reason: [String: Any]?
    let trackReason: Bool

    var versionForEvents: Int? { flagVersion ?? version }

    init(flagKey: LDFlagKey,
         value: Any? = nil,
         variation: Int? = nil,
         version: Int? = nil,
         flagVersion: Int? = nil,
         trackEvents: Bool = false,
         debugEventsUntilDate: Date? = nil,
         reason: [String: Any]? = nil,
         trackReason: Bool = false) {
        self.flagKey = flagKey
        self.value = value is NSNull ? nil : value
        self.variation = variation
        self.version = version
        self.flagVersion = flagVersion
        self.trackEvents = trackEvents
        self.debugEventsUntilDate = debugEventsUntilDate
        self.reason = reason
        self.trackReason = trackReason
    }

    init?(dictionary: [String: Any]?) {
        guard let dictionary = dictionary,
            let flagKey = dictionary.flagKey
        else { return nil }
        self.init(flagKey: flagKey,
                  value: dictionary.value,
                  variation: dictionary.variation,
                  version: dictionary.version,
                  flagVersion: dictionary.flagVersion,
                  trackEvents: dictionary.trackEvents ?? false,
                  debugEventsUntilDate: Date(millisSince1970: dictionary.debugEventsUntilDate),
                  reason: dictionary.reason,
                  trackReason: dictionary.trackReason ?? false)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let flagKey = try container.decode(LDFlagKey.self, forKey: .flagKey)
        try self.init(flagKey: flagKey, container: container)
    }

    fileprivate init(flagKey: LDFlagKey, container: KeyedDecodingContainer<CodingKeys>) throws {
        let containedFlagKey = try container.decodeIfPresent(LDFlagKey.self, forKey: .flagKey)
        if let contained = containedFlagKey, contained != flagKey {
            let description = "key in flag model \"\(contained)\" does not match contextual flag key \"\(flagKey)\""
            throw DecodingError.dataCorruptedError(forKey: .flagKey, in: container, debugDescription: description)
        }
        self.flagKey = flagKey
        self.value = (try container.decodeIfPresent(LDValue.self, forKey: .value))?.toAny()
        self.variation = try container.decodeIfPresent(Int.self, forKey: .variation)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version)
        self.flagVersion = try container.decodeIfPresent(Int.self, forKey: .flagVersion)
        self.trackEvents = (try container.decodeIfPresent(Bool.self, forKey: .trackEvents)) ?? false
        self.debugEventsUntilDate = Date(millisSince1970: try container.decodeIfPresent(Int64.self, forKey: .debugEventsUntilDate))
        self.reason = (try container.decodeIfPresent(LDValue.self, forKey: .reason))?.toAny() as? [String: Any]
        self.trackReason = (try container.decodeIfPresent(Bool.self, forKey: .trackReason)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(flagKey, forKey: .flagKey)
        let val = LDValue.fromAny(value)
        if val != .null { try container.encode(val, forKey: .value) }
        try container.encodeIfPresent(variation, forKey: .variation)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encodeIfPresent(flagVersion, forKey: .flagVersion)
        if trackEvents { try container.encode(true, forKey: .trackEvents) }
        if let debugEventsUntilDate = debugEventsUntilDate {
            try container.encode(debugEventsUntilDate.millisSince1970, forKey: .debugEventsUntilDate)
        }
        if reason != nil { try container.encode(LDValue.fromAny(reason), forKey: .reason) }
        if trackReason { try container.encode(true, forKey: .trackReason) }
    }

    var dictionaryValue: [String: Any] {
        var dictionaryValue = [String: Any]()
        dictionaryValue[CodingKeys.flagKey.rawValue] = flagKey
        dictionaryValue[CodingKeys.value.rawValue] = value ?? NSNull()
        dictionaryValue[CodingKeys.variation.rawValue] = variation ?? NSNull()
        dictionaryValue[CodingKeys.version.rawValue] = version ?? NSNull()
        dictionaryValue[CodingKeys.flagVersion.rawValue] = flagVersion ?? NSNull()
        dictionaryValue[CodingKeys.trackEvents.rawValue] = trackEvents ? true : NSNull()
        dictionaryValue[CodingKeys.debugEventsUntilDate.rawValue] = debugEventsUntilDate?.millisSince1970 ?? NSNull()
        dictionaryValue[CodingKeys.reason.rawValue] = reason ?? NSNull()
        dictionaryValue[CodingKeys.trackReason.rawValue] = trackReason ? true : NSNull()
        return dictionaryValue
    }

    func shouldCreateDebugEvents(lastEventReportResponseTime: Date?) -> Bool {
        (lastEventReportResponseTime ?? Date()) <= (debugEventsUntilDate ?? Date.distantPast)
    }
}

struct FeatureFlagCollection: Codable {
    let flags: [LDFlagKey: FeatureFlag]

    init(_ flags: [FeatureFlag]) {
        self.flags = Dictionary(uniqueKeysWithValues: flags.map { ($0.flagKey, $0) })
    }

    init(from decoder: Decoder) throws {
        var allFlags: [LDFlagKey: FeatureFlag] = [:]
        let container = try decoder.container(keyedBy: DynamicKey.self)
        try container.allKeys.forEach { key in
            let flagContainer = try container.nestedContainer(keyedBy: FeatureFlag.CodingKeys.self, forKey: key)
            allFlags[key.stringValue] = try FeatureFlag(flagKey: key.stringValue, container: flagContainer)
        }
        self.flags = allFlags
    }

    func encode(to encoder: Encoder) throws {
        try flags.encode(to: encoder)
    }
}

extension FeatureFlag: Equatable {
    static func == (lhs: FeatureFlag, rhs: FeatureFlag) -> Bool {
        lhs.flagKey == rhs.flagKey &&
        lhs.variation == rhs.variation &&
        lhs.version == rhs.version &&
        AnyComparer.isEqual(lhs.reason, to: rhs.reason) &&
        lhs.trackReason == rhs.trackReason
    }
}

extension Dictionary where Key == LDFlagKey, Value == FeatureFlag {
    var dictionaryValue: [String: Any] { self.compactMapValues { $0.dictionaryValue } }
}

extension Dictionary where Key == String, Value == Any {
    var flagKey: String? {
        self[FeatureFlag.CodingKeys.flagKey.rawValue] as? String
    }

    var value: Any? {
        self[FeatureFlag.CodingKeys.value.rawValue]
    }

    var variation: Int? {
        self[FeatureFlag.CodingKeys.variation.rawValue] as? Int
    }

    var version: Int? {
        self[FeatureFlag.CodingKeys.version.rawValue] as? Int
    }

    var flagVersion: Int? {
        self[FeatureFlag.CodingKeys.flagVersion.rawValue] as? Int
    }

    var trackEvents: Bool? {
        self[FeatureFlag.CodingKeys.trackEvents.rawValue] as? Bool
    }

    var debugEventsUntilDate: Int64? {
        self[FeatureFlag.CodingKeys.debugEventsUntilDate.rawValue] as? Int64
    }
    
    var reason: [String: Any]? {
        self[FeatureFlag.CodingKeys.reason.rawValue] as? [String: Any]
    }
    
    var trackReason: Bool? {
        self[FeatureFlag.CodingKeys.trackReason.rawValue] as? Bool
    }

    var flagCollection: [LDFlagKey: FeatureFlag]? {
        guard !(self is [LDFlagKey: FeatureFlag])
        else {
            return self as? [LDFlagKey: FeatureFlag]
        }
        let flagCollection = [LDFlagKey: FeatureFlag](uniqueKeysWithValues: compactMap { flagKey, value -> (LDFlagKey, FeatureFlag)? in
            var elementDictionary = value as? [String: Any]
            if elementDictionary?[FeatureFlag.CodingKeys.flagKey.rawValue] == nil {
                elementDictionary?[FeatureFlag.CodingKeys.flagKey.rawValue] = flagKey
            }
            guard let featureFlag = FeatureFlag(dictionary: elementDictionary)
            else { return nil }
            return (flagKey, featureFlag)
        })
        guard flagCollection.count == self.count
        else { return nil }
        return flagCollection
    }
}
