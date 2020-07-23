//
//  JSONSerialization.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

extension JSONSerialization {
    static func jsonDictionary(with data: Data, options: JSONSerialization.ReadingOptions = []) throws -> [String: Any] {
        guard let decodedDictionary = try JSONSerialization.jsonObject(with: data, options: options) as? [String: Any]
        else {
            throw LDInvalidArgumentError("JSON is not an object")
        }
        return decodedDictionary
    }
}
