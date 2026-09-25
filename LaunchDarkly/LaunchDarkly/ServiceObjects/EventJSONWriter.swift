import Foundation

/// Writes an `Event` as the wire JSON the service already accepts, without going through `Codable`.
///
/// The field set, the omissions, and the redaction rules are deliberately identical to `Event.encode(to:)` and
/// `LDContext.encode(to:)`; where the two disagree, the `Codable` path is right and this is wrong.
///
/// One writer encodes one batch of events, and carries the byte buffer and the context cache for it. Events within a
/// batch are nearly always the same context over and over, and an instance is cheap, so the reuse worth having is the
/// reuse a batch already offers; making one writer outlive a batch would only mean sharing it across the concurrent
/// flushes `EventReporter` can have in flight.
///
/// Not thread-safe: the buffer and the cache are both mutated on every `encode(_:)`.
struct EventJSONWriter {
    private let allAttributesPrivate: Bool
    private let globalPrivateAttributes: [Reference]

    /// Reset for each event rather than replaced, so the capacity it has grown into is kept.
    private let writer = JSONWriter()

    /// Reuses a context's encoded bytes for the later events in this batch that carry it.
    private let contextCache = ContextEncodingCache()

    init(allAttributesPrivate: Bool, globalPrivateAttributes: [Reference]) {
        self.allAttributesPrivate = allAttributesPrivate
        self.globalPrivateAttributes = globalPrivateAttributes
    }

    init(config: LDConfig) {
        self.init(allAttributesPrivate: config.allContextAttributesPrivate,
                  globalPrivateAttributes: config.privateContextAttributes)
    }

    func encode(_ event: Event) -> Data? {
        writer.reset()
        guard write(event)
        else { return nil }
        return writer.data
    }

    private func write(_ event: Event) -> Bool {
        writer.beginObject()
        writer.key("kind")
        writer.write(event.kind.rawValue)

        switch event.kind {
        case .feature, .debug:
            guard let event = event as? FeatureEvent else { return false }
            write(feature: event)
        case .custom:
            guard let event = event as? CustomEvent else { return false }
            write(custom: event)
        case .identify:
            guard let event = event as? IdentifyEvent else { return false }
            write(identify: event)
        case .summary:
            guard let event = event as? SummaryEvent else { return false }
            write(summary: event)
        }

        writer.endObject()
        return true
    }

    private func write(feature event: FeatureEvent) {
        writer.key("key")
        writer.write(event.key)
        writeContext(event.context, of: event)

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

    private func write(custom event: CustomEvent) {
        writer.key("key")
        writer.write(event.key)
        writeContext(event.context, of: event)

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

    private func write(identify event: IdentifyEvent) {
        writer.key("key")
        writer.write(event.context.fullyQualifiedKey())
        writeContext(event.context, of: event)
        writer.key("creationDate")
        writer.write(event.creationDate.millisSince1970)
    }

    private func write(summary event: SummaryEvent) {
        writer.key("startDate")
        writer.write(event.flagRequestTracker.startDate.millisSince1970)
        writer.key("endDate")
        writer.write(event.endDate.millisSince1970)

        writer.key("features")
        writer.beginObject()
        for (flagKey, counter) in event.flagRequestTracker.flagCounters {
            writer.key(flagKey)
            write(counter: counter)
        }
        writer.endObject()

        if let context = event.context {
            writeContext(context, of: event)
        }
    }

    private func write(counter: FlagCounter) {
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
    private func writeContext(_ context: LDContext, of event: Event) {
        writer.key("context")
        // The event is the source of the directive. The context's own flag is folded in only so that this path cannot
        // disagree with `Codable` -- which reads that flag and has no way not to -- for a context that arrives with it
        // already set. Nothing in the SDK produces one, and the `||` is what keeps that from being load-bearing.
        let redactAnonymous = event.redactsAnonymousAttributes || context.redactAnonymousAttributes

        if let cached = contextCache.encodedContext(for: context, redactAnonymous: redactAnonymous) {
            writer.writeRaw(cached)
            return
        }

        let start = writer.byteCount
        context.writeJSON(into: writer,
                          allAttributesPrivate: allAttributesPrivate,
                          globalPrivateAttributes: globalPrivateAttributes,
                          redactAnonymousAttributes: redactAnonymous)
        contextCache.store(context, redactAnonymous: redactAnonymous, encoded: writer.bytes(from: start))
    }
}
