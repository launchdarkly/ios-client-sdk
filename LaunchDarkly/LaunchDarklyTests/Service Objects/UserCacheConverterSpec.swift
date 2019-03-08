//
//  UserCacheConverterSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 12/7/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
import Foundation
@testable import LaunchDarkly

final class UserCacheConverterSpec: QuickSpec {
    override func spec() {
        var subject: UserCacheConverter!
        var mockKeyStore: KeyedValueCachingMock!
        var mockFlagCollectionCache: FlagCollectionCachingMock!

        beforeEach {
            mockKeyStore = KeyedValueCachingMock()
            mockFlagCollectionCache = FlagCollectionCachingMock()
            subject = UserCacheConverter(keyStore: mockKeyStore, flagCollectionCache: mockFlagCollectionCache)
        }

        describe("convert user cache to flag cache") {
            var userStub: LDUser!
            var flagDictionary: [String: CacheableUserFlags]!

            beforeEach {
                userStub = LDUser.stub()
                flagDictionary = [userStub.key: CacheableUserFlags(user: userStub)]
            }

            context("when the user is stored as a dictionary") {
                beforeEach {
                    mockKeyStore.storeUserAsDictionary(user: userStub)

                    subject.convertUserCacheToFlagCache()
                }
                it("removes users from the keyStore") {
                    expect(mockKeyStore.removeObjectCallCount) == 1
                    expect(mockKeyStore.removeObjectReceivedForKey) == UserCacheConverter.Keys.cachedUsers
                }
                it("stores the users flags") {
                    expect(mockFlagCollectionCache.storeFlagsCallCount) == 1
                    expect(mockFlagCollectionCache.storeFlagsReceivedFlags).toNot(beNil())
                    guard let receivedFlagDictionaries = mockFlagCollectionCache.storeFlagsReceivedFlags
                    else {
                        return
                    }
                    expect(receivedFlagDictionaries.isEmpty).to(beFalse())
                    expect(receivedFlagDictionaries == flagDictionary).to(beTrue())
                }
            }
            context("when the user is stored as data") {
                beforeEach {
                    mockKeyStore.storeUserAsData(user: userStub)

                    subject.convertUserCacheToFlagCache()
                }
                it("removes users from the keyStore") {
                    expect(mockKeyStore.removeObjectCallCount) == 1
                    expect(mockKeyStore.removeObjectReceivedForKey) == UserCacheConverter.Keys.cachedUsers
                }
                it("stores the users flags") {
                    expect(mockFlagCollectionCache.storeFlagsCallCount) == 1
                    expect(mockFlagCollectionCache.storeFlagsReceivedFlags).toNot(beNil())
                    guard let receivedFlagDictionaries = mockFlagCollectionCache.storeFlagsReceivedFlags
                    else {
                        return
                    }
                    expect(receivedFlagDictionaries.isEmpty).to(beFalse())
                    expect(receivedFlagDictionaries == flagDictionary).to(beTrue())
                }
            }
        }
    }
}

extension KeyedValueCachingMock {
    func storeUserAsDictionary(user: LDUser) {
        let userDictionaries = [user.key: user.dictionaryValueWithAllAttributes(includeFlagConfig: true)]
        dictionaryReturnValue = userDictionaries
    }

    func storeUserAsData(user: LDUser) {
        let userData = [user.key: NSKeyedArchiver.archivedData(withRootObject: LDUserWrapper(user: user))]
        dictionaryReturnValue = userData
    }
}
