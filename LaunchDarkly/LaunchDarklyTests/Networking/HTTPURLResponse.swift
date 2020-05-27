//
//  HTTPURLResponse.swift
//  LaunchDarklyTests
//
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation
@testable import LaunchDarkly

extension HTTPURLResponse.StatusCodes {
    static let all = [ok, accepted, badRequest, unauthorized, methodNotAllowed, internalServerError, notImplemented]
    static let retry = LDConfig.reportRetryStatusCodes
    static let nonRetry = all.filter { statusCode in
        !LDConfig.reportRetryStatusCodes.contains(statusCode) && statusCode != ok
    }
}

extension HTTPURLResponse.HeaderKeys {
    static let cacheControl = "Cache-Control"
}

extension HTTPURLResponse {
    struct HeaderValues {
        static let etagStub = "4806e"
        static let maxAge = "max-age=0"
    }
}
