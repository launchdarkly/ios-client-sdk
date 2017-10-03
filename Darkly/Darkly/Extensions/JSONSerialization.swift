//
//  JSONSerialization.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 10/26/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

extension JSONSerialization {
    enum JSONError: Error {
        case notADictionary
    }

    static func jsonDictionary(with data: Data, options: JSONSerialization.ReadingOptions = []) throws -> [String: Any] {
        guard let decodedDictionary = try JSONSerialization.jsonObject(with: data, options: options) as? [String: Any] else { throw JSONError.notADictionary }
        return decodedDictionary
    }
}
