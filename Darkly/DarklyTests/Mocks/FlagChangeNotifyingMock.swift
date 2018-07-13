//
//  FlagChangeNotifyingMock.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 12/18/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation
@testable import LaunchDarkly

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
