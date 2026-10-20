import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// An open file an event log is written through, on a descriptor rather than Foundation's file handles.
///
/// Foundation's FileHandle is deliberately not used: it raises an Objective-C exception when a write fails, which is not
/// something a Swift caller can catch, and has taken host applications down with it when a device ran out of space.
///
/// A value, so a copy names the same open file. Whoever opened it closes it once, and uses no copy after that.
struct EventLogFile {
    let descriptor: Int32

    /// Opens a file, creating it readable and writable by its owner alone. Nil where it could not, with `errno` saying
    /// why.
    static func open(at url: URL, flags: Int32) -> EventLogFile? {
        let opened = url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path = path
            else { return -1 }
            return openFile(path, flags, 0o600)
        }
        return opened >= 0 ? EventLogFile(descriptor: opened) : nil
    }

    #if os(macOS) || targetEnvironment(macCatalyst)
    /// Opens a file and takes its lock without waiting, or nil where another live process holds it.
    ///
    /// The lock has to be on the file that is still at `url`: one renamed or removed between the open and the lock,
    /// by another process closing off or recovering it, is no longer a log anyone appends to.
    static func openLocked(_ url: URL, flags: Int32) -> EventLogFile? {
        for _ in 0..<3 {
            guard let opened = open(at: url, flags: flags)
            else { return nil }
            guard lockFile(opened.descriptor)
            else {
                opened.close()
                return nil
            }
            if isFile(opened.descriptor, at: url) {
                return opened
            }
            opened.close()
        }
        return nil
    }

    /// Whether a live process holds the lock on a log, which is to say is still appending to it.
    static func isLockedByLiveProcess(_ url: URL) -> Bool {
        guard let opened = openLocked(url, flags: O_RDONLY)
        else { return FileManager.default.fileExists(atPath: url.path) }
        opened.close()
        return false
    }
    #endif

    /// Removes a directory only if it is empty, so that nothing put there since it was last looked at goes with it.
    @discardableResult
    static func removeDirectoryIfEmpty(_ url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path -> Bool in
            guard let path = path
            else { return false }
            return removeDirectory(path) == 0
        }
    }

    static func excludeFromBackup(_ directory: URL) {
        #if canImport(Darwin)
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        #endif
    }

    /// Writes every byte, returning the errno it stopped on or nil where they all landed.
    func writeAll(_ bytes: Data) -> Int32? {
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

    var isEmpty: Bool {
        lseek(descriptor, 0, SEEK_END) == 0
    }

    /// How long the file is, or nil where that could not be found.
    var size: off_t? {
        let end = lseek(descriptor, 0, SEEK_END)
        return end >= 0 ? end : nil
    }

    /// Cuts the file back to `length`. False where it could not, with `errno` saying why.
    func truncate(to length: off_t) -> Bool {
        truncateFile(descriptor, length) == 0
    }

    func close() {
        closeFile(descriptor)
    }
}

// The POSIX calls are wrapped so that the names cannot be shadowed by a member of the type using them, and so the
// platform differences stay in one place.
#if canImport(Darwin)
private func openFile(_ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 {
    Darwin.open(path, flags, mode)
}

private func writeBytes(_ descriptor: Int32, _ bytes: UnsafeRawPointer, _ count: Int) -> Int {
    Darwin.write(descriptor, bytes, count)
}

private func truncateFile(_ descriptor: Int32, _ length: off_t) -> Int32 {
    Darwin.ftruncate(descriptor, length)
}

private func closeFile(_ descriptor: Int32) {
    _ = Darwin.close(descriptor)
}

private func removeDirectory(_ path: UnsafePointer<CChar>) -> Int32 {
    Darwin.rmdir(path)
}
#else
private func openFile(_ path: UnsafePointer<CChar>, _ flags: Int32, _ mode: mode_t) -> Int32 {
    open(path, flags, mode)
}

private func writeBytes(_ descriptor: Int32, _ bytes: UnsafeRawPointer, _ count: Int) -> Int {
    write(descriptor, bytes, count)
}

private func truncateFile(_ descriptor: Int32, _ length: off_t) -> Int32 {
    ftruncate(descriptor, length)
}

private func closeFile(_ descriptor: Int32) {
    _ = close(descriptor)
}

private func removeDirectory(_ path: UnsafePointer<CChar>) -> Int32 {
    rmdir(path)
}
#endif

#if os(macOS) || targetEnvironment(macCatalyst)
/// Takes an exclusive lock without waiting. Released by the kernel when the descriptor closes, including when the
/// process dies, so a crashed process never leaves one behind.
private func lockFile(_ descriptor: Int32) -> Bool {
    flock(descriptor, LOCK_EX | LOCK_NB) == 0
}

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
#endif
