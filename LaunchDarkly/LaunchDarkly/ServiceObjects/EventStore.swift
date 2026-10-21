import Foundation
import OSLog

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

    /// Whether a full event of any size could still be staged within the byte capacity.
    ///
    /// Asked before an event is accepted, when it has not been encoded and so has no size yet. An event accepted while
    /// there is room can still be refused at `stageReserved(_:)` if it turns out not to fit.
    var hasRoomForEventBytes: Bool { get }

    /// Whether a commit writes anything, which is false where persistence is off and once a write has failed and the
    /// store has given up on it.
    var isPersisting: Bool { get }

    /// Stages an already encoded event, returning false if it was dropped because `capacity` or the byte capacity is
    /// reached.
    ///
    /// Staging is a copy into a buffer, and never writes however much is staged; `commit()` is what makes the event
    /// outlive the process, and deciding when to call it is the caller's.
    ///
    /// - Parameter bypassingCapacity: true for a summary, which is not refused for `capacity` and may use the part of
    ///   the byte capacity held back from full events, but is still refused past the byte capacity itself.
    func stage(_ encodedEvent: Data, bypassingCapacity: Bool) -> Bool

    /// Counts events that have been accepted but are still being encoded, so capacity sees them until they are staged.
    func reserve(_ events: Int)

    /// Stages an event using up one reservation, rather than checking `capacity` again. Its bytes are checked, since
    /// they were not known when it was accepted.
    func stageReserved(_ encodedEvent: Data) -> Bool

    /// Gives back every reservation not used up by `stageReserved(_:)`, such as one for an event that failed to encode.
    func releaseReservations()

    /// Hands every staged byte to the kernel, so that the events recorded so far survive the process dying.
    func commit()

    /// Commits, then closes the open log into a batch to deliver, and whatever is still staged in memory into another.
    ///
    /// Returns the batch closed from the log, or the first closed from memory where the log held nothing, and nil when
    /// there is nothing to send. A log a commit filled was closed into a batch of its own as it filled, and memory is
    /// closed into as many batches as keep each within `EventLogFormat.maxBatchSize`; `pendingBatches()` lists every
    /// one.
    func closeBatch() -> EventBatch?

    /// Batches awaiting delivery, oldest first, including any recovered from a previous run of the application.
    func pendingBatches() -> [EventBatch]

    /// The `[...]` request body for a batch, or nil if it is gone or holds no events, neither of which loses anything.
    ///
    /// - throws: `UnreadableBatch` if the batch is there but holds nothing this version can send, which no later
    ///   attempt changes and which loses its events; anything else if it could not be read this time, which a later
    ///   attempt may manage.
    func body(of batch: EventBatch) throws -> Data?

    /// Forgets a batch, which is only correct once LaunchDarkly has accepted it or permanently refused it.
    func remove(_ batch: EventBatch)

    /// Stops counting a batch against capacity while its request is out. Ended by `remove(_:)` or `stoppedSending(_:)`.
    func startedSending(_ batch: EventBatch)

    /// Counts a batch against capacity again after a send that will be retried later.
    func stoppedSending(_ batch: EventBatch)

    /// Closes every log no live process holds, so its events join the batches to deliver: one a previous run left open,
    /// or another process that has since ended.
    func preparePayloadsFromInterruptedLogs()

    /// Deletes what has been stored for longer than the maximum age, except a batch whose request is out.
    ///
    /// The first call also empties and removes the directories of other environments of this application that nothing
    /// has written to for as long, which is what becomes of a mobile key the application stopped using.
    ///
    /// - Returns: how many events were discarded.
    func discardExpired() -> Int
}

/// A batch that is there to read and holds nothing this version can send: damaged, or written in a format it does not
/// read. Unlike a batch that is gone, its events are lost.
struct UnreadableBatch: Error {
    let payloadId: String
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
///
/// What a log looks like on disk is `EventLogFormat`; the directory of them, and the log this process appends to, are
/// `EventDirectory` and `DiskEventLog`. This is what decides when events move between memory, that log, and the
/// batches closed off for delivery, and what counts them against capacity on the way.
final class EventStore: EventStoring {
    /// Where the events are kept, or nil where the application asked for them to be kept off the disk.
    ///
    /// Nil rather than a directory this store is careful never to use, so that there is nowhere for it to write and
    /// nothing for it to read: what a run with persistence turned on left behind waits for the next run that has it
    /// turned on. A store that gave up on the disk partway through a session keeps its directory, since the batches
    /// there are its own.
    private let disk: EventDirectory?
    private let capacity: Int
    /// The most bytes summaries may take the store to.
    private let byteCapacity: Int
    /// The most bytes full events may take the store to: the byte capacity less a fifth of it, held back so that
    /// summaries, which bypass `capacity`, still have room once full events are being refused.
    private let eventByteCapacity: Int
    /// How long a batch may go unwritten before it is discarded rather than delivered.
    private let maxAge: TimeInterval
    private let logger: OSLog

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
    /// Taken out of the buffer to be written to the log, or assembled into a batch held in memory, and not yet
    /// counted where they land. Both happen outside `bufferLock`, and for as long as they take the events are in
    /// neither place; without this they would be counted nowhere, and capacity would admit that many more.
    private var writingEvents = 0
    private var committedEvents = 0
    /// Events in closed batches: the sum of what the directory holds and `inMemoryBatches`. Changed only in the
    /// critical section that changes one of those, so that it cannot drift from them; a total worked out from them and
    /// written afterwards would overwrite a close or a removal in between.
    private var closedEvents = 0
    /// Closed batches whose request is out, by payload ID, and what is in them. Every one is also in `closedEvents`,
    /// and leaves both in the same critical section.
    private var sendingBatches: [String: EventTally] = [:]
    private var sendingEvents = 0

    /// The bytes of the events counted above, state for state. Staged bytes are `bufferData` itself. Changed in the
    /// same critical sections as the event counts beside them, so that bytes and events are never counted in
    /// different places.
    private var writingBytes = 0
    private var committedBytes = 0
    private var closedBytes = 0
    private var sendingBytes = 0

    /// Whether the directories of other environments have been looked at for ones nobody uses any more, which is
    /// done once per process. Only to be used while holding `ioLock`.
    private var hasDiscardedAbandonedEnvironments = false
    /// Whether events are being written to disk, which is what the application asked for until a write fails and the
    /// store gives up on persistence for the rest of the session.
    private var persistEvents = true

    /// Batches held in memory because the filesystem would not take them, or because it was never asked.
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

    /// Where the batches are kept, or nil for a store told to keep events off the disk.
    var directory: URL? {
        ioLock.withLock { disk?.url }
    }

    /// Where the log this process appends to is, for a test or a diagnosis to look at.
    var openLogUrl: URL? {
        ioLock.withLock { disk?.openLogUrl }
    }

    #if os(macOS) || targetEnvironment(macCatalyst)
    /// Whether the open log is locked while it is open. Only to be changed before the store first touches the disk.
    var locksOpenLog: Bool {
        get { ioLock.withLock { disk?.locksOpenLog ?? false } }
        set { ioLock.withLock { disk?.locksOpenLog = newValue } }
    }
    #endif

    convenience init(directory: URL,
                     capacity: Int,
                     byteCapacity: Int = LDConfig.Defaults.eventCapacityBytes,
                     maxAge: TimeInterval = LDConfig.Defaults.eventMaxAge,
                     persistEvents: Bool = true,
                     logger: OSLog,
                     readFile: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) },
                     writeLog: @escaping (EventLogFile, Data) -> Int32? = { $0.writeAll($1) }) {
        self.init(locatingDirectory: { directory }, capacity: capacity, byteCapacity: byteCapacity, maxAge: maxAge,
                  persistEvents: persistEvents, logger: logger, readFile: readFile, writeLog: writeLog)
    }

    /// - Parameter locatingDirectory: answers where the batches go. Asked once, and only if the store reaches for the
    ///   disk, which one told not to persist events never does.
    init(locatingDirectory: @escaping () -> URL,
         capacity: Int,
         byteCapacity: Int = LDConfig.Defaults.eventCapacityBytes,
         maxAge: TimeInterval = LDConfig.Defaults.eventMaxAge,
         persistEvents: Bool = true,
         logger: OSLog,
         readFile: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) },
         writeLog: @escaping (EventLogFile, Data) -> Int32? = { $0.writeAll($1) }) {
        let ioLock = UnfairLock()
        self.ioLock = ioLock
        self.capacity = capacity
        self.byteCapacity = byteCapacity > 0 ? byteCapacity : LDConfig.Defaults.eventCapacityBytes
        self.eventByteCapacity = self.byteCapacity - self.byteCapacity / 5
        self.maxAge = maxAge > 0 ? maxAge : LDConfig.Defaults.eventMaxAge
        self.logger = logger
        // An application that has not asked for persistence gets the same store running the same way it runs once a
        // write has failed: events are held, delivered, and lost only if the process dies. It gets no directory at
        // all, so there is nothing for it to write to and nothing of a previous run's for it to read.
        self.persistEvents = persistEvents
        self.disk = persistEvents ? EventDirectory(locatingDirectory: locatingDirectory,
                                                   ioLock: ioLock,
                                                   logger: logger,
                                                   readFile: readFile,
                                                   writeLog: writeLog)
                                  : nil
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

    /// Every byte counted against the byte capacity. Only to be used while holding `bufferLock`.
    ///
    /// Events reserved while being encoded have no bytes yet; they are counted when they are staged.
    private var countedBytes: Int {
        bufferData.count + writingBytes + committedBytes + max(0, closedBytes - sendingBytes)
    }

    var hasRoomForEventBytes: Bool {
        // A store kept off the disk holds events the way the SDK did before persistence, bounded by count alone.
        disk == nil || bufferLock.withLock { countedBytes < eventByteCapacity }
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

        // Framed before the lock is taken, so that the critical section is the append.
        let frame = EventLogFormat.frame(for: encodedEvent)
        // Only a summary bypasses capacity without a reservation, and only a summary may use the bytes held back.
        let isSummary = bypassingCapacity && !usingReservation
        let boundedByBytes = disk != nil
        let staged = bufferLock.withLock { () -> Bool in
            // In the same critical section as the append, so the event is never counted twice or not at all.
            if usingReservation {
                reservedEvents = max(0, reservedEvents - 1)
            }
            guard bypassingCapacity || countedEvents < capacity,
                  !boundedByBytes || countedBytes + frame.count <= (isSummary ? byteCapacity : eventByteCapacity)
            else { return false }

            bufferData.append(frame)
            bufferedEventCount += 1
            return true
        }
        if !staged {
            os_log("%s dropping an event the store has no room for", log: logger, type: .debug, typeName(and: #function))
        }
        return staged
    }

    func commit() {
        // Where the application asked for no disk there is nothing for a commit to reach, and so nothing to serialize.
        guard disk != nil
        else { return }
        ioLock.withLock { writeStagedBytes() }
    }

    func closeBatch() -> EventBatch? {
        guard let disk
        else { return closeInMemoryBatches().first }

        ioLock.lock()
        defer { ioLock.unlock() }

        writeStagedBytes()

        let (committed, stillBuffered) = bufferLock.withLock {
            (EventTally(events: committedEvents, bytes: committedBytes), bufferedEventCount)
        }

        let fromLog = committed.events > 0 ? closeOpenLog(of: disk, holding: committed) : nil
        // Closed after the log, so the older events are delivered first. Both can hold events at once: a write that
        // fails after earlier ones landed gives up on persistence with those earlier events in the log and the failed
        // ones back in memory, and closing only the log would leave the rest to a delivery that reports success
        // without them. A full log that could not be closed leaves events staged too.
        let fromMemory = stillBuffered > 0 ? closeInMemoryBatches().first : nil
        return fromLog ?? fromMemory
    }

    /// Requires `ioLock`.
    private func closeOpenLog(of disk: EventDirectory, holding committed: EventTally) -> EventBatch? {
        ioLock.assertOwned()
        // The file is the frames behind its header. A listing counts it from the file itself.
        let closed = EventTally(events: committed.events, bytes: committed.bytes + EventLogFormat.fileHeader.count)
        switch disk.closeLog(holding: closed) {
        case .failed(let logSurvives):
            // Where the log went with its events, they have to stop counting against capacity or the store would
            // refuse events for the rest of the session.
            if !logSurvives {
                bufferLock.withLock {
                    committedEvents = 0
                    committedBytes = 0
                }
            }
            return nil
        case .closed(let batch):
            bufferLock.withLock {
                committedEvents = 0
                committedBytes = 0
                closedEvents += closed.events
                closedBytes += closed.bytes
            }
            return batch
        }
    }

    // MARK: Delivery

    func pendingBatches() -> [EventBatch] {
        // Listed in one critical section where there is a disk, so that the files and what is held cannot be counted
        // either side of a close that moves events between them.
        guard let disk
        else { return heldBatchesAndRecount(after: [], storedBytes: 0) }
        return ioLock.withLock {
            let listed = disk.listBatches()
            return heldBatchesAndRecount(after: listed, storedBytes: disk.storedBytes)
        }
    }

    /// Adds the batches the filesystem would not take, after the files: anything held was closed by this run and so is
    /// newer than whatever a previous run left on the disk. Then counts everything listed as closed, which is how
    /// batches another process closed or delivered come to be counted or not.
    ///
    /// Requires `ioLock` where there is a disk, so that the count is of the listing as it stands.
    ///
    /// - Parameter storedBytes: the bytes in the batches listed from the disk.
    private func heldBatchesAndRecount(after onDisk: [EventBatch], storedBytes: Int) -> [EventBatch] {
        heldLock.withLock {
            let batches = onDisk + inMemoryBatches.map { EventBatch(payloadId: $0.payloadId, eventCount: $0.eventCount) }
            bufferLock.withLock {
                closedEvents = batches.reduce(0) { $0 + $1.eventCount }
                closedBytes = inMemoryBatches.reduce(storedBytes) { $0 + $1.body.count }
                // One no longer listed is no longer counted, so it cannot be left out of the count either.
                let listed = Set(batches.map { $0.payloadId })
                sendingBatches.keys.filter { !listed.contains($0) }.forEach(forgetSending)
            }
            return batches
        }
    }

    func body(of batch: EventBatch) throws -> Data? {
        if let held = heldLock.withLock({ inMemoryBatches.first { $0.payloadId == batch.payloadId } }) {
            return held.body
        }

        // A batch is either held or on the disk, never both and never moved between them, so a batch that is not held
        // in a store with no disk does not exist.
        guard let disk
        else { return nil }

        return try ioLock.withLock { try disk.body(of: batch) }
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
                closedBytes -= held.body.count
                forgetSending(batch.payloadId)
            }
            return true
        }

        guard !wasHeld
        else { return }
        guard let disk
        else {
            bufferLock.withLock { forgetSending(batch.payloadId) }
            return
        }
        ioLock.withLock {
            let counted = disk.remove(batch.payloadId, holding: batch.eventCount)
            bufferLock.withLock {
                closedEvents -= counted.events
                closedBytes -= counted.bytes
                forgetSending(batch.payloadId)
            }
        }
    }

    func preparePayloadsFromInterruptedLogs() {
        guard let disk
        else { return }
        ioLock.withLock {
            let recovered = disk.preparePayloadsFromInterruptedLogs()
            guard recovered.events > 0
            else { return }
            bufferLock.withLock {
                closedEvents += recovered.events
                closedBytes += recovered.bytes
            }
        }
    }

    func discardExpired() -> Int {
        guard let disk
        else { return 0 }
        let cutoff = Date().addingTimeInterval(-maxAge)

        let (discarded, directory) = ioLock.withLock { () -> (Int, URL?) in
            let sending = bufferLock.withLock { Set(sendingBatches.keys) }
            let (events, counted) = disk.discard(lastWrittenBefore: cutoff, sparing: sending)
            // In the same critical section as the delete, as for any other path that loses events without delivering
            // them, so the store cannot go on counting what is gone.
            bufferLock.withLock {
                closedEvents -= counted.events
                closedBytes -= counted.bytes
            }
            defer { hasDiscardedAbandonedEnvironments = true }
            return (events, hasDiscardedAbandonedEnvironments ? nil : disk.url)
        }

        // Outside `ioLock`: none of it is this store's directory, and a commit point should not wait on it.
        guard let directory
        else { return discarded }
        return discarded + EventDirectory.discardAbandonedEnvironments(besides: directory, lastWrittenBefore: cutoff)
    }

    deinit {
        // One acquisition: the lock is not recursive, and `commit()` would take it again.
        ioLock.withLock {
            writeStagedBytes()
            disk?.closeOpenLog()
        }
    }
}

// MARK: Sending

extension EventStore {
    func startedSending(_ batch: EventBatch) {
        let bytes = bytes(of: batch.payloadId)
        bufferLock.withLock {
            guard sendingBatches[batch.payloadId] == nil
            else { return }
            sendingBatches[batch.payloadId] = EventTally(events: batch.eventCount, bytes: bytes)
            sendingEvents += batch.eventCount
            sendingBytes += bytes
        }
    }

    func stoppedSending(_ batch: EventBatch) {
        bufferLock.withLock { forgetSending(batch.payloadId) }
    }

    /// The bytes a closed batch is counted as, held or on the disk.
    private func bytes(of payloadId: String) -> Int {
        if let held = heldLock.withLock({ inMemoryBatches.first { $0.payloadId == payloadId } }) {
            return held.body.count
        }
        guard let disk
        else { return 0 }
        return ioLock.withLock { disk.bytes(of: payloadId) }
    }

    /// Requires `bufferLock`.
    fileprivate func forgetSending(_ payloadId: String) {
        if let sending = sendingBatches.removeValue(forKey: payloadId) {
            sendingEvents -= sending.events
            sendingBytes -= sending.bytes
        }
    }
}

// MARK: Writing

extension EventStore {
    /// Requires `ioLock`.
    ///
    /// Closes the open log into a batch wherever the next frame would take it past `EventLogFormat.maxBatchSize`, so a
    /// commit can land in several batches.
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
            writingEvents += staged.events
            writingBytes += staged.bytes.count
            return staged
        }
        guard let taken
        else { return }

        let base = taken.bytes.startIndex
        var written = 0
        var writtenEvents = 0
        while written < taken.bytes.count {
            let room = EventLogFormat.maxBatchSize - EventLogFormat.fileHeaderSize - bufferLock.withLock { committedBytes }
            if EventLogFormat.frameSize(in: taken.bytes, at: written) > room {
                guard closeFullLog()
                else { break }
                continue
            }
            let (end, landing) = EventLogFormat.framesFitting(in: taken.bytes, from: written, room: room)
            let isWhole = written == 0 && end == taken.bytes.count
            guard append(isWhole ? taken.bytes : taken.bytes.subdata(in: (base + written)..<(base + end)))
            else { break }
            // Counted where they landed in the same critical section that stops counting them on the way, so a
            // capacity check never sees them in both places or in neither.
            bufferLock.withLock {
                writingEvents -= landing
                writingBytes -= end - written
                committedEvents += landing
                committedBytes += end - written
            }
            written = end
            writtenEvents += landing
        }

        if written < taken.bytes.count {
            // Put back, to be delivered from memory rather than lost. Ahead of anything staged while the write was in
            // flight, so the events keep the order they were recorded in.
            bufferLock.withLock {
                writingEvents -= taken.events - writtenEvents
                writingBytes -= taken.bytes.count - written
                bufferData = taken.bytes.subdata(in: (base + written)..<taken.bytes.endIndex) + bufferData
                bufferedEventCount += taken.events - writtenEvents
            }
        }
    }

    /// Closes an open log that has no room for the next frame, so that the frame starts a batch of its own. Requires
    /// `ioLock`.
    ///
    /// Returns whether the next append starts a new log; false if this one could not be closed, which leaves the frames
    /// to be held in memory rather than grow it past the size of a batch.
    private func closeFullLog() -> Bool {
        ioLock.assertOwned()
        guard let disk
        else { return false }
        let committed = bufferLock.withLock { EventTally(events: committedEvents, bytes: committedBytes) }
        _ = closeOpenLog(of: disk, holding: committed)
        return bufferLock.withLock { committedBytes == 0 }
    }

    /// Requires `ioLock`.
    private func append(_ bytes: Data) -> Bool {
        ioLock.assertOwned()
        guard let disk
        else { return false }

        guard disk.append(bytes)
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
        disk?.closeOpenLog()
        bufferLock.withLock { persistEvents = false }
    }

    /// Closes whatever is staged into batches that never reach a file, as many as it takes to keep each within
    /// `EventLogFormat.maxBatchSize`. Returns them oldest first.
    ///
    /// Called under `ioLock` where there is a disk, so that it and the log are closed as one step, and on its own
    /// where there is not.
    func closeInMemoryBatches() -> [EventBatch] {
        let (frames, events) = bufferLock.withLock { () -> (frames: Data, events: Int) in
            let staged = (frames: bufferData, events: bufferedEventCount)
            bufferData = Data()
            bufferedEventCount = 0
            writingEvents += staged.events
            writingBytes += staged.frames.count
            return staged
        }

        // Assembled outside `bufferLock`, because it copies every staged frame; `writingEvents` is what keeps them
        // counted meanwhile. Through the same reader a batch on disk goes through, so a held batch and a written one
        // produce byte-identical request bodies.
        let base = frames.startIndex
        var closed: [EventBatch] = []
        var held = 0
        var heldEvents = 0
        while held < frames.count {
            let (end, batchEvents) = EventLogFormat.framesFitting(in: frames, from: held,
                                                                  room: EventLogFormat.maxBatchSize - EventLogFormat.fileHeaderSize)
            var log = EventLogFormat.fileHeader
            log.append(frames.subdata(in: (base + held)..<(base + end)))
            guard let body = EventLogFormat.assembleBody(from: log)
            else { break }

            let payloadId = UUID().uuidString
            heldLock.withLock {
                inMemoryBatches.append(HeldBatch(payloadId: payloadId, body: body, eventCount: batchEvents))
                // Counted where they landed in the same critical section that stops counting them on the way, so a
                // capacity check never sees them in both places or in neither. A held batch is counted as its body,
                // which is what it keeps.
                bufferLock.withLock {
                    writingEvents -= batchEvents
                    writingBytes -= end - held
                    closedEvents += batchEvents
                    closedBytes += body.count
                }
            }
            closed.append(EventBatch(payloadId: payloadId, eventCount: batchEvents))
            held = end
            heldEvents += batchEvents
        }

        if held < frames.count {
            bufferLock.withLock {
                writingEvents -= events - heldEvents
                writingBytes -= frames.count - held
            }
        }
        return closed
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

        var payloads = disk?.storedPayloads() ?? []
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
}

extension EventStore: TypeIdentifying { }
