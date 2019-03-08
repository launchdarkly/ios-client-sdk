//
//  LDFlagObserver.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 8/18/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

struct FlagChangeObserver {
    weak private(set) var owner: LDObserverOwner?
    let flagKeys: [LDFlagKey]
    let flagChangeHandler: LDFlagChangeHandler?
    let flagCollectionChangeHandler: LDFlagCollectionChangeHandler?

    init(key: LDFlagKey, owner: LDObserverOwner, flagChangeHandler: @escaping LDFlagChangeHandler) {
        self.flagKeys = [key]
        self.owner = owner
        self.flagChangeHandler = flagChangeHandler
        self.flagCollectionChangeHandler = nil
    }

    init(keys: [LDFlagKey], owner: LDObserverOwner, flagCollectionChangeHandler: @escaping LDFlagCollectionChangeHandler) {
        self.flagKeys = keys
        self.owner = owner
        self.flagChangeHandler = nil
        self.flagCollectionChangeHandler = flagCollectionChangeHandler
    }
}

extension FlagChangeObserver: Equatable {
    static func == (lhs: FlagChangeObserver, rhs: FlagChangeObserver) -> Bool {
        return lhs.flagKeys == rhs.flagKeys && lhs.owner === rhs.owner
    }
}
