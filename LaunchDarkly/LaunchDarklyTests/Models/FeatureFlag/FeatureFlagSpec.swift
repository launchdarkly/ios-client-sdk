//
//  FeatureFlagSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 2/19/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
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
                var flagVersion: Int {
                    return variation + 1
                }
                var version: Int {
                    return flagVersion + 1
                }
                let eventTrackingContext = EventTrackingContext.stub()
                it("creates a feature flag with matching elements") {
                    DarklyServiceMock.FlagKeys.knownFlags.forEach { (flagKey) in
                        let value = DarklyServiceMock.FlagValues.value(from: flagKey)
                        variation += 1

                        featureFlag = FeatureFlag(flagKey: flagKey, value: value, variation: variation, version: version, flagVersion: flagVersion, eventTrackingContext: eventTrackingContext)

                        expect(featureFlag.flagKey) == flagKey
                        expect(AnyComparer.isEqual(featureFlag.value, to: value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(featureFlag.variation) == variation
                        expect(featureFlag.version) == version
                        expect(featureFlag.flagVersion) == flagVersion
                        expect(featureFlag.eventTrackingContext?.trackEvents) == eventTrackingContext.trackEvents
                    }
                }
            }
            context("when elements don't exist") {
                beforeEach {
                    featureFlag = FeatureFlag(flagKey: DarklyServiceMock.FlagKeys.unknown, value: nil, variation: nil, version: nil, flagVersion: nil, eventTrackingContext: nil)
                }
                it("creates a feature flag with nil elements") {
                    expect(featureFlag).toNot(beNil())
                    expect(featureFlag.flagKey) == DarklyServiceMock.FlagKeys.unknown
                    expect(featureFlag.value).to(beNil())
                    expect(featureFlag.variation).to(beNil())
                    expect(featureFlag.version).to(beNil())
                    expect(featureFlag.eventTrackingContext).to(beNil())
                }
            }
        }

        describe("init with dictionary") {
            var variation = 0
            var flagVersion: Int {
                return variation + 1
            }
            var version: Int {
                return flagVersion + 1
            }
            let trackEvents = true
            var featureFlag: FeatureFlag?
            context("when elements make the whole dictionary") {
                it("creates a feature flag with all elements") {
                    DarklyServiceMock.FlagKeys.knownFlags.forEach { (flagKey) in
                        let value = DarklyServiceMock.FlagValues.value(from: flagKey)
                        variation += 1
                        let dictionaryFromElements = Dictionary(flagKey: flagKey, value: value, variation: variation, version: version, flagVersion: flagVersion, trackEvents: trackEvents)

                        featureFlag = FeatureFlag(dictionary: dictionaryFromElements)

                        expect(featureFlag?.flagKey) == flagKey
                        expect(AnyComparer.isEqual(featureFlag?.value, to: value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(featureFlag?.variation) == variation
                        expect(featureFlag?.version) == version
                        expect(featureFlag?.flagVersion) == flagVersion
                        expect(featureFlag?.eventTrackingContext?.trackEvents) == trackEvents
                    }
                }
            }
            context("when elements are part of the dictionary") {
                it("creates a feature flag with all elements") {
                    DarklyServiceMock.FlagKeys.knownFlags.forEach { (flagKey) in
                        let value = DarklyServiceMock.FlagValues.value(from: flagKey)
                        variation += 1
                        let dictionaryFromElements = Dictionary(flagKey: flagKey,
                                                                value: value,
                                                                variation: variation,
                                                                version: version,
                                                                flagVersion: flagVersion,
                                                                trackEvents: trackEvents,
                                                                includeExtraDictionaryItems: true)

                        featureFlag = FeatureFlag(dictionary: dictionaryFromElements)

                        expect(featureFlag?.flagKey) == flagKey
                        expect(AnyComparer.isEqual(featureFlag?.value, to: value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(featureFlag?.variation) == variation
                        expect(featureFlag?.version) == version
                        expect(featureFlag?.flagVersion) == flagVersion
                        expect(featureFlag?.eventTrackingContext?.trackEvents) == trackEvents
                    }
                }
            }
            context("when dictionary only contains the key and value") {
                it("it creates a feature flag with the key and value only") {
                    DarklyServiceMock.FlagKeys.knownFlags.forEach { (flagKey) in
                        let value = DarklyServiceMock.FlagValues.value(from: flagKey)
                        let dictionaryFromElements = Dictionary(flagKey: flagKey, value: value, variation: nil, version: nil, flagVersion: nil, trackEvents: nil)

                        featureFlag = FeatureFlag(dictionary: dictionaryFromElements)

                        expect(featureFlag?.flagKey) == flagKey
                        expect(AnyComparer.isEqual(featureFlag?.value, to: value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(featureFlag?.variation).to(beNil())
                        expect(featureFlag?.version).to(beNil())
                        expect(featureFlag?.flagVersion).to(beNil())
                        expect(featureFlag?.eventTrackingContext).to(beNil())
                    }
                }
            }
            context("when dictionary only contains the key and variation") {
                beforeEach {
                    let dictionaryFromElements = Dictionary(flagKey: DarklyServiceMock.FlagKeys.null,
                                                            value: nil,
                                                            variation: DarklyServiceMock.Constants.variation,
                                                            version: nil,
                                                            flagVersion: nil,
                                                            trackEvents: nil)

                    featureFlag = FeatureFlag(dictionary: dictionaryFromElements)
                }
                it("it creates a feature flag with the key and variation only") {
                    expect(featureFlag?.flagKey) == DarklyServiceMock.FlagKeys.null
                    expect(featureFlag?.value).to(beNil())
                    expect(featureFlag?.variation) == DarklyServiceMock.Constants.variation
                    expect(featureFlag?.version).to(beNil())
                    expect(featureFlag?.flagVersion).to(beNil())
                    expect(featureFlag?.eventTrackingContext).to(beNil())
                }
            }
            context("when dictionary only contains the key and version") {
                beforeEach {
                    let dictionaryFromElements = Dictionary(flagKey: DarklyServiceMock.FlagKeys.null,
                                                            value: nil,
                                                            variation: nil,
                                                            version: DarklyServiceMock.Constants.version,
                                                            flagVersion: nil, trackEvents: nil)

                    featureFlag = FeatureFlag(dictionary: dictionaryFromElements)
                }
                it("it creates a feature flag with the key and version only") {
                    expect(featureFlag?.flagKey) == DarklyServiceMock.FlagKeys.null
                    expect(featureFlag?.value).to(beNil())
                    expect(featureFlag?.variation).to(beNil())
                    expect(featureFlag?.version) == DarklyServiceMock.Constants.version
                    expect(featureFlag?.flagVersion).to(beNil())
                    expect(featureFlag?.eventTrackingContext).to(beNil())
                }
            }
            context("when dictionary only contains the key and flagVersion") {
                beforeEach {
                    let dictionaryFromElements = Dictionary(flagKey: DarklyServiceMock.FlagKeys.null,
                                                            value: nil,
                                                            variation: nil,
                                                            version: nil,
                                                            flagVersion: DarklyServiceMock.Constants.flagVersion,
                                                            trackEvents: nil)

                    featureFlag = FeatureFlag(dictionary: dictionaryFromElements)
                }
                it("it creates a feature flag with the key and version only") {
                    expect(featureFlag?.flagKey) == DarklyServiceMock.FlagKeys.null
                    expect(featureFlag?.value).to(beNil())
                    expect(featureFlag?.variation).to(beNil())
                    expect(featureFlag?.version).to(beNil())
                    expect(featureFlag?.flagVersion) == DarklyServiceMock.Constants.flagVersion
                    expect(featureFlag?.eventTrackingContext).to(beNil())
                }
            }
            context("when dictionary only contains the key and trackEvents") {
                beforeEach {
                    let dictionaryFromElements = Dictionary(flagKey: DarklyServiceMock.FlagKeys.null, value: nil, variation: nil, version: nil, flagVersion: nil, trackEvents: trackEvents)

                    featureFlag = FeatureFlag(dictionary: dictionaryFromElements)
                }
                it("it creates a feature flag with the key and trackEvents") {
                    expect(featureFlag?.flagKey) == DarklyServiceMock.FlagKeys.null
                    expect(featureFlag?.value).to(beNil())
                    expect(featureFlag?.variation).to(beNil())
                    expect(featureFlag?.version).to(beNil())
                    expect(featureFlag?.flagVersion).to(beNil())
                    expect(featureFlag?.eventTrackingContext?.trackEvents) == trackEvents
                }
            }
            context("when dictionary does not contain the flag key") {
                beforeEach {
                    let dictionaryFromElements = Dictionary(flagKey: nil,
                                                            value: DarklyServiceMock.FlagValues.bool,
                                                            variation: variation,
                                                            version: version,
                                                            flagVersion: flagVersion,
                                                            trackEvents: trackEvents)

                    featureFlag = FeatureFlag(dictionary: dictionaryFromElements)
                }
                it("it does not create a feature flag") {
                    expect(featureFlag).to(beNil())
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
    }

    func dictionaryValueSpec() {
        var featureFlags: [LDFlagKey: FeatureFlag]!
        describe("dictionaryValue") {
            context("with elements") {
                beforeEach {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                }
                it("creates a dictionary with all elements including nil value representations") {
                    featureFlags.forEach { (flagKey, featureFlag) in
                        let featureFlagDictionary = featureFlag.dictionaryValue

                        expect(featureFlagDictionary.flagKey) == flagKey
                        expect(AnyComparer.isEqual(featureFlagDictionary.value, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(featureFlagDictionary.variation) == featureFlag.variation
                        expect(featureFlagDictionary.version) == featureFlag.version
                        expect(featureFlagDictionary.flagVersion) == featureFlag.flagVersion
                        expect(featureFlagDictionary.trackEvents) == featureFlag.eventTrackingContext?.trackEvents
                    }
                }
            }
            context("without elements") {
                beforeEach {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeVariations: false, includeVersions: false, includeFlagVersions: false, eventTrackingContext: nil)
                }
                it("creates a dictionary with the value including nil value and version representations") {
                    featureFlags.forEach { (flagKey, featureFlag) in
                        let featureFlagDictionary = featureFlag.dictionaryValue

                        expect(featureFlagDictionary).toNot(beNil())
                        expect(featureFlagDictionary.flagKey) == flagKey
                        expect(AnyComparer.isEqual(featureFlagDictionary.value, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(featureFlagDictionary.variation).to(beNil())
                        expect(featureFlagDictionary.version).to(beNil())
                        expect(featureFlagDictionary.flagVersion).to(beNil())
                        expect(featureFlagDictionary.trackEvents).to(beNil())
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
                    featureFlags.forEach { (flagKey, featureFlag) in
                        let reinflatedFlag = FeatureFlag(dictionary: featureFlag.dictionaryValue)

                        expect(reinflatedFlag).toNot(beNil())
                        expect(reinflatedFlag?.flagKey) == flagKey
                        expect(AnyComparer.isEqual(reinflatedFlag?.value, to: featureFlag.value, considerNilAndNullEqual: true)).to(beTrue())
                        expect(reinflatedFlag?.version) == featureFlag.version
                        expect(reinflatedFlag?.flagVersion) == featureFlag.flagVersion
                        expect(reinflatedFlag?.eventTrackingContext?.trackEvents) == featureFlag.eventTrackingContext?.trackEvents
                    }
                }
            }
            context("dictionary has null value") {
                var reinflatedFlag: FeatureFlag?
                let eventTrackingContext = EventTrackingContext.stub()
                beforeEach {
                    let featureFlag = FeatureFlag(flagKey: DarklyServiceMock.FlagKeys.dictionary,
                                                  value: DarklyServiceMock.FlagValues.dictionary.appendNull(),
                                                  variation: DarklyServiceMock.Constants.variation,
                                                  version: DarklyServiceMock.Constants.version,
                                                  flagVersion: DarklyServiceMock.Constants.flagVersion,
                                                  eventTrackingContext: eventTrackingContext)

                    reinflatedFlag = FeatureFlag(dictionary: featureFlag.dictionaryValue)
                }
                it("creates a feature flag with the same elements as the original") {
                    expect(reinflatedFlag).toNot(beNil())
                    expect(reinflatedFlag?.flagKey) == DarklyServiceMock.FlagKeys.dictionary
                    expect(AnyComparer.isEqual(reinflatedFlag?.value, to: DarklyServiceMock.FlagValues.dictionary.appendNull())).to(beTrue())
                    expect(reinflatedFlag?.version) == DarklyServiceMock.Constants.version
                    expect(reinflatedFlag?.flagVersion) == DarklyServiceMock.Constants.flagVersion
                    expect(reinflatedFlag?.eventTrackingContext?.trackEvents) == eventTrackingContext.trackEvents
                }
            }
        }
    }

    func equalsSpec() {
        var originalFlags: [LDFlagKey: FeatureFlag]!
        var otherFlag: FeatureFlag!
        describe("equals") {
            context("when elements exist") {
                beforeEach {
                    originalFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                }
                context("when variation and version match") {
                    it("returns true") {
                        originalFlags.forEach { (_, originalFlag) in
                            otherFlag = FeatureFlag(copying: originalFlag)

                            expect(originalFlag == otherFlag).to(beTrue())
                        }
                    }
                }
                context("when keys differ") {
                    it("returns false") {
                        originalFlags.forEach { (_, originalFlag) in
                            otherFlag = FeatureFlag(flagKey: "dummyFlagKey", value: originalFlag.value, variation: originalFlag.variation, version: originalFlag.version, flagVersion: originalFlag.flagVersion, eventTrackingContext: originalFlag.eventTrackingContext)

                            expect(originalFlag == otherFlag).to(beFalse())
                        }
                    }
                }
                context("when values differ") {
                    it("returns true") {    //This is a weird effect of comparing the variation, and not the value itself. The server should not return different values for the same variation.
                        originalFlags.forEach { (_, originalFlag) in
                            if originalFlag.value == nil {
                                return
                            }
                            otherFlag = FeatureFlag(copying: originalFlag, value: DarklyServiceMock.FlagValues.alternate(originalFlag.value))

                            expect(originalFlag == otherFlag).to(beTrue())
                        }
                    }
                }
                context("when variations differ") {
                    context("when both variations exist") {
                        it("returns false") {
                            originalFlags.forEach { (_, originalFlag) in
                                otherFlag = FeatureFlag(copying: originalFlag, variation: DarklyServiceMock.Constants.variation + 1)

                                expect(originalFlag == otherFlag).to(beFalse())
                            }
                        }
                    }
                    context("when one variation is missing") {
                        beforeEach {
                            originalFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeVariations: false)
                        }
                        it("returns false") {
                            originalFlags.forEach { (_, originalFlag) in
                                otherFlag = FeatureFlag(copying: originalFlag, variation: DarklyServiceMock.Constants.variation)

                                expect(originalFlag == otherFlag).to(beFalse())
                            }
                        }
                    }
                }
                context("when versions differ") {
                    context("when both versions exist") {
                        it("returns false") {
                            originalFlags.forEach { (_, originalFlag) in
                                otherFlag = FeatureFlag(copying: originalFlag, version: DarklyServiceMock.Constants.version + 1)

                                expect(originalFlag == otherFlag).to(beFalse())
                            }
                        }
                    }
                    context("when one version is missing") {
                        beforeEach {
                            originalFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeVersions: false)
                        }
                        it("returns false") {
                            originalFlags.forEach { (_, originalFlag) in
                                otherFlag = FeatureFlag(copying: originalFlag, version: DarklyServiceMock.Constants.version)

                                expect(originalFlag == otherFlag).to(beFalse())
                            }
                        }
                    }
                }
                context("when flagVersions differ") {
                    it("returns true") {
                        originalFlags.forEach { (_, originalFlag) in
                            otherFlag = FeatureFlag(copying: originalFlag, flagVersion: DarklyServiceMock.Constants.flagVersion + 1)

                            expect(originalFlag == otherFlag).to(beTrue())
                        }
                    }
                }
                context("when event tracking contexts differ") {
                    it("returns true") {
                        let eventTrackingContext = EventTrackingContext(trackEvents: false)
                        originalFlags.forEach { (_, originalFlag) in
                            otherFlag = FeatureFlag(copying: originalFlag, eventTrackingContext: eventTrackingContext)

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
                    originalFlags.forEach { (flagKey, originalFlag) in
                        otherFlag = FeatureFlag(flagKey: flagKey, value: originalFlag.value, variation: nil, version: nil, flagVersion: nil, eventTrackingContext: nil)

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
                            otherFlag = FeatureFlag(copying: originalFlag)

                            expect(originalFlag.matchesVariation(otherFlag)).to(beTrue())
                        }
                    }
                }
                context("and variations do not match") {
                    it("returns false") {
                        featureFlags.forEach { (_, originalFlag) in
                            otherFlag = FeatureFlag(copying: originalFlag, variation: originalFlag.variation! + 1)

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
                    featureFlags.forEach { (flagKey, originalFlag) in
                        otherFlag = FeatureFlag(flagKey: flagKey,
                                                value: originalFlag.value,
                                                variation: nil,
                                                version: originalFlag.version,
                                                flagVersion: originalFlag.flagVersion,
                                                eventTrackingContext: originalFlag.eventTrackingContext)

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

                        featureFlagDictionaries = featureFlags.dictionaryValue
                    }
                    it("creates a matching dictionary that includes nil representations") {
                        featureFlags.forEach { (flagKey, featureFlag) in
                            featureFlagDictionary = featureFlagDictionaries[flagKey] as? [String: Any]

                            expect(featureFlagDictionary).toNot(beNil())
                            expect(featureFlagDictionary?.flagKey) == featureFlag.flagKey
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

                        featureFlagDictionaries = featureFlags.dictionaryValue
                    }
                    it("creates a matching dictionary that includes nil representations") {
                        featureFlags.forEach { (flagKey, featureFlag) in
                            featureFlagDictionary = featureFlagDictionaries[flagKey] as? [String: Any]

                            expect(featureFlagDictionary).toNot(beNil())
                            expect(featureFlagDictionary?.flagKey) == featureFlag.flagKey
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

                        featureFlagDictionaries = featureFlags.dictionaryValue.withNullValuesRemoved
                    }
                    it("creates a matching dictionary that excludes nil value representations") {
                        featureFlags.forEach { (flagKey, featureFlag) in
                            featureFlagDictionary = featureFlagDictionaries[flagKey] as? [String: Any]

                            expect(featureFlagDictionary?.flagKey) == featureFlag.flagKey
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
                        featureFlagDictionaries = featureFlags.dictionaryValue.withNullValuesRemoved
                    }
                    it("creates a matching dictionary that includes nil representations") {
                        featureFlags.forEach { (flagKey, featureFlag) in
                            featureFlagDictionary = featureFlagDictionaries[flagKey] as? [String: Any]

                            expect(featureFlagDictionary?.flagKey) == featureFlag.flagKey
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
                    flagDictionaries = DarklyServiceMock.Constants.stubFeatureFlags().dictionaryValue

                    featureFlags = flagDictionaries.flagCollection
                }
                it("creates matching FeatureFlags with flag elements") {
                    flagDictionaries.forEach { (flagKey, object) in
                        flagDictionary = object as? [String: Any]
                        featureFlag = featureFlags?[flagKey]

                        expect(featureFlag?.flagKey) == flagDictionary?.flagKey
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
                        .dictionaryValue.withNullValuesRemoved

                    featureFlags = flagDictionaries.flagCollection
                }
                it("creates matching FeatureFlags without missing elements") {
                    flagDictionaries.forEach { (flagKey, object) in
                        flagDictionary = object as? [String: Any]
                        featureFlag = featureFlags?[flagKey]

                        expect(featureFlag?.flagKey) == flagDictionary?.flagKey
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
            context("dictionary does not convert into FeatureFlags") {
                beforeEach {
                    flagDictionaries = Dictionary(flagKey: nil, value: true, variation: 1, version: 2, flagVersion: 3, trackEvents: nil)

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
    init(flagKey: String?, value: Any?, variation: Int?, version: Int?, flagVersion: Int?, trackEvents: Bool?, includeExtraDictionaryItems: Bool = false) {
        self.init()
        if let flagKey = flagKey {
            self[FeatureFlag.CodingKeys.flagKey.rawValue] = flagKey
        }
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
        if let trackEvents = trackEvents {
            self[EventTrackingContext.CodingKeys.trackEvents.rawValue] = trackEvents
        }
        if includeExtraDictionaryItems {
            self[FeatureFlagSpec.Constants.extraDictionaryKey] = FeatureFlagSpec.Constants.extraDictionaryValue
        }
    }
}

extension AnyComparer {
    static func isEqual(_ value: Any?, to other: Any?, considerNilAndNullEqual: Bool = false) -> Bool {
        if value == nil && other is NSNull {
            return considerNilAndNullEqual
        }
        if value is NSNull && other == nil {
            return considerNilAndNullEqual
        }
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

    init(copying featureFlag: FeatureFlag, value: Any? = nil, variation: Int? = nil, version: Int? = nil, flagVersion: Int? = nil, eventTrackingContext: EventTrackingContext? = nil) {
        self.init(flagKey: featureFlag.flagKey,
                  value: value ?? featureFlag.value,
                  variation: variation ?? featureFlag.variation,
                  version: version ?? featureFlag.version,
                  flagVersion: flagVersion ?? featureFlag.flagVersion,
                  eventTrackingContext: eventTrackingContext ?? featureFlag.eventTrackingContext)
    }
}
