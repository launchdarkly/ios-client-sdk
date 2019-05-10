//
//  TimeIntervalSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 3/27/19.
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class TimeIntervalSpec: QuickSpec {
    override func spec() {
        initSpec()
    }

    private func initSpec() {
        var timeInterval: TimeInterval!
        describe("initWithDays") {
            context("1 day") {
                beforeEach {
                    timeInterval = TimeInterval(days: 1)
                }
                it("creates a time interval of 1 day") {
                    expect(timeInterval) == 1.0 * 24 * 60 * 60
                }
            }
        }
    }
}
