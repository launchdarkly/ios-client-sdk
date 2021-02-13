//
//  FlagChangeNotifier.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

//sourcery: autoMockable
protocol FlagChangeNotifying {
    func addFlagChangeObserver(_ observer: FlagChangeObserver)
    func addFlagsUnchangedObserver(_ observer: FlagsUnchangedObserver)
    func addConnectionModeChangedObserver(_ observer: ConnectionModeChangedObserver)
    func removeObserver(owner: LDObserverOwner)
    func notifyConnectionModeChangedObservers(connectionMode: ConnectionInformation.ConnectionMode)
    func notifyObservers(flagStore: FlagMaintaining, oldFlags: [LDFlagKey: FeatureFlag])
}

final class FlagChangeNotifier: FlagChangeNotifying {
    private var flagChangeObservers = [FlagChangeObserver]()
    private var flagsUnchangedObservers = [FlagsUnchangedObserver]()
    private var connectionModeChangedObservers = [ConnectionModeChangedObserver]()
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

    ///Removes all change handling closures from owner
    func removeObserver(owner: LDObserverOwner) {
        Log.debug(typeName(and: #function) + "owner: \(owner)")
        flagChangeQueue.sync { flagChangeObservers.removeAll { $0.owner === owner } }
        flagsUnchangedQueue.sync { flagsUnchangedObservers.removeAll { $0.owner === owner } }
        connectionModeChangedQueue.sync { connectionModeChangedObservers.removeAll { $0.owner === owner } }
    }

    func notifyConnectionModeChangedObservers(connectionMode: ConnectionInformation.ConnectionMode) {
        connectionModeChangedQueue.sync {
            connectionModeChangedObservers.forEach { connectionModeChangedObserver in
                if let connectionModeChangedHandler = connectionModeChangedObserver.connectionModeChangedHandler {
                    DispatchQueue.main.async {
                        connectionModeChangedHandler(connectionMode)
                    }
                }
            }
        }
    }

    func notifyObservers(flagStore: FlagMaintaining, oldFlags: [LDFlagKey: FeatureFlag]) {
        removeOldObservers()

        let changedFlagKeys = findChangedFlagKeys(oldFlags: oldFlags, newFlags: flagStore.featureFlags)
        guard !changedFlagKeys.isEmpty
        else {
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
            return
        }

        let selectedObservers = flagChangeQueue.sync {
            flagChangeObservers.filter { $0.flagKeys == LDFlagKey.anyKey || $0.flagKeys.contains { changedFlagKeys.contains($0) } }
        }
        guard !selectedObservers.isEmpty
        else {
            Log.debug(typeName(and: #function) + "aborted. No observers watching changed flags.")
            return
        }

        let changedFlags = [LDFlagKey: LDChangedFlag](uniqueKeysWithValues: changedFlagKeys.map { flagKey in
            (flagKey, LDChangedFlag(key: flagKey,
                                    oldValue: oldFlags[flagKey]?.value,
                                    newValue: flagStore.featureFlags[flagKey]?.value))
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
        connectionModeChangedQueue.sync { connectionModeChangedObservers.removeAll { $0.owner == nil } }
    }

    private func findChangedFlagKeys(oldFlags: [LDFlagKey: FeatureFlag], newFlags: [LDFlagKey: FeatureFlag]) -> [LDFlagKey] {
        oldFlags.symmetricDifference(newFlags)     //symmetricDifference tests for equality, which includes version. Exclude version here.
            .filter { flagKey in
                guard let oldFeatureFlag = oldFlags[flagKey],
                    let newFeatureFlag = newFlags[flagKey]
                else {
                    return true
                }
                return !(oldFeatureFlag.variation == newFeatureFlag.variation &&
                         AnyComparer.isEqual(oldFeatureFlag.value, to: newFeatureFlag.value))
        }
    }
}

extension FlagChangeNotifier: TypeIdentifying { }
//Test support
#if DEBUG
    extension FlagChangeNotifier {
        var flagObservers: [FlagChangeObserver] { flagChangeObservers }
        var noChangeObservers: [FlagsUnchangedObserver] { flagsUnchangedObservers }

        convenience init(flagChangeObservers: [FlagChangeObserver], flagsUnchangedObservers: [FlagsUnchangedObserver]) {
            self.init()
            self.flagChangeObservers = flagChangeObservers
            self.flagsUnchangedObservers = flagsUnchangedObservers
        }

        func notifyObservers(flagStore: FlagMaintaining, oldFlags: [LDFlagKey: FeatureFlag], completion: @escaping () -> Void) {
            notifyObservers(flagStore: flagStore, oldFlags: oldFlags)
            DispatchQueue.main.async {
                completion()
            }
        }
    }
#endif
