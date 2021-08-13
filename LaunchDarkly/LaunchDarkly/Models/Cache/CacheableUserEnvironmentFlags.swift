//
//  CacheableUserEnvironments.swift
//  LaunchDarkly
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

// Data structure used to cache feature flags for a specific user for multiple environments
// Cache model in use from 4.0.0
/*
[<userKey>: [
    “userKey”: <userKey>,                               //CacheableUserEnvironmentFlags dictionary
    “environmentFlags”: [
        <mobileKey>: [
            “userKey”: <userKey>,                       //CacheableEnvironmentFlags dictionary
            “mobileKey”: <mobileKey>,
            “featureFlags”: [
                <flagKey>: [
                    “key”: <flagKey>,                   //FeatureFlag dictionary
                    “version”: <modelVersion>,
                    “flagVersion”: <flagVersion>,
                    “variation”: <variation>,
                    “value”: <value>,
                    “trackEvents”: <trackEvents>,
                    “debugEventsUntilDate”: <debugEventsUntilDate>,
                    "reason: <reason>,
                    "trackReason": <trackReason>
                    ]
                ]
            ]
        ],
    “lastUpdated”: <lastUpdated>
    ]
]
*/
struct CacheableUserEnvironmentFlags {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case userKey, environmentFlags, lastUpdated
    }

    let userKey: String
    let environmentFlags: [MobileKey: CacheableEnvironmentFlags]
    let lastUpdated: Date

    init(userKey: String, environmentFlags: [MobileKey: CacheableEnvironmentFlags], lastUpdated: Date) {
        self.userKey = userKey
        self.environmentFlags = environmentFlags
        self.lastUpdated = lastUpdated
    }

    init?(dictionary: [String: Any]) {
        guard let userKey = dictionary[CodingKeys.userKey.rawValue] as? String,
            let environmentFlagsDictionary = dictionary[CodingKeys.environmentFlags.rawValue] as? [MobileKey: [LDFlagKey: Any]],
            let lastUpdated = (dictionary[CodingKeys.lastUpdated.rawValue] as? String)?.dateValue
        else { return nil }
        let environmentFlags = environmentFlagsDictionary.compactMapValues { cacheableEnvironmentFlagsDictionary in
            CacheableEnvironmentFlags(dictionary: cacheableEnvironmentFlagsDictionary)
        }
        self.init(userKey: userKey, environmentFlags: environmentFlags, lastUpdated: lastUpdated)
    }

    init?(object: Any) {
        guard let dictionary = object as? [String: Any]
        else { return nil }
        self.init(dictionary: dictionary)
    }

    var dictionaryValue: [String: Any] {
        [CodingKeys.userKey.rawValue: userKey,
         CodingKeys.lastUpdated.rawValue: lastUpdated.stringValue,
         CodingKeys.environmentFlags.rawValue: environmentFlags.compactMapValues { $0.dictionaryValue } ]
    }
}

extension DateFormatter {
    /// Date formatter configured to format dates to/from the format 2018-08-13T19:06:38.123Z
    class var ldDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }
}

extension Date {
    /// Date string using the format 2018-08-13T19:06:38.123Z
    var stringValue: String { DateFormatter.ldDateFormatter.string(from: self) }

    // When a date is converted to JSON, the resulting string is not as precise as the original date (only to the nearest .001s)
    // By converting the date to json, then back into a date, the result can be compared with any date re-inflated from json
    /// Date truncated to the nearest millisecond, which is the precision for string formatted dates
    var stringEquivalentDate: Date { stringValue.dateValue }
}

extension String {
    /// Date converted from a string using the format 2018-08-13T19:06:38.123Z
    var dateValue: Date { DateFormatter.ldDateFormatter.date(from: self) ?? Date() }
}
