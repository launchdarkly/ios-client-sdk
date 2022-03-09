import Foundation
import XCTest

@testable import LaunchDarkly

final class FlagCounterSpec: XCTestCase {
    func testInit() {
        let flagCounter = FlagCounter()
        XCTAssertNil(flagCounter.defaultValue)
        XCTAssert(flagCounter.flagValueCounters.isEmpty)
    }

    func testTrackRequestInitialKnown() {
        let reportedValue = Placeholder()
        let defaultValue = Placeholder()
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, flagVersion: 3)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssert(result.flagCounterDefaultValue as! Placeholder === defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 1)
        let counter = counters![0]
        XCTAssert(counter.valueCounterReportedValue as! Placeholder === reportedValue)
        XCTAssertEqual(counter.valueCounterVersion, 3)
        XCTAssertEqual(counter.valueCounterVariation, 2)
        XCTAssertNil(counter.valueCounterIsUnknown)
        XCTAssertEqual(counter.valueCounterCount, 1)
    }

    func testTrackRequestKnownMatching() {
        let reportedValue = Placeholder()
        let defaultValue = Placeholder()
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 5, flagVersion: 3)
        let secondFeatureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 7, flagVersion: 3)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: secondFeatureFlag, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssert(result.flagCounterDefaultValue as! Placeholder === defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 1)
        let counter = counters![0]
        XCTAssert(counter.valueCounterReportedValue as! Placeholder === reportedValue)
        XCTAssertEqual(counter.valueCounterVersion, 3)
        XCTAssertEqual(counter.valueCounterVariation, 2)
        XCTAssertNil(counter.valueCounterIsUnknown)
        XCTAssertEqual(counter.valueCounterCount, 2)
    }

    func testTrackRequestKnownDifferentVariations() {
        let reportedValue = Placeholder()
        let defaultValue = Placeholder()
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10, flagVersion: 5)
        let secondFeatureFlag = FeatureFlag(flagKey: "test-key", variation: 3, version: 10, flagVersion: 5)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: secondFeatureFlag, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssert(result.flagCounterDefaultValue as! Placeholder === defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 2)
        let counter1 = counters!.first { $0.valueCounterVariation == 2 }!
        let counter2 = counters!.first { $0.valueCounterVariation == 3 }!
        XCTAssert(counter1.valueCounterReportedValue as! Placeholder === reportedValue)
        XCTAssertEqual(counter1.valueCounterVersion, 5)
        XCTAssertEqual(counter1.valueCounterVariation, 2)
        XCTAssertNil(counter1.valueCounterIsUnknown)
        XCTAssertEqual(counter1.valueCounterCount, 1)

        XCTAssert(counter2.valueCounterReportedValue as! Placeholder === reportedValue)
        XCTAssertEqual(counter2.valueCounterVersion, 5)
        XCTAssertEqual(counter2.valueCounterVariation, 3)
        XCTAssertNil(counter2.valueCounterIsUnknown)
        XCTAssertEqual(counter2.valueCounterCount, 1)
    }

    func testTrackRequestKnownDifferentFlagVersions() {
        let reportedValue = Placeholder()
        let defaultValue = Placeholder()
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10, flagVersion: 3)
        let secondFeatureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10, flagVersion: 5)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: secondFeatureFlag, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssert(result.flagCounterDefaultValue as! Placeholder === defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 2)
        let counter1 = counters!.first { $0.valueCounterVersion == 3 }!
        let counter2 = counters!.first { $0.valueCounterVersion == 5 }!
        XCTAssert(counter1.valueCounterReportedValue as! Placeholder === reportedValue)
        XCTAssertEqual(counter1.valueCounterVersion, 3)
        XCTAssertEqual(counter1.valueCounterVariation, 2)
        XCTAssertNil(counter1.valueCounterIsUnknown)
        XCTAssertEqual(counter1.valueCounterCount, 1)

        XCTAssert(counter2.valueCounterReportedValue as! Placeholder === reportedValue)
        XCTAssertEqual(counter2.valueCounterVersion, 5)
        XCTAssertEqual(counter2.valueCounterVariation, 2)
        XCTAssertNil(counter2.valueCounterIsUnknown)
        XCTAssertEqual(counter2.valueCounterCount, 1)
    }

    func testTrackRequestKnownMissingFlagVersionsMatchingVersions() {
        let reportedValue = Placeholder()
        let defaultValue = Placeholder()
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10)
        let secondFeatureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: secondFeatureFlag, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssert(result.flagCounterDefaultValue as! Placeholder === defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 1)
        let counter = counters![0]
        XCTAssert(counter.valueCounterReportedValue as! Placeholder === reportedValue)
        XCTAssertEqual(counter.valueCounterVersion, 10)
        XCTAssertEqual(counter.valueCounterVariation, 2)
        XCTAssertNil(counter.valueCounterIsUnknown)
        XCTAssertEqual(counter.valueCounterCount, 2)
    }

    func testTrackRequestKnownMissingFlagVersionsDifferentVersions() {
        let reportedValue = Placeholder()
        let defaultValue = Placeholder()
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 5)
        let secondFeatureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: secondFeatureFlag, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssert(result.flagCounterDefaultValue as! Placeholder === defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 2)
        let counter1 = counters!.first { $0.valueCounterVersion == 5 }!
        let counter2 = counters!.first { $0.valueCounterVersion == 10 }!
        XCTAssert(counter1.valueCounterReportedValue as! Placeholder === reportedValue)
        XCTAssertEqual(counter1.valueCounterVersion, 5)
        XCTAssertEqual(counter1.valueCounterVariation, 2)
        XCTAssertNil(counter1.valueCounterIsUnknown)
        XCTAssertEqual(counter1.valueCounterCount, 1)

        XCTAssert(counter2.valueCounterReportedValue as! Placeholder === reportedValue)
        XCTAssertEqual(counter2.valueCounterVersion, 10)
        XCTAssertEqual(counter2.valueCounterVariation, 2)
        XCTAssertNil(counter2.valueCounterIsUnknown)
        XCTAssertEqual(counter2.valueCounterCount, 1)
    }

    func testTrackRequestInitialUnknown() {
        let reportedValue = Placeholder()
        let defaultValue = Placeholder()
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: nil, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssert(result.flagCounterDefaultValue as! Placeholder === defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 1)
        let counter = counters![0]
        XCTAssert(counter.valueCounterReportedValue as! Placeholder === reportedValue)
        XCTAssertNil(counter.valueCounterVersion)
        XCTAssertNil(counter.valueCounterVariation)
        XCTAssertEqual(counter.valueCounterIsUnknown, true)
        XCTAssertEqual(counter.valueCounterCount, 1)
    }

    func testTrackRequestSecondUnknown() {
        let reportedValue = Placeholder()
        let defaultValue = Placeholder()
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: nil, defaultValue: defaultValue)
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: nil, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssert(result.flagCounterDefaultValue as! Placeholder === defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 1)
        let counter = counters![0]
        XCTAssert(counter.valueCounterReportedValue as! Placeholder === reportedValue)
        XCTAssertNil(counter.valueCounterVersion)
        XCTAssertNil(counter.valueCounterVariation)
        XCTAssertEqual(counter.valueCounterIsUnknown, true)
        XCTAssertEqual(counter.valueCounterCount, 2)
    }

    func testTrackRequestSecondUnknownWithDifferentValues() {
        let initialReportedValue = Placeholder()
        let initialDefaultValue = Placeholder()
        let secondReportedValue = Placeholder()
        let secondDefaultValue = Placeholder()
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: initialReportedValue, featureFlag: nil, defaultValue: initialDefaultValue)
        flagCounter.trackRequest(reportedValue: secondReportedValue, featureFlag: nil, defaultValue: secondDefaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssert(result.flagCounterDefaultValue as! Placeholder === secondDefaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 1)
        let counter = counters![0]
        XCTAssert(counter.valueCounterReportedValue as! Placeholder === initialReportedValue)
        XCTAssertNil(counter.valueCounterVersion)
        XCTAssertNil(counter.valueCounterVariation)
        XCTAssertEqual(counter.valueCounterIsUnknown, true)
        XCTAssertEqual(counter.valueCounterCount, 2)
    }
}

private class Placeholder { }

extension FlagCounter {
    struct Constants {
        static let requestCount = 5
    }

    class func stub(flagKey: LDFlagKey, includeVersion: Bool = true, includeFlagVersion: Bool = true) -> FlagCounter {
        let flagCounter = FlagCounter()
        var featureFlag: FeatureFlag? = nil
        if flagKey.isKnown {
            featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey, includeVersion: includeVersion, includeFlagVersion: includeFlagVersion)
            for _ in 0..<Constants.requestCount {
                flagCounter.trackRequest(reportedValue: featureFlag?.value, featureFlag: featureFlag, defaultValue: featureFlag?.value)
            }
        } else {
            for _ in 0..<Constants.requestCount {
                flagCounter.trackRequest(reportedValue: false, featureFlag: nil, defaultValue: false)
            }
        }

        return flagCounter
    }
}

extension CounterValue: Equatable {
    public static func == (lhs: CounterValue, rhs: CounterValue) -> Bool {
        AnyComparer.isEqual(lhs.value, to: rhs.value) && lhs.count == rhs.count
    }
}

extension FlagCounter: Equatable {
    public static func == (lhs: FlagCounter, rhs: FlagCounter) -> Bool {
        AnyComparer.isEqual(lhs.defaultValue, to: rhs.defaultValue, considerNilAndNullEqual: true) &&
            lhs.flagValueCounters == rhs.flagValueCounters
    }
}

extension Dictionary where Key == String, Value == Any {
    var valueCounterReportedValue: Any? {
        self[FlagCounter.CodingKeys.value.rawValue]
    }
    var valueCounterVariation: Int? {
        self[FlagCounter.CodingKeys.variation.rawValue] as? Int
    }
    var valueCounterVersion: Int? {
        self[FlagCounter.CodingKeys.version.rawValue] as? Int
    }
    var valueCounterIsUnknown: Bool? {
        self[FlagCounter.CodingKeys.unknown.rawValue] as? Bool
    }
    var valueCounterCount: Int? {
        self[FlagCounter.CodingKeys.count.rawValue] as? Int
    }
    var flagCounterDefaultValue: Any? {
        self[FlagCounter.CodingKeys.defaultValue.rawValue]
    }
    var flagCounterFlagValueCounters: [[String: Any]]? {
        self[FlagCounter.CodingKeys.counters.rawValue] as? [[String: Any]]
    }
}
