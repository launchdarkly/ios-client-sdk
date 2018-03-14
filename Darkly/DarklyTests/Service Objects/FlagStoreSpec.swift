//
//  FlagStoreSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 10/26/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
@testable import Darkly

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
        let subject: FlagStore!
        let originalFeatureFlags: [LDFlagKey: FeatureFlag]!

        var updateDictionary: [String: Any]?
        var updateDictionaryKey: LDFlagKey? { return updateDictionary?[FlagStore.Keys.flagKey] as? LDFlagKey }
        var updateDictionaryValue: Any? { return updateDictionary?[FeatureFlag.CodingKeys.value.rawValue] }
        var updateDictionaryVersion: Int? { return updateDictionary?[FeatureFlag.CodingKeys.version.rawValue] as? Int }

        var deleteDictionary: [String: Any]?
        var deleteDictionaryKey: LDFlagKey? { return deleteDictionary?[FlagStore.Keys.flagKey] as? LDFlagKey }
        var deleteDictionaryVersion: Int? { return deleteDictionary?[FeatureFlag.CodingKeys.version.rawValue] as? Int }

        init() {
            subject = FlagStore(featureFlags: DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true), flagValueSource: .server)
            originalFeatureFlags = subject.featureFlags
        }
    }

    override func spec() {
        initSpec()
        replaceStoreSpec()
        updateStoreSpec()
        deleteFlagSpec()
        variationAndSourceSpec()
        variationSpec()
    }

    func initSpec() {
        var subject: FlagStore!
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
                    subject = FlagStore(featureFlags: DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true), flagValueSource: .cache)
                }
                it("has matching feature flags") {
                    expect(subject.featureFlags == DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true)).to(beTrue())
                    expect(subject.flagValueSource == .cache).to(beTrue())
                }
            }
            context("with an initial flag store without versions") {
                beforeEach {
                    subject = FlagStore(featureFlags: DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: false), flagValueSource: .cache)
                }
                it("has matching feature flags") {
                    expect(subject.featureFlags == DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: false)).to(beTrue())
                    expect(subject.flagValueSource == .cache).to(beTrue())
                }
            }
            context("with an initial flag dictionary") {
                beforeEach {
                    subject = FlagStore(featureFlagDictionary: DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true)
                        .dictionaryValue(exciseNil: false),
                                        flagValueSource: .cache)
                }
                it("has the feature flags") {
                    expect(subject.featureFlags == DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true)).to(beTrue())
                    expect(subject.flagValueSource == .cache).to(beTrue())
                }
            }
        }
    }

    func replaceStoreSpec() {
        var subject: FlagStore!
        describe("replaceStore") {
            context("with new flag values") {
                beforeEach {
                    subject = FlagStore()
                    waitUntil(timeout: 1) { done in
                        subject.replaceStore(newFlags: DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true), source: .cache, completion: done)
                    }
                }
                it("causes FlagStore to replace the flag values and source") {
                    expect(subject.featureFlags == DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true)).to(beTrue())
                    expect(subject.flagValueSource == .cache).to(beTrue())
                }
            }
            context("with new flag value dictionary") {
                beforeEach {
                    subject = FlagStore()
                    waitUntil(timeout: 1) { done in
                        subject.replaceStore(newFlags: DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true).dictionaryValue(exciseNil: false), source: .cache, completion: done)
                    }
                }
                it("causes FlagStore to replace the flag values and source") {
                    expect(subject.featureFlags == DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true)).to(beTrue())
                    expect(subject.flagValueSource == .cache).to(beTrue())
                }
            }
            context("with nil flag values") {
                beforeEach {
                    subject = FlagStore(featureFlags: DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true), flagValueSource: .cache)

                    waitUntil(timeout: 1) { done in
                        subject.replaceStore(newFlags: nil, source: .server, completion: done)
                    }
                }
                it("causes FlagStore to empty the flag values and replace the source") {
                    expect(subject.featureFlags.isEmpty).to(beTrue())
                }
            }
        }
    }

    func updateStoreSpec() {
        var testContext: TestContext!
        describe("updateStore") {
            beforeEach {
                testContext = TestContext()
            }
            context("when feature flag does not already exist") {
                beforeEach {
                    testContext.updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: FlagKeys.newInt,
                                                                                           value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                                           version: DarklyServiceMock.Constants.version)

                    waitUntil { done in
                        testContext.subject.updateStore(updateDictionary: testContext.updateDictionary!, source: .server, completion: done)
                    }
                }
                it("adds the new flag to the store") {
                    let featureFlag = testContext.subject.featureFlags[FlagKeys.newInt]
                    expect(AnyComparer.isEqual(featureFlag?.value, to: testContext.updateDictionaryValue)).to(beTrue())
                    expect(featureFlag?.version) == testContext.updateDictionaryVersion
                }
            }
            context("when the feature flag exists") {
                context("and the update version > existing version") {
                    beforeEach {
                        testContext.updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                      value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                                      version: DarklyServiceMock.Constants.version + 1)

                        waitUntil { done in
                            testContext.subject.updateStore(updateDictionary: testContext.updateDictionary!, source: .server, completion: done)
                        }
                    }
                    it("updates the feature flag to the update value") {
                        let featureFlag = testContext.subject.featureFlags[DarklyServiceMock.FlagKeys.int]
                        expect(AnyComparer.isEqual(featureFlag?.value, to: testContext.updateDictionaryValue)).to(beTrue())
                        expect(featureFlag?.version) == testContext.updateDictionaryVersion
                    }
                }
                context("and the new value is null") {
                    beforeEach {
                        testContext.updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int, value: NSNull(), version: DarklyServiceMock.Constants.version + 1)

                        waitUntil { done in
                            testContext.subject.updateStore(updateDictionary: testContext.updateDictionary!, source: .server, completion: done)
                        }
                    }
                    it("updates the feature flag to the update value") {
                        let featureFlag = testContext.subject.featureFlags[DarklyServiceMock.FlagKeys.int]
                        expect(featureFlag?.value).to(beNil())
                        expect(featureFlag?.version) == testContext.updateDictionaryVersion
                    }
                }
                context("and the update version == existing version") {
                    beforeEach {
                        testContext.updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                      value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                                      version: DarklyServiceMock.Constants.version)

                        waitUntil { done in
                            testContext.subject.updateStore(updateDictionary: testContext.updateDictionary!, source: .server, completion: done)
                        }
                    }
                    it("does not change the feature flag value") {
                        expect(testContext.subject.featureFlags) == testContext.originalFeatureFlags
                    }
                }
                context("and the update version < existing version") {
                    beforeEach {
                        testContext.updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                      value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                                      version: DarklyServiceMock.Constants.version - 1)

                        waitUntil { done in
                            testContext.subject.updateStore(updateDictionary: testContext.updateDictionary!, source: .server, completion: done)
                        }
                    }
                    it("does not change the feature flag value") {
                        expect(testContext.subject.featureFlags) == testContext.originalFeatureFlags
                    }
                }
            }
            context("when the update dictionary is missing the key") {
                beforeEach {
                    testContext.updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: nil,
                                                                                           value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                                           version: DarklyServiceMock.Constants.version + 1)

                    waitUntil { done in
                        testContext.subject.updateStore(updateDictionary: testContext.updateDictionary!, source: .server, completion: done)
                    }
                }
                it("makes no changes") {
                    expect(testContext.subject.featureFlags) == testContext.originalFeatureFlags
                }
            }
            context("when the update dictionary is missing the value") {
                beforeEach {
                    testContext.updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                           value: nil,
                                                                                           version: DarklyServiceMock.Constants.version + 1)

                    waitUntil { done in
                        testContext.subject.updateStore(updateDictionary: testContext.updateDictionary!, source: .server, completion: done)
                    }
                }
                it("makes no changes") {
                    expect(testContext.subject.featureFlags) == testContext.originalFeatureFlags
                }
            }
            context("when the update dictionary is missing the version") {
                beforeEach {
                    testContext.updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                           value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                                           version: nil)

                    waitUntil { done in
                        testContext.subject.updateStore(updateDictionary: testContext.updateDictionary!, source: .server, completion: done)
                    }
                }
                it("makes no changes") {
                    expect(testContext.subject.featureFlags) == testContext.originalFeatureFlags
                }
            }
        }
    }

    func deleteFlagSpec() {
        var testContext: TestContext!
        describe("deleteFlag") {
            beforeEach {
                testContext = TestContext()
            }
            context("when the flag exists") {
                context("and the new version > existing version") {
                    beforeEach {
                        testContext.deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version + 1)

                        waitUntil { done in
                            testContext.subject.deleteFlag(deleteDictionary: testContext.deleteDictionary!, completion: done)
                        }
                    }
                    it("removes the feature flag from the store") {
                        expect(testContext.subject.featureFlags[DarklyServiceMock.FlagKeys.int]).to(beNil())
                    }
                }
                context("and the new version == existing version") {
                    beforeEach {
                        testContext.deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version)

                        waitUntil { done in
                            testContext.subject.deleteFlag(deleteDictionary: testContext.deleteDictionary!, completion: done)
                        }
                    }
                    it("makes no changes to the flag store") {
                        expect(testContext.subject.featureFlags) == testContext.originalFeatureFlags
                    }
                }
                context("and the new version < existing version") {
                    beforeEach {
                        testContext.deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version - 1)

                        waitUntil { done in
                            testContext.subject.deleteFlag(deleteDictionary: testContext.deleteDictionary!, completion: done)
                        }
                    }
                    it("makes no changes to the flag store") {
                        expect(testContext.subject.featureFlags) == testContext.originalFeatureFlags
                    }
                }
            }
            context("when the flag doesn't exist") {
                beforeEach {
                    testContext.deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: FlagKeys.newInt, version: DarklyServiceMock.Constants.version + 1)

                    waitUntil { done in
                        testContext.subject.deleteFlag(deleteDictionary: testContext.deleteDictionary!, completion: done)
                    }
                }
                it("makes no changes to the flag store") {
                    expect(testContext.subject.featureFlags) == testContext.originalFeatureFlags
                }
            }
            context("when delete dictionary is missing the key") {
                beforeEach {
                    testContext.deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: nil, version: DarklyServiceMock.Constants.version + 1)

                    waitUntil { done in
                        testContext.subject.deleteFlag(deleteDictionary: testContext.deleteDictionary!, completion: done)
                    }
                }
                it("makes no changes to the flag store") {
                    expect(testContext.subject.featureFlags) == testContext.originalFeatureFlags
                }
            }
            context("when delete dictionary is missing the version") {
                beforeEach {
                    testContext.deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: nil)

                    waitUntil { done in
                        testContext.subject.deleteFlag(deleteDictionary: testContext.deleteDictionary!, completion: done)
                    }
                }
                it("makes no changes to the flag store") {
                    expect(testContext.subject.featureFlags) == testContext.originalFeatureFlags
                }
            }
        }
    }

    func variationAndSourceSpec() {
        var subject: FlagStore!
        describe("variationAndSource") {
            context("when flags exist") {
                beforeEach {
                    subject = FlagStore(featureFlags: DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true), flagValueSource: .server)
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
                    subject = FlagStore(featureFlags: DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true), flagValueSource: .cache)
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
