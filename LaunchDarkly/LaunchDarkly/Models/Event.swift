//
//  Event.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

struct Event { //sdk internal, not publically accessible
    enum CodingKeys: String, CodingKey {
        case key, kind, creationDate, user, userKey, value, defaultValue = "default", variation, version, data, endDate, reason, metricValue
    }

    enum Kind: String {
        case feature, debug, identify, custom, summary

        static var allKinds: [Kind] {
            [feature, debug, identify, custom, summary]
        }
        static var alwaysInlineUserKinds: [Kind] {
            [identify, debug]
        }
        var isAlwaysInlineUserKind: Bool {
            Kind.alwaysInlineUserKinds.contains(self)
        }
        static var alwaysIncludeValueKinds: [Kind] {
            [feature, debug]
        }
        var isAlwaysIncludeValueKinds: Bool {
            Kind.alwaysIncludeValueKinds.contains(self)
        }
    }

    let kind: Kind
    let key: String?
    let creationDate: Date?
    let user: LDUser?
    let value: Any?
    let defaultValue: Any?
    let featureFlag: FeatureFlag?
    let data: Any?
    let flagRequestTracker: FlagRequestTracker?
    let endDate: Date?
    let includeReason: Bool
    let metricValue: Double?

    init(kind: Kind = .custom,
         key: String? = nil,
         user: LDUser? = nil,
         value: Any? = nil,
         defaultValue: Any? = nil,
         featureFlag: FeatureFlag? = nil,
         data: Any? = nil,
         flagRequestTracker: FlagRequestTracker? = nil,
         endDate: Date? = nil,
         includeReason: Bool = false,
         metricValue: Double? = nil) {
        self.kind = kind
        self.key = key
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
    }

    // swiftlint:disable:next function_parameter_count
    static func featureEvent(key: String, value: Any?, defaultValue: Any?, featureFlag: FeatureFlag?, user: LDUser, includeReason: Bool) -> Event {
        Log.debug(typeName(and: #function) + "key: " + key + ", value: \(String(describing: value)), " + "defaultValue: \(String(describing: defaultValue) + "reason: \(String(describing: includeReason))"), "
            + "featureFlag: \(String(describing: featureFlag))")
        return Event(kind: .feature, key: key, user: user, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason)
    }

    // swiftlint:disable:next function_parameter_count
    static func debugEvent(key: String, value: Any?, defaultValue: Any?, featureFlag: FeatureFlag, user: LDUser, includeReason: Bool) -> Event {
        Log.debug(typeName(and: #function) + "key: " + key + ", value: \(String(describing: value)), " + "defaultValue: \(String(describing: defaultValue) + "reason: \(String(describing: includeReason))"), "
            + "featureFlag: \(String(describing: featureFlag))")
        return Event(kind: .debug, key: key, user: user, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason)
    }

    static func customEvent(key: String, user: LDUser, data: Any? = nil, metricValue: Double? = nil) throws -> Event {
        Log.debug(typeName(and: #function) + "key: " + key + ", data: \(String(describing: data)), metricValue: \(String(describing: metricValue))")
        if let data = data {
            guard JSONSerialization.isValidJSONObject([CodingKeys.data.rawValue: data]) //the top level object must be either an array or an object for isValidJSONObject to work correctly
            else {
                throw LDInvalidArgumentError("data is not a JSON convertible value")
            }
        }
        return Event(kind: .custom, key: key, user: user, data: data, metricValue: metricValue)
    }

    static func identifyEvent(user: LDUser) -> Event {
        Log.debug(typeName(and: #function) + "key: " + user.key)
        return Event(kind: .identify, key: user.key, user: user)
    }

    static func summaryEvent(flagRequestTracker: FlagRequestTracker, endDate: Date = Date()) -> Event? {
        Log.debug(typeName(and: #function))
        guard flagRequestTracker.hasLoggedRequests
        else {
            return nil
        }
        return Event(kind: .summary, flagRequestTracker: flagRequestTracker, endDate: endDate)
    }

    func dictionaryValue(config: LDConfig) -> [String: Any] {
        var eventDictionary = [String: Any]()
        eventDictionary[CodingKeys.kind.rawValue] = kind.rawValue
        eventDictionary[CodingKeys.key.rawValue] = key
        eventDictionary[CodingKeys.creationDate.rawValue] = creationDate?.millisSince1970
        if kind.isAlwaysInlineUserKind || config.inlineUserInEvents {
            eventDictionary[CodingKeys.user.rawValue] = user?.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: false, config: config)
        } else {
            eventDictionary[CodingKeys.userKey.rawValue] = user?.key
        }
        if kind.isAlwaysIncludeValueKinds {
            eventDictionary[CodingKeys.value.rawValue] = value ?? NSNull()
            eventDictionary[CodingKeys.defaultValue.rawValue] = defaultValue ?? NSNull()
        }
        eventDictionary[CodingKeys.variation.rawValue] = featureFlag?.variation
        //If the flagVersion exists, it is reported as the "version". If not, the version is reported using the "version" key.
        eventDictionary[CodingKeys.version.rawValue] = featureFlag?.flagVersion ?? featureFlag?.version
        eventDictionary[CodingKeys.data.rawValue] = data
        if let flagRequestTracker = flagRequestTracker {
            eventDictionary.merge(flagRequestTracker.dictionaryValue) { _, trackerItem in
                trackerItem  // This should never happen because the eventDictionary does not use any conflicting keys with the flagRequestTracker
            }
        }
        eventDictionary[CodingKeys.endDate.rawValue] = endDate?.millisSince1970
        eventDictionary[CodingKeys.reason.rawValue] = includeReason || featureFlag?.trackReason ?? false ? featureFlag?.reason : nil
        eventDictionary[CodingKeys.metricValue.rawValue] = metricValue

        return eventDictionary
    }
}

extension Array where Element == Event {
    func dictionaryValues(config: LDConfig) -> [[String: Any]] {
        self.map { $0.dictionaryValue(config: config) }
    }
}

extension Array where Element == [String: Any] {
    var jsonData: Data? {
        guard JSONSerialization.isValidJSONObject(self)
        else { return nil }
        return try? JSONSerialization.data(withJSONObject: self, options: [])
    }

    func contains(_ eventDictionary: [String: Any]) -> Bool {
        self.contains { $0.matches(eventDictionary: eventDictionary) }
    }
}

extension Dictionary where Key == String, Value == Any {
    private var eventKindString: String? {
        self[Event.CodingKeys.kind.rawValue] as? String
    }
    var eventKind: Event.Kind? {
        guard let eventKindString = eventKindString
        else { return nil }
        return Event.Kind(rawValue: eventKindString)
    }
    var eventKey: String? {
        self[Event.CodingKeys.key.rawValue] as? String
    }
    var eventCreationDateMillis: Int64? {
        self[Event.CodingKeys.creationDate.rawValue] as? Int64
    }
    var eventEndDate: Date? {
        Date(millisSince1970: self[Event.CodingKeys.endDate.rawValue] as? Int64)
    }

    func matches(eventDictionary other: [String: Any]) -> Bool {
        guard let kind = eventKind
        else { return false }
        if kind == .summary {
            guard kind == other.eventKind,
                let eventEndDate = eventEndDate, eventEndDate.isWithin(0.001, of: other.eventEndDate)
            else { return false }
            return true
        }
        guard let key = eventKey, let creationDateMillis = eventCreationDateMillis,
            let otherKey = other.eventKey, let otherCreationDateMillis = other.eventCreationDateMillis
        else { return false }
        return key == otherKey && creationDateMillis == otherCreationDateMillis
    }
}

extension Event: Equatable {
    static func == (lhs: Event, rhs: Event) -> Bool {
        if lhs.kind == .summary {
            return lhs.kind == rhs.kind && lhs.endDate?.isWithin(0.001, of: rhs.endDate) ?? false
        }
        return lhs.kind == rhs.kind && lhs.key == rhs.key && lhs.creationDate == rhs.creationDate
    }
}

extension Event: TypeIdentifying { }
