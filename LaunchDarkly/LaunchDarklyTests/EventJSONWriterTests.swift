import XCTest
@testable import LaunchDarkly

/// For every event and context shape the SDK can produce, `EventJSONWriter` must write the same JSON as the `Codable`
/// path.
///
/// Comparison is JSON-equal rather than byte-equal, because neither encoder fixes the order of object keys. Both sides
/// are reparsed and reserialized with sorted keys, which normalizes ordering and `1` against `1.0` while still
/// separating `true` from `1` and `"1"` from `1`.
///
/// That normalization also hides the writer's known byte-level differences -- `/` against `\/`, `0` against `-0` --
/// and it reserializes `100000000000000000` and `1e+17` differently even though they are the same number, so numbers
/// are also compared as bytes where the two formats should agree exactly.
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

    /// Keys and values that need escaping.
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

    /// A private attribute that matches nothing, so nothing is redacted and no `_meta` is written.
    private func contextWithUnmatchedPrivateAttribute() -> LDContext {
        var builder = LDContextBuilder(key: "user-key")
        builder.name("Unmatched")
        builder.addPrivateAttribute(Reference("notPresent"))
        return try! builder.build().get()
    }

    /// Tries to set an attribute named `_meta` alongside a private attribute, so `_meta` is also written by the SDK.
    private func contextAttemptingMeta() -> LDContext {
        var builder = LDContextBuilder(key: "user-key")
        builder.name("Meta")
        _ = builder.trySetValue("email", "meta@example.com")
        _ = builder.trySetValue("_meta", ["redactedAttributes": [], "appSupplied": "leaked"])
        builder.addPrivateAttribute(Reference("email"))
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
         ("attempting _meta", contextAttemptingMeta()),
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

    // MARK: Agreement with Codable

    func testMatchesCodableOutputAcrossTheCorpus() throws {
        var compared = 0

        // Once with a writer per event, so the cache never hits, and once with one writer for the whole corpus, so
        // every event after the first for a context hits. Feature events and summaries use the other cache entry,
        // so the second pass also covers the two entries being kept apart.
        for sharingAWriter in [false, true] {
            for (privacyName, allAttributesPrivate, globalPrivateAttributes) in privacySettings {
                let codable = Self.makeCodableEncoder(allAttributesPrivate: allAttributesPrivate,
                                                      globalPrivateAttributes: globalPrivateAttributes)
                let shared = EventJSONWriter(allAttributesPrivate: allAttributesPrivate,
                                             globalPrivateAttributes: globalPrivateAttributes)

                for (contextName, context) in contexts {
                    for (eventName, event) in events(context: context) {
                        let label = "\(eventName) / \(contextName) / \(privacyName) / shared \(sharingAWriter)"

                        let handWritten = sharingAWriter
                            ? shared
                            : EventJSONWriter(allAttributesPrivate: allAttributesPrivate,
                                              globalPrivateAttributes: globalPrivateAttributes)

                        let expected = try codable.encode(event)
                        let actual = try XCTUnwrap(handWritten.encode(event), "no output for \(label)")

                        XCTAssertEqual(try canonical(expected),
                                       try canonical(actual),
                                       "mismatch for \(label)")
                        compared += 1
                    }
                }
            }
        }

        XCTAssertEqual(compared, 2 * privacySettings.count * contexts.count * events(context: simpleContext()).count)
    }

    /// Contexts that differ only in how a private attribute is spelled are `==`, so they share a cache entry, and must
    /// therefore encode the same.
    func testPrivateAttributeSpellingDoesNotReachTheOutput() throws {
        func context(privateAttribute: String) throws -> LDContext {
            var builder = LDContextBuilder(key: "user-key")
            builder.name("Spelling")
            _ = builder.trySetValue("email", "a@example.com")
            builder.addPrivateAttribute(Reference(privateAttribute))
            return try builder.build().get()
        }

        let slashed = try context(privateAttribute: "/email")
        let plain = try context(privateAttribute: "email")

        // The premise: `==` cannot tell them apart.
        XCTAssertEqual(slashed, plain)

        // Events are built once, with a fixed creationDate, so that the two differ only in the context.
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        let slashedEvent = IdentifyEvent(context: slashed, creationDate: when)
        let plainEvent = IdentifyEvent(context: plain, creationDate: when)

        // A fresh writer each time, so each event is encoded rather than served from the other's entry.
        func encodeAlone(_ event: Event) throws -> Data {
            let writer = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [])
            return try XCTUnwrap(writer.encode(event))
        }

        let slashedData = try encodeAlone(slashedEvent)
        let slashedJSON = try canonical(slashedData)
        XCTAssertEqual(try canonical(try encodeAlone(plainEvent)), slashedJSON)

        let written = try XCTUnwrap(String(data: slashedData, encoding: .utf8))
        XCTAssertTrue(written.contains("\"redactedAttributes\":[\"/email\"]"),
                      "expected the canonical spelling, got \(written)")

        // And the same through one writer, where the second event does come from the first's entry.
        let shared = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [])
        for event in [slashedEvent, plainEvent, slashedEvent, plainEvent] {
            XCTAssertEqual(try canonical(try XCTUnwrap(shared.encode(event))), slashedJSON)
        }
    }

    /// Checked on the raw bytes, because reparsing collapses repeated keys and would hide a second `_meta`.
    func testOnlyTheSDKWritesMeta() throws {
        let event = IdentifyEvent(context: contextAttemptingMeta())

        for (name, writer) in encoders() {
            let written = utf8(try XCTUnwrap(writer(event), name))

            XCTAssertEqual(written.components(separatedBy: "\"_meta\"").count - 1, 1, "\(name): \(written)")
            XCTAssertFalse(written.contains("appSupplied"), "\(name): \(written)")
            XCTAssertTrue(written.contains("\"redactedAttributes\":[\"") && written.contains("email\"]"),
                          "\(name): \(written)")
        }
    }

    /// Events write `_meta` only when something was redacted. Unredacted output keeps it for a context with private
    /// attributes, because `contextHash()` digests that output to validate cached flags.
    func testMetaIsWrittenOnlyWhenSomethingWasRedacted() throws {
        let context = contextWithUnmatchedPrivateAttribute()

        for (name, writer) in encoders() {
            let written = utf8(try XCTUnwrap(writer(IdentifyEvent(context: context)), name))
            XCTAssertFalse(written.contains("_meta"), "\(name): \(written)")
        }

        let unredacted = JSONEncoder()
        unredacted.userInfo[LDContext.UserInfoKeys.redactAttributes] = false
        XCTAssertTrue(utf8(try unredacted.encode(context)).contains("\"_meta\":{}"))
    }

    /// Wherever a NaN or infinite number sits in an event, neither encoder produces output for it.
    func testEventsHoldingNonFiniteNumbersAreRejectedByBothEncoders() throws {
        var builder = LDContextBuilder(key: "user-key")
        _ = builder.trySetValue("score", .number(.infinity))
        let contextWithInfinity = try builder.build().get()
        let context = simpleContext()

        var tracker = FlagRequestTracker(logger: .disabled)
        tracker.trackRequest(flagKey: "flag-key", reportedValue: .number(.nan), featureFlag: nil,
                             defaultValue: false, context: context)

        let events: [(String, Event)] = [
            ("metric", CustomEvent(key: "custom-key", context: context, metricValue: .nan)),
            ("data", CustomEvent(key: "custom-key", context: context, data: ["nested": [.number(-.infinity)]])),
            ("feature value", FeatureEvent(key: "flag-key", context: context, value: .number(.nan), defaultValue: false,
                                           featureFlag: nil, includeReason: false, isDebug: false)),
            ("summary value", SummaryEvent(flagRequestTracker: tracker, context: context)),
            ("context attribute", IdentifyEvent(context: contextWithInfinity))
        ]

        let codable = Self.makeCodableEncoder(allAttributesPrivate: false, globalPrivateAttributes: [])
        let handWritten = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [])
        for (name, event) in events {
            XCTAssertThrowsError(try codable.encode(event), name)
            XCTAssertNil(handWritten.encode(event), name)
        }
    }

    /// A context that failed to encode is not cached, or a later event would be served its bytes without the number
    /// that made them invalid.
    func testAContextHoldingANonFiniteNumberIsNotCached() throws {
        var builder = LDContextBuilder(key: "user-key")
        _ = builder.trySetValue("score", .number(.nan))
        let context = try builder.build().get()

        let writer = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [])
        for _ in 0..<3 {
            XCTAssertNil(writer.encode(IdentifyEvent(context: context)))
            XCTAssertNil(writer.encode(CustomEvent(key: "custom-key", context: context)))
        }
        XCTAssertNotNil(writer.encode(IdentifyEvent(context: simpleContext())))
    }

    /// A run of events on one context, then on a different one.
    func testCacheSurvivesContextChanges() throws {
        let caching = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [])

        var mutating = LDContextBuilder(key: "user-key")
        mutating.name("First")
        _ = mutating.trySetValue("email", "first@example.com")
        let first = try mutating.build().get()

        mutating.name("Second")
        _ = mutating.trySetValue("email", "second@example.com")
        let second = try mutating.build().get()

        // Same key and kind, different attributes.
        XCTAssertNotEqual(first, second)

        for context in [first, first, second, second, first, anonymousContext(), first] {
            for (name, event) in events(context: context) {
                let uncached = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [])
                let produced = try canonical(try XCTUnwrap(caching.encode(event), name))
                XCTAssertEqual(produced, try canonical(try XCTUnwrap(uncached.encode(event), name)), "mismatch for \(name)")
            }
        }
    }

    func testAnEqualContextBuiltSeparatelyIsServedFromTheCache() throws {
        let cache = ContextEncodingCache()
        let stored = richContext()
        let rebuilt = richContext()
        let encoded = Array("stored".utf8)
        XCTAssertEqual(stored, rebuilt)

        cache.store(stored, redactAnonymous: false, encoded: encoded)

        for _ in 0..<3 {
            XCTAssertEqual(cache.encodedContext(for: rebuilt, redactAnonymous: false), encoded)
            XCTAssertEqual(cache.encodedContext(for: stored, redactAnonymous: false), encoded)
        }
        XCTAssertNil(cache.encodedContext(for: rebuilt, redactAnonymous: true))
        XCTAssertNil(cache.encodedContext(for: simpleContext(), redactAnonymous: false))
        XCTAssertEqual(cache.encodedContext(for: stored, redactAnonymous: false), encoded)
    }

    /// The anonymous-redaction directive only affects contexts that are anonymous, or multi-contexts with an anonymous
    /// part.
    func testTheAnonymousRedactionFlagOnlyChangesBytesForAnonymousContexts() throws {
        func encoded(_ context: LDContext, redactAnonymous: Bool) throws -> String {
            let writer = JSONWriter()
            context.writeJSON(into: writer,
                              allAttributesPrivate: false,
                              globalPrivateAttributes: [],
                              redactAnonymousAttributes: redactAnonymous)
            return try canonical(writer.data)
        }

        // Nothing anonymous: the directive changes nothing.
        for (name, context) in [("simple", simpleContext()), ("rich", richContext())] {
            XCTAssertEqual(try encoded(context, redactAnonymous: false),
                           try encoded(context, redactAnonymous: true),
                           "the directive reached the output for a context with no anonymous part: \(name)")
        }

        // Anonymous, whole or in part: the directive changes the output.
        for (name, context) in [("anonymous", anonymousContext()), ("multi, anonymous device", multiContext())] {
            XCTAssertNotEqual(try encoded(context, redactAnonymous: false),
                              try encoded(context, redactAnonymous: true),
                              "the directive failed to reach the output for: \(name)")
        }
    }

    /// The same context is redacted in a feature event and not in the debug event that accompanies it, by both encoders.
    func testTheEventKindDecidesWhetherAnonymousAttributesAreRedacted() throws {
        let context = anonymousContext()
        let flag = FeatureFlag(flagKey: "flag-key", value: true, variation: 1, flagVersion: 7, trackEvents: true)

        func event(isDebug: Bool) -> FeatureEvent {
            FeatureEvent(key: "flag-key", context: context, value: true, defaultValue: false,
                         featureFlag: flag, includeReason: false, isDebug: isDebug)
        }

        for (name, writer) in encoders() {
            let feature = try canonical(try XCTUnwrap(writer(event(isDebug: false))))
            let debug = try canonical(try XCTUnwrap(writer(event(isDebug: true))))

            XCTAssertFalse(feature.contains("anon@example.com"), "feature event leaked an anonymous attribute: \(name)")
            XCTAssertTrue(feature.contains("redactedAttributes"), "feature event did not redact: \(name)")
            XCTAssertTrue(debug.contains("anon@example.com"), "debug event redacted when it should not have: \(name)")
        }
    }

    /// The `Codable` encoder and the hand-written one, so a test can assert a behaviour holds for both.
    private func encoders() -> [(String, (Event) throws -> Data?)] {
        let codable = Self.makeCodableEncoder(allAttributesPrivate: false, globalPrivateAttributes: [])
        let handWritten = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [])
        return [("Codable", { try codable.encode($0) }), ("hand-written", { handWritten.encode($0) })]
    }

    func testAFeatureEventRedactsEveryAnonymousPartOfAMultiContext() throws {
        var builder = LDMultiContextBuilder()
        for kind in ["user", "device"] {
            var part = LDContextBuilder(key: "\(kind)-key")
            part.kind(kind)
            part.anonymous(true)
            _ = part.trySetValue("email", .string("\(kind)@example.com"))
            builder.addContext(try part.build().get())
        }
        let context = try builder.build().get()
        let flag = FeatureFlag(flagKey: "flag-key", value: true, variation: 1, flagVersion: 7, trackEvents: true)

        for (name, writer) in encoders() {
            for isDebug in [false, true] {
                let event = FeatureEvent(key: "flag-key", context: context, value: true, defaultValue: false,
                                         featureFlag: flag, includeReason: false, isDebug: isDebug)
                let written = try canonical(try XCTUnwrap(writer(event)))

                for kind in ["user", "device"] {
                    XCTAssertEqual(written.contains("\(kind)@example.com"), isDebug, "\(name), debug \(isDebug): \(kind)")
                }
            }
        }
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

    func testIntegerFormatting() throws {
        let values: [Int64] = [0, 1, -1, 17, -17, Int64.min, Int64.max]

        for value in values {
            let writer = JSONWriter()
            writer.write(value)

            let expected = try JSONEncoder().encode([value])
            let actual = Data("[".utf8) + writer.data + Data("]".utf8)

            XCTAssertEqual(try canonical(expected), try canonical(actual), "mismatch formatting \(value)")
        }
    }

    func testNumberFormatting() throws {
        let numbers: [Double] = [0, -0, 1, -1, 17, -17, 0.5, -0.5, 1.25, 3.141592653589793,
                                 1e10, 1e-10, 1e20, -1e20, Double(Int32.max), Double(Int64.max), 9007199254740993,
                                 1e16, 1e17, -1e17, 1.5e17, 1e18, 9.2e18, -9.2e18, 9223372036854774784]

        for number in numbers {
            let writer = JSONWriter()
            writer.write(LDValue.number(number))

            let expected = try JSONEncoder().encode([LDValue.number(number)])
            let actual = Data("[".utf8) + writer.data + Data("]".utf8)

            XCTAssertEqual(try canonical(expected), try canonical(actual), "mismatch formatting \(number)")
        }
    }

    /// Integral doubles on both sides of 2^53, compared as bytes rather than through `canonical`.
    ///
    /// `JSONEncoder` writes plain integers up to 2^53 and exponent form above it. The writer has to change form at the
    /// same place: `canonical` cannot be relied on to notice, because it reserializes the two forms identically below
    /// 1e17 and differently above.
    func testIntegralDoublesChangeFormWhereJSONEncoderDoes() throws {
        let twoTo53: Double = 9_007_199_254_740_992
        let numbers: [Double] = [0, 1, -1, 1e15, twoTo53 - 1, twoTo53, -twoTo53, twoTo53 + 2, -(twoTo53 + 2),
                                 1e16, -1e16, 99999999999999984, 1e17, -1e17, 1e18, 9223372036854774784,
                                 Double(Int64.max), -Double(Int64.max), 1e20]

        for number in numbers {
            let writer = JSONWriter()
            writer.write(number)

            let expected = utf8(try JSONEncoder().encode([number]))
            let actual = "[" + utf8(writer.data) + "]"

            XCTAssertEqual(actual, expected, "\(number) written in a different form")
        }
    }

    /// The places the writer's bytes differ from `JSONEncoder`'s on purpose, pinned so a change to either is noticed.
    ///
    /// Each pair is the same JSON value; the writer skips an escape JSON does not require, and writes zero without a
    /// sign.
    func testKnownByteDifferencesFromJSONEncoderAreEqualJSON() throws {
        let slash = JSONWriter()
        slash.write("a/b")
        XCTAssertEqual(utf8(slash.data), "\"a/b\"")
        XCTAssertEqual(utf8(try JSONEncoder().encode("a/b")), "\"a\\/b\"")
        XCTAssertEqual(try canonical(slash.data), try canonical(try JSONEncoder().encode("a/b")))

        let negativeZero = JSONWriter()
        negativeZero.write(-0.0)
        XCTAssertEqual(utf8(negativeZero.data), "0")
        XCTAssertEqual(utf8(try JSONEncoder().encode(-0.0)), "-0")
        XCTAssertEqual(try canonical(negativeZero.data), try canonical(try JSONEncoder().encode(-0.0)))
    }

    /// The reporter's own path, so the switch is covered rather than just the writer behind it.
    func testReporterProducesEqualJSONEitherWay() throws {
        let context = richContext()
        var config = LDConfig.stub
        config.privateContextAttributes = [Reference("email")]

        for (name, event) in events(context: context) {
            let expected = try XCTUnwrap(published(event, config: config, encoding: .codable),
                                         "nothing published for \(name)")
            let actual = try XCTUnwrap(published(event, config: config, encoding: .handWritten),
                                       "nothing published for \(name)")

            XCTAssertEqual(try canonical(expected), try canonical(actual), "mismatch through the reporter for \(name)")
        }
    }

    /// Records one event and returns the payload the reporter handed to the service.
    private func published(_ event: Event, config: LDConfig, encoding: EventReporter.Encoding) -> Data? {
        let service = DarklyServiceMock()
        service.config = config
        service.stubEventResponse(success: true)

        let reporter = EventReporter(service: service, onSyncComplete: nil, encoding: encoding)
        reporter.isOnline = true
        reporter.record(event)

        let published = expectation(description: "published")
        reporter.flush { published.fulfill() }
        wait(for: [published], timeout: 5)

        return service.publishedEventData
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

    private func utf8(_ data: Data) -> String {
        String(bytes: data, encoding: .utf8) ?? ""
    }

    private func canonical(_ data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        let normalized = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed])
        return String(bytes: normalized, encoding: .utf8) ?? ""
    }
}
