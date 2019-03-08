//
//  FlagValueCounterSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 6/19/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class FlagValueCounterSpec: QuickSpec {
    override func spec() {
        initSpec()
        dictionaryValueSpec()
    }

    private func initSpec() {
        describe("init") {
            var flagValueCounter: FlagValueCounter!
            context("for known values") {
                var featureFlags: [LDFlagKey: FeatureFlag]!
                beforeEach {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                }
                it("creates a known value counter") {
                    featureFlags.forEach { (_, featureFlag) in
                        flagValueCounter = FlagValueCounter(reportedValue: featureFlag.value, featureFlag: featureFlag)

                        expect(AnyComparer.isEqual(flagValueCounter.reportedValue, to: featureFlag.value)).to(beTrue())
                        expect(flagValueCounter.featureFlag) == featureFlag
                        expect(flagValueCounter.isKnown) == true
                        expect(flagValueCounter.count) == 0
                    }
                }
            }
            context("for unknown values") {
                beforeEach {
                    flagValueCounter = FlagValueCounter(reportedValue: true, featureFlag: nil)
                }
                it("creates an unknown value counter") {
                    expect(AnyComparer.isEqual(flagValueCounter.reportedValue, to: true)).to(beTrue())
                    expect(flagValueCounter.featureFlag).to(beNil())
                    expect(flagValueCounter.isKnown) == false
                    expect(flagValueCounter.count) == 0
                }
            }
        }
    }

    private func dictionaryValueSpec() {
        describe("dictionaryValue") {
            var flagValueCounter: FlagValueCounter!
            var flagValueCounterDictionary: [String: Any]!
            context("for known values") {
                var featureFlags: [LDFlagKey: FeatureFlag]!
                context("with flag version") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                    }
                    it("creates a known value dictionary with elements matching the feature flag") {
                        featureFlags.forEach { (_, featureFlag) in
                            flagValueCounter = FlagValueCounter(reportedValue: featureFlag.value, featureFlag: featureFlag)

                            flagValueCounterDictionary = flagValueCounter.dictionaryValue

                            expect(AnyComparer.isEqual(flagValueCounterDictionary.valueCounterReportedValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                            expect(flagValueCounterDictionary.valueCounterVariation) == featureFlag.variation
                            expect(flagValueCounterDictionary.valueCounterVersion) == featureFlag.flagVersion
                            expect(flagValueCounterDictionary.valueCounterIsUnknown).to(beNil())
                            expect(flagValueCounterDictionary.valueCounterCount) == 0
                        }
                    }
                }
                context("without flag version") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeFlagVersions: false)
                    }
                    it("creates a known value dictionary with elements matching the feature flag") {
                        featureFlags.forEach { (_, featureFlag) in
                            flagValueCounter = FlagValueCounter(reportedValue: featureFlag.value, featureFlag: featureFlag)

                            flagValueCounterDictionary = flagValueCounter.dictionaryValue

                            expect(AnyComparer.isEqual(flagValueCounterDictionary.valueCounterReportedValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                            expect(flagValueCounterDictionary.valueCounterVariation) == featureFlag.variation
                            expect(flagValueCounterDictionary.valueCounterVersion) == featureFlag.version
                            expect(flagValueCounterDictionary.valueCounterIsUnknown).to(beNil())
                            expect(flagValueCounterDictionary.valueCounterCount) == 0
                        }
                    }
                }
            }
            context("for an unknown value") {
                beforeEach {
                    flagValueCounter = FlagValueCounter(reportedValue: true, featureFlag: nil)

                    flagValueCounterDictionary = flagValueCounter.dictionaryValue
                }
                it("creates an unknown value dictionary") {
                    expect(AnyComparer.isEqual(flagValueCounterDictionary.valueCounterReportedValue, to: true)).to(beTrue())
                    expect(flagValueCounterDictionary.valueCounterVariation).to(beNil())
                    expect(flagValueCounterDictionary.valueCounterVersion).to(beNil())
                    expect(flagValueCounterDictionary.valueCounterIsUnknown) == true
                    expect(flagValueCounterDictionary.valueCounterCount) == 0
                }
            }
        }
    }
}

extension FlagValueCounter: Equatable {
    public static func == (lhs: FlagValueCounter, rhs: FlagValueCounter) -> Bool {
        if !AnyComparer.isEqual(lhs.reportedValue, to: rhs.reportedValue, considerNilAndNullEqual: true) {
            return false
        }
        return lhs.featureFlag == rhs.featureFlag && lhs.isKnown == rhs.isKnown && lhs.count == rhs.count
    }
}

extension Array where Element == FlagValueCounter {
    static func == (lhs: [FlagValueCounter], rhs: [FlagValueCounter]) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }
        for (index, leftFlagValueCounter) in lhs.enumerated() where leftFlagValueCounter != rhs[index] {
            return false
        }
        return true
    }
}

extension Dictionary where Key == String, Value == Any {
    var valueCounterReportedValue: Any? {
        return self[FlagValueCounter.CodingKeys.value.rawValue]
    }
    var valueCounterVariation: Int? {
        return self[FlagValueCounter.CodingKeys.variation.rawValue] as? Int
    }
    var valueCounterVersion: Int? {
        return self[FlagValueCounter.CodingKeys.version.rawValue] as? Int
    }
    var valueCounterIsUnknown: Bool? {
        return self[FlagValueCounter.CodingKeys.unknown.rawValue] as? Bool
    }
    var valueCounterCount: Int? {
        return self[FlagValueCounter.CodingKeys.count.rawValue] as? Int
    }
}
