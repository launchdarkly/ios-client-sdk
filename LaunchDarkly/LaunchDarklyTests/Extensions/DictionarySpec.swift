//
//  DictionarySpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 11/28/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class DictionarySpec: QuickSpec {
    public override func spec() {
        symmetricDifferenceSpec()
        withNullValuesRemovedSpec()
    }

    private func symmetricDifferenceSpec() {
        describe("symmetric difference") {
            var dictionary: [String: Any]!
            var otherDictionary: [String: Any]!
            beforeEach {
                dictionary = [String: Any].stub()
                otherDictionary = [String: Any].stub()
            }
            context("when dictionaries are equal") {
                it("returns an empty array") {
                    expect(dictionary.symmetricDifference(otherDictionary)) == []
                }
            }
            context("when other is empty") {
                beforeEach {
                    otherDictionary = [:]
                }
                it("returns all keys in subject") {
                    expect(dictionary.symmetricDifference(otherDictionary)) == dictionary.keys.sorted()
                }
            }
            context("when subject is empty") {
                beforeEach {
                    dictionary = [:]
                }
                it("returns all keys in other") {
                    expect(dictionary.symmetricDifference(otherDictionary)) == otherDictionary.keys.sorted()
                }
            }
            context("when subject has an added key") {
                let addedKey = "addedKey"
                beforeEach {
                    dictionary[addedKey] = true
                }
                it("returns the different key") {
                    expect(dictionary.symmetricDifference(otherDictionary)) == [addedKey]
                }
            }
            context("when other has an added key") {
                let addedKey = "addedKey"
                beforeEach {
                    otherDictionary[addedKey] = true
                }
                it("returns the different key") {
                    expect(dictionary.symmetricDifference(otherDictionary)) == [addedKey]
                }
            }
            context("when other has a different key") {
                let addedKeyA = "addedKeyA"
                let addedKeyB = "addedKeyB"
                beforeEach {
                    otherDictionary[addedKeyA] = true
                    dictionary[addedKeyB] = true
                }
                it("returns the different keys") {
                    expect(dictionary.symmetricDifference(otherDictionary)) == [addedKeyA, addedKeyB]
                }
            }
            context("when other has a different bool value") {
                let differingKey = DarklyServiceMock.FlagKeys.bool
                beforeEach {
                    otherDictionary[differingKey] = !DarklyServiceMock.FlagValues.bool
                }
                it("returns the different key") {
                    expect(dictionary.symmetricDifference(otherDictionary)) == [differingKey]
                }
            }
            context("when other has a different int value") {
                let differingKey = DarklyServiceMock.FlagKeys.int
                beforeEach {
                    otherDictionary[differingKey] = DarklyServiceMock.FlagValues.int + 1
                }
                it("returns the different key") {
                    expect(dictionary.symmetricDifference(otherDictionary)) == [differingKey]
                }
            }
            context("when other has a different double value") {
                let differingKey = DarklyServiceMock.FlagKeys.double
                beforeEach {
                    otherDictionary[differingKey] = DarklyServiceMock.FlagValues.double - 1.0
                }
                it("returns the different key") {
                    expect(dictionary.symmetricDifference(otherDictionary)) == [differingKey]
                }
            }
            context("when other has a different string value") {
                let differingKey = DarklyServiceMock.FlagKeys.string
                beforeEach {
                    otherDictionary[differingKey] = DarklyServiceMock.FlagValues.string + " some new text"
                }
                it("returns the different key") {
                    expect(dictionary.symmetricDifference(otherDictionary)) == [differingKey]
                }
            }
            context("when other has a different array value") {
                let differingKey = DarklyServiceMock.FlagKeys.array
                beforeEach {
                    otherDictionary[differingKey] = DarklyServiceMock.FlagValues.array + [4]
                }
                it("returns the different key") {
                    expect(dictionary.symmetricDifference(otherDictionary)) == [differingKey]
                }
            }
            context("when other has a different dictionary value") {
                let differingKey = DarklyServiceMock.FlagKeys.dictionary
                beforeEach {
                    var differingDictionary = DarklyServiceMock.FlagValues.dictionary
                    differingDictionary["sub-flag-a"] = !(differingDictionary["sub-flag-a"] as! Bool)
                    otherDictionary[differingKey] = differingDictionary
                }
                it("returns the different key") {
                    expect(dictionary.symmetricDifference(otherDictionary)) == [differingKey]
                }
            }
        }
    }

    private func withNullValuesRemovedSpec() {
        describe("withNullValuesRemoved") {
            var dictionary: [String: Any]!
            var resultingDictionary: [String: Any]!
            context("when no null values exist") {
                beforeEach {
                    dictionary = Dictionary.stub()

                    resultingDictionary = dictionary.withNullValuesRemoved
                }
                it("returns the same dictionary") {
                    expect(dictionary == resultingDictionary).to(beTrue())
                }
            }
            context("when null values exist") {
                context("in the top level") {
                    beforeEach {
                        dictionary = Dictionary.stub().withNullValueAppended

                        resultingDictionary = dictionary.withNullValuesRemoved
                    }
                    it("returns the dictionary without the null value") {
                        expect(resultingDictionary == Dictionary.stub()).to(beTrue())
                    }
                }
                context("in the second level") {
                    beforeEach {
                        dictionary = Dictionary.stub()
                        dictionary[Dictionary.Keys.dictionary] = Dictionary.Values.dictionary.withNullValueAppended

                        resultingDictionary = dictionary.withNullValuesRemoved
                    }
                    it("returns a dictionary without the null value") {
                        expect(resultingDictionary == Dictionary.stub()).to(beTrue())
                    }
                }
            }
        }
    }
}

fileprivate extension Dictionary where Key == String, Value == Any {
    struct Keys {
        static var bool: String {
            return "bool-key"
        }
        static var int: String {
            return "int-key"
        }
        static var double: String {
            return "double-key"
        }
        static var string: String {
            return "string-key"
        }
        static var array: String {
            return "array-key"
        }
        static var dictionary: String {
            return "dictionary-key"
        }
        static var null: String {
            return "null-key"
        }

        static var all: [String] {
            return [bool, int, double, string, array, dictionary, null]
        }
    }

    struct Values {
        static var bool: Bool {
            return true
        }
        static var int: Int {
            return 7
        }
        static var double: Double {
            return 3.14159
        }
        static var string: String {
            return "string value"
        }
        static var array: [Int] {
            return [1, 2, 3]
        }
        static var dictionary: [String: Any] {
            return ["sub-flag-a": false, "sub-flag-b": 3, "sub-flag-c": 2.71828]
        }
        static var null: NSNull {
            return NSNull()
        }

        static var all: [Any] {
            return [bool, int, double, string, array, dictionary, null]
        }
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

    var withNullValueAppended: [String: Any] {
        var modifiedDictionary = self
        modifiedDictionary[Keys.null] = Values.null
        return modifiedDictionary
    }
}
