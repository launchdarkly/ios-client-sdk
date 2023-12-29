import Foundation
import XCTest

@testable import LaunchDarkly

final class EventSpec: XCTestCase {
    func testFeatureEventInit() {
        let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
        let context = LDContext.stub()
        let testDate = Date()
        let event = FeatureEvent(key: "abc", context: context, value: true, defaultValue: false, featureFlag: featureFlag, includeReason: true, isDebug: false, creationDate: testDate)
        XCTAssertEqual(event.kind, Event.Kind.feature)
        XCTAssertEqual(event.key, "abc")
        XCTAssertEqual(event.context, context)
        XCTAssertEqual(event.value, true)
        XCTAssertEqual(event.defaultValue, false)
        XCTAssertEqual(event.featureFlag, featureFlag)
        XCTAssertEqual(event.includeReason, true)
        XCTAssertEqual(event.creationDate, testDate)
    }

    func testDebugEventInit() {
        let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
        let context = LDContext.stub()
        let testDate = Date()
        let event = FeatureEvent(key: "abc", context: context, value: true, defaultValue: false, featureFlag: featureFlag, includeReason: false, isDebug: true, creationDate: testDate)
        XCTAssertEqual(event.kind, Event.Kind.debug)
        XCTAssertEqual(event.key, "abc")
        XCTAssertEqual(event.context, context)
        XCTAssertEqual(event.value, true)
        XCTAssertEqual(event.defaultValue, false)
        XCTAssertEqual(event.featureFlag, featureFlag)
        XCTAssertEqual(event.includeReason, false)
        XCTAssertEqual(event.creationDate, testDate)
    }

    func testCustomEventInit() {
        let context = LDContext.stub()
        let testDate = Date()
        let event = CustomEvent(key: "abc", context: context, data: ["abc": 123], metricValue: 5.0, creationDate: testDate)
        XCTAssertEqual(event.kind, Event.Kind.custom)
        XCTAssertEqual(event.key, "abc")
        XCTAssertEqual(event.context, context)
        XCTAssertEqual(event.data, ["abc": 123])
        XCTAssertEqual(event.metricValue, 5.0)
        XCTAssertEqual(event.creationDate, testDate)
    }

    func testIdentifyEventInit() {
        let testDate = Date()
        let context = LDContext.stub()
        let event = IdentifyEvent(context: context, creationDate: testDate)
        XCTAssertEqual(event.kind, Event.Kind.identify)
        XCTAssertEqual(event.context, context)
        XCTAssertEqual(event.creationDate, testDate)
    }

    func testSummaryEventInit() {
        let flagRequestTracker = FlagRequestTracker.stub()
        let endDate = Date()
        let event = SummaryEvent(flagRequestTracker: flagRequestTracker, endDate: endDate)
        XCTAssertEqual(event.kind, Event.Kind.summary)
        XCTAssertEqual(event.endDate, endDate)
        XCTAssertEqual(event.flagRequestTracker.startDate, flagRequestTracker.startDate)
        XCTAssertEqual(event.flagRequestTracker.flagCounters, flagRequestTracker.flagCounters)
    }

    func testCustomEventEncodingDataAndMetric() {
        let context = LDContext.stub()
        let event = CustomEvent(key: "event-key", context: context, data: ["abc", 12], metricValue: 0.5)
        encodesToObject(event) { dict in
            XCTAssertEqual(dict.count, 6)
            XCTAssertEqual(dict["kind"], "custom")
            XCTAssertEqual(dict["key"], "event-key")
            XCTAssertEqual(dict["data"], ["abc", 12])
            XCTAssertEqual(dict["metricValue"], 0.5)
            XCTAssertEqual(dict["contextKeys"], .object(["user": .string(context.fullyQualifiedKey())]))
            XCTAssertEqual(dict["creationDate"], .number(Double(event.creationDate.millisSince1970)))
        }
    }

    func testCustomEventEncodingAnonContext() {
        let context = LDContext.stub()
        let event = CustomEvent(key: "event-key", context: context, data: ["key": "val"])
        encodesToObject(event) { dict in
            XCTAssertEqual(dict.count, 5)
            XCTAssertEqual(dict["kind"], "custom")
            XCTAssertEqual(dict["key"], "event-key")
            XCTAssertEqual(dict["data"], ["key": "val"])
            XCTAssertEqual(dict["contextKeys"], .object(["user": .string(context.fullyQualifiedKey())]))
            XCTAssertEqual(dict["creationDate"], .number(Double(event.creationDate.millisSince1970)))
        }
    }

    func testCustomEventEncodingInlining() {
        let context = LDContext.stub()
        let event = CustomEvent(key: "event-key", context: context, data: nil, metricValue: 2.5)
        encodesToObject(event) { dict in
            XCTAssertEqual(dict.count, 5)
            XCTAssertEqual(dict["kind"], "custom")
            XCTAssertEqual(dict["key"], "event-key")
            XCTAssertEqual(dict["metricValue"], 2.5)
            XCTAssertEqual(dict["contextKeys"], .object(["user": .string(context.fullyQualifiedKey())]))
            XCTAssertEqual(dict["creationDate"], .number(Double(event.creationDate.millisSince1970)))
        }
    }

    func testFeatureEventEncodingNoReasonByDefault() {
        let context = LDContext.stub()
        let featureFlag = FeatureFlag(flagKey: "flag-key", variation: 2, flagVersion: 3, reason: ["kind": "OFF"])
        [false, true].forEach { isDebug in
            let event = FeatureEvent(key: "event-key", context: context, value: true, defaultValue: false, featureFlag: featureFlag, includeReason: false, isDebug: isDebug)
            encodesToObject(event) { dict in
                XCTAssertEqual(dict.count, 8)
                XCTAssertEqual(dict["kind"], isDebug ? "debug" : "feature")
                XCTAssertEqual(dict["key"], "event-key")
                XCTAssertEqual(dict["value"], true)
                XCTAssertEqual(dict["default"], false)
                XCTAssertEqual(dict["variation"], 2)
                XCTAssertEqual(dict["version"], 3)
                if isDebug {
                    XCTAssertEqual(dict["context"], encodeToLDValue(context))
                } else {
                    XCTAssertEqual(dict["contextKeys"], .object(["user": .string(context.fullyQualifiedKey())]))
                }
                XCTAssertEqual(dict["creationDate"], .number(Double(event.creationDate.millisSince1970)))
            }
        }
    }

    func testFeatureEventEncodingIncludeReason() {
        let context = LDContext.stub()
        let featureFlag = FeatureFlag(flagKey: "flag-key", variation: 2, version: 2, flagVersion: 3, reason: ["kind": "OFF"])
        [false, true].forEach { isDebug in
            let event = FeatureEvent(key: "event-key", context: context, value: 3, defaultValue: 4, featureFlag: featureFlag, includeReason: true, isDebug: isDebug)
            encodesToObject(event) { dict in
                XCTAssertEqual(dict.count, 9)
                XCTAssertEqual(dict["kind"], isDebug ? "debug" : "feature")
                XCTAssertEqual(dict["key"], "event-key")
                XCTAssertEqual(dict["value"], 3)
                XCTAssertEqual(dict["default"], 4)
                XCTAssertEqual(dict["variation"], 2)
                XCTAssertEqual(dict["version"], 3)
                XCTAssertEqual(dict["reason"], ["kind": "OFF"])
                if isDebug {
                    XCTAssertEqual(dict["context"], encodeToLDValue(context))
                } else {
                    XCTAssertEqual(dict["contextKeys"], .object(["user": .string(context.fullyQualifiedKey())]))
                }
                XCTAssertEqual(dict["creationDate"], .number(Double(event.creationDate.millisSince1970)))
            }
        }
    }

    func testFeatureEventEncodingTrackReason() {
        let context = LDContext.stub()
        let featureFlag = FeatureFlag(flagKey: "flag-key", reason: ["kind": "OFF"], trackReason: true)
        [false, true].forEach { isDebug in
            let event = FeatureEvent(key: "event-key", context: context, value: nil, defaultValue: nil, featureFlag: featureFlag, includeReason: false, isDebug: isDebug)
            encodesToObject(event) { dict in
                XCTAssertEqual(dict.count, 7)
                XCTAssertEqual(dict["kind"], isDebug ? "debug" : "feature")
                XCTAssertEqual(dict["key"], "event-key")
                XCTAssertEqual(dict["value"], .null)
                XCTAssertEqual(dict["default"], .null)
                XCTAssertEqual(dict["reason"], ["kind": "OFF"])
                if isDebug {
                    XCTAssertEqual(dict["context"], encodeToLDValue(context))
                } else {
                    XCTAssertEqual(dict["contextKeys"], .object(["user": .string(context.fullyQualifiedKey())]))
                }
                XCTAssertEqual(dict["creationDate"], .number(Double(event.creationDate.millisSince1970)))
            }
        }
    }

    func testFeatureEventEncodingAnonContextKind() {
        let context = LDContext.stub()
        [false, true].forEach { isDebug in
            let event = FeatureEvent(key: "event-key", context: context, value: true, defaultValue: false, featureFlag: nil, includeReason: true, isDebug: isDebug)
            encodesToObject(event) { dict in
                XCTAssertEqual(dict.count, 6)
                XCTAssertEqual(dict["kind"], isDebug ? "debug" : "feature")
                XCTAssertEqual(dict["key"], "event-key")
                XCTAssertEqual(dict["value"], true)
                XCTAssertEqual(dict["default"], false)
                if isDebug {
                    XCTAssertEqual(dict["context"], encodeToLDValue(context))
                } else {
                    XCTAssertEqual(dict["contextKeys"], .object(["user": .string(context.fullyQualifiedKey())]))
                }
                XCTAssertEqual(dict["creationDate"], .number(Double(event.creationDate.millisSince1970)))
            }
        }
    }

    func testFeatureEventEncodingInlinesContextForDebug() {
        let context = LDContext.stub()
        let featureFlag = FeatureFlag(flagKey: "flag-key", version: 3)
        let debugEvent = FeatureEvent(key: "event-key", context: context, value: true, defaultValue: false, featureFlag: featureFlag, includeReason: false, isDebug: true)
        let encodedDebug = encodeToLDValue(debugEvent)
        [encodedDebug].forEach { valueIsObject($0) { dict in
            XCTAssertEqual(dict.count, 7)
            XCTAssertEqual(dict["key"], "event-key")
            XCTAssertEqual(dict["value"], true)
            XCTAssertEqual(dict["default"], false)
            XCTAssertEqual(dict["version"], 3)
            XCTAssertEqual(dict["context"], encodeToLDValue(context))
        }}
    }

    func testIdentifyEventEncoding() throws {
        let context = LDContext.stub()
        let event = IdentifyEvent(context: context)
        encodesToObject(event) { dict in
            XCTAssertEqual(dict.count, 4)
                XCTAssertEqual(dict["kind"], "identify")
                XCTAssertEqual(dict["key"], .string(context.fullyQualifiedKey()))
                XCTAssertEqual(dict["context"], encodeToLDValue(context))
                XCTAssertEqual(dict["creationDate"], .number(Double(event.creationDate.millisSince1970)))
        }
    }

    func testSummaryEventEncoding() {
        let flag = FeatureFlag(flagKey: "bool-flag", variation: 1, version: 5, flagVersion: 2)
        var flagRequestTracker = FlagRequestTracker()
        flagRequestTracker.trackRequest(flagKey: "bool-flag", reportedValue: false, featureFlag: flag, defaultValue: true, context: LDContext.stub())
        flagRequestTracker.trackRequest(flagKey: "bool-flag", reportedValue: false, featureFlag: flag, defaultValue: true, context: LDContext.stub())
        let event = SummaryEvent(flagRequestTracker: flagRequestTracker, endDate: Date())
        encodesToObject(event) { dict in
            XCTAssertEqual(dict.count, 4)
            XCTAssertEqual(dict["kind"], "summary")
            XCTAssertEqual(dict["startDate"], .number(Double(flagRequestTracker.startDate.millisSince1970)))
            XCTAssertEqual(dict["endDate"], .number(Double(event.endDate.millisSince1970)))
            valueIsObject(dict["features"]) { features in
                XCTAssertEqual(features.count, 1)
                let counter = FlagCounter()
                counter.trackRequest(reportedValue: false, featureFlag: flag, defaultValue: true, context: LDContext.stub())
                counter.trackRequest(reportedValue: false, featureFlag: flag, defaultValue: true, context: LDContext.stub())
                XCTAssertEqual(features["bool-flag"], encodeToLDValue(counter))
            }
        }
    }
}

extension Event: Equatable {
    public static func == (_ lhs: Event, _ rhs: Event) -> Bool {
        let config = [LDContext.UserInfoKeys.includePrivateAttributes: true, LDContext.UserInfoKeys.redactAttributes: false]
        return encodeToLDValue(lhs, userInfo: config) == encodeToLDValue(rhs, userInfo: config)
    }
}

extension Event {
    static func stub(_ eventKind: Kind, with context: LDContext) -> Event {
        switch eventKind {
        case .feature:
            let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
            return FeatureEvent(key: UUID().uuidString, context: context, value: true, defaultValue: false, featureFlag: featureFlag, includeReason: false, isDebug: false)
        case .debug:
            let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
            return FeatureEvent(key: UUID().uuidString, context: context, value: true, defaultValue: false, featureFlag: featureFlag, includeReason: false, isDebug: true)
        case .identify: return IdentifyEvent(context: context)
        case .custom: return CustomEvent(key: UUID().uuidString, context: context, data: ["custom": .string(UUID().uuidString)])
        case .summary: return SummaryEvent(flagRequestTracker: FlagRequestTracker.stub())
        }
    }

    static func eventKind(for count: Int) -> Kind {
        Event.Kind.allKinds[count % Event.Kind.allKinds.count]
    }
}
