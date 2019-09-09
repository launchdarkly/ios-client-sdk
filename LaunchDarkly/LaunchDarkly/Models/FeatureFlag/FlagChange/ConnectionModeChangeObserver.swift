//
//  ConnectionModeChangeObserver.swift
//  LaunchDarkly
//
//  Created by Joe Cieslik on 8/29/19.
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

struct ConnectionModeChangedObserver {
    weak private(set) var owner: LDObserverOwner?
    let connectionModeChangedHandler: LDConnectionModeChangedHandler?
    
    init(owner: LDObserverOwner, connectionModeChangedHandler: @escaping LDConnectionModeChangedHandler) {
        self.owner = owner
        self.connectionModeChangedHandler = connectionModeChangedHandler
    }
}
