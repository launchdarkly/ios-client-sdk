//
//  EnvironmentReporterSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 1/10/19. +JMJ
//  Copyright © 2019 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
@testable import LaunchDarkly

final class EnvironmentReporterSpec: QuickSpec {

    override func spec() {
        integrationHarnessSpec()
    }

    private func integrationHarnessSpec() {
        var environmentReporter: EnvironmentReporter!
        describe("shouldRunThrottled") {
            context("Debug Build") {
                context("for the integration harness") {
                    beforeEach {
                        environmentReporter = EnvironmentReporter()
                    }
                    it("should not throttle online calls") {
                        expect(environmentReporter.shouldThrottleOnlineCalls) == false
                    }
                }
                context("not for the integration harness") {
                    beforeEach {
                        environmentReporter = EnvironmentReporter()
                    }
                    it("should throttle online calls") {
                        expect(environmentReporter.shouldThrottleOnlineCalls) == true
                    }
                }
            }
        }
    }
}
