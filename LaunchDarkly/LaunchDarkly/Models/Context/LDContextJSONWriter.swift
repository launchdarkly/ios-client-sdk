import Foundation

/// Writes a context as it appears in events, producing the same JSON as `LDContext.encode(to:)` with redaction on and
/// `privateAttributes` omitted. Redaction goes through the same `maybeRedact` as the `Codable` path.
extension LDContext {
    /// `redactAnonymousAttributes` applies to every part of a multi-context.
    internal func writeJSON(into writer: JSONWriter,
                            allAttributesPrivate: Bool,
                            globalPrivateAttributes: [Reference],
                            redactAnonymousAttributes: Bool) {
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

    /// Writes the members of one context, without the enclosing braces.
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
                redaction.redactedAttributes.append(reference.canonical())
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

        if !redactedAttributes.isEmpty {
            writer.key("_meta")
            writer.beginObject()
            writer.key("redactedAttributes")
            writer.beginArray()
            for attribute in redactedAttributes {
                writer.write(attribute)
            }
            writer.endArray()
            writer.endObject()
        }

        if isAnonymous {
            writer.key("anonymous")
            writer.write(true)
        }
    }

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
