//
//  LDFlagCacheSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 11/6/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
import Foundation
@testable import Darkly

final class LDFlagCacheSpec: QuickSpec {
    //swiftlint:disable:next function_body_length
    override func spec() {
        var subject: LDFlagCache!
        beforeEach {
            subject = LDFlagCache()
            subject.clearAllFlagsForTesting()
            subject.clearAllUsersForTesting()
        }

        describe("init") {
            context("with max cached values") {
                var maxCachedValues: Int!
                beforeEach {
                    maxCachedValues = LDFlagCache.Constants.maxCachedValues + 1

                    subject = LDFlagCache(maxCachedValues: maxCachedValues)
                }
                it("creates a user cache with max cached values set to the parameter value") {
                    expect(subject.maxCachedValues) == maxCachedValues
                }
            }
            context("without max cached values") {
                beforeEach {
                    subject = LDFlagCache()
                }
                it("creates a user cache with max cached values set to the default value") {
                    expect(subject.maxCachedValues) == LDFlagCache.Constants.maxCachedValues
                }
            }
        }

        describe("store and retrieve flags") {
            var userStub: LDUser!
            var retrievedFlags: [String: Any]?
            beforeEach {
                userStub = LDUser.stub()
                subject.storeFlags(for: userStub)

                retrievedFlags = subject.retrieveFlags(for: userStub)
            }
            it("retrieves flags that have matching key") {
                expect(retrievedFlags == userStub.flagStore.featureFlags).to(beTrue())
            }
        }

        describe("store user as dictionary and retrieve flags") {
            var userStub: LDUser!
            var retrievedFlags: [String: Any]?
            beforeEach {
                userStub = LDUser.stub()
                subject.storeUserAsDictionaryForTesting(user: userStub)
                subject.convertUserCacheToFlagCache()

                retrievedFlags = subject.retrieveFlags(for: userStub)
            }
            it("retrieves flags that have matching key") {
                expect(retrievedFlags == userStub.flagStore.featureFlags).to(beTrue())
            }
        }

        describe("store user as data and retrieve flags") {
            var userStub: LDUser!
            var retrievedFlags: [String: Any]?
            beforeEach {
                userStub = LDUser.stub()
                subject.storeUserAsDataForTesting(user: userStub)
                subject.convertUserCacheToFlagCache()

                retrievedFlags = subject.retrieveFlags(for: userStub)
            }
            it("retrieves flags that have matching key") {
                expect(retrievedFlags == userStub.flagStore.featureFlags).to(beTrue())
            }
        }

        describe("retrieveLatest") {
            var retrievedFlags: [String: Any]?
            context("when there are no cached users") {
                beforeEach {
                    subject = LDFlagCache()
                    subject.clearAllUsersForTesting()
                    retrievedFlags = subject.retrieveLatest()
                }
                it("returns nil") {
                    expect(retrievedFlags).to(beNil())
                }
            }
            context("when there are cached users") {
                var latestFlags: [String: Any]?
                beforeEach {
                    let userStubs = subject.stubAndStoreUsers(count: 3)
                    latestFlags = userStubs.last?.flagStore.featureFlags

                    retrievedFlags = subject.retrieveLatest()
                }
                it("retrieves the flags with the latest last updated time") {
                    expect(retrievedFlags == latestFlags).to(beTrue())
                }
            }
        }

        describe("store flags") {
            context("when max flags already stored") {
                var userStubs: [LDUser]!
                var retrievedFlags: [String: Any]?
                beforeEach {
                    userStubs = subject.stubAndStoreUsers(count: subject.maxCachedValues + 1)
                }
                it("stores the flags and removes the oldest user from the cache") {
                    for index in 0..<userStubs.count {
                        retrievedFlags = subject.retrieveFlags(for: userStubs[index])
                        if index == 0 {
                            expect(retrievedFlags).to(beNil())
                        }
                        else {
                            expect(retrievedFlags == userStubs[index].flagStore.featureFlags).to(beTrue())
                        }
                    }
                }
            }
        }
    }
}

extension LDFlagCache {
    func stubAndStoreUsers(count: Int) -> [LDUser] {
        var userStubs = [LDUser]()
        while userStubs.count < count {
            let newUser = LDUser.stub()
            userStubs.append(newUser)
            storeFlags(for: newUser)
        }
        return userStubs
    }

    func clearAllUsersForTesting() {
        UserDefaults.standard.removeObject(forKey: LDFlagCache.userCacheKey)
        UserDefaults.standard.synchronize()
        guard !cachedUsersForTesting.isEmpty else { return }
        //Sometimes removing Keys.cachedUsers doesn't actually work to clear the users for the test, so adding this gives another chance to get the users cleared for testing
        UserDefaults.standard.set([:], forKey: LDFlagCache.userCacheKey)
        UserDefaults.standard.synchronize()
        guard !cachedUsersForTesting.isEmpty else { return }
        //If we get here, not much else to do...the test will likely fail, but this will log that the users didn't get cleared
        print("LDFlagCache.clearAllUsersForTesting failed to clear the user cache")
    }

    func clearAllFlagsForTesting() {
        UserDefaults.standard.removeObject(forKey: LDFlagCache.flagCacheKey)
        UserDefaults.standard.synchronize()
    }

    func storeUserAsDictionaryForTesting(user: LDUser) {
        var users = cachedUsersForTesting
        while users.count > maxCachedValues { users.removeOldest() }
        var userDictionaries: [String: Any] = users.mapValues { (user) in user.jsonDictionaryWithConfig }
        userDictionaries[user.key] = user.jsonDictionaryWithConfig
        UserDefaults.standard.set(userDictionaries, forKey: LDFlagCache.userCacheKey)
        UserDefaults.standard.synchronize()
    }

    func storeUserAsDataForTesting(user: LDUser) {
        var users = cachedUsersForTesting
        while users.count > maxCachedValues { users.removeOldest() }
        var usersWithData: [String: Any] = users.mapValues { (user) in user.jsonDictionaryWithConfig }
        usersWithData[user.key] = NSKeyedArchiver.archivedData(withRootObject: LDUserWrapper(user: user))
        UserDefaults.standard.set(usersWithData, forKey: LDFlagCache.userCacheKey)
        UserDefaults.standard.synchronize()
    }

    func cache(usersForTesting users: [String: LDUser]) {
        var users = users
        while users.count > maxCachedValues { users.removeOldest() }
        UserDefaults.standard.set(users.mapValues { (user) in user.jsonDictionaryWithConfig }, forKey: LDFlagCache.userCacheKey)
        UserDefaults.standard.synchronize()
    }
}

extension Dictionary where Key == String, Value == LDUser {
    fileprivate mutating func removeOldest() {
        guard !self.isEmpty else { return }
        guard let oldestPair = self.max(by: { (pair1, pair2) -> Bool in pair1.value.lastUpdated > pair2.value.lastUpdated }) else { return }
        self.removeValue(forKey: oldestPair.key)
    }
}

extension LDUser {
    //swiftlint:disable:next cyclomatic_complexity
    fileprivate func matches(user otherUser: LDUser) -> ToMatchResult {
        var messages = [String]()
        if key != otherUser.key { messages.append("key equals \(key)") }
        if name != otherUser.name { messages.append("name equals \(name ?? "<nil>")") }
        if firstName != otherUser.firstName { messages.append("firstName equals \(firstName ?? "<nil>")") }
        if lastName != otherUser.lastName { messages.append("lastName equals \(lastName ?? "<nil>")") }
        if isAnonymous != otherUser.isAnonymous { messages.append("isAnonymous equals \(isAnonymous)") }
        if country != otherUser.country { messages.append("country equals \(country ?? "<nil>")") }
        if ipAddress != otherUser.ipAddress { messages.append("ipAddress equals \(ipAddress ?? "<nil>")") }
        if email != otherUser.email { messages.append("email equals \(email ?? "<nil>")") }
        if avatar != otherUser.avatar { messages.append("avatar equals \(avatar ?? "<nil>")") }
        if custom != otherUser.custom { messages.append("custom equals \(custom?.description ?? "<nil>")") }
        if device != otherUser.device { messages.append("device equals \(device ?? "<nil>")") }
        if operatingSystem != otherUser.operatingSystem { messages.append("operatingSystem equals \(operatingSystem ?? "<nil>")") }
        if lastUpdated.jsonDate != otherUser.lastUpdated.jsonDate { messages.append("lastUpdated equals \(lastUpdated.jsonDate)") }
        if flagStore.featureFlags != otherUser.flagStore.featureFlags { messages.append("featureFlags equals \(flagStore.featureFlags)") }

        return messages.isEmpty ? .matched : .failed(reason: messages.joined(separator: ", "))
    }
}
