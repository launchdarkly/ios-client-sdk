//
//  HTTPURLResponse.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 12/15/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

extension HTTPURLResponse {
    struct StatusCodes {
        //swiftlint:disable:next identifier_name
        static let ok = 200
        static let accepted = 202
        static let badRequest = 400
        static let unauthorized = 401
        static let methodNotAllowed = 405
        static let internalServerError = 500
        static let notImplemented = 501
    }
}
