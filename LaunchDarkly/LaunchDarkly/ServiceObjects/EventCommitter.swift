import Foundation
import OSLog

/// How many events the SDK accepted and then lost for good, which `DirectEventProcessor` and its `EventCommitter` both
/// add to.
///
/// A batch LaunchDarkly refuses is kept and retried, so it is not a loss, unless the refusal is a second refusal of the
/// payload in a row. Otherwise what is lost is what the store never received: an event or a summary that could not be
/// serialized when it was committed, or that serialized too large to store. A delivery that finds nothing to send cannot
/// tell those apart from events that arrived, so without this it would report success for them.
///
/// A count rather than a flag. Each delivery takes the count as it closes its batch, and answers for the losses up to that
/// mark, so a loss is told to the caller whose delivery it happened before rather than to whichever delivery answers next.
final class LostEventCount {
    private let lock = UnfairLock()
    /// Only to be used while holding `lock`.
    private var count: UInt64 = 0

    var value: UInt64 { lock.withLock { count } }

    func add(_ events: Int) {
        lock.withLock { count += UInt64(events) }
    }
}

/// Where `DirectEventProcessor` accepts events, holds them and commits them to the store.
///
/// Recording an event summarizes it and, if it has to be delivered in full, holds it as an `Event`. Nothing is encoded
/// on the thread that recorded it; a commit turns the whole held run into bytes at once. So an evaluation of an
/// untracked flag costs a counter update, and an evaluation of a tracked one costs that plus an array append.
///
/// Where the line falls is between the events an application asked for by name and the ones it did not. At `.immediate`
/// recording a custom or identify event is a *commit point*, because an application reporting something it chose to
/// report is saying this matters more than the microseconds it costs, and the crash it describes may be moments away. A
/// commit takes the whole held run with it, so the exposures leading up to the error go down alongside it. Everything
/// else is committed once `pendingCommitThreshold` events have accumulated, when a delivery starts, on entering the
/// background, or on `flush`.
///
/// Which of the two `track` gets is the application's choice, through `LDConfig.eventPersistence`. Only at `.immediate`
/// can `track` promise the event is on disk by the time it returns; at `.deferred` it costs what an evaluation does. At
/// `.disabled` nothing commits early: the held run waits for the delivery, which encodes it.
///
/// Threads. Recording runs on whichever thread evaluated or tracked. Commits run on `commitQueue`, or on the caller's
/// thread at a commit point, one at a time under `commitLock`. A delivery commits too, before it closes a batch.
final class EventCommitter {
    /// How many full events may be held unencoded before one of them pays for a commit.
    ///
    /// It sets two things at once. The first is how many evaluations a termination can take -- not everything a crash
    /// could take, since an application that flushes on its way out commits the whole run, but the window for the
    /// terminations that run nothing on the way out, such as the system reclaiming a backgrounded process. Recording a
    /// custom or identify event at `.immediate` closes it too, because that commits.
    ///
    /// The second is what a commit point usually costs, since it encodes whatever is held before returning. The commit
    /// queue keeps the run drained, so the common case is far below this; raising it trades that cost against the
    /// number of writes.
    ///
    /// Neither is a ceiling. Reaching this only schedules a commit, and recording does not wait for it, so where events
    /// arrive faster than the commit queue encodes them, or the queue is starved, the run grows up to the event
    /// capacity, and the next commit point encodes all of it.
    ///
    /// It is the only thing that writes events no caller asked to have written. The store writes only when told to, so
    /// every staged byte reaches the disk through a commit that started here, at a commit point, or at a delivery.
    static let pendingCommitThreshold = 32

    // MARK: Set in init and never changed

    private let store: EventStoring
    private let persistence: EventPersistence
    private let logger: OSLog
    private let diagnosticCache: DiagnosticCaching?
    private let lostEvents: LostEventCount

    /// How many events the SDK will hold in total, across `pending` and the store.
    private let eventCapacity: Int

    /// Where a commit runs when no caller is waiting on it.
    private let commitQueue: DispatchQueue

    /// Its summarizer is guarded by `recordLock`, and its encoders are reached only under `commitLock`.
    private let eventBuffer: OutboundEventBuffer

    // MARK: Guarded by commitLock

    /// Held for the whole of a commit, so that only one runs at a time.
    ///
    /// This is what a commit point's guarantee rests on. Without it a commit already in flight could take the caller's
    /// event out of `pending` before the caller got there, leaving the caller nothing to write and returning while
    /// those bytes were still being produced somewhere else. Waiting here instead means that when the call returns the
    /// event is on disk, whichever commit put it there. It also keeps two encoders from staging their runs in
    /// whichever order they happened to finish.
    ///
    /// Taken before `recordLock` and before anything the store locks, never after.
    private let commitLock = UnfairLock()

    /// The last recording a finished commit covered. Only to be used while holding `commitLock`.
    ///
    /// This is what makes concurrent `.immediate` commit points a group commit. The first caller's commit takes every
    /// recording made before it took the run, including those of callers now waiting behind it. They find their
    /// recordings covered and return, and the next caller still uncovered commits everything that arrived in the
    /// meantime. Without it each waiter committed again in turn.
    private var committedSequence: UInt64 = 0

    // MARK: Guarded by recordLock

    /// Guards everything one recording writes: the held events and the summarizer.
    ///
    /// One evaluation can produce a counter, a full event and a debug event, and the three have to land together. Taken
    /// separately, a commit landing between them splits one evaluation across two payloads.
    ///
    /// Held for the appends and the handover of the run, never across the encoder or a syscall. It is a lock rather
    /// than a queue because it is taken once per evaluation, and a `DispatchQueue.sync` costs enough at that rate to be
    /// worth avoiding: the same measurement that made `EvaluationExposureDeduper` a lock applies here.
    private let recordLock = UnfairLock()

    /// Full events recorded but not yet encoded. Only to be used while holding `recordLock`.
    ///
    /// Held rather than encoded because encoding early would not make them durable: the store stages bytes into memory
    /// too, and only a commit reaches the file. Both forms are equally lost to a crash, so the encode may as well
    /// happen where it is cheapest.
    private var pending: [Event] = []

    /// Numbers every recording, so a caller at a commit point can tell whether a commit has already covered it. Only to
    /// be used while holding `recordLock`.
    private var recordedSequence: UInt64 = 0

    /// Whether a commit is already queued, so a run of recordings past the threshold asks for one write rather than
    /// one each. Only to be used while holding `recordLock`.
    private var isCommitScheduled = false

    // MARK: Guarded by responseDateLock

    /// When LaunchDarkly last answered a post, by its own clock, which is how long debug events go on for.
    var lastEventResponseDate: Date {
        responseDateLock.withLock { responseDate }
    }

    /// Its own lock rather than `recordLock`, since an evaluation reads it before it takes that one.
    private let responseDateLock = UnfairLock()
    /// Only to be used while holding `responseDateLock`.
    private var responseDate = Date()

    init(config: LDConfig,
         store: EventStoring,
         encoding: OutboundEventBuffer.Encoding,
         commitQueue: DispatchQueue,
         diagnosticCache: DiagnosticCaching?,
         lostEvents: LostEventCount) {
        self.store = store
        self.persistence = config.eventPersistence
        self.logger = config.logger
        self.diagnosticCache = diagnosticCache
        self.lostEvents = lostEvents
        self.eventCapacity = config.eventCapacity
        self.commitQueue = commitQueue
        self.eventBuffer = OutboundEventBuffer(config: config, encoding: encoding)
    }

    // MARK: Recording

    /// Records an event, and at `.immediate` commits before returning if it is a commit point.
    ///
    /// At `.deferred` a custom or identify event writes nothing itself (durability §13.3), and is committed with what
    /// is held at the pending threshold, a flush, a delivery or entering the background. A commit per call would cost
    /// an application that tracks every few seconds one encode and write per event, each taking `recordLock` from the
    /// threads evaluating flags and the store's locks from delivery.
    func record(_ event: Event) {
        var sequence: UInt64 = 0
        let (dropped, needsCommit) = recordLock.withLock { () -> (Bool, Bool) in
            recordedSequence += 1
            sequence = recordedSequence
            return (!admitToPending(event), pending.count >= EventCommitter.pendingCommitThreshold)
        }

        if dropped {
            reportDropped()
        }
        if persistence == .immediate && EventCommitter.isCommitPoint(event.kind) {
            commitThrough(sequence)
        } else if needsCommit {
            scheduleCommitWherePersisting()
        }
    }

    // swiftlint:disable:next function_parameter_count
    func recordFlagEvaluationEvents(flagKey: LDFlagKey,
                                    value: LDValue,
                                    defaultValue: LDValue,
                                    featureFlag: FeatureFlag?,
                                    context: LDContext,
                                    includeReason: Bool) {
        let recordingFeatureEvent = featureFlag?.trackEvents == true
        let recordingDebugEvent = featureFlag?.shouldCreateDebugEvents(lastEventReportResponseTime: lastEventResponseDate) ?? false
        // Built before the lock is taken, so that the critical section is only the writes.
        let featureEvent = recordingFeatureEvent ? FeatureEvent(key: flagKey, context: context, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason, isDebug: false) : nil
        let debugEvent = recordingDebugEvent ? FeatureEvent(key: flagKey, context: context, value: value, defaultValue: defaultValue, featureFlag: featureFlag, includeReason: includeReason, isDebug: true) : nil

        var dropped = 0
        let (counted, needsCommit) = recordLock.withLock { () -> (Bool, Bool) in
            recordedSequence += 1
            let counted = eventBuffer.summarize(flagKey: flagKey, reportedValue: value, featureFlag: featureFlag, defaultValue: defaultValue, context: context)
            if let featureEvent, !admitToPending(featureEvent) { dropped += 1 }
            if let debugEvent, !admitToPending(debugEvent) { dropped += 1 }
            return (counted, pending.count >= EventCommitter.pendingCommitThreshold)
        }

        // A refused evaluation is a loss like a refused event, since nothing later reconstructs its counter. Its full
        // event is still decided by the event capacity alone.
        if !counted {
            diagnosticCache?.incrementDroppedEventCount()
        }
        for _ in 0..<dropped {
            reportDropped()
        }
        // Deliberately no commit point. An evaluation is expected to cost what bookkeeping costs, and it is usually the
        // main thread doing it; where events are persisted, the run is encoded and written on the commit queue once
        // enough of them have piled up, and at `.immediate` the next event recorded at a commit point makes them
        // durable along with itself.
        if needsCommit {
            scheduleCommitWherePersisting()
        }
    }

    /// Moves the response date forwards only, so that an older answer arriving late does not keep debug events going
    /// past the date a newer one set.
    func recordResponseDate(_ serverTime: Date) {
        responseDateLock.withLock {
            if serverTime > responseDate {
                responseDate = serverTime
            }
        }
    }

    /// Adds an event to `pending` for the next commit to encode, returning false if the SDK is already full. Requires
    /// `recordLock`.
    ///
    /// Capacity is consulted before anything else, so an event that will not be kept is never encoded. That ordering is
    /// what bounds an application re-evaluating a tracked flag in a render loop: once the limit is reached an
    /// evaluation costs no more than its summary counter, however fast the loop runs.
    ///
    /// The byte capacity can only be consulted as far as whether any room is left, since the event has no size until
    /// it is encoded; whether it fits is decided when it is staged.
    private func admitToPending(_ event: Event) -> Bool {
        recordLock.assertOwned()
        guard store.admitsEvent(heldElsewhere: pending.count, capacity: eventCapacity)
        else { return false }

        pending.append(event)
        return true
    }

    private func reportDropped() {
        os_log("%s aborted. Event store is full", log: logger, type: .debug, typeName(and: #function))
        diagnosticCache?.incrementDroppedEventCount()
    }

    /// Records the loss of an event the SDK accepted and then could not keep, which no later attempt recovers.
    private func reportLost() {
        os_log("%s dropping an event the store would not take", log: logger, type: .error, typeName(and: #function))
        diagnosticCache?.incrementDroppedEventCount()
        lostEvents.add(1)
    }

    /// Counts as lost the events of an open log a close found gone.
    private func reportVanished(_ events: Int) {
        guard events > 0
        else { return }
        os_log("%s %d stored event(s) were deleted before they could be sent", log: logger, type: .error, typeName(and: #function), events)
        lostEvents.add(events)
    }

    // MARK: Committing

    /// Queues a commit where there is a disk for it to reach.
    ///
    /// Without persistence a commit makes nothing durable. All it would do is move the encode into the middle of the
    /// application's evaluations, where it competes with them for the CPU and splits their counters across summaries;
    /// left alone, the run waits for the delivery, which encodes it anyway, and capacity still bounds how much is held.
    private func scheduleCommitWherePersisting() {
        if store.isPersisting {
            scheduleCommit()
        }
    }

    /// Queues a commit unless one is already queued, so a run of recordings asks for one write rather than one each.
    private func scheduleCommit() {
        let alreadyScheduled = recordLock.withLock { () -> Bool in
            defer { isCommitScheduled = true }
            return isCommitScheduled
        }
        guard !alreadyScheduled
        else { return }

        commitQueue.async { [weak self] in
            guard let self
            else { return }
            // Cleared before the commit rather than after it, so that an event held while this one is in flight can ask
            // for another commit instead of finding one apparently already on its way.
            self.recordLock.withLock { self.isCommitScheduled = false }

            self.commitRecordedEvents()
        }
    }

    /// Writes on the caller's thread at `.deferred` as well as at `.immediate`, unlike `track` and `identify`.
    ///
    /// A flush is what an application calls when it is about to end the process on purpose, and entering the background
    /// is when the system is most likely to end it; a write only queued is one the process may end before. Deferring is
    /// for the recordings an application makes all the time, which neither is. Where nothing persists, a commit makes
    /// nothing durable, and is left to the delivery.
    func commitWherePersisting() {
        if persistence == .immediate || store.isPersisting {
            commitThrough(recordLock.withLock { recordedSequence })
        }
    }

    /// Commits everything recorded so far for `flushAtClose()`, waiting for it no longer than `budget`.
    ///
    /// On `commitQueue` rather than the caller's thread, which for an application closing the client is usually the
    /// main one. Each step of a commit can block for as long as the device takes: on `commitLock` behind a commit
    /// stalled on the disk, on the store's I/O lock, and on the write itself. A commit that outlasts the budget is left
    /// to finish, and the delivery queued after it waits for it on the delivery queue, not on the caller's thread.
    /// Where nothing persists there is nothing to write: the final delivery encodes what it sends.
    func commitWithinBudget(_ budget: TimeInterval) {
        guard store.isPersisting
        else { return }
        let through = recordLock.withLock { recordedSequence }
        let committed = DispatchSemaphore(value: 0)
        commitQueue.async {
            self.commitThrough(through)
            committed.signal()
        }
        if committed.wait(timeout: .now() + budget) == .timedOut {
            os_log("%s gave up waiting for the final event commit after %dms; it continues in the background", log: logger, type: .info, typeName(and: #function), Int(budget * 1000))
        }
    }

    /// `commitWherePersisting()` queued on `commitQueue` rather than written on the caller's thread, for a flush whose
    /// caller has a deadline.
    ///
    /// `flushAndWait` can only hold to its timeout once every environment has handed back, and each step of a commit
    /// can block for as long as the device takes: on `commitLock` behind a commit stalled on the disk, on the store's
    /// I/O lock, and on the write itself. Queued rather than left to the delivery, because the delivery queue can be
    /// held by a request and its retry long after the caller stopped waiting, while `commitQueue` never waits on the
    /// network. The answer still covers the write: the delivery commits again before it sends, so `true` means the
    /// events were written first. A commit still running when the caller stops waiting is left to finish.
    func queueCommitWherePersisting() {
        if persistence == .immediate || store.isPersisting {
            scheduleCommit()
        }
    }

    /// Encodes everything recorded since the last commit, stages it, and commits it.
    ///
    /// The run and the counters are taken in one critical section, so that an evaluation's counter and its full event
    /// are staged by the same commit, and encoded outside it, so recording does not wait on the encoder.
    func commitRecordedEvents() {
        commitLock.withLock { encodeAndCommitPending() }
    }

    /// Commits unless a finished commit already covers recording `sequence`, checked once the lock is held, since the
    /// commit a caller waited behind is the one most likely to have covered it.
    private func commitThrough(_ sequence: UInt64) {
        commitLock.withLock {
            guard committedSequence < sequence
            else { return }
            encodeAndCommitPending()
        }
    }

    /// Commits what is held and closes it into a batch, as one step with respect to other commits.
    ///
    /// Closing takes everything staged so far, and a commit stages its run one event at a time, so a commit running
    /// between the two would be closed partway: an evaluation's event in this batch and its summary in the next.
    ///
    /// - Returns: the loss count as of the close, which is the mark this delivery answers for, and whether the close
    ///   took every committed event into a batch. Both taken under the same lock, so they cover the closed batch and
    ///   nothing a later commit does.
    func commitAndCloseBatch() -> (lossMark: UInt64, closedEverything: Bool) {
        commitLock.withLock {
            encodeAndCommitPending()
            _ = store.closeBatch()
            reportVanished(store.takeVanishedLogEvents())
            return (lostEvents.value, !store.holdsUnclosedEvents)
        }
    }

    /// `commitAndCloseBatch()` for a pass that found an earlier batch blocked, and so closes nothing.
    ///
    /// - Returns: the loss count as of the commit.
    func commitLeavingTheLogOpen() -> UInt64 {
        commitLock.withLock {
            encodeAndCommitPending()
            // A commit that fills the log closes it, and can find it gone.
            reportVanished(store.takeVanishedLogEvents())
            return lostEvents.value
        }
    }

    /// Requires `commitLock`.
    private func encodeAndCommitPending() {
        commitLock.assertOwned()
        var through: UInt64 = 0
        let (run, summaries) = recordLock.withLock { () -> ([Event], [(tracker: FlagRequestTracker, context: LDContext)]) in
            let run = pending
            pending = []
            let summaries = eventBuffer.takeSummaries()
            // Reserved in the same critical section the run leaves `pending` in, so capacity counts it in one place or
            // the other throughout the encode.
            store.reserve(run.count)
            through = recordedSequence
            return (run, summaries)
        }

        stage(run)
        store.releaseReservations()
        stageSummaries(summaries)
        store.commit()
        committedSequence = through
    }

    /// Encodes the held events as one run and stages the bytes.
    ///
    /// Staging uses the reservation taken with the run rather than checking capacity, because the decision to keep
    /// these events was made when they were held, and refusing them here would drop events the SDK has already counted
    /// as accepted.
    ///
    /// Requires `commitLock`: two threads draining separate runs would stage them in whichever order they finished
    /// encoding, which is not the order they were recorded in.
    private func stage(_ run: [Event]) {
        commitLock.assertOwned()
        for event in run {
            guard let encoded = eventBuffer.encode(event)
            else {
                reportLost()
                continue
            }
            // The event capacity is bypassed here, so what is left is an event too large for a frame or for the bytes
            // left in the store, which were not known until now. Either way it was accepted and is not kept.
            if !store.stageReserved(encoded) {
                reportLost()
            }
        }
    }

    /// Whether recording this kind of event at `.immediate` should encode and write the held run before it returns.
    ///
    /// Custom and identify events are recorded because the application did something it chose to report, which is both
    /// rare enough to afford a write and the moment it is least acceptable to lose. Evaluations are neither.
    private static func isCommitPoint(_ kind: Event.Kind) -> Bool {
        switch kind {
        case .custom, .identify: return true
        case .feature, .debug, .summary: return false
        }
    }

    /// Turns the counters taken with the run into summary events and stages them.
    ///
    /// Counters live only in memory, so a crash takes whatever has not been summarized with it. Summarizing at each
    /// commit point rather than only at a delivery is what bounds that loss, and it costs nothing in accuracy:
    /// LaunchDarkly sums the counters of every summary it receives, so a session that produced several summaries is
    /// counted the same as one that produced a single summary covering the same evaluations.
    private func stageSummaries(_ summaries: [(tracker: FlagRequestTracker, context: LDContext)]) {
        for encoded in summaries.flatMap({ eventBuffer.encodeSummary($0) }) {
            guard let encoded = encoded
            else {
                reportLost()
                continue
            }
            // Summaries are an aggregate of evaluations that were already counted, so refusing one for capacity would
            // lose evaluations the SDK promised to report rather than shed new load. Only the byte capacity refuses
            // one, once even the room held back for summaries is used up, since nothing else bounds how many are
            // staged while delivery keeps failing.
            if !store.stage(encoded, bypassingCapacity: true) {
                reportLost()
            }
        }
    }
}

extension EventCommitter: TypeIdentifying { }

#if DEBUG
    extension EventCommitter {
        /// Full events accepted but not yet handed to a commit.
        var pendingEventsForTesting: [Event] {
            recordLock.withLock { pending }
        }

        func setLastEventResponseDate(_ date: Date) {
            responseDateLock.withLock { responseDate = date }
        }

        /// Reads the summarizer under `recordLock`, which a scheduled commit may be holding to take its counters.
        func withContextSummarizer<T>(_ read: (ContextSummarizer) -> T) -> T {
            recordLock.withLock { read(eventBuffer.contextSummarizer) }
        }
    }
#endif
