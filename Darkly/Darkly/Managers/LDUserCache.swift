//
//  LDUserCache.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/24/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

final class LDUserCache {
    struct Constants {
        public static let maxUsers = 5
    }

    struct Keys {
        fileprivate static let cachedUsers = "ldUserModelDictionary"
    }

    let maxUsers: Int

    init(maxUsers: Int = Constants.maxUsers) {
        self.maxUsers = maxUsers
    }

    func store(user: LDUser) {
        var users = cachedUsers
        users[user.key] = user
        cache(users: users)
    }
    
    func retrieve(userKey: String) -> LDUser? {
        return cachedUsers[userKey]
    }
    
    func retrieveLatest() -> LDUser? {
        let users = cachedUsers
        guard !users.isEmpty else { return nil }
        return users.max(by: { (pair1, pair2) -> Bool in pair1.value.lastUpdated < pair2.value.lastUpdated })?.value
    }

    private var cachedUsers: [String: LDUser] {
        guard let userCache = UserDefaults.standard.object(forKey: Keys.cachedUsers) as? [String: Any]
        else { return [:] }

        return Dictionary(uniqueKeysWithValues: userCache.map { (keyObjectPair) in (keyObjectPair.key, LDUser(userObject: keyObjectPair.value, usingKeyIfMissing: keyObjectPair.key)) })
    }

    private func cache(users: [String: LDUser]) {
        var users = users
        while users.count > maxUsers { users.removeOldest() }
        UserDefaults.standard.set(users.mapValues { (user) in user.jsonDictionaryWithConfig }, forKey: Keys.cachedUsers)
        UserDefaults.standard.synchronize()
    }
}

extension LDUser {
    fileprivate init(userObject: Any, usingKeyIfMissing key: String) {
        self = LDUser(dataObject: userObject) ?? LDUser(dictionaryObject: userObject) ?? LDUser(key: key)
    }

    private init?(dictionaryObject: Any) {
        guard let userDictionary = dictionaryObject as? [String: Any]
        else { return nil }
        self = LDUser(jsonDictionary: userDictionary)
    }

    private init?(dataObject: Any) {
        guard let userData = dataObject as? Data,
            let wrapper = NSKeyedUnarchiver.unarchiveObject(with: userData) as? LDUserWrapper
        else { return nil }
        self = wrapper.wrapped
    }
}

extension Dictionary where Key == String, Value == LDUser {
    fileprivate mutating func removeOldest() {
        guard !self.isEmpty else { return }
        guard let oldestPair = self.max(by: { (pair1, pair2) -> Bool in pair1.value.lastUpdated > pair2.value.lastUpdated }) else { return }
        self.removeValue(forKey: oldestPair.key)
    }
}

#if TESTING
extension LDUserCache {
    func clearAllUsersForTesting() {
        UserDefaults.standard.set(nil, forKey: Keys.cachedUsers)
        UserDefaults.standard.synchronize()
    }

    func storeUserAsDataForTesting(user: LDUser) {
        var users = cachedUsers
        while users.count > maxUsers { users.removeOldest() }
        var usersWithData: [String: Any] = users.mapValues { (user) in user.jsonDictionaryWithConfig }
        usersWithData[user.key] = NSKeyedArchiver.archivedData(withRootObject: LDUserWrapper(user: user))
        UserDefaults.standard.set(usersWithData, forKey: Keys.cachedUsers)
        UserDefaults.standard.synchronize()
    }
}
#endif
