//
//  LDFlagObserver.swift
//  Darkly
//
//  Created by Mark Pokorny on 8/18/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

struct FlagObserver {
    weak private(set) var owner: LDFlagChangeOwner?
    let flagKeys: [LDFlagKey]
    let flagChangeHandler: LDFlagChangeHandler?
    let flagCollectionChangeHandler: LDFlagCollectionChangeHandler?

    init(key: LDFlagKey, owner: LDFlagChangeOwner, changeObserver: @escaping LDFlagChangeHandler) {
        self.flagKeys = [key]
        self.owner = owner
        self.flagChangeHandler = changeObserver
        self.flagCollectionChangeHandler = nil
    }

    init(keys: [LDFlagKey], owner: LDFlagChangeOwner, collectionChangeObserver: @escaping LDFlagCollectionChangeHandler) {
        self.flagKeys = keys
        self.owner = owner
        self.flagChangeHandler = nil
        self.flagCollectionChangeHandler = collectionChangeObserver
    }
}
