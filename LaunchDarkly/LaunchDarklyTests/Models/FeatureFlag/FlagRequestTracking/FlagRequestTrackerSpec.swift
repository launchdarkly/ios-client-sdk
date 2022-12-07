import Foundation
import XCTest

@testable import LaunchDarkly

final class FlagRequestTrackerSpec: XCTestCase {
    func testInit() {
        let flagRequestTracker = FlagRequestTracker()
        XCTAssertEqual(flagRequestTracker.flagCounters, [:])
        XCTAssertFalse(flagRequestTracker.hasLoggedRequests)
        let now = Date()
        XCTAssert(flagRequestTracker.startDate <= now)
        XCTAssert(flagRequestTracker.startDate >= now - 1.0)
    }

    func testTrackRequestInitial() {
        let flag = FeatureFlag(flagKey: "bool-flag", variation: 1, version: 5, flagVersion: 2)
        var flagRequestTracker = FlagRequestTracker()
        flagRequestTracker.trackRequest(flagKey: "bool-flag", reportedValue: false, featureFlag: flag, defaultValue: true, context: LDContext.stub())
        XCTAssertEqual(flagRequestTracker.flagCounters.count, 1)
        let counter = FlagCounter()
        counter.trackRequest(reportedValue: false, featureFlag: flag, defaultValue: true, context: LDContext.stub())
        XCTAssertEqual(flagRequestTracker.flagCounters["bool-flag"], counter)
    }

    func testTrackRequestSameFlagKey() {
        let flag = FeatureFlag(flagKey: "bool-flag", variation: 1, version: 5, flagVersion: 2)
        var flagRequestTracker = FlagRequestTracker()
        flagRequestTracker.trackRequest(flagKey: "bool-flag", reportedValue: false, featureFlag: flag, defaultValue: true, context: LDContext.stub())
        flagRequestTracker.trackRequest(flagKey: "bool-flag", reportedValue: false, featureFlag: flag, defaultValue: true, context: LDContext.stub())
        XCTAssertEqual(flagRequestTracker.flagCounters.count, 1)
        let counter = FlagCounter()
        counter.trackRequest(reportedValue: false, featureFlag: flag, defaultValue: true, context: LDContext.stub())
        counter.trackRequest(reportedValue: false, featureFlag: flag, defaultValue: true, context: LDContext.stub())
        XCTAssertEqual(flagRequestTracker.flagCounters["bool-flag"], counter)
    }

    func testTrackRequestDifferentFlagKey() {
        let flag = FeatureFlag(flagKey: "bool-flag", variation: 1, version: 5, flagVersion: 2)
        let secondFlag = FeatureFlag(flagKey: "alt-flag", variation: 2, version: 6, flagVersion: 3)
        var flagRequestTracker = FlagRequestTracker()
        flagRequestTracker.trackRequest(flagKey: "bool-flag", reportedValue: false, featureFlag: flag, defaultValue: true, context: LDContext.stub())
        flagRequestTracker.trackRequest(flagKey: "alt-flag", reportedValue: true, featureFlag: secondFlag, defaultValue: false, context: LDContext.stub())
        XCTAssertEqual(flagRequestTracker.flagCounters.count, 2)
        let counter1 = FlagCounter()
        counter1.trackRequest(reportedValue: false, featureFlag: flag, defaultValue: true, context: LDContext.stub())
        let counter2 = FlagCounter()
        counter2.trackRequest(reportedValue: true, featureFlag: secondFlag, defaultValue: false, context: LDContext.stub())
        XCTAssertEqual(flagRequestTracker.flagCounters["bool-flag"], counter1)
        XCTAssertEqual(flagRequestTracker.flagCounters["alt-flag"], counter2)
    }

    func testHasLoggedRequests() {
        var flagRequestTracker = FlagRequestTracker()
        flagRequestTracker.trackRequest(flagKey: "test-key", reportedValue: nil, featureFlag: FeatureFlag(flagKey: "test-key"), defaultValue: nil, context: LDContext.stub())
        XCTAssert(flagRequestTracker.hasLoggedRequests)
    }
}

extension FlagRequestTracker {
    static func stub() -> FlagRequestTracker {
        var tracker = FlagRequestTracker()
        DarklyServiceMock.FlagKeys.knownFlags.forEach { flagKey in
            tracker.flagCounters[flagKey] = FlagCounter.stub(flagKey: flagKey)
        }
        tracker.flagCounters[DarklyServiceMock.FlagKeys.unknown] = FlagCounter.stub(flagKey: DarklyServiceMock.FlagKeys.unknown)
        return tracker
    }
}

extension LDFlagKey {
    var isKnown: Bool {
        DarklyServiceMock.FlagKeys.knownFlags.contains(self)
    }
}

extension CounterValue: Equatable {
    public static func == (lhs: CounterValue, rhs: CounterValue) -> Bool {
        lhs.value == rhs.value && lhs.count == rhs.count
    }
}

extension FlagCounter: Equatable {
    public static func == (lhs: FlagCounter, rhs: FlagCounter) -> Bool {
        lhs.defaultValue == rhs.defaultValue && lhs.flagValueCounters == rhs.flagValueCounters
    }
}
