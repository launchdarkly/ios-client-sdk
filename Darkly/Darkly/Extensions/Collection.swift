//
//  Collection.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 10/26/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

extension Collection {
    static func toEncodable(_ value: Any) throws -> Encodable? {
        switch value {
        case let boolValue as Bool: return boolValue
        case let intValue as Int: return intValue
        case let doubleValue as Double: return doubleValue
        case let stringValue as String: return stringValue
        case let arrayValue as [Any]: return arrayValue.encodable
        case let dictionaryValue as [String: Any]: return dictionaryValue.encodable
        case _ as NSNull: return String.nullValueString
        default: throw JSONSerialization.JSONError.notADictionary
        }
    }
}

extension String {
    static var nullValueString: String { return "Collection.Encodable.toEncodable.nullValue" }
}
