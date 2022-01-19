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
    struct DefaultValues {
        static let bool = false
        static let int = 3
        static let double = 2.71828
        static let string = "defaultValue string"
        static let array = [0]
        static let dictionary: [String: Any] = [DarklyServiceMock.FlagKeys.string: DarklyServiceMock.FlagValues.string]
    }

    let stubFlags = DarklyServiceMock.Constants.stubFeatureFlags()

    override func spec() {
        initSpec()
        replaceStoreSpec()
        updateStoreSpec()
        deleteFlagSpec()
        featureFlagSpec()
    }

    func initSpec() {
        describe("init") {
            it("without an initial flag store is empty") {
                expect(FlagStore().featureFlags.isEmpty) == true
            }
            it("with an initial flag store") {
                expect(FlagStore(featureFlags: self.stubFlags).featureFlags) == self.stubFlags
            }
            it("with an initial flag store without elements") {
                let featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeVariations: false, includeVersions: false, includeFlagVersions: false)
                expect(FlagStore(featureFlags: featureFlags).featureFlags) == featureFlags
            }
            it("with an initial flag dictionary") {
                expect(FlagStore(featureFlagDictionary: self.stubFlags.dictionaryValue).featureFlags) == self.stubFlags
            }
        }
    }

    func replaceStoreSpec() {
        let featureFlags: [LDFlagKey: FeatureFlag] = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false)
        describe("replaceStore") {
            it("with new flag values replaces flag values") {
                let flagStore = FlagStore()
                waitUntil { done in
                    flagStore.replaceStore(newFlags: featureFlags, completion: done)
                }
                expect(flagStore.featureFlags) == featureFlags
            }
            it("with flags dictionary replaces flag values") {
                let flagStore = FlagStore()
                waitUntil { done in
                    flagStore.replaceStore(newFlags: featureFlags.dictionaryValue, completion: done)
                }
                expect(flagStore.featureFlags) == featureFlags
            }
            it("with invalid dictionary empties the flag values") {
                let flagStore = FlagStore(featureFlags: featureFlags)
                waitUntil { done in
                    flagStore.replaceStore(newFlags: ["fakeKey": "Not a flag dict"], completion: done)
                }
                expect(flagStore.featureFlags.isEmpty).to(beTrue())
            }
        }
    }

    func updateStoreSpec() {
        var subject: FlagStore!
        var updateDictionary: [String: Any]!

        func updateFlag(key: String? = DarklyServiceMock.FlagKeys.int,
                        value: Any? = DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                        variation: Int? = DarklyServiceMock.Constants.variation + 1,
                        version: Int? = DarklyServiceMock.Constants.version + 1,
                        includeExtraKey: Bool = false) {
            waitUntil { done in
                updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: key, value: value, variation: variation, version: version, includeExtraKey: includeExtraKey)
                subject.updateStore(updateDictionary: updateDictionary, completion: done)
            }
        }

        describe("updateStore") {
            beforeEach {
                subject = FlagStore(featureFlags: DarklyServiceMock.Constants.stubFeatureFlags())
            }
            context("makes no changes") {
                it("when the update version == existing version") {
                    updateFlag(variation: DarklyServiceMock.Constants.variation, version: DarklyServiceMock.Constants.version)
                    expect(subject.featureFlags) == self.stubFlags
                }
                it("when the update version < existing version") {
                    updateFlag(variation: DarklyServiceMock.Constants.variation - 1, version: DarklyServiceMock.Constants.version - 1)
                    expect(subject.featureFlags) == self.stubFlags
                }
                it("when the update dictionary is missing the flagKey") {
                    updateFlag(key: nil)
                    expect(subject.featureFlags) == self.stubFlags
                }
            }
            context("updates the feature flag") {
                it("when the update version > existing version") {
                    updateFlag()
                    let featureFlag = subject.featureFlags[DarklyServiceMock.FlagKeys.int]
                    expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary?.value)).to(beTrue())
                    expect(featureFlag?.variation) == updateDictionary?.variation
                    expect(featureFlag?.version) == updateDictionary?.version
                }
                it("when the new value is null") {
                    updateFlag(value: NSNull())
                    let featureFlag = subject.featureFlags[DarklyServiceMock.FlagKeys.int]
                    expect(featureFlag?.value).to(beNil())
                    expect(featureFlag?.variation) == updateDictionary.variation
                    expect(featureFlag?.version) == updateDictionary.version
                }
                it("when the update dictionary is missing the value") {
                    updateFlag(value: nil)
                    let featureFlag = subject.featureFlags[DarklyServiceMock.FlagKeys.int]
                    expect(featureFlag?.value).to(beNil())
                    expect(featureFlag?.variation) == updateDictionary.variation
                    expect(featureFlag?.version) == updateDictionary.version
                }
                it("when the update dictionary is missing the variation") {
                    updateFlag(variation: nil)
                    let featureFlag = subject.featureFlags[DarklyServiceMock.FlagKeys.int]
                    expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary.value)).to(beTrue())
                    expect(featureFlag?.variation).to(beNil())
                    expect(featureFlag?.version) == updateDictionary.version
                }
                it("when the update dictionary is missing the version") {
                    updateFlag(version: nil)
                    let featureFlag = subject.featureFlags[DarklyServiceMock.FlagKeys.int]
                    expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary.value)).to(beTrue())
                    expect(featureFlag?.variation) == updateDictionary.variation
                    expect(featureFlag?.version).to(beNil())
                }
                it("when the update dictionary has more keys than needed") {
                    updateFlag(includeExtraKey: true)
                    let featureFlag = subject.featureFlags[DarklyServiceMock.FlagKeys.int]
                    expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary.value)).to(beTrue())
                    expect(featureFlag?.variation) == updateDictionary.variation
                    expect(featureFlag?.version) == updateDictionary.version
                }
            }
            it("adds new feature flag to the store") {
                updateFlag(key: "new-int-flag")
                let featureFlag = subject.featureFlags["new-int-flag"]
                expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary?.value)).to(beTrue())
                expect(featureFlag?.variation) == updateDictionary?.variation
                expect(featureFlag?.version) == updateDictionary?.version
            }
        }
    }

    func deleteFlagSpec() {
        var subject: FlagStore!

        func deleteFlag(_ deleteDictionary: [String: Any]) {
            waitUntil { done in
                subject.deleteFlag(deleteDictionary: deleteDictionary, completion: done)
            }
        }

        describe("deleteFlag") {
            beforeEach {
                subject = FlagStore(featureFlags: DarklyServiceMock.Constants.stubFeatureFlags())
            }
            context("removes flag") {
                it("with exact dictionary") {
                    deleteFlag(FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version + 1))
                    expect(subject.featureFlags.count) == self.stubFlags.count - 1
                    expect(subject.featureFlags[DarklyServiceMock.FlagKeys.int]).to(beNil())
                }
                it("with extra fields on dictionary") {
                    var deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version + 1)
                    deleteDictionary["new-field"] = 10
                    deleteFlag(deleteDictionary)
                    expect(subject.featureFlags.count) == self.stubFlags.count - 1
                    expect(subject.featureFlags[DarklyServiceMock.FlagKeys.int]).to(beNil())
                }
            }
            context("makes no changes to the flag store") {
                it("when the version is the same") {
                    deleteFlag(FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version))
                    expect(subject.featureFlags) == self.stubFlags
                }
                it("when the new version < existing version") {
                    deleteFlag(FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version - 1))
                    expect(subject.featureFlags) == self.stubFlags
                }
                it("when the flag doesn't exist") {
                    deleteFlag(FlagMaintainingMock.stubDeleteDictionary(key: "new-int-flag", version: DarklyServiceMock.Constants.version + 1))
                    expect(subject.featureFlags) == self.stubFlags
                }
                it("when delete dictionary is missing the key") {
                    deleteFlag(FlagMaintainingMock.stubDeleteDictionary(key: nil, version: DarklyServiceMock.Constants.version + 1))
                    expect(subject.featureFlags) == self.stubFlags
                }
                it("when delete dictionary is missing the version") {
                    deleteFlag(FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: nil))
                    expect(subject.featureFlags) == self.stubFlags
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
            it("returns existing feature flag") {
                flagStore.featureFlags.forEach { flagKey, featureFlag in
                    expect(flagStore.featureFlag(for: flagKey)?.allPropertiesMatch(featureFlag)).to(beTrue())
                }
            }
            it("returns nil when flag doesn't exist") {
                let featureFlag = flagStore.featureFlag(for: DarklyServiceMock.FlagKeys.unknown)
                expect(featureFlag).to(beNil())
            }
        }
    }
}
