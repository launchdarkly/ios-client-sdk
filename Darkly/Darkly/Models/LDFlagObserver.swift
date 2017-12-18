//
//  LDFlagObserver.swift
//  Darkly
//
//  Created by Mark Pokorny on 8/18/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

struct LDFlagObserver {
    weak private(set) var owner: LDFlagChangeOwner?
    let flagKeys: [LDFlagKey]
    let flagChangeObserver: LDFlagChangeObserver?
    let flagCollectionChangeObserver: LDFlagCollectionChangeObserver?

    init(key: LDFlagKey, owner: LDFlagChangeOwner, changeObserver: @escaping LDFlagChangeObserver) {
        self.flagKeys = [key]
        self.owner = owner
        self.flagChangeObserver = changeObserver
        self.flagCollectionChangeObserver = nil
    }

    init(keys: [LDFlagKey], owner: LDFlagChangeOwner, collectionChangeObserver: @escaping LDFlagCollectionChangeObserver) {
        self.flagKeys = keys
        self.owner = owner
        self.flagChangeObserver = nil
        self.flagCollectionChangeObserver = collectionChangeObserver
    }
}
