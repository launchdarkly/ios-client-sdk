import Foundation

protocol FlagMaintaining {
    var featureFlags: [LDFlagKey: FeatureFlag] { get }

    func replaceStore(newFlags: FeatureFlagCollection)
    func updateStore(updatedFlag: FeatureFlag)
    func deleteFlag(deleteResponse: DeleteResponse)
    func featureFlag(for flagKey: LDFlagKey) -> FeatureFlag?
}

final class FlagStore: FlagMaintaining {
    struct Constants {
        fileprivate static let flagQueueLabel = "com.launchdarkly.flagStore.flagQueue"
    }

    var featureFlags: [LDFlagKey: FeatureFlag] { flagQueue.sync { _featureFlags } }

    private var _featureFlags: [LDFlagKey: FeatureFlag] = [:]
    // Used with .barrier as reader writer lock on _featureFlags
    private var flagQueue = DispatchQueue(label: Constants.flagQueueLabel, attributes: .concurrent)

    init() { }

    init(featureFlags: [LDFlagKey: FeatureFlag]) {
        Log.debug(typeName(and: #function) + "featureFlags: \(String(describing: featureFlags))")
        self._featureFlags = featureFlags
    }

    func replaceStore(newFlags: FeatureFlagCollection) {
        Log.debug(typeName(and: #function) + "newFlags: \(String(describing: newFlags))")
        flagQueue.sync(flags: .barrier) {
            self._featureFlags = newFlags.flags
        }
    }

    func updateStore(updatedFlag: FeatureFlag) {
        flagQueue.sync(flags: .barrier) {
            guard self.isValidVersion(for: updatedFlag.flagKey, newVersion: updatedFlag.version)
            else {
                Log.debug(self.typeName(and: #function) + "aborted. Invalid version. updateDictionary: \(updatedFlag) "
                          + "existing flag: \(String(describing: self._featureFlags[updatedFlag.flagKey]))")
                return
            }

            Log.debug(self.typeName(and: #function) + "succeeded. new flag: \(updatedFlag), " +
                      "prior flag: \(String(describing: self._featureFlags[updatedFlag.flagKey]))")
            self._featureFlags.updateValue(updatedFlag, forKey: updatedFlag.flagKey)
        }
    }

    func deleteFlag(deleteResponse: DeleteResponse) {
        flagQueue.sync(flags: .barrier) {
            guard self.isValidVersion(for: deleteResponse.key, newVersion: deleteResponse.version)
            else {
                Log.debug(self.typeName(and: #function) + "aborted. Invalid version. deleteResponse: \(deleteResponse) "
                          + "existing flag: \(String(describing: self._featureFlags[deleteResponse.key]))")
                return
            }

            Log.debug(self.typeName(and: #function) + "deleted flag with key: " + deleteResponse.key)
            self._featureFlags.removeValue(forKey: deleteResponse.key)
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
