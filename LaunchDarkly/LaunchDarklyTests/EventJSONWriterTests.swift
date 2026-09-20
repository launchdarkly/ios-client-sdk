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

        // Run the whole corpus with the context cache off and on. With it on, the first event for a context misses and
        // the rest hit, and the feature events hit a *different* entry from the others because they carry a copy with
        // `redactAnonymousAttributes` set -- so this covers the cache distinguishing them as well as agreeing with
        // `Codable`.
        for cachingContexts in [false, true] {
            for (privacyName, allAttributesPrivate, globalPrivateAttributes) in privacySettings {
                let codable = Self.makeCodableEncoder(allAttributesPrivate: allAttributesPrivate,
                                                      globalPrivateAttributes: globalPrivateAttributes)
                let handWritten = EventJSONWriter(allAttributesPrivate: allAttributesPrivate,
                                                  globalPrivateAttributes: globalPrivateAttributes,
                                                  cachingContexts: cachingContexts)

                for (contextName, context) in contexts {
                    for (eventName, event) in events(context: context) {
                        let label = "\(eventName) / \(contextName) / \(privacyName) / cache \(cachingContexts)"

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

    /// The cache key's one non-obvious obligation.
    ///
    /// `Reference` compares its parsed components and ignores the string it was built from, so two contexts whose only
    /// difference is how a private attribute was spelled are `==`. Redaction writes that spelling into
    /// `_meta.redactedAttributes`, so they do not encode the same. A cache keyed on `==` alone would serve one for the
    /// other, which is why `ContextEncodingCache` compares spellings separately.
    func testPrivateAttributeSpellingIsPartOfTheCacheKey() throws {
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
        XCTAssertEqual(slashed, plain, "the hole this test guards has closed; the cache key can be simplified")

        // Events are built once, with a fixed creationDate, so that re-encoding one compares equal to itself.
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        let slashedEvent = IdentifyEvent(context: slashed, creationDate: when)
        let plainEvent = IdentifyEvent(context: plain, creationDate: when)

        // They do not encode the same, so `==` alone would be an unsound key.
        let plainWriter = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [])
        let slashedJSON = try canonical(try XCTUnwrap(plainWriter.encode(slashedEvent)))
        let plainJSON = try canonical(try XCTUnwrap(plainWriter.encode(plainEvent)))
        XCTAssertNotEqual(slashedJSON, plainJSON)

        // The cache must not confuse them, in either order, including on a repeat.
        let caching = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [], cachingContexts: true)
        // Paired explicitly rather than selected with `==`, which by construction cannot tell these two apart.
        let sequence = [(slashedEvent, slashedJSON), (plainEvent, plainJSON), (slashedEvent, slashedJSON),
                        (slashedEvent, slashedJSON), (plainEvent, plainJSON)]
        for (event, expected) in sequence {
            let produced = try canonical(try XCTUnwrap(caching.encode(event)))
            XCTAssertEqual(produced, expected)
        }
    }

    /// A run of events on one context, which is the pattern the cache exists for, then a context that changes under it.
    func testCacheSurvivesContextChanges() throws {
        let caching = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [], cachingContexts: true)
        let uncached = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [])

        var mutating = LDContextBuilder(key: "user-key")
        mutating.name("First")
        _ = mutating.trySetValue("email", "first@example.com")
        let first = try mutating.build().get()

        mutating.name("Second")
        _ = mutating.trySetValue("email", "second@example.com")
        let second = try mutating.build().get()

        // Same key and kind, different attributes: a digest keyed on the canonical key would collide here.
        XCTAssertNotEqual(first, second)

        for context in [first, first, second, second, first, anonymousContext(), first] {
            for (name, event) in events(context: context) {
                let produced = try canonical(try XCTUnwrap(caching.encode(event), name))
                XCTAssertEqual(produced, try canonical(try XCTUnwrap(uncached.encode(event), name)), "mismatch for \(name)")
            }
        }
    }

    /// `redactAnonymousAttributes` is never written out -- it is a directive, read in one place:
    /// `redactAll = allAttributesPrivate || (isAnonymous && redactAnonymousAttributes)`. So it can only reach the
    /// output through a context that is itself anonymous, or, for a multi-context, through any part that is: the
    /// top-level flag is passed down and each part is tested against its own `anonymous`.
    ///
    /// Where it cannot reach the output, the two variants the event stream carries encode to identical bytes -- and
    /// still occupy separate cache slots, because the flag is a stored property and so part of `==`.
    func testTheAnonymousRedactionFlagOnlyChangesBytesForAnonymousContexts() throws {
        func encoded(_ context: LDContext, redactAnonymous: Bool) throws -> String {
            let writer = JSONWriter()
            context.writeJSON(into: writer,
                              allAttributesPrivate: false,
                              globalPrivateAttributes: [],
                              redactAnonymousAttributes: redactAnonymous)
            return try canonical(writer.data)
        }

        // Nothing anonymous: the directive is inert, and the two cache slots hold the same bytes.
        for (name, context) in [("simple", simpleContext()), ("rich", richContext())] {
            XCTAssertEqual(try encoded(context, redactAnonymous: false),
                           try encoded(context, redactAnonymous: true),
                           "the directive reached the output for a context with no anonymous part: \(name)")
        }

        // Anonymous, whole or in part: the directive is load-bearing, and the slots must stay separate.
        for (name, context) in [("anonymous", anonymousContext()), ("multi, anonymous device", multiContext())] {
            XCTAssertNotEqual(try encoded(context, redactAnonymous: false),
                              try encoded(context, redactAnonymous: true),
                              "the directive failed to reach the output for: \(name)")
        }
    }

    /// The directive now comes from the event kind, so the same context redacts on a feature event and does not on the
    /// debug event that accompanies it. Both paths have to agree on that, since the debug event exists to show what was
    /// evaluated.
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

    /// `redactingAnonymousAttributes()` is a plain struct copy, which -- unlike the deep copy it replaced -- leaves the
    /// sub-contexts of a multi-context untouched instead of clearing their flags. That is only safe because encoding
    /// reads the flag from the top-level context and passes it down, ignoring whatever the sub-contexts hold. This
    /// pins that: setting the flag on a sub-context before it is added changes nothing about the output, while setting
    /// it on the parent redacts both.
    func testOnlyTheTopLevelAnonymousRedactionFlagIsRead() throws {
        func multiContext(redactingParts: Bool) throws -> LDContext {
            var builder = LDMultiContextBuilder()
            for kind in ["user", "device"] {
                var part = LDContextBuilder(key: "\(kind)-key")
                part.kind(kind)
                part.anonymous(true)
                _ = part.trySetValue("email", "person@example.com")
                let built = try part.build().get()
                builder.addContext(redactingParts ? built.redactingAnonymousAttributes() : built)
            }
            return try builder.build().get()
        }

        let plain = try multiContext(redactingParts: false)
        let partsFlagged = try multiContext(redactingParts: true)

        for (name, writer) in encoders() {
            // Pinned, because an event stamps its creation date when it is built: two of them either side of a
            // millisecond boundary differ in a field this has nothing to say about.
            let creationDate = Date()
            func encoded(_ context: LDContext) throws -> String {
                try canonical(try XCTUnwrap(writer(IdentifyEvent(context: context, creationDate: creationDate))))
            }

            // A flag set on the sub-contexts is not read, so it makes no difference.
            XCTAssertEqual(try encoded(partsFlagged), try encoded(plain), name)
            // Set on the parent, it is read, and the anonymous attributes go away.
            let redacted = try encoded(plain.redactingAnonymousAttributes())
            XCTAssertNotEqual(redacted, try encoded(plain), name)
            XCTAssertFalse(redacted.contains("person@example.com"), name)
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

    private func canonical(_ data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        let normalized = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed])
        return String(bytes: normalized, encoding: .utf8) ?? ""
    }
}
