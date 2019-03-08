//
//  ErrorNotifier.swift
//  Darkly
//
//  Created by Mark Pokorny on 2/6/19. +JMJ
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

//sourcery: AutoMockable
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
        errorObservers = errorObservers.filter { (observer) in
            return observer.owner !== owner
        }
    }

    func notifyObservers(of error: Error) {
        removeOldObservers()
        errorObservers.forEach { (errorObserver) in
            errorObserver.errorHandler?(error)
        }
    }

    private func removeOldObservers() {
        errorObservers = errorObservers.filter { (errorObserver) in
            return errorObserver.owner != nil
        }
    }
}

#if DEBUG
extension ErrorNotifier {
    convenience init(observers: [ErrorObserver]? = nil) {
        self.init()
        guard let observers = observers, observers.isEmpty == false
        else {
            return
        }
        errorObservers.append(contentsOf: observers)
    }

    func erase(owner: LDObserverOwner) {
        for index in 0..<errorObservers.count {
            guard errorObservers[index].owner === owner
            else {
                continue
            }
            errorObservers[index].clearOwner()
        }
    }
}
#endif
