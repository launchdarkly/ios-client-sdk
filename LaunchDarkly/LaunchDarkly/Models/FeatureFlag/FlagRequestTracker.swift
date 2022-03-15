import Foundation

struct FlagRequestTracker {
    enum CodingKeys: String, CodingKey {
        case startDate, features
    }

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

    var dictionaryValue: [String: Any] {
        [CodingKeys.startDate.rawValue: startDate.millisSince1970,
         CodingKeys.features.rawValue: flagCounters.mapValues { $0.dictionaryValue }]
    }

    var hasLoggedRequests: Bool { !flagCounters.isEmpty }
}

extension FlagRequestTracker: TypeIdentifying { }

final class FlagCounter {
    enum CodingKeys: String, CodingKey {
        case defaultValue = "default", counters, value, variation, version, unknown, count
    }

    var defaultValue: LDValue = .null
    var flagValueCounters: [CounterKey: CounterValue] = [:]

    func trackRequest(reportedValue: LDValue, featureFlag: FeatureFlag?, defaultValue: LDValue) {
        self.defaultValue = defaultValue
        let key = CounterKey(variation: featureFlag?.variation, version: featureFlag?.versionForEvents)
        if let counter = flagValueCounters[key] {
            counter.increment()
        } else {
            flagValueCounters[key] = CounterValue(value: reportedValue)
        }
    }

    var dictionaryValue: [String: Any] {
        let counters: [[String: Any]] = flagValueCounters.map { (key, value) in
            var res: [String: Any] = [CodingKeys.value.rawValue: value.value.toAny() ?? NSNull(),
                                      CodingKeys.count.rawValue: value.count,
                                      CodingKeys.variation.rawValue: key.variation ?? NSNull()]
            if let version = key.version {
                res[CodingKeys.version.rawValue] = version
            } else {
                res[CodingKeys.unknown.rawValue] = true
            }
            return res
        }
        return [CodingKeys.defaultValue.rawValue: defaultValue.toAny() ?? NSNull(),
                CodingKeys.counters.rawValue: counters]
    }
}

struct CounterKey: Equatable, Hashable {
    let variation: Int?
    let version: Int?
}

class CounterValue {
    let value: LDValue
    var count: Int = 1

    init(value: LDValue) {
        self.value = value
    }

    func increment() {
        self.count += 1
    }
}
