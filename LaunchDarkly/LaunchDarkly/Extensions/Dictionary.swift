//
//  Dictionary.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 10/18/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

extension Dictionary where Key == String {
    var jsonString: String? {
        guard let encodedDictionary = jsonData
        else {
            return nil
        }
        return String(data: encodedDictionary, encoding: .utf8)
    }
    
    var jsonData: Data? {
        guard JSONSerialization.isValidJSONObject(self)
        else {
            return nil
        }
        return try? JSONSerialization.data(withJSONObject: self, options: [])
    }

    func isEqual(to other: [String: Any]) -> Bool {
        guard self.count == other.count
        else {
            return false
        }
        guard self.keys.sorted() == other.keys.sorted()
        else {
            return false
        }
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
        let matchingKeysWithDifferentValues = matchingKeys.filter { (key) -> Bool in
            !AnyComparer.isEqual(self[key], to: other[key])
        }
        return differingKeys.union(matchingKeysWithDifferentValues).sorted()
    }

    var base64UrlEncodedString: String? {
        return jsonData?.base64UrlEncodedString
    }
}

extension Dictionary where Key == String, Value == Any {
    var withNullValuesRemoved: [String: Any] {
        var filteredDictionary = self.filter { (_, value) in
            !(value is NSNull)
        }
        filteredDictionary = filteredDictionary.mapValues { (value) in
            guard let dictionary = value as? [String: Any]
            else {
                return value
            }
            return dictionary.withNullValuesRemoved
        }
        return filteredDictionary
    }
}

extension Optional where Wrapped == [String: Any] {
    public static func == (lhs: [String: Any]?, rhs: [String: Any]?) -> Bool {
        guard let lhs = lhs
        else {
            return rhs == nil
        }
        guard let rhs = rhs
        else {
            return false
        }
        return lhs.isEqual(to: rhs)
    }

    public static func != (lhs: [String: Any]?, rhs: [String: Any]?) -> Bool {
        return !(lhs == rhs)
    }
}

extension Dictionary {
    func compactMapValues<T>(_ transform: (Dictionary.Value) throws -> T?) rethrows -> Dictionary<Dictionary.Key, T> {
        var dictionary = [Dictionary.Key: T]()
        try self.mapValues(transform).compactMap { (keyValuePair) -> (Dictionary.Key, T)? in
            guard let value = keyValuePair.value
            else {
                return nil
            }
            return (keyValuePair.key, value)
        }.forEach { (pair: (key: Dictionary.Key, value: T)) in
            dictionary[pair.key] = pair.value
        }
        return dictionary
    }
}
