//
//  UserCacheConverter.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 12/6/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

protocol UserCacheConverting {
    func convertUserCacheToFlagCache()
}

final class UserCacheConverter: UserCacheConverting {
    struct Keys {
        static let cachedUsers = "ldUserModelDictionary"
    }

    private let keyStore: KeyedValueCaching
    private let flagCollectionCache: FlagCollectionCaching

    init(keyStore: KeyedValueCaching, flagCollectionCache: FlagCollectionCaching) {
        self.keyStore = keyStore
        self.flagCollectionCache = flagCollectionCache
    }

    func convertUserCacheToFlagCache() {
        guard let userCache = cachedUsers, !userCache.isEmpty
        else {
            return
        }
        keyStore.removeObject(forKey: Keys.cachedUsers)

        let userFlags = userCache.mapValues { (user) in
            CacheableUserFlags(user: user)
        }
        flagCollectionCache.storeFlags(userFlags)
    }

    private var cachedUserDictionaries: [String: Any]? {
        return keyStore.dictionary(forKey: Keys.cachedUsers)
    }
    private var cachedUsers: [String: LDUser]? {
        guard let userCache = cachedUserDictionaries
        else {
            return nil
        }
        return Dictionary(uniqueKeysWithValues: userCache.map { (keyObjectPair) in
            (keyObjectPair.key, LDUser(userObject: keyObjectPair.value, usingKeyIfMissing: keyObjectPair.key))
        })
    }
}

extension LDUser {
    fileprivate init(userObject: Any, usingKeyIfMissing key: String) {
        self = LDUser(dataObject: userObject) ?? LDUser(object: userObject) ?? LDUser(key: key)
    }

    private init?(dataObject: Any) {
        guard let userData = dataObject as? Data,
            let wrapper = NSKeyedUnarchiver.unarchiveObject(with: userData) as? LDUserWrapper
        else {
            return nil
        }
        self = wrapper.wrapped
    }
}
