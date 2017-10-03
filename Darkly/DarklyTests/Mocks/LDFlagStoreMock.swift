//
//  LDFlagStoreMock.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 9/29/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

@testable import Darkly

//TODO: Replace with sourcery mock
final class LDFlagStoreMock: LDFlagMaintaining {
    var replaceStoreCallCount = 0
    var replaceStoreCallParameters: (newFlags: [String: Any]?, source: LDFlagValueSource, completion: (() -> Void)?)?
    func replaceStore(newFlags: [String : Any]?, source: LDFlagValueSource, completion: (() -> Void)?) {
        replaceStoreCallCount += 1
        replaceStoreCallParameters = (newFlags, source, completion)
        completion?()
    }

    func updateStore(newFlags: [String : Any], source: LDFlagValueSource, completion: (() -> Void)?) {

    }

    func deleteFlag(name: String, completion: (() -> Void)?) {

    }

    init() { }
}
