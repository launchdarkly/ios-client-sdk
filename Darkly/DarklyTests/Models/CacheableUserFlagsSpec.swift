//
//  CacheableUserFlagsSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 2/21/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import Darkly

final class CacheableUserFlagsSpec: QuickSpec {
    struct Constants {
        static let lastUpdatedString = "2018-02-21T18:10:40.823Z"
        static let lastUpdatedDate = lastUpdatedString.dateValue
    }

    override func spec() {
        initSpec()
        dictionaryValueSpec()
        equalsSpec()
    }

    private func initSpec() {
        var subject: CacheableUserFlags?

        describe("init with flags and date") {
            beforeEach {
                subject = CacheableUserFlags(flags: DarklyServiceMock.Constants.featureFlags, lastUpdated: Constants.lastUpdatedDate)
            }
            it("creates a matching CacheableUserFlags") {
                expect(AnyComparer.isEqual(subject?.flags, to: DarklyServiceMock.Constants.featureFlags)).to(beTrue())
                expect(subject?.lastUpdated) == Constants.lastUpdatedDate
            }
        }

        describe("init with user") {
            var user: LDUser!
            var flagStoreMock: LDFlagMaintainingMock! { return user.flagStore as! LDFlagMaintainingMock }
            var userFlags: [LDFlagKey: Any]? { return flagStoreMock.featureFlags }

            beforeEach {
                user = LDUser.stub()
                subject = CacheableUserFlags(user: user)
            }
            it("creates a matching CacheableUserFlags") {
                expect(AnyComparer.isEqual(subject?.flags, to: userFlags)).to(beTrue())
                expect(subject?.lastUpdated) == user.lastUpdated
            }
        }

        describe("init with dictionary") {
            var flagDictionary: [String: Any]!
            context("with flags and lastUpdated") {
                context("matching types") {
                    beforeEach {
                        flagDictionary = [CacheableUserFlags.CodingKeys.flags.rawValue: DarklyServiceMock.Constants.featureFlags.dictionaryValue(exciseNil: false), CacheableUserFlags.CodingKeys.lastUpdated.rawValue: Constants.lastUpdatedString]
                        subject = CacheableUserFlags(dictionary: flagDictionary)
                    }
                    it("creates a matching CacheableUserFlags") {
                        expect(subject).toNot(beNil())
                        expect(AnyComparer.isEqual(subject?.flags, to: DarklyServiceMock.Constants.featureFlags)).to(beTrue())
                        expect(subject?.lastUpdated) == Constants.lastUpdatedDate
                    }
                }
                context("flag type mismatch") {
                    beforeEach {
                        flagDictionary = [CacheableUserFlags.CodingKeys.flags.rawValue: Constants.lastUpdatedString, CacheableUserFlags.CodingKeys.lastUpdated.rawValue: Constants.lastUpdatedString]
                        subject = CacheableUserFlags(dictionary: flagDictionary)
                    }
                    it("returns nil") {
                        expect(subject).to(beNil())
                    }
                }
                context("date type mismatch") {
                    beforeEach {
                        flagDictionary = [CacheableUserFlags.CodingKeys.flags.rawValue: DarklyServiceMock.Constants.featureFlags, CacheableUserFlags.CodingKeys.lastUpdated.rawValue: Constants.lastUpdatedDate]
                        subject = CacheableUserFlags(dictionary: flagDictionary)
                    }
                    it("creates a matching CacheableUserFlags with the current date") {
                        expect(AnyComparer.isEqual(subject?.flags, to: DarklyServiceMock.Constants.featureFlags)).to(beTrue())
                        expect(subject?.lastUpdated.timeIntervalSinceNow) > -0.1   //The exact date won't be right, so this is close enough
                    }
                }
            }
            context("without flags") {
                beforeEach {
                    flagDictionary = [CacheableUserFlags.CodingKeys.lastUpdated.rawValue: Constants.lastUpdatedString]
                    subject = CacheableUserFlags(dictionary: flagDictionary)
                }
                it("returns nil") {
                    expect(subject).to(beNil())
                }
            }
            context("without lastUpdated") {
                beforeEach {
                    flagDictionary = [CacheableUserFlags.CodingKeys.flags.rawValue: DarklyServiceMock.Constants.featureFlags]
                    subject = CacheableUserFlags(dictionary: flagDictionary)
                }
                it("creates a matching CacheableUserFlags with the current date") {
                    expect(AnyComparer.isEqual(subject?.flags, to: DarklyServiceMock.Constants.featureFlags)).to(beTrue())
                    expect(subject?.lastUpdated.timeIntervalSinceNow) > -0.1   //The exact date won't be right, so this is close enough
                }
            }
        }

        describe("init with object") {
            var object: Any!

            context("object is a dictionary") {
                beforeEach {
                    object = [CacheableUserFlags.CodingKeys.flags.rawValue: DarklyServiceMock.Constants.featureFlags.dictionaryValue(exciseNil: false), CacheableUserFlags.CodingKeys.lastUpdated.rawValue: Constants.lastUpdatedString]
                    subject = CacheableUserFlags(object: object)
                }
                it("creates a matching CacheableUserFlags") {
                    expect(subject).toNot(beNil())
                    expect(AnyComparer.isEqual(subject?.flags, to: DarklyServiceMock.Constants.featureFlags)).to(beTrue())
                    expect(subject?.lastUpdated) == Constants.lastUpdatedDate
                }
            }
            context("object is not a dictionary") {
                beforeEach {
                    object = Constants.lastUpdatedString
                    subject = CacheableUserFlags(object: object)
                }
                it("returns nil") {
                    expect(subject).to(beNil())
                }
            }
        }
    }

    func dictionaryValueSpec() {
        var subject: CacheableUserFlags!
        var subjectDictionary: [String: Any]!
        var subjectDictionaryFlags: [LDFlagKey: FeatureFlag]? { return (subjectDictionary[CacheableUserFlags.CodingKeys.flags.rawValue] as? [String: Any])?.flagCollection }
        var subjectDictionaryLastUpdated: String? { return subjectDictionary[CacheableUserFlags.CodingKeys.lastUpdated.rawValue] as? String }
        describe("dictionaryValue") {
            context("flags do not contain null values") {
                beforeEach {
                    subject = CacheableUserFlags(flags: DarklyServiceMock.Constants.featureFlags, lastUpdated: Constants.lastUpdatedDate)
                    subjectDictionary = subject.dictionaryValue
                }
                it("creates a dictionary matching dictionary without null values") {
                    expect(subjectDictionaryFlags) == DarklyServiceMock.Constants.featureFlags
                    expect(subjectDictionaryLastUpdated) == Constants.lastUpdatedString
                }
            }
            context("flags contain null values") {
                beforeEach {
                    subject = CacheableUserFlags(flags: DarklyServiceMock.Constants.featureFlagsWithNull, lastUpdated: Constants.lastUpdatedDate)
                    subjectDictionary = subject.dictionaryValue
                }
                it("creates a dictionary matching dictionary without null values") {
                    expect(subjectDictionaryFlags) == DarklyServiceMock.Constants.featureFlags
                    expect(subjectDictionaryLastUpdated) == Constants.lastUpdatedString
                }
            }
        }
    }

    func equalsSpec() {
        var subject: CacheableUserFlags!
        var other: CacheableUserFlags!
        describe("equals") {
            context("when flags and lastUpdated match") {
                beforeEach {
                    subject = CacheableUserFlags(flags: DarklyServiceMock.Constants.featureFlags, lastUpdated: Constants.lastUpdatedDate)
                    other = CacheableUserFlags(flags: DarklyServiceMock.Constants.featureFlags, lastUpdated: Constants.lastUpdatedDate)
                }
                it("returns true") {
                    expect(subject) == other
                }
            }
            context("when flags do not match") {
                beforeEach {
                    subject = CacheableUserFlags(flags: DarklyServiceMock.Constants.featureFlagsWithNull, lastUpdated: Constants.lastUpdatedDate)
                    other = CacheableUserFlags(flags: DarklyServiceMock.Constants.featureFlags, lastUpdated: Constants.lastUpdatedDate)
                }
                it("returns false") {
                    expect(subject) != other
                }
            }
            context("when last updates does not match") {
                beforeEach {
                    subject = CacheableUserFlags(flags: DarklyServiceMock.Constants.featureFlags, lastUpdated: Constants.lastUpdatedDate)
                    other = CacheableUserFlags(flags: DarklyServiceMock.Constants.featureFlags, lastUpdated: Date())
                }
                it("returns false") {
                    expect(subject) != other
                }
            }
        }
    }
}
