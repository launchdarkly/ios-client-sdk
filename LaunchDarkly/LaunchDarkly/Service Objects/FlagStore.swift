//
//  FlagStore.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 9/20/17. JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

//sourcery: AutoMockable
protocol FlagMaintaining {
    var featureFlags: [LDFlagKey: FeatureFlag] { get }
    //sourcery: DefaultMockValue = .cache
    var flagValueSource: LDFlagValueSource { get }
    func replaceStore(newFlags: [LDFlagKey: Any]?, source: LDFlagValueSource, completion: CompletionClosure?)
    func updateStore(updateDictionary: [String: Any], source: LDFlagValueSource, completion: CompletionClosure?)
    func deleteFlag(deleteDictionary: [String: Any], completion: CompletionClosure?)

    //sourcery: NoMock
    func featureFlag(for flagKey: LDFlagKey) -> FeatureFlag?
    //sourcery: NoMock
    func featureFlagAndSource(for flagKey: LDFlagKey) -> (FeatureFlag?, LDFlagValueSource?)

    //sourcery: NoMock
    func variation<T: LDFlagValueConvertible>(forKey key: LDFlagKey, fallback: T) -> T
    //sourcery: NoMock
    func variationAndSource<T: LDFlagValueConvertible>(forKey key: LDFlagKey, fallback: T) -> (T, LDFlagValueSource)
}

final class FlagStore: FlagMaintaining {
    struct Constants {
        fileprivate static let flagQueueLabel = "com.launchdarkly.flagStore.flagQueue"
    }
    
    struct Keys {
        static let flagKey = "key"
    }

    private(set) var featureFlags: [LDFlagKey: FeatureFlag] = [:]
    private(set) var flagValueSource = LDFlagValueSource.fallback
    private var flagQueue = DispatchQueue(label: Constants.flagQueueLabel)

    init() { }

    init(featureFlags: [LDFlagKey: FeatureFlag]?, flagValueSource: LDFlagValueSource = .fallback) {
        Log.debug(typeName(and: #function) + "featureFlags: \(String(describing: featureFlags)), " + "flagValueSource: \(flagValueSource)")
        self.featureFlags = featureFlags ?? [:]
        self.flagValueSource = flagValueSource
    }

    convenience init(featureFlagDictionary: [LDFlagKey: Any]?, flagValueSource: LDFlagValueSource = .fallback) {
        self.init(featureFlags: featureFlagDictionary?.flagCollection, flagValueSource: flagValueSource)
    }

    ///Replaces all feature flags with new flags. Pass nil to reset to an empty flag store
    func replaceStore(newFlags: [LDFlagKey: Any]?, source: LDFlagValueSource, completion: CompletionClosure?) {
        Log.debug(typeName(and: #function) + "newFlags: \(String(describing: newFlags)), " + "source: \(source)")
        flagQueue.async {
            self.featureFlags = newFlags?.flagCollection ?? [:]
            self.flagValueSource = source
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    /* updateDictionary should have the form:
       {
            "key": <flag-key>,
            "value": <new-flag-value>,
            "variation": <new-flag-variation>,
            "version": <new-flag-version>
            "flagVersion": <new-flag-flagVersion>
        }
    */
    func updateStore(updateDictionary: [String: Any], source: LDFlagValueSource, completion: CompletionClosure?) {
        flagQueue.async {
            defer {
                if let completion = completion {
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            }
            guard let flagKey = updateDictionary[Keys.flagKey] as? String,
                let newFlag = FeatureFlag(dictionary: updateDictionary)
            else {
                Log.debug(self.typeName(and: #function) + "aborted. Malformed update dictionary. updateDictionary: \(String(describing: updateDictionary))")
                return
            }
            //Use only the version for comparison, ignore the flagVersion. The flagVersion is only used for event reporting.
            guard self.isValidVersion(for: flagKey, newVersion: newFlag.version)
            else {
                Log.debug(self.typeName(and: #function) + "aborted. Invalid version. updateDictionary: \(String(describing: updateDictionary)) "
                    + "existing flag: \(String(describing: self.featureFlags[flagKey]))")
                return
            }

            Log.debug(self.typeName(and: #function) + "succeeded. new flag: \(newFlag), " + "prior flag: \(String(describing: self.featureFlags[flagKey]))")
            self.featureFlags[flagKey] = newFlag

        }
    }
    
    /* deleteDictionary should have the form:
        {
            "key": <flag-key>,
            "version": <new-flag-version>
        }
     */
    func deleteFlag(deleteDictionary: [String: Any], completion: CompletionClosure?) {
        flagQueue.async {
            defer {
                if let completion = completion {
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            }
            guard deleteDictionary.keys.sorted() == [Keys.flagKey, FeatureFlag.CodingKeys.version.rawValue],
                let flagKey = deleteDictionary[Keys.flagKey] as? String,
                let newVersion = deleteDictionary[FeatureFlag.CodingKeys.version.rawValue] as? Int
            else {
                Log.debug(self.typeName(and: #function) + "aborted. Malformed delete dictionary. deleteDictionary: \(String(describing: deleteDictionary))")
                return
            }
            //Use only the version for comparison, ignore the flagVersion. The flagVersion is only used for event reporting.
            guard self.isValidVersion(for: flagKey, newVersion: newVersion)
            else {
                Log.debug(self.typeName(and: #function) + "aborted. Invalid version. deleteDictionary: \(String(describing: deleteDictionary)) "
                    + "existing flag: \(String(describing: self.featureFlags[flagKey]))")
                return
            }

            Log.debug(self.typeName(and: #function) + "deleted flag with key: " + flagKey)
            self.featureFlags.removeValue(forKey: flagKey)
        }
    }

    private func isValidVersion(for flagKey: LDFlagKey, newVersion: Int?) -> Bool {
        //Use only the version, here called "environmentVersion" for comparison, ignore the flagVersion. The flagVersion is only used for event reporting.
        guard let environmentVersion = featureFlags[flagKey]?.version,
            let newEnvironmentVersion = newVersion
        else {
            return true     //new flags ignore version, ignore missing version too
        }
        return newEnvironmentVersion > environmentVersion
    }

    func featureFlag(for flagKey: LDFlagKey) -> FeatureFlag? {
        let (featureFlag, _) = featureFlagAndSource(for: flagKey)
        return featureFlag
    }

    func featureFlagAndSource(for flagKey: LDFlagKey) -> (FeatureFlag?, LDFlagValueSource?) {
        let featureFlag = featureFlags[flagKey]
        return (featureFlag, featureFlag == nil ? nil : flagValueSource)
    }

    func variation<T: LDFlagValueConvertible>(forKey key: LDFlagKey, fallback: T) -> T {
        let (flagValue, _) = variationAndSource(forKey: key, fallback: fallback)
        return flagValue
    }

    func variationAndSource<T: LDFlagValueConvertible>(forKey key: LDFlagKey, fallback: T) -> (T, LDFlagValueSource) {
        var (flagValue, source) = (fallback, LDFlagValueSource.fallback)
        if let foundValue = featureFlags[key]?.value as? T {
            (flagValue, source) = (foundValue, flagValueSource)
        }
        return (flagValue, source)
    }
}

extension FlagStore: TypeIdentifying { }
