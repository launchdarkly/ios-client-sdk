//
//  ErrorNotifier.swift
//  Darkly
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

// sourcery: autoMockable
protocol ErrorNotifying {
    func addErrorObserver(_ observer: ErrorObserver)
    func removeObservers(for owner: LDObserverOwner)
    func notifyObservers(of error: Error)
}

final class ErrorNotifier: ErrorNotifying {
    private(set) var errorObservers = [ErrorObserver]()

    func addErrorObserver(_ observer: ErrorObserver) {
        errorObservers.append(observer)
    }

    func removeObservers(for owner: LDObserverOwner) {
        errorObservers.removeAll { $0.owner === owner }
    }

    func notifyObservers(of error: Error) {
        removeOldObservers()
        errorObservers.forEach { $0.errorHandler(error) }
    }

    private func removeOldObservers() {
        errorObservers = errorObservers.filter { $0.owner != nil }
    }
}
