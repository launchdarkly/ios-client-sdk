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
}
