//
//  Dictionary.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

extension Dictionary where Key == String {
    var jsonString: String? {
        guard let encodedDictionary = jsonData
        else { return nil }
        return String(data: encodedDictionary, encoding: .utf8)
    }

    var jsonData: Data? {
        guard JSONSerialization.isValidJSONObject(self)
        else { return nil }
        return try? JSONSerialization.data(withJSONObject: self, options: [])
    }

    func isEqual(to other: [String: Any]) -> Bool {
        guard self.count == other.count
        else { return false }
        guard self.keys.sorted() == other.keys.sorted()
        else { return false }
        for key in self.keys {
            if !AnyComparer.isEqual(self[key], to: other[key]) {
                return false
            }
        }
        return true
    }

    func symmetricDifference(_ other: [String: Any]) -> [String] {
        let leftKeys: Set<String> = Set(self.keys)
        let rightKeys: Set<String> = Set(other.keys)
        let differingKeys = leftKeys.symmetricDifference(rightKeys)
        let matchingKeys = leftKeys.intersection(rightKeys)
        let matchingKeysWithDifferentValues = matchingKeys.filter { key -> Bool in
            !AnyComparer.isEqual(self[key], to: other[key])
        }
        return differingKeys.union(matchingKeysWithDifferentValues).sorted()
    }

    var base64UrlEncodedString: String? {
        jsonData?.base64UrlEncodedString
    }
}

extension Dictionary where Key == String, Value == Any {
    var withNullValuesRemoved: [String: Any] {
        self.filter { !($1 is NSNull) }.mapValues { value in
            if let dictionary = value as? [String: Any] {
                return dictionary.withNullValuesRemoved
            }
            return value
        }
    }
}

extension Optional where Wrapped == [String: Any] {
    public static func == (lhs: [String: Any]?, rhs: [String: Any]?) -> Bool {
        guard let lhs = lhs
        else {
            // swiftlint:disable unused_optional_binding
            guard let _ = rhs
            else {
                return true
            }
            return false
        }
        guard let rhs = rhs
        else {
            return false
        }
        return lhs.isEqual(to: rhs)
    }

    public static func != (lhs: [String: Any]?, rhs: [String: Any]?) -> Bool {
        !(lhs == rhs)
    }
}
