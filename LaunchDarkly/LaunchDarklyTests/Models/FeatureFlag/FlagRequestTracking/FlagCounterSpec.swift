import Foundation
import XCTest

@testable import LaunchDarkly

final class FlagCounterSpec: XCTestCase {
    func testInit() {
        let flagCounter = FlagCounter()
        XCTAssertEqual(flagCounter.defaultValue, .null)
        XCTAssert(flagCounter.flagValueCounters.isEmpty)
    }

    func testTrackRequestInitialKnown() {
        let reportedValue: LDValue = "a"
        let defaultValue: LDValue = "b"
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, flagVersion: 3)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssertEqual(result.flagCounterDefaultValue, defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 1)
        let counter = counters![0]
        XCTAssertEqual(counter.valueCounterReportedValue, reportedValue)
        XCTAssertEqual(counter.valueCounterVersion, 3)
        XCTAssertEqual(counter.valueCounterVariation, 2)
        XCTAssertNil(counter.valueCounterIsUnknown)
        XCTAssertEqual(counter.valueCounterCount, 1)
    }

    func testTrackRequestKnownMatching() {
        let reportedValue: LDValue = "a"
        let defaultValue: LDValue = "b"
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 5, flagVersion: 3)
        let secondFeatureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 7, flagVersion: 3)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: secondFeatureFlag, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssertEqual(result.flagCounterDefaultValue, defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 1)
        let counter = counters![0]
        XCTAssertEqual(counter.valueCounterReportedValue, reportedValue)
        XCTAssertEqual(counter.valueCounterVersion, 3)
        XCTAssertEqual(counter.valueCounterVariation, 2)
        XCTAssertNil(counter.valueCounterIsUnknown)
        XCTAssertEqual(counter.valueCounterCount, 2)
    }

    func testTrackRequestKnownDifferentVariations() {
        let reportedValue: LDValue = "a"
        let defaultValue: LDValue = "b"
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10, flagVersion: 5)
        let secondFeatureFlag = FeatureFlag(flagKey: "test-key", variation: 3, version: 10, flagVersion: 5)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: secondFeatureFlag, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssertEqual(result.flagCounterDefaultValue, defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 2)
        let counter1 = counters!.first { $0.valueCounterVariation == 2 }!
        let counter2 = counters!.first { $0.valueCounterVariation == 3 }!
        XCTAssertEqual(counter1.valueCounterReportedValue, reportedValue)
        XCTAssertEqual(counter1.valueCounterVersion, 5)
        XCTAssertEqual(counter1.valueCounterVariation, 2)
        XCTAssertNil(counter1.valueCounterIsUnknown)
        XCTAssertEqual(counter1.valueCounterCount, 1)

        XCTAssertEqual(counter2.valueCounterReportedValue, reportedValue)
        XCTAssertEqual(counter2.valueCounterVersion, 5)
        XCTAssertEqual(counter2.valueCounterVariation, 3)
        XCTAssertNil(counter2.valueCounterIsUnknown)
        XCTAssertEqual(counter2.valueCounterCount, 1)
    }

    func testTrackRequestKnownDifferentFlagVersions() {
        let reportedValue: LDValue = "a"
        let defaultValue: LDValue = "b"
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10, flagVersion: 3)
        let secondFeatureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10, flagVersion: 5)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: secondFeatureFlag, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssertEqual(result.flagCounterDefaultValue, defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 2)
        let counter1 = counters!.first { $0.valueCounterVersion == 3 }!
        let counter2 = counters!.first { $0.valueCounterVersion == 5 }!
        XCTAssertEqual(counter1.valueCounterReportedValue, reportedValue)
        XCTAssertEqual(counter1.valueCounterVersion, 3)
        XCTAssertEqual(counter1.valueCounterVariation, 2)
        XCTAssertNil(counter1.valueCounterIsUnknown)
        XCTAssertEqual(counter1.valueCounterCount, 1)

        XCTAssertEqual(counter2.valueCounterReportedValue, reportedValue)
        XCTAssertEqual(counter2.valueCounterVersion, 5)
        XCTAssertEqual(counter2.valueCounterVariation, 2)
        XCTAssertNil(counter2.valueCounterIsUnknown)
        XCTAssertEqual(counter2.valueCounterCount, 1)
    }

    func testTrackRequestKnownMissingFlagVersionsMatchingVersions() {
        let reportedValue: LDValue = "a"
        let defaultValue: LDValue = "b"
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10)
        let secondFeatureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: secondFeatureFlag, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssertEqual(result.flagCounterDefaultValue, defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 1)
        let counter = counters![0]
        XCTAssertEqual(counter.valueCounterReportedValue, reportedValue)
        XCTAssertEqual(counter.valueCounterVersion, 10)
        XCTAssertEqual(counter.valueCounterVariation, 2)
        XCTAssertNil(counter.valueCounterIsUnknown)
        XCTAssertEqual(counter.valueCounterCount, 2)
    }

    func testTrackRequestKnownMissingFlagVersionsDifferentVersions() {
        let reportedValue: LDValue = "a"
        let defaultValue: LDValue = "b"
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 5)
        let secondFeatureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: secondFeatureFlag, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssertEqual(result.flagCounterDefaultValue, defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 2)
        let counter1 = counters!.first { $0.valueCounterVersion == 5 }!
        let counter2 = counters!.first { $0.valueCounterVersion == 10 }!
        XCTAssertEqual(counter1.valueCounterReportedValue, reportedValue)
        XCTAssertEqual(counter1.valueCounterVersion, 5)
        XCTAssertEqual(counter1.valueCounterVariation, 2)
        XCTAssertNil(counter1.valueCounterIsUnknown)
        XCTAssertEqual(counter1.valueCounterCount, 1)

        XCTAssertEqual(counter2.valueCounterReportedValue, reportedValue)
        XCTAssertEqual(counter2.valueCounterVersion, 10)
        XCTAssertEqual(counter2.valueCounterVariation, 2)
        XCTAssertNil(counter2.valueCounterIsUnknown)
        XCTAssertEqual(counter2.valueCounterCount, 1)
    }

    func testTrackRequestInitialUnknown() {
        let reportedValue: LDValue = "a"
        let defaultValue: LDValue = "b"
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: nil, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssertEqual(result.flagCounterDefaultValue, defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 1)
        let counter = counters![0]
        XCTAssertEqual(counter.valueCounterReportedValue, reportedValue)
        XCTAssertNil(counter.valueCounterVersion)
        XCTAssertNil(counter.valueCounterVariation)
        XCTAssertEqual(counter.valueCounterIsUnknown, true)
        XCTAssertEqual(counter.valueCounterCount, 1)
    }

    func testTrackRequestSecondUnknown() {
        let reportedValue: LDValue = "a"
        let defaultValue: LDValue = "b"
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: nil, defaultValue: defaultValue)
        flagCounter.trackRequest(reportedValue: reportedValue, featureFlag: nil, defaultValue: defaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssertEqual(result.flagCounterDefaultValue, defaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 1)
        let counter = counters![0]
        XCTAssertEqual(counter.valueCounterReportedValue, reportedValue)
        XCTAssertNil(counter.valueCounterVersion)
        XCTAssertNil(counter.valueCounterVariation)
        XCTAssertEqual(counter.valueCounterIsUnknown, true)
        XCTAssertEqual(counter.valueCounterCount, 2)
    }

    func testTrackRequestSecondUnknownWithDifferentValues() {
        let initialReportedValue: LDValue = "a"
        let initialDefaultValue: LDValue = "b"
        let secondReportedValue: LDValue = "c"
        let secondDefaultValue: LDValue = "d"
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: initialReportedValue, featureFlag: nil, defaultValue: initialDefaultValue)
        flagCounter.trackRequest(reportedValue: secondReportedValue, featureFlag: nil, defaultValue: secondDefaultValue)
        let result = flagCounter.dictionaryValue
        XCTAssertEqual(result.flagCounterDefaultValue, secondDefaultValue)
        let counters = result.flagCounterFlagValueCounters
        XCTAssertEqual(counters?.count, 1)
        let counter = counters![0]
        XCTAssertEqual(counter.valueCounterReportedValue, initialReportedValue)
        XCTAssertNil(counter.valueCounterVersion)
        XCTAssertNil(counter.valueCounterVariation)
        XCTAssertEqual(counter.valueCounterIsUnknown, true)
        XCTAssertEqual(counter.valueCounterCount, 2)
    }
}

extension FlagCounter {
    struct Constants {
        static let requestCount = 5
    }

    class func stub(flagKey: LDFlagKey) -> FlagCounter {
        let flagCounter = FlagCounter()
        var featureFlag: FeatureFlag? = nil
        if flagKey.isKnown {
            featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey, includeVersion: true, includeFlagVersion: true)
            for _ in 0..<Constants.requestCount {
                flagCounter.trackRequest(reportedValue: LDValue.fromAny(featureFlag?.value), featureFlag: featureFlag, defaultValue: LDValue.fromAny(featureFlag?.value))
            }
        } else {
            for _ in 0..<Constants.requestCount {
                flagCounter.trackRequest(reportedValue: false, featureFlag: nil, defaultValue: false)
            }
        }

        return flagCounter
    }
}

extension Dictionary where Key == String, Value == Any {
    fileprivate var valueCounterReportedValue: LDValue {
        LDValue.fromAny(self[FlagCounter.CodingKeys.value.rawValue])
    }
    fileprivate var valueCounterVariation: Int? {
        self[FlagCounter.CodingKeys.variation.rawValue] as? Int
    }
    fileprivate var valueCounterVersion: Int? {
        self[FlagCounter.CodingKeys.version.rawValue] as? Int
    }
    fileprivate var valueCounterIsUnknown: Bool? {
        self[FlagCounter.CodingKeys.unknown.rawValue] as? Bool
    }
    fileprivate var valueCounterCount: Int? {
        self[FlagCounter.CodingKeys.count.rawValue] as? Int
    }
    fileprivate var flagCounterDefaultValue: LDValue {
        LDValue.fromAny(self[FlagCounter.CodingKeys.defaultValue.rawValue])
    }
    fileprivate var flagCounterFlagValueCounters: [[String: Any]]? {
        self[FlagCounter.CodingKeys.counters.rawValue] as? [[String: Any]]
    }
}
