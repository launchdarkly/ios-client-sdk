import Foundation
import OSLog

/// How many events, and how many bytes, something stored holds: the two things capacity counts. With how many of the
/// events are summaries, which capacity leaves out, where this store wrote them.
struct EventTally: Equatable {
    var events = 0
    var bytes = 0
    /// How many of `events` are known to be summaries; none for a batch this store did not close.
    var summaries = 0

    static func += (lhs: inout EventTally, rhs: EventTally) {
        lhs.events += rhs.events
        lhs.bytes += rhs.bytes
        lhs.summaries += rhs.summaries
    }
}

/// The directory one store keeps its events in: the log this process appends to, and beside it the batches that have
/// been closed off for delivery.
///
/// Everything about the filesystem lives here -- where the directory is, what the files in it are called, and how they
/// are listed, read, moved and deleted -- so that `EventStore` is left with the buffer, the capacity arithmetic, and
/// the batches it holds in memory, none of which need a disk at all. A store the application told to keep events off
/// the disk has no `EventDirectory`, rather than one it is careful never to use.
///
/// Where the directory is, is worked out on first use rather than at construction, so that a store which never reaches
/// for the disk makes no filesystem call at all, not even to find out where it would have written.
///
/// Belongs to an `EventStore`, which makes every call holding its `ioLock`, exactly as `DiskEventLog` belongs to this.
/// The lock is handed down so that each call can check it is held, rather than each level taking a lock of its own
/// that would have to be ordered against the others.
final class EventDirectory {
    /// Names a log that has been closed off for delivery. The rest of the name is the batch's payload ID and how many
    /// events are in it, `ready-<payloadId>.<count>`. Anything more a batch needs to say belongs in a frame type readers
    /// skip, rather than in the name.
    ///
    /// The count is in the name so that listing a batch this process did not close costs a directory entry rather than
    /// a read of the whole file. That is what every batch is at startup: the ones a previous run left behind, and the
    /// ones belonging to another process sharing the environment. Reading them all is done holding `ioLock`, which a
    /// commit at a commit point then waits behind.
    ///
    /// A batch is never appended to once it is closed, so the count is as good as the file is.
    private static let batchPrefix = "ready-"
    private static let nameFieldSeparator: Character = "."

    private let locateDirectory: () -> URL
    private let ioLock: UnfairLock
    private let logger: OSLog
    /// How a stored log is read, injectable so a test can make a read fail while the file is intact.
    private let readFile: (URL) throws -> Data
    /// How bytes reach the open log, injectable so a test can make a write fail partway through a session.
    private let writeLog: (EventLogFile, Data) -> Int32?

    /// Only to be used while holding `ioLock`.
    private var located: (directory: URL, log: DiskEventLog)?

    /// A batch in the directory: the file it is, how many events it holds, how big it is, when it was last written,
    /// which is what orders batches oldest first, and how many of its events this store knows to be summaries.
    private struct Stored {
        let url: URL
        let events: Int
        let bytes: Int
        let modified: Date
        var summaries = 0

        var tally: EventTally { EventTally(events: events, bytes: bytes, summaries: summaries) }
    }

    /// What this process knows about each batch in the directory, by payload ID, which is how everything outside this
    /// class names one.
    ///
    /// The file is remembered rather than composed from the payload ID, because the count is part of the name and a
    /// batch closed by a version that did not write one has no count to compose. The count is remembered so that such
    /// a batch is read at most once.
    ///
    /// Only to be used while holding `ioLock`.
    private var stored: [String: Stored] = [:]

    /// Batches LaunchDarkly has accepted whose file the filesystem would not let go of.
    ///
    /// Left out of every listing, because a batch that is delivered and merely still on the disk would otherwise be
    /// found again by the next delivery, and the one after that, and sent each time. The delete is tried once more on
    /// each listing, so a directory that stops being read-only clears itself.
    ///
    /// Only for this session: a later run, which may well be able to delete the file, treats it as it would any other
    /// batch a previous run left behind. LaunchDarkly discards a repeated payload ID, so the cost of that is a wasted
    /// request rather than events counted twice.
    ///
    /// Only to be used while holding `ioLock`.
    private var deliveredButUndeleted: Set<String> = []

    /// The batches this store has a request out for, by payload ID: the file each was locked under, so the lock is
    /// released from that file even once the batch has been removed or dropped from a listing, and how many of this
    /// store's deliveries are sending it.
    ///
    /// Only to be used while holding `ioLock`.
    private var sending: [String: (url: URL, senders: Int)] = [:]

    /// What `openInThisProcess` counts this store under, from locating the directory until closing the log, kept so
    /// that the count is taken back under the same path even once the directory is gone. Only to be used while holding
    /// `ioLock`.
    private var countedAsOpen: String?

    /// The directories of the stores open in this process, by resolved path, with how many stores have each open. Another
    /// environment's sweep leaves these alone, however long since they were written: a store that is open may be about
    /// to write, or be sending a batch older than the cutoff. Guarded by `openInThisProcessLock`.
    private static var openInThisProcess: [String: Int] = [:]
    private static let openInThisProcessLock = UnfairLock()

    #if os(macOS) || targetEnvironment(macCatalyst)
    /// Whether the open log is locked while it is open. Only to be changed before the store first touches the disk.
    ///
    /// Kept here rather than asked of the log, so that setting it does not build the log and with it work out where
    /// the directory is. Only to be used while holding `ioLock`.
    var locksOpenLog = true {
        didSet { located?.log.isLocked = locksOpenLog }
    }
    #endif

    /// - Parameter locatingDirectory: answers where the events go. Asked once, and only on first use.
    init(locatingDirectory: @escaping () -> URL,
         ioLock: UnfairLock,
         logger: OSLog,
         readFile: @escaping (URL) throws -> Data,
         writeLog: @escaping (EventLogFile, Data) -> Int32?) {
        self.locateDirectory = locatingDirectory
        self.ioLock = ioLock
        self.logger = logger
        self.readFile = readFile
        self.writeLog = writeLog
    }

    /// The directory and the log in it, worked out the first time either is reached for. Requires `ioLock`.
    private var disk: (directory: URL, log: DiskEventLog) {
        ioLock.assertOwned()
        if let located {
            return located
        }
        let directory = locateDirectory()
        let log = DiskEventLog(directory: directory,
                               ioLock: ioLock,
                               logger: logger,
                               writeLog: writeLog)
        #if os(macOS) || targetEnvironment(macCatalyst)
        log.isLocked = locksOpenLog
        #endif
        let disk = (directory: directory, log: log)
        located = disk
        let path = directory.resolvingSymlinksInPath().path
        countedAsOpen = path
        EventDirectory.openInThisProcessLock.withLock { EventDirectory.openInThisProcess[path, default: 0] += 1 }
        return disk
    }

    private static func isOpenInThisProcess(_ directory: URL) -> Bool {
        let path = directory.resolvingSymlinksInPath().path
        return openInThisProcessLock.withLock { openInThisProcess[path] != nil }
    }

    /// Where the batches are kept. Requires `ioLock`.
    var url: URL { disk.directory }

    /// Where the log this process appends to is, for a test or a diagnosis to look at. Requires `ioLock`.
    var openLogUrl: URL { disk.log.url }

    /// A batch is identified by its payload ID rather than by a path, so that a batch listed from the directory and
    /// the same batch as it was closed are one thing. Requires `ioLock`.
    ///
    /// - Parameter events: what the caller holding the batch knows it to contain, which is what names it where this
    ///   process has neither closed nor listed it -- as when it delivers a batch another process closed.
    private func url(of payloadId: String, holding events: Int) -> URL {
        stored[payloadId]?.url ?? newUrl(of: payloadId, holding: events)
    }

    /// Requires `ioLock`.
    private func newUrl(of payloadId: String, holding events: Int) -> URL {
        disk.directory.appendingPathComponent(
            "\(EventDirectory.batchPrefix)\(payloadId)\(EventDirectory.nameFieldSeparator)\(events)")
    }

    /// A batch as its name, `ready-<payloadId>.<count>`, gives it: each field by its position.
    ///
    /// Fields are split at `nameFieldSeparator`, which a payload ID never contains, so nothing about the count's own
    /// characters is needed to tell it apart. Fields after it, which a later version might add, are ignored.
    ///
    /// - Returns: the payload ID, and the count, which is nil where the name has none or it does not parse -- a batch a
    ///   recovery could not read, which is read once to count it.
    private static func parse(batchName name: String) -> (payloadId: String, events: Int?) {
        let fields = name.dropFirst(batchPrefix.count)
            .split(separator: nameFieldSeparator, omittingEmptySubsequences: false)
        let payloadId = String(fields[0])
        guard fields.count > 1, !fields[1].isEmpty, fields[1].allSatisfy({ $0.isASCII && $0.isNumber }),
              let events = Int32(fields[1])
        else { return (payloadId, nil) }
        return (payloadId, Int(events))
    }

    // MARK: Writing

    /// Appends to the open log, opening a new one where none is open. Requires `ioLock`.
    ///
    /// - Returns: whether every byte landed. False means none of `bytes` is in the log, and that the caller should give
    ///   up on the disk.
    func append(_ bytes: Data) -> Bool {
        ioLock.assertOwned()
        return disk.log.append(bytes)
    }

    /// What closing the open log produced.
    enum LogClose {
        case closed(EventBatch)
        /// The log is still there and still open, for the next append to continue and the next close to try again,
        /// unless `logSurvives` is false -- a purged cache directory on tvOS, say. Then its events are gone, and they
        /// have to stop counting against capacity or the store would refuse events for the rest of the session.
        case failed(logSurvives: Bool)
    }

    /// Closes the open log into a batch, so the next append starts a new one. Requires `ioLock`.
    ///
    /// - Parameter held: what the log holds, which the caller has counted as it staged and wrote it.
    func closeLog(holding held: EventTally) -> LogClose {
        ioLock.assertOwned()
        let events = held.events
        let payloadId = UUID().uuidString
        let file = newUrl(of: payloadId, holding: events)
        do {
            try disk.log.close(movingTo: file)
        } catch {
            os_log("%s could not close the event log, will try again at the next delivery: %s", log: logger, type: .info, typeName(and: #function), String(describing: error))
            guard disk.log.exists
            else {
                disk.log.closeDescriptor()
                return .failed(logSurvives: false)
            }
            return .failed(logSurvives: true)
        }

        stored[payloadId] = Stored(url: file, events: events, bytes: held.bytes, modified: Date(), summaries: held.summaries)
        return .closed(EventBatch(payloadId: payloadId, eventCount: events))
    }

    /// Closes the descriptor, leaving everything where it is, and stops counting the directory as open in this process.
    /// Requires `ioLock`.
    func closeOpenLog() {
        ioLock.assertOwned()
        // Not `disk`: a store that never wrote has never worked out where it lives, and shutting down or giving up on
        // the disk is no reason to start.
        located?.log.closeDescriptor()
        guard let path = countedAsOpen
        else { return }
        countedAsOpen = nil
        EventDirectory.openInThisProcessLock.withLock {
            let stores = EventDirectory.openInThisProcess[path] ?? 0
            EventDirectory.openInThisProcess[path] = stores > 1 ? stores - 1 : nil
        }
    }

    /// Locks a batch against expiry, in this process and every other, for as long as a request for it is out. Each
    /// call is ended by one `stoppedSending(_:)`. Requires `ioLock`.
    ///
    /// - Parameter events: what the caller holding the batch knows it to contain, as for `payload(of:)`.
    func startedSending(_ payloadId: String, holding events: Int) {
        ioLock.assertOwned()
        var batch = sending[payloadId] ?? (url: url(of: payloadId, holding: events), senders: 0)
        batch.senders += 1
        sending[payloadId] = batch
        BatchLocks.startedSending(batch.url)
    }

    /// Ends one `startedSending(_:holding:)`. Requires `ioLock`.
    func stoppedSending(_ payloadId: String) {
        ioLock.assertOwned()
        guard var batch = sending[payloadId]
        else { return }
        BatchLocks.stoppedSending(batch.url)
        batch.senders -= 1
        sending[payloadId] = batch.senders > 0 ? batch : nil
    }

    // MARK: Listing and reading

    /// The batches in the directory, oldest first. Requires `ioLock`.
    ///
    /// Sizes come from the same listing, so that counting the directory's bytes reads no file either.
    ///
    /// A directory that is not there holds nothing. One that is there and cannot be listed -- out of file descriptors,
    /// or no longer readable -- is not empty, so it answers with the batches the last listing or close counted, as they
    /// were counted, and says the listing is incomplete.
    func listBatches() -> BatchListing {
        ioLock.assertOwned()
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(at: disk.directory,
                                                                   includingPropertiesForKeys: EventDirectory.listedKeys,
                                                                   options: [.skipsHiddenFiles])
        } catch {
            guard FileManager.default.fileExists(atPath: disk.directory.path)
            else {
                stored = [:]
                return BatchListing(batches: [], isComplete: true)
            }
            os_log("%s could not list stored events, will try again at the next delivery: %s", log: logger, type: .info, typeName(and: #function), String(describing: error))
            let known = stored
                .sorted { $0.value.modified < $1.value.modified }
                .map { EventBatch(payloadId: $0.key, eventCount: $0.value.events) }
            return BatchListing(batches: known, isComplete: false)
        }

        let batches = contents
            .filter { $0.lastPathComponent.hasPrefix(EventDirectory.batchPrefix) }
            .compactMap { file -> (EventBatch, Date)? in
                let (payloadId, counted) = EventDirectory.parse(batchName: file.lastPathComponent)
                guard !isDeliveredButUndeleted(payloadId, at: file)
                else { return nil }
                // Reading is only for a batch whose name does not count it, which a version that named them without a
                // count may have left behind, and then only the once.
                guard let events = counted ?? stored[payloadId]?.events ?? countOfEvents(in: file)
                else { return nil }
                let listed = EventDirectory.listed(file)
                let modified = listed.modified ?? Date.distantPast
                // What the close knew of its summaries is kept; nothing in the file says.
                let previous = stored[payloadId]
                stored[payloadId] = Stored(url: file, events: events, bytes: listed.bytes ?? previous?.bytes ?? 0,
                                           modified: modified,
                                           summaries: previous.map { $0.events == events ? $0.summaries : 0 } ?? 0)
                return (EventBatch(payloadId: payloadId, eventCount: events), modified)
            }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }

        // A batch that left the directory without going through `remove` -- a purged cache directory on tvOS, say --
        // would otherwise keep its count for the rest of the session.
        let listed = Set(batches.map { $0.payloadId })
        stored = stored.filter { listed.contains($0.key) }

        return BatchListing(batches: batches, isComplete: true)
    }

    private static let listedKeys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]

    /// What a directory listing says about a file, without opening it.
    private static func listed(_ file: URL) -> (bytes: Int?, modified: Date?) {
        let values = try? file.resourceValues(forKeys: Set(listedKeys))
        return (values?.fileSize, values?.contentModificationDate)
    }

    /// The bytes in every batch the last listing or close counted. Requires `ioLock`.
    var storedBytes: Int {
        ioLock.assertOwned()
        return stored.values.reduce(0) { $0 + $1.bytes }
    }

    /// The summaries known to be in the batches the last listing or close counted. Requires `ioLock`.
    var storedSummaries: Int {
        ioLock.assertOwned()
        return stored.values.reduce(0) { $0 + $1.summaries }
    }

    /// What this process counts for a batch, or nil if it counts nothing for it: one removed, or dropped by a listing it
    /// was no longer in. Requires `ioLock`.
    func counted(_ payloadId: String) -> EventTally? {
        ioLock.assertOwned()
        return stored[payloadId]?.tally
    }

    /// Whether a batch has already been delivered and only its file is left, trying the delete that failed once more
    /// on the way. Requires `ioLock`.
    private func isDeliveredButUndeleted(_ payloadId: String, at file: URL) -> Bool {
        guard deliveredButUndeleted.contains(payloadId)
        else { return false }
        try? FileManager.default.removeItem(at: file)
        if !FileManager.default.fileExists(atPath: file.path) {
            deliveredButUndeleted.remove(payloadId)
        }
        return true
    }

    /// The `[...]` payload for a batch, assembled in the bytes the file was read into; or nil if it is gone or holds no
    /// events.
    ///
    /// Requires `ioLock`.
    ///
    /// - throws: `UnreadableBatch` if the batch is there but holds nothing this version can send; anything else if it
    ///   could not be read this time, which a later attempt may manage.
    func payload(of batch: EventBatch) throws -> BatchPayload? {
        ioLock.assertOwned()
        // Taken out of the read's result rather than bound inside the switch, so that nothing else refers to it and it
        // is assembled where it is rather than copied first.
        var file: Data
        switch read(url(of: batch.payloadId, holding: batch.eventCount)) {
        case .missing: return nil
        case .failed(let error): throw error
        case .bytes(let bytes): file = bytes
        }
        // No more than the batch was closed holding. A write that failed and could not be truncated leaves whole frames
        // after them, whose events are delivered from memory instead, and would otherwise be sent twice.
        let assembled = EventLogFormat.assembleBody(inPlace: &file, maxEvents: batch.eventCount > 0 ? batch.eventCount : .max)
        if assembled > 0 {
            return BatchPayload(body: file, eventCount: assembled)
        }
        // A log this version reads that holds no events has nothing to lose, unless its first frame is damaged. Where
        // there is no payload the log is as it was read.
        guard EventLogFormat.eventCount(in: file) == 0, !EventLogFormat.isDamaged(file)
        else { throw UnreadableBatch(payloadId: batch.payloadId) }
        return nil
    }

    /// Forgets a batch. Requires `ioLock`.
    ///
    /// - Returns: what it stopped counting, which is nothing for a batch that was already gone -- one another process
    ///   delivered, say, which a listing has stopped counting already.
    func remove(_ payloadId: String, holding events: Int) -> EventTally {
        ioLock.assertOwned()
        let file = url(of: payloadId, holding: events)
        try? FileManager.default.removeItem(at: file)
        if FileManager.default.fileExists(atPath: file.path) {
            // Its events stop counting all the same: LaunchDarkly has them, and holding capacity for a file this
            // process may never be allowed to delete would cost the session events it could still have recorded.
            os_log("%s could not delete a delivered batch; it will not be sent again this session", log: logger, type: .debug, typeName(and: #function))
            deliveredButUndeleted.insert(payloadId)
        }
        return stored.removeValue(forKey: payloadId)?.tally ?? EventTally()
    }

    /// Every event in the directory, encoded exactly as it will be sent. Requires `ioLock`.
    ///
    /// For tests and for diagnosing a store rather than for the recording path: it reads every file.
    func storedPayloads() -> [Data] {
        ioLock.assertOwned()
        let contents = (try? FileManager.default.contentsOfDirectory(at: disk.directory,
                                                                     includingPropertiesForKeys: nil,
                                                                     options: [.skipsHiddenFiles])) ?? []
        var logs = contents.filter { $0.lastPathComponent.hasPrefix(EventDirectory.batchPrefix) }.sorted { $0.path < $1.path }
        if disk.log.exists {
            logs.append(disk.log.url)
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
            os_log("%s could not read stored events, will try again at the next delivery: %s", log: logger, type: .info, typeName(and: #function), String(describing: error))
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

    // MARK: Recovery

    /// A log whose writer is gone, and what reading it found.
    struct InterruptedLog {
        fileprivate enum Contents {
            case missing
            case failed(Error)
            /// Not a log this version reads.
            case unreadable
            case events(EventTally)
        }

        fileprivate let url: URL
        fileprivate let contents: Contents
    }

    /// The logs recovery is to close off, so their events join the batches to deliver: every one no store in this
    /// process has open, of which `DiskEventLog.claimForRecovery(_:)` then takes those no live process holds.
    ///
    /// The events in them were recorded by a store that is gone, so there is no one left to add to them: a previous run
    /// of this process, or another process that has since ended, whatever it was called.
    ///
    /// Requires `ioLock`.
    func interruptedLogs() -> [URL] {
        ioLock.assertOwned()
        return disk.log.logsNotOpenInThisProcess()
    }

    /// Reads and counts a log recovery has claimed.
    ///
    /// Needs no lock, and is meant to be called without `ioLock`: a log can be as large as a batch, and a commit at a
    /// commit point would otherwise wait for every log a crash left. Nothing here is this directory's state, and the
    /// log's writer is gone, so it is not changing either.
    func read(interruptedLog leftOpen: URL) -> InterruptedLog {
        switch read(leftOpen) {
        case .missing:
            return InterruptedLog(url: leftOpen, contents: .missing)
        case .failed(let error):
            return InterruptedLog(url: leftOpen, contents: .failed(error))
        case .bytes(let log):
            guard let events = EventLogFormat.eventCount(in: log)
            else { return InterruptedLog(url: leftOpen, contents: .unreadable) }
            return InterruptedLog(url: leftOpen, contents: .events(EventTally(events: events, bytes: log.count)))
        }
    }

    /// Closes off a log `read(interruptedLog:)` read. Requires `ioLock`, which is what keeps a listing from counting
    /// the batch it becomes on its own as well.
    ///
    /// - Returns: what it closed off, or nothing where there was nothing to close off.
    func preparePayload(from interrupted: InterruptedLog) -> EventTally {
        ioLock.assertOwned()
        let leftOpen = interrupted.url
        let events: Int
        let bytes: Int
        switch interrupted.contents {
        case .missing:
            return EventTally()
        case .failed(let error):
            // Deleting it would lose events that may be intact, and left under this name it would wait for the next
            // run's recovery. Closed off uncounted instead, it is read and counted by whichever listing first manages
            // to.
            // Named without a count, which is what a batch whose events have never been counted is: the listing that
            // first manages to read it is what counts it.
            let uncounted = disk.directory.appendingPathComponent("\(EventDirectory.batchPrefix)\(UUID().uuidString)")
            if (try? FileManager.default.moveItem(at: leftOpen, to: uncounted)) != nil {
                os_log("%s could not read events from a previous run, will try again at the next delivery: %s", log: logger, type: .info, typeName(and: #function), String(describing: error))
            } else {
                // Left where it is, unlocked and appended to by no one, for the next launch to recover.
                os_log("%s could not read events from a previous run, will try again at the next launch: %s", log: logger, type: .info, typeName(and: #function), String(describing: error))
            }
            return EventTally()
        case .unreadable:
            // A log that cannot be read cannot be appended to either.
            try? FileManager.default.removeItem(at: leftOpen)
            return EventTally()
        case .events(let counted):
            events = counted.events
            bytes = counted.bytes
        }

        guard events > 0
        else {
            try? FileManager.default.removeItem(at: leftOpen)
            return EventTally()
        }

        let payloadId = UUID().uuidString
        let file = newUrl(of: payloadId, holding: events)
        guard (try? FileManager.default.moveItem(at: leftOpen, to: file)) != nil
        else {
            // Gone since it was read is another store recovering it first, which where logs are not locked can be one
            // in this process.
            if FileManager.default.fileExists(atPath: leftOpen.path) {
                os_log("%s could not prepare %d event(s) from a previous run, will try again at the next launch", log: logger, type: .info, typeName(and: #function), events)
            }
            return EventTally()
        }

        let recovered = Stored(url: file, events: events, bytes: bytes, modified: EventDirectory.listed(file).modified ?? Date())
        stored[payloadId] = recovered
        return recovered.tally
    }
}

// MARK: Expiry

extension EventDirectory {
    /// Deletes the batches in this directory last written before `cutoff`, and the logs no live process holds that have
    /// not been written since then either. Requires `ioLock`.
    ///
    /// A batch's modification time is when its newest event was written, since a batch is renamed rather than rewritten
    /// when it is closed, so a batch is discarded only once everything in it is that old. A log is discarded only once
    /// nothing is appending to it, however long ago it was written: a live process may have gone that long without an
    /// event.
    ///
    /// A batch whose request is out is left alone however old it is, whichever store or process sent it; see
    /// `BatchLocks`.
    ///
    /// - Parameter sending: batches whose request is out from this store.
    /// - Returns: how many events were discarded, and how much this process had counted of the batches that left the
    ///   directory, which is what stops counting against capacity.
    func discard(lastWrittenBefore cutoff: Date, sparing sending: Set<String>) -> (events: Int, counted: EventTally) {
        ioLock.assertOwned()
        let contents = (try? FileManager.default.contentsOfDirectory(at: disk.directory,
                                                                     includingPropertiesForKeys: EventDirectory.listedKeys,
                                                                     options: [.skipsHiddenFiles])) ?? []
        var events = 0
        var counted = EventTally()
        for file in contents where EventDirectory.listed(file).modified.map({ $0 < cutoff }) ?? false {
            let name = file.lastPathComponent
            if name.hasPrefix(EventDirectory.batchPrefix) {
                let (payloadId, named) = EventDirectory.parse(batchName: name)
                guard !sending.contains(payloadId), !deliveredButUndeleted.contains(payloadId),
                      !BatchLocks.isSentInThisProcess(file)
                else { continue }
                let held = named ?? stored[payloadId]?.events ?? EventDirectory.eventsReading(file)
                guard BatchLocks.deleteUnlessBeingSent(file)
                else {
                    if !FileManager.default.fileExists(atPath: file.path) {
                        // Delivered by another process since the listing: no longer counted, and not dropped.
                        counted += stored.removeValue(forKey: payloadId)?.tally ?? EventTally()
                    }
                    continue
                }
                events += held
                counted += stored.removeValue(forKey: payloadId)?.tally ?? EventTally()
            } else {
                events += EventDirectory.discardIfAbandonedLog(file)
            }
        }
        return (events, counted)
    }

    /// Empties and removes the directories of other environments that nothing has written to since `cutoff`: those
    /// of a mobile key the application no longer uses, which no client will look in again.
    ///
    /// Age decides rather than the keys the application configures, because another process of the same application
    /// may be using a key this one does not configure. Nothing is touched here that this store reads or writes, so it
    /// needs no lock. A directory is removed only if it is empty, so a log another process starts in it meanwhile
    /// keeps the directory and itself.
    ///
    /// Only directories carrying this application's bundle identifier are considered. An unsandboxed Mac application
    /// shares Application Support with every other one, whose events are not this application's to delete.
    ///
    /// The directory of a store open in this process is left alone, and so is a batch some live process is sending;
    /// see `BatchLocks`.
    ///
    /// - Returns: how many events were discarded.
    static func discardAbandonedEnvironments(besides current: URL, lastWrittenBefore cutoff: Date) -> Int {
        let root = current.deletingLastPathComponent()
        let ownName = current.lastPathComponent
        let isSameApplication: (String) -> Bool
        if let dot = ownName.firstIndex(of: ".") {
            let prefix = ownName[...dot]
            isSameApplication = { $0.hasPrefix(prefix) }
        } else {
            isSameApplication = { !$0.contains(".") }
        }

        let siblings = (try? FileManager.default.contentsOfDirectory(at: root,
                                                                     includingPropertiesForKeys: [.isDirectoryKey],
                                                                     options: [.skipsHiddenFiles])) ?? []
        var events = 0
        for directory in siblings where directory.lastPathComponent != ownName && isSameApplication(directory.lastPathComponent) {
            guard (try? directory.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true,
                  !isOpenInThisProcess(directory)
            else { continue }
            let contents = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                         includingPropertiesForKeys: listedKeys,
                                                                         options: [])) ?? []
            for file in contents where listed(file).modified.map({ $0 < cutoff }) ?? false {
                let name = file.lastPathComponent
                if name.hasPrefix(batchPrefix) {
                    guard !BatchLocks.isSentInThisProcess(file)
                    else { continue }
                    let held = parse(batchName: name).events ?? eventsReading(file)
                    if BatchLocks.deleteUnlessBeingSent(file) {
                        events += held
                    }
                } else {
                    events += discardIfAbandonedLog(file)
                }
            }
            EventLogFile.removeDirectoryIfEmpty(directory)
        }
        return events
    }

    /// Deletes a log no live process is appending to, or one a process died opening, returning how many events it
    /// held. Anything else is left alone.
    private static func discardIfAbandonedLog(_ file: URL) -> Int {
        let name = file.lastPathComponent
        if name.hasPrefix(DiskEventLog.openingPrefix) {
            // Opening a log takes moments, so one this old was never finished, and holds no events.
            delete(file)
            return 0
        }
        guard name.hasPrefix(DiskEventLog.prefix), !DiskEventLog.isHeldByLiveProcess(file)
        else { return 0 }
        let held = eventsReading(file)
        return delete(file) ? held : 0
    }

    private static func eventsReading(_ file: URL) -> Int {
        (try? Data(contentsOf: file)).flatMap { EventLogFormat.eventCount(in: $0) } ?? 0
    }

    @discardableResult
    private static func delete(_ file: URL) -> Bool {
        try? FileManager.default.removeItem(at: file)
        return !FileManager.default.fileExists(atPath: file.path)
    }
}

/// What tells expiry which batches have a request out, so that it never deletes a batch someone is still sending: were
/// that request to fail, there would be no file left to retry from.
///
/// On a Mac, where processes of one application can share an environment, a sender holds a shared lock on the batch
/// for as long as its request is out, and expiry deletes a batch only while holding an exclusive lock on it, which it
/// cannot have while anyone holds the shared one. The kernel drops a lock when its process dies, so a batch whose
/// sender is gone is expired like any other. Elsewhere a process has its directory to itself, as it does its logs.
///
/// The batches sent in this process are also remembered, and expiry here asks that rather than opening the file. The
/// lock is taken once the batch has been read for sending; a batch another process expires in the moment between is
/// still sent from what was read, but has no file for a retry.
enum BatchLocks {
    /// A batch this process is sending, the descriptor its lock is held through, and how many send it.
    private final class Held {
        var file: EventLogFile?
        var senders = 0
    }

    /// The batches this process has a request out for, by `key(_:)`. Guarded by `lock`, which covers the probes and
    /// deletions below as well, so that a store in this process cannot start sending a batch another is expiring.
    private static var heldInThisProcess: [String: Held] = [:]
    private static let lock = UnfairLock()

    /// One name for a batch however its URL was come by, from a listing or put together from the directory: only the
    /// directory is resolved, since the batch itself may be gone by the time its send stops.
    private static func key(_ batch: URL) -> String {
        batch.deletingLastPathComponent().resolvingSymlinksInPath().appendingPathComponent(batch.lastPathComponent).path
    }

    /// Locks a batch for as long as a request for it is out. Each call is ended by one `stoppedSending(_:)`; a batch
    /// two deliveries send at once stays locked until both have stopped.
    static func startedSending(_ batch: URL) {
        let path = key(batch)
        lock.withLock {
            let held = heldInThisProcess[path] ?? Held()
            heldInThisProcess[path] = held
            held.senders += 1
            #if os(macOS) || targetEnvironment(macCatalyst)
            // Only fails to open where the batch is gone already, leaving nothing for expiry to take. Still remembered
            // where it cannot be locked, which keeps expiry in this process away from it; only other processes cannot
            // tell.
            guard held.file == nil, let opened = EventLogFile.open(at: batch, flags: O_RDONLY)
            else { return }
            if opened.tryLock(shared: true) {
                held.file = opened
            } else {
                opened.close()
            }
            #endif
        }
    }

    /// Ends one `startedSending(_:)`, releasing the lock once the last sender has stopped.
    static func stoppedSending(_ batch: URL) {
        let path = key(batch)
        lock.withLock {
            guard let held = heldInThisProcess[path]
            else { return }
            held.senders -= 1
            guard held.senders <= 0
            else { return }
            heldInThisProcess[path] = nil
            // Releases the lock with it.
            held.file?.close()
        }
    }

    /// Whether a store in this process is sending a batch, answered without opening the file.
    static func isSentInThisProcess(_ batch: URL) -> Bool {
        let path = key(batch)
        return lock.withLock { heldInThisProcess[path] != nil }
    }

    /// Deletes a batch for expiry, unless some live process is sending it.
    ///
    /// - Returns: whether this call deleted it; false for one being sent, one that could not be looked at, and one
    ///   already gone, whose events are someone else's to count.
    static func deleteUnlessBeingSent(_ batch: URL) -> Bool {
        let path = key(batch)
        return lock.withLock {
            guard heldInThisProcess[path] == nil
            else { return false }
            #if os(macOS) || targetEnvironment(macCatalyst)
            // Opened without being created: a batch delivered since it was listed has to stay gone, since a delivery
            // reading one brought back empty would report its events lost.
            guard let probe = EventLogFile.open(at: batch, flags: O_RDONLY)
            else { return false }
            defer { probe.close() }
            guard probe.tryLock(shared: false)
            else { return false }
            #endif
            // Deleted while still locked, so no sender can take its lock between the look and the delete.
            return (try? FileManager.default.removeItem(at: batch)) != nil
        }
    }
}

extension EventDirectory {
    /// The directory the store for a mobile key belongs in.
    ///
    /// tvOS is the reason this is not simply Application Support: a tvOS application is only allowed to persist to
    /// purgeable caches, so there the events are kept somewhere the system may reclaim, which is the most durability
    /// the platform offers. A directory that turns out not to be writable is no different from a full device: the store
    /// gives up on the disk and holds events in memory.
    static func defaultUrl(mobileKey: String) -> URL {
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

extension EventDirectory: TypeIdentifying { }
