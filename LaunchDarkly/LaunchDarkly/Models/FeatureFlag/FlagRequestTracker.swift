import Foundation

struct FlagRequestTracker {
    let startDate = Date()
    var flagCounters: [LDFlagKey: FlagCounter] = [:]

    mutating func trackRequest(flagKey: LDFlagKey, reportedValue: LDValue, featureFlag: FeatureFlag?, defaultValue: LDValue) {
        if flagCounters[flagKey] == nil {
            flagCounters[flagKey] = FlagCounter()
        }
        guard let flagCounter = flagCounters[flagKey]
        else { return }
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)

        Log.debug(typeName(and: #function) + "\n\tflagKey: \(flagKey)"
            + "\n\treportedValue: \(reportedValue), "
            + "\n\tvariation: \(String(describing: featureFlag?.variation)), "
            + "\n\tversion: \(String(describing: featureFlag?.flagVersion ?? featureFlag?.version)), "
            + "\n\tdefaultValue: \(defaultValue)\n")
    }

    var hasLoggedRequests: Bool { !flagCounters.isEmpty }
}

extension FlagRequestTracker: TypeIdentifying { }

final class FlagCounter: Encodable {
    enum CodingKeys: String, CodingKey {
        case defaultValue = "default", counters
    }

    enum CounterCodingKeys: String, CodingKey {
        case value, variation, version, unknown, count
    }

    private(set) var defaultValue: LDValue = .null
    private(set) var flagValueCounters: [CounterKey: CounterValue] = [:]

    func trackRequest(reportedValue: LDValue, featureFlag: FeatureFlag?, defaultValue: LDValue) {
        self.defaultValue = defaultValue
        let key = CounterKey(variation: featureFlag?.variation, version: featureFlag?.versionForEvents)
        if let counter = flagValueCounters[key] {
            counter.increment()
        } else {
            flagValueCounters[key] = CounterValue(value: reportedValue)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultValue, forKey: .defaultValue)
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
