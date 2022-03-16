import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class EventSpec: QuickSpec {
    struct Constants {
        static let eventKey = "EventSpec.Event.Key"
    }

    struct CustomEvent {
        static let dictionaryData: LDValue = ["dozen": 12,
                                              "phi": 1.61803,
                                              "true": true,
                                              "data string": "custom event dictionary data",
                                              "nestedArray": [1, 3, 7, 12],
                                              "nestedDictionary": ["one": 1.0, "three": 3.0]]
    }

    override func spec() {
        initSpec()
        aliasSpec()
        featureEventSpec()
        debugEventSpec()
        customEventSpec()
        identifyEventSpec()
        summaryEventSpec()
        testAliasEventEncoding()
        testCustomEventEncoding()
        testDebugEventEncoding()
        testFeatureEventEncoding()
        testIdentifyEventEncoding()
        testSummaryEventEncoding()
    }

    private func initSpec() {
        describe("init") {
            var user: LDUser!
            var featureFlag: FeatureFlag!
            var event: Event!
            beforeEach {
                user = LDUser.stub()
            }
            context("with optional items") {
                beforeEach {
                    featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)

                    event = Event(kind: .feature, key: Constants.eventKey, user: user, value: true, defaultValue: false, featureFlag: featureFlag, data: CustomEvent.dictionaryData, flagRequestTracker: FlagRequestTracker.stub(), endDate: Date())
                }
                it("creates an event with matching data") {
                    expect(event.kind) == Event.Kind.feature
                    expect(event.key) == Constants.eventKey
                    expect(event.creationDate).toNot(beNil())
                    expect(event.user) == user
                    expect(event.value) == true
                    expect(event.defaultValue) == false
                    expect(event.featureFlag?.allPropertiesMatch(featureFlag)).to(beTrue())
                    expect(event.data) == CustomEvent.dictionaryData
                    expect(event.flagRequestTracker).toNot(beNil())
                    expect(event.endDate).toNot(beNil())
                }
            }
            context("without optional items") {
                beforeEach {
                    event = Event(kind: .feature)
                }
                it("creates an event with matching data") {
                    expect(event.kind) == Event.Kind.feature
                    expect(event.key).to(beNil())
                    expect(event.creationDate).toNot(beNil())
                    expect(event.user).to(beNil())
                    expect(event.value) == .null
                    expect(event.defaultValue) == .null
                    expect(event.featureFlag).to(beNil())
                    expect(event.data) == .null
                    expect(event.flagRequestTracker).to(beNil())
                    expect(event.endDate).to(beNil())
                }
            }
        }
    }

    private func aliasSpec() {
        describe("alias events") {
            it("has correct fields") {
                let event = Event.aliasEvent(newUser: LDUser(), oldUser: LDUser())
                expect(event.kind) == Event.Kind.alias
            }
            it("from user to user") {
                let event = Event.aliasEvent(newUser: LDUser(key: "new"), oldUser: LDUser(key: "old"))
                expect(event.key) == "new"
                expect(event.previousKey) == "old"
                expect(event.contextKind) == "user"
                expect(event.previousContextKind) == "user"
            }
            it("from anon to anon") {
                let event = Event.aliasEvent(newUser: LDUser(key: "new", isAnonymous: true), oldUser: LDUser(key: "old", isAnonymous: true))
                expect(event.key) == "new"
                expect(event.previousKey) == "old"
                expect(event.contextKind) == "anonymousUser"
                expect(event.previousContextKind) == "anonymousUser"
            }
        }
    }

    private func featureEventSpec() {
        describe("featureEvent") {
            it("creates a feature event with matching data") {
                let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
                let user = LDUser.stub()
                let event = Event.featureEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user, includeReason: false)
                expect(event.kind) == Event.Kind.feature
                expect(event.key) == Constants.eventKey
                expect(event.creationDate).toNot(beNil())
                expect(event.user) == user
                expect(event.value) == true
                expect(event.defaultValue) == false
                expect(event.featureFlag?.allPropertiesMatch(featureFlag)).to(beTrue())

                expect(event.data) == .null
                expect(event.endDate).to(beNil())
                expect(event.flagRequestTracker).to(beNil())
            }
        }
    }

    private func debugEventSpec() {
        describe("debugEvent") {
            it("creates a debug event with matching data") {
                let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
                let user = LDUser.stub()
                let event = Event.debugEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user, includeReason: false)

                expect(event.kind) == Event.Kind.debug
                expect(event.key) == Constants.eventKey
                expect(event.creationDate).toNot(beNil())
                expect(event.user) == user
                expect(event.value) == true
                expect(event.defaultValue) == false
                expect(event.featureFlag?.allPropertiesMatch(featureFlag)).to(beTrue())

                expect(event.data) == .null
                expect(event.endDate).to(beNil())
                expect(event.flagRequestTracker).to(beNil())
            }
        }
    }

    private func customEventSpec() {
        var user: LDUser!
        beforeEach {
            user = LDUser.stub()
        }
        describe("customEvent") {
            context("with valid json data") {
                it("creates a custom event with matching data") {
                    let event = Event.customEvent(key: Constants.eventKey, user: user, data: ["abc": 123])
                    expect(event.kind) == Event.Kind.custom
                    expect(event.key) == Constants.eventKey
                    expect(event.creationDate).toNot(beNil())
                    expect(event.user) == user
                    expect(event.data) == ["abc": 123]
                    expect(event.value) == .null
                    expect(event.defaultValue) == .null
                    expect(event.endDate).to(beNil())
                    expect(event.flagRequestTracker).to(beNil())
                }
            }
            context("without data") {
                it("creates a custom event with matching data") {
                    let event = Event.customEvent(key: Constants.eventKey, user: user, data: nil)

                    expect(event.kind) == Event.Kind.custom
                    expect(event.key) == Constants.eventKey
                    expect(event.creationDate).toNot(beNil())
                    expect(event.user) == user
                    expect(event.data) == .null

                    expect(event.value) == .null
                    expect(event.defaultValue) == .null
                    expect(event.endDate).to(beNil())
                    expect(event.flagRequestTracker).to(beNil())
                }
            }
        }
    }

    private func identifyEventSpec() {
        var user: LDUser!
        var event: Event!
        beforeEach {
            user = LDUser.stub()
        }
        describe("identifyEvent") {
            beforeEach {
                event = Event.identifyEvent(user: user)
            }
            it("creates an identify event with matching data") {
                expect(event.kind) == Event.Kind.identify
                expect(event.key) == user.key
                expect(event.creationDate).toNot(beNil())
                expect(event.user) == user

                expect(event.value) == .null
                expect(event.defaultValue) == .null
                expect(event.data) == .null
                expect(event.endDate).to(beNil())
                expect(event.flagRequestTracker).to(beNil())
            }
        }
    }

    private func summaryEventSpec() {
        var event: Event!
        var flagRequestTracker: FlagRequestTracker!
        var endDate: Date!
        describe("summaryEvent") {
            context("with tracked requests") {
                beforeEach {
                    flagRequestTracker = FlagRequestTracker.stub()
                    endDate = Date()

                    event = Event.summaryEvent(flagRequestTracker: flagRequestTracker, endDate: endDate)
                }
                it("creates a summary event with matching data") {
                    expect(event.kind) == Event.Kind.summary
                    expect(event.endDate) == endDate
                    expect(event.flagRequestTracker?.startDate) == flagRequestTracker.startDate
                    expect(event.flagRequestTracker?.flagCounters) == flagRequestTracker.flagCounters

                    expect(event.key).to(beNil())
                    expect(event.creationDate).to(beNil())
                    expect(event.user).to(beNil())
                    expect(event.value) == .null
                    expect(event.defaultValue) == .null
                    expect(event.featureFlag).to(beNil())
                    expect(event.data) == .null
                }
            }
            context("without tracked requests") {
                beforeEach {
                    flagRequestTracker = FlagRequestTracker()
                    endDate = Date()

                    event = Event.summaryEvent(flagRequestTracker: flagRequestTracker, endDate: endDate)
                }
                it("does not create an event") {
                    expect(event).to(beNil())
                }
            }
        }
    }

    private func testAliasEventEncoding() {
        it("alias event encoding") {
            let user = LDUser(key: "abc")
            let anonUser = LDUser(key: "anon", isAnonymous: true)
            let event = Event.aliasEvent(newUser: user, oldUser: anonUser)
            encodesToObject(event) { dict in
                expect(dict.count) == 6
                expect(dict["kind"]) == "alias"
                expect(dict["key"]) == .string(user.key)
                expect(dict["previousKey"]) == .string(anonUser.key)
                expect(dict["contextKind"]) == "user"
                expect(dict["previousContextKind"]) == "anonymousUser"
                expect(dict["creationDate"]) == LDValue.fromAny(event.creationDate?.millisSince1970)
            }
        }
    }

    private func testCustomEventEncoding() {
        let user = LDUser.stub()
        context("custom event") {
            it("encodes with data and metric") {
                let event = Event.customEvent(key: "event-key", user: user, data: ["abc", 12], metricValue: 0.5)
                encodesToObject(event) { dict in
                    expect(dict.count) == 6
                    expect(dict["kind"]) == "custom"
                    expect(dict["key"]) == "event-key"
                    expect(dict["data"]) == ["abc", 12]
                    expect(dict["metricValue"]) == 0.5
                    expect(dict["userKey"]) == .string(user.key)
                    expect(dict["creationDate"]) == LDValue.fromAny(event.creationDate?.millisSince1970)
                }
            }
            it("encodes with only data and anon user") {
                let anonUser = LDUser()
                let event = Event.customEvent(key: "event-key", user: anonUser, data: ["key": "val"])
                encodesToObject(event) { dict in
                    expect(dict.count) == 6
                    expect(dict["kind"]) == "custom"
                    expect(dict["key"]) == "event-key"
                    expect(dict["data"]) == ["key": "val"]
                    expect(dict["userKey"]) == .string(anonUser.key)
                    expect(dict["contextKind"]) == "anonymousUser"
                    expect(dict["creationDate"]) == LDValue.fromAny(event.creationDate?.millisSince1970)
                }
            }
            it("encodes inlining user") {
                let event = Event.customEvent(key: "event-key", user: user, data: nil, metricValue: 2.5)
                encodesToObject(event, userInfo: [Event.UserInfoKeys.inlineUserInEvents: true]) { dict in
                    expect(dict.count) == 5
                    expect(dict["kind"]) == "custom"
                    expect(dict["key"]) == "event-key"
                    expect(dict["metricValue"]) == 2.5
                    expect(dict["user"]) == encodeToLDValue(user)
                    expect(dict["creationDate"]) == LDValue.fromAny(event.creationDate?.millisSince1970)
                }
            }
        }
    }

    private func testDebugEventEncoding() {
        let user = LDUser.stub()
        it("encodes without reason by default") {
            let featureFlag = FeatureFlag(flagKey: "flag-key", variation: 2, flagVersion: 3, reason: ["kind": "OFF"])
            let event = Event.debugEvent(key: "event-key", value: true, defaultValue: false, featureFlag: featureFlag, user: user, includeReason: false)
            encodesToObject(event) { dict in
                expect(dict.count) == 8
                expect(dict["kind"]) == "debug"
                expect(dict["key"]) == "event-key"
                expect(dict["value"]) == true
                expect(dict["default"]) == false
                expect(dict["variation"]) == 2
                expect(dict["version"]) == 3
                expect(dict["user"]) == encodeToLDValue(user)
                expect(dict["creationDate"]) == LDValue.fromAny(event.creationDate?.millisSince1970)
            }
        }
        it("encodes with reason when includeReason is true") {
            let featureFlag = FeatureFlag(flagKey: "flag-key", variation: 2, version: 2, flagVersion: 3, reason: ["kind": "OFF"])
            let event = Event.debugEvent(key: "event-key", value: 3, defaultValue: 4, featureFlag: featureFlag, user: user, includeReason: true)
            encodesToObject(event) { dict in
                expect(dict.count) == 9
                expect(dict["kind"]) == "debug"
                expect(dict["key"]) == "event-key"
                expect(dict["value"]) == 3
                expect(dict["default"]) == 4
                expect(dict["variation"]) == 2
                expect(dict["version"]) == 3
                expect(dict["reason"]) == ["kind": "OFF"]
                expect(dict["user"]) == encodeToLDValue(user)
                expect(dict["creationDate"]) == LDValue.fromAny(event.creationDate?.millisSince1970)
            }
        }
        it("encodes with reason when trackReason is true") {
            let featureFlag = FeatureFlag(flagKey: "flag-key", reason: ["kind": "OFF"], trackReason: true)
            let event = Event.debugEvent(key: "event-key", value: nil, defaultValue: nil, featureFlag: featureFlag, user: user, includeReason: false)
            encodesToObject(event) { dict in
                expect(dict.count) == 7
                expect(dict["kind"]) == "debug"
                expect(dict["key"]) == "event-key"
                expect(dict["value"]) == .null
                expect(dict["default"]) == .null
                expect(dict["reason"]) == ["kind": "OFF"]
                expect(dict["user"]) == encodeToLDValue(user)
                expect(dict["creationDate"]) == LDValue.fromAny(event.creationDate?.millisSince1970)
            }
        }
        it("encodes inlined user always") {
            let anonUser = LDUser()
            let featureFlag = FeatureFlag(flagKey: "flag-key", version: 3)
            let event = Event.debugEvent(key: "event-key", value: true, defaultValue: false, featureFlag: featureFlag, user: anonUser, includeReason: false)
            encodesToObject(event, userInfo: [Event.UserInfoKeys.inlineUserInEvents: false]) { dict in
                expect(dict.count) == 7
                expect(dict["kind"]) == "debug"
                expect(dict["key"]) == "event-key"
                expect(dict["value"]) == true
                expect(dict["default"]) == false
                expect(dict["version"]) == 3
                expect(dict["user"]) == encodeToLDValue(anonUser)
                expect(dict["creationDate"]) == LDValue.fromAny(event.creationDate?.millisSince1970)
            }
        }
    }

    private func testFeatureEventEncoding() {
        let user = LDUser.stub()
        it("encodes without reason by default") {
            let featureFlag = FeatureFlag(flagKey: "flag-key", variation: 2, flagVersion: 3, reason: ["kind": "OFF"])
            let event = Event.featureEvent(key: "event-key", value: true, defaultValue: false, featureFlag: featureFlag, user: user, includeReason: false)
            encodesToObject(event) { dict in
                expect(dict.count) == 8
                expect(dict["kind"]) == "feature"
                expect(dict["key"]) == "event-key"
                expect(dict["value"]) == true
                expect(dict["default"]) == false
                expect(dict["variation"]) == 2
                expect(dict["version"]) == 3
                expect(dict["userKey"]) == .string(user.key)
                expect(dict["creationDate"]) == LDValue.fromAny(event.creationDate?.millisSince1970)
            }
        }
        it("encodes with reason when includeReason is true") {
            let featureFlag = FeatureFlag(flagKey: "flag-key", variation: 2, version: 2, flagVersion: 3, reason: ["kind": "OFF"])
            let event = Event.featureEvent(key: "event-key", value: 3, defaultValue: 4, featureFlag: featureFlag, user: user, includeReason: true)
            encodesToObject(event) { dict in
                expect(dict.count) == 9
                expect(dict["kind"]) == "feature"
                expect(dict["key"]) == "event-key"
                expect(dict["value"]) == 3
                expect(dict["default"]) == 4
                expect(dict["variation"]) == 2
                expect(dict["version"]) == 3
                expect(dict["reason"]) == ["kind": "OFF"]
                expect(dict["userKey"]) == .string(user.key)
                expect(dict["creationDate"]) == LDValue.fromAny(event.creationDate?.millisSince1970)
            }
        }
        it("encodes with reason when trackReason is true") {
            let featureFlag = FeatureFlag(flagKey: "flag-key", reason: ["kind": "OFF"], trackReason: true)
            let event = Event.featureEvent(key: "event-key", value: nil, defaultValue: nil, featureFlag: featureFlag, user: user, includeReason: false)
            encodesToObject(event) { dict in
                expect(dict.count) == 7
                expect(dict["kind"]) == "feature"
                expect(dict["key"]) == "event-key"
                expect(dict["value"]) == .null
                expect(dict["default"]) == .null
                expect(dict["reason"]) == ["kind": "OFF"]
                expect(dict["userKey"]) == .string(user.key)
                expect(dict["creationDate"]) == LDValue.fromAny(event.creationDate?.millisSince1970)
            }
        }
        it("encodes inlined user when configured") {
            let featureFlag = FeatureFlag(flagKey: "flag-key", version: 3)
            let event = Event.featureEvent(key: "event-key", value: true, defaultValue: false, featureFlag: featureFlag, user: user, includeReason: false)
            encodesToObject(event, userInfo: [Event.UserInfoKeys.inlineUserInEvents: true]) { dict in
                expect(dict.count) == 7
                expect(dict["kind"]) == "feature"
                expect(dict["key"]) == "event-key"
                expect(dict["value"]) == true
                expect(dict["default"]) == false
                expect(dict["version"]) == 3
                expect(dict["user"]) == encodeToLDValue(user)
                expect(dict["creationDate"]) == LDValue.fromAny(event.creationDate?.millisSince1970)
            }
        }
        it("encodes with contextKind for anon user") {
            let anonUser = LDUser()
            let event = Event.featureEvent(key: "event-key", value: true, defaultValue: false, featureFlag: nil, user: anonUser, includeReason: false)
            encodesToObject(event) { dict in
                expect(dict.count) == 7
                expect(dict["kind"]) == "feature"
                expect(dict["key"]) == "event-key"
                expect(dict["value"]) == true
                expect(dict["default"]) == false
                expect(dict["userKey"]) == .string(anonUser.key)
                expect(dict["contextKind"]) == "anonymousUser"
                expect(dict["creationDate"]) == LDValue.fromAny(event.creationDate?.millisSince1970)
            }
        }
    }

    private func testIdentifyEventEncoding() {
        let user = LDUser.stub()
        it("identify event encoding") {
            for inlineUser in [true, false] {
                let event = Event.identifyEvent(user: user)
                encodesToObject(event, userInfo: [Event.UserInfoKeys.inlineUserInEvents: inlineUser]) { dict in
                    expect(dict.count) == 4
                    expect(dict["kind"]) == "identify"
                    expect(dict["key"]) == .string(user.key)
                    expect(dict["user"]) == encodeToLDValue(user)
                    expect(dict["creationDate"]) == LDValue.fromAny(event.creationDate?.millisSince1970)
                }
            }
        }
    }

    private func testSummaryEventEncoding() {
        it("summary event encoding") {
            let flag = FeatureFlag(flagKey: "bool-flag", variation: 1, version: 5, flagVersion: 2)
            var flagRequestTracker = FlagRequestTracker()
            flagRequestTracker.trackRequest(flagKey: "bool-flag", reportedValue: false, featureFlag: flag, defaultValue: true)
            flagRequestTracker.trackRequest(flagKey: "bool-flag", reportedValue: false, featureFlag: flag, defaultValue: true)
            let event = Event.summaryEvent(flagRequestTracker: flagRequestTracker, endDate: Date())
            encodesToObject(event) { dict in
                expect(dict.count) == 4
                expect(dict["kind"]) == "summary"
                expect(dict["startDate"]) == LDValue.fromAny(flagRequestTracker.startDate.millisSince1970)
                expect(dict["endDate"]) == LDValue.fromAny(event?.endDate?.millisSince1970)
                valueIsObject(dict["features"]) { features in
                    expect(features.count) == 1
                    let counter = FlagCounter()
                    counter.trackRequest(reportedValue: false, featureFlag: flag, defaultValue: true)
                    counter.trackRequest(reportedValue: false, featureFlag: flag, defaultValue: true)
                    expect(features["bool-flag"]) == encodeToLDValue(counter)
                }
            }
        }
    }
}

extension Event {
    static func stub(_ eventKind: Kind, with user: LDUser) -> Event {
        switch eventKind {
        case .feature:
            let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
            return Event.featureEvent(key: UUID().uuidString, value: true, defaultValue: false, featureFlag: featureFlag, user: user, includeReason: false)
        case .debug:
            let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
            return Event.debugEvent(key: UUID().uuidString, value: true, defaultValue: false, featureFlag: featureFlag, user: user, includeReason: false)
        case .identify: return Event.identifyEvent(user: user)
        case .custom: return Event.customEvent(key: UUID().uuidString, user: user, data: ["custom": .string(UUID().uuidString)])
        case .summary: return Event.summaryEvent(flagRequestTracker: FlagRequestTracker.stub())!
        case .alias: return Event.aliasEvent(newUser: LDUser(), oldUser: LDUser())
        }
    }

    static func eventKind(for count: Int) -> Kind {
        Event.Kind.allKinds[count % Event.Kind.allKinds.count]
    }
}
