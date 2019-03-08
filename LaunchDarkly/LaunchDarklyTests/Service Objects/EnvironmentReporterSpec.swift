//
//  EnvironmentReporterSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 1/10/19. +JMJ
//  Copyright © 2019 Catamorphic Co. All rights reserved.
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
                //This test is disabled. Configure the build for the integration harness before enabling & running this test.
                //If you enable this test, you might want to disable the test that follows "not for the integration harness", which should fail when the SDK is configured for the integration harness.
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
