import Foundation
import OSLog

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// The file of events on disk a store appends to, not to be confused with diagnostic logging.
///
/// One per store rather than one per directory, so that only one writer ever appends to a given log. Each is named for a
/// UUID picked when it is opened, which is what keeps two writers apart: nothing about it comes from the application, and
/// no two processes, or two stores in one, ever pick the same one.
///
/// A log nobody is appending to belongs to no one alive, whoever wrote it, and recovery takes it. The logs open in this
/// process are remembered, which is all it takes where only this process uses the directory. On a Mac, which runs a
/// second instance of an application over the same directory on request, the owner also holds its log locked for as
/// long as it is open, and the kernel releases the lock when the descriptor closes, including when the process dies.
/// Elsewhere a lock is not compiled in at all: iOS kills a suspended application that holds a lock on a file in a shared
/// container.
///
/// A log is given its header under a name recovery does not look for, and only then moved to one it does, so that a log
/// being opened is never taken for one whose owner is gone.
///
/// Belongs to an `EventStore`, which makes every call holding its `ioLock`. The lock is handed in so that each call can
/// check it is held, rather than this taking a lock of its own that would have to be ordered against the store's.
final class DiskEventLog {
    /// Names a log whose events are not yet in a batch: one its owner is appending to, or one left by an owner that is
    /// gone, for recovery to close off. The rest of the name is the UUID it was opened under.
    static let prefix = "pending-"
    /// Names a log while it is being opened, before it has its header. Recovery never looks at these; one left by a
    /// process that died opening it holds no events, and expiry removes it.
    static let openingPrefix = "new-"

    /// The paths of the logs open in this process, which recovery and expiry leave alone. Guarded by
    /// `openInThisProcessLock`.
    private static var openInThisProcess: Set<String> = []
    private static let openInThisProcessLock = UnfairLock()

    private let directory: URL
    private let ioLock: UnfairLock
    private let logger: OSLog
    /// How bytes reach the log, injectable so a test can make a write fail partway through a session, as a full disk
    /// does. Answers with the errno it stopped on, or nil where every byte landed.
    private let writeLog: (EventLogFile, Data) -> Int32?

    /// Where the log is, whether or not it exists yet.
    private(set) var url: URL
    /// Nil until the first append opens it, and again once it is closed.
    private var file: EventLogFile?

    #if os(macOS) || targetEnvironment(macCatalyst)
    /// Whether the log is locked while it is open, so that another live instance can tell it is taken. Only to be
    /// changed before the log is first opened.
    var isLocked = true
    #endif

    init(directory: URL,
         ioLock: UnfairLock,
         logger: OSLog,
         writeLog: @escaping (EventLogFile, Data) -> Int32?) {
        self.directory = directory
        self.ioLock = ioLock
        self.logger = logger
        self.writeLog = writeLog
        self.url = DiskEventLog.newUrl(in: directory)
    }

    private static func newUrl(in directory: URL) -> URL {
        directory.appendingPathComponent(prefix + UUID().uuidString)
    }

    /// Whether some live process is appending to a log, and recovery and expiry must leave it alone.
    ///
    /// A log open in this process is answered from memory. On a Mac any other is answered by its lock, and one that
    /// cannot be looked at counts as held: leaving a dead process's log for a later run costs nothing, while taking a
    /// live one's would lose what it appends next.
    static func isHeldByLiveProcess(_ log: URL) -> Bool {
        if isOpenInThisProcess(log) {
            return true
        }
        #if os(macOS) || targetEnvironment(macCatalyst)
        return EventLogFile.isLockedByLiveProcess(log)
        #else
        return false
        #endif
    }

    /// Requires `ioLock`.
    var isOpen: Bool {
        ioLock.assertOwned()
        return file != nil
    }

    /// Requires `ioLock`.
    var exists: Bool {
        ioLock.assertOwned()
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Appends to the log, opening it first where it is not open. False where it could not be opened or written to, in
    /// which case none of `bytes` is left in the log.
    ///
    /// Requires `ioLock`.
    func append(_ bytes: Data) -> Bool {
        ioLock.assertOwned()
        guard let file = fileForAppending()
        else { return false }

        let start = file.size
        guard write(bytes, to: file)
        else {
            // A write that fails partway can leave whole frames behind. The caller keeps every one of `bytes` in memory
            // to deliver from there, so frames left here as well would be sent twice. Where they cannot be cut back, the
            // batch this log is closed into still delivers only the events it was closed holding.
            if let start, !file.truncate(to: start) {
                os_log("%s could not cut back a failed write: errno %d", log: logger, type: .error, typeName(and: #function), errno)
            }
            return false
        }
        return true
    }

    /// Moves the log to `destination` and closes it, so that the next append starts a new one. The descriptor is closed
    /// whether or not the move succeeds.
    ///
    /// Requires `ioLock`.
    func close(movingTo destination: URL) throws {
        ioLock.assertOwned()
        // Closed after the move rather than before it, so that the log is still held while it moves. Another store
        // recovering logs could otherwise take it in between.
        defer { closeDescriptor() }
        try FileManager.default.moveItem(at: url, to: destination)
    }

    /// Closes the descriptor, leaving the log where it is. Requires `ioLock`.
    ///
    /// No longer held, it is from here on a log like one a process that died left behind, which recovery may take at
    /// any moment. So this log is never opened again: the next append starts a new one.
    func closeDescriptor() {
        ioLock.assertOwned()
        guard let file
        else { return }
        file.close()
        self.file = nil
        DiskEventLog.forget(url)
    }

    /// Hands `recover` every log no live process holds, which it has to move or remove: whoever wrote it is gone.
    ///
    /// Requires `ioLock`.
    func forEachUnheldLog(_ recover: (URL) -> Void) {
        ioLock.assertOwned()
        let contents = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                    includingPropertiesForKeys: nil,
                                                                    options: [.skipsHiddenFiles])) ?? []
        for log in contents where log.lastPathComponent.hasPrefix(DiskEventLog.prefix) {
            guard !DiskEventLog.isOpenInThisProcess(log)
            else { continue }
            #if os(macOS) || targetEnvironment(macCatalyst)
            // Locked for as long as it is recovered, so that another instance recovering at the same time leaves it be.
            guard let held = EventLogFile.openLocked(log, flags: O_RDONLY)
            else { continue }
            recover(log)
            held.close()
            #else
            recover(log)
            #endif
        }
    }

    /// Requires `ioLock`.
    private func fileForAppending() -> EventLogFile? {
        ioLock.assertOwned()
        if let file {
            return file
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            os_log("%s could not create the event directory: %s", log: logger, type: .debug, typeName(and: #function), String(describing: error))
            return nil
        }
        EventLogFile.excludeFromBackup(directory)

        if FileManager.default.fileExists(atPath: url.path) {
            // Left by an earlier open this session and closed since, so no longer this store's to write.
            url = DiskEventLog.newUrl(in: directory)
        }
        guard let opened = open()
        else { return nil }
        file = opened
        return opened
    }

    private func write(_ bytes: Data, to file: EventLogFile) -> Bool {
        guard let failure = writeLog(file, bytes)
        else { return true }
        os_log("%s could not write to the event log: errno %d", log: logger, type: .debug, typeName(and: #function), failure)
        return false
    }

    /// Opens a new log: created under `openingPrefix`, locked where logs are, given its header, and only then moved to
    /// the name recovery looks for. Requires `ioLock`.
    private func open() -> EventLogFile? {
        ioLock.assertOwned()
        let opening = directory.appendingPathComponent(
            DiskEventLog.openingPrefix + url.lastPathComponent.dropFirst(DiskEventLog.prefix.count))
        // O_APPEND is what makes each write land at the end of the file as one step, so that a commit racing a reader
        // cannot produce a spliced frame.
        let flags = O_WRONLY | O_APPEND | O_CREAT | O_EXCL
        DiskEventLog.remember(url)
        guard let opened = openFile(at: opening, flags: flags)
        else {
            os_log("%s could not open the event log: errno %d", log: logger, type: .debug, typeName(and: #function), errno)
            DiskEventLog.forget(url)
            return nil
        }

        guard write(EventLogFormat.fileHeader, to: opened)
        else { return abandon(opened, at: opening) }
        do {
            try FileManager.default.moveItem(at: opening, to: url)
        } catch {
            os_log("%s could not name the event log: %s", log: logger, type: .debug, typeName(and: #function), String(describing: error))
            return abandon(opened, at: opening)
        }
        return opened
    }

    /// Closes and removes a log that never got the name recovery looks for. Requires `ioLock`.
    private func abandon(_ opened: EventLogFile, at opening: URL) -> EventLogFile? {
        opened.close()
        try? FileManager.default.removeItem(at: opening)
        DiskEventLog.forget(url)
        return nil
    }

    /// Opens a file for a new log, locked where logs are. Requires `ioLock`.
    private func openFile(at url: URL, flags: Int32) -> EventLogFile? {
        #if os(macOS) || targetEnvironment(macCatalyst)
        if isLocked {
            return EventLogFile.openLocked(url, flags: flags)
        }
        #endif
        return EventLogFile.open(at: url, flags: flags)
    }

    private static func isOpenInThisProcess(_ log: URL) -> Bool {
        openInThisProcessLock.withLock { openInThisProcess.contains(log.standardizedFileURL.path) }
    }

    private static func remember(_ log: URL) {
        openInThisProcessLock.withLock { _ = openInThisProcess.insert(log.standardizedFileURL.path) }
    }

    private static func forget(_ log: URL) {
        openInThisProcessLock.withLock { _ = openInThisProcess.remove(log.standardizedFileURL.path) }
    }
}

extension DiskEventLog: TypeIdentifying { }
