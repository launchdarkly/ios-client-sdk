//
//  HTTPURLResponse.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 2/13/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation
@testable import LaunchDarkly

extension HTTPURLResponse.StatusCodes {
    static let all = [ok, accepted, badRequest, unauthorized, methodNotAllowed, internalServerError, notImplemented]
    static let retry = LDConfig.reportRetryStatusCodes
    static let nonRetry = all.filter { (statusCode) in
        !LDConfig.reportRetryStatusCodes.contains(statusCode) && statusCode != ok
    }
}
