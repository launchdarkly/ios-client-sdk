//
//  LDFlagCache.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 7/24/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

//sourcery: AutoMockable
protocol UserFlagCaching {
    func cacheFlags(for user: LDUser)
    //sourcery: DefaultReturnValue = nil
    func retrieveFlags(for user: LDUser) -> CacheableUserFlags?
}

final class UserFlagCache: UserFlagCaching {
    struct Constants {
        public static let maxCachedValues = 5
    }

    struct Keys {
        fileprivate static let cachedFlags = "LDFlagCacheDictionary"
    }

    private let flagCollectionStore: FlagCollectionCaching

    init(flagCollectionStore: FlagCollectionCaching) {
        self.flagCollectionStore = flagCollectionStore
    }

    func cacheFlags(for user: LDUser) {
        Log.debug(typeName(and: #function) + "user key: " + user.key)
        var flags = cachedFlags
        flags[user.key] = CacheableUserFlags(user: user)
        cache(flags: flags)
    }
    
    func retrieveFlags(for user: LDUser) -> CacheableUserFlags? {
        let userFlags = cachedFlags[user.key]
        Log.debug(typeName(and: #function) + (userFlags == nil ? "not found" : "found") + ". user key: " + user.key)
        return userFlags
    }
    
    private var cachedFlags: [String: CacheableUserFlags] {
        return flagCollectionStore.retrieveFlags()
    }

    private func cache(flags: [String: CacheableUserFlags]) {
        flagCollectionStore.storeFlags(flags)
    }
}

extension UserFlagCache: TypeIdentifying { }
