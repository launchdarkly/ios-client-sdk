//
//  URLResponse.swift
//  LaunchDarkly
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

extension URLResponse {
    var httpStatusCode: Int? { (self as? HTTPURLResponse)?.statusCode }
    var httpHeaderEtag: String? { (self as? HTTPURLResponse)?.headerEtag }
}
