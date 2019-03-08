//
//  FlagChangeNotifyingMock.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 12/18/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
@testable import LaunchDarkly

extension FlagChangeNotifyingMock {
    func removeObserver(_ key: String, owner: LDObserverOwner) {
        removeObserverCallCount += 1
        removeObserverReceivedArguments = ([key], owner)
    }

    func removeObserver(owner: LDObserverOwner) {
        removeObserverCallCount += 1
        removeObserverReceivedArguments = ([], owner)
    }
}
