//
//  URLResponse.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 3/13/19. +JMJ
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

extension URLResponse {
    var httpStatusCode: Int? {
        return (self as? HTTPURLResponse)?.statusCode
    }

    var httpHeaderEtag: String? {
        return (self as? HTTPURLResponse)?.headerEtag
    }
}
