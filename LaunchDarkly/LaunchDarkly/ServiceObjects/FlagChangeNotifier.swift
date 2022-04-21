import Foundation

// sourcery: autoMockable
protocol FlagChangeNotifying {
    func addFlagChangeObserver(_ observer: FlagChangeObserver)
    func addFlagsUnchangedObserver(_ observer: FlagsUnchangedObserver)
    func addConnectionModeChangedObserver(_ observer: ConnectionModeChangedObserver)
    func removeObserver(owner: LDObserverOwner)
    func notifyConnectionModeChangedObservers(connectionMode: ConnectionInformation.ConnectionMode)
    func notifyUnchanged()
    func notifyObservers(oldFlags: [LDFlagKey: FeatureFlag], newFlags: [LDFlagKey: FeatureFlag])
}

final class FlagChangeNotifier: FlagChangeNotifying {
    // Exposed for testing
    private (set) var flagChangeObservers = [FlagChangeObserver]()
    private (set) var flagsUnchangedObservers = [FlagsUnchangedObserver]()
    private (set) var connectionModeChangedObservers = [ConnectionModeChangedObserver]()
    private var flagChangeQueue = DispatchQueue(label: "com.launchdarkly.FlagChangeNotifier.FlagChangeQueue")
    private var flagsUnchangedQueue = DispatchQueue(label: "com.launchdarkly.FlagChangeNotifier.FlagsUnchangedQueue")
    private var connectionModeChangedQueue = DispatchQueue(label: "com.launchdarkly.FlagChangeNotifier.ConnectionModeChangedQueue")

    func addFlagChangeObserver(_ observer: FlagChangeObserver) {
        Log.debug(typeName(and: #function) + "observer: \(observer)")
        flagChangeQueue.sync { flagChangeObservers.append(observer) }
    }

    func addFlagsUnchangedObserver(_ observer: FlagsUnchangedObserver) {
        Log.debug(typeName(and: #function) + "observer: \(observer)")
        flagsUnchangedQueue.sync { flagsUnchangedObservers.append(observer) }
    }

    func addConnectionModeChangedObserver(_ observer: ConnectionModeChangedObserver) {
        Log.debug(typeName(and: #function) + "observer: \(observer)")
        connectionModeChangedQueue.sync { connectionModeChangedObservers.append(observer) }
    }

    /// Removes all change handling closures from owner
    func removeObserver(owner: LDObserverOwner) {
        Log.debug(typeName(and: #function) + "owner: \(owner)")
        flagChangeQueue.sync { flagChangeObservers.removeAll { $0.owner === owner } }
        flagsUnchangedQueue.sync { flagsUnchangedObservers.removeAll { $0.owner === owner } }
        connectionModeChangedQueue.sync { connectionModeChangedObservers.removeAll { $0.owner === owner } }
    }

    func notifyConnectionModeChangedObservers(connectionMode: ConnectionInformation.ConnectionMode) {
        connectionModeChangedQueue.sync {
            connectionModeChangedObservers.removeAll { $0.owner == nil }
            connectionModeChangedObservers.forEach { observer in
                DispatchQueue.main.async {
                    observer.connectionModeChangedHandler(connectionMode)
                }
            }
        }
    }

    func notifyUnchanged() {
        removeOldObservers()

        if flagsUnchangedObservers.isEmpty {
            Log.debug(typeName(and: #function) + "aborted. Flags unchanged and no flagsUnchanged observers set.")
        } else {
            Log.debug(typeName(and: #function) + "notifying observers that flags are unchanged.")
        }
        flagsUnchangedQueue.sync {
            flagsUnchangedObservers.forEach { flagsUnchangedObserver in
                DispatchQueue.main.async {
                    flagsUnchangedObserver.flagsUnchangedHandler()
                }
            }
        }
    }

    func notifyObservers(oldFlags: [LDFlagKey: FeatureFlag], newFlags: [LDFlagKey: FeatureFlag]) {
        let changedFlagKeys = findChangedFlagKeys(oldFlags: oldFlags, newFlags: newFlags)
        guard !changedFlagKeys.isEmpty
        else {
            notifyUnchanged()
            return
        }

        removeOldObservers()
        let selectedObservers = flagChangeQueue.sync {
            flagChangeObservers.filter { $0.flagKeys == LDFlagKey.anyKey || $0.flagKeys.contains { changedFlagKeys.contains($0) } }
        }
        guard !selectedObservers.isEmpty
        else {
            Log.debug(typeName(and: #function) + "aborted. No observers watching changed flags.")
            return
        }

        let changedFlags = [LDFlagKey: LDChangedFlag](uniqueKeysWithValues: changedFlagKeys.map {
            ($0, LDChangedFlag(key: $0, oldValue: oldFlags[$0]?.value ?? .null, newValue: newFlags[$0]?.value ?? .null))
        })
        Log.debug(typeName(and: #function) + "notifying observers for changes to flags: \(changedFlags.keys.joined(separator: ", ")).")
        selectedObservers.forEach { observer in
            let filteredChangedFlags = changedFlags.filter { flagKey, _ -> Bool in
                observer.flagKeys == LDFlagKey.anyKey || observer.flagKeys.contains(flagKey)
            }
            if let changeHandler = observer.flagCollectionChangeHandler {
                DispatchQueue.main.async { changeHandler(filteredChangedFlags) }
            }
            if let changeHandler = observer.flagChangeHandler {
                filteredChangedFlags.forEach { _, changedFlag in DispatchQueue.main.async { changeHandler(changedFlag) } }
            }
        }
    }

    private func removeOldObservers() {
        Log.debug(typeName(and: #function))
        flagChangeQueue.sync { flagChangeObservers.removeAll { $0.owner == nil } }
        flagsUnchangedQueue.sync { flagsUnchangedObservers.removeAll { $0.owner == nil } }
    }

    private func findChangedFlagKeys(oldFlags: [LDFlagKey: FeatureFlag], newFlags: [LDFlagKey: FeatureFlag]) -> [LDFlagKey] {
        let oldKeys = Set(oldFlags.keys)
        let newKeys = Set(newFlags.keys)
        let newOrDeletedKeys = oldKeys.symmetricDifference(newKeys)
        let updatedKeys = oldKeys.intersection(newKeys).filter { possibleUpdatedKey in
            guard let old = oldFlags[possibleUpdatedKey], let new = newFlags[possibleUpdatedKey]
            else { return true }
            return old.variation != new.variation || old.value != new.value
        }
        return newOrDeletedKeys.union(updatedKeys).sorted()
    }
}

extension FlagChangeNotifier: TypeIdentifying { }
