//
//  FlagMaintainingMock.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
@testable import LaunchDarkly

final class FlagMaintainingMock: FlagMaintaining {
    struct Constants {
        static let updateDictionaryExtraKey = "FlagMaintainingMock.UpdateDictionary.extraKey"
        static let updateDictionaryExtraValue = "FlagMaintainingMock.UpdateDictionary.extraValue"
    }

    let innerStore: FlagStore

    init() {
        innerStore = FlagStore()
    }

    init(flags: [LDFlagKey: FeatureFlag]) {
        innerStore = FlagStore(featureFlags: flags)
    }

    var featureFlags: [LDFlagKey: FeatureFlag] {
        innerStore.featureFlags
    }

    var replaceStoreCallCount = 0
    var replaceStoreReceivedArguments: (newFlags: [LDFlagKey: Any], completion: CompletionClosure?)?
    func replaceStore(newFlags: [LDFlagKey: Any], completion: CompletionClosure?) {
        replaceStoreCallCount += 1
        replaceStoreReceivedArguments = (newFlags: newFlags, completion: completion)
        innerStore.replaceStore(newFlags: newFlags, completion: completion)
    }

    var updateStoreCallCount = 0
    var updateStoreReceivedArguments: (updateDictionary: [String: Any], completion: CompletionClosure?)?
    func updateStore(updateDictionary: [String: Any], completion: CompletionClosure?) {
        updateStoreCallCount += 1
        updateStoreReceivedArguments = (updateDictionary: updateDictionary, completion: completion)
        innerStore.updateStore(updateDictionary: updateDictionary, completion: completion)
    }

    var deleteFlagCallCount = 0
    var deleteFlagReceivedArguments: (deleteDictionary: [String: Any], completion: CompletionClosure?)?
    func deleteFlag(deleteDictionary: [String: Any], completion: CompletionClosure?) {
        deleteFlagCallCount += 1
        deleteFlagReceivedArguments = (deleteDictionary: deleteDictionary, completion: completion)
        innerStore.deleteFlag(deleteDictionary: deleteDictionary, completion: completion)
    }

    func featureFlag(for flagKey: LDFlagKey) -> FeatureFlag? {
        innerStore.featureFlag(for: flagKey)
    }

    func variation<T: LDFlagValueConvertible>(forKey key: String, defaultValue: T) -> T {
        innerStore.variation(forKey: key, defaultValue: defaultValue)
    }

    static func stubPatchDictionary(key: LDFlagKey?, value: Any?, variation: Int?, version: Int?, includeExtraKey: Bool = false) -> [String: Any] {
        var updateDictionary = [String: Any]()
        if let key = key {
            updateDictionary[FlagStore.Keys.flagKey] = key
        }
        if let value = value {
            updateDictionary[FeatureFlag.CodingKeys.value.rawValue] = value
        }
        if let variation = variation {
            updateDictionary[FeatureFlag.CodingKeys.variation.rawValue] = variation
        }
        if let version = version {
            updateDictionary[FeatureFlag.CodingKeys.version.rawValue] = version
        }
        if includeExtraKey {
            updateDictionary[Constants.updateDictionaryExtraKey] = Constants.updateDictionaryExtraValue
        }
        return updateDictionary
    }

    static func stubDeleteDictionary(key: LDFlagKey?, version: Int?) -> [String: Any] {
        var deleteDictionary = [String: Any]()
        if let key = key {
            deleteDictionary[FlagStore.Keys.flagKey] = key
        }
        if let version = version {
            deleteDictionary[FeatureFlag.CodingKeys.version.rawValue] = version
        }
        return deleteDictionary
    }

    static func stubFlags(includeNullValue: Bool = true, includeVersions: Bool = true) -> [String: FeatureFlag] {
        var flags = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: includeNullValue, includeVersions: includeVersions)
        flags["userKey"] = FeatureFlag(flagKey: "userKey",
                                       value: UUID().uuidString,
                                       variation: DarklyServiceMock.Constants.variation,
                                       version: includeVersions ? DarklyServiceMock.Constants.version : nil,
                                       flagVersion: DarklyServiceMock.Constants.flagVersion,
                                       trackEvents: true,
                                       debugEventsUntilDate: Date().addingTimeInterval(30.0),
                                       reason: DarklyServiceMock.Constants.reason,
                                       trackReason: false)
        return flags
    }
}
