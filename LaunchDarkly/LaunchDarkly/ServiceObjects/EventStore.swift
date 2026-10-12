import Foundation
import OSLog

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// A group of encoded events that has been closed off for delivery.
///
/// The identifier doubles as the payload ID sent to LaunchDarkly, so a batch that is retried after the process died
/// mid-delivery is recognized upstream as the same delivery rather than counted twice.
struct EventBatch: Equatable {
    let payloadId: String
    let eventCount: Int
}

protocol EventStoring {
    /// Events counted against capacity: those recorded and not yet accepted by LaunchDarkly, whether they are reserved
    /// while being encoded, staged in memory, written to the open log, or sitting in a closed batch -- except a batch
    /// whose request is out.
    ///
    /// A batch being sent is left out so that a flush makes room as soon as it sends, as it did when events were only
    /// held in memory; otherwise an event recorded while the request is out is refused for a batch LaunchDarkly may
    /// already have. A send that fails puts the batch back, so a full store can briefly hold capacity plus that batch.
    var pendingEventCount: Int { get }

    /// Whether a commit writes anything, which is false where persistence is off and once a write has failed and the
    /// store has given up on it.
    var isPersisting: Bool { get }

    /// Stages an already encoded event, returning false if it was dropped because `capacity` is reached.
    ///
    /// Staging is a copy into a buffer; `commit()` is what makes the event outlive the process.
    func stage(_ encodedEvent: Data, bypassingCapacity: Bool) -> Bool

    /// Counts events that have been accepted but are still being encoded, so capacity sees them until they are staged.
    func reserve(_ events: Int)

    /// Stages an event using up one reservation, rather than checking capacity again.
    func stageReserved(_ encodedEvent: Data) -> Bool

    /// Gives back every reservation not used up by `stageReserved(_:)`, such as one for an event that failed to encode.
    func releaseReservations()

    /// Hands every staged byte to the kernel, so that the events recorded so far survive the process dying.
    func commit()

    /// Commits, then closes the open log into a batch to deliver, and whatever is still staged in memory into another.
    ///
    /// Returns the batch closed from the log, or the one closed from memory where the log held nothing, and nil when
    /// there is nothing to send.
    func closeBatch() -> EventBatch?

    /// Batches awaiting delivery, oldest first, including any recovered from a previous run of the application.
    func pendingBatches() -> [EventBatch]

    /// The `[...]` request body for a batch, or nil if it is gone or holds nothing this version can send, neither of
    /// which a later attempt changes.
    ///
    /// - throws: if the batch is there but could not be read this time, which a later attempt may manage.
    func body(of batch: EventBatch) throws -> Data?

    /// Forgets a batch, which is only correct once LaunchDarkly has accepted it or permanently refused it.
    func remove(_ batch: EventBatch)

    /// Stops counting a batch against capacity while its request is out. Ended by `remove(_:)` or `stoppedSending(_:)`.
    func startedSending(_ batch: EventBatch)

    /// Counts a batch against capacity again after a send that will be retried later.
    func stoppedSending(_ batch: EventBatch)

    /// Closes any log left open by a previous run of this process, so its events join the batches to deliver.
    func recoverInterruptedLog()
}

/// A crash-durable append log of encoded analytics events.
///
/// Events are appended to an open log, which is closed into a batch when the reporter is ready to deliver one. A batch
/// is deleted only once LaunchDarkly has accepted it, so a delivery interrupted by the process dying is retried on the
/// next run rather than lost.
///
/// Bytes reach the kernel through `write(2)` and are never `fsync`ed. What this defends against is the process dying --
/// which is what `fatalError`, an uncaught exception, and the OS killing a backgrounded application all are -- and a
/// process cannot take back bytes the kernel already holds; the kernel flushes them on its own schedule. Only losing
/// the kernel itself, to a panic or a power cut, can discard them, and covering that would mean `F_FULLFSYNC` on every
/// event, which costs milliseconds where this costs microseconds. The trade that buys is stated where the SDK records
/// events: a commit point is a point where staged bytes are committed, and the events an application cares most
/// about are recorded at one.
final class EventStore: EventStoring {
    /// Names a log that has been closed off for delivery; the rest of the name is the batch's payload ID.
    private static let batchPrefix = "ready-"
    /// How many staged bytes are allowed to accumulate before one of them pays for a write.
    ///
    /// This is what keeps a syscall off most recordings while bounding what a crash can take with it, for an
    /// application that only evaluates flags and so never reaches a commit point of its own.
    private static let stagingThreshold = 16 * 1024

    /// Where the batches are kept.
    var directory: URL {
        ioLock.withLock { disk.directory }
    }
    private let capacity: Int
    private let logger: OSLog
    /// How a stored log is read, injectable so a test can make a read fail while the file is intact.
    private let readFile: (URL) throws -> Data
    /// Where a commit runs when it was not asked for by a caller who needs it to have happened.
    ///
    /// Evaluating a flag must not put a write on whichever thread evaluated it, and that thread is usually the main one.
    /// A caller at a commit point still commits synchronously, because for them having returned is the guarantee.
    private let commitQueue: DispatchQueue

    /// Guards the buffer and the counters. It is held for a copy and never across a syscall, so an evaluation
    /// recording an event waits on another thread's memcpy at worst, never on the disk.
    private let bufferLock = UnfairLock()
    /// Serializes commits so that two threads committing at once cannot interleave a frame or write frames out of
    /// order. Taken before `bufferLock`, never after it.
    private let ioLock: UnfairLock

    /// Only to be used while holding `bufferLock`.
    private var bufferData = Data()
    private var bufferedEventCount = 0
    private var reservedEvents = 0
    /// Taken out of the buffer by a commit and not yet in the log. Counted so a slow write cannot open room under
    /// capacity for events the store is still holding.
    private var writingEvents = 0
    private var committedEvents = 0
    /// Events in closed batches: the sum of `eventCounts` and `inMemoryBatches`. Changed only in the critical section
    /// that changes one of those, so that it cannot drift from them; a total worked out from them and written
    /// afterwards would overwrite a close or a removal in between.
    private var closedEvents = 0
    /// Closed batches whose request is out, by payload ID, and the events in them. Every one is also in `closedEvents`,
    /// and leaves both in the same critical section.
    private var sendingBatches: [String: Int] = [:]
    private var sendingEvents = 0
    /// Whether events are being written to disk, which is what the application asked for until a write fails and the
    /// store gives up on persistence for the rest of the session.
    private var persistEvents = true
    /// Whether what is on the disk is this store's to recover, list, and deliver.
    ///
    /// False only where the application did not ask for persistence. What a run with persistence turned on left behind
    /// waits for the next run that has it turned on, rather than being delivered by a run that was told to keep
    /// events off the disk. A store that gave up on the disk partway through a session still reads it, since the
    /// batches there are its own.
    private let readsDisk: Bool
    /// Whether a commit is already on its way, so that a burst of recordings queues one write rather than one each.
    private var isCommitScheduled = false

    private let locateDirectory: () -> URL
    private let processName: String
    private let writeLog: (EventLogFile, Data) -> Int32?
    /// Only to be used while holding `ioLock`.
    private var located: (directory: URL, log: DiskEventLog)?

    /// The directory and the log in it, worked out the first time the disk is reached for, so that a store told to keep
    /// off the disk makes no filesystem call at all, not even to find out where it would have written. Requires `ioLock`.
    private var disk: (directory: URL, log: DiskEventLog) {
        ioLock.assertOwned()
        if let located {
            return located
        }
        let directory = locateDirectory()
        let disk = (directory: directory,
                    log: DiskEventLog(directory: directory, processName: processName, ioLock: ioLock, logger: logger, writeLog: writeLog))
        located = disk
        return disk
    }

    /// Requires `ioLock`.
    private var diskLog: DiskEventLog { disk.log }
    /// Whether a log left by a previous run has been dealt with. Only to be used while holding `ioLock`.
    private var hasRecoveredInterruptedLog = false

    /// Batches held in memory because the filesystem would not take them.
    ///
    /// Persistence failing should cost durability and nothing else, so the store falls back to what the SDK did before
    /// it kept a log: hold the events, deliver them, lose them only if the process dies. Kept in the order they were
    /// closed, so delivery still goes oldest first.
    ///
    /// Only to be used while holding `heldLock`.
    private var inMemoryBatches: [HeldBatch] = []

    /// Guards `inMemoryBatches`.
    ///
    /// Its own lock rather than `ioLock`, so that a store the application told to keep off the disk -- where held
    /// batches are the only ones there are -- never waits on the lock disk I/O is serialized under. Taken inside
    /// `ioLock` where there is a disk, never the other way round, and taken before `bufferLock`, never after it.
    private let heldLock = UnfairLock()

    /// How many events are in each batch this process closed or recovered, so that listing them does not have to read
    /// them back.
    ///
    /// A batch is never appended to once it is closed, so a count taken at the close holds until the batch is
    /// delivered. Without this, listing reads every batch file in full while holding `ioLock`, and a commit at a
    /// commit point can end up waiting behind those reads.
    ///
    /// Only to be used while holding `ioLock`.
    private var eventCounts: [String: Int] = [:]

    /// Where the log this process appends to is, for a test or a diagnosis to look at.
    var openLogUrl: URL {
        ioLock.withLock { diskLog.url }
    }

    #if os(macOS) || targetEnvironment(macCatalyst)
    /// Whether the open log is locked while it is open. Only to be changed before the store first touches the disk.
    var locksOpenLog: Bool {
        get { ioLock.withLock { diskLog.isLocked } }
        set { ioLock.withLock { diskLog.isLocked = newValue } }
    }
    #endif

    /// A batch is identified by its payload ID rather than by a path, so that a batch listed from the directory and the
    /// same batch as it was closed are one thing.
    private func url(of payloadId: String) -> URL {
        directory.appendingPathComponent("\(EventStore.batchPrefix)\(payloadId)")
    }

    init(directory: URL,
         capacity: Int,
         persistEvents: Bool = true,
         processName: String = ProcessInfo.processInfo.processName,
         logger: OSLog,
         commitQueue: DispatchQueue = DispatchQueue(label: "com.launchdarkly.EventStore.commitQueue", qos: .userInitiated),
         readFile: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) },
         writeLog: @escaping (EventLogFile, Data) -> Int32? = { $0.writeAll($1) }) {
        self.directory = directory
        let ioLock = UnfairLock()
        self.ioLock = ioLock
        self.diskLog = DiskEventLog(directory: directory, processName: processName, ioLock: ioLock, logger: logger, writeLog: writeLog)
        self.capacity = capacity
        self.logger = logger
        self.commitQueue = commitQueue
        self.readFile = readFile
        // An application that has not asked for persistence gets the same store running the same way it runs once a
        // write has failed: events are held, delivered, and lost only if the process dies.
        self.persistEvents = persistEvents
        self.readsDisk = persistEvents
    }

    // MARK: Recording

    var pendingEventCount: Int {
        bufferLock.withLock { countedEvents }
    }

    /// Every event counted against capacity. Only to be used while holding `bufferLock`.
    private var countedEvents: Int {
        // Clamped because a batch another process delivered can be marked as sending after a listing stopped counting it.
        reservedEvents + bufferedEventCount + writingEvents + committedEvents + max(0, closedEvents - sendingEvents)
    }

    var isPersisting: Bool {
        bufferLock.withLock { persistEvents }
    }

    func reserve(_ events: Int) {
        bufferLock.withLock { reservedEvents += events }
    }

    func releaseReservations() {
        bufferLock.withLock { reservedEvents = 0 }
    }

    func stage(_ encodedEvent: Data, bypassingCapacity: Bool = false) -> Bool {
        stage(encodedEvent, bypassingCapacity: bypassingCapacity, usingReservation: false)
    }

    func stageReserved(_ encodedEvent: Data) -> Bool {
        stage(encodedEvent, bypassingCapacity: true, usingReservation: true)
    }

    private func stage(_ encodedEvent: Data, bypassingCapacity: Bool, usingReservation: Bool) -> Bool {
        guard encodedEvent.count <= EventLogFormat.maxFrameSize
        else {
            os_log("%s dropping an event larger than a log frame allows", log: logger, type: .debug, typeName(and: #function))
            if usingReservation {
                bufferLock.withLock { reservedEvents = max(0, reservedEvents - 1) }
            }
            return false
        }

        // Whether the staged bytes are due a write, or nil where the event was refused for capacity.
        let needsCommit = bufferLock.withLock { () -> Bool? in
            guard bypassingCapacity || countedEvents < capacity
            else { return nil }

            // In the same critical section as the append, so the event is never counted twice or not at all.
            if usingReservation {
                reservedEvents = max(0, reservedEvents - 1)
            }
            bufferData.append(EventLogFormat.frame(for: encodedEvent))
            bufferedEventCount += 1
            // Nothing to schedule once persistence has been given up on: there is nowhere for a commit to put these
            // bytes, so they stay in memory until a delivery closes them into a batch.
            let due = persistEvents && bufferData.count >= EventStore.stagingThreshold && !isCommitScheduled
            if due {
                isCommitScheduled = true
            }
            return due
        }
        guard let needsCommit
        else { return false }

        // Handed to another thread rather than done here. Recording an event is something a flag evaluation does, and an
        // evaluation is expected to be a memory operation: the caller is usually the main thread, where a write that
        // happens to find a busy filesystem is a stall an application cannot do anything about.
        if needsCommit {
            commitQueue.async { [weak self] in
                self?.commitScheduled()
            }
        }
        return true
    }

    private func commitScheduled() {
        // Cleared before the commit rather than after it, so that an event staged while this write is in flight can ask
        // for another one instead of finding a commit apparently already on its way and waiting for a commit point.
        bufferLock.withLock { isCommitScheduled = false }

        commit()
    }

    func commit() {
        // Where the application asked for no disk there is nothing for a commit to reach, and so nothing to serialize.
        guard readsDisk
        else { return }
        ioLock.withLock { writeStagedBytes() }
    }

    func closeBatch() -> EventBatch? {
        guard readsDisk
        else { return closeInMemoryBatch() }

        ioLock.lock()
        defer { ioLock.unlock() }

        writeStagedBytes()

        let (events, stillBuffered) = bufferLock.withLock { (committedEvents, bufferedEventCount) }

        let fromLog = events > 0 ? closeOpenLog(events) : nil
        // Closed after the log, so the older events are delivered first. Both can hold events at once: a write that
        // fails after earlier ones landed gives up on persistence with those earlier events in the log and the failed
        // ones back in memory, and closing only the log would leave the rest to a delivery that reports success
        // without them.
        let fromMemory = stillBuffered > 0 ? closeInMemoryBatch() : nil
        return fromLog ?? fromMemory
    }

    /// Requires `ioLock`.
    private func closeOpenLog(_ events: Int) -> EventBatch? {
        ioLock.assertOwned()
        let payloadId = UUID().uuidString
        do {
            try diskLog.close(movingTo: url(of: payloadId))
        } catch {
            os_log("%s could not close the event log: %s", log: logger, type: .debug, typeName(and: #function), String(describing: error))
            // The log is still there to try again with, unless it is the log that went missing -- a purged cache
            // directory on tvOS, say. Then its events are gone, and they have to stop counting against capacity or the
            // store would refuse events for the rest of the session.
            if !diskLog.exists {
                bufferLock.withLock { committedEvents = 0 }
            }
            return nil
        }

        eventCounts[payloadId] = events

        bufferLock.withLock {
            committedEvents = 0
            closedEvents += events
        }

        return EventBatch(payloadId: payloadId, eventCount: events)
    }

    // MARK: Delivery

    /// What reading a stored log produced.
    ///
    /// A read that failed is kept apart from a file that is not there, because the two arrive the same way: a process
    /// out of file descriptors fails to open a file that is perfectly intact with the error a missing one gets. Only
    /// what is missing, or what this version cannot make sense of, is gone for good.
    private enum LogRead {
        case bytes(Data)
        case missing
        case failed(Error)
    }

    private func read(_ url: URL) -> LogRead {
        do {
            return .bytes(try readFile(url))
        } catch {
            return FileManager.default.fileExists(atPath: url.path) ? .failed(error) : .missing
        }
    }

    func pendingBatches() -> [EventBatch] {
        // Listed in one critical section where there is a disk, so that the files and what is held cannot be counted
        // either side of a close that moves events between them.
        readsDisk ? ioLock.withLock { heldBatchesAndRecount(after: batchesOnDisk()) } : heldBatchesAndRecount(after: [])
    }

    /// Adds the batches the filesystem would not take, after the files: anything held was closed by this run and so is
    /// newer than whatever a previous run left on the disk. Then counts everything listed as closed, which is how
    /// batches another process closed or delivered come to be counted or not.
    ///
    /// Requires `ioLock` where there is a disk, so that the count is of the listing as it stands.
    private func heldBatchesAndRecount(after onDisk: [EventBatch]) -> [EventBatch] {
        heldLock.withLock {
            let batches = onDisk + inMemoryBatches.map { EventBatch(payloadId: $0.payloadId, eventCount: $0.eventCount) }
            bufferLock.withLock {
                closedEvents = batches.reduce(0) { $0 + $1.eventCount }
                // One no longer listed is no longer counted, so it cannot be left out of the count either.
                let listed = Set(batches.map { $0.payloadId })
                sendingBatches.keys.filter { !listed.contains($0) }.forEach(forgetSending)
            }
            return batches
        }
    }

    /// The batch files in the directory, oldest first.
    ///
    /// Requires `ioLock`.
    private func batchesOnDisk() -> [EventBatch] {
        ioLock.assertOwned()
        let contents = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                    includingPropertiesForKeys: [.contentModificationDateKey],
                                                                    options: [.skipsHiddenFiles])) ?? []

        let batches = contents
            .filter { $0.lastPathComponent.hasPrefix(EventStore.batchPrefix) }
            .compactMap { file -> (EventBatch, Date)? in
                let payloadId = String(file.lastPathComponent.dropFirst(EventStore.batchPrefix.count))
                // Reading is only for a batch this process has not counted: one a previous run left behind.
                guard let events = eventCounts[payloadId] ?? countOfEvents(in: file)
                else { return nil }
                eventCounts[payloadId] = events
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                return (EventBatch(payloadId: payloadId, eventCount: events), modified ?? Date.distantPast)
            }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }

        // A batch that left the directory without going through `remove` -- a purged cache directory on tvOS, say --
        // would otherwise keep its count for the rest of the session.
        let listed = Set(batches.map { $0.payloadId })
        eventCounts = eventCounts.filter { listed.contains($0.key) }

        return batches
    }

    /// How many events a batch file holds, or nil when it is not one to list this time.
    ///
    /// Requires `ioLock`.
    private func countOfEvents(in file: URL) -> Int? {
        ioLock.assertOwned()
        switch read(file) {
        case .missing:
            // Gone since the directory was listed.
            return nil
        case .failed(let error):
            // Left for a later listing rather than deleted: the read may pass then, and the events in it may have been
            // intact all along. Without a count it cannot be delivered now.
            os_log("%s could not read stored events, will try again later: %s", log: logger, type: .debug, typeName(and: #function), String(describing: error))
            return nil
        case .bytes(let log):
            guard let events = EventLogFormat.eventCount(in: log)
            else {
                // Written by a version of the SDK whose format this one does not read, or damaged beyond what the
                // torn tail recovery tolerates. Either way it can never be delivered, so it is not kept.
                try? FileManager.default.removeItem(at: file)
                return nil
            }
            return events
        }
    }

    func body(of batch: EventBatch) throws -> Data? {
        if let held = heldLock.withLock({ inMemoryBatches.first { $0.payloadId == batch.payloadId } }) {
            return held.body
        }

        // A batch is either held or on the disk, never both and never moved between them, so a batch that is not held
        // in a store with no disk does not exist.
        guard readsDisk
        else { return nil }

        return try ioLock.withLock {
            switch read(url(of: batch.payloadId)) {
            case .missing: return nil
            case .failed(let error): throw error
            case .bytes(let file): return EventLogFormat.assembleBody(from: file)
            }
        }
    }

    func remove(_ batch: EventBatch) {
        // Only a count this call takes away stops counting. Two deliveries can both get to the same batch, and a listing
        // drops a batch another process delivered before this one gets to remove it.
        let wasHeld = heldLock.withLock { () -> Bool in
            guard let index = inMemoryBatches.firstIndex(where: { $0.payloadId == batch.payloadId })
            else { return false }
            let held = inMemoryBatches.remove(at: index)
            bufferLock.withLock {
                closedEvents -= held.eventCount
                forgetSending(batch.payloadId)
            }
            return true
        }

        guard !wasHeld
        else { return }
        guard readsDisk
        else {
            bufferLock.withLock { forgetSending(batch.payloadId) }
            return
        }
        ioLock.withLock {
            try? FileManager.default.removeItem(at: url(of: batch.payloadId))
            let counted = eventCounts.removeValue(forKey: batch.payloadId) ?? 0
            bufferLock.withLock {
                closedEvents -= counted
                forgetSending(batch.payloadId)
            }
        }
    }

    /// Closes any log left open by a previous run of this process, so its events join the batches to deliver.
    ///
    /// The events in it were recorded by a process that is gone, so there is no one left to add to it. Only this
    /// process's own log is touched: another process's may still be open in a process that is alive. Where logs are
    /// locked, any log no live process holds is recovered, whatever it is named.
    func recoverInterruptedLog() {
        ioLock.withLock { recoverInterruptedLogOnce() }
    }

    /// Requires `ioLock`. Does its work once per store: after that, the open log is one this run opened.
    private func recoverInterruptedLogOnce() {
        ioLock.assertOwned()
        guard readsDisk, !hasRecoveredInterruptedLog
        else { return }
        hasRecoveredInterruptedLog = true
        diskLog.forEachLogLeftOpen { recover(logAt: $0) }
    }

    /// Closes off a log nobody is writing to any more. Requires `ioLock`.
    private func recover(logAt leftOpen: URL) {
        ioLock.assertOwned()
        let events: Int
        switch read(leftOpen) {
        case .missing:
            return
        case .failed(let error):
            // It cannot stay under this name, which this run is about to append its own events to, and deleting it
            // would lose events that may be intact. Closed off uncounted instead, it is read and counted by whichever
            // listing first manages to.
            os_log("%s could not read events from a previous run, will try again later: %s", log: logger, type: .debug, typeName(and: #function), String(describing: error))
            try? FileManager.default.moveItem(at: leftOpen, to: url(of: UUID().uuidString))
            return
        case .bytes(let log):
            guard let counted = EventLogFormat.eventCount(in: log)
            else {
                // Unreadable, and a log that cannot be read cannot be appended to either.
                try? FileManager.default.removeItem(at: leftOpen)
                return
            }
            events = counted
        }

        guard events > 0
        else {
            try? FileManager.default.removeItem(at: leftOpen)
            return
        }

        let payloadId = UUID().uuidString
        guard (try? FileManager.default.moveItem(at: leftOpen, to: url(of: payloadId))) != nil
        else { return }

        eventCounts[payloadId] = events
        bufferLock.withLock { closedEvents += events }
        os_log("%s recovered %d event(s) from a previous run", log: logger, type: .debug, typeName(and: #function), events)
    }

    deinit {
        // One acquisition: the lock is not recursive, and `commit()` would take it again.
        ioLock.withLock {
            writeStagedBytes()
            diskLog.closeDescriptor()
        }
    }
}

// MARK: Sending

extension EventStore {
    func startedSending(_ batch: EventBatch) {
        bufferLock.withLock {
            guard sendingBatches[batch.payloadId] == nil
            else { return }
            sendingBatches[batch.payloadId] = batch.eventCount
            sendingEvents += batch.eventCount
        }
    }

    func stoppedSending(_ batch: EventBatch) {
        bufferLock.withLock { forgetSending(batch.payloadId) }
    }

    /// Requires `bufferLock`.
    fileprivate func forgetSending(_ payloadId: String) {
        if let events = sendingBatches.removeValue(forKey: payloadId) {
            sendingEvents -= events
        }
    }
}

// MARK: Writing

extension EventStore {
    /// Requires `ioLock`.
    private func writeStagedBytes() {
        ioLock.assertOwned()
        let taken = bufferLock.withLock { () -> (bytes: Data, events: Int)? in
            // Staged bytes are left where they are. With nowhere durable to put them, memory is better than dropping
            // them: a delivery can still close them into a batch and send them.
            guard persistEvents, bufferedEventCount > 0
            else { return nil }
            let staged = (bytes: bufferData, events: bufferedEventCount)
            bufferData = Data()
            bufferedEventCount = 0
            writingEvents = staged.events
            return staged
        }
        guard let taken
        else { return }

        if append(taken.bytes) {
            bufferLock.withLock {
                writingEvents = 0
                committedEvents += taken.events
            }
        } else {
            // Put back, to be delivered from memory rather than lost. Ahead of anything staged while the write was in
            // flight, so the events keep the order they were recorded in.
            bufferLock.withLock {
                writingEvents = 0
                bufferData = taken.bytes + bufferData
                bufferedEventCount += taken.events
            }
        }
    }

    /// Requires `ioLock`.
    private func append(_ bytes: Data) -> Bool {
        ioLock.assertOwned()
        // Before the log is opened, because it may still be the one a previous run died writing. Appended to, this
        // run's events would sit behind that run's torn last frame, where a reader can no longer find where they start.
        if !diskLog.isOpen {
            recoverInterruptedLogOnce()
        }
        guard diskLog.append(bytes)
        else {
            // Never trap on a full disk. The SDK gives up on persistence for the rest of the session rather than taking
            // the application down with it, which is how other SDKs have crashed their hosts.
            disablePersistence()
            return false
        }
        return true
    }
}

/// A batch the filesystem would not take, kept where the SDK used to keep all of them.
private struct HeldBatch {
    let payloadId: String
    let body: Data
    let eventCount: Int
}

/// What the store does once the filesystem has refused it.
///
/// Losing the disk should cost durability and nothing else, so the store falls back to what the SDK did before it kept
/// a log: hold the events in memory, deliver them from there, and lose them only if the process dies. That is a worse
/// guarantee than Tier 3 and a better one than dropping the events, which is what a full device used to mean here.
private extension EventStore {
    /// Gives up on the disk for the rest of the session, leaving the events themselves alone.
    ///
    /// Requires `ioLock`.
    func disablePersistence() {
        ioLock.assertOwned()
        diskLog.closeDescriptor()
        bufferLock.withLock { persistEvents = false }
    }

    /// Closes whatever is staged into a batch that never reaches a file.
    ///
    /// Called under `ioLock` where there is a disk, so that it and the log are closed as one step, and on its own
    /// where there is not.
    func closeInMemoryBatch() -> EventBatch? {
        let (frames, events) = bufferLock.withLock { () -> (Data, Int) in
            let staged = (bufferData, bufferedEventCount)
            bufferData = Data()
            bufferedEventCount = 0
            return staged
        }

        // Assembled through the same reader a batch on disk goes through, so a held batch and a written one produce
        // byte-identical request bodies.
        var log = EventLogFormat.fileHeader
        log.append(frames)
        guard let body = EventLogFormat.assembleBody(from: log)
        else { return nil }

        let payloadId = UUID().uuidString
        heldLock.withLock {
            inMemoryBatches.append(HeldBatch(payloadId: payloadId, body: body, eventCount: events))
            bufferLock.withLock { closedEvents += events }
        }

        return EventBatch(payloadId: payloadId, eventCount: events)
    }
}

extension EventStore {
    /// Every event the store is holding, encoded exactly as it will be sent.
    ///
    /// Reading the log means committing what is staged, so this is not free and is meant for tests and for diagnosing a
    /// store rather than for the recording path.
    func pendingEventPayloads() -> [Data] {
        commit()

        ioLock.lock()
        defer { ioLock.unlock() }

        var payloads = readsDisk ? payloadsOnDisk() : []
        // After the disk, which is older: a store that gave up on persistence holds what came later in memory.
        let held = heldLock.withLock { inMemoryBatches.map { $0.body } }
        for body in held {
            let events = (try? JSONDecoder().decode([LDValue].self, from: body)) ?? []
            payloads.append(contentsOf: events.compactMap { try? JSONEncoder().encode($0) })
        }
        var staged = EventLogFormat.fileHeader
        staged.append(bufferLock.withLock { bufferData })
        _ = EventLogFormat.forEachFrame(in: staged) { type, payload in
            if type == EventLogFormat.eventFrame {
                payloads.append(payload)
            }
        }
        return payloads
    }

    /// Requires `ioLock`.
    private func payloadsOnDisk() -> [Data] {
        ioLock.assertOwned()
        let contents = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                    includingPropertiesForKeys: nil,
                                                                    options: [.skipsHiddenFiles])) ?? []
        var logs = contents.filter { $0.lastPathComponent.hasPrefix(EventStore.batchPrefix) }.sorted { $0.path < $1.path }
        if diskLog.exists {
            logs.append(diskLog.url)
        }

        var payloads: [Data] = []
        for log in logs {
            guard let file = try? Data(contentsOf: log)
            else { continue }
            _ = EventLogFormat.forEachFrame(in: file) { type, payload in
                if type == EventLogFormat.eventFrame {
                    payloads.append(payload)
                }
            }
        }
        return payloads
    }
}

extension EventStore {
    /// The directory the store for a mobile key belongs in.
    ///
    /// tvOS is the reason this is not simply Application Support: a tvOS application is only allowed to persist to
    /// purgeable caches, so there the events are kept somewhere the system may reclaim, which is the most durability
    /// the platform offers. A directory that turns out not to be writable is no different from a full device: the store
    /// gives up on the disk and holds events in memory.
    static func defaultDirectory(mobileKey: String) -> URL {
        #if os(tvOS)
        let searchPath = FileManager.SearchPathDirectory.cachesDirectory
        #else
        let searchPath = FileManager.SearchPathDirectory.applicationSupportDirectory
        #endif

        let root = FileManager.default.urls(for: searchPath, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        var keyComponent = Util.sha256(mobileKey).base64UrlEncodedString
        if let bundleId = Bundle.main.bundleIdentifier {
            keyComponent = "\(Util.sha256(bundleId).base64UrlEncodedString).\(keyComponent)"
        }

        return root
            .appendingPathComponent("com.launchdarkly.events", isDirectory: true)
            .appendingPathComponent(keyComponent, isDirectory: true)
    }
}

extension EventStore: TypeIdentifying { }
