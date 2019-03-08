//
//  KeyedValueCacheSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 12/7/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
import Foundation
@testable import LaunchDarkly

final class KeyedValueCacheSpec: QuickSpec {
    struct Keys {
        fileprivate static let cachedUsers = "ldUserModelDictionary"
        fileprivate static let cachedFlags = "LDFlagCacheDictionary"
    }

    override func spec() {
        var subject: KeyedValueCaching!

        beforeSuite {
            UserDefaults.standard.removeObject(forKey: Keys.cachedUsers)
            UserDefaults.standard.removeObject(forKey: Keys.cachedFlags)
        }

        beforeEach {
            subject = UserDefaults.standard
            subject.removeObject(forKey: FlagCollectionCache.flagCacheKey)
        }

        describe("store and retrieve flags using user defaults") {
            var userStubs: [LDUser]!
            var userFlags: [String: Any]!
            var retrievedFlags: [String: Any]?
            beforeEach {
                userStubs = LDUser.stubUsers(FlagCollectionCache.Constants.maxCachedValues)
                userFlags = userStubs.userFlagDictionaries

                subject.set(userFlags, forKey: FlagCollectionCache.flagCacheKey)

                retrievedFlags = subject.dictionary(forKey: FlagCollectionCache.flagCacheKey)
            }
            it("retrieves matching flags") {
                expect(retrievedFlags == userFlags).to(beTrue())
            }
        }

        afterEach {
            subject.removeObject(forKey: FlagCollectionCache.flagCacheKey)
        }
    }
}
