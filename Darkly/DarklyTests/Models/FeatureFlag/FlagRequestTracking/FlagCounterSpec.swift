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
@testable import LaunchDarkly

final class FlagCounterSpec: QuickSpec {
    override func spec() {
        initSpec()
        trackRequestSpec()
        dictionaryValueSpec()
    }

    private func initSpec() {
        describe("init") {
            var flagCounter: FlagCounter!
            it("creates a flag counter") {
                flagCounter = FlagCounter()
                
                expect(flagCounter.defaultValue).to(beNil())
                expect(flagCounter.flagValueCounters.isEmpty).to(beTrue())
            }
        }
    }

    private func trackRequestSpec() {
        describe("trackRequest") {
            var featureFlag: FeatureFlag!
            var flagValueCounter: FlagValueCounter!
            var flagCounter: FlagCounter!
            context("with known values") {
                DarklyServiceMock.FlagKeys.knownFlags.forEach { (flagKey) in
                    context("first request") {
                        beforeEach {
                            flagCounter = FlagCounter()
                            featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey)

                            flagCounter.trackRequest(reportedValue: featureFlag.value, featureFlag: featureFlag, defaultValue: featureFlag.value)
                        }
                        it("sets the default value") {
                            expect(AnyComparer.isEqual(flagCounter.defaultValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                        }
                        it("creates a new flag value counter") {
                            expect(flagCounter.flagValueCounters.count) == 1
                            flagValueCounter = flagCounter.flagValueCounters.flagValueCounter(for: featureFlag)
                            expect(flagValueCounter).toNot(beNil())
                            expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                            expect(flagValueCounter?.featureFlag) == featureFlag
                            expect(flagValueCounter?.isKnown) == true
                            expect(flagValueCounter?.count) == 1
                        }
                    }
                    context("later request") {
                        context("with the same value") {
                            beforeEach {
                                flagCounter = FlagCounter.stub(flagKey: flagKey)
                                featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey)

                                flagCounter.trackRequest(reportedValue: featureFlag.value, featureFlag: featureFlag, defaultValue: featureFlag.value)
                            }
                            it("increments the flag value counter") {
                                expect(flagCounter.flagValueCounters.count) == 1
                                flagValueCounter = flagCounter.flagValueCounters.flagValueCounter(for: featureFlag)
                                expect(flagValueCounter).toNot(beNil())
                                expect(flagValueCounter?.count) == FlagCounter.Constants.requestCount + 1
                            }
                        }
                        context("with a different value") {
                            //null doesn't have an alternate value, so skip this part of the test
                            guard flagKey.hasAlternateValue else { return }
                            beforeEach {
                                flagCounter = FlagCounter.stub(flagKey: flagKey)
                                featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey, useAlternateValue: true)

                                flagCounter.trackRequest(reportedValue: featureFlag.value, featureFlag: featureFlag, defaultValue: featureFlag.value)
                            }
                            it("creates a new flag value counter") {
                                expect(AnyComparer.isEqual(flagCounter.defaultValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                                expect(flagCounter.flagValueCounters.count) == 2
                                flagValueCounter = flagCounter.flagValueCounters.flagValueCounter(for: featureFlag)
                                expect(flagValueCounter).toNot(beNil())
                                expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                                expect(flagValueCounter?.featureFlag) == featureFlag
                                expect(flagValueCounter?.isKnown) == true
                                expect(flagValueCounter?.count) == 1
                            }
                        }
                    }
                }
            }
            context("with unknown value") {
                context("first request") {
                    beforeEach {
                        flagCounter = FlagCounter()

                        flagCounter.trackRequest(reportedValue: false, featureFlag: nil, defaultValue: false)
                    }
                    it("sets the default value") {
                        expect(AnyComparer.isEqual(flagCounter.defaultValue, to: false, considerNilAndNullEqual: true)).to(beTrue())
                    }
                    it("creates a new flag value counter") {
                        expect(flagCounter.flagValueCounters.count) == 1
                        flagValueCounter = flagCounter.flagValueCounters.flagValueCounter(for: nil)
                        expect(flagValueCounter).toNot(beNil())
                        expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: false, considerNilAndNullEqual: true)).to(beTrue())
                        expect(flagValueCounter?.featureFlag).to(beNil())
                        expect(flagValueCounter?.isKnown) == false
                        expect(flagValueCounter?.count) == 1
                    }
                }
                context("later request") {
                    context("with the same value") {
                        beforeEach {
                            flagCounter = FlagCounter.stub(flagKey: DarklyServiceMock.FlagKeys.unknown)

                            flagCounter.trackRequest(reportedValue: false, featureFlag: nil, defaultValue: false)
                        }
                        it("increments the flag value counter") {
                            expect(flagCounter.flagValueCounters.count) == 1
                            flagValueCounter = flagCounter.flagValueCounters.flagValueCounter(for: nil)
                            expect(flagValueCounter).toNot(beNil())
                            expect(flagValueCounter?.count) == FlagCounter.Constants.requestCount + 1
                        }
                    }
                    context("with a different value") {
                        beforeEach {
                            flagCounter = FlagCounter.stub(flagKey: DarklyServiceMock.FlagKeys.unknown)

                            flagCounter.trackRequest(reportedValue: true, featureFlag: nil, defaultValue: true)
                        }
                        it("sets the default value") {
                            expect(AnyComparer.isEqual(flagCounter.defaultValue, to: true, considerNilAndNullEqual: true)).to(beTrue())
                        }
                        it("increments the flag value counter and updates the reported value") {
                            expect(flagCounter.flagValueCounters.count) == 1
                            flagValueCounter = flagCounter.flagValueCounters.flagValueCounter(for: nil)
                            expect(flagValueCounter).toNot(beNil())
                            expect(AnyComparer.isEqual(flagValueCounter?.reportedValue, to: true, considerNilAndNullEqual: true)).to(beTrue())
                            expect(flagValueCounter?.count) == FlagCounter.Constants.requestCount + 1
                        }
                    }
                }
            }
        }
    }

    private func dictionaryValueSpec() {
        describe("dictionaryValue") {
            var flagCounter: FlagCounter!
            var flagValueCounter: FlagValueCounter! {
                return flagCounter.flagValueCounters.first!
            }
            var flagCounterDictionary: [String: Any]!
            DarklyServiceMock.FlagKeys.knownFlags.forEach { (flagKey) in
                context("with known flags") {
                    beforeEach {
                        flagCounter = FlagCounter.stub(flagKey: flagKey)

                        flagCounterDictionary = flagCounter.dictionaryValue
                    }
                    it("creates a flag counter dictionary") {
                        expect(AnyComparer.isEqual(flagCounterDictionary.flagCounterDefaultValue, to: flagCounter.defaultValue, considerNilAndNullEqual: true)).to(beTrue())
                        expect(flagCounterDictionary.flagCounterFlagValueCounters?.count) == 1
                    }
                    it("creates a flag value counter dictionary") {
                        let valueCounterDictionary = flagCounterDictionary.flagCounterFlagValueCounters?.first
                        expect(valueCounterDictionary).toNot(beNil())
                        expect(AnyComparer.isEqual(valueCounterDictionary?.valueCounterReportedValue, to: flagValueCounter.reportedValue, considerNilAndNullEqual: true)).to(beTrue())
                        expect(valueCounterDictionary?.valueCounterVariation) == flagValueCounter.featureFlag?.variation
                        expect(valueCounterDictionary?.valueCounterVersion) == flagValueCounter.featureFlag?.flagVersion
                        expect(valueCounterDictionary?.valueCounterIsUnknown).to(beNil())
                        expect(valueCounterDictionary?.valueCounterCount) == flagValueCounter.count
                    }
                }
            }
            context("with unknown flag") {
                beforeEach {
                    flagCounter = FlagCounter.stub(flagKey: DarklyServiceMock.FlagKeys.unknown)

                    flagCounterDictionary = flagCounter.dictionaryValue
                }
                it("creates a flag counter dictionary") {
                    expect(AnyComparer.isEqual(flagCounterDictionary.flagCounterDefaultValue, to: flagCounter.defaultValue, considerNilAndNullEqual: true)).to(beTrue())
                    expect(flagCounterDictionary.flagCounterFlagValueCounters?.count) == 1
                }
                it("creates a flag value counter dictionary") {
                    let valueCounterDictionary = flagCounterDictionary.flagCounterFlagValueCounters?.first
                    expect(valueCounterDictionary).toNot(beNil())
                    expect(AnyComparer.isEqual(valueCounterDictionary?.valueCounterReportedValue, to: flagValueCounter.reportedValue, considerNilAndNullEqual: true)).to(beTrue())
                    expect(valueCounterDictionary?.valueCounterVariation).to(beNil())
                    expect(valueCounterDictionary?.valueCounterVersion).to(beNil())
                    expect(valueCounterDictionary?.valueCounterIsUnknown) == true
                    expect(valueCounterDictionary?.valueCounterCount) == flagValueCounter.count
                }
            }
        }
    }
}

extension FlagCounter {
    struct Constants {
        static let requestCount = 3
    }

    class func stub(flagKey: LDFlagKey) -> FlagCounter {
        let flagCounter = FlagCounter()
        var featureFlag: FeatureFlag? = nil
        if flagKey.isKnown {
            featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey)
            flagCounter.trackRequest(reportedValue: featureFlag?.value, featureFlag: featureFlag, defaultValue: featureFlag?.value)
        } else {
            flagCounter.trackRequest(reportedValue: false, featureFlag: nil, defaultValue: false)
        }
        let flagValueCounter = flagCounter.flagValueCounters.flagValueCounter(for: featureFlag)
        flagValueCounter?.count = Constants.requestCount

        return flagCounter
    }

    class func stubFlagCounters(includeUnknownValue: Bool = true) -> [LDFlagKey: FlagCounter] {
        var stubbedCounters = [LDFlagKey: FlagCounter]()

        DarklyServiceMock.FlagKeys.knownFlags.forEach { (flagKey) in
            stubbedCounters[flagKey] = FlagCounter.stub(flagKey: flagKey)
        }

        if includeUnknownValue {
            stubbedCounters[DarklyServiceMock.FlagKeys.unknown] = FlagCounter.stub(flagKey: DarklyServiceMock.FlagKeys.unknown)
        }

        return stubbedCounters
    }
}

extension Dictionary where Key == String, Value == Any {
    var flagCounterDefaultValue: Any? {
        return self[FlagCounter.CodingKeys.defaultValue.rawValue]
    }
    var flagCounterFlagValueCounters: [[String: Any]]? {
        return self[FlagCounter.CodingKeys.counters.rawValue] as? [[String: Any]]
    }
}
