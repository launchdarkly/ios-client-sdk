import Foundation
import OSLog

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
    /// events are in it, `ready-<payloadId>-<count>`.
    ///
    /// The count is in the name so that listing a batch this process did not close costs a directory entry rather than
    /// a read of the whole file. That is what every batch is at startup: the ones a previous run left behind, and the
    /// ones belonging to another process sharing the environment. Reading them all is done holding `ioLock`, which a
    /// commit at a commit point then waits behind.
    ///
    /// A batch is never appended to once it is closed, so the count is as good as the file is.
    private static let batchPrefix = "ready-"

    private let locateDirectory: () -> URL
    private let processName: String
    private let ioLock: UnfairLock
    private let logger: OSLog
    /// How a stored log is read, injectable so a test can make a read fail while the file is intact.
    private let readFile: (URL) throws -> Data
    /// How bytes reach the open log, injectable so a test can make a write fail partway through a session.
    private let writeLog: (EventLogFile, Data) -> Int32?

    /// Only to be used while holding `ioLock`.
    private var located: (directory: URL, log: DiskEventLog)?
    /// Whether a log left by a previous run has been dealt with. Only to be used while holding `ioLock`.
    private var hasRecoveredInterruptedLog = false

    /// A batch in the directory: the file it is, and how many events it holds.
    private struct Stored {
        let url: URL
        let events: Int
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
         processName: String,
         ioLock: UnfairLock,
         logger: OSLog,
         readFile: @escaping (URL) throws -> Data,
         writeLog: @escaping (EventLogFile, Data) -> Int32?) {
        self.locateDirectory = locatingDirectory
        self.processName = processName
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
                               processName: processName,
                               ioLock: ioLock,
                               logger: logger,
                               writeLog: writeLog)
        #if os(macOS) || targetEnvironment(macCatalyst)
        log.isLocked = locksOpenLog
        #endif
        let disk = (directory: directory, log: log)
        located = disk
        return disk
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
        disk.directory.appendingPathComponent("\(EventDirectory.batchPrefix)\(payloadId)-\(events)")
    }

    /// A batch as its filename gives it: everything between the prefix and the count is the payload ID.
    ///
    /// - Returns: the payload ID, and the count the name ends with, which is nil where it has none -- how a version
    ///   that did not write one named its batches. A payload ID cannot be mistaken for a count: it is a UUID, whose
    ///   last group is twelve characters. Twelve digits are more than an `Int32` holds unless they start with a zero,
    ///   which a count never does.
    private static func parse(batchName name: String) -> (payloadId: String, events: Int?) {
        let rest = String(name.dropFirst(batchPrefix.count))
        guard let split = rest.lastIndex(of: "-")
        else { return (rest, nil) }
        let suffix = rest[rest.index(after: split)...]
        guard !suffix.isEmpty, suffix.allSatisfy({ $0.isASCII && $0.isNumber }),
              suffix == "0" || suffix.first != "0",
              let events = Int32(suffix)
        else { return (rest, nil) }
        return (String(rest[..<split]), Int(events))
    }

    // MARK: Writing

    /// Appends to the open log, first closing off one a previous run left behind.
    ///
    /// Requires `ioLock`.
    ///
    /// - Returns: how many events that recovery found, and whether every byte landed. False means none of `bytes` is
    ///   in the log, and that the caller should give up on the disk.
    func append(_ bytes: Data) -> (recovered: Int, written: Bool) {
        ioLock.assertOwned()
        // Recovered before the log is opened, because it may still be the one a previous run died writing. Appended
        // to, this run's events would sit behind that run's torn last frame, where a reader can no longer find where
        // they start.
        let recovered = disk.log.isOpen ? 0 : recoverInterruptedLog()
        return (recovered, disk.log.append(bytes))
    }

    /// What closing the open log produced.
    enum LogClose {
        case closed(EventBatch)
        /// The log is still there to try again with, unless `logSurvives` is false -- a purged cache directory on
        /// tvOS, say. Then its events are gone, and they have to stop counting against capacity or the store would
        /// refuse events for the rest of the session.
        case failed(logSurvives: Bool)
    }

    /// Closes the open log into a batch, so the next append starts a new one. Requires `ioLock`.
    ///
    /// - Parameter events: how many events the log holds, which the caller has counted as it staged them.
    func closeLog(holding events: Int) -> LogClose {
        ioLock.assertOwned()
        let payloadId = UUID().uuidString
        let file = newUrl(of: payloadId, holding: events)
        do {
            try disk.log.close(movingTo: file)
        } catch {
            os_log("%s could not close the event log: %s", log: logger, type: .debug, typeName(and: #function), String(describing: error))
            return .failed(logSurvives: disk.log.exists)
        }

        stored[payloadId] = Stored(url: file, events: events)
        return .closed(EventBatch(payloadId: payloadId, eventCount: events))
    }

    /// Closes the descriptor, leaving everything where it is. Requires `ioLock`.
    func closeOpenLog() {
        ioLock.assertOwned()
        // Not `disk`: a store that never wrote has never worked out where it lives, and shutting down or giving up on
        // the disk is no reason to start.
        located?.log.closeDescriptor()
    }

    // MARK: Listing and reading

    /// The batches in the directory, oldest first. Requires `ioLock`.
    func listBatches() -> [EventBatch] {
        ioLock.assertOwned()
        let contents = (try? FileManager.default.contentsOfDirectory(at: disk.directory,
                                                                     includingPropertiesForKeys: [.contentModificationDateKey],
                                                                     options: [.skipsHiddenFiles])) ?? []

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
                stored[payloadId] = Stored(url: file, events: events)
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                return (EventBatch(payloadId: payloadId, eventCount: events), modified ?? Date.distantPast)
            }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }

        // A batch that left the directory without going through `remove` -- a purged cache directory on tvOS, say --
        // would otherwise keep its count for the rest of the session.
        let listed = Set(batches.map { $0.payloadId })
        stored = stored.filter { listed.contains($0.key) }

        return batches
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

    /// The `[...]` request body for a batch, or nil if it is gone or holds no events.
    ///
    /// Requires `ioLock`.
    ///
    /// - throws: `UnreadableBatch` if the batch is there but holds nothing this version can send; anything else if it
    ///   could not be read this time, which a later attempt may manage.
    func body(of batch: EventBatch) throws -> Data? {
        ioLock.assertOwned()
        switch read(url(of: batch.payloadId, holding: batch.eventCount)) {
        case .missing: return nil
        case .failed(let error): throw error
        case .bytes(let file):
            if let body = EventLogFormat.assembleBody(from: file) {
                return body
            }
            // A log this version reads that holds no events has nothing to lose.
            guard EventLogFormat.eventCount(in: file) == 0
            else { throw UnreadableBatch(payloadId: batch.payloadId) }
            return nil
        }
    }

    /// Forgets a batch. Requires `ioLock`.
    ///
    /// - Returns: the events it stopped counting, which is zero for a batch that was already gone -- one another
    ///   process delivered, say, which a listing has stopped counting already.
    func remove(_ payloadId: String, holding events: Int) -> Int {
        ioLock.assertOwned()
        let file = url(of: payloadId, holding: events)
        try? FileManager.default.removeItem(at: file)
        if FileManager.default.fileExists(atPath: file.path) {
            // Its events stop counting all the same: LaunchDarkly has them, and holding capacity for a file this
            // process may never be allowed to delete would cost the session events it could still have recorded.
            os_log("%s could not delete a delivered batch; it will not be sent again this session", log: logger, type: .debug, typeName(and: #function))
            deliveredButUndeleted.insert(payloadId)
        }
        return stored.removeValue(forKey: payloadId)?.events ?? 0
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

    // MARK: Recovery

    /// Closes off any log left open by a previous run of this process, so its events join the batches to deliver.
    ///
    /// The events in it were recorded by a process that is gone, so there is no one left to add to it. Only this
    /// process's own log is touched: another process's may still be open in a process that is alive. Where logs are
    /// locked, any log no live process holds is recovered, whatever it is named.
    ///
    /// Requires `ioLock`. Does its work once: after that, the open log is one this run opened.
    ///
    /// - Returns: how many events it closed off, which is zero on every call after the first.
    func recoverInterruptedLog() -> Int {
        ioLock.assertOwned()
        guard !hasRecoveredInterruptedLog
        else { return 0 }
        hasRecoveredInterruptedLog = true

        var recovered = 0
        disk.log.forEachLogLeftOpen { recovered += events(recoveredFrom: $0) }
        return recovered
    }

    /// Closes off a log nobody is writing to any more. Requires `ioLock`.
    ///
    /// - Returns: how many events it closed off, or zero where there was nothing to close off.
    private func events(recoveredFrom leftOpen: URL) -> Int {
        ioLock.assertOwned()
        let events: Int
        switch read(leftOpen) {
        case .missing:
            return 0
        case .failed(let error):
            // It cannot stay under this name, which this run is about to append its own events to, and deleting it
            // would lose events that may be intact. Closed off uncounted instead, it is read and counted by whichever
            // listing first manages to.
            os_log("%s could not read events from a previous run, will try again later: %s", log: logger, type: .debug, typeName(and: #function), String(describing: error))
            // Named without a count, which is what a batch whose events have never been counted is: the listing that
            // first manages to read it is what counts it.
            let uncounted = disk.directory.appendingPathComponent("\(EventDirectory.batchPrefix)\(UUID().uuidString)")
            try? FileManager.default.moveItem(at: leftOpen, to: uncounted)
            return 0
        case .bytes(let log):
            guard let counted = EventLogFormat.eventCount(in: log)
            else {
                // Unreadable, and a log that cannot be read cannot be appended to either.
                try? FileManager.default.removeItem(at: leftOpen)
                return 0
            }
            events = counted
        }

        guard events > 0
        else {
            try? FileManager.default.removeItem(at: leftOpen)
            return 0
        }

        let payloadId = UUID().uuidString
        let file = newUrl(of: payloadId, holding: events)
        guard (try? FileManager.default.moveItem(at: leftOpen, to: file)) != nil
        else { return 0 }

        stored[payloadId] = Stored(url: file, events: events)
        os_log("%s recovered %d event(s) from a previous run", log: logger, type: .debug, typeName(and: #function), events)
        return events
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
