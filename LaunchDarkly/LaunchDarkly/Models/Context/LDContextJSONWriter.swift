import Foundation

/// The hand-written counterpart to `LDContext.encode(to:)`, for the encoding experiment behind `EventJSONWriter`.
///
/// The field set, the omissions, and the redaction rules are deliberately identical to the `Codable` path; where the
/// two disagree, the `Codable` path is right and this is wrong. `EventJSONWriterTests` asserts they agree.
extension LDContext {
    internal func writeJSON(into writer: JSONWriter, allAttributesPrivate: Bool, globalPrivateAttributes: [Reference]) {
        let lookup = LDContext.privateAttributeLookup(for: globalPrivateAttributes)

        writer.beginObject()
        if isMulti() {
            writer.key("kind")
            writer.write(kind.description)

            for context in contexts {
                writer.key(context.kind.description)
                writer.beginObject()
                context.writeSingleContext(into: writer,
                                           discardKind: true,
                                           allAttributesPrivate: allAttributesPrivate,
                                           globalPrivateAttributes: lookup,
                                           redactAnonymousAttributes: redactAnonymousAttributes)
                writer.endObject()
            }
        } else {
            writeSingleContext(into: writer,
                               discardKind: false,
                               allAttributesPrivate: allAttributesPrivate,
                               globalPrivateAttributes: lookup,
                               redactAnonymousAttributes: redactAnonymousAttributes)
        }
        writer.endObject()
    }

    /// Writes the members of one context, without the enclosing braces, mirroring `encodeSingleContext`.
    private func writeSingleContext(into writer: JSONWriter,
                                    discardKind: Bool,
                                    allAttributesPrivate: Bool,
                                    globalPrivateAttributes: SharedDictionary<String, PrivateAttributeLookupNode>,
                                    redactAnonymousAttributes: Bool) {
        if !discardKind {
            writer.key("kind")
            writer.write(kind.description)
        }

        if let key = writableKey {
            writer.key("key")
            writer.write(key)
        }

        var redaction = Redaction(globalPrivateAttributes: globalPrivateAttributes)
        let redactAll = allAttributesPrivate || (isAnonymous && redactAnonymousAttributes)

        for name in getOptionalAttributeNames() {
            let reference = Reference(name)
            guard let value = getValue(reference)
            else { continue }

            if redactAll {
                redaction.redactedAttributes.append(reference.raw())
                continue
            }

            var path: [String] = []
            path.reserveCapacity(10)
            writeFilteredAttribute(into: writer,
                                   parentPath: path,
                                   key: name,
                                   value: value,
                                   redaction: &redaction)
        }
        let redactedAttributes = redaction.redactedAttributes

        // Matches `Meta.isEmpty` and `Meta.encode`: `_meta` is written whenever either list is non-empty, but
        // `privateAttributes` is only included when the caller asked for it, which the event path never does. A context
        // with private attributes and nothing redacted therefore writes an empty `_meta`, as it does today.
        if !privateAttributes.isEmpty || !redactedAttributes.isEmpty {
            writer.key("_meta")
            writer.beginObject()
            if !redactedAttributes.isEmpty {
                writer.key("redactedAttributes")
                writer.beginArray()
                for attribute in redactedAttributes {
                    writer.write(attribute)
                }
                writer.endArray()
            }
            writer.endObject()
        }

        if isAnonymous {
            writer.key("anonymous")
            writer.write(true)
        }
    }

    /// What the attribute walk accumulates, grouped so the recursion carries one value rather than two.
    private struct Redaction {
        let globalPrivateAttributes: SharedDictionary<String, PrivateAttributeLookupNode>
        var redactedAttributes: [String] = []

        init(globalPrivateAttributes: SharedDictionary<String, PrivateAttributeLookupNode>) {
            self.globalPrivateAttributes = globalPrivateAttributes
            self.redactedAttributes.reserveCapacity(20)
        }
    }

    private func writeFilteredAttribute(into writer: JSONWriter,
                                        parentPath: [String],
                                        key: String,
                                        value: LDValue,
                                        redaction: inout Redaction) {
        var path = parentPath
        path.append(key.description)

        let lookup = redaction.globalPrivateAttributes
        let (isRedacted, nestedPropertiesAreRedacted) = redactionDecision(
            parentPath: path,
            value: value,
            redactedAttributes: &redaction.redactedAttributes,
            globalPrivateAttributes: lookup)

        switch value {
        case .object where isRedacted:
            break
        case .object(let objectMap):
            if !nestedPropertiesAreRedacted {
                writer.key(key)
                writer.write(value)
                return
            }

            writer.key(key)
            writer.beginObject()
            for (nestedKey, nestedValue) in objectMap {
                writeFilteredAttribute(into: writer,
                                       parentPath: path,
                                       key: nestedKey,
                                       value: nestedValue,
                                       redaction: &redaction)
            }
            writer.endObject()
        case _ where !isRedacted:
            writer.key(key)
            writer.write(value)
        default:
            break
        }
    }
}
