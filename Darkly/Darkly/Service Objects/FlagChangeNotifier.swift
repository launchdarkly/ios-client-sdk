//
//  FlagChangeNotifier.swift
//  Darkly
//
//  Created by Mark Pokorny on 8/18/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

//TODO: Change this to add a flags unchanged closure that gets called when notifyObservers is called with no flags changed. Have the LDClient set the closure when it creates the change notifier, or when the closure is set by the client app. That contains the change notifier's responsibility better
//sourcery: AutoMockable
protocol FlagChangeNotifying {
    var flagsUnchangedObserver: FlagsUnchangedObserver? { get set }
    func add(_ observer: FlagChangeObserver)
    //sourcery: NoMock
    func removeObserver(_ key: LDFlagKey, owner: LDFlagChangeOwner)
    func removeObserver(_ keys: [LDFlagKey], owner: LDFlagChangeOwner)
    //sourcery: NoMock
    func removeObserver(owner: LDFlagChangeOwner)
    func notifyObservers(user: LDUser, oldFlags: [LDFlagKey: FeatureFlag], oldFlagSource: LDFlagValueSource)
}

final class FlagChangeNotifier: FlagChangeNotifying {
    private var observers = [FlagChangeObserver]()
    var flagsUnchangedObserver: FlagsUnchangedObserver?
    
    func add(_ observer: FlagChangeObserver) {
        observers.append(observer)
    }
    
    ///Removes any change handling closures for flag.key from owner
    func removeObserver(_ key: LDFlagKey, owner: LDFlagChangeOwner) {
        removeObserver([key], owner: owner)
    }
    
    ///Removes any change handling closures for flag keys from owner
    func removeObserver(_ keys: [LDFlagKey], owner: LDFlagChangeOwner) {
        observers = observers.filter { (observer) in !(observer.flagKeys == keys && observer.owner === owner) }
    }
    
    ///Removes all change handling closures from owner
    func removeObserver(owner: LDFlagChangeOwner) {
        observers = observers.filter { (observer) in observer.owner !== owner }
        if flagsUnchangedObserver?.owner === owner { flagsUnchangedObserver = nil }
    }
    
    func notifyObservers(user: LDUser, oldFlags: [LDFlagKey: FeatureFlag], oldFlagSource: LDFlagValueSource) {
        removeOldObservers()

        let changedFlagKeys = findChangedFlagKeys(oldFlags: oldFlags, newFlags: user.flagStore.featureFlags)
        guard !changedFlagKeys.isEmpty else {
            if let flagsUnchangedHandler = flagsUnchangedObserver?.flagsUnchangedHandler { flagsUnchangedHandler() }
            return
        }

        let selectedObservers = observers.watching(changedFlagKeys)
        guard !selectedObservers.isEmpty else { return }

        let changedFlags = [LDFlagKey: LDChangedFlag](uniqueKeysWithValues: changedFlagKeys.map { (flagKey) in
            return (flagKey, LDChangedFlag(key: flagKey,
                                           oldValue: oldFlags[flagKey],
                                           oldValueSource: oldFlagSource,
                                           newValue: user.flagStore.featureFlags[flagKey],
                                           newValueSource: user.flagStore.flagValueSource))
        })
        selectedObservers.forEach { (observer) in
            let filteredChangedFlags = changedFlags.filter({ (flagKey, _) -> Bool in observer.flagKeys.contains(flagKey) })
            if observer.flagCollectionChangeHandler != nil {
                observer.flagCollectionChangeHandler?(filteredChangedFlags)
                return
            }
            filteredChangedFlags.forEach({ (_, changedFlag) in
                observer.flagChangeHandler?(changedFlag)
            })
        }
    }
    
    private func removeOldObservers() {
        let newObservers = observers.filter { (observer) in observer.owner != nil }
        observers = newObservers
    }

    private func findChangedFlagKeys(oldFlags: [LDFlagKey: FeatureFlag], newFlags: [LDFlagKey: FeatureFlag]) -> [LDFlagKey] {
        return oldFlags.symmetricDifference(newFlags)     //symmetricDifference tests for equality, which includes version. Exclude version here.
            .filter { (flagKey) in
                guard let oldFeatureFlag = oldFlags[flagKey], let newFeatureFlag = newFlags[flagKey] else { return true }
                return !oldFeatureFlag.matchesValue(newFeatureFlag)
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
        return filter { (observer) in observer.flagKeys.containsAny(flagKeys) }
    }
}

//Test support
#if DEBUG
    extension FlagChangeNotifier {
        var flagObservers: [FlagChangeObserver] { return observers }

        convenience init(observers: [FlagChangeObserver]) {
            self.init()
            self.observers = observers
        }

        func notifyObservers(user: LDUser, oldFlags: [LDFlagKey: FeatureFlag], oldFlagSource: LDFlagValueSource, completion: @escaping () -> Void) {
            notifyObservers(user: user, oldFlags: oldFlags, oldFlagSource: oldFlagSource)
            DispatchQueue.main.async {
                completion()
            }
        }
    }
#endif
