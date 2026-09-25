import Foundation

/// Writes an `Event` as the JSON the events endpoint accepts, producing the same JSON as `Event.encode(to:)`.
///
/// Create one per batch. The buffer and the context cache are reused across the events of that batch, and neither is
/// safe to share between threads.
struct EventJSONWriter {
    private let allAttributesPrivate: Bool
    private let globalPrivateAttributes: [Reference]

    /// Reset for each event rather than replaced, so its capacity is kept.
    private let writer = JSONWriter()
    private let contextCache = ContextEncodingCache()

    init(allAttributesPrivate: Bool, globalPrivateAttributes: [Reference]) {
        self.allAttributesPrivate = allAttributesPrivate
        self.globalPrivateAttributes = globalPrivateAttributes
    }

    init(config: LDConfig) {
        self.init(allAttributesPrivate: config.allContextAttributesPrivate,
                  globalPrivateAttributes: config.privateContextAttributes)
    }

    /// Nil if the event cannot be encoded, including when it holds a NaN or infinite number, which `JSONEncoder` also
    /// rejects.
    func encode(_ event: Event) -> Data? {
        writer.reset()
        guard write(event), !writer.wroteNonFiniteNumber
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

    private func writeContext(_ context: LDContext, of event: Event) {
        writer.key("context")
        let redactAnonymous = event.redactsAnonymousAttributes

        if let cached = contextCache.encodedContext(for: context, redactAnonymous: redactAnonymous) {
            writer.writeRaw(cached)
            return
        }

        let start = writer.byteCount
        context.writeJSON(into: writer,
                          allAttributesPrivate: allAttributesPrivate,
                          globalPrivateAttributes: globalPrivateAttributes,
                          redactAnonymousAttributes: redactAnonymous)
        // A later event would otherwise be served these bytes without writing the number that makes them invalid.
        guard !writer.wroteNonFiniteNumber
        else { return }
        contextCache.store(context, redactAnonymous: redactAnonymous, encoded: writer.bytes(from: start))
    }
}
