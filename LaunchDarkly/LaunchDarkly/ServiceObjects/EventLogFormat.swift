import Foundation

/// The on-disk shape of an event log.
///
/// A log opens with a magic and a format version, and holds a sequence of frames:
///
///     +- 4 bytes -+- 2 bytes -+     +- 2 bytes -+- 4 bytes -+- n bytes -+- 4 bytes -+
///     |   LDEV    |  version  | ... |   type    |  size (n) |  payload  |   CRC-32  |
///     +-----------+-----------+     +-----------+-----------+-----------+-----------+
///
/// The size prefix is what makes a log recoverable: a reader can tell a frame the writer finished from one it did not,
/// without having to parse the event to find where it ends. The checksum, over the type, the size and the payload --
/// everything before it in the frame -- is what tells a frame the writer finished from one the storage has since
/// damaged; a reader treats either the same way.
/// The version is what makes an upgrade safe -- a log this version does not understand is discarded rather than
/// misread -- and the frame type leaves room for a later version to write something new into a log this one still
/// reads.
enum EventLogFormat {
    /// Bump this whenever the framing or the meaning of a frame changes.
    static let version: UInt16 = 1
    static let magic = Data("LDEV".utf8)
    static let fileHeaderSize = 6
    /// The type and the size, before a frame's payload.
    static let frameHeaderSize = 6
    /// The checksum, after a frame's payload.
    static let frameTrailerSize = 4
    /// What a frame takes beyond its payload.
    static let frameOverhead = frameHeaderSize + frameTrailerSize
    /// The only frame type written today; a reader skips a frame whose type it does not know.
    static let eventFrame: UInt16 = 1
    /// The most a batch may hold, file header included, so that no request it becomes is larger than the events
    /// service accepts.
    static let maxBatchSize = 2 * 1024 * 1024
    /// A ceiling on a single frame's payload: the most that still fits in a batch on its own. It is also what keeps a
    /// corrupt size from making recovery allocate wildly.
    static let maxFrameSize = maxBatchSize - fileHeaderSize - frameOverhead

    static var fileHeader: Data {
        var header = magic
        header.append(bigEndian(version))
        return header
    }

    static func frame(for encodedEvent: Data) -> Data {
        var frame = Data(capacity: frameOverhead + encodedEvent.count)
        withUnsafeBytes(of: eventFrame.bigEndian) { frame.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(encodedEvent.count).bigEndian) { frame.append(contentsOf: $0) }
        frame.append(encodedEvent)
        var checksum = Crc32()
        frame.withUnsafeBytes { checksum.advance(withBytes: $0) }
        withUnsafeBytes(of: checksum.checksum.bigEndian) { frame.append(contentsOf: $0) }
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
        forEachFramePayload(in: file) { type, payload in
            visit(type, file.subdata(in: (file.startIndex + payload.lowerBound)..<(file.startIndex + payload.upperBound)))
        }
    }

    /// `forEachFrame(in:_:)` handing over where each payload is, as offsets into the file, rather than a copy of it.
    @discardableResult
    static func forEachFramePayload(in file: Data, _ visit: (UInt16, Range<Int>) -> Void) -> FrameWalk? {
        guard isReadable(file)
        else { return nil }
        return file.withUnsafeBytes { walkFrames($0, visit) }
    }

    private static func isReadable(_ file: Data) -> Bool {
        file.count >= fileHeaderSize && file.prefix(magic.count) == magic && readUInt16(file, at: magic.count) == version
    }

    /// Hands over each frame once it has been checked, and before the next one is read, so that `visit` may write
    /// anywhere before where the frame ends.
    private static func walkFrames(_ bytes: UnsafeRawBufferPointer, _ visit: (UInt16, Range<Int>) -> Void) -> FrameWalk {
        var cursor = fileHeaderSize
        while cursor + frameOverhead <= bytes.count {
            let type = UInt16(bytes[cursor]) << 8 | UInt16(bytes[cursor + 1])
            let length = Int(readUInt32(bytes, at: cursor + 2))
            let start = cursor + frameHeaderSize
            let end = start + length
            guard length > 0, length <= maxFrameSize, end + frameTrailerSize <= bytes.count
            else { break }

            var checksum = Crc32()
            checksum.advance(withBytes: UnsafeRawBufferPointer(rebasing: bytes[cursor..<end]))
            guard checksum.checksum == readUInt32(bytes, at: end)
            else { break }

            visit(type, start..<end)
            cursor = end + frameTrailerSize
        }
        return FrameWalk(reachedEnd: cursor == bytes.count)
    }

    private static func readUInt32(_ bytes: UnsafeRawBufferPointer, at offset: Int) -> UInt32 {
        UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
    }

    /// How many events a log holds, or nil where it is not one this version reads.
    static func eventCount(in file: Data) -> Int? {
        var events = 0
        guard forEachFramePayload(in: file, { type, _ in
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
        forEachFramePayload(in: file) { _, _ in }?.reachedEnd == false
    }

    /// Turns a log into the JSON array LaunchDarkly expects, in the log's own bytes, without parsing the events
    /// themselves: they were serialized on the way in and are shipped exactly as they were recorded.
    ///
    /// There is always room: the file header becomes the "[", and each frame's header and trailer the "," or "]" after
    /// its payload.
    /// Each payload moves towards the start only once its frame has been checked, and never past where that frame
    /// began, so no frame still to be checked is written over. A log nothing else refers to is changed where it is,
    /// rather than copied first.
    ///
    /// Only the first `maxEvents` events go into it; any after them are left out. So is everything from a frame that is
    /// torn or fails its checksum on, which is why the count it returns can be fewer than the log was closed holding.
    ///
    /// - Returns: how many events went into it. Where none did, or the log is not one this version reads, it is left as
    ///   it was.
    static func assembleBody(inPlace file: inout Data, maxEvents: Int = .max) -> Int {
        guard isReadable(file)
        else { return 0 }

        let (length, assembled) = file.withUnsafeMutableBytes { bytes -> (Int, Int) in
            var cursor = 1
            var events = 0
            _ = walkFrames(UnsafeRawBufferPointer(bytes)) { type, payload in
                guard type == eventFrame, events < maxEvents
                else { return }
                memmove(bytes.baseAddress! + cursor, bytes.baseAddress! + payload.lowerBound, payload.count)
                cursor += payload.count
                bytes[cursor] = UInt8(ascii: ",")
                cursor += 1
                events += 1
            }
            guard events > 0
            else { return (0, 0) }
            bytes[0] = UInt8(ascii: "[")
            bytes[cursor - 1] = UInt8(ascii: "]")
            return (cursor, events)
        }
        guard assembled > 0
        else { return 0 }
        file.count = length
        return assembled
    }

    /// `assembleBody(inPlace:maxEvents:)` into bytes of its own, leaving the log as it was.
    static func assembleBody(from file: Data, maxEvents: Int = .max) -> Data? {
        var body = file
        return assembleBody(inPlace: &body, maxEvents: maxEvents) > 0 ? body : nil
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

    /// The size, header and trailer included, of the frame at `start` in frames this process wrote.
    static func frameSize(in frames: Data, at start: Int) -> Int {
        frameOverhead + Int(readUInt32(frames, at: start + 2))
    }

    /// Where a run of whole frames from `start`, in frames this process wrote, ends if it is to take no more than
    /// `room` bytes, and how many frames it takes. It takes the first frame whatever its size.
    static func framesFitting(in frames: Data, from start: Int, room: Int) -> (end: Int, count: Int) {
        var end = start + frameSize(in: frames, at: start)
        var count = 1
        while end < frames.count, end + frameSize(in: frames, at: end) - start <= room {
            end += frameSize(in: frames, at: end)
            count += 1
        }
        return (end, count)
    }

    /// How many whole frames lie from `start` up to `end`, in frames this process wrote.
    static func frameCount(in frames: Data, from start: Int, to end: Int) -> Int {
        var count = 0
        var at = start
        while at < end {
            at += frameSize(in: frames, at: at)
            count += 1
        }
        return count
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
