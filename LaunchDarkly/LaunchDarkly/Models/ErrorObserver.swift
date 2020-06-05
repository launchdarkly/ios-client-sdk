//
//  ErrorObserver.swift
//  Darkly
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

struct ErrorObserver {
    private(set) var key: UUID
    private(set) weak var owner: LDObserverOwner?
    var errorHandler: LDErrorHandler?

    init(owner: LDObserverOwner, errorHandler: @escaping LDErrorHandler) {
        key = UUID()
        self.owner = owner
        self.errorHandler = errorHandler
    }
}

extension ErrorObserver: Equatable {
    static func == (lhs: ErrorObserver, rhs: ErrorObserver) -> Bool {
        lhs.key == rhs.key && lhs.owner === rhs.owner
    }
}

#if DEBUG
extension ErrorObserver {
    mutating func clearOwner() {
        owner = nil
    }
}
#endif
