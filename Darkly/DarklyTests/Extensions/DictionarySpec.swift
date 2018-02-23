//
//  DictionarySpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 11/28/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import Darkly

public final class DictionarySpec: QuickSpec {
    public override func spec() {
        var subject: [String: Any]!
        var other: [String: Any]!
        beforeEach {
            subject = [String: Any].stub()
            other = [String: Any].stub()
        }

        describe("symmetric difference") {
            context("when dictionaries are equal") {
                it("returns an empty array") {
                    expect(subject.symmetricDifference(other)) == []
                }
            }
            context("when other is empty") {
                beforeEach {
                    other = [:]
                }
                it("returns all keys in subject") {
                    expect(subject.symmetricDifference(other)) == subject.keys.sorted()
                }
            }
            context("when subject is empty") {
                beforeEach {
                    subject = [:]
                }
                it("returns all keys in other") {
                    expect(subject.symmetricDifference(other)) == other.keys.sorted()
                }
            }
            context("when subject has an added key") {
                let addedKey = "addedKey"
                beforeEach {
                    subject[addedKey] = true
                }
                it("returns the different key") {
                    expect(subject.symmetricDifference(other)) == [addedKey]
                }
            }
            context("when other has an added key") {
                let addedKey = "addedKey"
                beforeEach {
                    other[addedKey] = true
                }
                it("returns the different key") {
                    expect(subject.symmetricDifference(other)) == [addedKey]
                }
            }
            context("when other has a different key") {
                let addedKeyA = "addedKeyA"
                let addedKeyB = "addedKeyB"
                beforeEach {
                    other[addedKeyA] = true
                    subject[addedKeyB] = true
                }
                it("returns the different keys") {
                    expect(subject.symmetricDifference(other)) == [addedKeyA, addedKeyB]
                }
            }
            context("when other has a different bool value") {
                let differingKey = DarklyServiceMock.FlagKeys.bool
                beforeEach {
                    other[differingKey] = !DarklyServiceMock.FlagValues.bool
                }
                it("returns the different key") {
                    expect(subject.symmetricDifference(other)) == [differingKey]
                }
            }
            context("when other has a different int value") {
                let differingKey = DarklyServiceMock.FlagKeys.int
                beforeEach {
                    other[differingKey] = DarklyServiceMock.FlagValues.int + 1
                }
                it("returns the different key") {
                    expect(subject.symmetricDifference(other)) == [differingKey]
                }
            }
            context("when other has a different double value") {
                let differingKey = DarklyServiceMock.FlagKeys.double
                beforeEach {
                    other[differingKey] = DarklyServiceMock.FlagValues.double - 1.0
                }
                it("returns the different key") {
                    expect(subject.symmetricDifference(other)) == [differingKey]
                }
            }
            context("when other has a different string value") {
                let differingKey = DarklyServiceMock.FlagKeys.string
                beforeEach {
                    other[differingKey] = DarklyServiceMock.FlagValues.string + " some new text"
                }
                it("returns the different key") {
                    expect(subject.symmetricDifference(other)) == [differingKey]
                }
            }
            context("when other has a different array value") {
                let differingKey = DarklyServiceMock.FlagKeys.array
                beforeEach {
                    other[differingKey] = DarklyServiceMock.FlagValues.array + [4]
                }
                it("returns the different key") {
                    expect(subject.symmetricDifference(other)) == [differingKey]
                }
            }
            context("when other has a different dictionary value") {
                let differingKey = DarklyServiceMock.FlagKeys.dictionary
                beforeEach {
                    var differingDictionary = DarklyServiceMock.FlagValues.dictionary
                    differingDictionary["sub-flag-a"] = !(differingDictionary["sub-flag-a"] as! Bool)
                    other[differingKey] = differingDictionary
                }
                it("returns the different key") {
                    expect(subject.symmetricDifference(other)) == [differingKey]
                }
            }
        }
    }
}

fileprivate extension Dictionary {
    struct Keys {
        static var bool: String { return "bool-key" }
        static var int: String { return "int-key" }
        static var double: String { return "double-key" }
        static var string: String { return "string-key" }
        static var array: String { return "array-key" }
        static var dictionary: String { return "dictionary-key" }
        static var null: String { return "null-key" }

        static var all: [Any] { return [bool, int, double, string, array, dictionary, null] }
    }

    struct Values {
        static var bool: Bool { return true }
        static var int: Int { return 7 }
        static var double: Double { return 3.14159 }
        static var string: String { return "string value" }
        static var array: [Int] { return [1, 2, 3] }
        static var dictionary: [String: Any] { return ["sub-flag-a": false, "sub-flag-b": 3, "sub-flag-c": 2.71828] }
        static var null: NSNull { return NSNull() }

        static var all: [Any] { return [bool, int, double, string, array, dictionary, null] }
    }

    static func stub() -> [String: Any] {
        return [Keys.bool: Values.bool,
                Keys.int: Values.int,
                Keys.double: Values.double,
                Keys.string: Values.string,
                Keys.array: Values.array,
                Keys.dictionary: Values.dictionary]
    }
}

extension Dictionary where Key == String, Value == Any {
    func appendNull() -> [String: Any] {
        var dictWithNull = self
        dictWithNull[Keys.null] = Values.null
        return dictWithNull
    }
}
