import Foundation

/// Caches the encoded, redacted bytes of the contexts events were most recently written for.
///
/// The access pattern this exploits: an application identifies once and then evaluates repeatedly, so a run of events
/// shares one context.
///
/// **Two entries rather than one, because the event stream interleaves two variants of the same context.** Feature
/// events carry a copy with `redactAnonymousAttributes` set, and so do summaries, since
/// `ContextSummarizer.ensureTrackerExists` stores a filtered copy; custom, identify and debug events carry it clear.
/// Those two variants are not `==` -- correctly, since the flag changes what an anonymous context encodes to -- so a
/// single entry thrashes. Measured: a one-entry cache hit on **0 of 40,400** lookups at a commit point, which
/// alternates a custom event with a summary. Since the flag is a boolean, two slots cover the interleaving exactly.
///
/// **The cache key is the whole of the correctness argument.** Serving one context's redacted bytes for another is a
/// privacy bug, and a far worse outcome than being slow, so the key is the context *value* rather than a digest of it.
/// Everything redaction reads is either a stored property of `LDContext` -- and so covered by its synthesized `==` --
/// or fixed for the lifetime of the reporter that owns this cache:
///
/// - `kind`, `key`, `name`, `anonymous`, `attributes`, `contexts`, `privateAttributes` and `redactAnonymousAttributes`
///   are stored properties, compared by `==`.
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

    /// Counted only so the experiment can report a hit rate rather than assume one.
    private(set) var hits = 0
    private(set) var misses = 0

    /// The encoded bytes for `context`, or nil if no slot holds it.
    func encodedContext(for context: LDContext) -> [UInt8]? {
        lock.lock()
        defer { lock.unlock() }

        guard let entry = entries[ContextEncodingCache.slot(for: context)],
              entry.context == context,
              ContextEncodingCache.spellingsMatch(entry.spellings, context)
        else {
            misses += 1
            return nil
        }

        hits += 1
        return entry.encoded
    }

    func resetCounters() {
        lock.lock()
        defer { lock.unlock() }
        hits = 0
        misses = 0
    }

    func store(_ context: LDContext, encoded: [UInt8]) {
        let entry = Entry(context: context,
                          spellings: ContextEncodingCache.spellings(of: context),
                          encoded: encoded)

        lock.lock()
        defer { lock.unlock() }

        entries[ContextEncodingCache.slot(for: context)] = entry
    }

    /// `redactAnonymousAttributes` is part of `==`, so the two variants would evict each other in a single slot.
    private static func slot(for context: LDContext) -> Int {
        context.redactAnonymousAttributes ? 1 : 0
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
