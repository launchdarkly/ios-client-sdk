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
    let flagKeys: LDFlagKeyList
    let handler: LDFlagChangeObserver<LDFlagType>
}
