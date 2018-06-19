//
//  FlagsUnchangedObserver.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 3/6/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation

struct FlagsUnchangedObserver {
    weak private(set) var owner: LDFlagChangeOwner?
    let flagsUnchangedHandler: LDFlagsUnchangedHandler?

    init(owner: LDFlagChangeOwner, flagsUnchangedHandler: @escaping LDFlagsUnchangedHandler) {
        self.owner = owner
        self.flagsUnchangedHandler = flagsUnchangedHandler
    }
}
