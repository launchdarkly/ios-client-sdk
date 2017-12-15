//
//  LDFlagChangeNotifyingSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 12/14/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
import Foundation
@testable import Darkly

final class LDFlagChangeNotifyingSpec: QuickSpec {
    override func spec() {

    }
}

extension FlagChangeNotifyingMock {
    func removeObserver(_ key: String, owner: LDFlagChangeOwner) {
        removeObserverCallCount += 1
        removeObserverReceivedArguments = ([key], owner)
    }

    func removeObserver(owner: LDFlagChangeOwner) {
        removeObserverCallCount += 1
        removeObserverReceivedArguments = ([], owner)
    }
}
