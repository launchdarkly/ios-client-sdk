//
//  UserCacheConverter.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 12/6/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

protocol UserCacheConverting {
    func convertUserCacheToFlagCache()
}

final class UserCacheConverter: UserCacheConverting {
    private let store: KeyedValueCaching

    init(store: KeyedValueCaching) {
        self.store = store
    }

    func convertUserCacheToFlagCache() {
        //        let userCache = cachedUsers
        //        guard !userCache.isEmpty else { return }
        //        keyedValueStore.removeObject(forKey: Keys.cachedUsers)
        //        let flagCache = userCache.mapValues { (user) in CachedFlags(user: user).dictionaryValue }
        //        keyedValueStore.set(flagCache, forKey: Keys.cachedFlags)
    }
}

extension LDUser {
    fileprivate init(userObject: Any, usingKeyIfMissing key: String) {
        self = LDUser(dataObject: userObject) ?? LDUser(dictionaryObject: userObject) ?? LDUser(key: key)
    }

    private init?(dictionaryObject: Any) {
        guard let userDictionary = dictionaryObject as? [String: Any] else { return nil }
        self = LDUser(jsonDictionary: userDictionary)
    }

    private init?(dataObject: Any) {
        guard let userData = dataObject as? Data,
            let wrapper = NSKeyedUnarchiver.unarchiveObject(with: userData) as? LDUserWrapper
            else { return nil }
        self = wrapper.wrapped
    }
}
