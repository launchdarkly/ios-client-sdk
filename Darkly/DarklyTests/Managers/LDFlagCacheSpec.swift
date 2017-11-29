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
    override func spec() {
        var subject: LDFlagCache!
        var mockStore: KeyedValueStoringMock!
        beforeEach {
            mockStore = KeyedValueStoringMock()
            subject = LDFlagCache(keyedValueStore: mockStore)
        }

        describe("store and retrieve flags using user defaults") {
            var userStub: LDUser!
            var retrievedFlags: [String: Any]?
            beforeEach {
                userStub = LDUser.stub()
                subject = LDFlagCache(keyedValueStore: UserDefaults.standard)
                subject.storeFlags(for: userStub)

                retrievedFlags = subject.retrieveFlags(for: userStub)
            }
            it("retrieves flags that have matching key") {
                expect(retrievedFlags == userStub.flagStore.featureFlags).to(beTrue())
            }
            afterEach {
                subject.keyedValueStoreForTesting.removeObject(forKey: LDFlagCache.flagCacheKey)
            }
        }

        describe("convert user cache to flag cache") {
            var userStub: LDUser!
            beforeEach {
                userStub = LDUser.stub()
            }
            context("when the user is stored as a dictionary") {
                beforeEach {
                    mockStore.storeUserAsDictionary(user: userStub)

                    subject.convertUserCacheToFlagCache()
                }
                it("stores the user's flags") {
                    expect(mockStore.lastUpdated(for: userStub)).toNot(beNil())
                    expect(mockStore.flags(for: userStub)).toNot(beNil())
                    guard let userFlags = mockStore.flags(for: userStub) else { return }
                    expect(userFlags == userStub!.flagStore.featureFlags).to(beTrue())
                }
            }
            context("when the user is stored as data") {
                beforeEach {
                    mockStore.storeUserAsData(user: userStub)

                    subject.convertUserCacheToFlagCache()
                }
                it("stores the user's flags") {
                    expect(mockStore.lastUpdated(for: userStub)).toNot(beNil())
                    expect(mockStore.flags(for: userStub)).toNot(beNil())
                    guard let userFlags = mockStore.flags(for: userStub) else { return }
                    expect(userFlags == userStub!.flagStore.featureFlags).to(beTrue())
                }
            }
        }

        describe("retrieveLatest") {
            var retrievedFlags: [String: Any]?
            context("when there are no cached flags") {
                beforeEach {
                    retrievedFlags = subject.retrieveLatest()
                }
                it("returns nil") {
                    expect(retrievedFlags).to(beNil())
                }
            }
            context("when there are cached flags") {
                var latestFlags: [String: Any]?
                beforeEach {
                    let userStubs = mockStore.stubAndStoreUserFlags(count: 3)
                    latestFlags = userStubs.last?.flagStore.featureFlags

                    retrievedFlags = subject.retrieveLatest()
                }
                it("retrieves the flags with the latest last updated time") {
                    expect(retrievedFlags == latestFlags).to(beTrue())
                }
            }
        }

        describe("retrieve flags") {
            context("when flag store is full and an older flag set has been removed") {
                var userStubs: [LDUser]!
                var retrievedFlags: [String: Any]?
                beforeEach {
                    userStubs = [LDUser.stub()] + mockStore.stubAndStoreUserFlags(count: subject.maxCachedValues)
                }
                it("retrieves the flags present in the flag store") {
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

        describe("store flags") {
            context("when the flag store is full") {
                var userStubs: [LDUser]!
                var storedFlags: [String: Any]?
                beforeEach {
                    userStubs = mockStore.stubAndStoreUserFlags(count: subject.maxCachedValues) + [LDUser.stub()]

                    subject.storeFlags(for: userStubs.last!)
                }
                it("retrieves the flags present in the flag store") {
                    for index in 0..<userStubs.count {
                        storedFlags = mockStore.flags(for: userStubs![index])
                        if index == 0 {
                            expect(storedFlags).to(beNil())
                        }
                        else {
                            expect(storedFlags == userStubs[index].flagStore.featureFlags).to(beTrue())
                        }
                    }
                }
            }
        }
    }
}

extension LDFlagCache {
    var keyedValueStoreMock: KeyedValueStoringMock? { return keyedValueStoreForTesting as? KeyedValueStoringMock }
}

extension KeyedValueStoringMock {
    func stubAndStoreUserFlags(count: Int) -> [LDUser] {
        var userStubs = [LDUser]()
        //swiftlint:disable:next empty_count
        guard count > 0 else { return userStubs }
        while userStubs.count < count { userStubs.append(LDUser.stub()) }
        var cachedFlags = [String: Any]()
        userStubs.forEach { (user) in cachedFlags[user.key] = CachedFlags(user: user).dictionaryValue }
        dictionaryReturnValue = cachedFlags
        return userStubs
    }

    func storeUserAsDictionary(user: LDUser) {
        let userDictionaries = [user.key: user.jsonDictionaryWithConfig]
        dictionaryReturnValue = userDictionaries
    }

    func storeUserAsData(user: LDUser) {
        let userData = [user.key: NSKeyedArchiver.archivedData(withRootObject: LDUserWrapper(user: user))]
        dictionaryReturnValue = userData
    }

    func lastUpdated(for user: LDUser) -> Date? {
        return cachedFlags(for: user)?.lastUpdated
    }

    func flags(for user: LDUser) -> [String: Any]? {
        return cachedFlags(for: user)?.flags
    }

    private func cachedFlags(for user: LDUser) -> CachedFlags? {
        guard let receivedArguments = setReceivedArguments, receivedArguments.forKey == LDFlagCache.flagCacheKey,
            let flagStore = receivedArguments.value as? [String: Any],
            let userFlagDictionary = flagStore[user.key] as? [String: Any]
        else { return nil }
        return CachedFlags(dictionary: userFlagDictionary)
    }
}

extension Dictionary where Key == String, Value == LDUser {
    fileprivate mutating func removeOldest() {
        guard !self.isEmpty else { return }
        guard let oldestPair = self.max(by: { (pair1, pair2) -> Bool in pair1.value.lastUpdated > pair2.value.lastUpdated }) else { return }
        self.removeValue(forKey: oldestPair.key)
    }
}
