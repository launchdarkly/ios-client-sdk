//
//  LDFlagStoreSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 10/26/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
@testable import Darkly

final class LDFlagStoreSpec: QuickSpec {

    struct FallbackValues {
        static let bool = false
        static let int = 3
        static let double = 2.71828
        static let string = "fallback string"
        static let array = [0]
        static let dictionary: [String: Any] = [DarklyServiceMock.FlagKeys.string: DarklyServiceMock.FlagValues.string]
    }

    override func spec() {
        initSpec()
        replaceStoreSpec()
        variationAndSourceSpec()
        variationSpec()
    }

    func initSpec() {
        var subject: LDFlagStore!
        describe("init") {
            context("without an initial flag store") {
                beforeEach {
                    subject = LDFlagStore()
                }
                it("has no feature flags") {
                    expect(subject.featureFlags.isEmpty).to(beTrue())
                    expect(subject.flagValueSource == .fallback).to(beTrue())
                }
            }
            context("with an initial flag store") {
                beforeEach {
                    subject = LDFlagStore(featureFlags: DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true), flagValueSource: .cache)
                }
                it("has matching feature flags") {
                    expect(subject.featureFlags == DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true)).to(beTrue())
                    expect(subject.flagValueSource == .cache).to(beTrue())
                }
            }
            context("with an initial flag store without versions") {
                beforeEach {
                    subject = LDFlagStore(featureFlags: DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: false), flagValueSource: .cache)
                }
                it("has matching feature flags") {
                    expect(subject.featureFlags == DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: false)).to(beTrue())
                    expect(subject.flagValueSource == .cache).to(beTrue())
                }
            }
            context("with an initial flag dictionary") {
                beforeEach {
                    subject = LDFlagStore(featureFlagDictionary: DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true).dictionaryValue(exciseNil: false), flagValueSource: .cache)
                }
                it("has the feature flags") {
                    expect(subject.featureFlags == DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true)).to(beTrue())
                    expect(subject.flagValueSource == .cache).to(beTrue())
                }
            }
        }
    }

    func replaceStoreSpec() {
        var subject: LDFlagStore!
        describe("replaceStore") {
            context("with new flag values") {
                beforeEach {
                    subject = LDFlagStore()
                    waitUntil(timeout: 1) { done in
                        subject.replaceStore(newFlags: DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true), source: .cache) {
                            done()
                        }
                    }
                }
                it("causes LDFlagStore to replace the flag values and source") {
                    expect(subject.featureFlags == DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true)).to(beTrue())
                    expect(subject.flagValueSource == .cache).to(beTrue())
                }
            }
            context("with new flag value dictionary") {
                beforeEach {
                    subject = LDFlagStore()
                    waitUntil(timeout: 1) { done in
                        subject.replaceStore(newFlags: DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true).dictionaryValue(exciseNil: false), source: .cache) {
                            done()
                        }
                    }
                }
                it("causes LDFlagStore to replace the flag values and source") {
                    expect(subject.featureFlags == DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true)).to(beTrue())
                    expect(subject.flagValueSource == .cache).to(beTrue())
                }
            }
            context("with nil flag values") {
                beforeEach {
                    subject = LDFlagStore(featureFlags: DarklyServiceMock.Constants.featureFlags(includeNullValue: false, includeVersions: true), flagValueSource: .cache)

                    waitUntil(timeout: 1) { done in
                        subject.replaceStore(newFlags: nil, source: .server) {
                            done()
                        }
                    }
                }
                it("causes LDFlagStore to empty the flag values and replace the source") {
                    expect(subject.featureFlags.isEmpty).to(beTrue())
                }
            }
        }
    }

    func variationAndSourceSpec() {
        var subject: LDFlagStore!
        describe("variationAndSource") {
            context("when flags exist") {
                beforeEach {
                    subject = LDFlagStore(featureFlags: DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true), flagValueSource: .server)
                }
                it("causes the LDFlagStore to provide the flag value and source") {
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.bool, fallback: FallbackValues.bool) == (DarklyServiceMock.FlagValues.bool, LDFlagValueSource.server)).to(beTrue())
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.int, fallback: FallbackValues.int) == (DarklyServiceMock.FlagValues.int, LDFlagValueSource.server)).to(beTrue())
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.double, fallback: FallbackValues.double) == (DarklyServiceMock.FlagValues.double, LDFlagValueSource.server)).to(beTrue())
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.string, fallback: FallbackValues.string) == (DarklyServiceMock.FlagValues.string, LDFlagValueSource.server)).to(beTrue())

                    let (arrayValue, arrayFlagSource) = subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.array, fallback: FallbackValues.array)
                    expect(arrayValue == DarklyServiceMock.FlagValues.array).to(beTrue())
                    expect(arrayFlagSource == LDFlagValueSource.server).to(beTrue())

                    let (dictionaryValue, dictionaryFlagSource) = subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: FallbackValues.dictionary)
                    expect(dictionaryValue == DarklyServiceMock.FlagValues.dictionary).to(beTrue())
                    expect(dictionaryFlagSource == LDFlagValueSource.server).to(beTrue())

                    let (nullValue, nullFlagSource) = subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.null, fallback: FallbackValues.int)
                    expect(nullValue == FallbackValues.int).to(beTrue())
                    expect(nullFlagSource == LDFlagValueSource.fallback).to(beTrue())
                }
            }
            context("when flags do not exist") {
                beforeEach {
                    subject = LDFlagStore()
                }
                it("causes the LDFlagStore to provide the fallback flag value and source") {
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.bool, fallback: FallbackValues.bool) == (FallbackValues.bool, LDFlagValueSource.fallback)).to(beTrue())
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.int, fallback: FallbackValues.int) == (FallbackValues.int, LDFlagValueSource.fallback)).to(beTrue())
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.double, fallback: FallbackValues.double) == (FallbackValues.double, LDFlagValueSource.fallback)).to(beTrue())
                    expect(subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.string, fallback: FallbackValues.string) == (FallbackValues.string, LDFlagValueSource.fallback)).to(beTrue())

                    let (arrayValue, arrayFlagSource) = subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.array, fallback: FallbackValues.array)
                    expect(arrayValue == FallbackValues.array).to(beTrue())
                    expect(arrayFlagSource == LDFlagValueSource.fallback).to(beTrue())

                    let (dictionaryValue, dictionaryFlagSource) = subject.variationAndSource(forKey: DarklyServiceMock.FlagKeys.dictionary, fallback: FallbackValues.dictionary)
                    expect(dictionaryValue == FallbackValues.dictionary).to(beTrue())
                    expect(dictionaryFlagSource == LDFlagValueSource.fallback).to(beTrue())
                }
            }
        }
    }

    func variationSpec() {
        var subject: LDFlagStore!
        describe("variation") {
            context("when flags exist") {
                beforeEach {
                    subject = LDFlagStore(featureFlags: DarklyServiceMock.Constants.featureFlags(includeNullValue: true, includeVersions: true), flagValueSource: .cache)
                }
                it("causes the LDFlagStore to provide the flag value") {
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
                    subject = LDFlagStore()
                }
                it("causes the LDFlagStore to provide the fallback flag value") {
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
