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
        matchesVariationSpec()
        collectionSpec()
    }

    func initSpec() {
        describe("init") {
            var featureFlag: FeatureFlag!
            context("when elements exist") {
                var variation = 0
                var flagVersion: Int { return variation + 1 }
                var version: Int { return flagVersion + 1 }
                it("creates a feature flag with matching elements") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        variation += 1

                        featureFlag = FeatureFlag(value: value, variation: variation, version: version, flagVersion: flagVersion)

                        expect(AnyComparer.isEqual(featureFlag.value, to: value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(featureFlag.variation) == variation
                        expect(featureFlag.version) == version
                        expect(featureFlag.flagVersion) == flagVersion
                    }
                }
            }
            context("when elements are nil") {
                beforeEach {
                    featureFlag = FeatureFlag(value: nil, variation: nil, version: nil, flagVersion: nil)
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
            var variation = 0
            var flagVersion: Int { return variation + 1 }
            var version: Int { return flagVersion + 1 }
            var featureFlag: FeatureFlag?
            context("when elements make the whole dictionary") {
                it("creates a feature flag with all elements") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        variation += 1
                        let dictionaryFromElements = Dictionary(value: value, variation: variation, version: version, flagVersion: flagVersion)

                        featureFlag = FeatureFlag(dictionary: dictionaryFromElements)

                        expect(AnyComparer.isEqual(featureFlag?.value, to: value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(featureFlag?.variation) == variation
                        expect(featureFlag?.version) == version
                        expect(featureFlag?.flagVersion) == flagVersion
                    }
                }
            }
            context("when elements are part of the dictionary") {
                it("creates a feature flag with all elements") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        variation += 1
                        let dictionaryFromElements = Dictionary(value: value, variation: variation, version: version, flagVersion: flagVersion, includeExtraDictionaryItems: true)

                        featureFlag = FeatureFlag(dictionary: dictionaryFromElements)

                        expect(AnyComparer.isEqual(featureFlag?.value, to: value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(featureFlag?.variation) == variation
                        expect(featureFlag?.version) == version
                        expect(featureFlag?.flagVersion) == flagVersion
                    }
                }
            }
            context("when dictionary only contains value") {
                it("it creates a feature flag with the value only") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        let dictionaryFromElements = Dictionary(value: value, variation: nil, version: nil, flagVersion: nil)

                        featureFlag = FeatureFlag(dictionary: dictionaryFromElements)

                        expect(AnyComparer.isEqual(featureFlag?.value, to: value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(featureFlag?.variation).to(beNil())
                        expect(featureFlag?.version).to(beNil())
                        expect(featureFlag?.flagVersion).to(beNil())
                    }
                }
            }
            context("when dictionary only contains variation") {
                beforeEach {
                    let dictionaryFromElements = Dictionary(value: nil, variation: DarklyServiceMock.Constants.variation, version: nil, flagVersion: nil)

                    featureFlag = FeatureFlag(dictionary: dictionaryFromElements)
                }
                it("it creates a feature flag with the variation only") {
                    expect(featureFlag?.value).to(beNil())
                    expect(featureFlag?.variation) == DarklyServiceMock.Constants.variation
                    expect(featureFlag?.version).to(beNil())
                    expect(featureFlag?.flagVersion).to(beNil())
                }
            }
            context("when dictionary only contains version") {
                beforeEach {
                    let dictionaryFromElements = Dictionary(value: nil, variation: nil, version: DarklyServiceMock.Constants.version, flagVersion: nil)

                    featureFlag = FeatureFlag(dictionary: dictionaryFromElements)
                }
                it("it creates a feature flag with the version only") {
                    expect(featureFlag?.value).to(beNil())
                    expect(featureFlag?.variation).to(beNil())
                    expect(featureFlag?.version) == DarklyServiceMock.Constants.version
                    expect(featureFlag?.flagVersion).to(beNil())
                }
            }
            context("when dictionary only contains flagVersion") {
                beforeEach {
                    let dictionaryFromElements = Dictionary(value: nil, variation: nil, version: nil, flagVersion: DarklyServiceMock.Constants.flagVersion)

                    featureFlag = FeatureFlag(dictionary: dictionaryFromElements)
                }
                it("it creates a feature flag with the version only") {
                    expect(featureFlag?.value).to(beNil())
                    expect(featureFlag?.variation).to(beNil())
                    expect(featureFlag?.version).to(beNil())
                    expect(featureFlag?.flagVersion) == DarklyServiceMock.Constants.flagVersion
                }
            }
            context("when the dictionary does not contain any element") {
                beforeEach {
                    featureFlag = FeatureFlag(dictionary: DarklyServiceMock.FlagValues.dictionary)
                }
                it("it does not create a feature flag") {
                    expect(featureFlag).to(beNil())
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

        describe("init with any object") {
            var variation = 0
            var flagVersion: Int { return variation + 1 }
            var version: Int { return flagVersion + 1 }
            var featureFlag: FeatureFlag?
            context("object is a dictionary with all elements") {
                it("creates a feature flag with all elements") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        variation += 1
                        let object: Any? = Dictionary(value: value, variation: variation, version: version, flagVersion: flagVersion)

                        featureFlag = FeatureFlag(object: object)

                        expect(AnyComparer.isEqual(featureFlag?.value, to: value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(featureFlag?.variation) == variation
                        expect(featureFlag?.version) == version
                        expect(featureFlag?.flagVersion) == flagVersion
                    }
                }
            }
            context("object is any value") {
                it("returns nil") {
                    DarklyServiceMock.FlagValues.all.forEach { (value) in
                        featureFlag = FeatureFlag(object: value)

                        expect(featureFlag).to(beNil())
                    }
                }
            }
            context("nil") {
                beforeEach {
                    featureFlag = FeatureFlag(object: nil)
                }
                it("returns nil") {
                    expect(featureFlag).to(beNil())
                }
            }
        }
    }

    func dictionaryValueSpec() {
        var featureFlags: [LDFlagKey: FeatureFlag]!
        describe("dictionaryValue") {
            context("when not excising nil values") {
                context("with elements") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                    }
                    it("creates a dictionary with all elements including nil value representations") {
                        featureFlags.forEach { (_, featureFlag) in
                            let featureFlagDictionary = featureFlag.dictionaryValue(exciseNil: false)

                            expect(featureFlagDictionary).toNot(beNil())
                            expect(AnyComparer.isEqual(featureFlagDictionary?.value, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                            expect(featureFlagDictionary?.variation) == featureFlag.variation
                            expect(featureFlagDictionary?.version) == featureFlag.version
                            expect(featureFlagDictionary?.flagVersion) == featureFlag.flagVersion
                        }
                    }
                }
                context("without elements") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeVariations: false, includeVersions: false, includeFlagVersions: false)
                    }
                    it("creates a dictionary with the value including nil value and version representations") {
                        featureFlags.forEach { (_, featureFlag) in
                            let featureFlagDictionary = featureFlag.dictionaryValue(exciseNil: false)

                            expect(featureFlagDictionary).toNot(beNil())
                            expect(AnyComparer.isEqual(featureFlagDictionary?.value, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                            expect(featureFlagDictionary?.variation).to(beNil())
                            expect(featureFlagDictionary?.version).to(beNil())
                            expect(featureFlagDictionary?.flagVersion).to(beNil())
                        }
                    }
                }
            }
            context("when excising nil values") {
                context("with elements") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                    }
                    it("creates a dictionary that excludes nil value representations") {
                        featureFlags.forEach { (_, featureFlag) in
                            let featureFlagDictionary = featureFlag.dictionaryValue(exciseNil: true)

                            expect(AnyComparer.isEqual(featureFlagDictionary?.value, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                            expect(featureFlagDictionary?.variation) == featureFlag.variation
                            expect(featureFlagDictionary?.version) == featureFlag.version
                            expect(featureFlagDictionary?.flagVersion) == featureFlag.flagVersion
                        }
                    }
                }
                context("without elements") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeVariations: false, includeVersions: false, includeFlagVersions: false)
                    }
                    it("creates a dictionary with the value excluding nil value and version representations") {
                        featureFlags.forEach { (_, featureFlag) in
                            let featureFlagDictionary = featureFlag.dictionaryValue(exciseNil: true)

                            if featureFlag.value is NSNull {
                                expect(featureFlagDictionary?.value).to(beNil())
                            } else {
                                expect(AnyComparer.isEqual(featureFlagDictionary?.value, to: featureFlag.value)).to(beTrue())
                            }
                            expect(featureFlagDictionary?.variation).to(beNil())
                            expect(featureFlagDictionary?.version).to(beNil())
                            expect(featureFlagDictionary?.flagVersion).to(beNil())
                        }
                    }
                }
            }
        }

        describe("dictionary restores to feature flag") {
            context("with elements") {
                var featureFlags: [LDFlagKey: FeatureFlag]!
                beforeEach {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                }
                it("creates a feature flag with the same elements as the original") {
                    featureFlags.forEach { (_, featureFlag) in
                        let reinflatedFlag = FeatureFlag(dictionary: featureFlag.dictionaryValue(exciseNil: false))

                        expect(reinflatedFlag).toNot(beNil())
                        expect(AnyComparer.isEqual(reinflatedFlag?.value, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(reinflatedFlag?.version) == featureFlag.version
                        expect(reinflatedFlag?.flagVersion) == featureFlag.flagVersion
                    }
                }
            }
            context("dictionary has null value") {
                var reinflatedFlag: FeatureFlag?
                beforeEach {
                    let featureFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.dictionary.appendNull(),
                                                  variation: DarklyServiceMock.Constants.variation,
                                                  version: DarklyServiceMock.Constants.version,
                                                  flagVersion: DarklyServiceMock.Constants.flagVersion)

                    reinflatedFlag = FeatureFlag(dictionary: featureFlag.dictionaryValue(exciseNil: false))
                }
                it("creates a feature flag with the same elements as the original") {
                    expect(reinflatedFlag).toNot(beNil())
                    expect(AnyComparer.isEqual(reinflatedFlag?.value, to: DarklyServiceMock.FlagValues.dictionary.appendNull())).to(beTrue())
                    expect(reinflatedFlag?.version) == DarklyServiceMock.Constants.version
                    expect(reinflatedFlag?.flagVersion) == DarklyServiceMock.Constants.flagVersion
                }
            }
        }
    }

    func equalsSpec() {
        var originalFlags: [LDFlagKey: FeatureFlag]!
        var otherFlag: FeatureFlag!
        describe("equals") {
            context("when elements exists") {
                beforeEach {
                    originalFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                }
                context("when variation and version match") {
                    it("returns true") {
                        originalFlags.forEach { (_, originalFlag) in
                            otherFlag = FeatureFlag(value: originalFlag.value, variation: originalFlag.variation, version: originalFlag.version, flagVersion: originalFlag.flagVersion)

                            expect(originalFlag == otherFlag).to(beTrue())
                        }
                    }
                }
                context("when values differ") {
                    it("returns true") {    //This is a weird effect of comparing the variation, and not the value itself. The server should not return different values for the same variation.
                        originalFlags.forEach { (_, originalFlag) in
                            if originalFlag.value == nil { return }
                            otherFlag = FeatureFlag(value: DarklyServiceMock.FlagValues.alternate(originalFlag.value),
                                                    variation: originalFlag.variation,
                                                    version: originalFlag.version,
                                                    flagVersion: originalFlag.flagVersion)

                            expect(originalFlag == otherFlag).to(beTrue())
                        }
                    }
                }
                context("when variations differ") {
                    it("returns false") {
                        originalFlags.forEach { (_, originalFlag) in
                            otherFlag = FeatureFlag(value: originalFlag.value,
                                                    variation: DarklyServiceMock.Constants.variation + 1,
                                                    version: originalFlag.version,
                                                    flagVersion: originalFlag.flagVersion)

                            expect(originalFlag == otherFlag).to(beFalse())
                        }
                    }
                }
                context("when versions differ") {
                    it("returns false") {
                        originalFlags.forEach { (_, originalFlag) in
                            otherFlag = FeatureFlag(value: originalFlag.value,
                                                    variation: originalFlag.variation,
                                                    version: DarklyServiceMock.Constants.version + 1,
                                                    flagVersion: originalFlag.flagVersion)

                            expect(originalFlag == otherFlag).to(beFalse())
                        }
                    }
                }
                context("when flagVersions differ") {
                    it("returns true") {
                        originalFlags.forEach { (_, originalFlag) in
                            otherFlag = FeatureFlag(value: originalFlag.value,
                                                    variation: originalFlag.variation,
                                                    version: originalFlag.version,
                                                    flagVersion: DarklyServiceMock.Constants.flagVersion + 1)

                            expect(originalFlag == otherFlag).to(beTrue())
                        }
                    }
                }
            }
            context("when value only exists") {
                beforeEach {
                    originalFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeVariations: false, includeVersions: false, includeFlagVersions: false)
                }
                it("returns true") {
                    originalFlags.forEach { (_, originalFlag) in
                        otherFlag = FeatureFlag(value: originalFlag.value, variation: nil, version: nil, flagVersion: nil)

                        expect(originalFlag == otherFlag).to(beTrue())
                    }
                }
            }
        }
    }

    func matchesVariationSpec() {
        var featureFlags: [LDFlagKey: FeatureFlag]!
        var otherFlag: FeatureFlag!
        describe("matchesVariation") {
            context("when elements exist") {
                beforeEach {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                }
                context("and variations match") {
                    it("returns true") {
                        featureFlags.forEach { (_, originalFlag) in
                            otherFlag = FeatureFlag(value: originalFlag.value, variation: originalFlag.variation, version: originalFlag.version, flagVersion: originalFlag.flagVersion)

                            expect(originalFlag.matchesVariation(otherFlag)).to(beTrue())
                        }
                    }
                }
                context("and variations do not match") {
                    it("returns false") {
                        featureFlags.forEach { (_, originalFlag) in
                            otherFlag = FeatureFlag(value: originalFlag.value, variation: originalFlag.variation! + 1, version: originalFlag.version, flagVersion: originalFlag.flagVersion)

                            expect(originalFlag.matchesVariation(otherFlag)).to(beFalse())
                        }
                    }
                }
            }
            context("when variation does not exist") {
                beforeEach {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeVariations: false, includeVersions: true)
                }
                it("compares value and check version is nil") {
                    featureFlags.forEach { (_, originalFlag) in
                        otherFlag = FeatureFlag(value: originalFlag.value, variation: nil, version: originalFlag.version, flagVersion: originalFlag.flagVersion)

                        expect(originalFlag.matchesVariation(otherFlag)).to(beTrue())
                    }
                }
            }
        }
    }

    func collectionSpec() {
        describe("dictionaryValue") {
            var featureFlags: [LDFlagKey: FeatureFlag]!
            var featureFlagDictionaries: [LDFlagKey: Any]!
            var featureFlagDictionary: [String: Any]?
            context("when not excising nil values") {
                context("with elements") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()

                        featureFlagDictionaries = featureFlags.dictionaryValue(exciseNil: false)
                    }
                    it("creates a matching dictionary that includes nil representations") {
                        featureFlags.forEach { (key, featureFlag) in
                            featureFlagDictionary = featureFlagDictionaries[key] as? [String: Any]

                            expect(featureFlagDictionary).toNot(beNil())
                            expect(AnyComparer.isEqual(featureFlagDictionary?.value, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                            expect(featureFlagDictionary?.variation) == featureFlag.variation
                            expect(featureFlagDictionary?.version) == featureFlag.version
                            expect(featureFlagDictionary?.flagVersion) == featureFlag.flagVersion
                        }
                    }
                }
                context("without elements") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeVariations: false, includeVersions: false, includeFlagVersions: false)

                        featureFlagDictionaries = featureFlags.dictionaryValue(exciseNil: false)
                    }
                    it("creates a matching dictionary that includes nil representations") {
                        featureFlags.forEach { (key, featureFlag) in
                            featureFlagDictionary = featureFlagDictionaries[key] as? [String: Any]

                            expect(featureFlagDictionary).toNot(beNil())
                            expect(AnyComparer.isEqual(featureFlagDictionary?.value, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                            expect(featureFlagDictionary?.variation).to(beNil())
                            expect(featureFlagDictionary?.version).to(beNil())
                            expect(featureFlagDictionary?.flagVersion).to(beNil())
                        }
                    }
                }
            }
            context("when excising nil values") {
                context("with elements") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: true)

                        featureFlagDictionaries = featureFlags.dictionaryValue(exciseNil: true)
                    }
                    it("creates a matching dictionary that excludes nil value representations") {
                        featureFlags.forEach { (key, featureFlag) in
                            featureFlagDictionary = featureFlagDictionaries[key] as? [String: Any]

                            if featureFlag.value == nil {
                                expect(featureFlagDictionary?.value).to(beNil())
                            } else {
                                expect(AnyComparer.isEqual(featureFlagDictionary?.value, to: featureFlag.value)).to(beTrue())
                            }
                            expect(featureFlagDictionary?.variation) == featureFlag.variation
                            expect(featureFlagDictionary?.version) == featureFlag.version
                            expect(featureFlagDictionary?.flagVersion) == featureFlag.flagVersion
                        }
                    }
                }
                context("without elements") {
                    beforeEach {
                        featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: true, includeVariations: false, includeVersions: false, includeFlagVersions: false)
                        featureFlagDictionaries = featureFlags.dictionaryValue(exciseNil: true)
                    }
                    it("creates a matching dictionary that includes nil representations") {
                        featureFlags.forEach { (key, featureFlag) in
                            featureFlagDictionary = featureFlagDictionaries[key] as? [String: Any]

                            if featureFlag.value is NSNull {
                                expect(featureFlagDictionary?.value).to(beNil())
                            } else {
                                expect(AnyComparer.isEqual(featureFlagDictionary?.value, to: featureFlag.value)).to(beTrue())
                            }
                            expect(featureFlagDictionary?.variation).to(beNil())
                            expect(featureFlagDictionary?.version).to(beNil())
                            expect(featureFlagDictionary?.flagVersion).to(beNil())
                        }
                    }
                }
            }
        }

        describe("flagCollection") {
            var flagDictionaries: [LDFlagKey: Any]!
            var flagDictionary: [String: Any]?
            var featureFlags: [LDFlagKey: FeatureFlag]?
            var featureFlag: FeatureFlag?
            context("dictionary has feature flag elements") {
                beforeEach {
                    flagDictionaries = DarklyServiceMock.Constants.stubFeatureFlags().dictionaryValue(exciseNil: false)

                    featureFlags = flagDictionaries.flagCollection
                }
                it("creates matching FeatureFlags with flag elements") {
                    flagDictionaries.forEach { (key, object) in
                        flagDictionary = object as? [String: Any]
                        featureFlag = featureFlags?[key]

                        expect(AnyComparer.isEqual(featureFlag?.value, to: flagDictionary?.value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(featureFlag?.variation) == flagDictionary?.variation
                        expect(featureFlag?.version) == flagDictionary?.version
                        expect(featureFlag?.flagVersion) == flagDictionary?.flagVersion
                    }
                }
            }
            context("dictionary has flag values without nil version placeholders") {
                beforeEach {
                    flagDictionaries = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false, includeVariations: false, includeVersions: false, includeFlagVersions: false)
                        .dictionaryValue(exciseNil: true)

                    featureFlags = flagDictionaries.flagCollection
                }
                it("creates matching FeatureFlags without missing elements") {
                    flagDictionaries.forEach { (key, object) in
                        flagDictionary = object as? [String: Any]
                        featureFlag = featureFlags?[key]

                        expect(AnyComparer.isEqual(featureFlag?.value, to: flagDictionary?.value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(featureFlag?.variation).to(beNil())
                        expect(featureFlag?.version).to(beNil())
                        expect(featureFlag?.flagVersion).to(beNil())
                    }
                }
            }
            context("dictionary already has FeatureFlag values") {
                beforeEach {
                    flagDictionaries = DarklyServiceMock.Constants.stubFeatureFlags()

                    featureFlags = flagDictionaries.flagCollection
                }
                it("returns the existing FeatureFlag dictionary") {
                    expect(featureFlags == flagDictionaries).to(beTrue())
                }
            }
            context("dictionary does not all convert into FeatureFlags") {
                beforeEach {
                    flagDictionaries = DarklyServiceMock.Constants.stubFeatureFlags(includeVariations: false, includeVersions: false, includeFlagVersions: false)
                        .dictionaryValue(exciseNil: true)

                    featureFlags = flagDictionaries.flagCollection
                }
                it("returns nil") {
                    expect(featureFlags).to(beNil())
                }
            }
        }
    }
}

extension Dictionary where Key == String, Value == Any {
    init(value: Any?, variation: Int?, version: Int?, flagVersion: Int?, includeExtraDictionaryItems: Bool = false) {
        self.init()
        if let value = value {
            self[FeatureFlag.CodingKeys.value.rawValue] = value
        }
        if let variation = variation {
            self[FeatureFlag.CodingKeys.variation.rawValue] = variation
        }
        if let version = version {
            self[FeatureFlag.CodingKeys.version.rawValue] = version
        }
        if let flagVersion = flagVersion {
            self[FeatureFlag.CodingKeys.flagVersion.rawValue] = flagVersion
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

extension FeatureFlag {
    static let nilPlaceholder = -1
    func allPropertiesMatch(_ otherFlag: FeatureFlag) -> Bool {
        return AnyComparer.isEqual(self.value, to: otherFlag.value, considerNilAndNullEqual: true)
            && variation ?? FeatureFlag.nilPlaceholder == otherFlag.variation ?? FeatureFlag.nilPlaceholder
            && version ?? FeatureFlag.nilPlaceholder == otherFlag.version ?? FeatureFlag.nilPlaceholder
            && flagVersion ?? FeatureFlag.nilPlaceholder == otherFlag.flagVersion ?? FeatureFlag.nilPlaceholder
    }
}
