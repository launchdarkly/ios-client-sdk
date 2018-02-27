//
//  Data.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 10/26/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

extension Data {
    var base64UrlEncodedString: String {
        return base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    }
}
