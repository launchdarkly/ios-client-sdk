//
//  AnyComparerSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 2/20/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class AnyComparerSpec: QuickSpec {
    struct Constants {
        
    }

    struct Values {
        static let bool = true
        static let int = 1027
        static let double = 1.6180339887
        static let string = "an interesting string"
        static let array = [1, 2, 3, 5, 7, 11]
        static let dictionary: [String: Any] = ["bool-key": true,
                                                "int-key": -72,
                                                "double-key": 1.414,
                                                "string-key": "a not so interesting string",
                                                "any-array-key": [true, 2, "hello-kitty"],
                                                "int-array-key": [1, 2, 3],
                                                "dictionary-key": ["keyA": true, "keyB": -1, "keyC": "howdy"]]
        static let date = Date()
        static let userFlags = CacheableUserFlags.stub()
        static let null = NSNull()

        static let all: [Any] = [bool, int, double, string, array, dictionary, date, userFlags, null]
        static let allThatCanBeInequal: [Any] = [bool, int, double, string, array, dictionary, date, userFlags]
    }

    struct AltValues {
        static let bool = false
        static let int = 1028
        static let double = 1.6180339887 * 2
        static let string = "an interesting string-"
        static let array = [1, 2, 3, 5, 7]
        static let dictionary: [String: Any] = ["bool-key": false,
                                                "int-key": -72,
                                                "double-key": 1.414,
                                                "string-key": "a not so interesting string",
                                                "any-array-key": [true, 2, "hello-kitty"],
                                                "int-array-key": [1, 2, 3],
                                                "dictionary-key": ["keyA": true, "keyB": -1, "keyC": "howdy"]]
        static let date = Date().addingTimeInterval(-1.0)
        static let userFlags = CacheableUserFlags(userKey: UUID().uuidString,
                                                  flags: DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false),
                                                  lastUpdated: Date().addingTimeInterval(1.0))
        static let null = NSNull()

        static let all: [Any] = [bool, int, double, string, array, dictionary, date, userFlags, null]
        static let allThatCanBeInequal: [Any] = [bool, int, double, string, array, dictionary, date, userFlags]
    }

    override func spec() {
        nonOptionalSpec()
        semiOptionalSpec()
        optionalSpec()
    }

    func nonOptionalSpec() {
        var other: Any!

        describe("isEqual(to:)") {
            context("when values match") {
                context("and are the same type") {
                    it("returns true") {
                        Values.all.forEach { (value) in
                            other = value

                            expect(AnyComparer.isEqual(value, to: other)).to(beTrue())
                        }
                        expect(AnyComparer.isEqual(Int64(Values.int), to: Int64(Values.int))).to(beTrue())
                    }
                }
                context("and are different types") {
                    it("returns true") {
                        expect(AnyComparer.isEqual(Values.int, to: Double(Values.int))).to(beTrue())
                        expect(AnyComparer.isEqual(Double(Values.int), to: Values.int)).to(beTrue())
                        expect(AnyComparer.isEqual(Int64(Values.int), to: Double(Values.int))).to(beTrue())
                        expect(AnyComparer.isEqual(Double(Values.int), to: Int64(Values.int))).to(beTrue())
                    }
                }
            }
            context("when values dont match") {
                context("and are the same type") {
                    it("returns false") {
                        zip(Values.allThatCanBeInequal, AltValues.allThatCanBeInequal).forEach { (value, altValue) in
                            other = altValue
                            expect(AnyComparer.isEqual(value, to: other)).to(beFalse())
                        }
                    }
                    expect(AnyComparer.isEqual(Int64(Values.int), to: Int64(AltValues.int))).to(beFalse())
                }
                context("and are different types") {
                    it("returns false") {
                        expect(AnyComparer.isEqual(Values.int, to: Values.double)).to(beFalse())
                        expect(AnyComparer.isEqual(Values.double, to: Values.int)).to(beFalse())
                        expect(AnyComparer.isEqual(Int64(Values.int), to: Values.double)).to(beFalse())
                        expect(AnyComparer.isEqual(Values.double, to: Int64(Values.int))).to(beFalse())
                    }
                }
            }
            context("with matching feature flags") {
                var featureFlags: [LDFlagKey: FeatureFlag]!
                var otherFlag: FeatureFlag!
                context("with elements") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                    }
                    it("returns true") {
                        featureFlags.forEach { (_, featureFlag) in
                            otherFlag = FeatureFlag(copying: featureFlag)

                            expect(AnyComparer.isEqual(featureFlag, to: otherFlag)).to(beTrue())
                        }
                    }
                }
                context("without elements") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeVariations: false, includeVersions: false, includeFlagVersions: false)
                    }
                    it("returns true") {
                        featureFlags.forEach { (flagKey, featureFlag) in
                            otherFlag = FeatureFlag(flagKey: flagKey, value: featureFlag.value, variation: nil, version: nil, flagVersion: nil, eventTrackingContext: nil)

                            expect(AnyComparer.isEqual(featureFlag, to: otherFlag)).to(beTrue())
                        }
                    }
                }
            }
            context("with different feature flags") {
                var featureFlags: [LDFlagKey: FeatureFlag]!
                var otherFlag: FeatureFlag!
                context("with elements") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                    }
                    context("with differing variation") {
                        it("returns false") {
                            featureFlags.forEach { (_, featureFlag) in
                                otherFlag = FeatureFlag(copying: featureFlag, variation: featureFlag.variation! + 1)

                                expect(AnyComparer.isEqual(featureFlag, to: otherFlag)).to(beFalse())
                            }
                        }
                    }
                    context("with differing version") {
                        it("returns false") {
                            featureFlags.forEach { (_, featureFlag) in
                                otherFlag = FeatureFlag(copying: featureFlag, version: featureFlag.version! + 1)

                                expect(AnyComparer.isEqual(featureFlag, to: otherFlag)).to(beFalse())
                            }
                        }
                    }
                    context("with differing flagVersion") {
                        it("returns true") {
                            featureFlags.forEach { (_, featureFlag) in
                                otherFlag = FeatureFlag(copying: featureFlag, flagVersion: featureFlag.flagVersion! + 1)

                                expect(AnyComparer.isEqual(featureFlag, to: otherFlag)).to(beTrue())
                            }
                        }
                    }
                    context("with differing eventTrackingContext") {
                        var eventTrackingContext: EventTrackingContext!
                        beforeEach {
                            eventTrackingContext = EventTrackingContext(trackEvents: false)
                        }
                        it("returns true") {
                            featureFlags.forEach { (_, featureFlag) in
                                otherFlag = FeatureFlag(copying: featureFlag, eventTrackingContext: eventTrackingContext)

                                expect(AnyComparer.isEqual(featureFlag, to: otherFlag)).to(beTrue())
                            }
                        }
                    }
                }
                context("without elements") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeVariations: false, includeVersions: false, includeFlagVersions: false)
                    }
                    context("with differing value") {
                        it("returns true") {    //Yeah, this is weird. Since the variation is missing the comparison succeeds
                            featureFlags.forEach { (flagKey, featureFlag) in
                                otherFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: flagKey,
                                                                                        includeVariation: false,
                                                                                        includeVersion: false,
                                                                                        includeFlagVersion: false,
                                                                                        useAlternateValue: true)

                                expect(AnyComparer.isEqual(featureFlag, to: otherFlag)).to(beTrue())
                            }
                        }
                    }
                }
            }
        }
    }

    func semiOptionalSpec() {
        var other: Any?

        describe("isEqual(to:)") {
            context("when values match") {
                it("returns true") {
                    Values.all.forEach { (value) in
                        other = value

                        expect(AnyComparer.isEqual(value, to: other)).to(beTrue())
                        expect(AnyComparer.isEqual(other, to: value)).to(beTrue())
                    }
                }
            }
            context("when values dont match") {
                it("returns false") {
                    zip(Values.all, AltValues.all).forEach { (value, altValue) in
                        other = altValue

                        if !(value is NSNull) {
                            expect(AnyComparer.isEqual(value, to: other)).to(beFalse())
                            expect(AnyComparer.isEqual(other, to: value)).to(beFalse())
                        }
                    }
                }
            }
            context("when one value is nil") {
                it("returns false") {
                    Values.all.forEach { (value) in
                        expect(AnyComparer.isEqual(value, to: nil)).to(beFalse())
                        expect(AnyComparer.isEqual(nil, to: value)).to(beFalse())
                    }
                }
            }
        }
    }

    func optionalSpec() {
        var optionalValue: Any?
        var other: Any?

        describe("isEqual(to:)") {
            context("when values match") {
                it("returns true") {
                    Values.all.forEach { (value) in
                        optionalValue = value
                        other = value

                        expect(AnyComparer.isEqual(optionalValue, to: other)).to(beTrue())
                    }
                }
            }
            context("when values dont match") {
                it("returns false") {
                    zip(Values.all, AltValues.all).forEach { (value, altValue) in
                        optionalValue = value
                        other = altValue

                        if !(value is NSNull) {
                            expect(AnyComparer.isEqual(optionalValue, to: other)).to(beFalse())
                        }
                    }
                }
            }
            context("when one value is nil") {
                it("returns false") {
                    Values.all.forEach { (value) in
                        optionalValue = value

                        expect(AnyComparer.isEqual(optionalValue, to: nil)).to(beFalse())
                        expect(AnyComparer.isEqual(nil, to: optionalValue)).to(beFalse())
                    }
                }
            }
            context("when both values are nil") {
                it("returns true") {
                    expect(AnyComparer.isEqual(nil, to: nil)).to(beTrue())
                }
            }
        }
    }
}
