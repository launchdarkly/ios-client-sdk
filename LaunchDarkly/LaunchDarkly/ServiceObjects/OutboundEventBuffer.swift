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

    /// For building the writer an oversized summary is measured with.
    private let config: LDConfig

    init(config: LDConfig, encoding: Encoding) {
        self.encoding = encoding
        self.config = config
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

    /// How many times the writer events go through encoded a context rather than reusing its last encoding.
    var contextEncodingCount: Int { eventJSONWriter.contextEncodingCount }

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
    ///
    /// A summary larger than one log frame holds is split between summaries of the same context and period, each with
    /// as many of its flags as fit beside the context. Whole, it would be refused by the store and every evaluation in
    /// it lost. Only a single flag too large to fit beside the context, and a summary whose context alone takes a frame,
    /// are left whole, for the store to refuse.
    ///
    /// - Returns: at least one summary, nil for each part that could not be encoded.
    func encodeSummary(_ summary: (tracker: FlagRequestTracker, context: LDContext)) -> [Data?] {
        let tracker = summary.tracker
        let context = summary.context
        let endDate = Date()
        let encoded = encode(SummaryEvent(flagRequestTracker: tracker, context: context, endDate: endDate))
        guard let size = encoded?.count, size > EventLogFormat.maxFrameSize, tracker.flagCounters.count > 1
        else { return [encoded] }
        let parts = packIntoFrames(tracker, flagKeys: tracker.flagCounters.keys.sorted(), endDate: endDate, size: size)
        guard parts.count > 1
        else { return [encoded] }
        return parts.flatMap { flagKeys -> [Data?] in
            let part = tracker.withFlags(flagKeys)
            return halveUntilFits(part, encode(SummaryEvent(flagRequestTracker: part, context: context, endDate: endDate)),
                                  context: context, endDate: endDate)
        }
    }

    private static let standInContext = try? LDContextBuilder(key: "k").build().get()

    /// Splits an oversized summary's flags into runs, in key order, that each fit a frame beside the context. Every
    /// part carries the whole context, so how much room a part has for flags is a frame less the context. What each
    /// flag takes is measured with a small stand-in for the context, which costs one small encoding per flag rather than
    /// one of the context per part, and what is left of the whole summary is what every part repeats. Where the context
    /// alone takes a frame, nothing fits, so the summary is one part, refused whole as one loss rather than one per flag.
    ///
    /// The stand-in goes through a writer of its own, which leaves the context's encoding in the cache of the writer
    /// the parts go through, so that no part encodes the context again.
    ///
    /// - Parameters:
    ///   - flagKeys: the summary's flags, sorted, at least two.
    ///   - size: the whole summary's encoded size.
    /// - Returns: the flags of each part.
    private func packIntoFrames(_ tracker: FlagRequestTracker, flagKeys: [LDFlagKey], endDate: Date, size: Int) -> [ArraySlice<LDFlagKey>] {
        let whole = [flagKeys[...]]
        guard let standIn = OutboundEventBuffer.standInContext
        else { return whole }
        let standInWriter = encoding == .handWritten ? EventJSONWriter(config: config) : nil
        func standInSize(_ keys: ArraySlice<LDFlagKey>) -> Int? {
            let event = SummaryEvent(flagRequestTracker: tracker.withFlags(keys), context: standIn, endDate: endDate)
            return (standInWriter.map { $0.encode(event) } ?? encode(event))?.count
        }
        var flagSizes: [Int] = []
        flagSizes.reserveCapacity(flagKeys.count)
        for index in flagKeys.indices {
            guard let single = standInSize(flagKeys[index...index])
            else { return whole }
            flagSizes.append(single)
        }
        // Two flags measured alone and together give what a part of the stand-in repeats, less the separator a flag
        // adds beside another, so that what a part takes is that plus the sum of its flags' sizes.
        guard let pair = standInSize(flagKeys[0...1])
        else { return whole }
        let standInRepeated = flagSizes[0] + flagSizes[1] - pair
        flagSizes = flagSizes.map { $0 - standInRepeated }
        let room = EventLogFormat.maxFrameSize - (size - flagSizes.reduce(0, +))
        guard room > 0
        else { return whole }

        var parts: [ArraySlice<LDFlagKey>] = []
        var start = 0
        var used = 0
        for (index, flagSize) in flagSizes.enumerated() {
            if index > start && used + flagSize > room {
                parts.append(flagKeys[start..<index])
                start = index
                used = 0
            }
            used += flagSize
        }
        parts.append(flagKeys[start...])
        return parts
    }

    /// Halves a packed part that came out larger than measured until each half fits, which only a part whose context
    /// fits a frame reaches, so the halving ends. A single flag too large beside the context is left whole, for the
    /// store to refuse.
    private func halveUntilFits(_ tracker: FlagRequestTracker, _ encoded: Data?, context: LDContext, endDate: Date) -> [Data?] {
        guard let size = encoded?.count, size > EventLogFormat.maxFrameSize, let halves = tracker.halved()
        else { return [encoded] }
        return [halves.0, halves.1].flatMap { half -> [Data?] in
            halveUntilFits(half, encode(SummaryEvent(flagRequestTracker: half, context: context, endDate: endDate)),
                           context: context, endDate: endDate)
        }
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
