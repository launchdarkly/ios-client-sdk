import Foundation

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
