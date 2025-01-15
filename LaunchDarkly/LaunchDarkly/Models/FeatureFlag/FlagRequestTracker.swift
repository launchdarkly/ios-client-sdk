import Foundation
import OSLog

struct FlagRequestTracker {
    let startDate = Date()
    var flagCounters: [LDFlagKey: FlagCounter] = [:]
    let logger: OSLog

    init(logger: OSLog) {
        self.logger = logger
    }

    mutating func trackRequest(flagKey: LDFlagKey, reportedValue: LDValue, featureFlag: FeatureFlag?, defaultValue: LDValue, context: LDContext) {
        if flagCounters[flagKey] == nil {
            flagCounters[flagKey] = FlagCounter(defaultValue: defaultValue)
        }
        guard let flagCounter = flagCounters[flagKey]
        else { return }
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: featureFlag, context: context)

        os_log("%s \n\tflagKey: %s\n\tvariation: %s\n\tversion: %s", log: logger, type: .debug,
            typeName(and: #function),
            flagKey,
            String(describing: featureFlag?.variation),
            String(describing: featureFlag?.flagVersion ?? featureFlag?.version))
    }

    var hasLoggedRequests: Bool { !flagCounters.isEmpty }
}

extension FlagRequestTracker: TypeIdentifying { }

final class FlagCounter: Encodable {
    enum CodingKeys: String, CodingKey {
        case defaultValue = "default", counters, contextKinds
    }

    enum CounterCodingKeys: String, CodingKey {
        case value, variation, version, unknown, count
    }

    private(set) var defaultValue: LDValue
    private(set) var flagValueCounters: [CounterKey: CounterValue] = [:]
    private(set) var contextKinds: Set<String> = Set()

    init(defaultValue: LDValue) {
        // default value follows a "first one wins" approach where the first evaluation for a flag key sets the default value for the summary events
        self.defaultValue = defaultValue
    }

    func trackRequest(reportedValue: LDValue, featureFlag: FeatureFlag?, context: LDContext) {
        let key = CounterKey(variation: featureFlag?.variation, version: featureFlag?.versionForEvents)
        if let counter = flagValueCounters[key] {
            counter.increment()
        } else {
            flagValueCounters[key] = CounterValue(value: reportedValue)
        }

        context.contextKeys().forEach { kind, _ in
            contextKinds.insert(kind)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if defaultValue != .null {
            try container.encode(defaultValue, forKey: .defaultValue)
        }
        try container.encode(contextKinds, forKey: .contextKinds)
        var countersContainer = container.nestedUnkeyedContainer(forKey: .counters)
        try flagValueCounters.forEach { (key, value) in
            var counterContainer = countersContainer.nestedContainer(keyedBy: CounterCodingKeys.self)
            try counterContainer.encodeIfPresent(key.version, forKey: .version)
            try counterContainer.encodeIfPresent(key.variation, forKey: .variation)
            try counterContainer.encode(value.count, forKey: .count)
            try counterContainer.encode(value.value, forKey: .value)
            if key.version == nil {
                try counterContainer.encode(true, forKey: .unknown)
            }
        }
    }
}

struct CounterKey: Equatable, Hashable {
    let variation: Int?
    let version: Int?
}

class CounterValue {
    let value: LDValue
    private(set) var count: Int = 1

    init(value: LDValue) {
        self.value = value
    }

    func increment() {
        self.count += 1
    }
}
