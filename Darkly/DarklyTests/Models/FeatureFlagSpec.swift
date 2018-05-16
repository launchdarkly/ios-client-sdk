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

    struct Constants {
        static let extraDictionaryKey = "FeatureFlagSpec.dictionary.key"
        static let extraDictionaryValue = "FeatureFlagSpec.dictionary.value"
    }

    struct TestContext {
        var subject: FeatureFlag!
        var dictionaryFromElements: [String: Any]!

        init(value: Any?, version: Int?, includeExtraDictionaryItems: Bool = false) {
            subject = FeatureFlag(value: value, version: version)
            dictionaryFromElements = [String: Any]()
            if let value = value {
                dictionaryFromElements[FeatureFlag.CodingKeys.value.rawValue] = value
            }
            if let version = version {
                dictionaryFromElements[FeatureFlag.CodingKeys.version.rawValue] = version
            }
            if includeExtraDictionaryItems {
                dictionaryFromElements[Constants.extraDictionaryKey] = Constants.extraDictionaryValue
            }
        }

        func subjectDictionary(exciseNil: Bool) -> [String: Any]? {
            return subject.dictionaryValue(exciseNil: exciseNil)
        }

        func value(from subjectDictionary: [String: Any]?) -> Any? {
            return subjectDictionary?[FeatureFlag.CodingKeys.value.rawValue]
        }

        func version(from subjectDictionary: [String: Any]?) -> Int? {
            return subjectDictionary?[FeatureFlag.CodingKeys.version.rawValue] as? Int
        }
    }

    override func spec() {
        initSpec()
        dictionaryValueSpec()
        equalsSpec()
        matchesValueSpec()
        collectionSpec()
    }

    func initSpec() {
        var subject: FeatureFlag?
        var testContext: TestContext!
        describe("init") {
            context("when value and version are both nil") {
                beforeEach {
                    testContext = TestContext(value: nil, version: nil)
                }
                it("creates a feature flag with nil value and version") {
                    expect(testContext!.subject!.value).to(beNil())
                    expect(testContext!.subject!.version).to(beNil())
                }
            }
            context("when value and version both exist") {
                var version = 0
                it("creates a feature flag with the value and version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        testContext = TestContext(value: value, version: version)

                        if value is NSNull {
                            expect(testContext!.subject!.value).to(beNil())
                        } else {
                            expect(AnyComparer.isEqual(testContext!.subject!.value, to: value)).to(beTrue())
                        }
                        expect(testContext!.subject!.version) == version
                    }
                }
            }
        }

        describe("init with dictionary") {
            context("when value and version are the dictionary") {
                var version = 0
                it("creates a feature flag with the value and version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        testContext = TestContext(value: value, version: version)
                        subject = FeatureFlag(dictionary: testContext.dictionaryFromElements)

                        if value is NSNull {
                            expect(subject?.value).to(beNil())
                        } else {
                            expect(AnyComparer.isEqual(subject?.value, to: value)).to(beTrue())
                        }
                        expect(subject?.version) == version
                    }
                }
            }
            context("when value and version are part of the dictionary") {
                var version = 0
                it("creates a feature flag with the value and version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        testContext = TestContext(value: value, version: version, includeExtraDictionaryItems: false)
                        subject = FeatureFlag(dictionary: testContext.dictionaryFromElements)

                        if value is NSNull {
                            expect(subject?.value).to(beNil())
                        } else {
                            expect(AnyComparer.isEqual(subject?.value, to: value)).to(beTrue())
                        }
                        expect(subject?.version) == version
                    }
                }
            }
            context("when the dictionary is the value") {
                beforeEach {
                    subject = FeatureFlag(dictionary: DarklyServiceMock.FlagValues.dictionary)
                }
                it("creates a feature flag with the value but without a version") {
                    expect(AnyComparer.isEqual(subject?.value, to: DarklyServiceMock.FlagValues.dictionary)).to(beTrue())
                    expect(subject?.version).to(beNil())
                }
            }
            context("when value only exists in the dictionary") {
                it("it creates a feature flag with the dictionary as the value but without a version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        testContext = TestContext(value: value, version: nil)
                        subject = FeatureFlag(dictionary: testContext.dictionaryFromElements)

                        expect(AnyComparer.isEqual(subject?.value, to: testContext.dictionaryFromElements)).to(beTrue())
                        expect(subject?.version).to(beNil())
                    }
                }
            }
            context("when version only exists in the dictionary") {
                beforeEach {
                    testContext = TestContext(value: nil, version: DarklyServiceMock.FlagValues.int)
                    subject = FeatureFlag(dictionary: testContext.dictionaryFromElements)
                }
                it("it creates a feature flag with the dictionary as the value but without a version") {
                    expect(AnyComparer.isEqual(subject?.value, to: testContext.dictionaryFromElements)).to(beTrue())
                    expect(subject?.version).to(beNil())
                }
            }
            context("when the dictionary is nil") {
                beforeEach {
                    subject = FeatureFlag(dictionary: nil)
                }
                it("returns nil") {
                    expect(subject).to(beNil())
                }
            }
        }

        describe("init with any value") {
            context("valid value") {
                it("creates a feature flag with the value but without a version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        subject = FeatureFlag(object: value)

                        if value is NSNull {
                            expect(subject).toNot(beNil())
                            expect(subject?.value).to(beNil())
                        } else {
                            expect(AnyComparer.isEqual(subject?.value, to: value)).to(beTrue())
                        }
                        expect(subject?.version).to(beNil())
                    }
                }
            }
            context("value and version dictionary") {
                var version = 0

                it("creates a feature flag with the value and version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        testContext = TestContext(value: value, version: version)
                        subject = FeatureFlag(object: testContext.dictionaryFromElements)

                        if value is NSNull {
                            expect(subject?.value).to(beNil())
                        } else {
                            expect(AnyComparer.isEqual(subject?.value, to: value)).to(beTrue())
                        }
                        expect(subject?.version) == version
                    }
                }
            }
            context("nil") {
                beforeEach {
                    subject = FeatureFlag(object: nil)
                }
                it("returns nil") {
                    expect(subject?.value).to(beNil())
                }
            }
        }
    }

    func dictionaryValueSpec() {
        describe("dictionaryValue") {
            context("dont exciseNil") {
                context("with versions") {
                    var version = 0
                    it("creates a dictionary with the value and version including nil value representations") {
                        DarklyServiceMock.FlagValues.all.forEach { (value) in
                            version += 1
                            let testContext = TestContext(value: value, version: version)
                            let subjectDictionary = testContext.subjectDictionary(exciseNil: false)

                            expect(subjectDictionary).toNot(beNil())
                            guard let subjectDictionaryValue = testContext.value(from: subjectDictionary) else { return }
                            expect(AnyComparer.isEqual(subjectDictionaryValue, to: value)).to(beTrue())
                            expect(testContext.version(from: subjectDictionary)) == version
                        }
                    }
                }
                context("without versions") {
                    it("creates a dictionary with the value including nil value and version representations") {
                        DarklyServiceMock.FlagValues.all.forEach { (value) in
                            let testContext = TestContext(value: value, version: nil)
                            let subjectDictionary = testContext.subjectDictionary(exciseNil: false)

                            expect(AnyComparer.isEqual(testContext.value(from: subjectDictionary), to: value)).to(beTrue())
                            expect(subjectDictionary?[FeatureFlag.CodingKeys.version.rawValue] is NSNull).to(beTrue())
                        }
                    }
                }
                context("dictionary has null value") {
                    var testContext: TestContext!
                    var subjectDictionary: [String: Any]?
                    let dictionaryValue: [String: Any]! = DarklyServiceMock.FlagValues.dictionary.appendNull()
                    beforeEach {
                        testContext = TestContext(value: dictionaryValue, version: DarklyServiceMock.Constants.version)
                        subjectDictionary = testContext.subjectDictionary(exciseNil: false)
                    }
                    it("creates a dictionary with the dictionary value including nil value representation") {
                        expect(AnyComparer.isEqual(testContext.value(from: subjectDictionary), to: dictionaryValue)).to(beTrue())
                        expect(testContext.version(from: subjectDictionary)) == DarklyServiceMock.Constants.version
                    }
                }
            }
            context("exciseNil") {
                context("with versions") {
                    var version = 0

                    it("creates a dictionary with the value and version excluding nil values") {
                        DarklyServiceMock.FlagValues.all.forEach { (value) in
                            version += 1
                            let testContext = TestContext(value: value, version: version)
                            let subjectDictionary = testContext.subjectDictionary(exciseNil: true)

                            if value is NSNull {
                                expect(subjectDictionary).to(beNil())
                            } else {
                                expect(AnyComparer.isEqual(testContext.value(from: subjectDictionary), to: value)).to(beTrue())
                                expect(testContext.version(from: subjectDictionary)) == version
                            }
                        }
                    }
                }
                context("without versions") {
                    it("creates a dictionary with the value excluding nil value and version representations") {
                        DarklyServiceMock.FlagValues.all.forEach { (value) in
                            let testContext = TestContext(value: value, version: nil)
                            let subjectDictionary = testContext.subjectDictionary(exciseNil: true)

                            if value is NSNull {
                                expect(subjectDictionary).to(beNil())
                            } else {
                                expect(AnyComparer.isEqual(testContext.value(from: subjectDictionary), to: value)).to(beTrue())
                                expect(testContext.version(from: subjectDictionary)) == FeatureFlag.Constants.nilVersionPlaceholder
                            }
                        }
                    }
                }
                context("dictionary has null value") {
                    var testContext: TestContext!
                    var subjectDictionary: [String: Any]?
                    beforeEach {
                        testContext = TestContext(value: DarklyServiceMock.FlagValues.dictionary.appendNull(), version: DarklyServiceMock.Constants.version)
                        subjectDictionary = testContext.subjectDictionary(exciseNil: true)

                    }
                    it("creates a dictionary with the dictionary value excluding nil value representation") {
                        expect(subjectDictionary).toNot(beNil())
                        expect(AnyComparer.isEqual(testContext.value(from: subjectDictionary), to: DarklyServiceMock.FlagValues.dictionary)).to(beTrue())
                        expect(testContext.version(from: subjectDictionary)) == DarklyServiceMock.Constants.version
                    }
                }
            }
        }

        describe("dictionary restores to feature flag") {
            context("with versions") {
                var version = 0
                it("creates a feature flag with the same values as the original") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        let testContext = TestContext(value: value, version: version)
                        let reinflatedFlag = FeatureFlag(dictionary: testContext.subjectDictionary(exciseNil: false))

                        if value is NSNull {
                            expect(reinflatedFlag?.value).to(beNil())
                        } else {
                            expect(AnyComparer.isEqual(reinflatedFlag?.value, to: value)).to(beTrue())
                        }
                        expect(reinflatedFlag?.version) == version
                    }
                }
            }
            context("dictionary has null value") {
                var reinflatedFlag: FeatureFlag?
                beforeEach {
                    let testContext = TestContext(value: DarklyServiceMock.FlagValues.dictionary.appendNull(), version: DarklyServiceMock.FlagValues.int)
                    reinflatedFlag = FeatureFlag(dictionary: testContext.subjectDictionary(exciseNil: false))
                }
                it("creates a feature flag with the same value and version as the original") {
                    expect(reinflatedFlag).toNot(beNil())
                    expect(AnyComparer.isEqual(reinflatedFlag?.value, to: DarklyServiceMock.FlagValues.dictionary.appendNull())).to(beTrue())
                    expect(reinflatedFlag?.version) == DarklyServiceMock.FlagValues.int
                }
            }
        }
    }

    func equalsSpec() {
        var subject: FeatureFlag?
        var version = 0
        var otherFlag: FeatureFlag?

        describe("equals") {

            context("when value and version exists") {
                it("compares value and version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        subject = FeatureFlag(value: value, version: version)
                        otherFlag = subject

                        expect(subject) == otherFlag

                        if !(value is NSNull) {
                            otherFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.alternate(value) as Any, version: version)
                            expect(subject) != otherFlag
                        }

                        otherFlag = FeatureFlag(value: value, version: version + 1)
                        expect(subject) != otherFlag
                    }
                }
            }
            context("when value only exists") {
                it("compares value and check version is nil") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        subject = FeatureFlag(value: value, version: nil)
                        otherFlag = subject

                        expect(subject) == otherFlag

                        if !(value is NSNull) {
                            otherFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.alternate(value) as Any, version: version)
                            expect(subject) != otherFlag
                        }

                        otherFlag = FeatureFlag(value: value, version: DarklyServiceMock.Constants.version)
                        expect(subject) != otherFlag
                    }
                }
            }
        }
    }

    func matchesValueSpec() {
        var subject: FeatureFlag?
        var version = 0
        var otherFlag: FeatureFlag?

        describe("matchesValue") {
            context("when value and version exists") {
                it("compares value only") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        subject = FeatureFlag(value: value, version: version)
                        otherFlag = subject

                        expect(subject!.matchesValue(otherFlag!)).to(beTrue())

                        if !(value is NSNull) {
                            otherFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.alternate(value) as Any, version: version)
                            expect(subject!.matchesValue(otherFlag!)).to(beFalse())
                        }

                        otherFlag = FeatureFlag(value: value, version: version + 1)
                        expect(subject!.matchesValue(otherFlag!)).to(beTrue())
                    }
                }
            }
            context("when value only exists") {
                it("compares value and check version is nil") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        subject = FeatureFlag(value: value, version: nil)
                        otherFlag = subject

                        expect(subject!.matchesValue(otherFlag!)).to(beTrue())

                        if !(value is NSNull) {
                            otherFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.alternate(value) as Any, version: version)
                            expect(subject!.matchesValue(otherFlag!)).to(beFalse())
                        }

                        otherFlag = FeatureFlag(value: value, version: DarklyServiceMock.Constants.version)
                        expect(subject!.matchesValue(otherFlag!)).to(beTrue())
                    }
                }
            }
        }
    }

    func collectionSpec() {
        describe("dictionaryValue") {
            var featureFlags: [LDFlagKey: FeatureFlag]!
            var subject: [LDFlagKey: Any]!
            //Unwrap the dictionary values that we want to verify match the originals. 2 step process.
            //First step is to unwrap the FeatureFlag dictionary for the specific key
            var subjectFlagDictionary: (LDFlagKey) -> [String: Any]? { return { (key) in subject[key] as? [String: Any] } }
            //Then we can unwrap the value & version. The key here is really just used to pass into the previous closure
            var subjectFlagValue: (LDFlagKey) -> Any? { return { (key) in subjectFlagDictionary(key)?[FeatureFlag.CodingKeys.value.rawValue] } }
            var subjectFlagVersion: (LDFlagKey) -> Int? { return { (key) in subjectFlagDictionary(key)?[FeatureFlag.CodingKeys.version.rawValue] as? Int } }
            context("when not excising nil values") {
                context("with value and version") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true)
                        subject = featureFlags.dictionaryValue(exciseNil: false)
                    }
                    it("creates a matching dictionary that includes nil representations") {
                        featureFlags.forEach { (keyValuePair) in
                            let (key, featureFlag) = keyValuePair
                            if featureFlag.value == nil {
                                expect(subjectFlagValue(key) is NSNull).to(beTrue())
                            } else {
                                expect(AnyComparer.isEqual(subjectFlagValue(key), to: featureFlag.value)).to(beTrue())
                            }
                            expect(subjectFlagVersion(key)) == featureFlag.version
                        }
                    }
                }
                context("with value only") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: false)
                        subject = featureFlags.dictionaryValue(exciseNil: false)
                    }
                    it("creates a matching dictionary that includes nil representations") {
                        featureFlags.forEach { (keyValuePair) in
                            let (key, featureFlag) = keyValuePair
                            if featureFlag.value == nil {
                                expect(subjectFlagValue(key) is NSNull).to(beTrue())
                            } else {
                                expect(AnyComparer.isEqual(subjectFlagValue(key), to: featureFlag.value)).to(beTrue())
                            }
                            expect(subjectFlagDictionary(key)?[FeatureFlag.CodingKeys.version.rawValue] is NSNull).to(beTrue())
                        }
                    }
                }
            }
            context("when excising nil values") {
                context("with value and version") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true)
                        subject = featureFlags.dictionaryValue(exciseNil: true)
                    }
                    it("creates a matching dictionary that excludes nil representations") {
                        featureFlags.forEach { (keyValuePair) in
                            let (key, featureFlag) = keyValuePair
                            if featureFlag.value == nil {
                                expect(subjectFlagDictionary(key)).to(beNil())
                            } else {
                                expect(AnyComparer.isEqual(subjectFlagValue(key), to: featureFlag.value)).to(beTrue())
                                expect(subjectFlagVersion(key)) == featureFlag.version
                            }
                        }
                    }
                }
                context("with value only") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: false)
                        subject = featureFlags.dictionaryValue(exciseNil: true)
                    }
                    it("creates a matching dictionary that includes nil representations") {
                        featureFlags.forEach { (keyValuePair) in
                            let (key, featureFlag) = keyValuePair
                            if featureFlag.value == nil {
                                expect(subjectFlagDictionary(key)).to(beNil())
                            } else {
                                expect(AnyComparer.isEqual(subjectFlagValue(key), to: featureFlag.value)).to(beTrue())
                                expect(subjectFlagVersion(key)) == FeatureFlag.Constants.nilVersionPlaceholder
                            }
                        }
                    }
                }
            }
        }

        describe("flagCollection") {
            var flagDictionary: [LDFlagKey: Any]!
            var subject: [LDFlagKey: FeatureFlag]?
            context("dictionary has feature flag values and versions") {
                beforeEach {
                    flagDictionary = self.flagDictionary(versions: true, exciseNil: false)
                    subject = flagDictionary.flagCollection
                }
                it("creates a matching FeatureFlag dictionary with values and versions") {
                    DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true).forEach { (keyValuePair) in
                        let (key, featureFlag) = keyValuePair
                        if featureFlag.value == nil {
                            expect(subject?[key]?.value).to(beNil())
                        } else {
                            expect(AnyComparer.isEqual(subject?[key]?.value, to: featureFlag.value)).to(beTrue())
                        }
                        expect(subject?[key]?.version) == DarklyServiceMock.Constants.version
                    }
                }
            }
            context("dictionary has feature flag values and nil version placeholders") {
                beforeEach {
                    flagDictionary = self.flagDictionary(versions: false, exciseNil: true)
                    subject = flagDictionary.flagCollection
                }
                it("creates a matching FeatureFlag dictionary with values and nil versions") {
                    DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true).forEach { (keyValuePair) in
                        let (key, featureFlag) = keyValuePair
                        if featureFlag.value == nil {
                            expect(subject?.keys.contains(key)).to(beFalse())
                        } else {
                            expect(AnyComparer.isEqual(subject?[key]?.value, to: featureFlag.value)).to(beTrue())
                            expect(subject?[key]?.version) == FeatureFlag.Constants.nilVersionPlaceholder
                        }
                    }
                }
            }
            context("dictionary has feature flag values only") {
                beforeEach {
                    flagDictionary = [String: Any](uniqueKeysWithValues: zip(DarklyServiceMock.FlagKeys.all, DarklyServiceMock.FlagValues.all))
                    subject = flagDictionary.flagCollection
                }
                it("creates a matching FeatureFlag dictionary with values and nil versions") {
                    flagDictionary.forEach { (keyValuePair) in
                        let (key, value) = keyValuePair
                        if value is NSNull {
                            expect(subject?[key]).toNot(beNil())
                            expect(subject?[key]?.value).to(beNil())
                        } else {
                            expect(AnyComparer.isEqual(subject?[key]?.value, to: value)).to(beTrue())
                        }
                        expect(subject?[key]?.version).to(beNil())
                    }
                }
            }
            context("dictionary already has FeatureFlag values") {
                beforeEach {
                    flagDictionary = DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true)
                    subject = flagDictionary.flagCollection
                }
                it("returns the existing FeatureFlag dictionary") {
                    expect(subject == flagDictionary).to(beTrue())
                }
            }
        }
    }

    func flagDictionary(versions: Bool, exciseNil: Bool) -> [String: Any] {
        return DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true)
            .flatMapValues {(featureFlag) in versions ? featureFlag : FeatureFlag(value: featureFlag.value, version: nil) }
            .dictionaryValue(exciseNil: exciseNil)
    }
}
