//
//  Date.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

extension Date {
    var millisSince1970: Int64 {
        Int64(floor(self.timeIntervalSince1970 * 1_000))
    }

    init?(millisSince1970: Int64?) {
        guard let millisSince1970 = millisSince1970, millisSince1970 >= 0
        else { return nil }
        self = Date(timeIntervalSince1970: Double(millisSince1970) / 1_000)
    }

    func isWithin(_ timeInterval: TimeInterval, of otherDate: Date?) -> Bool {
        guard let otherDate = otherDate
        else { return false }
        return fabs(self.timeIntervalSince(otherDate)) <= timeInterval
    }

    func isEarlierThan(_ otherDate: Date) -> Bool {
        self.timeIntervalSince(otherDate) < 0.0
    }
}
