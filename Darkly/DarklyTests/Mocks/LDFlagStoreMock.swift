//
//  LDFlagStoreMock.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 9/29/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

@testable import Darkly

final class LDFlagStoreMock: LDFlagMaintaining {
    func updateStore(newFlags: [String : Any], source: LDFlagValueSource) {

    }

    var replaceStoreCallCount = 0
    var replaceStoreCallParameters: (newFlags: [String: Any], source: LDFlagValueSource)?
    func replaceStore(newFlags: [String : Any], source: LDFlagValueSource) {
        replaceStoreCallCount += 1
        replaceStoreCallParameters = (newFlags, source)
    }

    func deleteFlag(name: String) {

    }

    init() { }
}
