//
//  FlagMaintainingMock.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 11/20/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation
@testable import Darkly

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

    func variation<T: LDFlagValueConvertible>(forKey key: String, fallback: T) -> T {
        return featureFlags[key]?.value as? T ?? fallback
    }

    func variationAndSource<T: LDFlagValueConvertible>(forKey key: String, fallback: T) -> (T, LDFlagValueSource) {
        guard let value = featureFlags[key]?.value as? T else { return (fallback, .fallback) }
        return (value, .server)
    }

    static func stubPatchDictionary(key: LDFlagKey?, value: Any?, version: Int?, includeExtraKey: Bool = false) -> [String: Any] {
        var updateDictionary = [String: Any]()
        if let key = key { updateDictionary[FlagStore.Keys.flagKey] = key }
        if let value = value { updateDictionary[FeatureFlag.CodingKeys.value.rawValue] = value }
        if let version = version { updateDictionary[FeatureFlag.CodingKeys.version.rawValue] = version }
        if includeExtraKey { updateDictionary[Constants.updateDictionaryExtraKey] = Constants.updateDictionaryExtraValue }
        return updateDictionary
    }

    static func stubDeleteDictionary(key: LDFlagKey?, version: Int?) -> [String: Any] {
        var deleteDictionary = [String: Any]()
        if let key = key { deleteDictionary[FlagStore.Keys.flagKey] = key }
        if let version = version { deleteDictionary[FeatureFlag.CodingKeys.version.rawValue] = version }
        return deleteDictionary
    }
}
