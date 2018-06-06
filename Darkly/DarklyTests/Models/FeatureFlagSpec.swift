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
@testable import LaunchDarkly

final class FeatureFlagSpec: QuickSpec {

    struct Constants {
        static let extraDictionaryKey = "FeatureFlagSpec.dictionary.key"
        static let extraDictionaryValue = "FeatureFlagSpec.dictionary.value"
    }

    override func spec() {
        initSpec()
        dictionaryValueSpec()
        equalsSpec()
        matchesValueSpec()
        collectionSpec()
    }

    func initSpec() {
        describe("init") {
            var featureFlag: FeatureFlag!
            context("when elements exist") {
                var version = 0
                var variation: Int { return version + 1 }
                it("creates a feature flag with matching elements") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        featureFlag = FeatureFlag(value: value, variation: variation, version: version)

                        expect(AnyComparer.isEqual(featureFlag.value, to: value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(featureFlag.variation) == variation
                        expect(featureFlag.version) == version
                    }
                }
            }
            context("when elements are nil") {
                beforeEach {
                    featureFlag = FeatureFlag(value: nil, variation: nil, version: nil)
                }
                it("creates a feature flag with nil elements") {
                    expect(featureFlag).toNot(beNil())
                    expect(featureFlag.value).to(beNil())
                    expect(featureFlag.variation).to(beNil())
                    expect(featureFlag.version).to(beNil())
                }
            }
        }

        describe("init with dictionary") {
            var featureFlag: FeatureFlag?
            context("when value and version are the dictionary") {
                var version = 0
                it("creates a feature flag with the value and version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        let dictionaryFromElements = [String: Any](value: value, version: version)

                        featureFlag = FeatureFlag(dictionary: dictionaryFromElements)

                        expect(featureFlag).toNot(beNil())
                        if value is NSNull {
                            expect(featureFlag?.value).to(beNil())
                        } else {
                            expect(AnyComparer.isEqual(featureFlag?.value, to: value)).to(beTrue())
                        }
                        expect(featureFlag?.version) == version
                    }
                }
            }
            context("when value and version are part of the dictionary") {
                var version = 0
                it("creates a feature flag with the value and version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        let dictionaryFromElements = [String: Any](value: value, version: version, includeExtraDictionaryItems: true)

                        featureFlag = FeatureFlag(dictionary: dictionaryFromElements)

                        expect(featureFlag).toNot(beNil())
                        if value is NSNull {
                            expect(featureFlag?.value).to(beNil())
                        } else {
                            expect(AnyComparer.isEqual(featureFlag?.value, to: value)).to(beTrue())
                        }
                        expect(featureFlag?.version) == version
                    }
                }
            }
            context("when the dictionary is the value") {
                beforeEach {
                    featureFlag = FeatureFlag(dictionary: DarklyServiceMock.FlagValues.dictionary)
                }
                it("creates a feature flag with the value but without a version") {
                    expect(featureFlag).toNot(beNil())
                    expect(AnyComparer.isEqual(featureFlag?.value, to: DarklyServiceMock.FlagValues.dictionary)).to(beTrue())
                    expect(featureFlag?.version).to(beNil())
                }
            }
            context("when value only exists in the dictionary") {
                it("it creates a feature flag with the dictionary as the value but without a version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        let dictionaryFromElements = [String: Any](value: value, version: nil)

                        featureFlag = FeatureFlag(dictionary: dictionaryFromElements)

                        expect(featureFlag).toNot(beNil())
                        expect(AnyComparer.isEqual(featureFlag?.value, to: dictionaryFromElements)).to(beTrue())
                        expect(featureFlag?.version).to(beNil())
                    }
                }
            }
            context("when version only exists in the dictionary") {
                var dictionaryFromElements: [String: Any]!
                beforeEach {
                    dictionaryFromElements = [String: Any](value: nil, version: DarklyServiceMock.FlagValues.int)

                    featureFlag = FeatureFlag(dictionary: dictionaryFromElements)
                }
                it("it creates a feature flag with the dictionary as the value but without a version") {
                    expect(AnyComparer.isEqual(featureFlag?.value, to: dictionaryFromElements)).to(beTrue())
                    expect(featureFlag?.version).to(beNil())
                }
            }
            context("when the dictionary is nil") {
                beforeEach {
                    featureFlag = FeatureFlag(dictionary: nil)
                }
                it("returns nil") {
                    expect(featureFlag).to(beNil())
                }
            }
        }

        describe("init with any value") {
            var featureFlag: FeatureFlag?
            context("valid value") {
                it("creates a feature flag with the value but without a version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        featureFlag = FeatureFlag(object: value)

                        expect(featureFlag).toNot(beNil())
                        if value is NSNull {
                            expect(featureFlag?.value).to(beNil())
                        } else {
                            expect(AnyComparer.isEqual(featureFlag?.value, to: value)).to(beTrue())
                        }
                        expect(featureFlag?.version).to(beNil())
                    }
                }
            }
            context("value and version dictionary") {
                var version = 0
                it("creates a feature flag with the value and version") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        version += 1
                        let dictionaryFromElements = [String: Any](value: value, version: version)

                        featureFlag = FeatureFlag(object: dictionaryFromElements)

                        expect(featureFlag).toNot(beNil())
                        if value is NSNull {
                            expect(featureFlag?.value).to(beNil())
                        } else {
                            expect(AnyComparer.isEqual(featureFlag?.value, to: value)).to(beTrue())
                        }
                        expect(featureFlag?.version) == version
                    }
                }
            }
            context("nil") {
                beforeEach {
                    featureFlag = FeatureFlag(object: nil)
                }
                it("returns nil") {
                    expect(featureFlag?.value).to(beNil())
                }
            }
        }
    }

    func dictionaryValueSpec() {
        var featureFlags: [LDFlagKey: FeatureFlag]!
        beforeEach {
            featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false, includeVariations: true, includeVersions: true)    //TODO: Include null value
        }
        describe("dictionaryValue") {
            context("dont exciseNil") {
                context("with elements") {
                    it("creates a dictionary with the value and version including nil value representations") {
                        featureFlags.forEach { (_, featureFlag) in
                            let featureFlagDictionary = featureFlag.dictionaryValue(exciseNil: false)

                            expect(featureFlagDictionary).toNot(beNil())
                            expect(AnyComparer.isEqual(featureFlagDictionary?.value, to: featureFlag.value)).to(beTrue())
//                            expect(featureFlagDictionary?.variation) == featureFlag.variation
                            expect(featureFlagDictionary?.version) == featureFlag.version
                        }
                    }
                }
                context("without elements") {
                    it("creates a dictionary with the value including nil value and version representations") {
                        DarklyServiceMock.FlagValues.all.forEach { (value) in
                            let featureFlag = FeatureFlag(value: value, variation: nil, version: nil)

                            let featureFlagDictionary = featureFlag.dictionaryValue(exciseNil: false)

                            expect(featureFlagDictionary).toNot(beNil())
                            expect(AnyComparer.isEqual(featureFlagDictionary?.value, to: value)).to(beTrue())
                            expect(featureFlagDictionary?.version).to(beNil())
                        }
                    }
                }
                context("dictionary has null value") {
                    var featureFlag: FeatureFlag!
                    var featureFlagDictionary: [String: Any]?
                    let dictionaryValue: [String: Any]! = DarklyServiceMock.FlagValues.dictionary.appendNull()
                    beforeEach {
                        featureFlag = FeatureFlag(value: dictionaryValue, variation: DarklyServiceMock.Constants.variation, version: DarklyServiceMock.Constants.version)

                        featureFlagDictionary = featureFlag.dictionaryValue(exciseNil: false)
                    }
                    it("creates a dictionary with the dictionary value including nil value representation") {
                        expect(featureFlagDictionary).toNot(beNil())
                        expect(AnyComparer.isEqual(featureFlagDictionary?.value, to: dictionaryValue)).to(beTrue())
                        expect(featureFlagDictionary?.version) == DarklyServiceMock.Constants.version
                    }
                }
            }
            context("exciseNil") {
                context("with versions") {
                    var version = 0
                    it("creates a dictionary with the value and version excluding nil values") {
                        DarklyServiceMock.FlagValues.all.forEach { (value) in
                            version += 1
                            let featureFlag = FeatureFlag(value: value, variation: version + 1, version: version)

                            let featureFlagDictionary = featureFlag.dictionaryValue(exciseNil: true)

                            if value is NSNull {
                                expect(featureFlagDictionary).to(beNil())
                            } else {
                                expect(AnyComparer.isEqual(featureFlagDictionary?.value, to: value)).to(beTrue())
                                expect(featureFlagDictionary?.version) == version
                            }
                        }
                    }
                }
                context("without versions") {
                    it("creates a dictionary with the value excluding nil value and version representations") {
                        DarklyServiceMock.FlagValues.all.forEach { (value) in
                            let featureFlag = FeatureFlag(value: value, variation: nil, version: nil)

                            let featureFlagDictionary = featureFlag.dictionaryValue(exciseNil: true)

                            if value is NSNull {
                                expect(featureFlagDictionary).to(beNil())
                            } else {
                                expect(AnyComparer.isEqual(featureFlagDictionary?.value, to: value)).to(beTrue())
                                expect(featureFlagDictionary?.version) == FeatureFlag.Constants.nilVersionPlaceholder
                            }
                        }
                    }
                }
                context("dictionary has null value") {
                    var featureFlag: FeatureFlag!
                    var featureFlagDictionary: [String: Any]?
                    beforeEach {
                        featureFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.dictionary.appendNull(), variation: DarklyServiceMock.Constants.variation, version: DarklyServiceMock.Constants.version)

                        featureFlagDictionary = featureFlag.dictionaryValue(exciseNil: true)
                    }
                    it("creates a dictionary with the dictionary value excluding nil value representation") {
                        expect(featureFlagDictionary).toNot(beNil())
                        expect(AnyComparer.isEqual(featureFlagDictionary?.value, to: DarklyServiceMock.FlagValues.dictionary)).to(beTrue())
                        expect(featureFlagDictionary?.version) == DarklyServiceMock.Constants.version
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
                        let featureFlag = FeatureFlag(value: value, variation: version + 1, version: version)

                        let reinflatedFlag = FeatureFlag(dictionary: featureFlag.dictionaryValue(exciseNil: false))

                        expect(reinflatedFlag).toNot(beNil())
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
                    let featureFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.dictionary.appendNull(), variation: DarklyServiceMock.Constants.variation, version: DarklyServiceMock.FlagValues.int)

                    reinflatedFlag = FeatureFlag(dictionary: featureFlag.dictionaryValue(exciseNil: false))
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
                        subject = FeatureFlag(value: value, variation: version + 1, version: version)
                        otherFlag = subject

                        expect(subject) == otherFlag

                        if !(value is NSNull) {
                            otherFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.alternate(value) as Any, variation: version + 1, version: version)
                            expect(subject) != otherFlag
                        }

                        otherFlag = FeatureFlag(value: value, variation: version + 1, version: version + 1)
                        expect(subject) != otherFlag
                    }
                }
            }
            context("when value only exists") {
                it("compares value and check version is nil") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        subject = FeatureFlag(value: value, variation: nil, version: nil)
                        otherFlag = subject

                        expect(subject) == otherFlag

                        if !(value is NSNull) {
                            otherFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.alternate(value) as Any, variation: version + 1, version: version)
                            expect(subject) != otherFlag
                        }

                        otherFlag = FeatureFlag(value: value, variation: DarklyServiceMock.Constants.variation, version: DarklyServiceMock.Constants.version)
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
                        subject = FeatureFlag(value: value, variation: version + 1, version: version)
                        otherFlag = subject

                        expect(subject!.matchesValue(otherFlag!)).to(beTrue())

                        if !(value is NSNull) {
                            otherFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.alternate(value) as Any, variation: version + 1, version: version)
                            expect(subject!.matchesValue(otherFlag!)).to(beFalse())
                        }

                        otherFlag = FeatureFlag(value: value, variation: version + 1, version: version + 1)
                        expect(subject!.matchesValue(otherFlag!)).to(beTrue())
                    }
                }
            }
            context("when value only exists") {
                it("compares value and check version is nil") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        subject = FeatureFlag(value: value, variation: nil, version: nil)
                        otherFlag = subject

                        expect(subject!.matchesValue(otherFlag!)).to(beTrue())

                        if !(value is NSNull) {
                            otherFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.alternate(value) as Any, variation: version + 1, version: version)
                            expect(subject!.matchesValue(otherFlag!)).to(beFalse())
                        }

                        otherFlag = FeatureFlag(value: value, variation: DarklyServiceMock.Constants.variation, version: DarklyServiceMock.Constants.version)
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
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: true, includeVariations: true, includeVersions: true)
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
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: true, includeVariations: true, includeVersions: false)
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
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: true, includeVariations: true, includeVersions: true)
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
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: true, includeVariations: true, includeVersions: false)
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
                    DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: true, includeVariations: true, includeVersions: true).forEach { (keyValuePair) in
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
                    DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: true, includeVariations: true, includeVersions: true).forEach { (keyValuePair) in
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
                    flagDictionary = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: true, includeVariations: true, includeVersions: true)
                    subject = flagDictionary.flagCollection
                }
                it("returns the existing FeatureFlag dictionary") {
                    expect(subject == flagDictionary).to(beTrue())
                }
            }
        }
    }

    func flagDictionary(versions: Bool, exciseNil: Bool) -> [String: Any] {
        return DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: true, includeVariations: true, includeVersions: true)
            .flatMapValues {(featureFlag) in versions ? featureFlag : FeatureFlag(value: featureFlag.value, variation: nil, version: nil) }
            .dictionaryValue(exciseNil: exciseNil)
    }
}

extension Dictionary where Key == String, Value == Any {
    init(value: Any?, version: Int?, includeExtraDictionaryItems: Bool = false) {
        self.init()
        if let value = value {
            self[FeatureFlag.CodingKeys.value.rawValue] = value
        }
        if let version = version {
            self[FeatureFlag.CodingKeys.version.rawValue] = version
        }
        if includeExtraDictionaryItems {
            self[FeatureFlagSpec.Constants.extraDictionaryKey] = FeatureFlagSpec.Constants.extraDictionaryValue
        }
    }
}

extension AnyComparer {
    static func isEqual(_ value: Any?, to other: Any?, considerNilAndNullEqual: Bool = false) -> Bool {
        if value == nil && other is NSNull { return considerNilAndNullEqual }
        if value is NSNull && other == nil { return considerNilAndNullEqual }
        return isEqual(value, to: other)
    }
}
