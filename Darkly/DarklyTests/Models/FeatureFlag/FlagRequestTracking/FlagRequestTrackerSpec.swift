//
//  FlagRequestTrackerSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 6/20/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import Darkly

final class FlagRequestTrackerSpec: QuickSpec {
    override func spec() {
        initSpec()
        logRequestSpec()
        dictionaryValueSpec()
    }

    private func initSpec() {
        describe("init") {
            var flagRequestTracker: FlagRequestTracker!
            beforeEach {
                flagRequestTracker = FlagRequestTracker()
            }
            it("creates a tracker") {
                expect(flagRequestTracker.startDate.isWithin(0.001, of: Date())).to(beTrue())
                expect(flagRequestTracker.flagCounters.isEmpty).to(beTrue())
            }
        }
    }

    private func logRequestSpec() {
        describe("logRequest") {
            var flagRequestTracker: FlagRequestTracker!
            var featureFlag: FeatureFlag!
            context("with known value") {
                beforeEach {
                    flagRequestTracker = FlagRequestTracker()
                }
                it("logs the flag request") {
                    DarklyServiceMock.FlagKeys.all.forEach { (flagKey) in
                        for useAlternateValue in [false, true] {
                            guard !(flagKey == DarklyServiceMock.FlagKeys.null && useAlternateValue) else { return }     //skip alternate value on null since there isn't one
                            featureFlag =  DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey, useAlternateValue: useAlternateValue)
                            for logRequestCount in [1, 2, 3] {
                                flagRequestTracker.logRequest(flagKey: flagKey, reportedValue: featureFlag.value, featureFlag: featureFlag, defaultValue: featureFlag.value)

                                guard let flagCounter = flagRequestTracker.flagCounters[flagKey]
                                    else {
                                        XCTFail("expected flagCounter to not be nil, got nil")
                                        return
                                }
                                expect(AnyComparer.isEqual(flagCounter.defaultValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                                expect(flagCounter.flagValueCounters.count) == (useAlternateValue ? 2 : 1)
                                guard let flagValueCounter = flagCounter.flagValueCounters.flagValueCounter(for: featureFlag)
                                    else {
                                        XCTFail("expected flagValueCounter to not be nil, got nil")
                                        return
                                }
                                expect(AnyComparer.isEqual(flagValueCounter.reportedValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                                expect(flagValueCounter.featureFlag) == featureFlag
                                expect(flagValueCounter.isKnown) == true
                                expect(flagValueCounter.count) == logRequestCount
                            }
                        }
                    }
                }
            }
            context("with unknown value") {
                beforeEach {
                    flagRequestTracker = FlagRequestTracker()
                }
                it("logs the flag request") {
                    for logRequestCount in [1, 2, 3] {
                        flagRequestTracker.logRequest(flagKey: DarklyServiceMock.FlagKeys.dummy, reportedValue: false, featureFlag: nil, defaultValue: false)

                        guard let flagCounter = flagRequestTracker.flagCounters[DarklyServiceMock.FlagKeys.dummy]
                            else {
                                XCTFail("expected flagCounter to not be nil, got nil")
                                return
                        }
                        expect(AnyComparer.isEqual(flagCounter.defaultValue, to: false, considerNilAndNullEqual: true)).to(beTrue())
                        expect(flagCounter.flagValueCounters.count) == 1
                        guard let flagValueCounter = flagCounter.flagValueCounters.flagValueCounter(for: nil)
                            else {
                                XCTFail("expected flagValueCounter to not be nil, got nil")
                                return
                        }
                        expect(AnyComparer.isEqual(flagValueCounter.reportedValue, to: false, considerNilAndNullEqual: true)).to(beTrue())
                        expect(flagValueCounter.featureFlag).to(beNil())
                        expect(flagValueCounter.isKnown) == false
                        expect(flagValueCounter.count) == logRequestCount
                    }
                }
            }
        }
    }

    private func dictionaryValueSpec() {
        describe("dictionaryValue") {
            var flagRequestTracker: FlagRequestTracker!
            var trackerDictionary: [String: Any]!
            context("") {
                beforeEach {
                    flagRequestTracker = FlagRequestTracker.stub()

                    trackerDictionary = flagRequestTracker.dictionaryValue
                }
                it("creates a tracker dictionary") {
                    expect(trackerDictionary.flagRequestTrackerStartDate?.isWithin(0.001, of: flagRequestTracker.startDate)).to(beTrue())
                    expect(trackerDictionary.flagRequestTrackerFeatures).toNot(beNil())
                    guard let trackerDictionaryFeatures = trackerDictionary.flagRequestTrackerFeatures
                    else {
                        XCTFail("expected trackerDictionaryFeatures to not be nil, got nil")
                        return
                    }
                    flagRequestTracker.flagCounters.forEach { (flagKey, flagCounter) in
                        guard let flagCounterDictionary = trackerDictionaryFeatures[flagKey] as? [String: Any]
                        else {
                            XCTFail("expected flagCounterDictionary to not be nil, got nil")
                            return
                        }
                        expect(AnyComparer.isEqual(flagCounterDictionary.flagCounterDefaultValue, to: flagCounter.defaultValue, considerNilAndNullEqual: true)).to(beTrue())
                        expect(flagCounterDictionary.flagCounterCounters?.count) == 1
                        guard let flagValueCounterDictionary = flagCounterDictionary.flagCounterCounters?.first
                        else {
                            XCTFail("expected flagValueCounterDictionary to not be nil, got nil")
                            return
                        }
                        let flagValueCounter = flagCounter.flagValueCounters.first!
                        if flagKey.isKnown {
                            expect(AnyComparer.isEqual(flagValueCounterDictionary.valueCounterReportedValue, to: flagValueCounter.reportedValue, considerNilAndNullEqual: true)).to(beTrue())
                            expect(flagValueCounterDictionary.valueCounterVariation) == flagValueCounter.featureFlag?.variation
                            expect(flagValueCounterDictionary.valueCounterVersion) == flagValueCounter.featureFlag?.flagVersion
                            expect(flagValueCounterDictionary.valueCounterIsUnknown).to(beNil())
                        } else {
                            expect(AnyComparer.isEqual(flagValueCounterDictionary.valueCounterReportedValue, to: false, considerNilAndNullEqual: true)).to(beTrue())
                            expect(flagValueCounterDictionary.valueCounterVariation).to(beNil())
                            expect(flagValueCounterDictionary.valueCounterVersion).to(beNil())
                            expect(flagValueCounterDictionary.valueCounterIsUnknown) == true
                        }
                        expect(flagValueCounterDictionary.valueCounterCount) == flagValueCounter.count
                    }
                }
            }
        }
    }
}

extension FlagRequestTracker {
    static func stub() -> FlagRequestTracker {
        var tracker = FlagRequestTracker()
        tracker.flagCounters = FlagCounter.stubFlagCounters()
        return tracker
    }
}

extension Dictionary where Key == String, Value == Any {
    var flagRequestTrackerStartDateMillis: Int64? {
        return self[FlagRequestTracker.CodingKeys.startDate.rawValue] as? Int64
    }
    var flagRequestTrackerStartDate: Date? {
        return Date(millisSince1970: flagRequestTrackerStartDateMillis)
    }
    var flagRequestTrackerFeatures: [LDFlagKey: Any]? {
        return self[FlagRequestTracker.CodingKeys.features.rawValue] as? [LDFlagKey: Any]
    }
}

extension LDFlagKey {
    var isKnown: Bool {
        return DarklyServiceMock.FlagKeys.all.contains(self)
    }
}
