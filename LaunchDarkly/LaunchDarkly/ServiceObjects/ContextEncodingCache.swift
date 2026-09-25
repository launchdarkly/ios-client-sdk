import Foundation

/// Caches the encoded, redacted bytes of the most recently written contexts, so a run of events sharing a context
/// encodes it once.
///
/// There is one entry per redaction directive. Feature events and summaries redact anonymous attributes and the other
/// event kinds do not, so an anonymous context has two encodings, and a stream that alternates them would evict a
/// single entry on every event.
///
/// Serving one context's bytes for another would leak attributes that should have been redacted, so the key is the
/// context value itself, compared with `==`. That covers everything redaction depends on: the context's stored
/// properties are all part of `==`, the directive selects the entry, and `allAttributesPrivate` and
/// `globalPrivateAttributes` are fixed for the lifetime of the owning `EventJSONWriter`. Redacted attributes are
/// written from `Reference.canonical()`, so private attributes that are `==` but spelled differently encode the same.
///
/// `==` returns without reading attributes when both sides share storage, which is the case for copies of one
/// context. A hit therefore replaces the stored context with the caller's, so that after an equal but separately built
/// context arrives, later lookups compare by identity again rather than attribute by attribute.
///
/// Not thread-safe. It belongs to one `EventJSONWriter` and is used only through it.
final class ContextEncodingCache {
    private struct Entry {
        let context: LDContext
        let encoded: [UInt8]
    }

    private var entries: [Entry?] = [nil, nil]

    /// The encoded bytes for `context` under `redactAnonymous`, or nil if that entry holds a different context.
    func encodedContext(for context: LDContext, redactAnonymous: Bool) -> [UInt8]? {
        let slot = ContextEncodingCache.slot(redactAnonymous)
        guard let entry = entries[slot], entry.context == context
        else { return nil }

        entries[slot] = Entry(context: context, encoded: entry.encoded)
        return entry.encoded
    }

    func store(_ context: LDContext, redactAnonymous: Bool, encoded: [UInt8]) {
        entries[ContextEncodingCache.slot(redactAnonymous)] = Entry(context: context, encoded: encoded)
    }

    private static func slot(_ redactAnonymous: Bool) -> Int {
        redactAnonymous ? 1 : 0
    }
}
