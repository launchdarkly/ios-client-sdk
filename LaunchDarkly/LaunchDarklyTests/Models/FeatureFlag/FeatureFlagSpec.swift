import Foundation
import XCTest

@testable import LaunchDarkly

final class FeatureFlagSpec: XCTestCase {
    func testInitMinimal() {
        let featureFlag = FeatureFlag(flagKey: "abc")
        XCTAssertEqual(featureFlag.flagKey, "abc")
        XCTAssertEqual(featureFlag.value, .null)
        XCTAssertNil(featureFlag.variation)
        XCTAssertNil(featureFlag.version)
        XCTAssertFalse(featureFlag.trackEvents)
        XCTAssertNil(featureFlag.debugEventsUntilDate)
        XCTAssertNil(featureFlag.reason)
        XCTAssertFalse(featureFlag.trackReason)
    }

    func testInitAll() {
        let reason = DarklyServiceMock.Constants.reason
        let debugEventsUntilDate = Date().addingTimeInterval(30.0)
        let featureFlag = FeatureFlag(flagKey: "abc",
                                      value: 123,
                                      variation: 2,
                                      version: 3,
                                      flagVersion: 4,
                                      trackEvents: true,
                                      debugEventsUntilDate: debugEventsUntilDate,
                                      reason: reason,
                                      trackReason: false)

        XCTAssertEqual(featureFlag.flagKey, "abc")
        XCTAssertEqual(featureFlag.value, 123)
        XCTAssertEqual(featureFlag.variation, 2)
        XCTAssertEqual(featureFlag.version, 3)
        XCTAssertEqual(featureFlag.flagVersion, 4)
        XCTAssertEqual(featureFlag.trackEvents, true)
        XCTAssertEqual(featureFlag.debugEventsUntilDate, debugEventsUntilDate)
        XCTAssertEqual(featureFlag.reason, reason)
        XCTAssertEqual(featureFlag.trackReason, false)
    }

    func testDecodeMinimal() throws {
        let minimal: LDValue = ["key": "flag-key"]
        let flag = try JSONDecoder().decode(FeatureFlag.self, from: try JSONEncoder().encode(minimal))
        XCTAssertEqual(flag.flagKey, "flag-key")
        XCTAssertEqual(flag.value, .null)
        XCTAssertNil(flag.variation)
        XCTAssertNil(flag.version)
        XCTAssertNil(flag.flagVersion)
        XCTAssertFalse(flag.trackEvents)
        XCTAssertNil(flag.debugEventsUntilDate)
        XCTAssertNil(flag.reason)
        XCTAssertFalse(flag.trackReason)
    }

    func testDecodeFull() throws {
        let now = Date().millisSince1970
        let value: LDValue = ["key": "flag-key", "value": [1, 2, 3], "variation": 2, "version": 3,
                              "flagVersion": 4, "trackEvents": false, "debugEventsUntilDate": .number(Double(now)),
                              "reason": ["kind": "OFF"], "trackReason": true]
        let flag = try JSONDecoder().decode(FeatureFlag.self, from: try JSONEncoder().encode(value))
        XCTAssertEqual(flag.flagKey, "flag-key")
        XCTAssertEqual(flag.value, [1, 2, 3])
        XCTAssertEqual(flag.variation, 2)
        XCTAssertEqual(flag.version, 3)
        XCTAssertEqual(flag.flagVersion, 4)
        XCTAssertEqual(flag.trackEvents, false)
        XCTAssertEqual(flag.debugEventsUntilDate?.millisSince1970, now)
        XCTAssertEqual(flag.reason, ["kind": "OFF"])
        XCTAssertEqual(flag.trackReason, true)
    }

    func testDecodeExtra() throws {
        let extra: LDValue = ["key": "flag-key", "unused": "foo"]
        let flag = try JSONDecoder().decode(FeatureFlag.self, from: try JSONEncoder().encode(extra))
        XCTAssertEqual(flag.flagKey, "flag-key")
    }

    func testDecodeMissingKey() throws {
        let testData = try JSONEncoder().encode([:] as LDValue)
        XCTAssertThrowsError(try JSONDecoder().decode(FeatureFlag.self, from: testData)) { err in
            guard let err = err as? DecodingError, case .keyNotFound = err
            else { return XCTFail("Expected key not found error") }
        }
    }

    func testDecodeMismatchedType() throws {
        let encoder = JSONEncoder()
        let invalidValues: [LDValue] = [[], ["key": 5], ["key": "a", "variation": "1"],
                                        ["key": "a", "version": "1"], ["key": "a", "flagVersion": "1"],
                                        ["key": "a", "trackEvents": "1"], ["key": "a", "trackReason": "1"],
                                        ["key": "a", "debugEventsUntilDate": "1"]]
        try invalidValues.map { try encoder.encode($0) }.forEach {
            XCTAssertThrowsError(try JSONDecoder().decode(FeatureFlag.self, from: $0)) { err in
                guard let err = err as? DecodingError, case .typeMismatch = err
                else { return XCTFail("Expected type mismatch error") }
            }
        }
    }

    func testEncodeMinimal() {
        let flag = FeatureFlag(flagKey: "flag-key")
        encodesToObject(flag) { value in
            XCTAssertEqual(value.count, 1)
            XCTAssertEqual(value["key"], "flag-key")
        }
    }

    func testEncodeFull() {
        let now = Date()
        let flag = FeatureFlag(flagKey: "flag-key", value: [1, 2, 3], variation: 2, version: 3, flagVersion: 4,
                               trackEvents: true, debugEventsUntilDate: now, reason: ["kind": "OFF"], trackReason: true)
        encodesToObject(flag) { value in
            XCTAssertEqual(value.count, 9)
            XCTAssertEqual(value["key"], "flag-key")
            XCTAssertEqual(value["value"], [1, 2, 3])
            XCTAssertEqual(value["variation"], 2)
            XCTAssertEqual(value["version"], 3)
            XCTAssertEqual(value["flagVersion"], 4)
            XCTAssertEqual(value["trackEvents"], true)
            XCTAssertEqual(value["debugEventsUntilDate"], .number(Double(now.millisSince1970)))
            XCTAssertEqual(value["reason"], ["kind": "OFF"])
            XCTAssertEqual(value["trackReason"], true)
        }
    }

    func testEncodeOmitsDefaults() {
        let flag = FeatureFlag(flagKey: "flag-key", trackEvents: false, trackReason: false)
        encodesToObject(flag) { value in
            XCTAssertEqual(value.count, 1)
            XCTAssertEqual(value["key"], "flag-key")
        }
    }

    func testStoredItemCollectionDecodeValid() throws {
        let testData: LDValue = [
            "flags": [
                "key1": ["item": ["key": "key1"]],
                "key2": ["tombstone": 10]
            ]
        ]
        let encoded = try JSONEncoder().encode(testData)
        let storedItemCollection = try JSONDecoder().decode(StoredItemCollection.self, from: encoded)
        XCTAssertEqual(storedItemCollection.flags.count, 2)
        XCTAssertEqual(storedItemCollection.flags.featureFlags["key1"]?.flagKey, "key1")
        XCTAssertNil(storedItemCollection.flags.featureFlags["key2"])
    }

    func testStoredItemCollectionEncoding() {
        let collection = StoredItemCollection(["flag-key": .item(FeatureFlag(flagKey: "flag-key"))])
        encodesToObject(collection) { values in
            XCTAssertEqual(values.count, 1)
            valueIsObject(values["flags"]) { flags in
                valueIsObject(flags["flag-key"]) { storageItem in
                    valueIsObject(storageItem["item"]) { flagValue in
                        XCTAssertEqual(flagValue["key"], "flag-key")
                    }
                }
            }
        }
    }

    func testFlagCollectionDecodeValid() throws {
        let testData: LDValue = ["key1": [:], "key2": ["key": "key2"]]
        let flagCollection = try JSONDecoder().decode(FeatureFlagCollection.self, from: JSONEncoder().encode(testData))
        XCTAssertEqual(flagCollection.flags.count, 2)
        XCTAssertEqual(flagCollection.flags["key1"]?.flagKey, "key1")
        XCTAssertEqual(flagCollection.flags["key2"]?.flagKey, "key2")
    }

    func testFlagCollectionDecodeConflicting() throws {
        let testData = try JSONEncoder().encode(["flag-key": ["key": "flag-key2"]] as LDValue)
        XCTAssertThrowsError(try JSONDecoder().decode(FeatureFlagCollection.self, from: testData)) { err in
            guard let err = err as? DecodingError, case .dataCorrupted = err
            else { return XCTFail("Expected data corrupted error") }
        }
    }

    func testFlagCollectionEncoding() {
        encodesToObject(FeatureFlagCollection(["flag-key": FeatureFlag(flagKey: "flag-key")])) { values in
            XCTAssertEqual(values.count, 1)
            valueIsObject(values["flag-key"]) { flagValue in
                XCTAssertEqual(flagValue["key"], "flag-key")
            }
        }
    }

    func testShouldCreateDebugEvents() {
        // When debugEventsUntilDate doesn't exist should yield false
        var flag = FeatureFlag(flagKey: "test-key", trackEvents: true, debugEventsUntilDate: nil)
        XCTAssertFalse(flag.shouldCreateDebugEvents(lastEventReportResponseTime: Date()))
        // When lastEventReportResponseTime is nil should use current system time
        flag = FeatureFlag(flagKey: "test-key", trackEvents: true, debugEventsUntilDate: Date().addingTimeInterval(1.0))
        XCTAssertTrue(flag.shouldCreateDebugEvents(lastEventReportResponseTime: nil))
        flag = FeatureFlag(flagKey: "test-key", trackEvents: true, debugEventsUntilDate: Date().addingTimeInterval(-1.0))
        XCTAssertFalse(flag.shouldCreateDebugEvents(lastEventReportResponseTime: nil))
        // Otherwise should use lastEventReportResponseTime
        let lastEventResponseDate = Date().addingTimeInterval(-30.0)
        flag = FeatureFlag(flagKey: "test-key", trackEvents: true, debugEventsUntilDate: Date().addingTimeInterval(-29.0))
        XCTAssertTrue(flag.shouldCreateDebugEvents(lastEventReportResponseTime: lastEventResponseDate))
        flag = FeatureFlag(flagKey: "test-key", trackEvents: true, debugEventsUntilDate: Date().addingTimeInterval(-31.0))
        XCTAssertFalse(flag.shouldCreateDebugEvents(lastEventReportResponseTime: lastEventResponseDate))
    }

    func testVersionForEvents() {
        XCTAssertNil(FeatureFlag(flagKey: "t").versionForEvents)
        XCTAssertEqual(FeatureFlag(flagKey: "t", version: 4).versionForEvents, 4)
        XCTAssertEqual(FeatureFlag(flagKey: "t", flagVersion: 3).versionForEvents, 3)
        XCTAssertEqual(FeatureFlag(flagKey: "t", version: 2, flagVersion: 3).versionForEvents, 3)
    }
}

extension StorageItem: Equatable {
    public static func == (lhs: StorageItem, rhs: StorageItem) -> Bool {
        switch (lhs, rhs) {
        case let (.item(lFlag), .item(rFlag)):
            return lFlag == rFlag
        case let (.tombstone(lVersion), .tombstone(rVersion)):
            return lVersion == rVersion
        default:
            return false
        }
    }
}

extension FeatureFlag: Equatable {
    public static func == (lhs: FeatureFlag, rhs: FeatureFlag) -> Bool {
        lhs.flagKey == rhs.flagKey &&
        lhs.value == rhs.value &&
        lhs.variation == rhs.variation &&
        lhs.version == rhs.version &&
        lhs.flagVersion == rhs.flagVersion &&
        lhs.trackEvents == rhs.trackEvents &&
//        lhs.debugEventsUntilDate == rhs.debugEventsUntilDate &&
        lhs.reason == rhs.reason &&
        lhs.trackReason == rhs.trackReason
    }
}
