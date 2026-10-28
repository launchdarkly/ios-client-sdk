import Foundation

/// Hears when the flag synchronizer's first request after going online starts and how it ended, so that events can
/// give way to it.
protocol FlagRequestListening: AnyObject {
    func flagRequestStarted()
    func flagRequestSettled(_ outcome: FlagRequestOutcome)
}

enum FlagRequestOutcome {
    case loaded
    case failed
    /// The synchronizer went offline, or was replaced, before an answer came.
    case stopped
}

/// Whether a flag request is in flight, and the waits events make for it.
///
/// Flag values decide what the application shows, and events only report on it afterwards. So at launch, and whenever
/// the SDK sends a backlog on its own, events wait for the flag request rather than compete with it for the network.
final class FlagTraffic {
    /// How long events give way.
    struct Timings {
        static let specified = Timings(launchFloor: 2, launchCap: 10, gap: 1, flagRequestWait: 10)
        /// No waits at all, for tests about something else.
        static let noWaits = Timings(launchFloor: 0, launchCap: 0, gap: 0, flagRequestWait: 0)

        /// The soonest after first going online that a previous run's events are sent, whatever the flag request is
        /// doing. It gives the application's own startup traffic the network first, and is short enough for an
        /// application that dies a few seconds after every launch to still send them.
        let launchFloor: TimeInterval
        /// The longest after first going online that a previous run's events wait for the first flag request: the
        /// default connection timeout, by which a request that has not answered has most likely failed.
        let launchCap: TimeInterval
        /// The least time between one paced batch's answer and the next batch's request.
        let gap: TimeInterval
        /// The longest a paced batch waits for a flag request in flight, so that a hung one cannot stop delivery.
        let flagRequestWait: TimeInterval
    }

    /// One batch waiting for its turn.
    private final class Turn {
        let gapEnds: DispatchTime
        let flagWait: TimeInterval
        let isStopped: () -> Bool
        let proceed: () -> Void
        /// When it stops waiting on the flag request, set once the gap has passed with one in flight. Only to be used
        /// while holding the lock.
        var flagWaitEnds: DispatchTime?

        init(gapEnds: DispatchTime, flagWait: TimeInterval, isStopped: @escaping () -> Bool, proceed: @escaping () -> Void) {
            self.gapEnds = gapEnds
            self.flagWait = flagWait
            self.isStopped = isStopped
            self.proceed = proceed
        }
    }

    private let lock = UnfairLock()
    // Only to be used while holding `lock`.
    private var inFlight = false
    /// How the last flag request ended, or nil if none has.
    private var lastOutcome: FlagRequestOutcome?
    private var turns: [Turn] = []

    func started() {
        lock.withLock { inFlight = true }
    }

    func settled(_ outcome: FlagRequestOutcome) {
        lock.withLock {
            inFlight = false
            lastOutcome = outcome
        }
        checkTurns()
    }

    /// Has the batches waiting look at whether they were stopped again.
    func wake() {
        checkTurns()
    }

    /// Why the launch gate may open, once its floor has passed, or nil while it waits on the flag request.
    ///
    /// - Parameters:
    ///   - capReached: whether the cap has passed, after which it waits on nothing
    ///   - cap: the cap, for saying so
    func launchGateReason(capReached: Bool, cap: TimeInterval) -> String? {
        lock.withLock {
            guard inFlight
            else {
                switch lastOutcome {
                case .loaded: return "flags loaded"
                case .failed: return "the flag request failed"
                case .stopped, nil: return "no flag request at launch"
                }
            }
            return capReached ? "waiting \(Int(cap * 1000))ms for flags" : nil
        }
    }

    /// Calls `proceed`, on a global queue, once `gapEnds` has passed and then no flag request is in flight, waiting on
    /// one for no longer than `flagWait`; or at once when `isStopped` says so. `isStopped` is asked outside this
    /// object's lock, so it may take a lock of its own.
    func awaitTurn(gapEnds: DispatchTime, flagWait: TimeInterval, isStopped: @escaping () -> Bool, then proceed: @escaping () -> Void) {
        let turn = Turn(gapEnds: gapEnds, flagWait: flagWait, isStopped: isStopped, proceed: proceed)
        lock.withLock { turns.append(turn) }
        DispatchQueue.global().asyncAfter(deadline: gapEnds) { [weak self] in self?.checkTurns() }
        checkTurns()
    }

    private func checkTurns() {
        let now = DispatchTime.now()
        var due: [Turn] = []
        var waiting: [Turn] = []
        var deadlines: [DispatchTime] = []
        lock.withLock {
            for turn in turns {
                guard now >= turn.gapEnds
                else {
                    waiting.append(turn)
                    continue
                }
                guard inFlight
                else {
                    due.append(turn)
                    continue
                }
                if turn.flagWaitEnds == nil {
                    let ends = now + turn.flagWait
                    turn.flagWaitEnds = ends
                    deadlines.append(ends)
                }
                if let ends = turn.flagWaitEnds, now >= ends {
                    due.append(turn)
                } else {
                    waiting.append(turn)
                }
            }
        }
        due += waiting.filter { $0.isStopped() }
        for deadline in deadlines {
            DispatchQueue.global().asyncAfter(deadline: deadline) { [weak self] in self?.checkTurns() }
        }
        for turn in due {
            // Two checks can find the same turn due; only the one that takes it proceeds.
            let taken = lock.withLock { () -> Bool in
                guard let index = turns.firstIndex(where: { $0 === turn })
                else { return false }
                turns.remove(at: index)
                return true
            }
            if taken {
                DispatchQueue.global().async(execute: turn.proceed)
            }
        }
    }
}
