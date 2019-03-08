//
//  ErrorObserver.swift
//  Darkly
//
//  Created by Mark Pokorny on 2/6/19. +JMJ
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

struct ErrorObserver {
    private(set) var key: UUID
    weak private(set) var owner: LDObserverOwner?
    var errorHandler: LDErrorHandler?

    init(owner: LDObserverOwner, errorHandler: @escaping LDErrorHandler) {
        key = UUID()
        self.owner = owner
        self.errorHandler = errorHandler
    }
}

extension ErrorObserver: Equatable {
    static func == (lhs: ErrorObserver, rhs: ErrorObserver) -> Bool {
        return lhs.key == rhs.key && lhs.owner === rhs.owner
    }
}

#if DEBUG
extension ErrorObserver {
    mutating func clearOwner() {
        owner = nil
    }
}
#endif
