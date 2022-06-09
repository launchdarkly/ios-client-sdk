import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class LDUserSpec: QuickSpec {

    override func spec() {
        initSpec()
    }

    private func initSpec() {
        initSubSpec()
        initWithEnvironmentReporterSpec()
    }

    private func initSubSpec() {
        var user: LDUser!
        describe("init") {
            it("with all fields and custom overriding system values") {
                user = LDUser(key: LDUser.StubConstants.key,
                              name: LDUser.StubConstants.name,
                              firstName: LDUser.StubConstants.firstName,
                              lastName: LDUser.StubConstants.lastName,
                              country: LDUser.StubConstants.country,
                              ipAddress: LDUser.StubConstants.ipAddress,
                              email: LDUser.StubConstants.email,
                              avatar: LDUser.StubConstants.avatar,
                              custom: LDUser.StubConstants.custom,
                              isAnonymous: LDUser.StubConstants.isAnonymous,
                              privateAttributes: LDUser.optionalAttributes,
                              secondary: LDUser.StubConstants.secondary)
                expect(user.key) == LDUser.StubConstants.key
                expect(user.secondary) == LDUser.StubConstants.secondary
                expect(user.name) == LDUser.StubConstants.name
                expect(user.firstName) == LDUser.StubConstants.firstName
                expect(user.lastName) == LDUser.StubConstants.lastName
                expect(user.isAnonymous) == LDUser.StubConstants.isAnonymous
                expect(user.isAnonymousNullable) == LDUser.StubConstants.isAnonymous
                expect(user.country) == LDUser.StubConstants.country
                expect(user.ipAddress) == LDUser.StubConstants.ipAddress
                expect(user.email) == LDUser.StubConstants.email
                expect(user.avatar) == LDUser.StubConstants.avatar
                expect(user.custom == LDUser.StubConstants.custom).to(beTrue())
                expect(user.privateAttributes) == LDUser.optionalAttributes
            }
            it("without setting anonymous") {
                user = LDUser(key: "abc")
                expect(user.isAnonymous) == false
                expect(user.isAnonymousNullable).to(beNil())
            }
            context("called without optional elements") {
                var environmentReporter: EnvironmentReporter!
                beforeEach {
                    user = LDUser()
                    environmentReporter = EnvironmentReporter()
                }
                it("creates a LDUser without optional elements") {
                    expect(user.key) == LDUser.defaultKey(environmentReporter: environmentReporter)
                    expect(user.isAnonymous) == true
                    expect(user.isAnonymousNullable) == true

                    expect(user.name).to(beNil())
                    expect(user.firstName).to(beNil())
                    expect(user.lastName).to(beNil())
                    expect(user.country).to(beNil())
                    expect(user.ipAddress).to(beNil())
                    expect(user.email).to(beNil())
                    expect(user.avatar).to(beNil())
                    expect(user.custom.count) == 0
                    expect(user.privateAttributes).to(beEmpty())
                    expect(user.secondary).to(beNil())
                }
            }
            context("called without a key multiple times") {
                var users = [LDUser]()
                beforeEach {
                    while users.count < 3 {
                        users.append(LDUser())
                    }
                }
                it("creates each LDUser with the default key and isAnonymous set") {
                    let environmentReporter = EnvironmentReporter()
                    users.forEach { user in
                        expect(user.key) == LDUser.defaultKey(environmentReporter: environmentReporter)
                        expect(user.isAnonymous) == true
                        expect(user.isAnonymousNullable) == true
                    }
                }
            }
        }
    }

    private func initWithEnvironmentReporterSpec() {
        describe("initWithEnvironmentReporter") {
            var user: LDUser!
            var environmentReporter: EnvironmentReportingMock!
            beforeEach {
                environmentReporter = EnvironmentReportingMock()
                user = LDUser(environmentReporter: environmentReporter)
            }
            it("creates a user with system values matching the environment reporter") {
                expect(user.key) == LDUser.defaultKey(environmentReporter: environmentReporter)
                expect(user.isAnonymous) == true
                expect(user.isAnonymousNullable) == true

                expect(user.secondary).to(beNil())
                expect(user.name).to(beNil())
                expect(user.firstName).to(beNil())
                expect(user.lastName).to(beNil())
                expect(user.country).to(beNil())
                expect(user.ipAddress).to(beNil())
                expect(user.email).to(beNil())
                expect(user.avatar).to(beNil())
                expect(user.custom.count) == 0

                expect(user.privateAttributes).to(beEmpty())
            }
        }
    }
}
