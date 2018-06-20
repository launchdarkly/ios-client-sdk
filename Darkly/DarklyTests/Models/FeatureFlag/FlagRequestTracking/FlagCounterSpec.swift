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
        dictionaryValueSpec()
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

    private func dictionaryValueSpec() {
        describe("dictionaryValue") {
            var flagCounters: [LDFlagKey: FlagCounter]!
            var flagCounterDictionary: [String: Any]!
            context("with known values") {
                beforeEach {
                    flagCounters = FlagCounter.stubFlagCounters(includeUnknownValue: false)
                }
                it("creates a flag counter dictionary") {
                    flagCounters.forEach { (flagKey, flagCounter) in
                        let flagValueCounter = flagCounter.flagValueCounters.first!

                        flagCounterDictionary = flagCounter.dictionaryValue

                        expect(flagCounterDictionary.keys.count) == 1
                        expect(flagCounterDictionary.keys.first) == flagKey

                        guard let counterDetailDictionary = flagCounterDictionary.flagCounterDetailDictionary(for: flagKey) else { return }
                        expect(AnyComparer.isEqual(counterDetailDictionary.flagCounterDefaultValue, to: flagCounter.defaultValue, considerNilAndNullEqual: true)).to(beTrue())
                        expect(counterDetailDictionary.flagCounterCounters?.count) == 1

                        guard let valueCounterDictionaries = counterDetailDictionary.flagCounterCounters, valueCounterDictionaries.count == 1,
                            let valueCounterDictionary = valueCounterDictionaries.first
                        else { return }
                        expect(AnyComparer.isEqual(valueCounterDictionary.valueCounterReportedValue, to: flagValueCounter.reportedValue, considerNilAndNullEqual: true)).to(beTrue())
                        expect(valueCounterDictionary.valueCounterVariation) == flagValueCounter.featureFlag?.variation
                        expect(valueCounterDictionary.valueCounterVersion) == flagValueCounter.featureFlag?.flagVersion
                        expect(valueCounterDictionary.valueCounterIsUnknown).to(beNil())
                        expect(valueCounterDictionary.valueCounterCount) == flagValueCounter.count
                    }
                }
            }
            context("with unknown value") {
                var flagCounter: FlagCounter!
                beforeEach {
                    flagCounter = FlagCounter.stub(flagKey: DarklyServiceMock.FlagKeys.dummy)
                }
                it("creates a flag counter dictionary") {
                    let flagValueCounter = flagCounter.flagValueCounters.first!

                    flagCounterDictionary = flagCounter.dictionaryValue

                    expect(flagCounterDictionary.keys.count) == 1
                    expect(flagCounterDictionary.keys.first) == flagCounter.flagKey

                    guard let counterDetailDictionary = flagCounterDictionary.flagCounterDetailDictionary(for: flagCounter.flagKey) else { return }
                    expect(AnyComparer.isEqual(counterDetailDictionary.flagCounterDefaultValue, to: flagCounter.defaultValue, considerNilAndNullEqual: true)).to(beTrue())
                    expect(counterDetailDictionary.flagCounterCounters?.count) == 1

                    guard let counterDictionaries = counterDetailDictionary.flagCounterCounters, counterDictionaries.count == 1,
                        let counterDictionary = counterDictionaries.first
                        else { return }
                    expect(AnyComparer.isEqual(counterDictionary.valueCounterReportedValue, to: flagValueCounter.reportedValue, considerNilAndNullEqual: true)).to(beTrue())
                    expect(counterDictionary.valueCounterVariation).to(beNil())
                    expect(counterDictionary.valueCounterVersion).to(beNil())
                    expect(counterDictionary.valueCounterIsUnknown) == true
                    expect(counterDictionary.valueCounterCount) == flagValueCounter.count
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
        let flagCounter = FlagCounter(flagKey: flagKey)
        var featureFlag: FeatureFlag? = nil
        if DarklyServiceMock.FlagKeys.all.contains(flagKey) {
            featureFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey)
            flagCounter.logRequest(reportedValue: featureFlag?.value, featureFlag: featureFlag, defaultValue: featureFlag?.value)
        } else {
            flagCounter.logRequest(reportedValue: false, featureFlag: nil, defaultValue: false)
        }
        let flagValueCounter = flagCounter.flagValueCounters.flagValueCounter(for: featureFlag)
        flagValueCounter?.count = Constants.requestCount

        return flagCounter
    }

    class func stubFlagCounters(includeUnknownValue: Bool = true) -> [LDFlagKey: FlagCounter] {
        var stubbedCounters = [LDFlagKey: FlagCounter]()

        DarklyServiceMock.FlagKeys.all.forEach { (flagKey) in
            stubbedCounters[flagKey] = FlagCounter.stub(flagKey: flagKey)
        }

        if includeUnknownValue {
            stubbedCounters[DarklyServiceMock.FlagKeys.dummy] = FlagCounter.stub(flagKey: DarklyServiceMock.FlagKeys.dummy)
        }

        return stubbedCounters
    }
}

extension Dictionary where Key == String, Value == Any {
    func flagCounterDetailDictionary(for flagKey: LDFlagKey) -> [String: Any]? {
        return self[flagKey] as? [String: Any]
    }
    var flagCounterDefaultValue: Any? {
        return self[FlagCounter.CodingKeys.defaultValue.rawValue]
    }
    var flagCounterCounters: [[String: Any]]? {
        return self[FlagCounter.CodingKeys.counters.rawValue] as? [[String: Any]]
    }
}
