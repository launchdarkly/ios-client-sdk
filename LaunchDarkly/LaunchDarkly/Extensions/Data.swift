//
//  Data.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 10/26/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

extension Data {
    var base64UrlEncodedString: String {
        return base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    }
}
