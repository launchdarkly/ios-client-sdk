//
//  JSONSerialization.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 10/26/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

extension JSONSerialization {
    @objc (LaunchDarklyJSONError)
    public enum JSONError: Int, Error {
        ///Error used when the expected JSON object is a dictionary, but the actual object is not
        case notADictionary
        ///Error used when the expected object is a valid JSON object, but the actual object is not
        case invalidJsonObject
    }

    static func jsonDictionary(with data: Data, options: JSONSerialization.ReadingOptions = []) throws -> [String: Any] {
        guard let decodedDictionary = try JSONSerialization.jsonObject(with: data, options: options) as? [String: Any]
        else {
            throw JSONError.notADictionary
        }
        return decodedDictionary
    }

    ///String domain set into NSError objects for Objective-C clients when the SDK sends a JSONError 
    @objc(LaunchDarklyJSONErrorDomain)
    public static let JSONErrorDomain = "LaunchDarkly.JSONError"
}
