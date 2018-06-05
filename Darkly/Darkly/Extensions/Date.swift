//
//  Date.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 10/26/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

extension Date {
    var millisSince1970: Int64 { return Int64(floor(self.timeIntervalSince1970 * 1000)) }

    init?(millisSince1970: Int64?) {
        guard let millisSince1970 = millisSince1970, millisSince1970 >= 0 else { return nil }
        self = Date(timeIntervalSince1970: Double(millisSince1970) / 1000)
    }

    func isWithin(_ timeInterval: TimeInterval, of otherDate: Date) -> Bool {
        return fabs(self.timeIntervalSince(otherDate)) <= timeInterval
    }
}
