//
//  ConnectionModeChangeObserver.swift
//  LaunchDarkly
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

struct ConnectionModeChangedObserver {
    private(set) weak var owner: LDObserverOwner?
    let connectionModeChangedHandler: LDConnectionModeChangedHandler

    init(owner: LDObserverOwner, connectionModeChangedHandler: @escaping LDConnectionModeChangedHandler) {
        self.owner = owner
        self.connectionModeChangedHandler = connectionModeChangedHandler
    }
}
