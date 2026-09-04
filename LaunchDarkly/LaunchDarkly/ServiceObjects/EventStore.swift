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
    /// Encoded events that have been recorded but not yet accepted by LaunchDarkly, whether they are still staged in
    /// memory, written to the open log, or sitting in a closed batch.
    var pendingEventCount: Int { get }

    /// Stages an already encoded event, returning false if it was dropped because `capacity` is reached.
    ///
    /// Staging is a copy into a buffer; `commit()` is what makes the event outlive the process.
    func stage(_ encodedEvent: Data, bypassingCapacity: Bool) -> Bool

    /// Hands every staged byte to the kernel, so that the events recorded so far survive the process dying.
    func commit()

    /// Commits, then closes the open log into a batch to deliver. Returns nil when there is nothing to send.
    func closeBatch() -> EventBatch?

    /// Batches awaiting delivery, oldest first, including any recovered from a previous run of the application.
    func pendingBatches() -> [EventBatch]

    /// The `[...]` request body for a batch, or nil if the file has since become unreadable.
    func body(of batch: EventBatch) -> Data?

    /// Forgets a batch, which is only correct once LaunchDarkly has accepted it or permanently refused it.
    func remove(_ batch: EventBatch)

    /// Closes any log left open by a previous run of the application, so its events join the batches to deliver.
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
/// events: a durable barrier is a point where staged bytes are committed, and the events an application cares most
/// about are recorded at one.
final class EventStore: EventStoring {
    /// Names a log that has been closed off for delivery; the rest of the name is the batch's payload ID.
    private static let batchPrefix = "ready-"
    /// How many staged bytes are allowed to accumulate before one of them pays for a write.
    ///
    /// This is what keeps a syscall off most recordings while bounding what a crash can take with it, for an
    /// application that only evaluates flags and so never reaches a durable barrier of its own.
    private static let stagingThreshold = 16 * 1024

    let directory: URL
    private let capacity: Int
    private let logger: OSLog
    /// Where a commit runs when it was not asked for by a caller who needs it to have happened.
    ///
    /// Evaluating a flag must not put a write on whichever thread evaluated it, and that thread is usually the main one.
    /// A caller at a durable barrier still commits synchronously, because for them having returned is the guarantee.
    private let commitQueue: DispatchQueue

    /// Guards the staging buffer and the counters. It is held for a copy and never across a syscall, so an evaluation
    /// recording an event waits on another thread's memcpy at worst, never on the disk.
    private let stateLock = UnfairLock()
    /// Serializes commits so that two threads committing at once cannot interleave a frame or write frames out of
    /// order. Taken before `stateLock`, never after it.
    private let ioLock = UnfairLock()

    /// Only to be used while holding `stateLock`.
    private var staged = Data()
    private var stagedEvents = 0
    private var committedEvents = 0
    private var closedEvents = 0
    private var isDisabled = false
    /// Whether a commit is already on its way, so that a burst of recordings queues one write rather than one each.
    private var isCommitScheduled = false

    /// Only to be used while holding `ioLock`.
    private var descriptor: Int32 = -1

    private var currentLogUrl: URL { directory.appendingPathComponent("current") }

    /// A batch is identified by its payload ID rather than by a path, so that a batch listed from the directory and the
    /// same batch as it was closed are one thing.
    private func url(of payloadId: String) -> URL {
        directory.appendingPathComponent("\(EventStore.batchPrefix)\(payloadId)")
    }

    init(directory: URL,
         capacity: Int,
         logger: OSLog,
         commitQueue: DispatchQueue = DispatchQueue(label: "com.launchdarkly.EventStore.commitQueue", qos: .userInitiated)) {
        self.directory = directory
        self.capacity = capacity
        self.logger = logger
        self.commitQueue = commitQueue
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
        stateLock.lock()
        defer { stateLock.unlock() }
        return stagedEvents + committedEvents + closedEvents
    }

    func stage(_ encodedEvent: Data, bypassingCapacity: Bool = false) -> Bool {
        guard encodedEvent.count <= EventLogFormat.maxFrameSize
        else {
            os_log("%s dropping an event larger than a log frame allows", log: logger, type: .debug, typeName(and: #function))
            return false
        }

        stateLock.lock()

        guard !isDisabled
        else {
            stateLock.unlock()
            return false
        }
        guard bypassingCapacity || stagedEvents + committedEvents + closedEvents < capacity
        else {
            stateLock.unlock()
            return false
        }

        staged.append(EventLogFormat.frame(for: encodedEvent))
        stagedEvents += 1
        let needsCommit = staged.count >= EventStore.stagingThreshold && !isCommitScheduled
        if needsCommit {
            isCommitScheduled = true
        }
        stateLock.unlock()

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
        // for another one instead of finding a commit apparently already on its way and waiting for a barrier.
        stateLock.lock()
        isCommitScheduled = false
        stateLock.unlock()

        commit()
    }

    func commit() {
        ioLock.lock()
        defer { ioLock.unlock() }
        commitHoldingIoLock()
    }

    func closeBatch() -> EventBatch? {
        ioLock.lock()
        defer { ioLock.unlock() }

        commitHoldingIoLock()

        stateLock.lock()
        let events = committedEvents
        stateLock.unlock()

        guard events > 0
        else { return nil }

        closeDescriptor()

        let payloadId = UUID().uuidString
        do {
            try FileManager.default.moveItem(at: currentLogUrl, to: url(of: payloadId))
        } catch {
            os_log("%s could not close the event log: %s", log: logger, type: .debug, typeName(and: #function), String(describing: error))
            // The log is still there to try again with, unless it is the log that went missing -- a purged cache
            // directory on tvOS, say. Then its events are gone, and they have to stop counting against capacity or the
            // store would refuse events for the rest of the session.
            if !FileManager.default.fileExists(atPath: currentLogUrl.path) {
                stateLock.lock()
                committedEvents = 0
                stateLock.unlock()
            }
            return nil
        }

        stateLock.lock()
        committedEvents = 0
        closedEvents += events
        stateLock.unlock()

        return EventBatch(payloadId: payloadId, eventCount: events)
    }

    // MARK: Delivery

    func pendingBatches() -> [EventBatch] {
        ioLock.lock()
        defer { ioLock.unlock() }

        let contents = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                    includingPropertiesForKeys: [.contentModificationDateKey],
                                                                    options: [.skipsHiddenFiles])) ?? []

        let batches = contents
            .filter { $0.lastPathComponent.hasPrefix(EventStore.batchPrefix) }
            .compactMap { file -> (EventBatch, Date)? in
                guard let events = EventLogFormat.eventCount(in: file)
                else {
                    // Written by a version of the SDK whose format this one does not read, or damaged beyond what the
                    // torn tail recovery tolerates. Either way it can never be delivered, so it is not kept.
                    try? FileManager.default.removeItem(at: file)
                    return nil
                }
                let payloadId = String(file.lastPathComponent.dropFirst(EventStore.batchPrefix.count))
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                return (EventBatch(payloadId: payloadId, eventCount: events), modified ?? Date.distantPast)
            }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }

        stateLock.lock()
        closedEvents = batches.reduce(0) { $0 + $1.eventCount }
        stateLock.unlock()

        return batches
    }

    func body(of batch: EventBatch) -> Data? {
        ioLock.lock()
        defer { ioLock.unlock() }

        guard let file = try? Data(contentsOf: url(of: batch.payloadId))
        else { return nil }
        return EventLogFormat.assembleBody(from: file)
    }

    func remove(_ batch: EventBatch) {
        ioLock.lock()
        defer { ioLock.unlock() }

        try? FileManager.default.removeItem(at: url(of: batch.payloadId))

        stateLock.lock()
        closedEvents = max(0, closedEvents - batch.eventCount)
        stateLock.unlock()
    }

    /// Closes any log left open by a previous run of the application, so its events join the batches to deliver.
    ///
    /// The events in it were recorded by a process that is gone, so there is no one left to add to it.
    func recoverInterruptedLog() {
        ioLock.lock()
        defer { ioLock.unlock() }

        guard FileManager.default.fileExists(atPath: currentLogUrl.path),
              let events = EventLogFormat.eventCount(in: currentLogUrl)
        else {
            // Nothing recoverable. An unreadable log cannot be appended to either, so it goes.
            if FileManager.default.fileExists(atPath: currentLogUrl.path) {
                try? FileManager.default.removeItem(at: currentLogUrl)
            }
            return
        }

        guard events > 0
        else {
            try? FileManager.default.removeItem(at: currentLogUrl)
            return
        }

        let payloadId = UUID().uuidString
        guard (try? FileManager.default.moveItem(at: currentLogUrl, to: url(of: payloadId))) != nil
        else { return }

        os_log("%s recovered %d event(s) from a previous run", log: logger, type: .debug, typeName(and: #function), events)
    }

    // MARK: Writing

    /// Requires `ioLock`.
    private func commitHoldingIoLock() {
        stateLock.lock()
        let bytes = staged
        let events = stagedEvents
        let disabled = isDisabled
        staged = Data()
        stagedEvents = 0
        stateLock.unlock()

        guard !disabled, !bytes.isEmpty
        else { return }

        if append(bytes) {
            stateLock.lock()
            committedEvents += events
            stateLock.unlock()
        }
    }

    /// Requires `ioLock`.
    private func append(_ bytes: Data) -> Bool {
        guard let descriptor = descriptorForAppending()
        else { return false }
        return append(bytes, to: descriptor)
    }

    /// Requires `ioLock`.
    private func append(_ bytes: Data, to descriptor: Int32) -> Bool {
        var offset = 0
        let failure: Int32? = bytes.withUnsafeBytes { raw -> Int32? in
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

        if let failure = failure {
            // Never trap on a full disk. The SDK gives up on persistence for the rest of the session rather than
            // taking the application down with it, which is how other SDKs have crashed their hosts.
            os_log("%s giving up on persisting events: errno %d", log: logger, type: .debug, typeName(and: #function), failure)
            closeDescriptor()
            stateLock.lock()
            isDisabled = true
            staged = Data()
            stagedEvents = 0
            stateLock.unlock()
            return false
        }

        return true
    }

    /// Requires `ioLock`.
    private func descriptorForAppending() -> Int32? {
        if descriptor >= 0 {
            return descriptor
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            os_log("%s could not create the event directory: %s", log: logger, type: .debug, typeName(and: #function), String(describing: error))
            return nil
        }
        excludeFromBackup()

        // O_APPEND is what makes each write land at the end of the file as one step, so that clients for several
        // environments writing their own logs, or a commit racing a reader, cannot produce a spliced frame.
        let opened = currentLogUrl.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path = path
            else { return -1 }
            return openFile(path, O_WRONLY | O_APPEND | O_CREAT, 0o600)
        }

        guard opened >= 0
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

    /// Requires `ioLock`.
    private func closeDescriptor() {
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
        commitHoldingIoLock()
        closeDescriptor()
        ioLock.unlock()
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
private enum EventLogFormat {
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

    static func eventCount(in url: URL) -> Int? {
        guard let file = try? Data(contentsOf: url)
        else { return nil }

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

        let contents = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                    includingPropertiesForKeys: nil,
                                                                    options: [.skipsHiddenFiles])) ?? []
        var logs = contents.filter { $0.lastPathComponent.hasPrefix(EventStore.batchPrefix) }.sorted { $0.path < $1.path }
        if FileManager.default.fileExists(atPath: currentLogUrl.path) {
            logs.append(currentLogUrl)
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
#endif
