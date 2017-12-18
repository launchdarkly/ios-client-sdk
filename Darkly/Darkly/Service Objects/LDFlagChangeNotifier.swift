//
//  LDFlagChangeNotifier.swift
//  Darkly
//
//  Created by Mark Pokorny on 8/18/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

//sourcery: AutoMockable
protocol FlagChangeNotifying {
    func addObserver(_ observer: LDFlagObserver)
    //sourcery: NoMock
    func removeObserver(_ key: LDFlagKey, owner: LDFlagChangeOwner)
    func removeObserver(_ keys: [LDFlagKey], owner: LDFlagChangeOwner)
    //sourcery: NoMock
    func removeObserver(owner: LDFlagChangeOwner)
    func notifyObservers(changedFlags: [LDFlagKey], user: LDUser, oldFlags: [LDFlagKey: Any])
}

class LDFlagChangeNotifier: FlagChangeNotifying {
    private var observers = [LDFlagObserver]()
    
    func addObserver(_ observer: LDFlagObserver) {
        
    }
    
    ///Removes any change handling closures for flag.key from owner
    func removeObserver(_ key: LDFlagKey, owner: LDFlagChangeOwner) {
        
    }
    
    ///Removes any change handling closures for flag keys from owner
    func removeObserver(_ keys: [LDFlagKey], owner: LDFlagChangeOwner) {
        
    }
    
    ///Removes all change handling closures from owner
    func removeObserver(owner: LDFlagChangeOwner) {
        
    }
    
    func notifyObservers(changedFlags: [LDFlagKey], user: LDUser, oldFlags: [LDFlagKey: Any]) {
        
    }
    
    private func removeOldObservers() {
        
    }
}
