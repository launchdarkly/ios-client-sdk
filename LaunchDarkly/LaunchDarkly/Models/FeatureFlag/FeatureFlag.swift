//
//  FeatureFlag.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

struct FeatureFlag {

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
    let trackEvents: Bool?
    let debugEventsUntilDate: Date?
    let reason: [String: Any]?
    let trackReason: Bool?

    var versionForEvents: Int? { flagVersion ?? version }

    init(flagKey: LDFlagKey,
         value: Any? = nil,
         variation: Int? = nil,
         version: Int? = nil,
         flagVersion: Int? = nil,
         trackEvents: Bool? = nil,
         debugEventsUntilDate: Date? = nil,
         reason: [String: Any]? = nil,
         trackReason: Bool? = nil) {
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
                  trackEvents: dictionary.trackEvents,
                  debugEventsUntilDate: Date(millisSince1970: dictionary.debugEventsUntilDate),
                  reason: dictionary.reason,
                  trackReason: dictionary.trackReason)
    }

    var dictionaryValue: [String: Any] {
        var dictionaryValue = [String: Any]()
        dictionaryValue[CodingKeys.flagKey.rawValue] = flagKey
        dictionaryValue[CodingKeys.value.rawValue] = value ?? NSNull()
        dictionaryValue[CodingKeys.variation.rawValue] = variation ?? NSNull()
        dictionaryValue[CodingKeys.version.rawValue] = version ?? NSNull()
        dictionaryValue[CodingKeys.flagVersion.rawValue] = flagVersion ?? NSNull()
        dictionaryValue[CodingKeys.trackEvents.rawValue] = trackEvents ?? NSNull()
        dictionaryValue[CodingKeys.debugEventsUntilDate.rawValue] = debugEventsUntilDate?.millisSince1970 ?? NSNull()
        dictionaryValue[CodingKeys.reason.rawValue] = reason ?? NSNull()
        dictionaryValue[CodingKeys.trackReason.rawValue] = trackReason ?? NSNull()
        return dictionaryValue
    }

    func shouldCreateDebugEvents(lastEventReportResponseTime: Date?) -> Bool {
        guard let debugEventsUntilDate = debugEventsUntilDate
        else { return false }
        let comparisonDate = lastEventReportResponseTime ?? Date()
        return comparisonDate.isEarlierThan(debugEventsUntilDate) || comparisonDate == debugEventsUntilDate
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
