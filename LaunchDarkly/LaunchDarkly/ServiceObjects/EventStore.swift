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
    /// Events that have been recorded but not yet accepted by LaunchDarkly, whether they are reserved while being
    /// encoded, staged in memory, written to the open log, or sitting in a closed batch.
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
    /// Names the log a single process appends to; the rest of the name is that process.
    private static let openLogPrefix = "open-"
    /// How many staged bytes are allowed to accumulate before one of them pays for a write.
    ///
    /// This is what keeps a syscall off most recordings while bounding what a crash can take with it, for an
    /// application that only evaluates flags and so never reaches a commit point of its own.
    private static let stagingThreshold = 16 * 1024

    let directory: URL
    private let capacity: Int
    private let logger: OSLog
    /// How a stored log is read, injectable so a test can make a read fail while the file is intact.
    private let readFile: (URL) throws -> Data
    /// How bytes reach the open log, injectable so a test can make a write fail partway through a session, as a full
    /// disk does. Answers with the errno it stopped on, or nil where every byte landed.
    private let writeLog: (Int32, Data) -> Int32?
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
    private let ioLock = UnfairLock()

    /// Only to be used while holding `bufferLock`.
    private var bufferData = Data()
    private var bufferedEventCount = 0
    private var reservedEvents = 0
    private var committedEvents = 0
    private var closedEvents = 0
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

    /// Only to be used while holding `ioLock`.
    private var descriptor: Int32 = -1
    /// Whether a log left by a previous run has been dealt with. Only to be used while holding `ioLock`.
    private var hasRecoveredInterruptedLog = false

    /// Batches held in memory because the filesystem would not take them.
    ///
    /// Persistence failing should cost durability and nothing else, so the store falls back to what the SDK did before
    /// it kept a log: hold the events, deliver them, lose them only if the process dies. Kept in the order they were
    /// closed, so delivery still goes oldest first.
    ///
    /// Only to be used while holding `ioLock`.
    private var inMemoryBatches: [HeldBatch] = []

    /// How many events are in each batch this process closed or recovered, so that listing them does not have to read
    /// them back.
    ///
    /// A batch is never appended to once it is closed, so a count taken at the close holds until the batch is
    /// delivered. Without this, listing reads every batch file in full while holding `ioLock`, and a commit at a
    /// commit point can end up waiting behind those reads.
    ///
    /// Only to be used while holding `ioLock`.
    private var eventCounts: [String: Int] = [:]

    /// The log this process appends to.
    ///
    /// One per process rather than one per directory, so that only one process ever writes a given log and recovery
    /// only ever touches its own. With one shared log, a second process starting up would close off, as if a previous
    /// run had left it, a log the first is still appending to through its open descriptor, and the first's later
    /// events would land in a batch already sent or deleted. Another process's log is left for that process to recover
    /// the next time it runs.
    ///
    /// Named for the process, unless `locksOpenLog` found another live instance holding that name, in which case it is
    /// named for this instance's process ID as well. Only to be used while holding `ioLock`.
    private(set) var openLogUrl: URL
    /// The readable, collision-proof form of the process name every log this process opens is named after.
    private let processLogName: String
    /// Whether the open log is locked while this store has it open, so that another live process can tell it is taken.
    ///
    /// Only where two live processes can run under one name, which a process name alone cannot keep apart: a Mac runs
    /// a second instance of an application on request. Elsewhere a name is one live process, and a lock is avoided
    /// rather than added for nothing, because iOS kills a suspended application that holds a lock on a file in a
    /// shared container.
    private let locksOpenLog: Bool

    /// Whether this platform can run two live instances of an application under one process name. True on a Mac,
    /// which includes an iPhone or iPad application running on one, whether built with Mac Catalyst or not.
    static var instancesCanShareProcessName: Bool {
        #if os(macOS)
        return true
        #elseif canImport(Darwin)
        return ProcessInfo.processInfo.isMacCatalystApp
        #else
        return false
        #endif
    }

    /// A batch is identified by its payload ID rather than by a path, so that a batch listed from the directory and the
    /// same batch as it was closed are one thing.
    private func url(of payloadId: String) -> URL {
        directory.appendingPathComponent("\(EventStore.batchPrefix)\(payloadId)")
    }

    init(directory: URL,
         capacity: Int,
         persistEvents: Bool = true,
         processName: String = ProcessInfo.processInfo.processName,
         locksOpenLog: Bool = EventStore.instancesCanShareProcessName,
         logger: OSLog,
         commitQueue: DispatchQueue = DispatchQueue(label: "com.launchdarkly.EventStore.commitQueue", qos: .userInitiated),
         readFile: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) },
         writeLog: @escaping (Int32, Data) -> Int32? = EventStore.writeAll) {
        self.directory = directory
        self.processLogName = EventStore.logName(for: processName)
        self.openLogUrl = directory.appendingPathComponent(EventStore.openLogPrefix + processLogName)
        self.locksOpenLog = locksOpenLog
        self.capacity = capacity
        self.logger = logger
        self.commitQueue = commitQueue
        self.readFile = readFile
        self.writeLog = writeLog
        // An application that has not asked for persistence gets the same store running the same way it runs once a
        // write has failed: events are held, delivered, and lost only if the process dies.
        self.persistEvents = persistEvents
        self.readsDisk = persistEvents
    }

    /// Names the log belonging to one process.
    ///
    /// The readable part is the process name with anything awkward in a filename replaced, which keeps a directory of
    /// these diagnosable. That reduction is not one-to-one, and two processes sharing a log is the one thing this name
    /// exists to prevent, so a digest of the original name is appended.
    static func logName(for processName: String) -> String {
        let trimmed = processName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "unknown" : trimmed
        let readable = String(name.unicodeScalars.map { scalar -> Character in
            switch scalar {
            case "a"..."z", "A"..."Z", "0"..."9", "-", "_":
                return Character(scalar)
            default:
                return "_"
            }
        })
        let digest = Util.sha256(name).prefix(4).map { String(format: "%02x", $0) }.joined()
        return "\(readable)-\(digest)"
    }

    /// The directory the store for a mobile key belongs in, or nil where the platform gave us nowhere to write.
    ///
    /// tvOS is the reason this is not simply Application Support: a tvOS application is only allowed to persist to
    /// purgeable caches, so there the events are kept somewhere the system may reclaim, which is the most durability
    /// the platform offers.
    static func defaultDirectory(mobileKey: String) -> URL? {
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

    // MARK: Recording

    var pendingEventCount: Int {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return reservedEvents + bufferedEventCount + committedEvents + closedEvents
    }

    var isPersisting: Bool {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return persistEvents
    }

    func reserve(_ events: Int) {
        bufferLock.lock()
        reservedEvents += events
        bufferLock.unlock()
    }

    func releaseReservations() {
        bufferLock.lock()
        reservedEvents = 0
        bufferLock.unlock()
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
                bufferLock.lock()
                reservedEvents = max(0, reservedEvents - 1)
                bufferLock.unlock()
            }
            return false
        }

        bufferLock.lock()

        guard bypassingCapacity || reservedEvents + bufferedEventCount + committedEvents + closedEvents < capacity
        else {
            bufferLock.unlock()
            return false
        }

        // In the same critical section as the append, so the event is never counted twice or not at all.
        if usingReservation {
            reservedEvents = max(0, reservedEvents - 1)
        }
        bufferData.append(EventLogFormat.frame(for: encodedEvent))
        bufferedEventCount += 1
        // Nothing to schedule once persistence has been given up on: there is nowhere for a commit to put these bytes,
        // so they stay in memory until a delivery closes them into a batch.
        let needsCommit = persistEvents && bufferData.count >= EventStore.stagingThreshold && !isCommitScheduled
        if needsCommit {
            isCommitScheduled = true
        }
        bufferLock.unlock()

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
        bufferLock.lock()
        isCommitScheduled = false
        bufferLock.unlock()

        commit()
    }

    func commit() {
        ioLock.lock()
        defer { ioLock.unlock() }
        writeStagedBytes()
    }

    func closeBatch() -> EventBatch? {
        ioLock.lock()
        defer { ioLock.unlock() }

        writeStagedBytes()

        bufferLock.lock()
        let events = committedEvents
        let stillBuffered = bufferedEventCount
        bufferLock.unlock()

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
        // Closed after the rename rather than before it, so that a locked log is still locked while it moves. Another
        // instance recovering unlocked logs could otherwise take it in between.
        defer { closeDescriptor() }

        let payloadId = UUID().uuidString
        do {
            try FileManager.default.moveItem(at: openLogUrl, to: url(of: payloadId))
        } catch {
            os_log("%s could not close the event log: %s", log: logger, type: .debug, typeName(and: #function), String(describing: error))
            // The log is still there to try again with, unless it is the log that went missing -- a purged cache
            // directory on tvOS, say. Then its events are gone, and they have to stop counting against capacity or the
            // store would refuse events for the rest of the session.
            if !FileManager.default.fileExists(atPath: openLogUrl.path) {
                bufferLock.lock()
                committedEvents = 0
                bufferLock.unlock()
            }
            return nil
        }

        eventCounts[payloadId] = events

        bufferLock.lock()
        committedEvents = 0
        closedEvents += events
        bufferLock.unlock()

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
        ioLock.lock()
        defer { ioLock.unlock() }

        var batches = readsDisk ? batchesOnDisk() : []

        // After the files, since anything held in memory was closed by this run and so is newer than whatever a
        // previous run left on the disk.
        batches.append(contentsOf: inMemoryBatches.map {
            EventBatch(payloadId: $0.payloadId, eventCount: $0.eventCount)
        })

        bufferLock.lock()
        closedEvents = batches.reduce(0) { $0 + $1.eventCount }
        bufferLock.unlock()

        return batches
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
        ioLock.lock()
        defer { ioLock.unlock() }

        if let held = inMemoryBatches.first(where: { $0.payloadId == batch.payloadId }) {
            return held.body
        }

        switch read(url(of: batch.payloadId)) {
        case .missing: return nil
        case .failed(let error): throw error
        case .bytes(let file): return EventLogFormat.assembleBody(from: file)
        }
    }

    func remove(_ batch: EventBatch) {
        ioLock.lock()
        defer { ioLock.unlock() }

        if let index = inMemoryBatches.firstIndex(where: { $0.payloadId == batch.payloadId }) {
            inMemoryBatches.remove(at: index)
        } else {
            try? FileManager.default.removeItem(at: url(of: batch.payloadId))
            eventCounts[batch.payloadId] = nil
        }

        bufferLock.lock()
        closedEvents = max(0, closedEvents - batch.eventCount)
        bufferLock.unlock()
    }

    /// Closes any log left open by a previous run of this process, so its events join the batches to deliver.
    ///
    /// The events in it were recorded by a process that is gone, so there is no one left to add to it. Only this
    /// process's own log is touched: another process's may still be open in a process that is alive. Where logs are
    /// locked, any log no live process holds is recovered, whatever it is named.
    func recoverInterruptedLog() {
        ioLock.lock()
        defer { ioLock.unlock() }
        recoverInterruptedLogOnce()
    }

    /// Requires `ioLock`. Does its work once per store: after that, the open log is one this run opened.
    private func recoverInterruptedLogOnce() {
        ioLock.assertOwned()
        guard readsDisk, !hasRecoveredInterruptedLog
        else { return }
        hasRecoveredInterruptedLog = true

        guard locksOpenLog
        else {
            recover(logAt: openLogUrl)
            return
        }

        // A log that can be locked is one no live process has open, so whoever wrote it is gone. That includes a log a
        // second instance opened under its process ID, which no later run would otherwise come back for by name.
        let contents = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                    includingPropertiesForKeys: nil,
                                                                    options: [.skipsHiddenFiles])) ?? []
        for log in contents where log.lastPathComponent.hasPrefix(EventStore.openLogPrefix) {
            guard let held = EventStore.openLocked(log, flags: O_RDONLY)
            else { continue }
            recover(logAt: log)
            closeFile(held)
        }
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
        os_log("%s recovered %d event(s) from a previous run", log: logger, type: .debug, typeName(and: #function), events)
    }

    // MARK: Writing

    /// Requires `ioLock`.
    private func writeStagedBytes() {
        ioLock.assertOwned()
        bufferLock.lock()
        guard persistEvents, bufferedEventCount > 0
        else {
            // Staged bytes are left where they are. With nowhere durable to put them, memory is better than dropping
            // them: a delivery can still close them into a batch and send them.
            bufferLock.unlock()
            return
        }
        let bytes = bufferData
        let events = bufferedEventCount
        bufferData = Data()
        bufferedEventCount = 0
        bufferLock.unlock()

        if append(bytes) {
            bufferLock.lock()
            committedEvents += events
            bufferLock.unlock()
        } else {
            // Put back, to be delivered from memory rather than lost. Ahead of anything staged while the write was in
            // flight, so the events keep the order they were recorded in.
            bufferLock.lock()
            let laterFrames = bufferData
            bufferData = bytes
            bufferData.append(laterFrames)
            bufferedEventCount += events
            bufferLock.unlock()
        }
    }

    /// Requires `ioLock`.
    private func append(_ bytes: Data) -> Bool {
        ioLock.assertOwned()
        guard let descriptor = descriptorForAppending()
        else {
            disablePersistence()
            return false
        }
        return append(bytes, to: descriptor)
    }

    /// Requires `ioLock`.
    private func append(_ bytes: Data, to descriptor: Int32) -> Bool {
        ioLock.assertOwned()
        guard let failure = writeLog(descriptor, bytes)
        else { return true }

        // Never trap on a full disk. The SDK gives up on persistence for the rest of the session rather than taking
        // the application down with it, which is how other SDKs have crashed their hosts.
        os_log("%s giving up on persisting events: errno %d", log: logger, type: .debug, typeName(and: #function), failure)
        disablePersistence()
        return false
    }

    /// Writes every byte to the log, returning the errno it stopped on or nil where they all landed.
    static func writeAll(_ descriptor: Int32, _ bytes: Data) -> Int32? {
        var offset = 0
        return bytes.withUnsafeBytes { raw -> Int32? in
            guard let base = raw.baseAddress
            else { return nil }
            while offset < raw.count {
                let result = writeBytes(descriptor, base.advanced(by: offset), raw.count - offset)
                if result > 0 {
                    offset += result
                    continue
                }
                // A signal interrupting the write is not a failure; anything else is.
                if errno == EINTR {
                    continue
                }
                return errno
            }
            return nil
        }
    }

    /// Requires `ioLock`.
    private func descriptorForAppending() -> Int32? {
        ioLock.assertOwned()
        if descriptor >= 0 {
            return descriptor
        }

        // Before opening, because the open log may still be the one a previous run died writing. Appended to, this run's
        // events would sit behind that run's torn last frame, where a reader can no longer find where they start.
        recoverInterruptedLogOnce()

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            os_log("%s could not create the event directory: %s", log: logger, type: .debug, typeName(and: #function), String(describing: error))
            return nil
        }
        excludeFromBackup()

        guard let opened = openLogForAppending()
        else {
            os_log("%s could not open the event log: errno %d", log: logger, type: .debug, typeName(and: #function), errno)
            return nil
        }

        descriptor = opened

        if lseek(opened, 0, SEEK_END) == 0 {
            guard append(EventLogFormat.fileHeader, to: opened)
            else { return nil }
        }

        return descriptor
    }

    /// Opens the log this process appends to, locked where logs are. Requires `ioLock`.
    private func openLogForAppending() -> Int32? {
        ioLock.assertOwned()
        // O_APPEND is what makes each write land at the end of the file as one step, so that clients for several
        // environments writing their own logs, or a commit racing a reader, cannot produce a spliced frame.
        let flags = O_WRONLY | O_APPEND | O_CREAT
        guard locksOpenLog
        else {
            let opened = EventStore.openDescriptor(at: openLogUrl, flags: flags)
            return opened >= 0 ? opened : nil
        }

        if let opened = EventStore.openLocked(openLogUrl, flags: flags) {
            return opened
        }

        // Another live instance of the application holds the log for this process name, so this one takes a log of its
        // own. The process ID keeps it apart from every other live process, and the suffix from another store in this
        // one, as a closed client's can be while it is still going away. Recovery finds the log by its lock rather than
        // its name, so it is not orphaned when this instance ends.
        let ownLog = directory.appendingPathComponent(
            "\(EventStore.openLogPrefix)\(processLogName)-\(getpid())-\(UUID().uuidString.prefix(8))")
        guard let opened = EventStore.openLocked(ownLog, flags: flags)
        else { return nil }
        openLogUrl = ownLog
        return opened
    }

    private static func openDescriptor(at url: URL, flags: Int32) -> Int32 {
        url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path = path
            else { return -1 }
            return openFile(path, flags, 0o600)
        }
    }

    /// Opens a file and takes its lock without waiting, or nil where another live process holds it.
    ///
    /// The lock has to be on the file that is still at `url`: one renamed or removed between the open and the lock,
    /// by another process closing off or recovering it, is no longer a log anyone appends to.
    private static func openLocked(_ url: URL, flags: Int32) -> Int32? {
        for _ in 0..<3 {
            let opened = openDescriptor(at: url, flags: flags)
            guard opened >= 0
            else { return nil }
            guard lockFile(opened)
            else {
                closeFile(opened)
                return nil
            }
            if isFile(opened, at: url) {
                return opened
            }
            closeFile(opened)
        }
        return nil
    }

    /// Requires `ioLock`.
    private func closeDescriptor() {
        ioLock.assertOwned()
        guard descriptor >= 0
        else { return }
        closeFile(descriptor)
        descriptor = -1
    }

    private func excludeFromBackup() {
        #if canImport(Darwin)
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        #endif
    }

    deinit {
        // One acquisition: the lock is not recursive, and `commit()` would take it again.
        ioLock.lock()
        writeStagedBytes()
        closeDescriptor()
        ioLock.unlock()
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
        closeDescriptor()
        bufferLock.lock()
        persistEvents = false
        bufferLock.unlock()
    }

    /// Closes whatever is staged into a batch that never reaches a file.
    ///
    /// Requires `ioLock`.
    func closeInMemoryBatch() -> EventBatch? {
        ioLock.assertOwned()
        bufferLock.lock()
        let frames = bufferData
        let events = bufferedEventCount
        bufferData = Data()
        bufferedEventCount = 0
        bufferLock.unlock()

        // Assembled through the same reader a batch on disk goes through, so a held batch and a written one produce
        // byte-identical request bodies.
        var log = EventLogFormat.fileHeader
        log.append(frames)
        guard let body = EventLogFormat.assembleBody(from: log)
        else { return nil }

        let payloadId = UUID().uuidString
        inMemoryBatches.append(HeldBatch(payloadId: payloadId, body: body, eventCount: events))

        bufferLock.lock()
        closedEvents += events
        bufferLock.unlock()

        return EventBatch(payloadId: payloadId, eventCount: events)
    }
}

/// The on-disk shape of an event log.
///
/// A log opens with a magic and a format version, and holds a sequence of frames:
///
///     +- 4 bytes -+- 2 bytes -+     +- 2 bytes -+-  4 bytes  -+- n bytes -+
///     |   LDEV    |  version  | ... |   type    |  length (n) |  payload  |
///     +-----------+-----------+     +-----------+-------------+-----------+
///
/// The length prefix is what makes a log recoverable: a reader can tell a frame the writer finished from one it did not,
/// without having to parse the event to find where it ends. The version is what makes an upgrade safe -- a log this
/// version does not understand is discarded rather than misread -- and the frame type leaves room for a later version to
/// write something new into a log this one still reads.
enum EventLogFormat {
    /// Bump this whenever the framing or the meaning of a frame changes.
    static let version: UInt16 = 1
    static let magic = Data("LDEV".utf8)
    static let fileHeaderSize = 6
    static let frameHeaderSize = 6
    /// The only frame type written today; a reader skips a frame whose type it does not know.
    static let eventFrame: UInt16 = 1
    /// A ceiling on a single frame, so a corrupt length cannot make recovery allocate wildly.
    static let maxFrameSize = 8 * 1024 * 1024

    static var fileHeader: Data {
        var header = magic
        header.append(bigEndian(version))
        return header
    }

    static func frame(for encodedEvent: Data) -> Data {
        var frame = Data(capacity: frameHeaderSize + encodedEvent.count)
        frame.append(bigEndian(eventFrame))
        frame.append(bigEndian(UInt32(encodedEvent.count)))
        frame.append(encodedEvent)
        return frame
    }

    /// Walks the frames of a log, stopping at the first one that is not wholly there.
    ///
    /// A process that died partway through a write leaves a torn frame at the end. Everything before it is intact, so
    /// recovery keeps that and drops only the tail. Returns false when the file is not a log this version reads.
    static func forEachFrame(in file: Data, _ visit: (UInt16, Data) -> Void) -> Bool {
        guard file.count >= fileHeaderSize,
              file.prefix(magic.count) == magic,
              readUInt16(file, at: magic.count) == version
        else { return false }

        var cursor = fileHeaderSize
        while cursor + frameHeaderSize <= file.count {
            let type = readUInt16(file, at: cursor)
            let length = Int(readUInt32(file, at: cursor + 2))
            let start = cursor + frameHeaderSize
            guard length > 0, length <= maxFrameSize, start + length <= file.count
            else { break }

            visit(type, file.subdata(in: start..<(start + length)))
            cursor = start + length
        }
        return true
    }

    /// How many events a log holds, or nil where it is not one this version reads.
    static func eventCount(in file: Data) -> Int? {
        var events = 0
        guard forEachFrame(in: file, { type, _ in
            if type == eventFrame {
                events += 1
            }
        })
        else { return nil }
        return events
    }

    /// Assembles the JSON array LaunchDarkly expects out of the frames, without parsing the events themselves: they were
    /// serialized on the way in and are shipped exactly as they were recorded.
    static func assembleBody(from file: Data) -> Data? {
        var body = Data("[".utf8)
        var isFirst = true
        let readable = forEachFrame(in: file) { type, payload in
            guard type == eventFrame
            else { return }
            if !isFirst {
                body.append(UInt8(ascii: ","))
            }
            body.append(payload)
            isFirst = false
        }

        guard readable, !isFirst
        else { return nil }

        body.append(UInt8(ascii: "]"))
        return body
    }

    static func bigEndian(_ value: UInt16) -> Data {
        Data([UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)])
    }

    static func bigEndian(_ value: UInt32) -> Data {
        Data([UInt8(truncatingIfNeeded: value >> 24),
              UInt8(truncatingIfNeeded: value >> 16),
              UInt8(truncatingIfNeeded: value >> 8),
              UInt8(truncatingIfNeeded: value)])
    }

    static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        let start = data.startIndex + offset
        return UInt16(data[start]) << 8 | UInt16(data[start + 1])
    }

    static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        let start = data.startIndex + offset
        return UInt32(data[start]) << 24 | UInt32(data[start + 1]) << 16 | UInt32(data[start + 2]) << 8 | UInt32(data[start + 3])
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

        guard readsDisk
        else { return [] }

        let contents = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                    includingPropertiesForKeys: nil,
                                                                    options: [.skipsHiddenFiles])) ?? []
        var logs = contents.filter { $0.lastPathComponent.hasPrefix(EventStore.batchPrefix) }.sorted { $0.path < $1.path }
        if FileManager.default.fileExists(atPath: openLogUrl.path) {
            logs.append(openLogUrl)
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

extension EventStore: TypeIdentifying { }

// The POSIX calls are wrapped so that the names cannot be shadowed by a member of the type using them, and so the
// platform differences stay in one place. Foundation's FileHandle is deliberately not used: it raises an Objective-C
// exception when a write fails, which is not something a Swift caller can catch, and has taken host applications down
// with it when a device ran out of space.
#if canImport(Darwin)
private func openFile(_ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 {
    Darwin.open(path, flags, mode)
}

private func writeBytes(_ descriptor: Int32, _ bytes: UnsafeRawPointer, _ count: Int) -> Int {
    Darwin.write(descriptor, bytes, count)
}

private func closeFile(_ descriptor: Int32) {
    _ = Darwin.close(descriptor)
}

/// Takes an exclusive lock without waiting. Released by the kernel when the descriptor closes, including when the
/// process dies, so a crashed process never leaves one behind.
private func lockFile(_ descriptor: Int32) -> Bool {
    flock(descriptor, LOCK_EX | LOCK_NB) == 0
}
#else
private func openFile(_ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 {
    open(path, flags, mode)
}

private func writeBytes(_ descriptor: Int32, _ bytes: UnsafeRawPointer, _ count: Int) -> Int {
    write(descriptor, bytes, count)
}

private func closeFile(_ descriptor: Int32) {
    _ = close(descriptor)
}

private func lockFile(_ descriptor: Int32) -> Bool {
    flock(descriptor, LOCK_EX | LOCK_NB) == 0
}
#endif

/// Whether a descriptor is open on the file currently at `url`, rather than one since renamed or removed.
private func isFile(_ descriptor: Int32, at url: URL) -> Bool {
    var opened = stat()
    var named = stat()
    guard fstat(descriptor, &opened) == 0
    else { return false }
    let found = url.withUnsafeFileSystemRepresentation { path -> Bool in
        guard let path = path
        else { return false }
        return stat(path, &named) == 0
    }
    return found && opened.st_ino == named.st_ino && opened.st_dev == named.st_dev
}
