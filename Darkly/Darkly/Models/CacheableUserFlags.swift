//
//  CacheableUserFlags.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 12/6/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

struct CacheableUserFlags {
    enum CodingKeys: String, CodingKey {
        case flags, lastUpdated
    }

    let flags: [String: FeatureFlag]
    let lastUpdated: Date

    init(flags: [String: FeatureFlag], lastUpdated: Date) {
        self.flags = flags
        self.lastUpdated = lastUpdated
    }

    init(user: LDUser) {
        self.init(flags: user.flagStore.featureFlags, lastUpdated: user.lastUpdated)
    }

    var dictionaryValue: [String: Any] {
        return [CodingKeys.flags.rawValue: flags.dictionaryValue.withNullValuesRemoved, CodingKeys.lastUpdated.rawValue: lastUpdated.stringValue]
    }

    init?(dictionary: [String: Any]) {
        guard let flags = (dictionary[CodingKeys.flags.rawValue] as? [String: Any])?.flagCollection
            else { return nil }

        self.init(flags: flags, lastUpdated: (dictionary[CodingKeys.lastUpdated.rawValue] as? String)?.dateValue ?? Date())
    }

    init?(object: Any) {
        guard let dictionary = object as? [String: Any],
            let flags = CacheableUserFlags(dictionary: dictionary)
            else { return nil }

        self = flags
    }
}

extension CacheableUserFlags: Equatable {
    static func == (lhs: CacheableUserFlags, rhs: CacheableUserFlags) -> Bool {
        return lhs.flags == rhs.flags && (lhs.lastUpdated == rhs.lastUpdated || lhs.lastUpdated.isStringEquivalent(to: rhs.lastUpdated))
    }
}

extension Date {
    func isStringEquivalent(to other: Date) -> Bool { return stringEquivalentDate == other.stringEquivalentDate }
}
