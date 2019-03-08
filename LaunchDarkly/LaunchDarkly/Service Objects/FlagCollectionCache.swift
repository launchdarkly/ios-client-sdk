//
//  FlagCollectionCache.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 12/6/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

//sourcery: AutoMockable
protocol FlagCollectionCaching {
    //Responsibility: store & retrieve flag collection using KeyedValueStoring
    //controls the number of user flag sets stored in the flag collection
    //sourcery: DefaultReturnValue = [:]
    func retrieveFlags() -> [String: CacheableUserFlags]
    func storeFlags(_ flags: [String: CacheableUserFlags])
}

final class FlagCollectionCache: FlagCollectionCaching {
    struct Constants {
        static let maxCachedValues = 5
    }

    struct Keys {
        fileprivate static let cachedFlags = "Darkly.FlagCacheDictionary"
    }

    private let keyStore: KeyedValueCaching
    let maxCachedValues: Int

    init(keyStore: KeyedValueCaching, maxCachedValues: Int = Constants.maxCachedValues) {
        self.keyStore = keyStore
        self.maxCachedValues = maxCachedValues
    }

    func retrieveFlags() -> [String: CacheableUserFlags] {
        return cachedUserFlags ?? [:]
    }

    func storeFlags(_ flags: [String: CacheableUserFlags]) {
        var flags = flags
        while flags.count > maxCachedValues {
            flags.removeOldest()
        }
        keyStore.set(flags.flagDictionaries, forKey: Keys.cachedFlags)
    }

    private var cachedFlagDictionaries: [String: Any]? {
        return keyStore.dictionary(forKey: Keys.cachedFlags)
    }
    private var cachedUserFlags: [String: CacheableUserFlags]? {
        return cachedFlagDictionaries?.compactMapValues { (flagDictionary) in
            return CacheableUserFlags(object: flagDictionary)
        }
    }
}

extension Dictionary where Key == String, Value == CacheableUserFlags {
    fileprivate mutating func removeOldest() {
        guard !self.isEmpty
        else {
            return
        }
        guard let oldestPair = self.max(by: { (pair1, pair2) -> Bool in pair1.value.lastUpdated > pair2.value.lastUpdated })
        else {
            return
        }
        Log.debug("FlagCollectionCache.storeFlags(flags:) " + "cache is full, removing: " + oldestPair.key)
        self.removeValue(forKey: oldestPair.key)
    }

    fileprivate var flagDictionaries: [String: Any] {
        return self.mapValues { (userFlags) in
            userFlags.dictionaryValue
        }
    }
}

extension FlagCollectionCache: TypeIdentifying { }

// MARK: - Test Support
#if DEBUG
    extension FlagCollectionCache {
        static var flagCacheKey: String {
            return Keys.cachedFlags
        }
    }
#endif
