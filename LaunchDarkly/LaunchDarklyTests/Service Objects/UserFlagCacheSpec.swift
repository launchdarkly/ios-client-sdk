//
//  LDFlagCacheSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 11/6/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
import Foundation
@testable import LaunchDarkly

final class UserFlagCacheSpec: QuickSpec {
    override func spec() {
        var subject: UserFlagCache!
        var mockFlagCollectionStore: FlagCollectionCachingMock!
        beforeEach {
            mockFlagCollectionStore = FlagCollectionCachingMock()
            mockFlagCollectionStore.retrieveFlagsReturnValue = [:]
            subject = UserFlagCache(flagCollectionStore: mockFlagCollectionStore)
        }

        describe("retrieve flags") {
            context("when the user flags exist in the flag collection store") {
                var mockUser: LDUser!
                var mockUserFlags: CacheableUserFlags!
                var retrievedFlags: CacheableUserFlags?
                beforeEach {
                    mockUser = LDUser.stub()
                    mockUserFlags = CacheableUserFlags(user: mockUser)
                    mockFlagCollectionStore.retrieveFlagsReturnValue = [mockUser.key: mockUserFlags]

                    retrievedFlags = subject.retrieveFlags(for: mockUser)
                }
                it("returns the user flags") {
                    expect(retrievedFlags) == mockUserFlags
                }
            }
            context("when the user flags do not exist in the flag collection store") {
                var mockUser: LDUser!
                var retrievedFlags: CacheableUserFlags?
                beforeEach {
                    mockUser = LDUser.stub()
                    retrievedFlags = subject.retrieveFlags(for: mockUser)
                }
                it("returns nil for user flags") {
                    expect(retrievedFlags).to(beNil())
                    expect(mockFlagCollectionStore.retrieveFlagsCallCount) == 1
                }
            }
        }

        describe("store flags") {
            var mockUser: LDUser!
            var userFlags: CacheableUserFlags!
            context("when the user flags are not already stored") {
                beforeEach {
                    mockUser = LDUser.stub()
                    userFlags = CacheableUserFlags(user: mockUser)

                    subject.cacheFlags(for: mockUser)
                }
                it("stores user flags") {
                    expect(mockFlagCollectionStore.storeFlagsReceivedFlags).toNot(beNil())
                    guard let storedCollection = mockFlagCollectionStore.storeFlagsReceivedFlags else {
                        return
                    }
                    expect(storedCollection[mockUser.key]).toNot(beNil())
                    guard let storedFlags = storedCollection[mockUser.key] else {
                        return
                    }
                    expect(storedFlags) == userFlags
                }
            }
            context("when the user flags are already stored") {
                var mockFlagStore: FlagMaintainingMock!
                var changedFlags: [LDFlagKey: FeatureFlag]!
                var changedUserFlags: CacheableUserFlags!
                beforeEach {
                    mockUser = mockFlagCollectionStore.stubAndStoreUserFlags(count: 1).first!
                    mockFlagStore = mockUser.flagStore as? FlagMaintainingMock

                    changedFlags = mockFlagStore.featureFlags
                    changedFlags["newKey"] = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
                    mockFlagStore.featureFlags = changedFlags!
                    changedUserFlags = CacheableUserFlags(user: mockUser)

                    subject.cacheFlags(for: mockUser)
                }
                it("stores user flags") {
                    expect(mockFlagCollectionStore.storeFlagsReceivedFlags).toNot(beNil())
                    guard let storedCollection = mockFlagCollectionStore.storeFlagsReceivedFlags else {
                        return
                    }
                    expect(storedCollection[mockUser.key]).toNot(beNil())
                    guard let storedFlags = storedCollection[mockUser.key] else {
                        return
                    }
                    expect(storedFlags) == changedUserFlags
                }
            }
        }
    }
}

extension FlagCollectionCachingMock {
    func stubAndStoreUserFlags(count: Int) -> [LDUser] {
        var userStubs = [LDUser]()
        //swiftlint:disable:next empty_count
        guard count > 0 else {
            return userStubs
        }
        while userStubs.count < count {
            userStubs.append(LDUser.stub())
        }
        var cachedFlags = [String: CacheableUserFlags]()
        userStubs.forEach { (user) in
            cachedFlags[user.key] = CacheableUserFlags(user: user)
        }
        retrieveFlagsReturnValue = cachedFlags
        return userStubs
    }
}

extension Dictionary where Key == String, Value == LDUser {
    fileprivate mutating func removeOldest() {
        guard !self.isEmpty
        else {
            return
        }
        guard let oldestPair = self.max(by: { (pair1, pair2) -> Bool in
            pair1.value.lastUpdated > pair2.value.lastUpdated })
        else {
            return
        }
        self.removeValue(forKey: oldestPair.key)
    }
}
