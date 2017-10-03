//
//  Dictionary.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 10/18/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

extension Dictionary where Key == String, Value == Encodable {
    var jsonString: String? {
        guard let encodedDictionary = jsonData
            else { return nil }
        return String(data: encodedDictionary, encoding: .utf8)
    }
    
    var jsonData: Data? {
        guard JSONSerialization.isValidJSONObject(self) else { return nil }
        return try? JSONSerialization.data(withJSONObject: self, options: [])
    }

    public static func == (lhs: [String: Encodable], rhs: [String: Encodable]) -> Bool {
        return lhs.jsonString == rhs.jsonString
    }

    var base64UrlEncodedString: String? { return jsonData?.base64UrlEncodedString }
}

extension Dictionary where Key == String {
    var encodable: [String: Encodable]? {
        let keyValuePairs = mapValues { (value) -> Encodable? in
            try? Dictionary.toEncodable(value)
        }.flatMap { (key, value) -> (String, Encodable)? in
            guard let value = value else { return nil }
            return (key, value)
        }
        guard self.count == keyValuePairs.count else { return nil }
        let filteredPairs = keyValuePairs.filter { (pair) -> Bool in
            let (_, value) = pair
            guard let stringValue = value as? String else { return true }
            return stringValue != String.nullValueString
        }
        return Dictionary.dictionary(from: filteredPairs)
    }

    static func dictionary(from keyValuePairs: [(String, Encodable)]) -> [String: Encodable] {
        var converted = [String: Encodable]()
        keyValuePairs.forEach { (key, value) in converted[key] = value }
        return converted
    }
}

extension Dictionary {
    init(_ pairs: [Element]) {
        self.init()
        pairs.forEach { (key, value) in self[key] = value }
    }
}
