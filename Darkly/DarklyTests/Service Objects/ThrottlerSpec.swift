//
//  ThrottlerSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 5/14/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
@testable import Darkly

final class ThrottlerSpec: QuickSpec {

    struct Constants {
        static let maxDelay: TimeInterval = 10.0
    }

    override func spec() {
        initSpec()
    }

    func initSpec() {
        describe("init") {
            var subject: Throttler!
            context("with a maxDelay parameter") {
                beforeEach {
                    subject = Throttler(maxDelay: Constants.maxDelay)
                }
                it("sets the maxDelay") {
                    expect(subject.maxDelay) == Constants.maxDelay
                }
                it("is ready for the first run") {
                    expect(subject.runAttempts) == 0
                    expect(subject.delay) == 0.0
                    expect(subject.timerStart).to(beNil())
                    expect(subject.delayTimer).to(beNil())
                }
            }
            context("without a maxDelay parameter") {
                beforeEach {
                    subject = Throttler()
                }
                it("sets the maxDelay constant") {
                    expect(subject.maxDelay) == Throttler.Constants.maxDelay
                }
                it("is ready for the first run") {
                    expect(subject.runAttempts) == 0
                    expect(subject.delay) == 0.0
                    expect(subject.timerStart).to(beNil())
                    expect(subject.delayTimer).to(beNil())
                }
            }
        }
    }
}
