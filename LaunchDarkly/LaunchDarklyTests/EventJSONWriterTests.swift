import XCTest
@testable import LaunchDarkly

/// The gate `EventJSONWriter` has to pass before its speed is worth discussing: for every event and context shape the
/// SDK can produce, it must write the same JSON the `Codable` path writes.
///
/// Comparison is JSON-equal rather than byte-equal, because neither encoder fixes the order of object keys and Swift's
/// `Dictionary` iteration order is not stable between runs. Both sides are reparsed and reserialized with sorted keys,
/// which normalizes ordering and `1` against `1.0` while still separating `true` from `1` and `"1"` from `1`.
final class EventJSONWriterTests: XCTestCase {

    // MARK: Corpus

    private func simpleContext() -> LDContext {
        var builder = LDContextBuilder(key: "user-key")
        builder.name("Simple")
        return try! builder.build().get()
    }

    private func richContext() -> LDContext {
        var builder = LDContextBuilder(key: "user-key")
        builder.kind("user")
        builder.name("Rich Context")
        _ = builder.trySetValue("firstName", "Ada")
        _ = builder.trySetValue("lastName", "Lovelace")
        _ = builder.trySetValue("email", "ada@example.com")
        _ = builder.trySetValue("age", 36)
        _ = builder.trySetValue("score", 12.5)
        _ = builder.trySetValue("negative", -17)
        _ = builder.trySetValue("verified", true)
        _ = builder.trySetValue("nothing", .null)
        _ = builder.trySetValue("tags", ["a", "b", "c"])
        _ = builder.trySetValue("address", ["street": "1 Main St", "city": "Springfield", "zip": 12345])
        _ = builder.trySetValue("deep", ["a": ["b": ["c": "d"]]])
        return try! builder.build().get()
    }

    /// Keys and values that exercise escaping, which is where a hand-written writer is most likely to be wrong.
    private func awkwardContext() -> LDContext {
        var builder = LDContextBuilder(key: "quote\"back\\slash")
        builder.name("tab\there\nnewline\u{0001}control")
        _ = builder.trySetValue("emoji 🎉", "héllo wörld → ✅")
        _ = builder.trySetValue("slash/key", "a/b")
        _ = builder.trySetValue("\u{7F}del", "\u{1F}unit")
        _ = builder.trySetValue("empty", "")
        _ = builder.trySetValue("emptyObject", [:])
        _ = builder.trySetValue("emptyArray", [])
        return try! builder.build().get()
    }

    private func anonymousContext() -> LDContext {
        var builder = LDContextBuilder(key: "anon-key")
        builder.name("Anonymous")
        builder.anonymous(true)
        _ = builder.trySetValue("email", "anon@example.com")
        return try! builder.build().get()
    }

    private func contextWithPrivateAttributes() -> LDContext {
        var builder = LDContextBuilder(key: "user-key")
        builder.name("Private")
        _ = builder.trySetValue("email", "private@example.com")
        _ = builder.trySetValue("address", ["street": "1 Main St", "city": "Springfield"])
        builder.addPrivateAttribute(Reference("email"))
        builder.addPrivateAttribute(Reference("/address/street"))
        return try! builder.build().get()
    }

    /// A context whose only `_meta` content is private attributes, which the event path never writes. The `Codable`
    /// path still emits an empty `_meta` object here, and so must this one.
    private func contextWithUnmatchedPrivateAttribute() -> LDContext {
        var builder = LDContextBuilder(key: "user-key")
        builder.name("Unmatched")
        builder.addPrivateAttribute(Reference("notPresent"))
        return try! builder.build().get()
    }

    private func multiContext() -> LDContext {
        var user = LDContextBuilder(key: "user-key")
        user.kind("user")
        user.name("Multi User")
        _ = user.trySetValue("email", "multi@example.com")

        var device = LDContextBuilder(key: "device-key")
        device.kind("device")
        device.anonymous(true)
        _ = device.trySetValue("os", ["name": "iOS", "version": 18])

        var builder = LDMultiContextBuilder()
        builder.addContext(try! user.build().get())
        builder.addContext(try! device.build().get())
        return try! builder.build().get()
    }

    private var contexts: [(String, LDContext)] {
        [("simple", simpleContext()),
         ("rich", richContext()),
         ("awkward", awkwardContext()),
         ("anonymous", anonymousContext()),
         ("private attributes", contextWithPrivateAttributes()),
         ("unmatched private attribute", contextWithUnmatchedPrivateAttribute()),
         ("multi", multiContext())]
    }

    /// The privacy configurations that change what redaction produces.
    private var privacySettings: [(String, Bool, [Reference])] {
        [("no redaction configured", false, []),
         ("all attributes private", true, []),
         ("global private: email", false, [Reference("email")]),
         ("global private: nested", false, [Reference("/address/street")]),
         ("global private: several", false, [Reference("email"), Reference("name"), Reference("/os/version")])]
    }

    private func events(context: LDContext) -> [(String, Event)] {
        let plainFlag = FeatureFlag(flagKey: "flag-key", value: true, variation: 1, flagVersion: 7, trackEvents: true)
        let reasonFlag = FeatureFlag(flagKey: "flag-key",
                                     value: true,
                                     variation: 2,
                                     version: 11,
                                     trackEvents: true,
                                     reason: ["kind": "RULE_MATCH", "ruleIndex": 1, "ruleId": "rule-id"],
                                     trackReason: true)
        let unknownFlag = FeatureFlag(flagKey: "flag-key", value: true)

        var tracker = FlagRequestTracker(logger: .disabled)
        tracker.trackRequest(flagKey: "flag-key", reportedValue: true, featureFlag: plainFlag, defaultValue: false, context: context)
        tracker.trackRequest(flagKey: "flag-key", reportedValue: true, featureFlag: plainFlag, defaultValue: false, context: context)
        tracker.trackRequest(flagKey: "other-key", reportedValue: "a", featureFlag: unknownFlag, defaultValue: .null, context: context)

        return [
            ("feature", FeatureEvent(key: "flag-key", context: context, value: true, defaultValue: false, featureFlag: plainFlag, includeReason: false, isDebug: false)),
            ("feature, reason", FeatureEvent(key: "flag-key", context: context, value: "v", defaultValue: "d", featureFlag: reasonFlag, includeReason: true, isDebug: false)),
            ("feature, no flag", FeatureEvent(key: "flag-key", context: context, value: .null, defaultValue: [1, 2], featureFlag: nil, includeReason: false, isDebug: false)),
            ("debug", FeatureEvent(key: "flag-key", context: context, value: true, defaultValue: false, featureFlag: plainFlag, includeReason: false, isDebug: true)),
            ("identify", IdentifyEvent(context: context)),
            ("custom, bare", CustomEvent(key: "custom-key", context: context)),
            ("custom, data", CustomEvent(key: "custom \"key\"", context: context, data: ["a": 1, "b": [true, .null, "x"]])),
            ("custom, metric", CustomEvent(key: "custom-key", context: context, data: "payload", metricValue: 3.25)),
            ("summary", SummaryEvent(flagRequestTracker: tracker, context: context))
        ]
    }

    // MARK: The gate

    func testMatchesCodableOutputAcrossTheCorpus() throws {
        var compared = 0

        for (privacyName, allAttributesPrivate, globalPrivateAttributes) in privacySettings {
            let codable = Self.makeCodableEncoder(allAttributesPrivate: allAttributesPrivate,
                                                  globalPrivateAttributes: globalPrivateAttributes)
            let handWritten = EventJSONWriter(allAttributesPrivate: allAttributesPrivate,
                                              globalPrivateAttributes: globalPrivateAttributes)

            for (contextName, context) in contexts {
                for (eventName, event) in events(context: context) {
                    let label = "\(eventName) / \(contextName) / \(privacyName)"

                    let expected = try codable.encode(event)
                    let actual = try XCTUnwrap(handWritten.encode(event), "no output for \(label)")

                    XCTAssertEqual(try canonical(expected),
                                   try canonical(actual),
                                   "mismatch for \(label)")
                    compared += 1
                }
            }
        }

        XCTAssertEqual(compared, privacySettings.count * contexts.count * events(context: simpleContext()).count)
    }

    /// Escaping in isolation, over every code point the writer treats specially plus a sample of those it does not.
    func testStringEscaping() throws {
        var scalars: [String] = ["", "plain", "\"", "\\", "/", "\u{07}", "\u{0B}", "\u{7F}", "é", "→", "🎉", "𝄞"]
        for code in 0x00...0x1F {
            scalars.append("x\(Character(UnicodeScalar(code)!))y")
        }

        for scalar in scalars {
            let writer = JSONWriter()
            writer.write(scalar)

            let expected = try JSONEncoder().encode([scalar])
            let actual = Data("[".utf8) + writer.data + Data("]".utf8)

            XCTAssertEqual(try canonical(expected), try canonical(actual), "mismatch escaping \(scalar.debugDescription)")
        }
    }

    func testNumberFormatting() throws {
        let numbers: [Double] = [0, -0, 1, -1, 17, -17, 0.5, -0.5, 1.25, 3.141592653589793,
                                 1e10, 1e-10, 1e20, -1e20, Double(Int32.max), Double(Int64.max), 9007199254740993]

        for number in numbers {
            let writer = JSONWriter()
            writer.write(LDValue.number(number))

            let expected = try JSONEncoder().encode([LDValue.number(number)])
            let actual = Data("[".utf8) + writer.data + Data("]".utf8)

            XCTAssertEqual(try canonical(expected), try canonical(actual), "mismatch formatting \(number)")
        }
    }

    /// The reporter's own path, so the switch is covered rather than just the writer behind it.
    func testReporterProducesIdenticalBytesEitherWay() throws {
        let context = richContext()
        var config = LDConfig.stub
        config.privateContextAttributes = [Reference("email")]

        for (name, event) in events(context: context) {
            let codableStore = EventStore.temporary(capacity: .max)
            defer { codableStore.deleteEverything() }
            let handWrittenStore = EventStore.temporary(capacity: .max)
            defer { handWrittenStore.deleteEverything() }

            let service = DarklyServiceMock()
            service.config = config

            let codableReporter = EventReporter(service: service, onSyncComplete: nil, store: codableStore, encoding: .codable)
            let handWrittenReporter = EventReporter(service: service, onSyncComplete: nil, store: handWrittenStore, encoding: .handWritten)

            codableReporter.record(event)
            handWrittenReporter.record(event)

            let expected = try XCTUnwrap(codableStore.pendingEventPayloads().first, "nothing recorded for \(name)")
            let actual = try XCTUnwrap(handWrittenStore.pendingEventPayloads().first, "nothing recorded for \(name)")

            XCTAssertEqual(try canonical(expected), try canonical(actual), "mismatch through the reporter for \(name)")
        }
    }

    // MARK: Helpers

    private static func makeCodableEncoder(allAttributesPrivate: Bool, globalPrivateAttributes: [Reference]) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.userInfo = [
            LDContext.UserInfoKeys.allAttributesPrivate: allAttributesPrivate,
            LDContext.UserInfoKeys.globalPrivateAttributes: globalPrivateAttributes.map { $0 }
        ]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.millisSince1970)
        }
        return encoder
    }

    private func canonical(_ data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        let normalized = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed])
        return String(bytes: normalized, encoding: .utf8) ?? ""
    }
}
