import Foundation
import XCTest

@testable import LaunchDarkly

final class FlagRequestTrackerSpec: XCTestCase {
    func testInit() {
        let flagRequestTracker = FlagRequestTracker()
        XCTAssertFalse(flagRequestTracker.hasLoggedRequests)
        let now = Date()
        XCTAssert(flagRequestTracker.startDate <= now)
        XCTAssert(flagRequestTracker.startDate >= now - 1.0)
    }

    func testTrackRequestInitial() {
        let flag = FeatureFlag(flagKey: "bool-flag", variation: 1, version: 5, flagVersion: 2)
        var flagRequestTracker = FlagRequestTracker()
        let now = Date().millisSince1970
        flagRequestTracker.trackRequest(flagKey: "bool-flag", reportedValue: false, featureFlag: flag, defaultValue: true)
        let dictionaryValue = flagRequestTracker.dictionaryValue
        XCTAssert(dictionaryValue.flagRequestTrackerStartDateMillis! <= now)
        XCTAssert(dictionaryValue.flagRequestTrackerStartDateMillis! >= now - 1000)
        let features = dictionaryValue.flagRequestTrackerFeatures!
        XCTAssertEqual(features.count, 1)
        let counter = FlagCounter()
        counter.trackRequest(reportedValue: false, featureFlag: flag, defaultValue: true)
        XCTAssert(AnyComparer.isEqual(features["bool-flag"], to: counter.dictionaryValue))
    }

    func testTrackRequestSameFlagKey() {
        let flag = FeatureFlag(flagKey: "bool-flag", variation: 1, version: 5, flagVersion: 2)
        var flagRequestTracker = FlagRequestTracker()
        let now = Date().millisSince1970
        flagRequestTracker.trackRequest(flagKey: "bool-flag", reportedValue: false, featureFlag: flag, defaultValue: true)
        flagRequestTracker.trackRequest(flagKey: "bool-flag", reportedValue: false, featureFlag: flag, defaultValue: true)
        let dictionaryValue = flagRequestTracker.dictionaryValue
        XCTAssert(dictionaryValue.flagRequestTrackerStartDateMillis! <= now)
        XCTAssert(dictionaryValue.flagRequestTrackerStartDateMillis! >= now - 1000)
        let features = dictionaryValue.flagRequestTrackerFeatures!
        XCTAssertEqual(features.count, 1)
        let counter = FlagCounter()
        counter.trackRequest(reportedValue: false, featureFlag: flag, defaultValue: true)
        counter.trackRequest(reportedValue: false, featureFlag: flag, defaultValue: true)
        XCTAssert(AnyComparer.isEqual(features["bool-flag"], to: counter.dictionaryValue))
    }

    func testTrackRequestDifferentFlagKey() {
        let flag = FeatureFlag(flagKey: "bool-flag", variation: 1, version: 5, flagVersion: 2)
        let secondFlag = FeatureFlag(flagKey: "alt-flag", variation: 2, version: 6, flagVersion: 3)
        var flagRequestTracker = FlagRequestTracker()
        let now = Date().millisSince1970
        flagRequestTracker.trackRequest(flagKey: "bool-flag", reportedValue: false, featureFlag: flag, defaultValue: true)
        flagRequestTracker.trackRequest(flagKey: "alt-flag", reportedValue: true, featureFlag: secondFlag, defaultValue: false)
        let dictionaryValue = flagRequestTracker.dictionaryValue
        XCTAssert(dictionaryValue.flagRequestTrackerStartDateMillis! <= now)
        XCTAssert(dictionaryValue.flagRequestTrackerStartDateMillis! >= now - 1000)
        let features = dictionaryValue.flagRequestTrackerFeatures!
        XCTAssertEqual(features.count, 2)
        let counter = FlagCounter()
        counter.trackRequest(reportedValue: false, featureFlag: flag, defaultValue: true)
        let secondCounter = FlagCounter()
        secondCounter.trackRequest(reportedValue: true, featureFlag: secondFlag, defaultValue: false)
        XCTAssert(AnyComparer.isEqual(features["bool-flag"], to: counter.dictionaryValue))
        XCTAssert(AnyComparer.isEqual(features["alt-flag"], to: secondCounter.dictionaryValue))
    }

    func testHasLoggedRequests() {
        var flagRequestTracker = FlagRequestTracker()
        flagRequestTracker.trackRequest(flagKey: "test-key", reportedValue: nil, featureFlag: FeatureFlag(flagKey: "test-key"), defaultValue: nil)
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

extension FlagRequestTracker: Equatable {
    public static func == (lhs: FlagRequestTracker, rhs: FlagRequestTracker) -> Bool {
        if !lhs.startDate.isWithin(0.001, of: rhs.startDate) {
            return false
        }
        return lhs.flagCounters == rhs.flagCounters
    }
}

extension Dictionary where Key == String, Value == Any {
    var flagRequestTrackerStartDateMillis: Int64? {
        self[FlagRequestTracker.CodingKeys.startDate.rawValue] as? Int64
    }
    var flagRequestTrackerFeatures: [LDFlagKey: Any]? {
        self[FlagRequestTracker.CodingKeys.features.rawValue] as? [LDFlagKey: Any]
    }
}

extension LDFlagKey {
    var isKnown: Bool {
        DarklyServiceMock.FlagKeys.knownFlags.contains(self)
    }
}
