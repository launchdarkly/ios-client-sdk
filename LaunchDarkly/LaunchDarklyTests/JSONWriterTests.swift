import XCTest
@testable import LaunchDarkly

/// Edge cases for `JSONWriter` on its own: strings, structure, and numbers at their extremes.
///
/// Values are written and then read back with `JSONDecoder`, because what has to agree with the writer is a parser --
/// the service parses what it receives rather than comparing bytes. Where the writer's form is fixed, bytes are
/// compared as well.
final class JSONWriterTests: XCTestCase {

    // MARK: Strings

    func testUnicodeIsWrittenUnchanged() throws {
        let strings = [
            "😀🎉🚀🌍💡🔥❤️✨🎵🎨",
            "👨‍👩‍👧‍👦",
            "🇺🇸🇬🇧🇯🇵🇫🇷",
            "中文日本語한국어",
            "العربية עברית",
            "Hello 世界",
            "e\u{301}",
            "\u{E9}"
        ]
        for string in strings {
            try assertRoundTrips(string)
        }
    }

    func testEmptyString() {
        let writer = JSONWriter()
        writer.write("")

        XCTAssertEqual(text(writer), #""""#)
    }

    func testEveryEscapeRoundTrips() throws {
        try assertRoundTrips("quote: \" backslash: \\ slash: / newline: \n tab: \t carriage: \r backspace: \u{08} formfeed: \u{0C}")
        try assertRoundTrips("before\u{0}after")
        try assertRoundTrips("   \n\t\r   ")
    }

    /// Runs that need no escaping are copied in one go, so escapes go at both ends of a long run and inside one.
    func testVeryLongStrings() throws {
        let run = String(repeating: "x", count: 1_000_000)
        try assertRoundTrips(run)
        try assertRoundTrips("\"" + run + "\"")
        try assertRoundTrips(run + "\n" + run)
    }

    // MARK: Arrays

    func testArrayOfEveryKind() {
        let writer = JSONWriter()
        writer.beginArray()
        writer.writeNull()
        writer.write(true)
        writer.write(false)
        writer.write(42)
        writer.write(3.14)
        writer.write("string")
        writer.beginArray()
        writer.endArray()
        writer.beginObject()
        writer.endObject()
        writer.endArray()

        XCTAssertEqual(text(writer), #"[null,true,false,42,3.14,"string",[],{}]"#)
    }

    func testArraysOfDifferentLengths() {
        let writer = JSONWriter()
        writer.beginArray()
        for length in 0...3 {
            writer.beginArray()
            for element in 0..<length {
                writer.write(element + 1)
            }
            writer.endArray()
        }
        writer.endArray()

        XCTAssertEqual(text(writer), "[[],[1],[1,2],[1,2,3]]")
    }

    func testLargeArray() throws {
        let writer = JSONWriter()
        writer.beginArray()
        for element in 0..<10_000 {
            writer.write(element)
        }
        writer.endArray()

        XCTAssertEqual(try JSONDecoder().decode([Int].self, from: writer.data), Array(0..<10_000))
    }

    func testDeeplyNestedArrays() {
        let writer = JSONWriter()
        for _ in 0..<100 {
            writer.beginArray()
        }
        writer.write(1)
        for _ in 0..<100 {
            writer.endArray()
        }

        XCTAssertEqual(text(writer), String(repeating: "[", count: 100) + "1" + String(repeating: "]", count: 100))
    }

    // MARK: Objects

    func testObjectWithManyKeys() throws {
        let writer = JSONWriter()
        writer.beginObject()
        for index in 0..<1000 {
            writer.key(String(index))
            writer.write(index)
        }
        writer.endObject()

        let expected = Dictionary(uniqueKeysWithValues: (0..<1000).map { (String($0), $0) })
        XCTAssertEqual(try JSONDecoder().decode([String: Int].self, from: writer.data), expected)
    }

    func testKeysThatNeedCareRoundTrip() throws {
        let values = ["": "empty", " ": "space", "\n": "newline", "key with spaces": "value", "\"": "quote", "🔑": "emoji"]

        let writer = JSONWriter()
        writer.beginObject()
        for (key, value) in values {
            writer.key(key)
            writer.write(value)
        }
        writer.endObject()

        XCTAssertEqual(try JSONDecoder().decode([String: String].self, from: writer.data), values)
    }

    func testDeeplyNestedObjects() {
        let writer = JSONWriter()
        for level in (0..<100).reversed() {
            writer.beginObject()
            writer.key("level\(level)")
        }
        writer.beginObject()
        writer.key("value")
        writer.write(42)
        writer.endObject()
        for _ in 0..<100 {
            writer.endObject()
        }

        var expected = #"{"value":42}"#
        for level in 0..<100 {
            expected = #"{"level\#(level)":\#(expected)}"#
        }
        XCTAssertEqual(text(writer), expected)
    }

    // MARK: Numbers

    func testExtremeDoublesRoundTripExactly() throws {
        let numbers: [Double] = [1e-308, 1e308, .leastNonzeroMagnitude, .leastNormalMagnitude, .greatestFiniteMagnitude,
                                 -.greatestFiniteMagnitude, 0.12345678901234567890, 0.1, 1.0 / 3.0, -2.5e-10,
                                 -1e-17, -1e24, -9.999999991999999e24]

        for number in numbers {
            let writer = JSONWriter()
            writer.beginArray()
            writer.write(number)
            writer.endArray()

            let decoded = try JSONDecoder().decode([Double].self, from: writer.data)
            XCTAssertEqual(decoded.first?.bitPattern, number.bitPattern, "\(number) read back as \(decoded)")
        }
    }

    func testIntegralDoubleIsWrittenWithoutAFraction() {
        let writer = JSONWriter()
        writer.write(42.0)

        XCTAssertEqual(text(writer), "42")
    }

    func testNonFiniteDoublesAreWrittenAsNullAndReported() {
        for number in [Double.nan, .infinity, -.infinity] {
            let writer = JSONWriter()
            writer.beginArray()
            writer.write(1.5)
            XCTAssertFalse(writer.wroteNonFiniteNumber)
            writer.write(number)
            writer.endArray()

            XCTAssertEqual(text(writer), "[1.5,null]")
            XCTAssertTrue(writer.wroteNonFiniteNumber, "\(number)")

            writer.reset()
            XCTAssertFalse(writer.wroteNonFiniteNumber)
        }
    }

    func testIntegerBoundaries() {
        let values: [Int] = [Int(Int8.min), Int(Int8.max), Int(Int16.min), Int(Int16.max), Int(Int32.min), Int(Int32.max),
                             Int(UInt8.max), Int(UInt16.max), Int(UInt32.max), .min, .max]

        for value in values {
            let writer = JSONWriter()
            writer.write(value)

            XCTAssertEqual(text(writer), String(value))
        }
    }

    // MARK: Reuse

    /// `reset()` has to clear the separator state as well as the bytes, or every use after the first starts with a comma.
    func testResetStartsEachUseAfresh() {
        let writer = JSONWriter()
        for _ in 0..<1000 {
            writer.reset()
            writer.beginObject()
            writer.key("key")
            writer.write("value")
            writer.key("n")
            writer.beginArray()
            writer.write(1)
            writer.write(2)
            writer.endArray()
            writer.endObject()

            XCTAssertEqual(text(writer), #"{"key":"value","n":[1,2]}"#)
        }
    }

    // MARK: Helpers

    private func text(_ writer: JSONWriter) -> String {
        String(bytes: writer.data, encoding: .utf8) ?? ""
    }

    /// Compares Unicode scalars rather than strings: `String` equality is canonical equivalence, so it would accept a
    /// writer that normalized what it was given.
    private func assertRoundTrips(_ string: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let writer = JSONWriter()
        writer.beginArray()
        writer.write(string)
        writer.endArray()

        let decoded = try JSONDecoder().decode([String].self, from: writer.data)
        let read = try XCTUnwrap(decoded.first, file: file, line: line)
        XCTAssertEqual(decoded.count, 1, file: file, line: line)
        XCTAssertTrue(read.unicodeScalars.elementsEqual(string.unicodeScalars),
                      "\(string.prefix(40).debugDescription) did not read back unchanged", file: file, line: line)
    }
}
