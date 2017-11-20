//
//  Dictionary.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 10/18/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

extension Dictionary where Key == String {
    var jsonString: String? {
        guard let encodedDictionary = jsonData
            else { return nil }
        return String(data: encodedDictionary, encoding: .utf8)
    }
    
    var jsonData: Data? {
        guard JSONSerialization.isValidJSONObject(self) else { return nil }
        return try? JSONSerialization.data(withJSONObject: self, options: [])
    }

    public static func == (lhs: [String: Any], rhs: [String: Any]) -> Bool {
        return lhs.isEqual(to: rhs)
    }

    public func isEqual(to other: [String: Any]) -> Bool {
        guard self.count == other.count else { return false }
        guard self.keys.sorted() == other.keys.sorted() else { return false }
        for key in self.keys {
            if self[key] == nil && other[key] == nil { continue }
            guard let value = self[key], let otherValue = other[key] else { return false }
            if !AnyComparer.isEqual(value, to: otherValue) { return false }
        }
        return true
    }

    var base64UrlEncodedString: String? { return jsonData?.base64UrlEncodedString }
}

extension Optional where Wrapped == [String: Any] {
    public static func == (lhs: [String: Any]?, rhs: [String: Any]?) -> Bool {
        guard let lhs = lhs else { return rhs == nil }
        guard let rhs = rhs else { return false }
        return lhs.isEqual(to: rhs)
    }

    public static func != (lhs: [String: Any]?, rhs: [String: Any]?) -> Bool {
        return !(lhs == rhs)
    }
}

extension Dictionary {
    init(_ pairs: [Element]) {
        self.init()
        pairs.forEach { (key, value) in self[key] = value }
    }

    func flatMapValues<T>(_ transform: (Dictionary.Value) throws -> T?) rethrows -> Dictionary<Dictionary.Key, T> {
        var dictionary = [Dictionary.Key: T]()
        try self.mapValues(transform).flatMap { (keyValuePair) -> (Dictionary.Key, T)? in
            guard let value = keyValuePair.value else { return nil }
            return (keyValuePair.key, value)
            }.forEach { (pair: (key: Dictionary.Key, value: T)) in dictionary[pair.key] = pair.value }
        return dictionary
    }
}
