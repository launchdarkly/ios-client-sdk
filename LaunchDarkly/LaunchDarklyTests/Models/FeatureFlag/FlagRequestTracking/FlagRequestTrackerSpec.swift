//
//  FlagRequestTrackerSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 6/20/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class FlagRequestTrackerSpec: QuickSpec {
    override func spec() {
        initSpec()
        trackRequestSpec()
        dictionaryValueSpec()
        hasLoggedRequestsSpec()
    }

    private func initSpec() {
        describe("init") {
            var flagRequestTracker: FlagRequestTracker!
            beforeEach {
                flagRequestTracker = FlagRequestTracker()
            }
            it("creates a tracker") {
                expect(flagRequestTracker.startDate.isWithin(0.001, of: Date())).to(beTrue())
                expect(flagRequestTracker.hasLoggedRequests) == false
            }
        }
    }

    private func trackRequestSpec() {
        describe("trackRequest") {
            var flagRequestTracker: FlagRequestTracker!
            var flagKey: LDFlagKey!
            var featureFlag: FeatureFlag!
            context("with known value") {
                context("first request") {
                    beforeEach {
                        flagRequestTracker = FlagRequestTracker()
                        flagKey = DarklyServiceMock.FlagKeys.dictionary
                        featureFlag =  DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey)

                        flagRequestTracker.trackRequest(flagKey: flagKey, reportedValue: featureFlag.value, featureFlag: featureFlag, defaultValue: featureFlag.value)
                    }
                    it("creates a flag counter for the flagKey") {
                        let flagCounter = flagRequestTracker.flagCounters[flagKey]
                        expect(flagCounter).toNot(beNil())
                        expect(AnyComparer.isEqual(flagCounter?.defaultValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                    }
                    it("creates a flag value counter for the feature flag") {
                        let flagCounter = flagRequestTracker.flagCounters[flagKey]
                        let flagValueCounter = flagCounter?.flagValueCounters.flagValueCounter(for: featureFlag)
                        expect(flagCounter?.flagValueCounters.count) == 1
                        expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(flagValueCounter?.featureFlag) == featureFlag
                        expect(flagValueCounter?.isKnown) == true
                        expect(flagValueCounter?.count) == 1
                    }
                }
                context("later request") {
                    context("with the same feature flag value") {
                        beforeEach {
                            flagRequestTracker = FlagRequestTracker.stub()
                            flagKey = DarklyServiceMock.FlagKeys.dictionary
                            featureFlag =  DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey)

                            flagRequestTracker.trackRequest(flagKey: flagKey, reportedValue: featureFlag.value, featureFlag: featureFlag, defaultValue: featureFlag.value)
                        }
                        it("increments the flag value counter for the feature flag") {
                            let flagCounter = flagRequestTracker.flagCounters[flagKey]
                            let flagValueCounter = flagCounter?.flagValueCounters.flagValueCounter(for: featureFlag)
                            expect(flagCounter?.flagValueCounters.count) == 1
                            expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                            expect(flagValueCounter?.featureFlag) == featureFlag
                            expect(flagValueCounter?.isKnown) == true
                            expect(flagValueCounter?.count) == FlagCounter.Constants.requestCount + 1
                        }
                    }
                    context("with a different feature flag value") {
                        beforeEach {
                            flagRequestTracker = FlagRequestTracker.stub()
                            flagKey = DarklyServiceMock.FlagKeys.dictionary
                            featureFlag =  DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey, useAlternateValue: true)

                            flagRequestTracker.trackRequest(flagKey: flagKey, reportedValue: featureFlag.value, featureFlag: featureFlag, defaultValue: featureFlag.value)
                        }
                        it("creates a new flag value counter for the feature flag") {
                            let flagCounter = flagRequestTracker.flagCounters[flagKey]
                            let flagValueCounter = flagCounter?.flagValueCounters.flagValueCounter(for: featureFlag)
                            expect(flagCounter?.flagValueCounters.count) == 2
                            expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                            expect(flagValueCounter?.featureFlag) == featureFlag
                            expect(flagValueCounter?.isKnown) == true
                            expect(flagValueCounter?.count) == 1
                        }
                    }
                }
            }
            context("with unknown value") {
                context("first request") {
                    beforeEach {
                        flagRequestTracker = FlagRequestTracker()
                        flagKey = DarklyServiceMock.FlagKeys.unknown

                        flagRequestTracker.trackRequest(flagKey: flagKey, reportedValue: false, featureFlag: nil, defaultValue: false)
                    }
                    it("creates a flag counter for the flagKey") {
                        let flagCounter = flagRequestTracker.flagCounters[flagKey]
                        expect(flagCounter).toNot(beNil())
                        expect(AnyComparer.isEqual(flagCounter?.defaultValue, to: false, considerNilAndNullEqual: true)).to(beTrue())
                    }
                    it("creates a flag value counter for the feature flag") {
                        let flagCounter = flagRequestTracker.flagCounters[flagKey]
                        let flagValueCounter = flagCounter?.flagValueCounters.flagValueCounter(for: nil)
                        expect(flagCounter?.flagValueCounters.count) == 1
                        expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: false, considerNilAndNullEqual: true)).to(beTrue())
                        expect(flagValueCounter?.featureFlag).to(beNil())
                        expect(flagValueCounter?.isKnown) == false
                        expect(flagValueCounter?.count) == 1
                    }
                }
                context("later request") {
                    beforeEach {
                        flagRequestTracker = FlagRequestTracker.stub()
                        flagKey = DarklyServiceMock.FlagKeys.unknown

                        flagRequestTracker.trackRequest(flagKey: flagKey, reportedValue: false, featureFlag: nil, defaultValue: false)
                    }
                    it("increments the flag value counter for the feature flag") {
                        let flagCounter = flagRequestTracker.flagCounters[flagKey]
                        let flagValueCounter = flagCounter?.flagValueCounters.flagValueCounter(for: nil)
                        expect(flagCounter?.flagValueCounters.count) == 1
                        expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: false, considerNilAndNullEqual: true)).to(beTrue())
                        expect(flagValueCounter?.featureFlag).to(beNil())
                        expect(flagValueCounter?.isKnown) == false
                        expect(flagValueCounter?.count) == FlagCounter.Constants.requestCount + 1
                    }
                }
                context("later request with a different default value") {
                    beforeEach {
                        flagRequestTracker = FlagRequestTracker.stub()
                        flagKey = DarklyServiceMock.FlagKeys.unknown

                        flagRequestTracker.trackRequest(flagKey: flagKey, reportedValue: true, featureFlag: nil, defaultValue: true)
                    }
                    it("increments the flag value counter for the feature flag") {
                        let flagCounter = flagRequestTracker.flagCounters[flagKey]
                        let flagValueCounter = flagCounter?.flagValueCounters.flagValueCounter(for: nil)
                        expect(flagCounter?.flagValueCounters.count) == 1
                        expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: true, considerNilAndNullEqual: true)).to(beTrue())
                        expect(flagValueCounter?.featureFlag).to(beNil())
                        expect(flagValueCounter?.isKnown) == false
                        expect(flagValueCounter?.count) == FlagCounter.Constants.requestCount + 1
                    }
                }
            }
        }
    }

    private func dictionaryValueSpec() {
        describe("dictionaryValue") {
            var flagRequestTracker: FlagRequestTracker!
            var trackerDictionary: [String: Any]!
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
                    expect(flagCounterDictionary.flagCounterFlagValueCounters?.count) == 1
                    guard let flagValueCounterDictionary = flagCounterDictionary.flagCounterFlagValueCounters?.first
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

    private func hasLoggedRequestsSpec() {
        describe("hasLoggedRequests") {
            var flagRequestTracker: FlagRequestTracker!
            var hasLoggedRequests: Bool!
            context("with flag counters") {
                beforeEach {
                    flagRequestTracker = FlagRequestTracker()
                    let featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.bool)
                    flagRequestTracker.trackRequest(flagKey: DarklyServiceMock.FlagKeys.bool, reportedValue: featureFlag.value, featureFlag: featureFlag, defaultValue: false)

                    hasLoggedRequests = flagRequestTracker.hasLoggedRequests
                }
                it("returns true") {
                    expect(hasLoggedRequests) == true
                }
            }
            context("without flag counters") {
                beforeEach {
                    flagRequestTracker = FlagRequestTracker()

                    hasLoggedRequests = flagRequestTracker.hasLoggedRequests
                }
                it("returns false") {
                    expect(hasLoggedRequests) == false
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
        return DarklyServiceMock.FlagKeys.knownFlags.contains(self)
    }
}
