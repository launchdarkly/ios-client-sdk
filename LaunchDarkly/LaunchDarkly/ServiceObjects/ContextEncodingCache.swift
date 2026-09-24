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
/// or fixed for the lifetime of the reporter:
///
/// - `kind`, `key`, `name`, `anonymous`, `attributes`, `contexts` and `privateAttributes` are stored properties,
///   compared by `==`; the redaction directive is the slot.
/// - `allAttributesPrivate` and `globalPrivateAttributes` come from `LDConfig`, which is a `let` on the service.
///
/// `Reference` equality is on parsed components and ignores the string a reference was spelled with, which would
/// leave a gap here if redaction wrote that spelling out. It does not: redacted attributes are written from
/// `Reference.canonical()`, so contexts that are `==` encode the same.
///
/// One instance belongs to one `EventJSONWriter`, which belongs to one batch being encoded, so it is never shared and
/// takes no lock.
final class ContextEncodingCache {
    private struct Entry {
        let context: LDContext
        let encoded: [UInt8]
    }

    private var entries: [Entry?] = [nil, nil]

    /// The encoded bytes for `context` under `redactAnonymous`, or nil if that slot does not hold it.
    func encodedContext(for context: LDContext, redactAnonymous: Bool) -> [UInt8]? {
        guard let entry = entries[ContextEncodingCache.slot(redactAnonymous)], entry.context == context
        else { return nil }

        return entry.encoded
    }

    func store(_ context: LDContext, redactAnonymous: Bool, encoded: [UInt8]) {
        entries[ContextEncodingCache.slot(redactAnonymous)] = Entry(context: context, encoded: encoded)
    }

    /// The directive is not part of the context, and so not part of `==`; the two encodings would otherwise evict each
    /// other in a single slot.
    private static func slot(_ redactAnonymous: Bool) -> Int {
        redactAnonymous ? 1 : 0
    }
}
