//
//  FlagStore.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 9/20/17. JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

//sourcery: autoMockable
protocol FlagMaintaining {
    var featureFlags: [LDFlagKey: FeatureFlag] { get }
    //sourcery: defaultMockValue = .cache
    var flagValueSource: LDFlagValueSource { get }
    func replaceStore(newFlags: [LDFlagKey: Any]?, source: LDFlagValueSource, completion: CompletionClosure?)
    func updateStore(updateDictionary: [String: Any], source: LDFlagValueSource, completion: CompletionClosure?)
    func deleteFlag(deleteDictionary: [String: Any], completion: CompletionClosure?)

    //sourcery: noMock
    func featureFlag(for flagKey: LDFlagKey) -> FeatureFlag?
    //sourcery: noMock
    func featureFlagAndSource(for flagKey: LDFlagKey) -> (FeatureFlag?, LDFlagValueSource?)

    //sourcery: noMock
    func variation<T: LDFlagValueConvertible>(forKey key: LDFlagKey, fallback: T) -> T
    //sourcery: noMock
    func variationAndSource<T: LDFlagValueConvertible>(forKey key: LDFlagKey, fallback: T) -> (T, LDFlagValueSource)
}

final class FlagStore: FlagMaintaining {
    struct Keys {
        static let flagKey = "key"
    }

    private(set) var featureFlags: [LDFlagKey: FeatureFlag] = [:]
    private(set) var flagValueSource = LDFlagValueSource.fallback
    // Used with .barrier as reader writer lock on featureFlags, flagValueSource
    private var flagQueue: DispatchQueue
    fileprivate var flagQueueName: String

    init() {
        self.flagQueueName = UUID().uuidString
        self.flagQueue = DispatchQueue(label: flagQueueName, attributes: .concurrent)
    }

    init(featureFlags: [LDFlagKey: FeatureFlag]?, flagValueSource: LDFlagValueSource = .fallback) {
        self.flagQueueName = UUID().uuidString
        self.flagQueue = DispatchQueue(label: flagQueueName, attributes: .concurrent)
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
        flagQueue.async(flags: .barrier) {
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
            "version": <new-flag-version>,
            "flagVersion": <new-flag-flagVersion>,
            "reason": <new-flag-reason>
        }
    */
    func updateStore(updateDictionary: [String: Any], source: LDFlagValueSource, completion: CompletionClosure?) {
        flagQueue.async(flags: .barrier) {
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
            guard self.isValidVersion(for: flagKey, newVersion: newFlag.version)
            else {
                Log.debug(self.typeName(and: #function) + "aborted. Invalid version. updateDictionary: \(String(describing: updateDictionary)) "
                    + "existing flag: \(String(describing: self.featureFlags[flagKey]))")
                return
            }

            Log.debug(self.typeName(and: #function) + "succeeded. new flag: \(newFlag), " + "prior flag: \(String(describing: self.featureFlags[flagKey]))")
            self.featureFlags.updateValue(newFlag, forKey: flagKey)
        }
    }
    
    /* deleteDictionary should have the form:
        {
            "key": <flag-key>,
            "version": <new-flag-version>
        }
     */
    func deleteFlag(deleteDictionary: [String: Any], completion: CompletionClosure?) {
        flagQueue.async(flags: .barrier) {
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
        // Currently only called from within barrier, only call on flagQueue
        // Use only the version, here called "environmentVersion" for comparison. The flagVersion is only used for event reporting.
        if let environmentVersion = featureFlags[flagKey]?.version,
           let newEnvironmentVersion = newVersion {
            return newEnvironmentVersion > environmentVersion
        }
        // Always update if either environment version is missing, or updating non-existent flag
        return true
    }

    func featureFlag(for flagKey: LDFlagKey) -> FeatureFlag? {
        featureFlagAndSource(for: flagKey).0
    }

    func featureFlagAndSource(for flagKey: LDFlagKey) -> (FeatureFlag?, LDFlagValueSource?) {
        flagQueue.sync {
            let featureFlag = featureFlags[flagKey]
            return (featureFlag, featureFlag == nil ? nil : flagValueSource)
        }
    }

    func variation<T: LDFlagValueConvertible>(forKey key: LDFlagKey, fallback: T) -> T {
        variationAndSource(forKey: key, fallback: fallback).0
    }

    func variationAndSource<T: LDFlagValueConvertible>(forKey key: LDFlagKey, fallback: T) -> (T, LDFlagValueSource) {
        flagQueue.sync {
            let foundValue = featureFlags[key]?.value as? T
            return (foundValue ?? fallback, foundValue == nil ? .fallback : flagValueSource)
        }
    }
}

extension FlagStore: TypeIdentifying { }

extension Dictionary where Key == LDFlagKey, Value == FeatureFlag {
    var allFlagValues: [LDFlagKey: Any] { compactMapValues { $0.value } }
}
