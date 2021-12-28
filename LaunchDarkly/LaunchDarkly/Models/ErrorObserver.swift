//
//  ErrorObserver.swift
//  Darkly
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

struct ErrorObserver {
    weak var owner: LDObserverOwner?
    let errorHandler: LDErrorHandler

    init(owner: LDObserverOwner, errorHandler: @escaping LDErrorHandler) {
        self.owner = owner
        self.errorHandler = errorHandler
    }
}
