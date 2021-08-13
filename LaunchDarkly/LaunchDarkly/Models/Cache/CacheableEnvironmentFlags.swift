//
//  CacheableEnvironmentFlags.swift
//  LaunchDarkly
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

// Data structure used to cache feature flags for a specific user from a specific environment
struct CacheableEnvironmentFlags {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case userKey, mobileKey, featureFlags
    }

    let userKey: String
    let mobileKey: String
    let featureFlags: [LDFlagKey: FeatureFlag]

    init(userKey: String, mobileKey: String, featureFlags: [LDFlagKey: FeatureFlag]) {
        (self.userKey, self.mobileKey, self.featureFlags) = (userKey, mobileKey, featureFlags)
    }

    var dictionaryValue: [String: Any] {
        [CodingKeys.userKey.rawValue: userKey,
         CodingKeys.mobileKey.rawValue: mobileKey,
         CodingKeys.featureFlags.rawValue: featureFlags.dictionaryValue.withNullValuesRemoved]
    }

    init?(dictionary: [String: Any]) {
        guard let userKey = dictionary[CodingKeys.userKey.rawValue] as? String,
            let mobileKey = dictionary[CodingKeys.mobileKey.rawValue] as? String,
            let featureFlags = (dictionary[CodingKeys.featureFlags.rawValue] as? [String: Any])?.flagCollection
        else { return nil }
        self.init(userKey: userKey, mobileKey: mobileKey, featureFlags: featureFlags)
    }
}
