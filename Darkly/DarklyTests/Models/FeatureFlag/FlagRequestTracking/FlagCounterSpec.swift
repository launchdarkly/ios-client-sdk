//
//  FlagCounterSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 6/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import Darkly

final class FlagCounterSpec: QuickSpec {
    override func spec() {
        initSpec()
        logRequestSpec()
    }

    private func initSpec() {
        describe("init") {
            var flagCounter: FlagCounter!
            it("creates a flag counter") {
                DarklyServiceMock.FlagKeys.all.forEach { (flagKey) in
                    flagCounter = FlagCounter(flagKey: flagKey)

                    expect(flagCounter.flagKey) == flagKey
                    expect(flagCounter.defaultValue).to(beNil())
                    expect(flagCounter.flagValueCounters.isEmpty).to(beTrue())
                }
            }
        }
    }

    private func logRequestSpec() {
        describe("logRequest") {
            var featureFlag: FeatureFlag!
            var flagValueCounter: FlagValueCounter!
            var flagCounter: FlagCounter!
            context("with known values") {
                it("logs the request") {
                    DarklyServiceMock.FlagKeys.all.forEach { (flagKey) in
                        flagCounter = FlagCounter(flagKey: flagKey)
                        featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey)

                        //log request with original featureFlag
                        for logRequestCount in [1, 2, 3] {

                            flagCounter.logRequest(reportedValue: featureFlag.value, featureFlag: featureFlag, defaultValue: featureFlag.value)

                            expect(flagCounter.flagValueCounters.count) == 1
                            flagValueCounter = flagCounter.flagValueCounters.flagValueCounter(for: featureFlag)
                            expect(flagValueCounter).toNot(beNil())
                            expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                            expect(flagValueCounter?.featureFlag) == featureFlag
                            expect(flagValueCounter?.isKnown) == true
                            expect(flagValueCounter?.count) == logRequestCount
                            expect(AnyComparer.isEqual(flagCounter.defaultValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                        }

                        //null doesn't have an alternate value, so skip this part of the test
                        guard flagKey != DarklyServiceMock.FlagKeys.null else { return }

                        //log request with new featureFlag
                        featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey, useAlternateValue: true)
                        for logRequestCount in [1, 2, 3] {

                            flagCounter.logRequest(reportedValue: featureFlag.value, featureFlag: featureFlag, defaultValue: featureFlag.value)

                            expect(flagCounter.flagValueCounters.count) == 2
                            flagValueCounter = flagCounter.flagValueCounters.flagValueCounter(for: featureFlag)
                            expect(flagValueCounter).toNot(beNil())
                            expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                            expect(flagValueCounter?.featureFlag) == featureFlag
                            expect(flagValueCounter?.isKnown) == true
                            expect(flagValueCounter?.count) == logRequestCount
                            expect(AnyComparer.isEqual(flagCounter.defaultValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                        }
                    }
                }
            }
            context("with unknown value") {
                beforeEach {
                    flagCounter = FlagCounter(flagKey: DarklyServiceMock.FlagKeys.dummy)
                }
                it("logs the request") {
                    for logRequestCount in [1, 2, 3] {

                        flagCounter.logRequest(reportedValue: false, featureFlag: nil, defaultValue: false)

                        expect(flagCounter.flagValueCounters.count) == 1
                        flagValueCounter = flagCounter.flagValueCounters.flagValueCounter(for: nil)
                        expect(flagValueCounter).toNot(beNil())
                        expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: false, considerNilAndNullEqual: true)).to(beTrue())
                        expect(flagValueCounter?.featureFlag).to(beNil())
                        expect(flagValueCounter?.isKnown) == false
                        expect(flagValueCounter?.count) == logRequestCount
                        expect(AnyComparer.isEqual(flagCounter.defaultValue, to: false, considerNilAndNullEqual: true)).to(beTrue())
                    }
                }
            }
        }
    }
}
