//
//  FlagsUnchangedObserver.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 3/6/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation

struct FlagsUnchangedObserver {
    weak private(set) var owner: LDObserverOwner?
    let flagsUnchangedHandler: LDFlagsUnchangedHandler?

    init(owner: LDObserverOwner, flagsUnchangedHandler: @escaping LDFlagsUnchangedHandler) {
        self.owner = owner
        self.flagsUnchangedHandler = flagsUnchangedHandler
    }
}
