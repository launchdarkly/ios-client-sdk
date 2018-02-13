//
//  URLResponse.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 2/12/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation

extension URLResponse {
    var httpStatusCode: Int? { return (self as? HTTPURLResponse)?.statusCode }
}
