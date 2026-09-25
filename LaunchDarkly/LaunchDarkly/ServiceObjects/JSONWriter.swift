import Foundation

/// Appends compact JSON to a byte buffer. Callers are responsible for well-formed nesting: every `key` is followed by
/// exactly one value, and every container that is begun is ended.
final class JSONWriter {
    private var bytes: [UInt8] = []

    /// Whether the next value written needs a comma in front of it.
    ///
    /// Writing a key clears it, so the value that follows the colon is not preceded by one; writing a value or closing
    /// a container sets it, so whatever comes next is.
    private var needsSeparator = false

    init(reservingCapacity capacity: Int = 512) {
        bytes.reserveCapacity(capacity)
    }

    var data: Data {
        // Copied, so the next `reset()` cannot affect it.
        bytes.withUnsafeBytes { Data($0) }
    }

    var byteCount: Int { bytes.count }

    /// Whether a NaN or infinite `Double` has been written since the last `reset()`. JSON cannot represent one, so
    /// output with this set is not what the caller asked for.
    private(set) var wroteNonFiniteNumber = false

    func reset() {
        bytes.removeAll(keepingCapacity: true)
        needsSeparator = false
        wroteNonFiniteNumber = false
    }

    /// Appends JSON that was produced earlier, in the position a value would go.
    func writeRaw(_ raw: [UInt8]) {
        separate()
        bytes.append(contentsOf: raw)
        needsSeparator = true
    }

    /// A copy of the bytes written since `offset`, independent of the buffer so that `reset()` does not affect it.
    func bytes(from offset: Int) -> [UInt8] {
        bytes.withUnsafeBufferPointer { buffer in
            Array(buffer[offset..<buffer.count])
        }
    }

    // MARK: Structure

    func beginObject() {
        separate()
        bytes.append(UInt8(ascii: "{"))
        needsSeparator = false
    }

    func endObject() {
        bytes.append(UInt8(ascii: "}"))
        needsSeparator = true
    }

    func beginArray() {
        separate()
        bytes.append(UInt8(ascii: "["))
        needsSeparator = false
    }

    func endArray() {
        bytes.append(UInt8(ascii: "]"))
        needsSeparator = true
    }

    func key(_ name: String) {
        separate()
        writeQuoted(name)
        bytes.append(UInt8(ascii: ":"))
        needsSeparator = false
    }

    // MARK: Values

    func write(_ value: String) {
        separate()
        writeQuoted(value)
        needsSeparator = true
    }

    func write(_ value: Bool) {
        separate()
        bytes.append(contentsOf: value ? JSONWriter.trueBytes : JSONWriter.falseBytes)
        needsSeparator = true
    }

    func write(_ value: Int) {
        write(Int64(value))
    }

    func write(_ value: Int64) {
        separate()
        writeInteger(value)
        needsSeparator = true
    }

    /// Integral values up to 2^53 are written as plain integers and everything else as Swift's shortest round-trip
    /// description, the same boundary `JSONEncoder` uses. A non-finite value is written as `null`, so the output stays
    /// well-formed, and sets `wroteNonFiniteNumber`.
    ///
    /// `-0.0` is written as `0`, where `JSONEncoder` writes `-0`. Both parse to a value equal to zero.
    func write(_ value: Double) {
        separate()
        if value.isFinite, value.rounded() == value, value.magnitude <= JSONWriter.largestPlainInteger {
            writeInteger(Int64(value))
        } else if value.isFinite {
            bytes.append(contentsOf: String(value).utf8)
        } else {
            bytes.append(contentsOf: JSONWriter.nullBytes)
            wroteNonFiniteNumber = true
        }
        needsSeparator = true
    }

    func writeNull() {
        separate()
        bytes.append(contentsOf: JSONWriter.nullBytes)
        needsSeparator = true
    }

    func write(_ value: LDValue) {
        switch value {
        case .null:
            writeNull()
        case .bool(let boolValue):
            write(boolValue)
        case .number(let doubleValue):
            write(doubleValue)
        case .string(let stringValue):
            write(stringValue)
        case .array(let arrayValue):
            beginArray()
            for element in arrayValue {
                write(element)
            }
            endArray()
        case .object(let objectValue):
            beginObject()
            for (name, element) in objectValue {
                key(name)
                write(element)
            }
            endObject()
        }
    }

    // MARK: Primitives

    private static let trueBytes = Array("true".utf8)
    private static let falseBytes = Array("false".utf8)
    private static let nullBytes = Array("null".utf8)
    private static let hexDigits = Array("0123456789abcdef".utf8)

    /// 2^53, the largest value `JSONEncoder` writes without an exponent.
    private static let largestPlainInteger: Double = 9_007_199_254_740_992

    private func separate() {
        if needsSeparator {
            bytes.append(UInt8(ascii: ","))
        }
    }

    /// Digits are appended in reverse and then flipped in place, so no scratch buffer is allocated per number.
    private func writeInteger(_ value: Int64) {
        if value < 0 {
            bytes.append(UInt8(ascii: "-"))
        }
        var magnitude = value.magnitude
        if magnitude == 0 {
            bytes.append(UInt8(ascii: "0"))
            return
        }

        let start = bytes.count
        while magnitude > 0 {
            bytes.append(UInt8(ascii: "0") + UInt8(magnitude % 10))
            magnitude /= 10
        }

        var lower = start
        var upper = bytes.count - 1
        while lower < upper {
            bytes.swapAt(lower, upper)
            lower += 1
            upper -= 1
        }
    }

    /// Escapes exactly what JSON requires: control characters, `"` and `\`. Multi-byte UTF-8 passes through untouched,
    /// because every byte of it has the high bit set. `/` is left unescaped, where `JSONEncoder` writes `\/`; both
    /// decode to the same string.
    ///
    /// Runs that need no escaping are copied in one append. The byte-at-a-time fallback is for bridged strings, which
    /// may not have contiguous UTF-8 storage.
    private func writeQuoted(_ value: String) {
        bytes.append(UInt8(ascii: "\""))
        let written: Void? = value.utf8.withContiguousStorageIfAvailable { buffer in
            appendEscaped(buffer)
        }
        if written == nil {
            for byte in value.utf8 {
                if JSONWriter.needsEscape(byte) {
                    appendEscape(byte)
                } else {
                    bytes.append(byte)
                }
            }
        }
        bytes.append(UInt8(ascii: "\""))
    }

    private static func needsEscape(_ byte: UInt8) -> Bool {
        byte < 0x20 || byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "\\")
    }

    private func appendEscaped(_ buffer: UnsafeBufferPointer<UInt8>) {
        var runStart = 0
        for index in 0..<buffer.count where JSONWriter.needsEscape(buffer[index]) {
            if index > runStart {
                bytes.append(contentsOf: buffer[runStart..<index])
            }
            appendEscape(buffer[index])
            runStart = index + 1
        }
        if runStart < buffer.count {
            bytes.append(contentsOf: buffer[runStart...])
        }
    }

    private func appendEscape(_ byte: UInt8) {
        bytes.append(UInt8(ascii: "\\"))
        switch byte {
        case UInt8(ascii: "\""): bytes.append(UInt8(ascii: "\""))
        case UInt8(ascii: "\\"): bytes.append(UInt8(ascii: "\\"))
        case 0x08: bytes.append(UInt8(ascii: "b"))
        case 0x09: bytes.append(UInt8(ascii: "t"))
        case 0x0A: bytes.append(UInt8(ascii: "n"))
        case 0x0C: bytes.append(UInt8(ascii: "f"))
        case 0x0D: bytes.append(UInt8(ascii: "r"))
        default:
            bytes.append(UInt8(ascii: "u"))
            bytes.append(UInt8(ascii: "0"))
            bytes.append(UInt8(ascii: "0"))
            bytes.append(JSONWriter.hexDigits[Int(byte >> 4)])
            bytes.append(JSONWriter.hexDigits[Int(byte & 0x0F)])
        }
    }
}
