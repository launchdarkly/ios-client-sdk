import Foundation

/// Writes an `Event` as the wire JSON the service already accepts, without going through `Codable`.
///
/// The field set, the omissions, and the redaction rules are deliberately identical to `Event.encode(to:)` and
/// `LDContext.encode(to:)`; where the two disagree, the `Codable` path is right and this is wrong.
struct EventJSONWriter {
    private let allAttributesPrivate: Bool
    private let globalPrivateAttributes: [Reference]

    /// Reuses the last context's encoded bytes when the next event carries the same context. Nil encodes every time.
    private(set) var contextCache: ContextEncodingCache?

    init(allAttributesPrivate: Bool, globalPrivateAttributes: [Reference], cachingContexts: Bool = false) {
        self.allAttributesPrivate = allAttributesPrivate
        self.globalPrivateAttributes = globalPrivateAttributes
        self.contextCache = cachingContexts ? ContextEncodingCache() : nil
    }

    init(config: LDConfig, cachingContexts: Bool = false) {
        self.init(allAttributesPrivate: config.allContextAttributesPrivate,
                  globalPrivateAttributes: config.privateContextAttributes,
                  cachingContexts: cachingContexts)
    }

    func encode(_ event: Event) -> Data? {
        encode(event, into: JSONWriter())
    }

    /// Encodes into a writer the caller owns, so its buffer can outlive one event. Callers are responsible for not
    /// sharing one writer across threads; `encode(_:)` allocates precisely so that the ordinary path need not care.
    func encode(_ event: Event, into writer: JSONWriter) -> Data? {
        writer.reset()
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
        writeContext(event.context, of: event, into: writer)

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
        writeContext(event.context, of: event, into: writer)

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
        writeContext(event.context, of: event, into: writer)
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
            writeContext(context, of: event, into: writer)
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

    /// The redaction directive comes from the event rather than the context, so every event can carry the caller's
    /// context value unchanged -- which is also what keeps the cache's `==` on its identity fast path.
    private func writeContext(_ context: LDContext, of event: Event, into writer: JSONWriter) {
        writer.key("context")
        // The event is the source of the directive. The context's own flag is folded in only so that this path cannot
        // disagree with `Codable` -- which reads that flag and has no way not to -- for a context that arrives with it
        // already set. Nothing in the SDK produces one, and the `||` is what keeps that from being load-bearing.
        let redactAnonymous = event.redactsAnonymousAttributes || context.redactAnonymousAttributes

        guard let cache = contextCache
        else {
            context.writeJSON(into: writer,
                              allAttributesPrivate: allAttributesPrivate,
                              globalPrivateAttributes: globalPrivateAttributes,
                              redactAnonymousAttributes: redactAnonymous)
            return
        }

        if let cached = cache.encodedContext(for: context, redactAnonymous: redactAnonymous) {
            writer.writeRaw(cached)
            return
        }

        let start = writer.byteCount
        context.writeJSON(into: writer,
                          allAttributesPrivate: allAttributesPrivate,
                          globalPrivateAttributes: globalPrivateAttributes,
                          redactAnonymousAttributes: redactAnonymous)
        cache.store(context, redactAnonymous: redactAnonymous, encoded: writer.bytes(from: start))
    }
}
