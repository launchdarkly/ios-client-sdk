//
//  FlagChangeNotifyingMock.swift
//  LaunchDarklyTests
//
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
