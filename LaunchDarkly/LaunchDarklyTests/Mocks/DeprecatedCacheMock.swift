//
//  DeprecatedCacheMock.swift
//  LaunchDarklyTests
//
//  Copyright © 2020 Catamorphic Co. All rights reserved.
//
import Foundation
@testable import LaunchDarkly

// MARK: - DeprecatedCacheMock
final class DeprecatedCacheMock: DeprecatedCache {

    // MARK: model
    var modelSetCount = 0
    var setModelCallback: (() -> Void)?
    // This may need to be updated when new cache versions are introduced
    var model: DeprecatedCacheModel = .version5 {
        didSet {
            modelSetCount += 1
            setModelCallback?()
        }
    }

    // MARK: cachedDataKey
    var cachedDataKeySetCount = 0
    var setCachedDataKeyCallback: (() -> Void)?
    var cachedDataKey: String = CacheConverter.CacheKeys.cachedDataKeyStub {
        didSet {
            cachedDataKeySetCount += 1
            setCachedDataKeyCallback?()
        }
    }

    // MARK: keyedValueCache
    var keyedValueCacheSetCount = 0
    var setKeyedValueCacheCallback: (() -> Void)?
    var keyedValueCache: KeyedValueCaching = KeyedValueCachingMock() {
        didSet {
            keyedValueCacheSetCount += 1
            setKeyedValueCacheCallback?()
        }
    }

    // MARK: retrieveFlags
    var retrieveFlagsCallCount = 0
    var retrieveFlagsCallback: (() -> Void)?
    var retrieveFlagsReceivedArguments: (userKey: UserKey, mobileKey: MobileKey)?
    var retrieveFlagsReturnValue: (featureFlags: [LDFlagKey: FeatureFlag]?, lastUpdated: Date?)!
    func retrieveFlags(for userKey: UserKey, and mobileKey: MobileKey) -> (featureFlags: [LDFlagKey: FeatureFlag]?, lastUpdated: Date?) {
        retrieveFlagsCallCount += 1
        retrieveFlagsReceivedArguments = (userKey: userKey, mobileKey: mobileKey)
        retrieveFlagsCallback?()
        return retrieveFlagsReturnValue
    }

    // MARK: userKeys
    var userKeysCallCount = 0
    var userKeysCallback: (() -> Void)?
    var userKeysReceivedArguments: (cachedUserData: [UserKey: [String: Any]], olderThan: Date)?
    var userKeysReturnValue: [UserKey]!
    func userKeys(from cachedUserData: [UserKey: [String: Any]], olderThan: Date) -> [UserKey] {
        userKeysCallCount += 1
        userKeysReceivedArguments = (cachedUserData: cachedUserData, olderThan: olderThan)
        userKeysCallback?()
        return userKeysReturnValue
    }

    // MARK: removeData
    var removeDataCallCount = 0
    var removeDataCallback: (() -> Void)?
    var removeDataReceivedExpirationDate: Date?
    func removeData(olderThan expirationDate: Date) {
        removeDataCallCount += 1
        removeDataReceivedExpirationDate = expirationDate
        removeDataCallback?()
    }
}
