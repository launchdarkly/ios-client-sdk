//
//  EventSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class EventSpec: QuickSpec {
    struct Constants {
        static let eventKey = "EventSpec.Event.Key"
    }

    struct CustomEvent {
        static let intData = 3
        static let doubleData = 1.414
        static let boolData = true
        static let stringData = "custom event string data"
        static let arrayData: [Any] = [12, 1.61803, true, "custom event array data"]
        static let nestedArrayData = [1, 3, 7, 12]
        static let nestedDictionaryData = ["one": 1.0, "three": 3.0, "seven": 7.0, "twelve": 12.0]
        static let dictionaryData: [String: Any] = ["dozen": 12,
                                                    "phi": 1.61803,
                                                    "true": true,
                                                    "data string": "custom event dictionary data",
                                                    "nestedArray": nestedArrayData,
                                                    "nestedDictionary": nestedDictionaryData]

        static let allData: [Any] = [intData, doubleData, boolData, stringData, arrayData, dictionaryData]
    }

    override func spec() {
        initSpec()
        kindSpec()
        featureEventSpec()
        debugEventSpec()
        customEventSpec()
        identifyEventSpec()
        summaryEventSpec()
        dictionaryValueSpec()
        dictionaryValuesSpec()
        eventDictionarySpec()
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
                    expect(AnyComparer.isEqual(event.value, to: true)).to(beTrue())
                    expect(AnyComparer.isEqual(event.defaultValue, to: false)).to(beTrue())
                    expect(event.featureFlag?.allPropertiesMatch(featureFlag)).to(beTrue())
                    expect(event.data).toNot(beNil())
                    expect(AnyComparer.isEqual(event.data, to: CustomEvent.dictionaryData)).to(beTrue())
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
                    expect(event.value).to(beNil())
                    expect(event.defaultValue).to(beNil())
                    expect(event.featureFlag).to(beNil())
                    expect(event.data).to(beNil())
                    expect(event.flagRequestTracker).to(beNil())
                    expect(event.endDate).to(beNil())
                }
            }
        }
    }

    private func kindSpec() {
        describe("isAlwaysInlineUserKind") {
            it("returns true when event kind should inline user") {
                for kind in Event.Kind.allKinds {
                    expect(kind.isAlwaysInlineUserKind) == Event.Kind.alwaysInlineUserKinds.contains(kind)
                }
            }
        }
    }

    private func featureEventSpec() {
        var user: LDUser!
        var event: Event!
        var featureFlag: FeatureFlag!
        beforeEach {
            featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
            user = LDUser.stub()
        }
        describe("featureEvent") {
            beforeEach {
                event = Event.featureEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user, includeReason: false)
            }
            it("creates a feature event with matching data") {
                expect(event.kind) == Event.Kind.feature
                expect(event.key) == Constants.eventKey
                expect(event.creationDate).toNot(beNil())
                expect(event.user) == user
                expect(AnyComparer.isEqual(event.value, to: true)).to(beTrue())
                expect(AnyComparer.isEqual(event.defaultValue, to: false)).to(beTrue())
                expect(event.featureFlag?.allPropertiesMatch(featureFlag)).to(beTrue())

                expect(event.data).to(beNil())
                expect(event.endDate).to(beNil())
                expect(event.flagRequestTracker).to(beNil())
            }
        }
    }

    private func debugEventSpec() {
        var user: LDUser!
        var event: Event!
        var featureFlag: FeatureFlag!
        beforeEach {
            featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
            user = LDUser.stub()
        }
        describe("debugEvent") {
            beforeEach {
                event = Event.debugEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user, includeReason: false)
            }
            it("creates a debug event with matching data") {
                expect(event.kind) == Event.Kind.debug
                expect(event.key) == Constants.eventKey
                expect(event.creationDate).toNot(beNil())
                expect(event.user) == user
                expect(AnyComparer.isEqual(event.value, to: true)).to(beTrue())
                expect(AnyComparer.isEqual(event.defaultValue, to: false)).to(beTrue())
                expect(event.featureFlag?.allPropertiesMatch(featureFlag)).to(beTrue())

                expect(event.data).to(beNil())
                expect(event.endDate).to(beNil())
                expect(event.flagRequestTracker).to(beNil())
            }
        }
    }

    private func customEventSpec() {
        var user: LDUser!
        var event: Event!
        beforeEach {
            user = LDUser.stub()
        }
        describe("customEvent") {
            for eventData in CustomEvent.allData {
                context("with valid json data") {
                    it("creates a custom event with matching data") {
                        expect(event = try Event.customEvent(key: Constants.eventKey, user: user, data: eventData)).toNot(throwError())

                        expect(event.kind) == Event.Kind.custom
                        expect(event.key) == Constants.eventKey
                        expect(event.creationDate).toNot(beNil())
                        expect(event.user) == user
                        expect(AnyComparer.isEqual(event.data, to: eventData)).to(beTrue())

                        expect(event.value).to(beNil())
                        expect(event.defaultValue).to(beNil())
                        expect(event.endDate).to(beNil())
                        expect(event.flagRequestTracker).to(beNil())
                    }
                }
            }
            context("with invalid json data") {
                it("throws an invalidJsonObject error") {
                    expect(event = try Event.customEvent(key: Constants.eventKey, user: user, data: Date())).to(throwError(errorType: LDInvalidArgumentError.self))
                }
            }
            context("without data") {
                it("creates a custom event with matching data") {
                    expect(event = try Event.customEvent(key: Constants.eventKey, user: user, data: nil)).toNot(throwError())

                    expect(event.kind) == Event.Kind.custom
                    expect(event.key) == Constants.eventKey
                    expect(event.creationDate).toNot(beNil())
                    expect(event.user) == user
                    expect(event.data).to(beNil())

                    expect(event.value).to(beNil())
                    expect(event.defaultValue).to(beNil())
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

                expect(event.value).to(beNil())
                expect(event.defaultValue).to(beNil())
                expect(event.data).to(beNil())
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
                    expect(event.flagRequestTracker) == flagRequestTracker

                    expect(event.key).to(beNil())
                    expect(event.creationDate).to(beNil())
                    expect(event.user).to(beNil())
                    expect(event.value).to(beNil())
                    expect(event.defaultValue).to(beNil())
                    expect(event.featureFlag).to(beNil())
                    expect(event.data).to(beNil())
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

    private func dictionaryValueSpec() {
        describe("dictionaryValue") {
            dictionaryValueFeatureEventSpec()
            dictionaryValueIdentifyEventSpec()
            dictionaryValueCustomEventSpec()
            dictionaryValueDebugEventSpec()
            dictionaryValueSummaryEventSpec()
        }
    }

    private func dictionaryValueFeatureEventSpec() {
        var config: LDConfig!
        let user = LDUser.stub()
        var featureFlag: FeatureFlag!
        var event: Event!
        var eventDictionary: [String: Any]!
        context("feature event") {
            beforeEach {
                config = LDConfig.stub
                featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
            }
            context("without inlining user and with reason") {
                beforeEach {
                    let featureFlagWithReason = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, includeEvaluationReason: true, includeTrackReason: true)
                    event = Event.featureEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlagWithReason, user: user, includeReason: true)
                    config.inlineUserInEvents = false   //Default value, here for clarity
                    eventDictionary = event.dictionaryValue(config: config)
                }
                it("creates a dictionary with matching non-user elements") {
                    expect(eventDictionary.eventKind) == .feature
                    expect(eventDictionary.eventKey) == Constants.eventKey
                    expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventValue, to: true)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: false)).to(beTrue())
                    expect(eventDictionary.eventVariation) == featureFlag.variation
                    expect(eventDictionary.eventVersion) == featureFlag.flagVersion     //Since feature flags include the flag version, it should be used.
                    expect(eventDictionary.eventData).to(beNil())
                    expect(AnyComparer.isEqual(eventDictionary.reason, to: DarklyServiceMock.Constants.reason)).to(beTrue())
                }
                it("creates a dictionary with the user key only") {
                    expect(eventDictionary.eventUserKey) == user.key
                    expect(eventDictionary.eventUser).to(beNil())
                }
            }
            context("inlining user and without reason") {
                beforeEach {
                    event = Event.featureEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user, includeReason: false)
                    config.inlineUserInEvents = true
                    eventDictionary = event.dictionaryValue(config: config)
                }
                it("creates a dictionary with matching non-user elements") {
                    expect(eventDictionary.eventKind) == .feature
                    expect(eventDictionary.eventKey) == Constants.eventKey
                    expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventValue, to: true)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: false)).to(beTrue())
                    expect(eventDictionary.eventVariation) == featureFlag.variation
                    expect(eventDictionary.eventVersion) == featureFlag.flagVersion     //Since feature flags include the flag version, it should be used.
                    expect(eventDictionary.eventData).to(beNil())
                    expect(eventDictionary.reason).to(beNil())
                }
                it("creates a dictionary with the full user") {
                    expect(AnyComparer.isEqual(eventDictionary.eventUserDictionary, to: user.dictionaryValue(includePrivateAttributes: false, config: config))).to(beTrue())
                    expect(eventDictionary.eventUserKey).to(beNil())
                }
            }
            context("omitting the flagVersion") {
                beforeEach {
                    featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, includeFlagVersion: false, includeEvaluationReason: true)
                    event = Event.featureEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user, includeReason: false)
                    eventDictionary = event.dictionaryValue(config: config)
                }
                it("creates a dictionary with the version") {
                    expect(eventDictionary.eventKind) == .feature
                    expect(eventDictionary.eventKey) == Constants.eventKey
                    expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventValue, to: true)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: false)).to(beTrue())
                    expect(eventDictionary.eventUserKey) == user.key
                    expect(eventDictionary.eventUser).to(beNil())
                    expect(eventDictionary.eventVariation) == featureFlag.variation
                    expect(eventDictionary.eventVersion) == featureFlag.version
                    expect(eventDictionary.eventData).to(beNil())
                }
            }
            context("omitting flagVersion and version") {
                beforeEach {
                    featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, includeVersion: false, includeFlagVersion: false, includeEvaluationReason: true, includeTrackReason: false)
                    event = Event.featureEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user, includeReason: false)
                    eventDictionary = event.dictionaryValue(config: config)
                }
                it("creates a dictionary without the version") {
                    expect(eventDictionary.eventKind) == .feature
                    expect(eventDictionary.eventKey) == Constants.eventKey
                    expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventValue, to: true)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: false)).to(beTrue())
                    expect(eventDictionary.eventUserKey) == user.key
                    expect(eventDictionary.eventUser).to(beNil())
                    expect(eventDictionary.eventVariation) == featureFlag.variation
                    expect(eventDictionary.eventVersion).to(beNil())
                    expect(eventDictionary.eventData).to(beNil())
                }
            }
            context("without value or defaultValue") {
                beforeEach {
                    featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.null)
                    event = Event.featureEvent(key: Constants.eventKey, value: nil, defaultValue: nil, featureFlag: featureFlag, user: user, includeReason: false)
                    eventDictionary = event.dictionaryValue(config: config)
                }
                it("creates a dictionary with matching non-user elements") {
                    expect(eventDictionary.eventKind) == .feature
                    expect(eventDictionary.eventKey) == Constants.eventKey
                    expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventValue, to: NSNull())).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: NSNull())).to(beTrue())
                    expect(eventDictionary.eventVariation) == featureFlag.variation
                    expect(eventDictionary.eventVersion) == featureFlag.flagVersion     //Since feature flags include the flag version, it should be used.
                    expect(eventDictionary.eventData).to(beNil())
                }
                it("creates a dictionary with the user key only") {
                    expect(eventDictionary.eventUserKey) == user.key
                    expect(eventDictionary.eventUser).to(beNil())
                }
            }
        }
    }

    private func dictionaryValueIdentifyEventSpec() {
        var config: LDConfig!
        let user = LDUser.stub()
        var event: Event!
        var eventDictionary: [String: Any]!
        context("identify event") {
            beforeEach {
                config = LDConfig.stub
                event = Event.identifyEvent(user: user)
            }
            it("creates a dictionary with the full user and matching non-user elements") {
                for inlineUser in [true, false] {
                    config.inlineUserInEvents = inlineUser
                    eventDictionary = event.dictionaryValue(config: config)

                    expect(eventDictionary.eventKind) == .identify
                    expect(eventDictionary.eventKey) == user.key
                    expect(eventDictionary.eventCreationDate?.isWithin(0.1, of: event.creationDate!)).to(beTrue())
                    expect(eventDictionary.eventValue).to(beNil())
                    expect(eventDictionary.eventDefaultValue).to(beNil())
                    expect(eventDictionary.eventVariation).to(beNil())
                    expect(eventDictionary.eventData).to(beNil())
                    expect(AnyComparer.isEqual(eventDictionary.eventUserDictionary, to: user.dictionaryValue(includePrivateAttributes: false, config: config))).to(beTrue())
                    expect(eventDictionary.eventUserKey).to(beNil())
                }
            }
        }
    }

    private func dictionaryValueCustomEventSpec() {
        var config: LDConfig!
        let user = LDUser.stub()
        var event: Event!
        var eventDictionary: [String: Any]!
        var metricValue: Double!
        context("custom event") {
            beforeEach {
                config = LDConfig.stub
            }
            metricValue = 0.5
            for eventData in CustomEvent.allData {
                context("with valid json data") {
                    beforeEach {
                        do {
                            event = try Event.customEvent(key: Constants.eventKey, user: user, data: eventData, metricValue: metricValue)
                        } catch is LDInvalidArgumentError {
                            fail("customEvent threw an invalid argument exception")
                        } catch {
                            fail("customEvent threw an exception")
                        }
                        eventDictionary = event.dictionaryValue(config: config)
                    }
                    it("creates a dictionary with matching custom data") {
                        expect(eventDictionary.eventKind) == .custom
                        expect(eventDictionary.eventKey) == Constants.eventKey
                        expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                        expect(AnyComparer.isEqual(eventDictionary.eventData, to: eventData)).to(beTrue())
                        expect(eventDictionary.eventValue).to(beNil())
                        expect(eventDictionary.eventDefaultValue).to(beNil())
                        expect(eventDictionary.eventVariation).to(beNil())
                        expect(eventDictionary.eventUserKey) == user.key
                        expect(eventDictionary.eventUser).to(beNil())
                        expect(eventDictionary.eventMetricValue) == metricValue
                    }
                }
            }
            context("without data") {
                beforeEach {
                    do {
                        event = try Event.customEvent(key: Constants.eventKey, user: user, data: nil)
                    } catch is LDInvalidArgumentError {
                        fail("customEvent threw an invalid argument exception")
                    } catch {
                        fail("customEvent threw an exception")
                    }
                    eventDictionary = event.dictionaryValue(config: config)
                }
                it("creates a dictionary with matching custom data") {
                    expect(eventDictionary.eventKind) == .custom
                    expect(eventDictionary.eventKey) == Constants.eventKey
                    expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                    expect(eventDictionary.eventData).to(beNil())
                    expect(eventDictionary.eventValue).to(beNil())
                    expect(eventDictionary.eventDefaultValue).to(beNil())
                    expect(eventDictionary.eventVariation).to(beNil())
                    expect(eventDictionary.eventUserKey) == user.key
                    expect(eventDictionary.eventUser).to(beNil())
                }
            }
            context("without inlining user") {
                beforeEach {
                    do {
                        event = try Event.customEvent(key: Constants.eventKey, user: user, data: CustomEvent.dictionaryData)
                    } catch is LDInvalidArgumentError {
                        fail("customEvent threw an invalid argument exception")
                    } catch {
                        fail("customEvent threw an exception")
                    }
                    config.inlineUserInEvents = false   //Default value, here for clarity
                    eventDictionary = event.dictionaryValue(config: config)
                }
                it("creates a dictionary with matching non-user elements") {
                    expect(eventDictionary.eventKind) == .custom
                    expect(eventDictionary.eventKey) == Constants.eventKey
                    expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventData, to: CustomEvent.dictionaryData)).to(beTrue())
                    expect(eventDictionary.eventValue).to(beNil())
                    expect(eventDictionary.eventDefaultValue).to(beNil())
                    expect(eventDictionary.eventVariation).to(beNil())
                }
                it("creates a dictionary with the user key only") {
                    expect(eventDictionary.eventUserKey) == user.key
                    expect(eventDictionary.eventUser).to(beNil())
                }
            }
            context("inlining user") {
                beforeEach {
                    do {
                        event = try Event.customEvent(key: Constants.eventKey, user: user, data: CustomEvent.dictionaryData)
                    } catch is LDInvalidArgumentError {
                        fail("customEvent threw an invalid argument exception")
                    } catch {
                        fail("customEvent threw an exception")
                    }
                    config.inlineUserInEvents = true
                    eventDictionary = event.dictionaryValue(config: config)
                }
                it("creates a dictionary with matching non-user elements") {
                    expect(eventDictionary.eventKind) == .custom
                    expect(eventDictionary.eventKey) == Constants.eventKey
                    expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventData, to: CustomEvent.dictionaryData)).to(beTrue())
                    expect(eventDictionary.eventValue).to(beNil())
                    expect(eventDictionary.eventDefaultValue).to(beNil())
                    expect(eventDictionary.eventVariation).to(beNil())
                }
                it("creates a dictionary with the full user") {
                    expect(AnyComparer.isEqual(eventDictionary.eventUserDictionary, to: user.dictionaryValue(includePrivateAttributes: false, config: config))).to(beTrue())
                    expect(eventDictionary.eventUserKey).to(beNil())
                }
            }
        }
    }

    private func dictionaryValueDebugEventSpec() {
        var config: LDConfig!
        let user = LDUser.stub()
        var featureFlag: FeatureFlag!
        var event: Event!
        var eventDictionary: [String: Any]!
        context("debug event") {
            beforeEach {
                config = LDConfig.stub
                featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
            }
            context("regardless of inlining user") {
                beforeEach {
                    event = Event.debugEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user, includeReason: false)
                }
                [true, false].forEach { inlineUser in
                    it("creates a dictionary with matching non-user elements") {
                        config.inlineUserInEvents = inlineUser
                        eventDictionary = event.dictionaryValue(config: config)

                        expect(eventDictionary.eventKind) == .debug
                        expect(eventDictionary.eventKey) == Constants.eventKey
                        expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                        expect(AnyComparer.isEqual(eventDictionary.eventValue, to: true)).to(beTrue())
                        expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: false)).to(beTrue())
                        expect(eventDictionary.eventVariation) == featureFlag.variation
                        expect(eventDictionary.eventVersion) == featureFlag.flagVersion     //Since feature flags include the flag version, it should be used.
                        expect(eventDictionary.eventData).to(beNil())
                    }
                    it("creates a dictionary with the full user") {
                        config.inlineUserInEvents = inlineUser
                        eventDictionary = event.dictionaryValue(config: config)

                        expect(AnyComparer.isEqual(eventDictionary.eventUserDictionary, to: user.dictionaryValue(includePrivateAttributes: false, config: config))).to(beTrue())
                        expect(eventDictionary.eventUserKey).to(beNil())
                    }
                }
            }
            context("omitting the flagVersion") {
                beforeEach {
                    featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, includeFlagVersion: false)
                    event = Event.debugEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user, includeReason: false)
                    eventDictionary = event.dictionaryValue(config: config)
                }
                it("creates a dictionary with the version") {
                    expect(eventDictionary.eventKind) == .debug
                    expect(eventDictionary.eventKey) == Constants.eventKey
                    expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventValue, to: true)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: false)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventUserDictionary, to: user.dictionaryValue(includePrivateAttributes: false, config: config))).to(beTrue())
                    expect(eventDictionary.eventUserKey).to(beNil())
                    expect(eventDictionary.eventVariation) == featureFlag.variation
                    expect(eventDictionary.eventVersion) == featureFlag.version
                    expect(eventDictionary.eventData).to(beNil())
                }
            }
            context("omitting flagVersion and version") {
                beforeEach {
                    featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, includeVersion: false, includeFlagVersion: false)
                    event = Event.debugEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user, includeReason: false)
                    eventDictionary = event.dictionaryValue(config: config)
                }
                it("creates a dictionary without the version") {
                    expect(eventDictionary.eventKind) == .debug
                    expect(eventDictionary.eventKey) == Constants.eventKey
                    expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventValue, to: true)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: false)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventUserDictionary, to: user.dictionaryValue(includePrivateAttributes: false, config: config))).to(beTrue())
                    expect(eventDictionary.eventUserKey).to(beNil())
                    expect(eventDictionary.eventVariation) == featureFlag.variation
                    expect(eventDictionary.eventVersion).to(beNil())
                    expect(eventDictionary.eventData).to(beNil())
                }
            }
            context("without value or defaultValue") {
                beforeEach {
                    featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.null)
                    event = Event.debugEvent(key: Constants.eventKey, value: nil, defaultValue: nil, featureFlag: featureFlag, user: user, includeReason: false)
                    eventDictionary = event.dictionaryValue(config: config)
                }
                it("creates a dictionary with matching non-user elements") {
                    expect(eventDictionary.eventKind) == .debug
                    expect(eventDictionary.eventKey) == Constants.eventKey
                    expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventValue, to: NSNull())).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: NSNull())).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventUserDictionary, to: user.dictionaryValue(includePrivateAttributes: false, config: config))).to(beTrue())
                    expect(eventDictionary.eventUserKey).to(beNil())
                    expect(eventDictionary.eventVariation) == featureFlag.variation
                    expect(eventDictionary.eventVersion) == featureFlag.flagVersion     //Since feature flags include the flag version, it should be used.
                    expect(eventDictionary.eventData).to(beNil())
                }
            }
        }
    }

    private func dictionaryValueSummaryEventSpec() {
        var config: LDConfig!
        var event: Event!
        var eventDictionary: [String: Any]!
        context("summary event") {
            beforeEach {
                config = LDConfig.stub
                event = Event.summaryEvent(flagRequestTracker: FlagRequestTracker.stub(), endDate: Date())

                eventDictionary = event.dictionaryValue(config: config)
            }
            it("creates a summary dictionary with matching elements") {
                expect(eventDictionary.eventKind) == .summary
                expect(eventDictionary.eventStartDate?.isWithin(0.001, of: event.flagRequestTracker?.startDate)).to(beTrue())
                expect(eventDictionary.eventEndDate?.isWithin(0.001, of: event.endDate)).to(beTrue())
                guard let features = eventDictionary.eventFeatures
                else {
                    fail("expected eventDictionary features to not be nil, got nil")
                    return
                }
                expect(features.count) == event.flagRequestTracker?.flagCounters.count
                event.flagRequestTracker?.flagCounters.forEach { flagKey, flagCounter in
                    guard let flagCounterDictionary = features[flagKey] as? [String: Any]
                    else {
                        fail("expected features to contain flag counter for \(flagKey), got nil")
                        return
                    }
                    expect(AnyComparer.isEqual(flagCounterDictionary, to: flagCounter.dictionaryValue, considerNilAndNullEqual: true)).to(beTrue())
                }

                expect(eventDictionary.eventKey).to(beNil())
                expect(eventDictionary.eventCreationDate).to(beNil())
                expect(eventDictionary.eventUser).to(beNil())
                expect(eventDictionary.eventUserKey).to(beNil())
                expect(eventDictionary.eventValue).to(beNil())
                expect(eventDictionary.eventDefaultValue).to(beNil())
                expect(eventDictionary.eventVariation).to(beNil())
                expect(eventDictionary.eventVersion).to(beNil())
                expect(eventDictionary.eventData).to(beNil())
            }
        }
    }

    private func dictionaryValuesSpec() {
        let config = LDConfig.stub
        let user = LDUser.stub()
        describe("dictionaryValues") {
            var events: [Event]!
            var eventDictionaries: [[String: Any]]!
            beforeEach {
                events = Event.stubEvents(for: user)

                eventDictionaries = events.dictionaryValues(config: config)
            }
            it("creates an array of event dictionaries with matching elements") {
                expect(eventDictionaries.count) == events.count
                events.forEach { event in
                    expect(eventDictionaries.eventDictionary(for: event)).toNot(beNil())
                    guard let eventDictionary = eventDictionaries.eventDictionary(for: event)
                    else { return }
                    expect(eventDictionary.eventKind) == event.kind
                    if let eventCreationDate = event.creationDate {
                        expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: eventCreationDate)).to(beTrue())
                    }
                    if event.kind.isAlwaysInlineUserKind {
                        expect(AnyComparer.isEqual(eventDictionary.eventUserDictionary, to: user.dictionaryValue(includePrivateAttributes: false, config: config))).to(beTrue())
                        expect(eventDictionary.eventUserKey).to(beNil())
                    } else {
                        if let eventUserKey = event.user?.key {
                            expect(eventDictionary.eventUserKey) == eventUserKey
                        }
                        expect(eventDictionary.eventUser).to(beNil())
                    }
                    if let eventValue = event.value {
                        expect(AnyComparer.isEqual(eventDictionary.eventValue, to: eventValue)).to(beTrue())
                    } else {
                        expect(eventDictionary.eventValue).to(beNil())
                    }
                    if let eventDefaultValue = event.defaultValue {
                        expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: eventDefaultValue)).to(beTrue())
                    } else {
                        expect(eventDictionary.eventDefaultValue).to(beNil())
                    }
                    if let eventVariation = event.featureFlag?.variation {
                        expect(eventDictionary.eventVariation) == eventVariation
                    } else {
                        expect(eventDictionary.eventVariation).to(beNil())
                    }
                    if let eventFlagVersion = event.featureFlag?.flagVersion {
                        expect(eventDictionary.eventVersion) == eventFlagVersion
                    } else {
                        expect(eventDictionary.eventVersion).to(beNil())
                    }
                    if let eventData = event.data {
                        expect(eventDictionary.eventData).toNot(beNil())
                        if let eventDictionaryData = eventDictionary.eventData {
                            expect(AnyComparer.isEqual(eventDictionaryData, to: eventData)).to(beTrue())
                        }
                    } else {
                        expect(eventDictionary.eventData).to(beNil())
                    }
                }
            }
        }
    }

    //Dictionary extension methods that extract an event key, or creationDateMillis, and compare them with another dictionary
    private func eventDictionarySpec() {
        let config = LDConfig.stub
        let user = LDUser.stub()
        describe("event dictionary") {
            describe("eventKind") {
                context("when the dictionary contains the event kind") {
                    var events: [Event]!
                    var eventDictionary: [String: Any]!
                    beforeEach {
                        events = Event.stubEvents(for: user)
                    }
                    it("returns the event kind") {
                        events.forEach { event in
                            eventDictionary = event.dictionaryValue(config: config)

                            expect(eventDictionary.eventKind) == event.kind
                        }
                    }
                }
                context("when the dictionary does not contain the event kind") {
                    var eventDictionary: [String: Any]!
                    beforeEach {
                        let event = Event.stub(.custom, with: user)
                        eventDictionary = event.dictionaryValue(config: config)
                        eventDictionary.removeValue(forKey: Event.CodingKeys.kind.rawValue)
                    }
                    it("returns nil") {
                        expect(eventDictionary.eventKind).to(beNil())
                    }
                }
            }

            describe("eventKey") {
                var event: Event!
                var eventDictionary: [String: Any]!
                beforeEach {
                    event = Event.stub(.custom, with: user)
                    eventDictionary = event.dictionaryValue(config: config)
                }
                context("when the dictionary contains a key") {
                    it("returns the key") {
                        expect(eventDictionary.eventKey) == event.key
                    }
                }
                context("when the dictionary does not contain a key") {
                    beforeEach {
                        eventDictionary.removeValue(forKey: Event.CodingKeys.key.rawValue)
                    }
                    it("returns nil") {
                        expect(eventDictionary.eventKey).to(beNil())
                    }
                }
            }

            describe("eventCreationDateMillis") {
                var event: Event!
                var eventDictionary: [String: Any]!
                beforeEach {
                    event = Event.stub(.custom, with: user)
                    eventDictionary = event.dictionaryValue(config: config)
                }
                context("when the dictionary contains a creation date") {
                    it("returns the creation date millis") {
                        expect(eventDictionary.eventCreationDateMillis) == event.creationDate?.millisSince1970
                    }
                }
                context("when the dictionary does not contain a creation date") {
                    beforeEach {
                        eventDictionary.removeValue(forKey: Event.CodingKeys.creationDate.rawValue)
                    }
                    it("returns nil") {
                        expect(eventDictionary.eventCreationDateMillis).to(beNil())
                    }
                }
            }

            describe("eventEndDate") {
                var event: Event!
                var eventDictionary: [String: Any]!
                beforeEach {
                    event = Event.stub(.summary, with: user)
                    eventDictionary = event.dictionaryValue(config: config)
                }
                context("when the dictionary contains the event endDate") {
                    it("returns the event kind") {
                        expect(eventDictionary.eventEndDate?.isWithin(0.001, of: event.endDate)).to(beTrue())
                    }
                }
                context("when the dictionary does not contain the event kind") {
                    beforeEach {
                        eventDictionary.removeValue(forKey: Event.CodingKeys.endDate.rawValue)
                    }
                    it("returns nil") {
                        expect(eventDictionary.eventEndDate).to(beNil())
                    }
                }
            }

            describe("matches") {
                var eventDictionary: [String: Any]!
                var otherDictionary: [String: Any]!
                beforeEach {
                    eventDictionary = Event.stub(.custom, with: user).dictionaryValue(config: config)
                    otherDictionary = eventDictionary
                }
                context("when keys and creationDateMillis are equal") {
                    it("returns true") {
                        expect(eventDictionary.matches(eventDictionary: otherDictionary)) == true
                    }
                }
                context("when keys differ") {
                    beforeEach {
                        otherDictionary[Event.CodingKeys.key.rawValue] = otherDictionary.eventKey! + "dummy"
                    }
                    it("returns false") {
                        expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                    }
                }
                context("when creationDateMillis differ") {
                    beforeEach {
                        otherDictionary[Event.CodingKeys.creationDate.rawValue] = otherDictionary.eventCreationDateMillis! + 1
                    }
                    it("returns false") {
                        expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                    }
                }
                context("when dictionary key is nil") {
                    beforeEach {
                        eventDictionary.removeValue(forKey: Event.CodingKeys.key.rawValue)
                    }
                    it("returns false") {
                        expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                    }
                }
                context("when other dictionary key is nil") {
                    beforeEach {
                        otherDictionary.removeValue(forKey: Event.CodingKeys.key.rawValue)
                    }
                    it("returns false") {
                        expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                    }
                }
                context("when dictionary creationDateMillis is nil") {
                    beforeEach {
                        eventDictionary.removeValue(forKey: Event.CodingKeys.creationDate.rawValue)
                    }
                    it("returns false") {
                        expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                    }
                }
                context("when other dictionary creationDateMillis is nil") {
                    beforeEach {
                        otherDictionary.removeValue(forKey: Event.CodingKeys.creationDate.rawValue)
                    }
                    it("returns false") {
                        expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                    }
                }
                context("for summary event dictionaries") {
                    var event: Event!
                    beforeEach {
                        event = Event.stub(.summary, with: user)
                        eventDictionary = event.dictionaryValue(config: config)
                    }
                    context("when the kinds and endDates match") {
                        beforeEach {
                            otherDictionary = event.dictionaryValue(config: config)
                        }
                        it("returns true") {
                            expect(eventDictionary.matches(eventDictionary: otherDictionary)) == true
                        }
                    }
                    context("when the kinds do not match") {
                        beforeEach {
                            otherDictionary = event.dictionaryValue(config: config)
                            otherDictionary[Event.CodingKeys.kind.rawValue] = Event.Kind.feature.rawValue
                        }
                        it("returns false") {
                            expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                        }
                    }
                    context("when the endDates do not match") {
                        context("endDates differ") {
                            beforeEach {
                                otherDictionary = event.dictionaryValue(config: config)
                                otherDictionary[Event.CodingKeys.endDate.rawValue] = event.endDate!.addingTimeInterval(0.002).millisSince1970
                            }
                            it("returns false") {
                                expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                            }
                        }
                        context("endDate is nil") {
                            beforeEach {
                                eventDictionary.removeValue(forKey: Event.CodingKeys.endDate.rawValue)
                                otherDictionary = event.dictionaryValue(config: config)
                            }
                            it("returns false") {
                                expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                            }
                        }
                        context("other endDate is nil") {
                            beforeEach {
                                otherDictionary = event.dictionaryValue(config: config)
                                otherDictionary.removeValue(forKey: Event.CodingKeys.endDate.rawValue)
                            }
                            it("returns false") {
                                expect(eventDictionary.matches(eventDictionary: otherDictionary)) == false
                            }
                        }
                    }
                }
            }
        }
    }
}

extension Dictionary where Key == String, Value == Any {
    var eventCreationDate: Date? {
        Date(millisSince1970: self[Event.CodingKeys.creationDate.rawValue] as? Int64)
    }
    var eventUserKey: String? {
        self[Event.CodingKeys.userKey.rawValue] as? String
    }
    var eventUser: LDUser? {
        if let userDictionary = eventUserDictionary {
            return LDUser(userDictionary: userDictionary)
        }
        return nil
    }
    var eventUserDictionary: [String: Any]? {
        self[Event.CodingKeys.user.rawValue] as? [String: Any]
    }
    var eventValue: Any? {
        self[Event.CodingKeys.value.rawValue]
    }
    var eventDefaultValue: Any? {
        self[Event.CodingKeys.defaultValue.rawValue]
    }
    var eventVariation: Int? {
        self[Event.CodingKeys.variation.rawValue] as? Int
    }
    var eventVersion: Int? {
        self[Event.CodingKeys.version.rawValue] as? Int
    }
    var eventData: Any? {
        self[Event.CodingKeys.data.rawValue]
    }
    var eventStartDate: Date? {
        Date(millisSince1970: self[FlagRequestTracker.CodingKeys.startDate.rawValue] as? Int64)
    }
    var eventEndDate: Date? {
        Date(millisSince1970: self[Event.CodingKeys.endDate.rawValue] as? Int64)
    }
    var eventFeatures: [String: Any]? {
        self[FlagRequestTracker.CodingKeys.features.rawValue] as? [String: Any]
    }
    var eventMetricValue: Double? {
        self[Event.CodingKeys.metricValue.rawValue] as? Double
    }
    private var eventKindString: String? {
        self[Event.CodingKeys.kind.rawValue] as? String
    }
    var eventKind: Event.Kind? {
        guard let eventKindString = eventKindString
        else { return nil }
        return Event.Kind(rawValue: eventKindString)
    }
    var eventKey: String? {
        self[Event.CodingKeys.key.rawValue] as? String
    }
    var eventCreationDateMillis: Int64? {
        self[Event.CodingKeys.creationDate.rawValue] as? Int64
    }

    func matches(eventDictionary other: [String: Any]) -> Bool {
        guard let kind = eventKind
            else { return false }
        if kind == .summary {
            guard kind == other.eventKind,
                let eventEndDate = eventEndDate, eventEndDate.isWithin(0.001, of: other.eventEndDate)
                else { return false }
            return true
        }
        guard let key = eventKey, let creationDateMillis = eventCreationDateMillis,
            let otherKey = other.eventKey, let otherCreationDateMillis = other.eventCreationDateMillis
            else { return false }
        return key == otherKey && creationDateMillis == otherCreationDateMillis
    }
}

extension Array where Element == [String: Any] {
    func eventDictionary(for event: Event) -> [String: Any]? {
        let selectedDictionaries = self.filter { eventDictionary -> Bool in
            event.key == eventDictionary.eventKey
        }
        guard selectedDictionaries.count == 1
        else { return nil }
        return selectedDictionaries.first
    }
    var eventKinds: [Event.Kind] {
        self.compactMap { $0.eventKind }
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
        case .custom: return (try? Event.customEvent(key: UUID().uuidString, user: user, data: ["custom": UUID().uuidString]))!
        case .summary: return Event.summaryEvent(flagRequestTracker: FlagRequestTracker.stub())!
        }
    }

    static func stubEvents(eventCount: Int = Event.Kind.allKinds.count, for user: LDUser) -> [Event] {
        var eventStubs = [Event]()
        while eventStubs.count < eventCount {
            eventStubs.append(Event.stub(eventKind(for: eventStubs.count), with: user))
        }
        return eventStubs
    }

    static func eventKind(for count: Int) -> Kind {
        Event.Kind.allKinds[count % Event.Kind.allKinds.count]
    }

    static func stubEventDictionaries(_ eventCount: Int, user: LDUser, config: LDConfig) -> [[String: Any]] {
        let eventStubs = stubEvents(eventCount: eventCount, for: user)
        return eventStubs.map { event in
            event.dictionaryValue(config: config)
        }
    }
}
