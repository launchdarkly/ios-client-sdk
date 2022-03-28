//
//  FlagStore.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

protocol FlagMaintaining {
    var featureFlags: [LDFlagKey: FeatureFlag] { get }

    func replaceStore(newFlags: [LDFlagKey: Any], completion: CompletionClosure?)
    func updateStore(updateDictionary: [LDFlagKey: Any], completion: CompletionClosure?)
    func deleteFlag(deleteDictionary: [LDFlagKey: Any], completion: CompletionClosure?)
    func featureFlag(for flagKey: LDFlagKey) -> FeatureFlag?
}

final class FlagStore: FlagMaintaining {
    struct Constants {
        fileprivate static let flagQueueLabel = "com.launchdarkly.flagStore.flagQueue"
    }

    struct Keys {
        static let flagKey = "key"
    }

    var featureFlags: [LDFlagKey: FeatureFlag] { flagQueue.sync { _featureFlags } }

    private var _featureFlags: [LDFlagKey: FeatureFlag] = [:]
    // Used with .barrier as reader writer lock on _featureFlags
    private var flagQueue = DispatchQueue(label: Constants.flagQueueLabel, attributes: .concurrent)

    init() { }

    init(featureFlags: [LDFlagKey: FeatureFlag]?) {
        Log.debug(typeName(and: #function) + "featureFlags: \(String(describing: featureFlags))")
        self._featureFlags = featureFlags ?? [:]
    }

    convenience init(featureFlagDictionary: [LDFlagKey: Any]?) {
        self.init(featureFlags: featureFlagDictionary?.flagCollection)
    }

    /// Replaces all feature flags with new flags. Pass nil to reset to an empty flag store
    func replaceStore(newFlags: [LDFlagKey: Any], completion: CompletionClosure?) {
        Log.debug(typeName(and: #function) + "newFlags: \(String(describing: newFlags))")
        flagQueue.async(flags: .barrier) {
            self._featureFlags = newFlags.flagCollection ?? [:]
            if let completion = completion {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    // An update dictionary is the same as a flag dictionary. The version will be validated and if it's newer than the
    // stored flag, the store will replace the flag with the updated flag.
    func updateStore(updateDictionary: [LDFlagKey: Any], completion: CompletionClosure?) {
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
                    + "existing flag: \(String(describing: self._featureFlags[flagKey]))")
                return
            }

            Log.debug(self.typeName(and: #function) + "succeeded. new flag: \(newFlag), " + "prior flag: \(String(describing: self._featureFlags[flagKey]))")
            self._featureFlags.updateValue(newFlag, forKey: flagKey)
        }
    }

    /* deleteDictionary should have the form:
        {
            "key": <flag-key>,
            "version": <new-flag-version>
        }
     */
    func deleteFlag(deleteDictionary: [LDFlagKey: Any], completion: CompletionClosure?) {
        flagQueue.async(flags: .barrier) {
            defer {
                if let completion = completion {
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            }
            guard let flagKey = deleteDictionary[Keys.flagKey] as? String,
                  let newVersion = deleteDictionary[FeatureFlag.CodingKeys.version.rawValue] as? Int
            else {
                Log.debug(self.typeName(and: #function) + "aborted. Malformed delete dictionary. deleteDictionary: \(String(describing: deleteDictionary))")
                return
            }
            guard self.isValidVersion(for: flagKey, newVersion: newVersion)
            else {
                Log.debug(self.typeName(and: #function) + "aborted. Invalid version. deleteDictionary: \(String(describing: deleteDictionary)) "
                    + "existing flag: \(String(describing: self._featureFlags[flagKey]))")
                return
            }

            Log.debug(self.typeName(and: #function) + "deleted flag with key: " + flagKey)
            self._featureFlags.removeValue(forKey: flagKey)
        }
    }

    private func isValidVersion(for flagKey: LDFlagKey, newVersion: Int?) -> Bool {
        // Currently only called from within barrier, only call on flagQueue
        // Use only the version, here called "environmentVersion" for comparison. The flagVersion is only used for event reporting.
        if let environmentVersion = _featureFlags[flagKey]?.version,
           let newEnvironmentVersion = newVersion {
            return newEnvironmentVersion > environmentVersion
        }
        // Always update if either environment version is missing, or updating non-existent flag
        return true
    }

    func featureFlag(for flagKey: LDFlagKey) -> FeatureFlag? {
        flagQueue.sync { _featureFlags[flagKey] }
    }
}

extension FlagStore: TypeIdentifying { }

extension Dictionary where Key == LDFlagKey, Value == FeatureFlag {
    var allFlagValues: [LDFlagKey: Any] { compactMapValues { $0.value } }
}
