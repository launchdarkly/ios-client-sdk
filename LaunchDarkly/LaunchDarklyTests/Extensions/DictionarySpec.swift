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
                it("returns all keys in subject") {
                    otherDictionary = [:]
                    expect(dictionary.symmetricDifference(otherDictionary)) == dictionary.keys.sorted()
                }
            }
            context("when subject is empty") {
                it("returns all keys in other") {
                    dictionary = [:]
                    expect(dictionary.symmetricDifference(otherDictionary)) == otherDictionary.keys.sorted()
                }
            }
            context("when subject has an added key") {
                it("returns the different key") {
                    let addedKey = "addedKey"
                    dictionary[addedKey] = true
                    expect(dictionary.symmetricDifference(otherDictionary)) == [addedKey]
                }
            }
            context("when other has an added key") {
                it("returns the different key") {
                    let addedKey = "addedKey"
                    otherDictionary[addedKey] = true
                    expect(dictionary.symmetricDifference(otherDictionary)) == [addedKey]
                }
            }
            context("when other has a different key") {
                it("returns the different keys") {
                    let addedKeyA = "addedKeyA"
                    let addedKeyB = "addedKeyB"
                    otherDictionary[addedKeyA] = true
                    dictionary[addedKeyB] = true
                    expect(dictionary.symmetricDifference(otherDictionary)) == [addedKeyA, addedKeyB]
                }
            }
            context("when other has a different bool value") {
                it("returns the different key") {
                    let differingKey = DarklyServiceMock.FlagKeys.bool
                    otherDictionary[differingKey] = !DarklyServiceMock.FlagValues.bool
                    expect(dictionary.symmetricDifference(otherDictionary)) == [differingKey]
                }
            }
            context("when other has a different int value") {
                it("returns the different key") {
                    let differingKey = DarklyServiceMock.FlagKeys.int
                    otherDictionary[differingKey] = DarklyServiceMock.FlagValues.int + 1
                    expect(dictionary.symmetricDifference(otherDictionary)) == [differingKey]
                }
            }
            context("when other has a different double value") {
                it("returns the different key") {
                    let differingKey = DarklyServiceMock.FlagKeys.double
                    otherDictionary[differingKey] = DarklyServiceMock.FlagValues.double - 1.0
                    expect(dictionary.symmetricDifference(otherDictionary)) == [differingKey]
                }
            }
            context("when other has a different string value") {
                it("returns the different key") {
                    let differingKey = DarklyServiceMock.FlagKeys.string
                    otherDictionary[differingKey] = DarklyServiceMock.FlagValues.string + " some new text"
                    expect(dictionary.symmetricDifference(otherDictionary)) == [differingKey]
                }
            }
            context("when other has a different array value") {
                it("returns the different key") {
                    let differingKey = DarklyServiceMock.FlagKeys.array
                    otherDictionary[differingKey] = DarklyServiceMock.FlagValues.array + [4]
                    expect(dictionary.symmetricDifference(otherDictionary)) == [differingKey]
                }
            }
            context("when other has a different dictionary value") {
                it("returns the different key") {
                    let differingKey = DarklyServiceMock.FlagKeys.dictionary
                    var differingDictionary = DarklyServiceMock.FlagValues.dictionary
                    differingDictionary["sub-flag-a"] = !(differingDictionary["sub-flag-a"] as! Bool)
                    otherDictionary[differingKey] = differingDictionary
                    expect(dictionary.symmetricDifference(otherDictionary)) == [differingKey]
                }
            }
        }
    }

    private func withNullValuesRemovedSpec() {
        describe("withNullValuesRemoved") {
            it("when no null values exist") {
                let dictionary = Dictionary.stub()
                let resultingDictionary = dictionary.withNullValuesRemoved
                expect(dictionary.keys) == resultingDictionary.keys
            }
            context("when null values exist") {
                it("in the top level") {
                    var dictionary = Dictionary.stub()
                    dictionary["null-key"] = NSNull()
                    let resultingDictionary = dictionary.withNullValuesRemoved
                    expect(resultingDictionary.keys) == Dictionary.stub().keys
                }
                it("in the second level") {
                    var dictionary = Dictionary.stub()
                    var subDict = Dictionary.Values.dictionary
                    subDict["null-key"] = NSNull()
                    dictionary[Dictionary.Keys.dictionary] = subDict
                    let resultingDictionary = dictionary.withNullValuesRemoved
                    expect((resultingDictionary[Dictionary.Keys.dictionary] as! [String: Any]).keys) == Dictionary.Values.dictionary.keys
                }
            }
        }
    }
}

fileprivate extension Dictionary where Key == String, Value == Any {
    struct Keys {
        static let bool: String = "bool-key"
        static let int: String = "int-key"
        static let double: String = "double-key"
        static let string: String = "string-key"
        static let array: String = "array-key"
        static let dictionary: String = "dictionary-key"
        static let null: String = "null-key"
    }

    struct Values {
        static let bool: Bool = true
        static let int: Int = 7
        static let double: Double = 3.14159
        static let string: String = "string value"
        static let array: [Int] = [1, 2, 3]
        static let dictionary: [String: Any] = ["sub-flag-a": false, "sub-flag-b": 3, "sub-flag-c": 2.71828]
        static let null: NSNull = NSNull()
    }

    static func stub() -> [String: Any] {
        [Keys.bool: Values.bool,
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
