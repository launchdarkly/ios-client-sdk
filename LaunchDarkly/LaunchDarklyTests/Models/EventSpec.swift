//
//  EventSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 10/19/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
@testable import LaunchDarkly

final class EventSpec: QuickSpec {
    struct Constants {
        static var eventCapacity: Int {
            return Event.Kind.allKinds.count
        }
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
        containsSpec()
        eventDictionarySpec()
        equalsSpec()
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
                event = Event.featureEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user)
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
                event = Event.debugEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user)
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
                        expect { event = try Event.customEvent(key: Constants.eventKey, user: user, data: eventData) }.toNot(throwError())

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
                    expect { event = try Event.customEvent(key: Constants.eventKey, user: user, data: Date()) }.to(throwError(JSONSerialization.JSONError.invalidJsonObject))
                }
            }
            context("without data") {
                it("creates a custom event with matching data") {
                    expect { event = try Event.customEvent(key: Constants.eventKey, user: user, data: nil) }.toNot(throwError())

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
            context("without inlining user") {
                beforeEach {
                    event = Event.featureEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user)
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
                }
                it("creates a dictionary with the user key only") {
                    expect(eventDictionary.eventUserKey) == user.key
                    expect(eventDictionary.eventUser).to(beNil())
                }
            }
            context("inlining user") {
                beforeEach {
                    event = Event.featureEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user)
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
                }
                it("creates a dictionary with the full user") {
                    expect(eventDictionary.eventUser).toNot(beNil())
                    if let eventDictionaryUser = eventDictionary.eventUser {
                        expect(eventDictionaryUser.key) == user.key
                        expect(eventDictionaryUser.name) == user.name
                        expect(eventDictionaryUser.firstName) == user.firstName
                        expect(eventDictionaryUser.lastName) == user.lastName
                        expect(eventDictionaryUser.country) == user.country
                        expect(eventDictionaryUser.ipAddress) == user.ipAddress
                        expect(eventDictionaryUser.email) == user.email
                        expect(eventDictionaryUser.avatar) == user.avatar
                        expect(AnyComparer.isEqual(eventDictionaryUser.custom, to: user.custom)).to(beTrue())
                        expect(eventDictionaryUser.device) == user.device
                        expect(eventDictionaryUser.operatingSystem) == user.operatingSystem
                        expect(eventDictionaryUser.isAnonymous) == user.isAnonymous
                        expect(eventDictionaryUser.privateAttributes).to(beNil())
                    }
                    expect(eventDictionary.eventUserKey).to(beNil())
                }
            }
            context("omitting the flagVersion") {
                beforeEach {
                    featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, includeFlagVersion: false)
                    event = Event.featureEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user)
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
                    featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, includeVersion: false, includeFlagVersion: false)
                    event = Event.featureEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user)
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
                    event = Event.featureEvent(key: Constants.eventKey, value: nil, defaultValue: nil, featureFlag: featureFlag, user: user)
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
                    expect(eventDictionary.eventUser).toNot(beNil())
                    if let eventDictionaryUser = eventDictionary.eventUser {
                        expect(eventDictionaryUser.key) == user.key
                        expect(eventDictionaryUser.name) == user.name
                        expect(eventDictionaryUser.firstName) == user.firstName
                        expect(eventDictionaryUser.lastName) == user.lastName
                        expect(eventDictionaryUser.country) == user.country
                        expect(eventDictionaryUser.ipAddress) == user.ipAddress
                        expect(eventDictionaryUser.email) == user.email
                        expect(eventDictionaryUser.avatar) == user.avatar
                        expect(AnyComparer.isEqual(eventDictionaryUser.custom, to: user.custom)).to(beTrue())
                        expect(eventDictionaryUser.device) == user.device
                        expect(eventDictionaryUser.operatingSystem) == user.operatingSystem
                        expect(eventDictionaryUser.isAnonymous) == user.isAnonymous
                        expect(eventDictionaryUser.privateAttributes).to(beNil())
                    }
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
        context("custom event") {
            beforeEach {
                config = LDConfig.stub
            }
            for eventData in CustomEvent.allData {
                context("with valid json data") {
                    beforeEach {
                        do {
                            event = try Event.customEvent(key: Constants.eventKey, user: user, data: eventData)
                        } catch JSONSerialization.JSONError.invalidJsonObject {
                            fail("customEvent threw an invalidJsonObject exception")
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
                    }
                }
            }
            context("without data") {
                beforeEach {
                    do {
                        event = try Event.customEvent(key: Constants.eventKey, user: user, data: nil)
                    } catch JSONSerialization.JSONError.invalidJsonObject {
                        fail("customEvent threw an invalidJsonObject exception")
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
                    } catch JSONSerialization.JSONError.invalidJsonObject {
                        fail("customEvent threw an invalidJsonObject exception")
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
                    } catch JSONSerialization.JSONError.invalidJsonObject {
                        fail("customEvent threw an invalidJsonObject exception")
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
                    expect(eventDictionary.eventUser).toNot(beNil())
                    if let eventDictionaryUser = eventDictionary.eventUser {
                        expect(eventDictionaryUser.key) == user.key
                        expect(eventDictionaryUser.name) == user.name
                        expect(eventDictionaryUser.firstName) == user.firstName
                        expect(eventDictionaryUser.lastName) == user.lastName
                        expect(eventDictionaryUser.country) == user.country
                        expect(eventDictionaryUser.ipAddress) == user.ipAddress
                        expect(eventDictionaryUser.email) == user.email
                        expect(eventDictionaryUser.avatar) == user.avatar
                        expect(AnyComparer.isEqual(eventDictionaryUser.custom, to: user.custom)).to(beTrue())
                        expect(eventDictionaryUser.device) == user.device
                        expect(eventDictionaryUser.operatingSystem) == user.operatingSystem
                        expect(eventDictionaryUser.isAnonymous) == user.isAnonymous
                        expect(eventDictionaryUser.privateAttributes).to(beNil())
                    }
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
                    event = Event.debugEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user)
                }
                [true, false].forEach { (inlineUser) in
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

                        expect(eventDictionary.eventUser).toNot(beNil())
                        if let eventDictionaryUser = eventDictionary.eventUser {
                            expect(eventDictionaryUser.key) == user.key
                            expect(eventDictionaryUser.name) == user.name
                            expect(eventDictionaryUser.firstName) == user.firstName
                            expect(eventDictionaryUser.lastName) == user.lastName
                            expect(eventDictionaryUser.country) == user.country
                            expect(eventDictionaryUser.ipAddress) == user.ipAddress
                            expect(eventDictionaryUser.email) == user.email
                            expect(eventDictionaryUser.avatar) == user.avatar
                            expect(AnyComparer.isEqual(eventDictionaryUser.custom, to: user.custom)).to(beTrue())
                            expect(eventDictionaryUser.device) == user.device
                            expect(eventDictionaryUser.operatingSystem) == user.operatingSystem
                            expect(eventDictionaryUser.isAnonymous) == user.isAnonymous
                            expect(eventDictionaryUser.privateAttributes).to(beNil())
                        }
                        expect(eventDictionary.eventUserKey).to(beNil())
                    }
                }
            }
            context("omitting the flagVersion") {
                beforeEach {
                    featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, includeFlagVersion: false)
                    event = Event.debugEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user)
                    eventDictionary = event.dictionaryValue(config: config)
                }
                it("creates a dictionary with the version") {
                    expect(eventDictionary.eventKind) == .debug
                    expect(eventDictionary.eventKey) == Constants.eventKey
                    expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventValue, to: true)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: false)).to(beTrue())
                    expect(eventDictionary.eventUser).toNot(beNil())
                    if let eventDictionaryUser = eventDictionary.eventUser {
                        expect(eventDictionaryUser.key) == user.key
                        expect(eventDictionaryUser.name) == user.name
                        expect(eventDictionaryUser.firstName) == user.firstName
                        expect(eventDictionaryUser.lastName) == user.lastName
                        expect(eventDictionaryUser.country) == user.country
                        expect(eventDictionaryUser.ipAddress) == user.ipAddress
                        expect(eventDictionaryUser.email) == user.email
                        expect(eventDictionaryUser.avatar) == user.avatar
                        expect(AnyComparer.isEqual(eventDictionaryUser.custom, to: user.custom)).to(beTrue())
                        expect(eventDictionaryUser.device) == user.device
                        expect(eventDictionaryUser.operatingSystem) == user.operatingSystem
                        expect(eventDictionaryUser.isAnonymous) == user.isAnonymous
                        expect(eventDictionaryUser.privateAttributes).to(beNil())
                    }
                    expect(eventDictionary.eventUserKey).to(beNil())
                    expect(eventDictionary.eventVariation) == featureFlag.variation
                    expect(eventDictionary.eventVersion) == featureFlag.version
                    expect(eventDictionary.eventData).to(beNil())
                }
            }
            context("omitting flagVersion and version") {
                beforeEach {
                    featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool, includeVersion: false, includeFlagVersion: false)
                    event = Event.debugEvent(key: Constants.eventKey, value: true, defaultValue: false, featureFlag: featureFlag, user: user)
                    eventDictionary = event.dictionaryValue(config: config)
                }
                it("creates a dictionary without the version") {
                    expect(eventDictionary.eventKind) == .debug
                    expect(eventDictionary.eventKey) == Constants.eventKey
                    expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventValue, to: true)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: false)).to(beTrue())
                    expect(eventDictionary.eventUser).toNot(beNil())
                    if let eventDictionaryUser = eventDictionary.eventUser {
                        expect(eventDictionaryUser.key) == user.key
                        expect(eventDictionaryUser.name) == user.name
                        expect(eventDictionaryUser.firstName) == user.firstName
                        expect(eventDictionaryUser.lastName) == user.lastName
                        expect(eventDictionaryUser.country) == user.country
                        expect(eventDictionaryUser.ipAddress) == user.ipAddress
                        expect(eventDictionaryUser.email) == user.email
                        expect(eventDictionaryUser.avatar) == user.avatar
                        expect(AnyComparer.isEqual(eventDictionaryUser.custom, to: user.custom)).to(beTrue())
                        expect(eventDictionaryUser.device) == user.device
                        expect(eventDictionaryUser.operatingSystem) == user.operatingSystem
                        expect(eventDictionaryUser.isAnonymous) == user.isAnonymous
                        expect(eventDictionaryUser.privateAttributes).to(beNil())
                    }
                    expect(eventDictionary.eventUserKey).to(beNil())
                    expect(eventDictionary.eventVariation) == featureFlag.variation
                    expect(eventDictionary.eventVersion).to(beNil())
                    expect(eventDictionary.eventData).to(beNil())
                }
            }
            context("without value or defaultValue") {
                beforeEach {
                    featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.null)
                    event = Event.debugEvent(key: Constants.eventKey, value: nil, defaultValue: nil, featureFlag: featureFlag, user: user)
                    eventDictionary = event.dictionaryValue(config: config)
                }
                it("creates a dictionary with matching non-user elements") {
                    expect(eventDictionary.eventKind) == .debug
                    expect(eventDictionary.eventKey) == Constants.eventKey
                    expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: event.creationDate!)).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventValue, to: NSNull())).to(beTrue())
                    expect(AnyComparer.isEqual(eventDictionary.eventDefaultValue, to: NSNull())).to(beTrue())
                    expect(eventDictionary.eventUser).toNot(beNil())
                    if let eventDictionaryUser = eventDictionary.eventUser {
                        expect(eventDictionaryUser.key) == user.key
                        expect(eventDictionaryUser.name) == user.name
                        expect(eventDictionaryUser.firstName) == user.firstName
                        expect(eventDictionaryUser.lastName) == user.lastName
                        expect(eventDictionaryUser.country) == user.country
                        expect(eventDictionaryUser.ipAddress) == user.ipAddress
                        expect(eventDictionaryUser.email) == user.email
                        expect(eventDictionaryUser.avatar) == user.avatar
                        expect(AnyComparer.isEqual(eventDictionaryUser.custom, to: user.custom)).to(beTrue())
                        expect(eventDictionaryUser.device) == user.device
                        expect(eventDictionaryUser.operatingSystem) == user.operatingSystem
                        expect(eventDictionaryUser.isAnonymous) == user.isAnonymous
                        expect(eventDictionaryUser.privateAttributes).to(beNil())
                    }
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
                        XCTFail("expected eventDictionary features to not be nil, got nil")
                        return
                }
                expect(features.count) == event.flagRequestTracker?.flagCounters.count
                event.flagRequestTracker?.flagCounters.forEach { (flagKey, flagCounter) in
                    guard let flagCounterDictionary = features[flagKey] as? [String: Any]
                    else {
                        XCTFail("expected features to contain flag counter for \(flagKey), got nil")
                        return
                    }
                    expect(AnyComparer.isEqual(flagCounterDictionary.flagCounterDefaultValue, to: flagCounter.defaultValue, considerNilAndNullEqual: true)).to(beTrue())
                    guard let flagValueCounters = flagCounterDictionary.flagCounterFlagValueCounters, flagValueCounters.count == flagCounter.flagValueCounters.count
                    else {
                        XCTFail("expected flag value counters for \(flagKey) to have \(flagCounter.flagValueCounters.count) entries, got \(flagCounterDictionary.flagCounterFlagValueCounters?.count ?? 0)")
                        return
                    }
                    for (index, flagValueCounter) in flagCounter.flagValueCounters.enumerated() {
                        let flagValueCounterDictionary = flagValueCounters[index]
                        expect(AnyComparer.isEqual(flagValueCounterDictionary.value, to: flagValueCounter.reportedValue, considerNilAndNullEqual: true)).to(beTrue())
                        if let featureFlag = flagValueCounter.featureFlag {
                            expect(flagValueCounterDictionary.valueCounterVariation) == featureFlag.variation
                            expect(flagValueCounterDictionary.valueCounterVersion) == featureFlag.flagVersion
                            expect(flagValueCounterDictionary.valueCounterIsUnknown).to(beNil())
                        } else {
                            expect(flagValueCounterDictionary.valueCounterVariation).to(beNil())
                            expect(flagValueCounterDictionary.valueCounterVersion).to(beNil())
                            expect(flagValueCounterDictionary.valueCounterIsUnknown) == true
                        }
                        expect(flagValueCounterDictionary.valueCounterCount) == flagValueCounter.count
                    }
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
                events.forEach { (event) in
                    expect(eventDictionaries.eventDictionary(for: event)).toNot(beNil())
                    guard let eventDictionary = eventDictionaries.eventDictionary(for: event) else {
                        return
                    }
                    expect(eventDictionary.eventKind) == event.kind
                    if let eventCreationDate = event.creationDate {
                        expect(eventDictionary.eventCreationDate?.isWithin(0.001, of: eventCreationDate)).to(beTrue())
                    }
                    if event.kind.isAlwaysInlineUserKind {
                        expect(eventDictionary.eventUser).toNot(beNil())
                        if let eventDictionaryUser = eventDictionary.eventUser {
                            expect(eventDictionaryUser.key) == user.key
                            expect(eventDictionaryUser.name) == user.name
                            expect(eventDictionaryUser.firstName) == user.firstName
                            expect(eventDictionaryUser.lastName) == user.lastName
                            expect(eventDictionaryUser.country) == user.country
                            expect(eventDictionaryUser.ipAddress) == user.ipAddress
                            expect(eventDictionaryUser.email) == user.email
                            expect(eventDictionaryUser.avatar) == user.avatar
                            expect(AnyComparer.isEqual(eventDictionaryUser.custom, to: user.custom)).to(beTrue())
                            expect(eventDictionaryUser.device) == user.device
                            expect(eventDictionaryUser.operatingSystem) == user.operatingSystem
                            expect(eventDictionaryUser.isAnonymous) == user.isAnonymous
                            expect(eventDictionaryUser.privateAttributes).to(beNil())
                        }
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

    private func containsSpec() {
        let config = LDConfig.stub
        let user = LDUser.stub()
        describe("array contains eventDictionary") {
            var eventDictionaries: [[String: Any]]!
            var targetDictionary: [String: Any]!
            beforeEach {
                eventDictionaries = Event.stubEventDictionaries(Constants.eventCapacity, user: user, config: config)
            }
            context("when the event dictionary is in the array") {
                context("at the first item") {
                    beforeEach {
                        targetDictionary = eventDictionaries.first
                    }
                    it("returns true") {
                        expect(eventDictionaries.contains(targetDictionary)) == true
                    }
                }
                context("at a middle item") {
                    beforeEach {
                        targetDictionary = eventDictionaries[eventDictionaries.startIndex.advanced(by: 1)]
                    }
                    it("returns true") {
                        expect(eventDictionaries.contains(targetDictionary)) == true
                    }
                }
                context("at the last item") {
                    beforeEach {
                        targetDictionary = eventDictionaries.last
                    }
                    it("returns true") {
                        expect(eventDictionaries.contains(targetDictionary)) == true
                    }
                }
            }
            context("when the event dictionary is not in the array") {
                beforeEach {
                    targetDictionary = Event.stub(.feature, with: user).dictionaryValue(config: config)
                }
                it("returns false") {
                    expect(eventDictionaries.contains(targetDictionary)) == false
                }
            }
            context("when the target dictionary is not an event dictionary") {
                beforeEach {
                    targetDictionary = user.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                }
                it("returns false") {
                    expect(eventDictionaries.contains(targetDictionary)) == false
                }
            }
            context("when the array doesn't contain event dictionaries") {
                beforeEach {
                    eventDictionaries = LDUser.stubUsers(Constants.eventCapacity).map { (user) in
                        user.dictionaryValue(includeFlagConfig: false, includePrivateAttributes: true, config: config)
                    }
                    targetDictionary = Event.stub(.identify, with: user).dictionaryValue(config: config)
                }
                it("returns false") {
                    expect(eventDictionaries.contains(targetDictionary)) == false
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
                        events.forEach { (event) in
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

    private func equalsSpec() {
        let user = LDUser.stub()
        describe("equals") {
            var event1: Event!
            var event2: Event!
            context("on the same event") {
                beforeEach {
                    event1 = Event(kind: .feature, key: Constants.eventKey, user: user, value: true, defaultValue: false, data: CustomEvent.dictionaryData)
                    event2 = event1
                }
                it("returns true") {
                    expect(event1) == event2
                }
            }
            context("when only the keys match") {
                let eventKey = UUID().uuidString
                beforeEach {
                    event1 = Event(kind: .feature, key: eventKey, user: LDUser.stub(key: UUID().uuidString), value: true, defaultValue: false)
                    event2 = Event(kind: .custom, key: eventKey, user: LDUser.stub(key: UUID().uuidString), data: CustomEvent.dictionaryData)
                }
                it("returns false") {
                    expect(event1) != event2
                }
            }
            context("when only the keys differ") {
                beforeEach {
                    event1 = Event(kind: .feature, key: UUID().uuidString, user: user, value: true, defaultValue: false, data: CustomEvent.dictionaryData)
                    event2 = Event(kind: .feature, key: UUID().uuidString, user: user, value: true, defaultValue: false, data: CustomEvent.dictionaryData)
                }
                it("returns false") {
                    expect(event1) != event2
                }
            }
            context("on different events") {
                beforeEach {
                    event1 = Event(kind: .feature, key: UUID().uuidString, user: user, value: true, defaultValue: false, data: CustomEvent.dictionaryData)
                    event2 = Event(kind: .identify, key: UUID().uuidString, user: LDUser.stub(key: UUID().uuidString))
                }
                it("returns false") {
                    expect(event1) != event2
                }
            }
            context("summary events") {
                beforeEach {
                    event1 = Event.stub(.summary, with: user)
                }
                context("when events match") {
                    beforeEach {
                        event2 = event1
                    }
                    it("returns true") {
                        expect(event1) == event2
                    }
                }
                context("when kinds differ") {
                    beforeEach {
                        event2 = Event(kind: .custom, flagRequestTracker: event1.flagRequestTracker, endDate: event1.endDate)
                    }
                    it("returns false") {
                        expect(event1) != event2
                    }
                }
                context("when endDates differ") {
                    beforeEach {
                        event2 = Event(kind: .summary, flagRequestTracker: event1.flagRequestTracker, endDate: event1.endDate?.addingTimeInterval(0.0011))
                    }
                    it("returns false") {
                        expect(event1) != event2
                    }
                }
            }
        }
    }
}

extension Dictionary where Key == String, Value == Any {
    var eventCreationDate: Date? {
        return Date(millisSince1970: self[Event.CodingKeys.creationDate.rawValue] as? Int64)
    }
    var eventUserKey: String? {
        return self[Event.CodingKeys.userKey.rawValue] as? String
    }
    var eventUser: LDUser? {
        return LDUser(object: self[Event.CodingKeys.user.rawValue])
    }
    var eventValue: Any? {
        return self[Event.CodingKeys.value.rawValue]
    }
    var eventDefaultValue: Any? {
        return self[Event.CodingKeys.defaultValue.rawValue]
    }
    var eventVariation: Int? {
        return self[Event.CodingKeys.variation.rawValue] as? Int
    }
    var eventVersion: Int? {
        return self[Event.CodingKeys.version.rawValue] as? Int
    }
    var eventData: Any? {
        return self[Event.CodingKeys.data.rawValue]
    }
    var eventStartDate: Date? {
        return Date(millisSince1970: self[FlagRequestTracker.CodingKeys.startDate.rawValue] as? Int64)
    }
    var eventEndDate: Date? {
        return Date(millisSince1970: self[Event.CodingKeys.endDate.rawValue] as? Int64)
    }
    var eventFeatures: [String: Any]? {
        return self[FlagRequestTracker.CodingKeys.features.rawValue] as? [String: Any]
    }
}

extension Array where Element == [String: Any] {
    func eventDictionary(for event: Event) -> [String: Any]? {
        let selectedDictionaries = self.filter { (eventDictionary) -> Bool in
            event.key == eventDictionary.eventKey
        }
        guard selectedDictionaries.count == 1 else {
            return nil
        }
        return selectedDictionaries.first
    }
    var eventKinds: [Event.Kind] {
        return self.compactMap { (eventDictionary) in return eventDictionary.eventKind }
    }
}

extension Event.Kind {
    static var random: Event.Kind {
        let index = Int(arc4random_uniform(UInt32(Event.Kind.allKinds.count) - 1))
        return Event.Kind.allKinds[index]
    }
}

extension Event {
    static func stub(_ eventKind: Kind, with user: LDUser) -> Event {
        switch eventKind {
        case .feature:
            let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
            return Event.featureEvent(key: UUID().uuidString, value: true, defaultValue: false, featureFlag: featureFlag, user: user)
        case .debug:
            let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
            return Event.debugEvent(key: UUID().uuidString, value: true, defaultValue: false, featureFlag: featureFlag, user: user)
        case .identify: return Event.identifyEvent(user: user)
        case .custom: return (try? Event.customEvent(key: UUID().uuidString, user: user, data: ["custom": UUID().uuidString]))!
        case .summary: return Event.summaryEvent(flagRequestTracker: FlagRequestTracker.stub())!
        }
    }

    static func stubFeatureEvent(_ featureFlag: FeatureFlag, with user: LDUser) -> Event {
        return Event.featureEvent(key: UUID().uuidString, value: true, defaultValue: false, featureFlag: featureFlag, user: user)
    }

    static func stubEvents(eventCount: Int = Event.Kind.allKinds.count, for user: LDUser) -> [Event] {
        var eventStubs = [Event]()
        while eventStubs.count < eventCount {
            eventStubs.append(Event.stub(eventKind(for: eventStubs.count), with: user))
        }
        return eventStubs
    }

    static func eventKind(for count: Int) -> Kind {
        return Event.Kind.allKinds[count % Event.Kind.allKinds.count]
    }

    static func stubEventDictionaries(_ eventCount: Int, user: LDUser, config: LDConfig) -> [[String: Any]] {
        let eventStubs = stubEvents(eventCount: eventCount, for: user)
        return eventStubs.map { (event) in
            event.dictionaryValue(config: config)
        }
    }

    func matches(eventDictionary: [String: Any]?) -> Bool {
        guard let eventDictionary = eventDictionary
        else {
            return false
        }
        if kind == .summary {
            return kind == eventDictionary.eventKind && endDate?.isWithin(0.001, of: eventDictionary.eventEndDate) ?? false
        }
        guard let eventDictionaryKey = eventDictionary.eventKey,
            let eventDictionaryCreationDateMillis = eventDictionary.eventCreationDateMillis
        else {
            return false
        }
        return key == eventDictionaryKey && creationDate?.millisSince1970 == eventDictionaryCreationDateMillis
    }
}

extension Array where Element == Event {
    func matches(eventDictionaries: [[String: Any]]) -> Bool {
        guard self.count == eventDictionaries.count else {
            return false
        }
        for index in self.indices {
            if !self[index].matches(eventDictionary: eventDictionaries[index]) {
                return false
            }
        }
        return true
    }
}

extension Array where Element == [String: Any] {
    func matches(events: [Event]) -> Bool {
        guard self.count == events.count else {
            return false
        }
        for index in self.indices {
            if !events[index].matches(eventDictionary: self[index]) {
                return false
            }
        }
        return true
    }
}
