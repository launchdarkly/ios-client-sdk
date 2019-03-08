//
//  CacheableUserFlags.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 12/6/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

struct CacheableUserFlags {
    enum CodingKeys: String, CodingKey {
        case userKey, flags, lastUpdated
    }

    let userKey: String
    let flags: [String: FeatureFlag]
    let lastUpdated: Date

    init(userKey: String, flags: [LDFlagKey: FeatureFlag], lastUpdated: Date) {
        self.userKey = userKey
        self.flags = flags
        self.lastUpdated = lastUpdated
    }

    init(user: LDUser) {
        self.init(userKey: user.key, flags: user.flagStore.featureFlags, lastUpdated: user.lastUpdated)
    }

    var dictionaryValue: [String: Any] {
        return [CodingKeys.userKey.rawValue: userKey,
                CodingKeys.flags.rawValue: flags.dictionaryValue.withNullValuesRemoved,
                CodingKeys.lastUpdated.rawValue: lastUpdated.stringValue]
    }

    init?(dictionary: [String: Any]) {
        guard let flags = (dictionary[CodingKeys.flags.rawValue] as? [String: Any])?.flagCollection,
            let userKey = dictionary[CodingKeys.userKey.rawValue] as? String
        else {
            return nil
        }

        self.init(userKey: userKey, flags: flags, lastUpdated: (dictionary[CodingKeys.lastUpdated.rawValue] as? String)?.dateValue ?? Date())
    }

    init?(object: Any) {
        guard let dictionary = object as? [String: Any],
            let flags = CacheableUserFlags(dictionary: dictionary)
        else {
            return nil
        }

        self = flags
    }
}

extension CacheableUserFlags: Equatable {
    static func == (lhs: CacheableUserFlags, rhs: CacheableUserFlags) -> Bool {
        return lhs.userKey == rhs.userKey && lhs.flags == rhs.flags && (lhs.lastUpdated == rhs.lastUpdated || lhs.lastUpdated.isStringEquivalent(to: rhs.lastUpdated))
    }
}

extension Date {
    func isStringEquivalent(to other: Date) -> Bool {
        return stringEquivalentDate == other.stringEquivalentDate
    }
}
