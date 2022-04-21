import Foundation
import XCTest

@testable import LaunchDarkly

final class EventSpec: XCTestCase {
    func testAliasEventInit() {
        let testDate = Date()
        let event = AliasEvent(key: "abc", previousKey: "def", contextKind: "user", previousContextKind: "anonymousUser", creationDate: testDate)
        XCTAssertEqual(event.kind, .alias)
        XCTAssertEqual(event.key, "abc")
        XCTAssertEqual(event.previousKey, "def")
        XCTAssertEqual(event.contextKind, "user")
        XCTAssertEqual(event.previousContextKind, "anonymousUser")
        XCTAssertEqual(event.creationDate, testDate)
    }

    func testFeatureEventInit() {
        let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
        let user = LDUser.stub()
        let testDate = Date()
        let event = FeatureEvent(key: "abc", user: user, value: true, defaultValue: false, featureFlag: featureFlag, includeReason: true, isDebug: false, creationDate: testDate)
        XCTAssertEqual(event.kind, Event.Kind.feature)
        XCTAssertEqual(event.key, "abc")
        XCTAssertEqual(event.user, user)
        XCTAssertEqual(event.value, true)
        XCTAssertEqual(event.defaultValue, false)
        XCTAssertEqual(event.featureFlag, featureFlag)
        XCTAssertEqual(event.includeReason, true)
        XCTAssertEqual(event.creationDate, testDate)
    }

    func testDebugEventInit() {
        let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
        let user = LDUser.stub()
        let testDate = Date()
        let event = FeatureEvent(key: "abc", user: user, value: true, defaultValue: false, featureFlag: featureFlag, includeReason: false, isDebug: true, creationDate: testDate)
        XCTAssertEqual(event.kind, Event.Kind.debug)
        XCTAssertEqual(event.key, "abc")
        XCTAssertEqual(event.user, user)
        XCTAssertEqual(event.value, true)
        XCTAssertEqual(event.defaultValue, false)
        XCTAssertEqual(event.featureFlag, featureFlag)
        XCTAssertEqual(event.includeReason, false)
        XCTAssertEqual(event.creationDate, testDate)
    }

    func testCustomEventInit() {
        let user = LDUser.stub()
        let testDate = Date()
        let event = CustomEvent(key: "abc", user: user, data: ["abc": 123], metricValue: 5.0, creationDate: testDate)
        XCTAssertEqual(event.kind, Event.Kind.custom)
        XCTAssertEqual(event.key, "abc")
        XCTAssertEqual(event.user, user)
        XCTAssertEqual(event.data, ["abc": 123])
        XCTAssertEqual(event.metricValue, 5.0)
        XCTAssertEqual(event.creationDate, testDate)
    }

    func testIdentifyEventInit() {
        let testDate = Date()
        let user = LDUser.stub()
        let event = IdentifyEvent(user: user, creationDate: testDate)
        XCTAssertEqual(event.kind, Event.Kind.identify)
        XCTAssertEqual(event.user, user)
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

    func testAliasEventEncoding() {
        let event = AliasEvent(key: "abc", previousKey: "def", contextKind: "user", previousContextKind: "anonymousUser")
        encodesToObject(event) { dict in
            XCTAssertEqual(dict.count, 6)
            XCTAssertEqual(dict["kind"], "alias")
            XCTAssertEqual(dict["key"], "abc")
            XCTAssertEqual(dict["previousKey"], "def")
            XCTAssertEqual(dict["contextKind"], "user")
            XCTAssertEqual(dict["previousContextKind"], "anonymousUser")
            XCTAssertEqual(dict["creationDate"], LDValue.fromAny(event.creationDate.millisSince1970))
        }
    }

    func testCustomEventEncodingDataAndMetric() {
        let user = LDUser.stub()
        let event = CustomEvent(key: "event-key", user: user, data: ["abc", 12], metricValue: 0.5)
        encodesToObject(event) { dict in
            XCTAssertEqual(dict.count, 6)
            XCTAssertEqual(dict["kind"], "custom")
            XCTAssertEqual(dict["key"], "event-key")
            XCTAssertEqual(dict["data"], ["abc", 12])
            XCTAssertEqual(dict["metricValue"], 0.5)
            XCTAssertEqual(dict["userKey"], .string(user.key))
            XCTAssertEqual(dict["creationDate"], LDValue.fromAny(event.creationDate.millisSince1970))
        }
    }

    func testCustomEventEncodingAnonUser() {
        let anonUser = LDUser()
        let event = CustomEvent(key: "event-key", user: anonUser, data: ["key": "val"])
        encodesToObject(event) { dict in
            XCTAssertEqual(dict.count, 6)
            XCTAssertEqual(dict["kind"], "custom")
            XCTAssertEqual(dict["key"], "event-key")
            XCTAssertEqual(dict["data"], ["key": "val"])
            XCTAssertEqual(dict["userKey"], .string(anonUser.key))
            XCTAssertEqual(dict["contextKind"], "anonymousUser")
            XCTAssertEqual(dict["creationDate"], LDValue.fromAny(event.creationDate.millisSince1970))
        }
    }

    func testCustomEventEncodingInlining() {
        let user = LDUser.stub()
        let event = CustomEvent(key: "event-key", user: user, data: nil, metricValue: 2.5)
        encodesToObject(event, userInfo: [Event.UserInfoKeys.inlineUserInEvents: true]) { dict in
            XCTAssertEqual(dict.count, 5)
            XCTAssertEqual(dict["kind"], "custom")
            XCTAssertEqual(dict["key"], "event-key")
            XCTAssertEqual(dict["metricValue"], 2.5)
            XCTAssertEqual(dict["user"], encodeToLDValue(user))
            XCTAssertEqual(dict["creationDate"], LDValue.fromAny(event.creationDate.millisSince1970))
        }
    }

    func testFeatureEventEncodingNoReasonByDefault() {
        let user = LDUser.stub()
        let featureFlag = FeatureFlag(flagKey: "flag-key", variation: 2, flagVersion: 3, reason: ["kind": "OFF"])
        [false, true].forEach { isDebug in
            let event = FeatureEvent(key: "event-key", user: user, value: true, defaultValue: false, featureFlag: featureFlag, includeReason: false, isDebug: isDebug)
            encodesToObject(event) { dict in
                XCTAssertEqual(dict.count, 8)
                XCTAssertEqual(dict["kind"], isDebug ? "debug" : "feature")
                XCTAssertEqual(dict["key"], "event-key")
                XCTAssertEqual(dict["value"], true)
                XCTAssertEqual(dict["default"], false)
                XCTAssertEqual(dict["variation"], 2)
                XCTAssertEqual(dict["version"], 3)
                if isDebug {
                    XCTAssertEqual(dict["user"], encodeToLDValue(user))
                } else {
                    XCTAssertEqual(dict["userKey"], .string(user.key))
                }
                XCTAssertEqual(dict["creationDate"], LDValue.fromAny(event.creationDate.millisSince1970))
            }
        }
    }

    func testFeatureEventEncodingIncludeReason() {
        let user = LDUser.stub()
        let featureFlag = FeatureFlag(flagKey: "flag-key", variation: 2, version: 2, flagVersion: 3, reason: ["kind": "OFF"])
        [false, true].forEach { isDebug in
            let event = FeatureEvent(key: "event-key", user: user, value: 3, defaultValue: 4, featureFlag: featureFlag, includeReason: true, isDebug: isDebug)
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
                    XCTAssertEqual(dict["user"], encodeToLDValue(user))
                } else {
                    XCTAssertEqual(dict["userKey"], .string(user.key))
                }
                XCTAssertEqual(dict["creationDate"], LDValue.fromAny(event.creationDate.millisSince1970))
            }
        }
    }

    func testFeatureEventEncodingTrackReason() {
        let user = LDUser.stub()
        let featureFlag = FeatureFlag(flagKey: "flag-key", reason: ["kind": "OFF"], trackReason: true)
        [false, true].forEach { isDebug in
            let event = FeatureEvent(key: "event-key", user: user, value: nil, defaultValue: nil, featureFlag: featureFlag, includeReason: false, isDebug: isDebug)
            encodesToObject(event) { dict in
                XCTAssertEqual(dict.count, 7)
                XCTAssertEqual(dict["kind"], isDebug ? "debug" : "feature")
                XCTAssertEqual(dict["key"], "event-key")
                XCTAssertEqual(dict["value"], .null)
                XCTAssertEqual(dict["default"], .null)
                XCTAssertEqual(dict["reason"], ["kind": "OFF"])
                if isDebug {
                    XCTAssertEqual(dict["user"], encodeToLDValue(user))
                } else {
                    XCTAssertEqual(dict["userKey"], .string(user.key))
                }
                XCTAssertEqual(dict["creationDate"], LDValue.fromAny(event.creationDate.millisSince1970))
            }
        }
    }

    func testFeatureEventEncodingAnonContextKind() {
        let user = LDUser()
        [false, true].forEach { isDebug in
            let event = FeatureEvent(key: "event-key", user: user, value: true, defaultValue: false, featureFlag: nil, includeReason: true, isDebug: isDebug)
            encodesToObject(event) { dict in
                XCTAssertEqual(dict.count, isDebug ? 6 : 7)
                XCTAssertEqual(dict["kind"], isDebug ? "debug" : "feature")
                XCTAssertEqual(dict["key"], "event-key")
                XCTAssertEqual(dict["value"], true)
                XCTAssertEqual(dict["default"], false)
                if isDebug {
                    XCTAssertEqual(dict["user"], encodeToLDValue(user))
                } else {
                    XCTAssertEqual(dict["userKey"], .string(user.key))
                    XCTAssertEqual(dict["contextKind"], "anonymousUser")
                }
                XCTAssertEqual(dict["creationDate"], LDValue.fromAny(event.creationDate.millisSince1970))
            }
        }
    }

    func testFeatureEventEncodingInlinesUserForDebugOrConfig() {
        let user = LDUser.stub()
        let featureFlag = FeatureFlag(flagKey: "flag-key", version: 3)
        let featureEvent = FeatureEvent(key: "event-key", user: user, value: true, defaultValue: false, featureFlag: featureFlag, includeReason: false, isDebug: false)
        let debugEvent = FeatureEvent(key: "event-key", user: user, value: true, defaultValue: false, featureFlag: featureFlag, includeReason: false, isDebug: true)
        let encodedFeature = encodeToLDValue(featureEvent, userInfo: [Event.UserInfoKeys.inlineUserInEvents: true])
        let encodedDebug = encodeToLDValue(debugEvent, userInfo: [Event.UserInfoKeys.inlineUserInEvents: false])
        [encodedFeature, encodedDebug].forEach { valueIsObject($0) { dict in
            XCTAssertEqual(dict.count, 7)
            XCTAssertEqual(dict["key"], "event-key")
            XCTAssertEqual(dict["value"], true)
            XCTAssertEqual(dict["default"], false)
            XCTAssertEqual(dict["version"], 3)
            XCTAssertEqual(dict["user"], encodeToLDValue(user))
        }}
    }

    func testIdentifyEventEncoding() {
        let user = LDUser.stub()
        for inlineUser in [true, false] {
            let event = IdentifyEvent(user: user)
            encodesToObject(event, userInfo: [Event.UserInfoKeys.inlineUserInEvents: inlineUser]) { dict in
                XCTAssertEqual(dict.count, 4)
                XCTAssertEqual(dict["kind"], "identify")
                XCTAssertEqual(dict["key"], .string(user.key))
                XCTAssertEqual(dict["user"], encodeToLDValue(user))
                XCTAssertEqual(dict["creationDate"], LDValue.fromAny(event.creationDate.millisSince1970))
            }
        }
    }

    func testSummaryEventEncoding() {
        let flag = FeatureFlag(flagKey: "bool-flag", variation: 1, version: 5, flagVersion: 2)
        var flagRequestTracker = FlagRequestTracker()
        flagRequestTracker.trackRequest(flagKey: "bool-flag", reportedValue: false, featureFlag: flag, defaultValue: true)
        flagRequestTracker.trackRequest(flagKey: "bool-flag", reportedValue: false, featureFlag: flag, defaultValue: true)
        let event = SummaryEvent(flagRequestTracker: flagRequestTracker, endDate: Date())
        encodesToObject(event) { dict in
            XCTAssertEqual(dict.count, 4)
            XCTAssertEqual(dict["kind"], "summary")
            XCTAssertEqual(dict["startDate"], LDValue.fromAny(flagRequestTracker.startDate.millisSince1970))
            XCTAssertEqual(dict["endDate"], LDValue.fromAny(event.endDate.millisSince1970))
            valueIsObject(dict["features"]) { features in
                XCTAssertEqual(features.count, 1)
                let counter = FlagCounter()
                counter.trackRequest(reportedValue: false, featureFlag: flag, defaultValue: true)
                counter.trackRequest(reportedValue: false, featureFlag: flag, defaultValue: true)
                XCTAssertEqual(features["bool-flag"], encodeToLDValue(counter))
            }
        }
    }
}

extension Event: Equatable {
    public static func == (_ lhs: Event, _ rhs: Event) -> Bool {
        let config = [LDUser.UserInfoKeys.includePrivateAttributes: true, Event.UserInfoKeys.inlineUserInEvents: true]
        return encodeToLDValue(lhs, userInfo: config) == encodeToLDValue(rhs, userInfo: config)
    }
}

extension Event {
    static func stub(_ eventKind: Kind, with user: LDUser) -> Event {
        switch eventKind {
        case .feature:
            let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
            return FeatureEvent(key: UUID().uuidString, user: user, value: true, defaultValue: false, featureFlag: featureFlag, includeReason: false, isDebug: false)
        case .debug:
            let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
            return FeatureEvent(key: UUID().uuidString, user: user, value: true, defaultValue: false, featureFlag: featureFlag, includeReason: false, isDebug: true)
        case .identify: return IdentifyEvent(user: user)
        case .custom: return CustomEvent(key: UUID().uuidString, user: user, data: ["custom": .string(UUID().uuidString)])
        case .summary: return SummaryEvent(flagRequestTracker: FlagRequestTracker.stub())
        case .alias: return AliasEvent(key: UUID().uuidString, previousKey: UUID().uuidString, contextKind: "anonymousUser", previousContextKind: "anonymousUser")
        }
    }

    static func eventKind(for count: Int) -> Kind {
        Event.Kind.allKinds[count % Event.Kind.allKinds.count]
    }
}
