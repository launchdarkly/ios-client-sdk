//
//  UserFlags.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 12/6/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

struct UserFlags {
    enum CodingKeys: String, CodingKey {
        case flags, lastUpdated
    }

    let flags: [String: Any]
    let lastUpdated: Date

    init(flags: [String: Any], lastUpdated: Date) {
        self.flags = flags
        self.lastUpdated = lastUpdated
    }

    init(user: LDUser) {
        self.init(flags: user.flagStore.featureFlags, lastUpdated: user.lastUpdated)
    }

    var dictionaryValue: [String: Any] {
        return [CodingKeys.flags.rawValue: flags, CodingKeys.lastUpdated.rawValue: lastUpdated]
    }

    init?(dictionary: [String: Any]) {
        guard let flags = dictionary[CodingKeys.flags.rawValue] as? [String: Any],
            let lastUpdated = dictionary[CodingKeys.lastUpdated.rawValue] as? Date
            else { return nil }
        self = UserFlags(flags: flags, lastUpdated: lastUpdated)
    }

    init?(object: Any) {
        guard let dictionary = object as? [String: Any],
            let flags = UserFlags(dictionary: dictionary)
            else { return nil }

        self = flags
    }
}

extension UserFlags: Equatable {
    static func == (lhs: UserFlags, rhs: UserFlags) -> Bool {
        return lhs.flags == rhs.flags && lhs.lastUpdated == rhs.lastUpdated
    }
}
