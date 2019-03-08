//
//  FlagStoreSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 10/26/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
@testable import LaunchDarkly

final class FlagStoreSpec: QuickSpec {

    struct FlagKeys {
        static let newInt = "new-int-flag"
    }

    struct FallbackValues {
        static let bool = false
        static let int = 3
        static let double = 2.71828
        static let string = "fallback string"
        static let array = [0]
        static let dictionary: [String: Any] = [DarklyServiceMock.FlagKeys.string: DarklyServiceMock.FlagValues.string]
    }

    struct TestContext {
        let flagStore: FlagStore!
        let featureFlags: [LDFlagKey: FeatureFlag]!

        init() {
            featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
            flagStore = FlagStore(featureFlags: featureFlags, flagValueSource: .server)
        }
    }

    override func spec() {
        initSpec()
        replaceStoreSpec()
        updateStoreSpec()
        deleteFlagSpec()
        featureFlagSpec()
        featureFlagAndSourceSpec()
        variationAndSourceSpec()
        variationSpec()
    }

    func initSpec() {
        var subject: FlagStore!
        var featureFlags: [LDFlagKey: FeatureFlag]!
        describe("init") {
            context("without an initial flag store") {
                beforeEach {
                    subject = FlagStore()
                }
                it("has no feature flags") {
                    expect(subject.featureFlags.isEmpty).to(beTrue())
                    expect(subject.flagValueSource == .fallback).to(beTrue())
                }
            }
            context("with an initial flag store") {
                beforeEach {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                    subject = FlagStore(featureFlags: featureFlags, flagValueSource: .cache)
                }
                it("has matching feature flags") {
                    expect(subject.featureFlags == featureFlags).to(beTrue())
                    expect(subject.flagValueSource == .cache).to(beTrue())
                }
            }
            context("with an initial flag store without elements") {
                beforeEach {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeVariations: false, includeVersions: false, includeFlagVersions: false)
                    subject = FlagStore(featureFlags: featureFlags, flagValueSource: .cache)
                }
                it("has matching feature flags") {
                    expect(subject.featureFlags == featureFlags).to(beTrue())
                    expect(subject.flagValueSource == .cache).to(beTrue())
                }
            }
            context("with an initial flag dictionary") {
                beforeEach {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                    subject = FlagStore(featureFlagDictionary: featureFlags.dictionaryValue, flagValueSource: .cache)
                }
                it("has the feature flags") {
                    expect(subject.featureFlags == featureFlags).to(beTrue())
                    expect(subject.flagValueSource == .cache).to(beTrue())
                }
            }
        }
    }

    func replaceStoreSpec() {
        var featureFlags: [LDFlagKey: FeatureFlag]!
        var flagStore: FlagStore!
        describe("replaceStore") {
            context("with new flag values") {
                beforeEach {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false)
                    flagStore = FlagStore()
                    waitUntil(timeout: 1) { done in
                        flagStore.replaceStore(newFlags: featureFlags, source: .cache, completion: done)
                    }
                }
                it("causes FlagStore to replace the flag values and source") {
                    expect(flagStore.featureFlags == featureFlags).to(beTrue())
                    expect(flagStore.flagValueSource == .cache).to(beTrue())
                }
            }
            context("with new flag value dictionary") {
                beforeEach {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false)
                    flagStore = FlagStore()
                    waitUntil(timeout: 1) { done in
                        flagStore.replaceStore(newFlags: featureFlags.dictionaryValue, source: .cache, completion: done)
                    }
                }
                it("causes FlagStore to replace the flag values and source") {
                    expect(flagStore.featureFlags == featureFlags).to(beTrue())
                    expect(flagStore.flagValueSource == .cache).to(beTrue())
                }
            }
            context("with nil flag values") {
                beforeEach {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false)
                    flagStore = FlagStore(featureFlags: featureFlags, flagValueSource: .cache)

                    waitUntil(timeout: 1) { done in
                        flagStore.replaceStore(newFlags: nil, source: .server, completion: done)
                    }
                }
                it("causes FlagStore to empty the flag values and replace the source") {
                    expect(flagStore.featureFlags.isEmpty).to(beTrue())
                }
            }
        }
    }

    func updateStoreSpec() {
        var testContext: TestContext!
        var updateDictionary: [String: Any]!
        describe("updateStore") {
            beforeEach {
                testContext = TestContext()
            }
            context("when feature flag does not already exist") {
                beforeEach {
                    updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: FlagKeys.newInt,
                                                                               value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                               variation: DarklyServiceMock.Constants.variation,
                                                                               version: DarklyServiceMock.Constants.version)

                    waitUntil { done in
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, source: .server, completion: done)
                    }
                }
                it("adds the new flag to the store") {
                    let featureFlag = testContext.flagStore.featureFlags[FlagKeys.newInt]
                    expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary?.value)).to(beTrue())
                    expect(featureFlag?.variation) == updateDictionary?.variation
                    expect(featureFlag?.version) == updateDictionary?.version
                }
            }
            context("when the feature flag exists") {
                context("and the update version > existing version") {
                    beforeEach {
                        updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                   value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                                   variation: DarklyServiceMock.Constants.variation + 1,
                                                                                   version: DarklyServiceMock.Constants.version + 1)

                        waitUntil { done in
                            testContext.flagStore.updateStore(updateDictionary: updateDictionary, source: .server, completion: done)
                        }
                    }
                    it("updates the feature flag to the update value") {
                        let featureFlag = testContext.flagStore.featureFlags[DarklyServiceMock.FlagKeys.int]
                        expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary?.value)).to(beTrue())
                        expect(featureFlag?.variation) == updateDictionary?.variation
                        expect(featureFlag?.version) == updateDictionary?.version
                    }
                }
                context("and the new value is null") {
                    beforeEach {
                        updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                   value: NSNull(),
                                                                                   variation: DarklyServiceMock.Constants.variation + 1,
                                                                                   version: DarklyServiceMock.Constants.version + 1)

                        waitUntil { done in
                            testContext.flagStore.updateStore(updateDictionary: updateDictionary, source: .server, completion: done)
                        }
                    }
                    it("updates the feature flag to the update value") {
                        let featureFlag = testContext.flagStore.featureFlags[DarklyServiceMock.FlagKeys.int]
                        expect(featureFlag?.value).to(beNil())
                        expect(featureFlag?.variation) == updateDictionary.variation
                        expect(featureFlag?.version) == updateDictionary.version
                    }
                }
                context("and the update version == existing version") {
                    beforeEach {
                        updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                   value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                                   variation: DarklyServiceMock.Constants.variation,
                                                                                   version: DarklyServiceMock.Constants.version)

                        waitUntil { done in
                            testContext.flagStore.updateStore(updateDictionary: updateDictionary, source: .server, completion: done)
                        }
                    }
                    it("does not change the feature flag value") {
                        expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                    }
                }
                context("and the update version < existing version") {
                    beforeEach {
                        updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                   value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                                   variation: DarklyServiceMock.Constants.variation - 1,
                                                                                   version: DarklyServiceMock.Constants.version - 1)

                        waitUntil { done in
                            testContext.flagStore.updateStore(updateDictionary: updateDictionary, source: .server, completion: done)
                        }
                    }
                    it("does not change the feature flag value") {
                        expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                    }
                }
            }
            context("when the update dictionary is missing the flagKey") {
                beforeEach {
                    updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: nil,
                                                                               value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                               variation: DarklyServiceMock.Constants.variation + 1,
                                                                               version: DarklyServiceMock.Constants.version + 1)

                    waitUntil { done in
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, source: .server, completion: done)
                    }
                }
                it("makes no changes") {
                    expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                }
            }
            context("when the update dictionary is missing the value") {
                beforeEach {
                    updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                               value: nil,
                                                                               variation: DarklyServiceMock.Constants.variation + 1,
                                                                               version: DarklyServiceMock.Constants.version + 1)

                    waitUntil { done in
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, source: .server, completion: done)
                    }
                }
                it("updates the feature flag to the update value") {
                    let featureFlag = testContext.flagStore.featureFlags[DarklyServiceMock.FlagKeys.int]
                    expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary.value)).to(beTrue())
                    expect(featureFlag?.variation) == updateDictionary.variation
                    expect(featureFlag?.version) == updateDictionary.version
                }
            }
            context("when the update dictionary is missing the variation") {
                beforeEach {
                    updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                               value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                               variation: nil,
                                                                               version: DarklyServiceMock.Constants.version + 1)

                    waitUntil { done in
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, source: .server, completion: done)
                    }
                }
                it("updates the feature flag to the update value") {
                    let featureFlag = testContext.flagStore.featureFlags[DarklyServiceMock.FlagKeys.int]
                    expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary.value)).to(beTrue())
                    expect(featureFlag?.variation).to(beNil())
                    expect(featureFlag?.version) == updateDictionary.version
                }
            }
            context("when the update dictionary is missing the version") {
                beforeEach {
                    updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                               value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                               variation: DarklyServiceMock.Constants.variation + 1,
                                                                               version: nil)

                    waitUntil { done in
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, source: .server, completion: done)
                    }
                }
                it("updates the feature flag to the update value") {
                    let featureFlag = testContext.flagStore.featureFlags[DarklyServiceMock.FlagKeys.int]
                    expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary.value)).to(beTrue())
                    expect(featureFlag?.variation) == updateDictionary.variation
                    expect(featureFlag?.version).to(beNil())
                }
            }
            context("when the update dictionary has more keys than needed") {
                beforeEach {
                    updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                               value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                               variation: DarklyServiceMock.Constants.variation + 1,
                                                                               version: DarklyServiceMock.Constants.version + 1,
                                                                               includeExtraKey: true)

                    waitUntil { done in
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, source: .server, completion: done)
                    }
                }
                it("updates the feature flag to the update value") {
                    let featureFlag = testContext.flagStore.featureFlags[DarklyServiceMock.FlagKeys.int]
                    expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary.value)).to(beTrue())
                    expect(featureFlag?.variation) == updateDictionary.variation
                    expect(featureFlag?.version) == updateDictionary.version
                }
            }
        }
    }

    func deleteFlagSpec() {
        var testContext: TestContext!
        var deleteDictionary: [String: Any]!
        describe("deleteFlag") {
            beforeEach {
                testContext = TestContext()
            }
            context("when the flag exists") {
                context("and the new version > existing version") {
                    beforeEach {
                        deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version + 1)

                        waitUntil { done in
                            testContext.flagStore.deleteFlag(deleteDictionary: deleteDictionary, completion: done)
                        }
                    }
                    it("removes the feature flag from the store") {
                        expect(testContext.flagStore.featureFlags[DarklyServiceMock.FlagKeys.int]).to(beNil())
                    }
                }
                context("and the new version == existing version") {
                    beforeEach {
                        deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version)

                        waitUntil { done in
                            testContext.flagStore.deleteFlag(deleteDictionary: deleteDictionary, completion: done)
                        }
                    }
                    it("makes no changes to the flag store") {
                        expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                    }
                }
                context("and the new version < existing version") {
                    beforeEach {
                        deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version - 1)

                        waitUntil { done in
                            testContext.flagStore.deleteFlag(deleteDictionary: deleteDictionary, completion: done)
                        }
                    }
                    it("makes no changes to the flag store") {
                        expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                    }
                }
            }
            context("when the flag doesn't exist") {
                beforeEach {
                    deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: FlagKeys.newInt, version: DarklyServiceMock.Constants.version + 1)

                    waitUntil { done in
                        testContext.flagStore.deleteFlag(deleteDictionary: deleteDictionary, completion: done)
                    }
                }
                it("makes no changes to the flag store") {
                    expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                }
            }
            context("when delete dictionary is missing the key") {
                beforeEach {
                    deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: nil, version: DarklyServiceMock.Constants.version + 1)

                    waitUntil { done in
                        testContext.flagStore.deleteFlag(deleteDictionary: deleteDictionary, completion: done)
                    }
                }
                it("makes no changes to the flag store") {
                    expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                }
            }
            context("when delete dictionary is missing the version") {
                beforeEach {
                    deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: nil)

                    waitUntil { done in
                        testContext.flagStore.deleteFlag(deleteDictionary: deleteDictionary, completion: done)
                    }
                }
                it("makes no changes to the flag store") {
                    expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                }
            }
        }
    }

    func featureFlagSpec() {
        var flagStore: FlagStore!
        describe("featureFlag") {
            beforeEach {
                flagStore = FlagStore(featureFlags: DarklyServiceMock.Constants.stubFeatureFlags(), flagValueSource: .server)
            }
            context("when flag key exists") {
                it("returns the feature flag") {
                    flagStore.featureFlags.forEach { (flagKey, featureFlag) in
                        expect(flagStore.featureFlag(for: flagKey)?.allPropertiesMatch(featureFlag)).to(beTrue())
                    }
                }
            }
            context("when flag key doesn't exist") {
                var featureFlag: FeatureFlag?
                beforeEach {
                    featureFlag = flagStore.featureFlag(for: DarklyServiceMock.FlagKeys.unknown)
                }
                it("returns nil") {
                    expect(featureFlag).to(beNil())
                }
            }
        }
    }

    func featureFlagAndSourceSpec() {
        describe("featureFlagAndSource") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
            }
            context("when flag key exists") {
                it("returns the feature flag and source") {
                    testContext.featureFlags.forEach { (flagKey, featureFlag) in
                        let (flagStoreFeatureFlag, flagStoreSource) = testContext.flagStore.featureFlagAndSource(for: flagKey)

                        expect(flagStoreFeatureFlag) == featureFlag
                        expect(flagStoreSource) == .server
                    }
                }
            }
            context("when flag key does not exist") {
                var flagStoreFeatureFlag: FeatureFlag?
                var flagStoreSource: LDFlagValueSource?
                beforeEach {
                    (flagStoreFeatureFlag, flagStoreSource) = testContext.flagStore.featureFlagAndSource(for: DarklyServiceMock.FlagKeys.unknown)
                }
                it("returns nil for the feature flag and source") {
                    expect(flagStoreFeatureFlag).to(beNil())
                    expect(flagStoreSource).to(beNil())
                }
            }
        }
    }

    func variationAndSourceSpec() {
        var subject: FlagStore!
        describe("variationAndSource") {
            context("when flags exist") {
                beforeEach {
                    subject = FlagStore(featureFlags: DarklyServiceMock.Constants.stubFeatureFlags(), flagValueSource: .server)
                }
                it("causes the FlagStore to provide the flag value and source") {
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.bool,
                                                      fallback: FallbackValues.bool) == (DarklyServiceMock.FlagValues.bool, LDFlagValueSource.server)).to(beTrue())
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.int,
                                                      fallback: FallbackValues.int) == (DarklyServiceMock.FlagValues.int, LDFlagValueSource.server)).to(beTrue())
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.double,
                                                      fallback: FallbackValues.double) == (DarklyServiceMock.FlagValues.double, LDFlagValueSource.server)).to(beTrue())
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.string,
                                                      fallback: FallbackValues.string) == (DarklyServiceMock.FlagValues.string, LDFlagValueSource.server)).to(beTrue())

                    let (arrayValue, arrayFlagSource) = subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.array,
                                                                                   fallback: FallbackValues.array)
                    expect(arrayValue == DarklyServiceMock.FlagValues.array).to(beTrue())
                    expect(arrayFlagSource == LDFlagValueSource.server).to(beTrue())

                    let (dictionaryValue, dictionaryFlagSource) = subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.dictionary,
                                                                                             fallback: FallbackValues.dictionary)
                    expect(dictionaryValue == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                    expect(dictionaryFlagSource == LDFlagValueSource.server).to(beTrue())

                    let (nullValue, nullFlagSource) = subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.null,
                                                                                 fallback: FallbackValues.int)
                    expect(nullValue == FallbackValues.int).to(beTrue())
                    expect(nullFlagSource == LDFlagValueSource.fallback).to(beTrue())
                }
            }
            context("when flags do not exist") {
                beforeEach {
                    subject = FlagStore()
                }
                it("causes the FlagStore to provide the fallback flag value and source") {
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.bool,
                                                      fallback: FallbackValues.bool) == (FallbackValues.bool, LDFlagValueSource.fallback)).to(beTrue())
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.int,
                                                      fallback: FallbackValues.int) == (FallbackValues.int, LDFlagValueSource.fallback)).to(beTrue())
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.double,
                                                      fallback: FallbackValues.double) == (FallbackValues.double, LDFlagValueSource.fallback)).to(beTrue())
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.string,
                                                      fallback: FallbackValues.string) == (FallbackValues.string, LDFlagValueSource.fallback)).to(beTrue())

                    let (arrayValue, arrayFlagSource) = subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.array,
                                                                                   fallback: FallbackValues.array)
                    expect(arrayValue == FallbackValues.array).to(beTrue())
                    expect(arrayFlagSource == LDFlagValueSource.fallback).to(beTrue())

                    let (dictionaryValue, dictionaryFlagSource) = subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.dictionary,
                                                                                             fallback: FallbackValues.dictionary)
                    expect(dictionaryValue == FallbackValues.dictionary).to(beTrue())
                    expect(dictionaryFlagSource == LDFlagValueSource.fallback).to(beTrue())
                }
            }
        }
    }

    func variationSpec() {
        var subject: FlagStore!
        describe("variation") {
            context("when flags exist") {
                beforeEach {
                    subject = FlagStore(featureFlags: DarklyServiceMock.Constants.stubFeatureFlags(), flagValueSource: .cache)
                }
                it("causes the FlagStore to provide the flag value") {
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, fallback: FallbackValues.bool) == DarklyServiceMock.FlagValues.bool).to(beTrue())
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.int, fallback: FallbackValues.int) == DarklyServiceMock.FlagValues.int).to(beTrue())
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.double, fallback: FallbackValues.double) == DarklyServiceMock.FlagValues.double).to(beTrue())
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.string, fallback: FallbackValues.string) == DarklyServiceMock.FlagValues.string).to(beTrue())

                    let arrayValue = subject.variation(forKey: DarklyServiceMock.FlagKeys.array, fallback: FallbackValues.array)
                    expect(arrayValue == DarklyServiceMock.FlagValues.array).to(beTrue())

                    let dictionaryValue = subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: FallbackValues.dictionary)
                    expect(dictionaryValue == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                }
            }
            context("when flags do not exist") {
                beforeEach {
                    subject = FlagStore()
                }
                it("causes the FlagStore to provide the fallback flag value") {
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, fallback: FallbackValues.bool) == FallbackValues.bool).to(beTrue())
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.int, fallback: FallbackValues.int) == FallbackValues.int).to(beTrue())
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.double, fallback: FallbackValues.double) == FallbackValues.double).to(beTrue())
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.string, fallback: FallbackValues.string) == FallbackValues.string).to(beTrue())

                    let arrayValue = subject.variation(forKey: DarklyServiceMock.FlagKeys.array, fallback: FallbackValues.array)
                    expect(arrayValue == FallbackValues.array).to(beTrue())

                    let dictionaryValue = subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: FallbackValues.dictionary)
                    expect(dictionaryValue == FallbackValues.dictionary).to(beTrue())

                    let nullValue = subject.variation(forKey: DarklyServiceMock.FlagKeys.null, fallback: FallbackValues.int)
                    expect(nullValue == FallbackValues.int).to(beTrue())
                }
            }
        }
    }
}
