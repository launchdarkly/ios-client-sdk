//
//  AnySpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 2/20/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import Darkly

final class AnySpec: QuickSpec {
    struct Constants {
        
    }

    struct Values {
        static let bool = true
        static let int = 1027
        static let double = 1.6180339887
        static let string = "an interesting string"
        static let array = [1, 2, 3, 5, 7, 11]
        static let dictionary: [String: Any] = ["bool-key": true, "int-key": -72, "double-key": 1.414, "string-key": "a not so interesting string", "any-array-key": [true, 2, "hello-kitty"], "int-array-key": [1, 2, 3], "dictionary-key": ["keyA": true, "keyB": -1, "keyC": "howdy"]]
        static let date = Date()
        static let userFlags = CacheableUserFlags.stub()
        static let null = NSNull()

        static let all: [Any] = [bool, int, double, string, array, dictionary, date, userFlags, null]
    }

    struct AltValues {
        static let bool = false
        static let int = 1028
        static let double = 1.6180339887 * 2
        static let string = "an interesting string-"
        static let array = [1, 2, 3, 5, 7]
        static let dictionary: [String: Any] = ["bool-key": false, "int-key": -72, "double-key": 1.414, "string-key": "a not so interesting string", "any-array-key": [true, 2, "hello-kitty"], "int-array-key": [1, 2, 3], "dictionary-key": ["keyA": true, "keyB": -1, "keyC": "howdy"]]
        static let date = Date().addingTimeInterval(-1.0)
        static let userFlags = CacheableUserFlags(flags: DarklyServiceMock.Constants.featureFlags, lastUpdated: Date().addingTimeInterval(1.0))
        static let null = NSNull()

        static let all: [Any] = [bool, int, double, string, array, dictionary, date, userFlags, null]
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
                it("returns true") {
                    Values.all.forEach { (value) in
                        other = value

                        expect(AnyComparer.isEqual(value, to: other)).to(beTrue())
                    }
                }
            }
            context("when values dont match") {
                it("returns false") {
                    zip(Values.all, AltValues.all).forEach { (value, altValue) in
                        other = altValue

                        if !(value is NSNull) {
                            expect(AnyComparer.isEqual(value, to: other)).to(beFalse())
                        }
                    }
                }
            }
            context("with matching feature flags") {
                var featureFlag: FeatureFlag!
                var otherFlag: FeatureFlag!

                context("with version") {
                    var version = 0

                    it("returns true") {
                        DarklyServiceMock.FlagValues.all.forEach { (value) in
                            version += 1
                            featureFlag = FeatureFlag(value: value, version: version)
                            otherFlag = FeatureFlag(value: value, version: version)

                            expect(AnyComparer.isEqual(featureFlag, to: otherFlag)).to(beTrue())
                        }
                    }
                }
                context("without version") {
                    it("returns true") {
                        DarklyServiceMock.FlagValues.all.forEach { (value) in
                            featureFlag = FeatureFlag(value: value, version: nil)
                            otherFlag = FeatureFlag(value: value, version: nil)

                            expect(AnyComparer.isEqual(featureFlag, to: otherFlag)).to(beTrue())
                        }
                    }
                }
            }
            context("with non-matching feature flags") {
                var featureFlag: FeatureFlag!
                var otherFlag: FeatureFlag!

                context("with version") {
                    var version = 0

                    context("with differing value") {
                        it("returns false") {
                            DarklyServiceMock.FlagValues.all.forEach { (value) in
                                guard !(value is NSNull) else { return }
                                version += 1
                                featureFlag = FeatureFlag(value: value, version: version)
                                otherFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.alternate(value: value) as Any, version: version)

                                expect(AnyComparer.isEqual(featureFlag, to: otherFlag)).to(beFalse())
                            }
                        }
                    }
                    context("with differing version") {
                        it("returns false") {
                            DarklyServiceMock.FlagValues.all.forEach { (value) in
                                version += 1
                                featureFlag = FeatureFlag(value: value, version: version)
                                otherFlag = FeatureFlag(value: value, version: version + 1)

                                expect(AnyComparer.isEqual(featureFlag, to: otherFlag)).to(beFalse())
                            }
                        }
                    }
                }
                context("without version") {
                    context("with differing value") {
                        it("returns false") {
                            DarklyServiceMock.FlagValues.all.forEach { (value) in
                                guard !(value is NSNull) else { return }
                                featureFlag = FeatureFlag(value: value, version: nil)
                                otherFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.alternate(value: value) as Any, version: nil)

                                expect(AnyComparer.isEqual(featureFlag, to: otherFlag)).to(beFalse())
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
