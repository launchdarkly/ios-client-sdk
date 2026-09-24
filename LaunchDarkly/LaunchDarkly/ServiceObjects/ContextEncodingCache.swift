import Foundation

/// Caches the encoded, redacted bytes of the contexts events were most recently written for.
///
/// The access pattern this exploits: an application identifies once and then evaluates repeatedly, so a run of events
/// shares one context.
///
/// **Two entries rather than one, because the event stream interleaves two encodings of the same context.** Feature
/// events and summaries redact anonymous attributes; custom, identify and debug events do not. The two produce
/// different bytes for an anonymous context, so a single entry thrashes: measured at a one-entry cache hitting on
/// **0 of 40,400** lookups at a commit point, which alternates a custom event with a summary. The directive is a
/// boolean, so two slots cover the interleaving exactly.
///
/// The directive is supplied by the caller rather than read from the context, because it belongs to the event -- see
/// `Event.redactsAnonymousAttributes`. That is what lets every event share one context value, so the `==` below stays
/// on `Dictionary` and `Array`'s identity fast path instead of walking attributes.
///
/// **The cache key is the whole of the correctness argument.** Serving one context's redacted bytes for another is a
/// privacy bug, and a far worse outcome than being slow, so the key is the context *value* rather than a digest of it.
/// Everything redaction reads is either a stored property of `LDContext` -- and so covered by its synthesized `==` --
/// or fixed for the lifetime of the reporter that owns this cache:
///
/// - `kind`, `key`, `name`, `anonymous`, `attributes`, `contexts` and `privateAttributes` are stored properties,
///   compared by `==`; the redaction directive is the slot.
/// - `allAttributesPrivate` and `globalPrivateAttributes` come from `LDConfig`, which is a `let` on the service.
///
/// There is exactly one gap in `==`, and `spellingsMatch` closes it. See its comment.
final class ContextEncodingCache {
    private struct Entry {
        let context: LDContext
        let spellings: [String]
        let encoded: [UInt8]
    }

    private let lock = UnfairLock()
    private var entries: [Entry?] = [nil, nil]

    /// The encoded bytes for `context` under `redactAnonymous`, or nil if that slot does not hold it.
    func encodedContext(for context: LDContext, redactAnonymous: Bool) -> [UInt8]? {
        lock.lock()
        defer { lock.unlock() }

        guard let entry = entries[ContextEncodingCache.slot(redactAnonymous)],
              entry.context == context,
              ContextEncodingCache.spellingsMatch(entry.spellings, context)
        else { return nil }

        return entry.encoded
    }

    func store(_ context: LDContext, redactAnonymous: Bool, encoded: [UInt8]) {
        let entry = Entry(context: context,
                          spellings: ContextEncodingCache.spellings(of: context),
                          encoded: encoded)

        lock.lock()
        defer { lock.unlock() }

        entries[ContextEncodingCache.slot(redactAnonymous)] = entry
    }

    /// The directive is not part of the context, and so not part of `==`; the two encodings would otherwise evict each
    /// other in a single slot.
    private static func slot(_ redactAnonymous: Bool) -> Int {
        redactAnonymous ? 1 : 0
    }

    /// `Reference` compares and hashes its *parsed components* and ignores the raw string it was built from, so
    /// `Reference("name") == Reference("/name")`. Redaction writes `raw()` into `_meta.redactedAttributes`, so two
    /// contexts that differ only in how a private attribute was spelled are `==` yet encode differently. `==` alone is
    /// therefore not a sound key, and the spellings are compared separately.
    ///
    /// Contexts with no private attributes -- the common case -- settle this without allocating.
    private static func spellingsMatch(_ cached: [String], _ context: LDContext) -> Bool {
        if cached.isEmpty && !hasPrivateAttributes(context) {
            return true
        }
        return cached == spellings(of: context)
    }

    private static func hasPrivateAttributes(_ context: LDContext) -> Bool {
        !context.privateAttributes.isEmpty || context.contexts.contains(where: hasPrivateAttributes)
    }

    private static func spellings(of context: LDContext) -> [String] {
        guard hasPrivateAttributes(context)
        else { return [] }

        var raws = context.privateAttributes.map { $0.raw() }
        for sub in context.contexts {
            raws.append(contentsOf: spellings(of: sub))
        }
        return raws.sorted()
    }
}
