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

                                guard let flagCounter = flagRequestTracker.flagCounters.flagCounter(for: flagKey)
                                    else {
                                        XCTFail("expected flagCounter to not be nil, got nil")
                                        return
                                }
                                expect(flagCounter.flagKey) == flagKey
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

                        guard let flagCounter = flagRequestTracker.flagCounters.flagCounter(for: DarklyServiceMock.FlagKeys.dummy)
                            else {
                                XCTFail("expected flagCounter to not be nil, got nil")
                                return
                        }
                        expect(flagCounter.flagKey) == DarklyServiceMock.FlagKeys.dummy
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
}
