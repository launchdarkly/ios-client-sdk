//
//  FlagMaintainingMock.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 11/20/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
@testable import LaunchDarkly

extension FlagMaintainingMock {
    struct Constants {
        static let updateDictionaryExtraKey = "FlagMaintainingMock.UpdateDictionary.extraKey"
        static let updateDictionaryExtraValue = "FlagMaintainingMock.UpdateDictionary.extraValue"
    }

    convenience init(flags: [LDFlagKey: FeatureFlag]) {
        self.init()
        featureFlags = flags
        featureFlagsSetCount = 0
    }

    func featureFlag(for flagKey: LDFlagKey) -> FeatureFlag? {
        return featureFlags[flagKey]
    }

    func featureFlagAndSource(for flagKey: LDFlagKey) -> (FeatureFlag?, LDFlagValueSource?) {
        let featureFlag = featureFlags[flagKey]
        return (featureFlag, featureFlag == nil ? nil : flagValueSource)
    }

    func variation<T: LDFlagValueConvertible>(forKey key: String, fallback: T) -> T {
        return featureFlags[key]?.value as? T ?? fallback
    }

    func variationAndSource<T: LDFlagValueConvertible>(forKey key: String, fallback: T) -> (T, LDFlagValueSource) {
        guard let value = featureFlags[key]?.value as? T
        else {
            return (fallback, .fallback)
        }
        return (value, flagValueSource)
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
}
