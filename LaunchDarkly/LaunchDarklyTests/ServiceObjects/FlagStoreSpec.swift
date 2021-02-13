//
//  FlagStoreSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class FlagStoreSpec: QuickSpec {

    struct FlagKeys {
        static let newInt = "new-int-flag"
    }

    struct DefaultValues {
        static let bool = false
        static let int = 3
        static let double = 2.71828
        static let string = "defaultValue string"
        static let array = [0]
        static let dictionary: [String: Any] = [DarklyServiceMock.FlagKeys.string: DarklyServiceMock.FlagValues.string]
    }

    struct TestContext {
        let flagStore: FlagStore!
        let featureFlags: [LDFlagKey: FeatureFlag]!

        init() {
            featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
            flagStore = FlagStore(featureFlags: featureFlags)
        }
    }

    override func spec() {
        initSpec()
        replaceStoreSpec()
        updateStoreSpec()
        deleteFlagSpec()
        featureFlagSpec()
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
                }
            }
            context("with an initial flag store") {
                beforeEach {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                    subject = FlagStore(featureFlags: featureFlags)
                }
                it("has matching feature flags") {
                    expect(subject.featureFlags == featureFlags).to(beTrue())
                }
            }
            context("with an initial flag store without elements") {
                beforeEach {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeVariations: false, includeVersions: false, includeFlagVersions: false)
                    subject = FlagStore(featureFlags: featureFlags)
                }
                it("has matching feature flags") {
                    expect(subject.featureFlags == featureFlags).to(beTrue())
                }
            }
            context("with an initial flag dictionary") {
                beforeEach {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                    subject = FlagStore(featureFlagDictionary: featureFlags.dictionaryValue)
                }
                it("has the feature flags") {
                    expect(subject.featureFlags == featureFlags).to(beTrue())
                }
            }
        }
    }

    func replaceStoreSpec() {
        let featureFlags: [LDFlagKey: FeatureFlag] = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false)
        var flagStore: FlagStore!
        describe("replaceStore") {
            context("with new flag values") {
                beforeEach {
                    flagStore = FlagStore()
                    waitUntil(timeout: .seconds(1)) { done in
                        flagStore.replaceStore(newFlags: featureFlags, completion: done)
                    }
                }
                it("causes FlagStore to replace the flag values") {
                    expect(flagStore.featureFlags) == featureFlags
                }
            }
            context("with new flag value dictionary") {
                beforeEach {
                    flagStore = FlagStore()
                    waitUntil(timeout: .seconds(1)) { done in
                        flagStore.replaceStore(newFlags: featureFlags.dictionaryValue, completion: done)
                    }
                }
                it("causes FlagStore to replace the flag values") {
                    expect(flagStore.featureFlags) == featureFlags
                }
            }
            context("with invalid dictionary") {
                beforeEach {
                    flagStore = FlagStore(featureFlags: featureFlags)

                    waitUntil(timeout: .seconds(1)) { done in
                        flagStore.replaceStore(newFlags: ["fakeKey": "Not a flag dict"], completion: done)
                    }
                }
                it("causes FlagStore to empty the flag values") {
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
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
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
                            testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
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
                            testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
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
                            testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
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
                            testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
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
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
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
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
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
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
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
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
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
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
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
                flagStore = FlagStore(featureFlags: DarklyServiceMock.Constants.stubFeatureFlags())
            }
            context("when flag key exists") {
                it("returns the feature flag") {
                    flagStore.featureFlags.forEach { flagKey, featureFlag in
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

    func variationSpec() {
        var subject: FlagStore!
        describe("variation") {
            context("when flags exist") {
                beforeEach {
                    subject = FlagStore(featureFlags: DarklyServiceMock.Constants.stubFeatureFlags())
                }
                it("causes the FlagStore to provide the flag value") {
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultValues.bool)) == DarklyServiceMock.FlagValues.bool
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.int, defaultValue: DefaultValues.int)) == DarklyServiceMock.FlagValues.int
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.double, defaultValue: DefaultValues.double)) == DarklyServiceMock.FlagValues.double
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.string, defaultValue: DefaultValues.string)) == DarklyServiceMock.FlagValues.string

                    let arrayValue = subject.variation(forKey: DarklyServiceMock.FlagKeys.array, defaultValue: DefaultValues.array)
                    expect(arrayValue) == DarklyServiceMock.FlagValues.array

                    let dictionaryValue = subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, defaultValue: DefaultValues.dictionary)
                    expect(dictionaryValue == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                }
            }
            context("when flags do not exist") {
                beforeEach {
                    subject = FlagStore()
                }
                it("causes the FlagStore to provide the defaultValue flag value") {
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.bool, defaultValue: DefaultValues.bool)) == DefaultValues.bool
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.int, defaultValue: DefaultValues.int)) == DefaultValues.int
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.double, defaultValue: DefaultValues.double)) == DefaultValues.double
                    expect(subject.variation(forKey: DarklyServiceMock.FlagKeys.string, defaultValue: DefaultValues.string)) == DefaultValues.string

                    let arrayValue = subject.variation(forKey: DarklyServiceMock.FlagKeys.array, defaultValue: DefaultValues.array)
                    expect(arrayValue) == DefaultValues.array

                    let dictionaryValue = subject.variation(forKey: DarklyServiceMock.FlagKeys.dictionary, defaultValue: DefaultValues.dictionary)
                    expect(dictionaryValue == DefaultValues.dictionary).to(beTrue())

                    let nullValue = subject.variation(forKey: DarklyServiceMock.FlagKeys.null, defaultValue: DefaultValues.int)
                    expect(nullValue) == DefaultValues.int
                }
            }
        }
    }
}
