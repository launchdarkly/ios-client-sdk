import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class EnvironmentReporterSpec: QuickSpec {

    override func spec() {
        integrationHarnessSpec()
    }

    private func integrationHarnessSpec() {
        describe("shouldRunThrottled") {
            it("should throttle online calls for release build") {
                expect(EnvironmentReporter().shouldThrottleOnlineCalls) == false
            }
        }
    }
}
