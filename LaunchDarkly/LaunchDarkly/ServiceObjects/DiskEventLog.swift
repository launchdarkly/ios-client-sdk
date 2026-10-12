import Foundation
import OSLog

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// The file of events on disk this process appends to, not to be confused with diagnostic logging.
///
/// One per process rather than one per directory, so that only one process ever writes a given log and recovery only
/// ever touches its own. With one shared log, a second process starting up would close off, as if a previous run had
/// left it, a log the first is still appending to through its open descriptor, and the first's later events would land
/// in a batch already sent or deleted. Another process's log is left for that process to recover the next time it runs.
///
/// Belongs to an `EventStore`, which makes every call holding its `ioLock`. The lock is handed in so that each call can
/// check it is held, rather than this taking a lock of its own that would have to be ordered against the store's.
final class DiskEventLog {
    /// Names a log a single process appends to; the rest of the name is that process.
    static let prefix = "open-"

    private let directory: URL
    private let ioLock: UnfairLock
    private let logger: OSLog
    /// How bytes reach the log, injectable so a test can make a write fail partway through a session, as a full disk
    /// does. Answers with the errno it stopped on, or nil where every byte landed.
    private let writeLog: (EventLogFile, Data) -> Int32?

    /// Named for the process, unless on a Mac `isLocked` found another live instance holding that name, in which case
    /// it is named for this instance's process ID as well.
    private(set) var url: URL
    /// Nil until the first append opens it, and again once it is closed.
    private var file: EventLogFile?

    #if os(macOS) || targetEnvironment(macCatalyst)
    /// The readable, collision-proof form of the process name every log this process opens is named after.
    private let processLogName: String
    /// Whether the log is locked while it is open, so that another live process can tell it is taken. Only to be
    /// changed before the log is first opened or recovered.
    ///
    /// Only on a Mac, which runs a second instance of an application under the same process name on request, so that
    /// a name alone cannot keep two live processes apart. Elsewhere a name is one live process, and a lock is not
    /// compiled in at all: iOS kills a suspended application that holds a lock on a file in a shared container.
    var isLocked = true
    #endif

    init(directory: URL, processName: String, ioLock: UnfairLock, logger: OSLog, writeLog: @escaping (EventLogFile, Data) -> Int32?) {
        self.directory = directory
        self.ioLock = ioLock
        self.logger = logger
        self.writeLog = writeLog
        let processLogName = DiskEventLog.name(for: processName)
        self.url = directory.appendingPathComponent(DiskEventLog.prefix + processLogName)
        #if os(macOS) || targetEnvironment(macCatalyst)
        self.processLogName = processLogName
        #endif
    }

    /// Names the log belonging to one process.
    ///
    /// The readable part is the process name with anything awkward in a filename replaced, which keeps a directory of
    /// these diagnosable. That reduction is not one-to-one, and two processes sharing a log is the one thing this name
    /// exists to prevent, so a digest of the original name is appended.
    static func name(for processName: String) -> String {
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
            // to deliver from there, so frames left here as well would be sent twice: beside the memory copy when the
            // log is closed this session, or by recovery on the next launch.
            if let start, !file.truncate(to: start) {
                os_log("%s could not cut back a failed write: errno %d", log: logger, type: .debug, typeName(and: #function), errno)
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
        // Closed after the rename rather than before it, so that a locked log is still locked while it moves. Another
        // instance recovering unlocked logs could otherwise take it in between.
        defer { closeDescriptor() }
        try FileManager.default.moveItem(at: url, to: destination)
    }

    /// Closes the descriptor, leaving the log where it is. Requires `ioLock`.
    func closeDescriptor() {
        ioLock.assertOwned()
        file?.close()
        file = nil
    }

    /// Hands `recover` each log left open by a process that is gone, which it has to move or remove.
    ///
    /// Only this process's own log, by name: another process's may still be open in a process that is alive. Where
    /// logs are locked, any log no live process holds, whatever it is named.
    ///
    /// Requires `ioLock`.
    func forEachLogLeftOpen(_ recover: (URL) -> Void) {
        ioLock.assertOwned()
        #if os(macOS) || targetEnvironment(macCatalyst)
        if isLocked {
            forEachUnheldLog(recover)
            return
        }
        #endif
        recover(url)
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

        guard let opened = open()
        else {
            os_log("%s could not open the event log: errno %d", log: logger, type: .debug, typeName(and: #function), errno)
            return nil
        }

        file = opened

        if opened.isEmpty {
            guard write(EventLogFormat.fileHeader, to: opened)
            else { return nil }
        }

        return opened
    }

    private func write(_ bytes: Data, to file: EventLogFile) -> Bool {
        guard let failure = writeLog(file, bytes)
        else { return true }
        os_log("%s could not write to the event log: errno %d", log: logger, type: .debug, typeName(and: #function), failure)
        return false
    }

    /// Opens the log, locked where logs are. Requires `ioLock`.
    private func open() -> EventLogFile? {
        ioLock.assertOwned()
        // O_APPEND is what makes each write land at the end of the file as one step, so that clients for several
        // environments writing their own logs, or a commit racing a reader, cannot produce a spliced frame.
        let flags = O_WRONLY | O_APPEND | O_CREAT
        #if os(macOS) || targetEnvironment(macCatalyst)
        if isLocked {
            return openLocked(flags: flags)
        }
        #endif
        return EventLogFile.open(at: url, flags: flags)
    }

    #if os(macOS) || targetEnvironment(macCatalyst)
    /// Opens the log for this process name locked, or one of this instance's own where another live instance holds
    /// it. Requires `ioLock`.
    private func openLocked(flags: Int32) -> EventLogFile? {
        ioLock.assertOwned()
        if let opened = EventLogFile.openLocked(url, flags: flags) {
            return opened
        }

        // Another live instance of the application holds the log for this process name, so this one takes a log of its
        // own. The process ID keeps it apart from every other live process, and the suffix from another store in this
        // one, as a closed client's can be while it is still going away. Recovery finds the log by its lock rather than
        // its name, so it is not orphaned when this instance ends.
        let ownLog = directory.appendingPathComponent(
            "\(DiskEventLog.prefix)\(processLogName)-\(getpid())-\(UUID().uuidString.prefix(8))")
        guard let opened = EventLogFile.openLocked(ownLog, flags: flags)
        else { return nil }
        url = ownLog
        return opened
    }

    /// Hands `recover` every open log no live process holds. Requires `ioLock`.
    ///
    /// A log that can be locked is one no live process has open, so whoever wrote it is gone. That includes a log a
    /// second instance opened under its process ID, which no later run would otherwise come back for by name.
    private func forEachUnheldLog(_ recover: (URL) -> Void) {
        ioLock.assertOwned()
        let contents = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                    includingPropertiesForKeys: nil,
                                                                    options: [.skipsHiddenFiles])) ?? []
        for log in contents where log.lastPathComponent.hasPrefix(DiskEventLog.prefix) {
            guard let held = EventLogFile.openLocked(log, flags: O_RDONLY)
            else { continue }
            recover(log)
            held.close()
        }
    }
    #endif
}

extension DiskEventLog: TypeIdentifying { }
