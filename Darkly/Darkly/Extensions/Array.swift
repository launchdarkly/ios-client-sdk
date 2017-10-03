//
//  Array.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 10/26/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

extension Array {
    var encodable: [Encodable]? {
        let converted = flatMap { (element) -> Encodable? in try? Array.toEncodable(element) }
        guard self.count == converted.count else { return nil }
        return converted.filter { (element) in
            guard let stringValue = element as? String else { return true }
            return stringValue != String.nullValueString
        }
    }
}
