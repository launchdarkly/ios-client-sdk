import Foundation

/// Appends JSON straight into a byte buffer, with no intermediate objects, containers, or existentials.
///
/// This exists to find out what `Codable` costs on the event path, which is the one place the SDK pays for encoding on
/// the caller's thread. It is deliberately narrow: it knows how to write the shapes events are made of and nothing
/// else. Correctness against `JSONEncoder` is asserted by `EventJSONWriterTests`, which is the gate this has to pass
/// before any of it could be considered for use.
final class JSONWriter {
    private(set) var bytes: [UInt8] = []

    /// Whether the next value written needs a comma in front of it.
    ///
    /// Writing a key clears it, so the value that follows the colon is not preceded by one; writing a value or closing
    /// a container sets it, so whatever comes next is.
    private var needsSeparator = false

    init(reservingCapacity capacity: Int = 512) {
        bytes.reserveCapacity(capacity)
    }

    var data: Data { Data(bytes) }

    func reset() {
        bytes.removeAll(keepingCapacity: true)
        needsSeparator = false
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

    /// Integral values are written without a fractional part, which is what `JSONEncoder` does and what the service
    /// already receives. Anything else takes Swift's shortest round-trip description, which is valid JSON.
    func write(_ value: Double) {
        separate()
        if value.isFinite, value.rounded() == value, let exact = Int64(exactly: value.rounded()) {
            writeInteger(exact)
        } else if value.isFinite {
            bytes.append(contentsOf: String(value).utf8)
        } else {
            bytes.append(contentsOf: JSONWriter.nullBytes)
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

    /// Escapes exactly what JSON requires. Multi-byte UTF-8 passes through untouched, because every continuation byte
    /// has its high bit set and so matches none of the cases below.
    private func writeQuoted(_ value: String) {
        bytes.append(UInt8(ascii: "\""))
        for byte in value.utf8 {
            switch byte {
            case UInt8(ascii: "\""):
                bytes.append(contentsOf: [UInt8(ascii: "\\"), UInt8(ascii: "\"")])
            case UInt8(ascii: "\\"):
                bytes.append(contentsOf: [UInt8(ascii: "\\"), UInt8(ascii: "\\")])
            case 0x08:
                bytes.append(contentsOf: [UInt8(ascii: "\\"), UInt8(ascii: "b")])
            case 0x09:
                bytes.append(contentsOf: [UInt8(ascii: "\\"), UInt8(ascii: "t")])
            case 0x0A:
                bytes.append(contentsOf: [UInt8(ascii: "\\"), UInt8(ascii: "n")])
            case 0x0C:
                bytes.append(contentsOf: [UInt8(ascii: "\\"), UInt8(ascii: "f")])
            case 0x0D:
                bytes.append(contentsOf: [UInt8(ascii: "\\"), UInt8(ascii: "r")])
            case 0x00...0x1F:
                bytes.append(contentsOf: [UInt8(ascii: "\\"), UInt8(ascii: "u"), UInt8(ascii: "0"), UInt8(ascii: "0")])
                bytes.append(JSONWriter.hexDigits[Int(byte >> 4)])
                bytes.append(JSONWriter.hexDigits[Int(byte & 0x0F)])
            default:
                bytes.append(byte)
            }
        }
        bytes.append(UInt8(ascii: "\""))
    }
}

/// Writes an `Event` as the wire JSON the service already accepts, without going through `Codable`.
///
/// The field set, the omissions, and the redaction rules are deliberately identical to `Event.encode(to:)` and
/// `LDContext.encode(to:)`; where the two disagree, the `Codable` path is right and this is wrong.
struct EventJSONWriter {
    private let allAttributesPrivate: Bool
    private let globalPrivateAttributes: [Reference]

    init(allAttributesPrivate: Bool, globalPrivateAttributes: [Reference]) {
        self.allAttributesPrivate = allAttributesPrivate
        self.globalPrivateAttributes = globalPrivateAttributes
    }

    init(config: LDConfig) {
        self.init(allAttributesPrivate: config.allContextAttributesPrivate,
                  globalPrivateAttributes: config.privateContextAttributes)
    }

    func encode(_ event: Event) -> Data? {
        let writer = JSONWriter()
        guard write(event, into: writer)
        else { return nil }
        return writer.data
    }

    func write(_ event: Event, into writer: JSONWriter) -> Bool {
        writer.beginObject()
        writer.key("kind")
        writer.write(event.kind.rawValue)

        switch event.kind {
        case .feature, .debug:
            guard let event = event as? FeatureEvent else { return false }
            write(feature: event, into: writer)
        case .custom:
            guard let event = event as? CustomEvent else { return false }
            write(custom: event, into: writer)
        case .identify:
            guard let event = event as? IdentifyEvent else { return false }
            write(identify: event, into: writer)
        case .summary:
            guard let event = event as? SummaryEvent else { return false }
            write(summary: event, into: writer)
        }

        writer.endObject()
        return true
    }

    private func write(feature event: FeatureEvent, into writer: JSONWriter) {
        writer.key("key")
        writer.write(event.key)
        writeContext(event.context, into: writer)

        if let variation = event.featureFlag?.variation {
            writer.key("variation")
            writer.write(variation)
        }
        if let version = event.featureFlag?.versionForEvents {
            writer.key("version")
            writer.write(version)
        }

        writer.key("value")
        writer.write(event.value)
        writer.key("default")
        writer.write(event.defaultValue)

        let includeReason = event.includeReason || (event.featureFlag?.trackReason ?? false)
        if includeReason, let reason = event.featureFlag?.reason {
            writer.key("reason")
            writer.beginObject()
            for (name, value) in reason {
                writer.key(name)
                writer.write(value)
            }
            writer.endObject()
        }

        writer.key("creationDate")
        writer.write(event.creationDate.millisSince1970)
    }

    private func write(custom event: CustomEvent, into writer: JSONWriter) {
        writer.key("key")
        writer.write(event.key)
        writeContext(event.context, into: writer)

        if event.data != .null {
            writer.key("data")
            writer.write(event.data)
        }
        if let metricValue = event.metricValue {
            writer.key("metricValue")
            writer.write(metricValue)
        }

        writer.key("creationDate")
        writer.write(event.creationDate.millisSince1970)
    }

    private func write(identify event: IdentifyEvent, into writer: JSONWriter) {
        writer.key("key")
        writer.write(event.context.fullyQualifiedKey())
        writeContext(event.context, into: writer)
        writer.key("creationDate")
        writer.write(event.creationDate.millisSince1970)
    }

    private func write(summary event: SummaryEvent, into writer: JSONWriter) {
        writer.key("startDate")
        writer.write(event.flagRequestTracker.startDate.millisSince1970)
        writer.key("endDate")
        writer.write(event.endDate.millisSince1970)

        writer.key("features")
        writer.beginObject()
        for (flagKey, counter) in event.flagRequestTracker.flagCounters {
            writer.key(flagKey)
            write(counter: counter, into: writer)
        }
        writer.endObject()

        if let context = event.context {
            writeContext(context, into: writer)
        }
    }

    private func write(counter: FlagCounter, into writer: JSONWriter) {
        writer.beginObject()

        if counter.defaultValue != .null {
            writer.key("default")
            writer.write(counter.defaultValue)
        }

        writer.key("contextKinds")
        writer.beginArray()
        for kind in counter.contextKinds {
            writer.write(kind)
        }
        writer.endArray()

        writer.key("counters")
        writer.beginArray()
        for (key, value) in counter.flagValueCounters {
            writer.beginObject()
            if let version = key.version {
                writer.key("version")
                writer.write(version)
            }
            if let variation = key.variation {
                writer.key("variation")
                writer.write(variation)
            }
            writer.key("count")
            writer.write(value.count)
            writer.key("value")
            writer.write(value.value)
            if key.version == nil {
                writer.key("unknown")
                writer.write(true)
            }
            writer.endObject()
        }
        writer.endArray()

        writer.endObject()
    }

    private func writeContext(_ context: LDContext, into writer: JSONWriter) {
        writer.key("context")
        context.writeJSON(into: writer,
                          allAttributesPrivate: allAttributesPrivate,
                          globalPrivateAttributes: globalPrivateAttributes)
    }
}
