//
//  FlagChangeNotifier.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 8/18/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

//sourcery: AutoMockable
protocol FlagChangeNotifying {
    func addFlagChangeObserver(_ observer: FlagChangeObserver)
    func addFlagsUnchangedObserver(_ observer: FlagsUnchangedObserver)
    //sourcery: NoMock
    func removeObserver(_ key: LDFlagKey, owner: LDObserverOwner)
    func removeObserver(_ keys: [LDFlagKey], owner: LDObserverOwner)
    //sourcery: NoMock
    func removeObserver(owner: LDObserverOwner)
    func notifyObservers(user: LDUser, oldFlags: [LDFlagKey: FeatureFlag], oldFlagSource: LDFlagValueSource)
}

final class FlagChangeNotifier: FlagChangeNotifying {
    private var flagChangeObservers = [FlagChangeObserver]()
    private var flagsUnchangedObservers = [FlagsUnchangedObserver]()
    
    func addFlagChangeObserver(_ observer: FlagChangeObserver) {
        Log.debug(typeName(and: #function) + "observer: \(observer)")
        flagChangeObservers.append(observer)
    }
    
    func addFlagsUnchangedObserver(_ observer: FlagsUnchangedObserver) {
        Log.debug(typeName(and: #function) + "observer: \(observer)")
        flagsUnchangedObservers.append(observer)
    }

    ///Removes any change handling closures for flag.key from owner
    func removeObserver(_ key: LDFlagKey, owner: LDObserverOwner) {
        Log.debug(typeName(and: #function) + "key: \(key), owner: \(owner)")
        removeObserver([key], owner: owner)
    }
    
    ///Removes any change handling closures for flag keys from owner
    func removeObserver(_ keys: [LDFlagKey], owner: LDObserverOwner) {
        Log.debug(typeName(and: #function) + "keys: \(keys), owner: \(owner)")
        flagChangeObservers = flagChangeObservers.filter { (observer) in
            !(observer.flagKeys == keys && observer.owner === owner)
        }
    }
    
    ///Removes all change handling closures from owner
    func removeObserver(owner: LDObserverOwner) {
        Log.debug(typeName(and: #function) + "owner: \(owner)")
        flagChangeObservers = flagChangeObservers.filter { (observer) in
            observer.owner !== owner
        }
        flagsUnchangedObservers = flagsUnchangedObservers.filter { (observer) in
            observer.owner !== owner
        }
    }
    
    func notifyObservers(user: LDUser, oldFlags: [LDFlagKey: FeatureFlag], oldFlagSource: LDFlagValueSource) {
        removeOldObservers()

        let changedFlagKeys = findChangedFlagKeys(oldFlags: oldFlags, newFlags: user.flagStore.featureFlags)
        guard !changedFlagKeys.isEmpty
        else {
            let logMessage: String
            if flagsUnchangedObservers.isEmpty {
                logMessage = "aborted. Flags unchanged and no flagsUnchanged observers set."
            } else {
                logMessage = "notifying observers that flags are unchanged."
            }
            Log.debug(typeName(and: #function) + logMessage)
            flagsUnchangedObservers.forEach { (flagsUnchangedObserver) in
                if let flagsUnchangedHandler = flagsUnchangedObserver.flagsUnchangedHandler {
                    DispatchQueue.main.async {
                        flagsUnchangedHandler()
                    }
                }
            }
            return
        }

        let selectedObservers = flagChangeObservers.watching(changedFlagKeys)
        guard !selectedObservers.isEmpty
        else {
            Log.debug(typeName(and: #function) + "aborted. No observers watching changed flags.")
            return
        }

        let changedFlags = [LDFlagKey: LDChangedFlag](uniqueKeysWithValues: changedFlagKeys.map { (flagKey) in
            return (flagKey, LDChangedFlag(key: flagKey,
                                           oldValue: oldFlags[flagKey]?.value,
                                           oldValueSource: oldFlagSource,
                                           newValue: user.flagStore.featureFlags[flagKey]?.value,
                                           newValueSource: user.flagStore.flagValueSource))
        })
        Log.debug(typeName(and: #function) + "notifying observers for changes to flags: \(changedFlags.keys.joined(separator: ", ")).")
        selectedObservers.forEach { (observer) in
            let filteredChangedFlags = changedFlags.filter { (flagKey, _) -> Bool in
                observer.flagKeys == LDFlagKey.anyKey || observer.flagKeys.contains(flagKey)
            }
            if let changeHandler = observer.flagCollectionChangeHandler {
                DispatchQueue.main.async {
                    changeHandler(filteredChangedFlags)
                }
                return
            }
            filteredChangedFlags.forEach({ (_, changedFlag) in
                if let changeHandler = observer.flagChangeHandler {
                    DispatchQueue.main.async {
                        changeHandler(changedFlag)
                    }
                }
            })
        }
    }
    
    private func removeOldObservers() {
        Log.debug(typeName(and: #function))
        let newFlagChangeObservers = flagChangeObservers.filter { (observer) in
            observer.owner != nil
        }
        flagChangeObservers = newFlagChangeObservers
        let newFlagsUnchangedObservers = flagsUnchangedObservers.filter { (observer) in
            observer.owner != nil
        }
        flagsUnchangedObservers = newFlagsUnchangedObservers
    }

    private func findChangedFlagKeys(oldFlags: [LDFlagKey: FeatureFlag], newFlags: [LDFlagKey: FeatureFlag]) -> [LDFlagKey] {
        return oldFlags.symmetricDifference(newFlags)     //symmetricDifference tests for equality, which includes version. Exclude version here.
            .filter { (flagKey) in
                guard let oldFeatureFlag = oldFlags[flagKey],
                    let newFeatureFlag = newFlags[flagKey]
                else {
                    return true
                }
                return !oldFeatureFlag.matchesVariation(newFeatureFlag)
        }
    }
}

extension Array where Element == LDFlagKey {
    func containsAny(_ other: [LDFlagKey]) -> Bool {
        return !Set(self).isDisjoint(with: Set(other))
    }
}

extension Array where Element == FlagChangeObserver {
    func watching(_ flagKeys: [LDFlagKey]) -> [FlagChangeObserver] {
        return filter { (observer) in
            observer.flagKeys == LDFlagKey.anyKey || observer.flagKeys.containsAny(flagKeys)
        }
    }
}

extension FlagChangeNotifier: TypeIdentifying { }
//Test support
#if DEBUG
    extension FlagChangeNotifier {
        var flagObservers: [FlagChangeObserver] {
            return flagChangeObservers
        }
        var noChangeObservers: [FlagsUnchangedObserver] {
            return flagsUnchangedObservers
        }

        convenience init(flagChangeObservers: [FlagChangeObserver], flagsUnchangedObservers: [FlagsUnchangedObserver]) {
            self.init()
            self.flagChangeObservers = flagChangeObservers
            self.flagsUnchangedObservers = flagsUnchangedObservers
        }

        func notifyObservers(user: LDUser, oldFlags: [LDFlagKey: FeatureFlag], oldFlagSource: LDFlagValueSource, completion: @escaping () -> Void) {
            notifyObservers(user: user, oldFlags: oldFlags, oldFlagSource: oldFlagSource)
            DispatchQueue.main.async {
                completion()
            }
        }
    }
#endif
