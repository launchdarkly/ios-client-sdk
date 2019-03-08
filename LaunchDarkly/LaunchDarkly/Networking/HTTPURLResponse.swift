//
//  HTTPURLResponse.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 12/15/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

extension HTTPURLResponse {

    struct HeaderKeys {
        static let date = "Date"
    }

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

    var headerDate: Date? {
        guard let dateHeader = self.allHeaderFields[HeaderKeys.date] as? String
        else {
            return nil
        }
        return DateFormatter.httpUrlHeaderFormatter.date(from: dateHeader)
    }
}
