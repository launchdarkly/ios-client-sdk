//
//  HTTPURLRequest.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 2/8/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation

extension URLRequest {
    struct HTTPMethods {
        static let get = "GET"
        static let post = "POST"
        static let report = "REPORT"
    }
}
