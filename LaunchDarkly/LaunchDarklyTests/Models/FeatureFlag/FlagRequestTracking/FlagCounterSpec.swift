import Foundation
import XCTest

@testable import LaunchDarkly

final class FlagCounterSpec: XCTestCase {
    private let testDefaultValue: LDValue = "d"
    private let testValue: LDValue = 5.5

    func testInit() {
        let flagCounter = FlagCounter()
        XCTAssertEqual(flagCounter.defaultValue, .null)
        XCTAssert(flagCounter.flagValueCounters.isEmpty)
    }

    func testTrackRequestInitialKnown() {
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 2, flagVersion: 3)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: testValue, featureFlag: featureFlag, defaultValue: testDefaultValue, context: LDContext.stub())
        XCTAssertEqual(flagCounter.defaultValue, testDefaultValue)
        XCTAssertEqual(flagCounter.flagValueCounters.count, 1)
        let counter = flagCounter.flagValueCounters.first!
        XCTAssertEqual(counter.key.version, 3)
        XCTAssertEqual(counter.key.variation, 2)
        XCTAssertEqual(counter.value.value, testValue)
        XCTAssertEqual(counter.value.count, 1)
    }

    func testTrackRequestKnownMatching() {
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 5, flagVersion: 3)
        let secondFeatureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 7, flagVersion: 3)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: testValue, featureFlag: featureFlag, defaultValue: "e", context: LDContext.stub())
        flagCounter.trackRequest(reportedValue: "b", featureFlag: secondFeatureFlag, defaultValue: testDefaultValue, context: LDContext.stub())
        XCTAssertEqual(flagCounter.defaultValue, testDefaultValue)
        XCTAssertEqual(flagCounter.flagValueCounters.count, 1)
        let counter = flagCounter.flagValueCounters.first!
        XCTAssertEqual(counter.key.version, 3)
        XCTAssertEqual(counter.key.variation, 2)
        XCTAssertEqual(counter.value.value, testValue)
        XCTAssertEqual(counter.value.count, 2)
    }

    func testTrackRequestKnownDifferentVariations() {
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10, flagVersion: 5)
        let secondFeatureFlag = FeatureFlag(flagKey: "test-key", variation: 3, version: 10, flagVersion: 5)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: testValue, featureFlag: featureFlag, defaultValue: testDefaultValue, context: LDContext.stub())
        flagCounter.trackRequest(reportedValue: testValue, featureFlag: secondFeatureFlag, defaultValue: testDefaultValue, context: LDContext.stub())
        XCTAssertEqual(flagCounter.defaultValue, testDefaultValue)
        XCTAssertEqual(flagCounter.flagValueCounters.count, 2)
        let counter1 = flagCounter.flagValueCounters.first { key, _ in key.variation == 2 }!
        XCTAssertEqual(counter1.key.version, 5)
        XCTAssertEqual(counter1.value.value, testValue)
        XCTAssertEqual(counter1.value.count, 1)
        let counter2 = flagCounter.flagValueCounters.first { key, _ in key.variation == 3 }!
        XCTAssertEqual(counter2.key.version, 5)
        XCTAssertEqual(counter2.value.value, testValue)
        XCTAssertEqual(counter2.value.count, 1)
    }

    func testTrackRequestKnownDifferentFlagVersions() {
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10, flagVersion: 3)
        let secondFeatureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10, flagVersion: 5)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: testValue, featureFlag: featureFlag, defaultValue: testDefaultValue, context: LDContext.stub())
        flagCounter.trackRequest(reportedValue: testValue, featureFlag: secondFeatureFlag, defaultValue: testDefaultValue, context: LDContext.stub())
        XCTAssertEqual(flagCounter.defaultValue, testDefaultValue)
        XCTAssertEqual(flagCounter.flagValueCounters.count, 2)
        let counter1 = flagCounter.flagValueCounters.first { key, _ in key.version == 3 }!
        XCTAssertEqual(counter1.key.variation, 2)
        XCTAssertEqual(counter1.value.value, testValue)
        XCTAssertEqual(counter1.value.count, 1)
        let counter2 = flagCounter.flagValueCounters.first { key, _ in key.version == 5 }!
        XCTAssertEqual(counter2.key.variation, 2)
        XCTAssertEqual(counter2.value.value, testValue)
        XCTAssertEqual(counter2.value.count, 1)
    }

    func testTrackRequestKnownMissingFlagVersionMatchingVersions() {
        let featureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 10)
        let secondFeatureFlag = FeatureFlag(flagKey: "test-key", variation: 2, version: 5, flagVersion: 10)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: testValue, featureFlag: featureFlag, defaultValue: testDefaultValue, context: LDContext.stub())
        flagCounter.trackRequest(reportedValue: testValue, featureFlag: secondFeatureFlag, defaultValue: testDefaultValue, context: LDContext.stub())
        XCTAssertEqual(flagCounter.defaultValue, testDefaultValue)
        XCTAssertEqual(flagCounter.flagValueCounters.count, 1)
        let counter = flagCounter.flagValueCounters.first!
        XCTAssertEqual(counter.key.version, 10)
        XCTAssertEqual(counter.key.variation, 2)
        XCTAssertEqual(counter.value.value, testValue)
        XCTAssertEqual(counter.value.count, 2)
    }

    func testTrackRequestInitialUnknown() {
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: testValue, featureFlag: nil, defaultValue: testDefaultValue, context: LDContext.stub())
        XCTAssertEqual(flagCounter.defaultValue, testDefaultValue)
        XCTAssertEqual(flagCounter.flagValueCounters.count, 1)
        let counter = flagCounter.flagValueCounters.first!
        XCTAssertNil(counter.key.version)
        XCTAssertNil(counter.key.variation)
        XCTAssertEqual(counter.value.value, testValue)
        XCTAssertEqual(counter.value.count, 1)
    }

    func testTrackRequestSecondUnknown() {
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: testValue, featureFlag: nil, defaultValue: testDefaultValue, context: LDContext.stub())
        flagCounter.trackRequest(reportedValue: testValue, featureFlag: nil, defaultValue: testDefaultValue, context: LDContext.stub())
        XCTAssertEqual(flagCounter.defaultValue, testDefaultValue)
        XCTAssertEqual(flagCounter.flagValueCounters.count, 1)
        let counter = flagCounter.flagValueCounters.first!
        XCTAssertNil(counter.key.version)
        XCTAssertNil(counter.key.variation)
        XCTAssertEqual(counter.value.value, testValue)
        XCTAssertEqual(counter.value.count, 2)
    }

    func testTrackRequestSecondUnknownWithDifferentVariations() {
        let unknownFlag1 = FeatureFlag(flagKey: "unused", variation: 1)
        let unknownFlag2 = FeatureFlag(flagKey: "unused", variation: 2)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: testValue, featureFlag: unknownFlag1, defaultValue: testDefaultValue, context: LDContext.stub())
        flagCounter.trackRequest(reportedValue: testValue, featureFlag: unknownFlag2, defaultValue: testDefaultValue, context: LDContext.stub())
        XCTAssertEqual(flagCounter.defaultValue, testDefaultValue)
        XCTAssertEqual(flagCounter.flagValueCounters.count, 2)
        let counter1 = flagCounter.flagValueCounters.first { key, _ in key.variation == 1 }!
        XCTAssertNil(counter1.key.version)
        XCTAssertEqual(counter1.key.variation, 1)
        XCTAssertEqual(counter1.value.value, testValue)
        XCTAssertEqual(counter1.value.count, 1)
        let counter2 = flagCounter.flagValueCounters.first { key, _ in key.variation == 2 }!
        XCTAssertNil(counter2.key.version)
        XCTAssertEqual(counter2.key.variation, 2)
        XCTAssertEqual(counter2.value.value, testValue)
        XCTAssertEqual(counter2.value.count, 1)
    }

    func testEncoding() {
        let featureFlag = FeatureFlag(flagKey: "unused", variation: 3, version: 2, flagVersion: 5)
        let flagCounter = FlagCounter()
        flagCounter.trackRequest(reportedValue: "a", featureFlag: featureFlag, defaultValue: "b", context: LDContext.stub())
        flagCounter.trackRequest(reportedValue: "a", featureFlag: featureFlag, defaultValue: "b", context: LDContext.stub())
        encodesToObject(flagCounter) { dict in
            XCTAssertEqual(dict.count, 3)
            XCTAssertEqual(dict["default"], "b")
            XCTAssertEqual(dict["contextKinds"], ["user"])
            valueIsArray(dict["counters"]) { counters in
                XCTAssertEqual(counters.count, 1)
                valueIsObject(counters[0]) { counter in
                    XCTAssertEqual(counter.count, 4)
                    XCTAssertEqual(counter["value"], "a")
                    XCTAssertEqual(counter["count"], 2)
                    XCTAssertEqual(counter["version"], 5)
                    XCTAssertEqual(counter["variation"], 3)
                }
            }
        }

        let flagCounterNulls = FlagCounter()
        flagCounterNulls.trackRequest(reportedValue: nil, featureFlag: nil, defaultValue: nil, context: LDContext.stub())
        encodesToObject(flagCounterNulls) { dict in
            XCTAssertEqual(dict.count, 3)
            XCTAssertEqual(dict["default"], .null)
            XCTAssertEqual(dict["contextKinds"], ["user"])
            valueIsArray(dict["counters"]) { counters in
                XCTAssertEqual(counters.count, 1)
                valueIsObject(counters[0]) { counter in
                    XCTAssertEqual(counter.count, 3)
                    XCTAssertEqual(counter["value"], .null)
                    XCTAssertEqual(counter["count"], 1)
                    XCTAssertEqual(counter["unknown"], true)
                }
            }
        }
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
            featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey)
            for _ in 0..<Constants.requestCount {
                flagCounter.trackRequest(reportedValue: featureFlag?.value ?? .null, featureFlag: featureFlag, defaultValue: featureFlag?.value ?? .null, context: LDContext.stub())
            }
        } else {
            for _ in 0..<Constants.requestCount {
                flagCounter.trackRequest(reportedValue: false, featureFlag: nil, defaultValue: false, context: LDContext.stub())
            }
        }

        return flagCounter
    }
}
