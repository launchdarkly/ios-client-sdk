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
        (self as [String: Any?]).compactMapValues { value in
            if value is NSNull {
                return nil
            }
            if let dictionary = value as? [String: Any] {
                return dictionary.withNullValuesRemoved
            }
            if let arr = value as? [Any] {
                return arr.withNullValuesRemoved
            }
            return value
        }
    }
}

private extension Array where Element == Any {
    var withNullValuesRemoved: [Any] {
        (self as [Any?]).compactMap { value in
            if value is NSNull {
                return nil
            }
            if let arr = value as? [Any] {
                return arr.withNullValuesRemoved
            }
            if let dict = value as? [String: Any] {
                return dict.withNullValuesRemoved
            }
            return value
        }
    }
}
