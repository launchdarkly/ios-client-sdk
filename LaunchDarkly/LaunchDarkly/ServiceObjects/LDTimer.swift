import Foundation

protocol TimeResponding {
    var fireDate: Date? { get }

    init(withTimeInterval: TimeInterval, fireQueue: DispatchQueue, execute: @escaping () -> Void)
    func cancel()
}

final class LDTimer: TimeResponding {

    private (set) weak var timer: Timer?
    private let fireQueue: DispatchQueue
    private let execute: () -> Void
    private (set) var isCancelled: Bool = false
    var fireDate: Date? { timer?.fireDate }

    init(withTimeInterval timeInterval: TimeInterval, fireQueue: DispatchQueue = DispatchQueue.main, execute: @escaping () -> Void) {
        self.fireQueue = fireQueue
        self.execute = execute

        // the run loop retains the timer, so the property is weak to avoid a retain cycle. Setting the timer to a strong reference is important so that the timer doesn't get nil'd before it's added to the run loop.
        let timer = Timer(timeInterval: timeInterval, target: self, selector: #selector(timerFired), userInfo: nil, repeats: true)
        self.timer = timer
        RunLoop.main.add(timer, forMode: RunLoop.Mode.default)
    }

    deinit {
        timer?.invalidate()
    }

    @objc private func timerFired() {
        fireQueue.async { [weak self] in
            guard (self?.isCancelled ?? true) == false
            else { return }
            self?.execute()
        }
    }

    func cancel() {
        timer?.invalidate()
        isCancelled = true
    }
}
