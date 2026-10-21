import Foundation

/// The on-disk shape of an event log.
///
/// A log opens with a magic and a format version, and holds a sequence of frames:
///
///     +- 4 bytes -+- 2 bytes -+     +- 2 bytes -+- 4 bytes -+- 4 bytes -+- n bytes -+
///     |   LDEV    |  version  | ... |   type    |  size (n) |   CRC-32  |  payload  |
///     +-----------+-----------+     +-----------+-----------+-----------+-----------+
///
/// The size prefix is what makes a log recoverable: a reader can tell a frame the writer finished from one it did not,
/// without having to parse the event to find where it ends. The checksum, over the type, the size and the payload, is
/// what tells a frame the writer finished from one the storage has since damaged; a reader treats either the same way.
/// The version is what makes an upgrade safe -- a log this version does not understand is discarded rather than
/// misread -- and the frame type leaves room for a later version to write something new into a log this one still
/// reads.
enum EventLogFormat {
    /// Bump this whenever the framing or the meaning of a frame changes.
    static let version: UInt16 = 1
    static let magic = Data("LDEV".utf8)
    static let fileHeaderSize = 6
    static let frameHeaderSize = 10
    /// The only frame type written today; a reader skips a frame whose type it does not know.
    static let eventFrame: UInt16 = 1
    /// A ceiling on a single frame, so a corrupt size cannot make recovery allocate wildly.
    static let maxFrameSize = 8 * 1024 * 1024

    static var fileHeader: Data {
        var header = magic
        header.append(bigEndian(version))
        return header
    }

    static func frame(for encodedEvent: Data) -> Data {
        var frame = Data(capacity: frameHeaderSize + encodedEvent.count)
        withUnsafeBytes(of: eventFrame.bigEndian) { frame.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(encodedEvent.count).bigEndian) { frame.append(contentsOf: $0) }
        var checksum = Crc32()
        frame.withUnsafeBytes { checksum.advance(withBytes: $0) }
        encodedEvent.withUnsafeBytes { checksum.advance(withBytes: $0) }
        withUnsafeBytes(of: checksum.checksum.bigEndian) { frame.append(contentsOf: $0) }
        frame.append(encodedEvent)
        return frame
    }

    /// What walking a log's frames found.
    struct FrameWalk {
        /// False when the walk stopped at a frame that is torn or fails its checksum, rather than at the end of the
        /// file.
        let reachedEnd: Bool
    }

    /// Walks the frames of a log, stopping at the first one that is not wholly there or fails its checksum.
    ///
    /// A process that died partway through a write leaves a torn frame at the end. Everything before it is intact, so
    /// recovery keeps that and drops only the tail. A frame the storage damaged afterwards ends the walk the same way,
    /// because its size can no longer be trusted to say where the next frame starts. Returns nil when the file is not a
    /// log this version reads.
    @discardableResult
    static func forEachFrame(in file: Data, _ visit: (UInt16, Data) -> Void) -> FrameWalk? {
        guard file.count >= fileHeaderSize,
              file.prefix(magic.count) == magic,
              readUInt16(file, at: magic.count) == version
        else { return nil }

        return file.withUnsafeBytes { bytes in
            var cursor = fileHeaderSize
            while cursor + frameHeaderSize <= bytes.count {
                let type = UInt16(bytes[cursor]) << 8 | UInt16(bytes[cursor + 1])
                let length = Int(readUInt32(bytes, at: cursor + 2))
                let start = cursor + frameHeaderSize
                guard length > 0, length <= maxFrameSize, start + length <= bytes.count
                else { break }

                let payload = UnsafeRawBufferPointer(rebasing: bytes[start..<(start + length)])
                var checksum = Crc32()
                checksum.advance(withBytes: UnsafeRawBufferPointer(rebasing: bytes[cursor..<(cursor + 6)]))
                checksum.advance(withBytes: payload)
                guard checksum.checksum == readUInt32(bytes, at: cursor + 6)
                else { break }

                visit(type, Data(payload))
                cursor = start + length
            }
            return FrameWalk(reachedEnd: cursor == bytes.count)
        }
    }

    private static func readUInt32(_ bytes: UnsafeRawBufferPointer, at offset: Int) -> UInt32 {
        UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
    }

    /// How many events a log holds, or nil where it is not one this version reads.
    static func eventCount(in file: Data) -> Int? {
        var events = 0
        guard forEachFrame(in: file, { type, _ in
            if type == eventFrame {
                events += 1
            }
        }) != nil
        else { return nil }
        return events
    }

    /// Whether a log holds frames that cannot be read back: torn, or failing their checksum. False for a log this
    /// version does not read at all.
    static func isDamaged(_ file: Data) -> Bool {
        forEachFrame(in: file) { _, _ in }?.reachedEnd == false
    }

    /// Assembles the JSON array LaunchDarkly expects out of the frames, without parsing the events themselves: they were
    /// serialized on the way in and are shipped exactly as they were recorded.
    ///
    /// Only the first `maxEvents` events go into it; any after them are left out.
    static func assembleBody(from file: Data, maxEvents: Int = .max) -> Data? {
        var body = Data("[".utf8)
        var isFirst = true
        var events = 0
        let readable = forEachFrame(in: file) { type, payload in
            guard type == eventFrame, events < maxEvents
            else { return }
            events += 1
            if !isFirst {
                body.append(UInt8(ascii: ","))
            }
            body.append(payload)
            isFirst = false
        }

        guard readable != nil, !isFirst
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
