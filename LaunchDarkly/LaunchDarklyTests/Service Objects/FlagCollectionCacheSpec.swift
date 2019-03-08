//
//  FlagCollectionCacheSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 12/7/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
import Foundation
@testable import LaunchDarkly

final class FlagCollectionCacheSpec: QuickSpec {
    override func spec() {
        var subject: FlagCollectionCache!
        var mockKeyStore: KeyedValueCachingMock!
        beforeEach {
            mockKeyStore = KeyedValueCachingMock()

            subject = FlagCollectionCache(keyStore: mockKeyStore)
        }

        describe("init") {
            context("without specifying max cached values") {
                it("sets the max cached values to the default") {
                    expect(subject.maxCachedValues) == FlagCollectionCache.Constants.maxCachedValues
                }
            }
            context("specifying max cached values") {
                beforeEach {
                    subject = FlagCollectionCache(keyStore: mockKeyStore, maxCachedValues: FlagCollectionCache.Constants.maxCachedValues + 1)
                }
                it("sets the max cached values to the specified value") {
                    expect(subject.maxCachedValues) == FlagCollectionCache.Constants.maxCachedValues + 1
                }
            }
        }

        describe("retrieve flags") {
            var userStubs: [LDUser]!
            var userFlags: [String: CacheableUserFlags]!
            var returnedFlags: [String: CacheableUserFlags]!
            context("when the keystore doesn't contain the cached flag key") {
                beforeEach {
                    returnedFlags = subject.retrieveFlags()
                }
                it("asks the key store for flags") {
                    expect(mockKeyStore.dictionaryReceivedForKey) == FlagCollectionCache.flagCacheKey
                }
                it("returns an empty dictionary") {
                    expect(returnedFlags.isEmpty).to(beTrue())
                }
            }
            context("when no flags exist in the keystore") {
                beforeEach {
                    userStubs = mockKeyStore.stubAndStoreUserFlags(count: 0)
                    userFlags = userStubs.userFlags

                    returnedFlags = subject.retrieveFlags()
                }
                it("asks the key store for flags") {
                    expect(mockKeyStore.dictionaryReceivedForKey) == FlagCollectionCache.flagCacheKey
                }
                it("returns an empty dictionary") {
                    expect(returnedFlags.isEmpty).to(beTrue())
                }
            }
            context("when 1 user's flags exist in the keystore") {
                beforeEach {
                    userStubs = mockKeyStore.stubAndStoreUserFlags(count: 1)
                    userFlags = userStubs.userFlags

                    returnedFlags = subject.retrieveFlags()
                }
                it("asks the key store for flags") {
                    expect(mockKeyStore.dictionaryReceivedForKey) == FlagCollectionCache.flagCacheKey
                }
                it("returns a dictionary containing the user flags") {
                    expect(returnedFlags.isEmpty).to(beFalse())
                    expect(returnedFlags.count) == userStubs.count
                    expect(returnedFlags) == userFlags
                }
            }
            context("when maxCachedValues flags exist in the keystore") {
                beforeEach {
                    userStubs = mockKeyStore.stubAndStoreUserFlags(count: subject.maxCachedValues)
                    userFlags = userStubs.userFlags

                    returnedFlags = subject.retrieveFlags()
                }
                it("asks the key store for flags") {
                    expect(mockKeyStore.dictionaryReceivedForKey) == FlagCollectionCache.flagCacheKey
                }
                it("returns a dictionary containing the user flags") {
                    expect(returnedFlags.isEmpty).to(beFalse())
                    expect(returnedFlags.count) == userStubs.count
                    expect(returnedFlags) == userFlags
                }
            }
        }

        describe("store flags") {
            var userStubs: [LDUser]!
            var userFlags: [String: CacheableUserFlags]!
            context("when the keystore doesn't contain the cached flag key") {
                var userFlagDictionaries: [String: Any]!
                beforeEach {
                    userStubs = LDUser.stubUsers(subject.maxCachedValues)
                    userFlags = userStubs.userFlags
                    userFlagDictionaries = userStubs.userFlagDictionaries

                    subject.storeFlags(userFlags)
                }
                it("sets flags into the keystore") {
                    expect(mockKeyStore.setCallCount) == 1
                    expect(mockKeyStore.setReceivedArguments?.forKey) == FlagCollectionCache.flagCacheKey
                    expect(mockKeyStore.setReceivedArguments?.value as? [String: Any]).toNot(beNil())
                    guard let receivedFlagDictionaries = mockKeyStore.setReceivedArguments?.value as? [String: Any]
                    else {
                        return
                    }
                    expect(receivedFlagDictionaries == userFlagDictionaries).to(beTrue())
                }
            }
            context("when no flags exist in the keystore") {
                var userFlagDictionaries: [String: Any]!
                beforeEach {
                    userStubs = LDUser.stubUsers(subject.maxCachedValues)
                    userFlags = userStubs.userFlags
                    userFlagDictionaries = userStubs.userFlagDictionaries

                    mockKeyStore.dictionaryReturnValue = [:]

                    subject.storeFlags(userFlags)
                }
                it("sets flags into the keystore") {
                    expect(mockKeyStore.setCallCount) == 1
                    expect(mockKeyStore.setReceivedArguments?.forKey) == FlagCollectionCache.flagCacheKey
                    expect(mockKeyStore.setReceivedArguments?.value as? [String: Any]).toNot(beNil())
                    guard let receivedFlagDictionaries = mockKeyStore.setReceivedArguments?.value as? [String: Any]
                    else {
                        return
                    }
                    expect(receivedFlagDictionaries == userFlagDictionaries).to(beTrue())
                }
            }
            context("when 1 user's flags exist in the keystore") {
                var userFlagDictionaries: [String: Any]!
                beforeEach {
                    userStubs = mockKeyStore.stubAndStoreUserFlags(count: 1) + LDUser.stubUsers(1)
                    userFlags = userStubs.userFlags
                    userFlagDictionaries = userStubs.userFlagDictionaries

                    subject.storeFlags(userFlags)
                }
                it("sets flags into the keystore") {
                    expect(mockKeyStore.setCallCount) == 1
                    expect(mockKeyStore.setReceivedArguments?.forKey) == FlagCollectionCache.flagCacheKey
                    expect(mockKeyStore.setReceivedArguments?.value as? [String: Any]).toNot(beNil())
                    guard let receivedFlagDictionaries = mockKeyStore.setReceivedArguments?.value as? [String: Any]
                    else {
                        return
                    }
                    expect(receivedFlagDictionaries == userFlagDictionaries).to(beTrue())
                }
            }
            context("when maxCachedValues-1 flags exist in the keystore") {
                var userFlagDictionaries: [String: Any]!
                beforeEach {
                    userStubs = mockKeyStore.stubAndStoreUserFlags(count: subject.maxCachedValues - 1) + LDUser.stubUsers(1)
                    userFlags = userStubs.userFlags
                    userFlagDictionaries = userStubs.userFlagDictionaries

                    subject.storeFlags(userFlags)
                }
                it("sets flags into the keystore") {
                    expect(mockKeyStore.setCallCount) == 1
                    expect(mockKeyStore.setReceivedArguments?.forKey) == FlagCollectionCache.flagCacheKey
                    expect(mockKeyStore.setReceivedArguments?.value as? [String: Any]).toNot(beNil())
                    guard let receivedFlagDictionaries = mockKeyStore.setReceivedArguments?.value as? [String: Any]
                    else {
                        return
                    }
                    expect(receivedFlagDictionaries == userFlagDictionaries).to(beTrue())
                }
            }
            context("when maxCachedValues flags exist in the keystore") {
                var userFlagDictionaries: [String: Any]!
                beforeEach {
                    userStubs = mockKeyStore.stubAndStoreUserFlags(count: subject.maxCachedValues) + LDUser.stubUsers(1)
                    userFlags = userStubs.userFlags

                    _ = userStubs.remove(at: 0)
                    userFlagDictionaries = userStubs.userFlagDictionaries

                    subject.storeFlags(userFlags)
                }
                it("sets flags into the keystore") {
                    expect(mockKeyStore.setCallCount) == 1
                    expect(mockKeyStore.setReceivedArguments?.forKey) == FlagCollectionCache.flagCacheKey
                    expect(mockKeyStore.setReceivedArguments?.value as? [String: Any]).toNot(beNil())
                    guard let receivedFlagDictionaries = mockKeyStore.setReceivedArguments?.value as? [String: Any]
                    else {
                        return
                    }
                    expect(receivedFlagDictionaries == userFlagDictionaries).to(beTrue())
                }
            }
        }
    }
}

extension KeyedValueCachingMock {
    func stubAndStoreUserFlags(count: Int) -> [LDUser] {
        let userStubs = LDUser.stubUsers(count)
        var cachedFlags = [String: [String: Any]]()
        userStubs.forEach { (user) in
            cachedFlags[user.key] = CacheableUserFlags(user: user).dictionaryValue
        }
        dictionaryReturnValue = cachedFlags
        return userStubs
    }
}
