//
//  LDTimer.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 1/17/19. +JMJ
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

protocol TimeResponding {
    var isRepeating: Bool { get }
    var fireDate: Date? { get }

    init(withTimeInterval: TimeInterval, repeats: Bool, fireQueue: DispatchQueue, execute: @escaping () -> Void)
    func cancel()
}

final class LDTimer: TimeResponding {

    weak private (set) var timer: Timer?
    private let fireQueue: DispatchQueue
    private let execute: () -> Void
    private (set) var isRepeating: Bool
    private (set) var isCancelled: Bool = false
    var fireDate: Date? {
        return timer?.fireDate
    }

    init(withTimeInterval timeInterval: TimeInterval, repeats: Bool, fireQueue: DispatchQueue = DispatchQueue.main, execute: @escaping () -> Void) {
        isRepeating = repeats
        self.fireQueue = fireQueue
        self.execute = execute

        // the run loop retains the timer, so the property is weak to avoid a retain cycle. Setting the timer to a strong reference is important so that the timer doesn't get nil'd before it's added to the run loop.
        let timer = Timer(timeInterval: timeInterval, target: self, selector: #selector(timerFired), userInfo: nil, repeats: repeats)
        self.timer = timer
        RunLoop.main.add(timer, forMode: RunLoop.Mode.default)
    }

    deinit {
        timer?.invalidate()
    }

    @objc private func timerFired() {
        fireQueue.async { [weak self] in
            guard (self?.isCancelled ?? true) == false
            else {
                return
            }
            self?.execute()
        }
    }

    func cancel() {
        timer?.invalidate()
        isCancelled = true
    }
}

#if DEBUG
extension LDTimer {
    var testFireQueue: DispatchQueue {
        return fireQueue
    }
}
#endif
