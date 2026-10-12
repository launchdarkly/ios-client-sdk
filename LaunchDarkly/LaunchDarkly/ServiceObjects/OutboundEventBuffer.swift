import Foundation
import OSLog

/// Turns what `DirectEventProcessor` records into what it stages: evaluations into summary counters, and events into the
/// JSON the events endpoint accepts. Android's `OutboundEventBuffer` plays the same part.
///
/// It has no lock of its own. The summarizer is only to be used while holding the processor's `recordLock`, and the
/// encoders are only reached under its `commitLock`.
final class OutboundEventBuffer {
    /// Which encoder recorded events go through.
    ///
    /// `.codable` is the reference `.handWritten` is tested against. The two produce equal JSON but not identical
    /// bytes: key order differs, as do `/` against `\/` and `0` against `-0`.
    enum Encoding {
        case codable
        case handWritten
    }

    let encoding: Encoding
    private let logger: OSLog

    /// Only to be used while holding the processor's `recordLock`.
    private(set) var contextSummarizer: ContextSummarizer

    /// Only to be used while holding the processor's `commitLock`.
    private let encoder: JSONEncoder

    /// Outlives a commit rather than being built per commit, so that its buffer and context cache span them.
    ///
    /// A commit point writes a single event, so a cache that lived for one commit would never be read. It needs no
    /// lock of its own because it is only ever reached from `encode(_:)`, which runs under the processor's
    /// `commitLock`.
    private let eventJSONWriter: EventJSONWriter

    init(config: LDConfig, encoding: Encoding) {
        self.encoding = encoding
        self.logger = config.logger
        self.contextSummarizer = ContextSummarizer(logger: config.logger, maxContexts: config.eventCapacity)
        self.encoder = OutboundEventBuffer.makeEncoder(config: config)
        self.eventJSONWriter = EventJSONWriter(config: config)
    }

    /// Counts an evaluation into its context's summary. Requires the processor's `recordLock`.
    ///
    /// - Returns: false if the evaluation was not counted, because its context is not counted yet and as many contexts
    ///   as the summarizer allows already are.
    func summarize(flagKey: LDFlagKey,
                   reportedValue: LDValue,
                   featureFlag: FeatureFlag?,
                   defaultValue: LDValue,
                   context: LDContext) -> Bool {
        contextSummarizer.trackRequest(flagKey: flagKey, reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue, context: context)
    }

    /// Takes the counters gathered so far, leaving the summarizer empty, or nothing if nothing was counted. Requires the
    /// processor's `recordLock`.
    func takeSummaries() -> [(tracker: FlagRequestTracker, context: LDContext)] {
        let summaries = contextSummarizer.hasLoggedRequests ? contextSummarizer.getSummaries() : []
        if !summaries.isEmpty {
            contextSummarizer.clear()
        }
        return summaries
    }

    /// Requires the processor's `commitLock`.
    func encode(_ event: Event) -> Data? {
        let encoded: Data? = encoding == .codable ? try? encoder.encode(event) : eventJSONWriter.encode(event)
        guard let encoded = encoded
        else {
            os_log("%s Failed to serialize event for publication: %s", log: logger, type: .error, typeName(and: #function), String(describing: event))
            return nil
        }
        return encoded
    }

    /// Encodes the summary of one context's counters. Requires the processor's `commitLock`.
    func encodeSummary(_ summary: (tracker: FlagRequestTracker, context: LDContext)) -> Data? {
        encode(SummaryEvent(flagRequestTracker: summary.tracker, context: summary.context))
    }

    private static func makeEncoder(config: LDConfig) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.userInfo = [
            LDContext.UserInfoKeys.allAttributesPrivate: config.allContextAttributesPrivate,
            LDContext.UserInfoKeys.globalPrivateAttributes: config.privateContextAttributes.map { $0 }
        ]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.millisSince1970)
        }
        return encoder
    }
}

extension OutboundEventBuffer: TypeIdentifying { }
