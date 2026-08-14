import Foundation
import XCTest

@testable import LaunchDarkly

final class LDValueSpec: XCTestCase {
    private let values: [LDValue] = [
        .null,
        .bool(false),
        .bool(true),
        .number(0),
        .number(1),
        .string(""),
        .string("a"),
        .array([]),
        .array([.number(1)]),
        .array([.number(1), .number(2)]),
        .object([:]),
        .object(["a": .number(1)]),
        .object(["a": .number(1), "b": .number(2)])
    ]

    func testEqualValuesHashAlike() {
        for value in values {
            XCTAssertEqual(value.hashValue, value.hashValue, "\(value)")
        }

        // Built separately, so that equality and the hash are of the payload rather than of one instance.
        XCTAssertEqual(LDValue.string("a").hashValue, LDValue.string("a").hashValue)
        XCTAssertEqual(LDValue.array([.string("a"), .null]).hashValue,
                       LDValue.array([.string("a"), .null]).hashValue)
        XCTAssertEqual(LDValue.object(["a": .array([.number(1)])]).hashValue,
                       LDValue.object(["a": .array([.number(1)])]).hashValue)
    }

    func testAnObjectHashesTheSameWhicheverOrderItsKeysWereWrittenIn() {
        let one = LDValue.object(["a": .number(1), "b": .number(2)])
        let other = LDValue.object(["b": .number(2), "a": .number(1)])

        // Key order is not part of equality, so it cannot be part of the hash either.
        XCTAssertEqual(one, other)
        XCTAssertEqual(one.hashValue, other.hashValue)
    }

    func testValuesOfDifferentKindsAreDistinct() {
        // A set rather than a pairwise comparison, so this also covers the values being usable as keys.
        XCTAssertEqual(Set(values).count, values.count)

        // Kinds a naive hash of the payload alone would collide.
        XCTAssertNotEqual(LDValue.bool(false), LDValue.null)
        XCTAssertNotEqual(LDValue.number(0), LDValue.bool(false))
        XCTAssertNotEqual(LDValue.array([]), LDValue.object([:]))
    }

    func testAValueCanKeyADictionary() {
        var byValue: [LDValue: String] = [:]

        for value in values {
            byValue[value] = String(describing: value)
        }

        XCTAssertEqual(byValue.count, values.count)
        XCTAssertEqual(byValue[.object(["a": .number(1)])], String(describing: LDValue.object(["a": .number(1)])))
    }
}
