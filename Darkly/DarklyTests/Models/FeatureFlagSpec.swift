//
//  FeatureFlagSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 2/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import Darkly

final class FeatureFlagSpec: QuickSpec {
    struct TestContext {
        let subject: FeatureFlag?

        init(value: Any?, version: Int?) {
            subject = FeatureFlag(value: value, version: version)
        }

        init(dictionary: [String: Any]?) {
            subject = FeatureFlag(dictionary: dictionary)
        }

        init(object: Any?) {
            subject = FeatureFlag(object: object)
        }
    }

    override func spec() {
        initSpec()
        dictionaryValueSpec()
        isEqualToSpec()
    }

    func initSpec() {
        var testContext: TestContext!

        describe("init") {
            context("nil value and version") {
                beforeEach {
                    testContext = TestContext(value: nil, version: nil)
                }
                it("creates a feature flag with nil value and version") {
                    expect(testContext.subject!.value).to(beNil())
                    expect(testContext.subject!.version).to(beNil())
                }
            }
            context("value and version exists") {
                var version = 0

                it("creates a feature flag with the value and version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        testContext = TestContext(value: value, version: version)

                        if value is NSNull {
                            expect(testContext.subject!.value).to(beNil())
                        } else {
                            expect(testContext.subject!.value).toNot(beNil())
                            expect(AnyComparer.isEqual(testContext.subject?.value, to: value)).to(beTrue())
                        }
                        expect(testContext.subject!.version) == version
                    }
                }
            }
        }

        describe("init with dictionary") {
            context("when value and version exists in the dictionary") {
                var version = 0

                it("creates a feature flag with the value and version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        testContext = TestContext(dictionary: [FeatureFlag.CodingKeys.value.rawValue: value, FeatureFlag.CodingKeys.version.rawValue: version])

                        if value is NSNull {
                            expect(testContext.subject?.value).to(beNil())
                        } else {
                            expect(testContext.subject!.value).toNot(beNil())
                            expect(AnyComparer.isEqual(testContext.subject?.value, to: value)).to(beTrue())
                        }
                        expect(testContext.subject?.version) == version
                    }
                }
            }
            context("when the dictionary is the value") {
                beforeEach {
                    testContext = TestContext(dictionary: DarklyServiceMock.Constants.featureFlags)
                }
                it("creates a feature flag with the value but without a version") {
                    expect(testContext.subject?.value).toNot(beNil())
                    expect(AnyComparer.isEqual(testContext.subject?.value, to: DarklyServiceMock.Constants.featureFlags)).to(beTrue())
                    expect(testContext.subject?.version).to(beNil())
                }
            }
            context("when value only exists in the dictionary") {
                it("returns nil") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        testContext = TestContext(dictionary: [FeatureFlag.CodingKeys.value.rawValue: value])

                        expect(testContext.subject?.value).to(beNil())
                    }
                }
            }
            context("when version only exists in the dictionary") {
                beforeEach {
                    testContext = TestContext(dictionary: [FeatureFlag.CodingKeys.version.rawValue: 1])
                }
                it("returns nil") {
                    expect(testContext.subject?.value).to(beNil())
                }
            }
            context("when the dictionary is nil") {
                beforeEach {
                    testContext = TestContext(dictionary: nil)
                }
                it("returns nil") {
                    expect(testContext.subject?.value).to(beNil())
                }
            }
        }

        describe("init with any value") {
            context("valid value") {
                it("creates a feature flag with the value but without a version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        testContext = TestContext(object: value)

                        if value is NSNull {
                            expect(testContext.subject?.value).to(beNil())
                        } else {
                            expect(testContext.subject?.value).toNot(beNil())
                            expect(AnyComparer.isEqual(testContext.subject?.value, to: value)).to(beTrue())
                        }
                        expect(testContext.subject?.version).to(beNil())
                    }
                }
            }
            context("value and version dictionary") {
                var version = 0

                it("creates a feature flag with the value and version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        testContext = TestContext(object: [FeatureFlag.CodingKeys.value.rawValue: value, FeatureFlag.CodingKeys.version.rawValue: version])

                        if value is NSNull {
                            expect(testContext.subject?.value).to(beNil())
                        } else {
                            expect(testContext.subject?.value).toNot(beNil())
                            expect(AnyComparer.isEqual(testContext.subject?.value, to: value)).to(beTrue())
                        }
                        expect(testContext.subject?.version) == version
                    }
                }
            }
            context("nil") {
                beforeEach {
                    testContext = TestContext(object: nil)
                }
                it("returns nil") {
                    expect(testContext.subject?.value).to(beNil())
                }
            }
        }
    }

    func dictionaryValueSpec() {
        var testContext: TestContext!
        var subjectDictionary: [String: Any]?
        var dictionaryValue: Any? { return subjectDictionary?[FeatureFlag.CodingKeys.value.rawValue] }
        var dictionaryVersion: Int? { return subjectDictionary?[FeatureFlag.CodingKeys.version.rawValue] as? Int }

        describe("dictionaryValue") {
            context("dont exciseNil") {
                context("with versions") {
                    var version = 0

                    it("creates a dictionary with the value and version including nil value representations") {
                        DarklyServiceMock.FlagValues.all.forEach { (value) in
                            version += 1
                            testContext = TestContext(value: value, version: version)
                            subjectDictionary = testContext.subject?.dictionaryValue(exciseNil: false)

                            guard let dictionaryValue = dictionaryValue else { return }
                            expect(AnyComparer.isEqual(dictionaryValue, to: value)).to(beTrue())
                            expect(dictionaryVersion) == version
                        }
                    }
                }
                context("without versions") {
                    it("creates a dictionary with the value including nil value and version representations") {
                        DarklyServiceMock.FlagValues.all.forEach { (value) in
                            testContext = TestContext(value: value, version: nil)
                            subjectDictionary = testContext.subject?.dictionaryValue(exciseNil: false)

                            expect(AnyComparer.isEqual(dictionaryValue, to: value)).to(beTrue())
                            expect(subjectDictionary?[FeatureFlag.CodingKeys.version.rawValue] is NSNull).to(beTrue())
                        }
                    }
                }
                context("dictionary has null value") {
                    beforeEach {
                        testContext = TestContext(value: DarklyServiceMock.Constants.featureFlagsWithNull, version: 1)
                        subjectDictionary = testContext.subject!.dictionaryValue(exciseNil: false)
                    }
                    it("creates a dictionary with the dictionary value including nil value representation") {
                        expect(AnyComparer.isEqual(dictionaryValue, to: DarklyServiceMock.Constants.featureFlagsWithNull)).to(beTrue())
                        expect(dictionaryVersion) == 1
                    }
                }
            }
            context("exciseNil") {
                context("with versions") {
                    var version = 0

                    it("creates a dictionary with the value and version excluding nil values") {
                        DarklyServiceMock.FlagValues.all.forEach { (value) in
                            version += 1
                            testContext = TestContext(value: value, version: version)
                            subjectDictionary = testContext.subject?.dictionaryValue(exciseNil: true)

                            if value is NSNull {
                                expect(subjectDictionary).to(beNil())
                            } else {
                                expect(AnyComparer.isEqual(dictionaryValue, to: value)).to(beTrue())
                                expect(dictionaryVersion) == version
                            }
                        }
                    }
                }
                context("without versions") {
                    it("creates a dictionary with the value excluding nil value and version representations") {
                        DarklyServiceMock.FlagValues.all.forEach { (value) in
                            testContext = TestContext(value: value, version: nil)
                            subjectDictionary = testContext.subject?.dictionaryValue(exciseNil: true)

                            if value is NSNull {
                                expect(subjectDictionary).to(beNil())
                            } else {
                                expect(AnyComparer.isEqual(dictionaryValue, to: value)).to(beTrue())
                                expect(dictionaryVersion) == FeatureFlag.Constants.nilVersionPlaceholder
                            }
                        }
                    }
                }
                context("dictionary has null value") {
                    beforeEach {
                        testContext = TestContext(value: DarklyServiceMock.Constants.featureFlagsWithNull, version: 1)
                        subjectDictionary = testContext.subject!.dictionaryValue(exciseNil: true)
                    }
                    it("creates a dictionary with the dictionary value excluding nil value representation") {
                        if let dictionaryValue = dictionaryValue {
                            expect(AnyComparer.isEqual(dictionaryValue, to: DarklyServiceMock.Constants.featureFlags)).to(beTrue())
                            expect(dictionaryVersion) == 1
                        }
                    }
                }
            }
        }

        describe("dictionary restores to feature flag") {
            var reinflatedFlag: FeatureFlag?
            context("with versions") {
                var version = 0

                it("creates a feature flag with the same values as the original") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        testContext = TestContext(value: value, version: version)
                        reinflatedFlag = FeatureFlag(dictionary: testContext.subject?.dictionaryValue(exciseNil: false))

                        expect(reinflatedFlag).toNot(beNil())
                        if value is NSNull {
                            expect(reinflatedFlag?.value).to(beNil())
                        } else {
                            expect(reinflatedFlag?.value).toNot(beNil())
                            expect(AnyComparer.isEqual(reinflatedFlag?.value, to: value)).to(beTrue())
                        }
                        expect(reinflatedFlag?.version) == version
                    }
                }
            }
            context("dictionary has null value") {
                beforeEach {
                    testContext = TestContext(value: DarklyServiceMock.Constants.featureFlagsWithNull, version: 1)
                    reinflatedFlag = FeatureFlag(dictionary: testContext.subject?.dictionaryValue(exciseNil: false))
                }
                it("creates a feature flag with the same value and version as the original") {
                    expect(reinflatedFlag).toNot(beNil())
                    expect(reinflatedFlag?.value).toNot(beNil())
                    expect(AnyComparer.isEqual(reinflatedFlag?.value, to: DarklyServiceMock.Constants.featureFlagsWithNull)).to(beTrue())
                    expect(reinflatedFlag?.version) == 1
                }
            }
        }
    }

    func isEqualToSpec() {
        var testContext: TestContext!

        describe("isEqualTo") {
            var version = 0
            var otherFlag: FeatureFlag!

            context("when value and version exists") {
                it("compares value and version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        testContext = TestContext(value: value, version: version)
                        otherFlag = testContext.subject!

                        expect(testContext.subject!.isEqual(to: otherFlag)).to(beTrue())

                        if !(value is NSNull) {
                            otherFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.alternate(value: value) as Any, version: version)
                            expect(testContext.subject!.isEqual(to: otherFlag)).to(beFalse())
                        }

                        otherFlag = FeatureFlag(value: value, version: version + 1)
                        expect(testContext.subject!.isEqual(to: otherFlag)).to(beFalse())
                    }
                }
            }
            context("when value only exists") {
                it("compares value and check version is nil") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        testContext = TestContext(value: value, version: nil)
                        otherFlag = testContext.subject!

                        expect(testContext.subject!.isEqual(to: otherFlag)).to(beTrue())

                        if !(value is NSNull) {
                            otherFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.alternate(value: value) as Any, version: version)
                            expect(testContext.subject!.isEqual(to: otherFlag)).to(beFalse())
                        }

                        otherFlag = FeatureFlag(value: value, version: 1)
                        expect(testContext.subject!.isEqual(to: otherFlag)).to(beFalse())
                    }
                }
            }
        }
    }
}
