@testable import LaunchDarkly
import Foundation
import XCTest

final class LDValueDecoderSpec: XCTestCase {
    func testDecodeBooleans() {
        let isFalse: LDValue = false
        let isTrue: LDValue = true

        XCTAssertEqual(self.decode(Bool.self, value: isFalse), false)
        XCTAssertEqual(self.decode(Bool.self, value: isTrue), true)
    }

    func testDecodeStrings() {
        let name: LDValue = "First A. Last"
        let empty: LDValue = ""

        XCTAssertEqual(self.decode(String.self, value: name), "First A. Last")
        XCTAssertEqual(self.decode(String.self, value: empty), "")
    }

    func testDecodeNumbers() {
        let theLoneliestNumber: LDValue = 1
        let pi: LDValue = 3.14

        XCTAssertEqual(self.decode(Int.self, value: theLoneliestNumber), 1)
        XCTAssertEqual(self.decode(Int.self, value: pi), 3)

        XCTAssertEqual(self.decode(Double.self, value: theLoneliestNumber), 1.0)
        XCTAssertEqual(self.decode(Double.self, value: pi), 3.14)
    }

    func testDecodeArrays() {
        let fruit: LDValue = ["Apple", "Banana", "Cucumber"]
        XCTAssertEqual(self.decode([String].self, value: fruit), ["Apple", "Banana", "Cucumber"])
    }

    func testDecodeDictionaries() {
        let address: LDValue = ["street": "123 Easy St", "city": "Anytown", "state": "CA"]
        let stats: LDValue = ["children": 3, "age": 79]

        XCTAssertEqual(self.decode([String: String].self, value: address), ["street": "123 Easy St", "city": "Anytown", "state": "CA"])
        XCTAssertEqual(self.decode([String: Int].self, value: stats), ["children": 3, "age": 79])
    }

    struct SimpleDecodable: Decodable {
        public let firstName: String
        public let age: Int
        public let address: [String: String]
    }

    func testDecodeDecodableType() {
        let simpleLDValue = LDValue(dictionaryLiteral: ("firstName", "Danny"), ("age", 79), ("address", ["street": "123 Easy St", "city": "Anytown", "state": "CA"]))

        let decoded = self.decode(SimpleDecodable.self, value: simpleLDValue)

        XCTAssertEqual(decoded?.firstName, "Danny")
        XCTAssertEqual(decoded?.age, 79)
        XCTAssertEqual(decoded?.address["street"], "123 Easy St")
        XCTAssertEqual(decoded?.address["city"], "Anytown")
        XCTAssertEqual(decoded?.address["state"], "CA")
    }

    struct ComplexDecodable: Decodable {
        public let firstName: String
        public let lastName: String
        public let address: Address

        private struct DynamicCodingKeys: CodingKey {
            // Protocol required implementations
            var stringValue: String
            var intValue: Int?

            init?(stringValue: String) {
                self.stringValue = stringValue
            }

            init?(intValue: Int) {
                return nil
            }

            // Convenience method since we don't want to unwrap everywhere
            init(string: String) {
                self.stringValue = string
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

            guard case .some(let bio) = try container.decodeIfPresent([String: String].self, forKey: DynamicCodingKeys(string: "bio")) else {
                throw DecodingError.valueNotFound([String: String].self, DecodingError.Context(codingPath: [DynamicCodingKeys(string: "bio")], debugDescription: "bio must be present and a dictionary of strings"))
            }

            guard let firstName = bio["firstName"] else {
                throw DecodingError.valueNotFound(String.self, DecodingError.Context(codingPath: [DynamicCodingKeys(string: "bio"), DynamicCodingKeys(string: "firstName")], debugDescription: "bio must contain first name"))
            }

            self.firstName = firstName

            guard let lastName = bio["lastName"] else {
                throw DecodingError.valueNotFound(String.self, DecodingError.Context(codingPath: [DynamicCodingKeys(string: "bio"), DynamicCodingKeys(string: "lastName")], debugDescription: "bio must contain last name"))
            }

            self.lastName = lastName

            guard case .some(let address) = try container.decodeIfPresent(Address.self, forKey: DynamicCodingKeys(string: "addy")) else {
                throw DecodingError.valueNotFound(String.self, DecodingError.Context(codingPath: [DynamicCodingKeys(string: "addy")], debugDescription: "addy must contain address information"))
            }

            self.address = address
        }
    }

    struct Address: Decodable {
        public let street: String
        public let city: String
        public let state: String
    }

    func testCustomDecodableType() {
        let bio: LDValue = ["firstName": "Danny", "lastName": "DeVito"]
        let address: LDValue = ["street": "123 Easy St", "city": "Anytown", "state": "CA"]

        let user: LDValue = ["bio": bio, "addy": address]
        let decoded = self.decode(ComplexDecodable.self, value: user)

        XCTAssertEqual(decoded?.firstName, "Danny")
        XCTAssertEqual(decoded?.lastName, "DeVito")
        XCTAssertEqual(decoded?.address.street, "123 Easy St")
        XCTAssertEqual(decoded?.address.city, "Anytown")
        XCTAssertEqual(decoded?.address.state, "CA")
    }

    private func decode<T>(_ type: T.Type, value: LDValue) -> T? where T: Decodable {
        do {
            return try LDValueDecoder().decode(type, from: value)
        } catch {
            return nil
        }
    }
}
