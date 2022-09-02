import Foundation

struct FeatureFlag: Codable {

    enum CodingKeys: String, CodingKey, CaseIterable {
        case flagKey = "key", value, variation, version, flagVersion, trackEvents, debugEventsUntilDate, reason, trackReason
    }

    let flagKey: LDFlagKey
    let value: LDValue
    let variation: Int?
    /// The "environment" version. It changes whenever any feature flag in the environment changes. Used for version comparisons for streaming patch and delete.
    let version: Int?
    /// The feature flag version. It changes whenever this feature flag changes. Used for event reporting only. Server json lists this as "flagVersion". Event json lists this as "version".
    let flagVersion: Int?
    let trackEvents: Bool
    let debugEventsUntilDate: Date?
    let reason: [String: LDValue]?
    let trackReason: Bool

    var versionForEvents: Int? { flagVersion ?? version }

    init(flagKey: LDFlagKey,
         value: LDValue = .null,
         variation: Int? = nil,
         version: Int? = nil,
         flagVersion: Int? = nil,
         trackEvents: Bool = false,
         debugEventsUntilDate: Date? = nil,
         reason: [String: LDValue]? = nil,
         trackReason: Bool = false) {
        self.flagKey = flagKey
        self.value = value
        self.variation = variation
        self.version = version
        self.flagVersion = flagVersion
        self.trackEvents = trackEvents
        self.debugEventsUntilDate = debugEventsUntilDate
        self.reason = reason
        self.trackReason = trackReason
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
        self.value = (try container.decodeIfPresent(LDValue.self, forKey: .value)) ?? .null
        self.variation = try container.decodeIfPresent(Int.self, forKey: .variation)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version)
        self.flagVersion = try container.decodeIfPresent(Int.self, forKey: .flagVersion)
        self.trackEvents = (try container.decodeIfPresent(Bool.self, forKey: .trackEvents)) ?? false
        self.debugEventsUntilDate = Date(millisSince1970: try container.decodeIfPresent(Int64.self, forKey: .debugEventsUntilDate))
        self.reason = try container.decodeIfPresent([String: LDValue].self, forKey: .reason)
        self.trackReason = (try container.decodeIfPresent(Bool.self, forKey: .trackReason)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(flagKey, forKey: .flagKey)
        if value != .null { try container.encode(value, forKey: .value) }
        try container.encodeIfPresent(variation, forKey: .variation)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encodeIfPresent(flagVersion, forKey: .flagVersion)
        if trackEvents { try container.encode(true, forKey: .trackEvents) }
        if let debugEventsUntilDate = debugEventsUntilDate {
            try container.encode(debugEventsUntilDate.millisSince1970, forKey: .debugEventsUntilDate)
        }
        if reason != nil { try container.encode(reason, forKey: .reason) }
        if trackReason { try container.encode(true, forKey: .trackReason) }
    }

    func shouldCreateDebugEvents(lastEventReportResponseTime: Date?) -> Bool {
        (lastEventReportResponseTime ?? Date()) <= (debugEventsUntilDate ?? Date.distantPast)
    }
}

struct FeatureFlagCollection: Codable {
    let flags: [LDFlagKey: FeatureFlag]

    init(_ flags: [LDFlagKey: FeatureFlag]) {
        self.flags = flags
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

struct StoredItemCollection: Codable {
    let flags: StoredItems

    init(_ flags: StoredItems) {
        self.flags = flags
    }

    init(_ collection: FeatureFlagCollection) {
        self.flags = StoredItems(items: collection.flags)
    }
}
