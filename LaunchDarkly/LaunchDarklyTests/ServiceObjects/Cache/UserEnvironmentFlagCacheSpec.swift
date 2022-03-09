import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class UserEnvironmentFlagCacheSpec: QuickSpec {

    private struct TestValues {
        static let replacementFlags = ["newFlagKey": FeatureFlag.stub(flagKey: "newFlagKey", flagValue: "newFlagValue")]
        static let newUserEnv = CacheableEnvironmentFlags(userKey: UUID().uuidString,
                                                          mobileKey: UUID().uuidString,
                                                          featureFlags: TestValues.replacementFlags)
        static let lastUpdated = Date().addingTimeInterval(60.0).stringEquivalentDate
    }

    struct TestContext {
        var keyedValueCacheMock = KeyedValueCachingMock()
        let storeMode: FlagCachingStoreMode
        var subject: UserEnvironmentFlagCache
        var userEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags]!
        var selectedUser: String {
            userEnvironmentsCollection.randomElement()!.key
        }
        var selectedMobileKey: String {
            userEnvironmentsCollection[selectedUser]!.environmentFlags.randomElement()!.key
        }
        var oldestUser: String {
            userEnvironmentsCollection.compactMapValues { $0.lastUpdated }
                .max { $1.value.isEarlierThan($0.value) }!
                .key
        }
        var setUserEnvironments: [UserKey: CacheableUserEnvironmentFlags]? {
            (keyedValueCacheMock.setReceivedArguments?.value as? [UserKey: Any])?.compactMapValues { CacheableUserEnvironmentFlags(object: $0) }
        }

        init(maxUsers: Int = 5, storeMode: FlagCachingStoreMode = .async) {
            self.storeMode = storeMode
            subject = UserEnvironmentFlagCache(withKeyedValueCache: keyedValueCacheMock, maxCachedUsers: maxUsers)
        }

        mutating func withCached(userCount: Int = 1) {
            userEnvironmentsCollection = CacheableUserEnvironmentFlags.stubCollection(userCount: userCount).collection
            keyedValueCacheMock.dictionaryReturnValue = userEnvironmentsCollection.compactMapValues { $0.dictionaryValue }
        }

        func storeNewUser() -> CacheableUserEnvironmentFlags {
            let env = storeNewUserEnv(userKey: UUID().uuidString)
            return CacheableUserEnvironmentFlags(userKey: env.userKey,
                                                 environmentFlags: [env.mobileKey: env],
                                                 lastUpdated: TestValues.lastUpdated)
        }

        func storeNewUserEnv(userKey: String) -> CacheableEnvironmentFlags {
            storeUserEnvUpdate(userKey: userKey, mobileKey: UUID().uuidString)
        }

        func storeUserEnvUpdate(userKey: String, mobileKey: String) -> CacheableEnvironmentFlags {
            storeFlags(TestValues.replacementFlags, userKey: userKey, mobileKey: mobileKey, lastUpdated: TestValues.lastUpdated)
            return CacheableEnvironmentFlags(userKey: userKey, mobileKey: mobileKey, featureFlags: TestValues.replacementFlags)
        }

        func storeFlags(_ featureFlags: [LDFlagKey: FeatureFlag],
                        userKey: String,
                        mobileKey: String,
                        lastUpdated: Date) {
            waitUntil { done in
                self.subject.storeFeatureFlags(featureFlags, userKey: userKey, mobileKey: mobileKey, lastUpdated: lastUpdated, storeMode: self.storeMode, completion: done)
                if self.storeMode == .sync { done() }
            }
            expect(self.keyedValueCacheMock.setReceivedArguments?.forKey) == UserEnvironmentFlagCache.CacheKeys.cachedUserEnvironmentFlags
        }
    }

    override func spec() {
        initSpec()
        retrieveFeatureFlagsSpec()
        storeFeatureFlagsSpec(maxUsers: LDConfig.Defaults.maxCachedUsers)
        storeFeatureFlagsSpec(maxUsers: 3)
        storeUnlimitedUsersSpec()
    }

    private func initSpec() {
        describe("init") {
            it("creates a UserEnvironmentFlagCache") {
                let testContext = TestContext(maxUsers: 5)
                expect(testContext.subject.keyedValueCache) === testContext.keyedValueCacheMock
                expect(testContext.subject.maxCachedUsers) == 5
            }
        }
    }

    private func retrieveFeatureFlagsSpec() {
        var testContext: TestContext!
        describe("retrieveFeatureFlags") {
            beforeEach {
                testContext = TestContext()
            }
            context("returns nil") {
                it("when no flags are stored") {
                    expect(testContext.subject.retrieveFeatureFlags(forUserWithKey: "unknown", andMobileKey: "unknown")).to(beNil())
                }
                it("when no flags are stored for user") {
                    testContext.withCached(userCount: LDConfig.Defaults.maxCachedUsers)
                    expect(testContext.subject.retrieveFeatureFlags(forUserWithKey: "unknown", andMobileKey: testContext.selectedMobileKey)).to(beNil())
                }
                it("when no flags are stored for environment") {
                    testContext.withCached(userCount: LDConfig.Defaults.maxCachedUsers)
                    expect(testContext.subject.retrieveFeatureFlags(forUserWithKey: testContext.selectedUser, andMobileKey: "unknown")).to(beNil())
                }
            }
            it("returns the flags for user and environment") {
                testContext.withCached(userCount: LDConfig.Defaults.maxCachedUsers)
                let toRetrieve = testContext.userEnvironmentsCollection.randomElement()!.value.environmentFlags.randomElement()!.value
                expect(testContext.subject.retrieveFeatureFlags(forUserWithKey: toRetrieve.userKey, andMobileKey: toRetrieve.mobileKey)) == toRetrieve.featureFlags
            }
        }
    }
    
    private func storeUnlimitedUsersSpec() {
        describe("storeFeatureFlags with no cached limit") {
            FlagCachingStoreMode.allCases.forEach { storeMode in
                it("and a new users flags are stored") {
                    var testContext = TestContext(maxUsers: -1, storeMode: storeMode)
                    testContext.withCached(userCount: LDConfig.Defaults.maxCachedUsers)
                    let expectedEnv = testContext.storeNewUser()

                    expect(testContext.setUserEnvironments?.count) == LDConfig.Defaults.maxCachedUsers + 1
                    expect(testContext.setUserEnvironments?[expectedEnv.userKey]) == expectedEnv
                    testContext.userEnvironmentsCollection.forEach { userKey, userEnv in
                        expect(testContext.setUserEnvironments?[userKey]) == userEnv
                    }
                }
            }
        }
    }

    private func storeFeatureFlagsSpec(maxUsers: Int) {
        FlagCachingStoreMode.allCases.forEach { storeMode in
            storeFeatureFlagsSpec(maxUsers: maxUsers, storeMode: storeMode)
        }
    }

    private func storeFeatureFlagsSpec(maxUsers: Int, storeMode: FlagCachingStoreMode) {
        var testContext: TestContext!
        describe(storeMode == .async ? "storeFeatureFlagsAsync" : "storeFeatureFlagsSync") {
            beforeEach {
                testContext = TestContext(maxUsers: maxUsers, storeMode: storeMode)
            }
            it("when store is empty") {
                let expectedEnv = testContext.storeNewUser()

                expect(testContext.setUserEnvironments?.count) == 1
                expect(testContext.setUserEnvironments?[expectedEnv.userKey]) == expectedEnv
            }
            context("when less than the max number of users flags are stored") {
                it("and an existing users flags are changed") {
                    testContext.withCached(userCount: maxUsers - 1)
                    let expectedEnv = testContext.storeUserEnvUpdate(userKey: testContext.selectedUser, mobileKey: testContext.selectedMobileKey)

                    expect(testContext.setUserEnvironments?.count) == maxUsers - 1
                    testContext.userEnvironmentsCollection.forEach { userKey, userEnv in
                        if userKey != expectedEnv.userKey {
                            expect(testContext.setUserEnvironments?[userKey]) == userEnv
                            return
                        }

                        var userFlags = userEnv.environmentFlags
                        userFlags[expectedEnv.mobileKey] = expectedEnv
                        expect(testContext.setUserEnvironments?[userKey]) == CacheableUserEnvironmentFlags(userKey: userKey, environmentFlags: userFlags, lastUpdated: TestValues.lastUpdated)
                    }
                }
                it("and an existing user adds a new environment") {
                    testContext.withCached(userCount: maxUsers - 1)
                    let expectedEnv = testContext.storeNewUserEnv(userKey: testContext.selectedUser)

                    expect(testContext.setUserEnvironments?.count) == maxUsers - 1
                    testContext.userEnvironmentsCollection.forEach { userKey, userEnv in
                        if userKey != expectedEnv.userKey {
                            expect(testContext.setUserEnvironments?[userKey]) == userEnv
                            return
                        }

                        var userFlags = userEnv.environmentFlags
                        userFlags[expectedEnv.mobileKey] = expectedEnv
                        expect(testContext.setUserEnvironments?[userKey]) == CacheableUserEnvironmentFlags(userKey: userKey, environmentFlags: userFlags, lastUpdated: TestValues.lastUpdated)
                    }
                }
                it("and a new users flags are stored") {
                    testContext.withCached(userCount: maxUsers - 1)
                    let expectedEnv = testContext.storeNewUser()

                    expect(testContext.setUserEnvironments?.count) == maxUsers
                    expect(testContext.setUserEnvironments?[expectedEnv.userKey]) == expectedEnv
                    testContext.userEnvironmentsCollection.forEach { userKey, userEnv in
                        expect(testContext.setUserEnvironments?[userKey]) == userEnv
                    }
                }
            }
            context("when max number of users flags are stored") {
                it("and an existing users flags are changed") {
                    testContext.withCached(userCount: maxUsers)
                    let expectedEnv = testContext.storeUserEnvUpdate(userKey: testContext.selectedUser, mobileKey: testContext.selectedMobileKey)

                    expect(testContext.setUserEnvironments?.count) == maxUsers
                    testContext.userEnvironmentsCollection.forEach { userKey, userEnv in
                        if userKey != expectedEnv.userKey {
                            expect(testContext.setUserEnvironments?[userKey]) == userEnv
                            return
                        }

                        var userFlags = userEnv.environmentFlags
                        userFlags[expectedEnv.mobileKey] = expectedEnv
                        expect(testContext.setUserEnvironments?[userKey]) == CacheableUserEnvironmentFlags(userKey: userKey, environmentFlags: userFlags, lastUpdated: TestValues.lastUpdated)
                    }
                }
                it("and an existing user adds a new environment") {
                    testContext.withCached(userCount: maxUsers)
                    let expectedEnv = testContext.storeNewUserEnv(userKey: testContext.selectedUser)

                    expect(testContext.setUserEnvironments?.count) == maxUsers
                    testContext.userEnvironmentsCollection.forEach { userKey, userEnv in
                        if userKey != expectedEnv.userKey {
                            expect(testContext.setUserEnvironments?[userKey]) == userEnv
                            return
                        }

                        var userFlags = userEnv.environmentFlags
                        userFlags[expectedEnv.mobileKey] = expectedEnv
                        expect(testContext.setUserEnvironments?[userKey]) == CacheableUserEnvironmentFlags(userKey: userKey, environmentFlags: userFlags, lastUpdated: TestValues.lastUpdated)
                    }
                }
                it("and a new users flags are stored overwrites oldest user") {
                    testContext.withCached(userCount: maxUsers)
                    let expectedEnv = testContext.storeNewUser()

                    expect(testContext.setUserEnvironments?.count) == maxUsers
                    expect(testContext.setUserEnvironments?.keys.contains(testContext.oldestUser)) == false
                    expect(testContext.setUserEnvironments?[expectedEnv.userKey]) == expectedEnv
                    testContext.userEnvironmentsCollection.forEach { userKey, userEnv in
                        guard userKey != testContext.oldestUser
                        else { return }
                        expect(testContext.setUserEnvironments?[userKey]) == userEnv
                    }
                }
            }
        }
    }
}

extension CacheableUserEnvironmentFlags: Equatable {
    public static func == (lhs: CacheableUserEnvironmentFlags, rhs: CacheableUserEnvironmentFlags) -> Bool {
        lhs.userKey == rhs.userKey &&
            lhs.lastUpdated == rhs.lastUpdated &&
            lhs.environmentFlags == rhs.environmentFlags
    }
}

private extension FeatureFlag {
    static func stub(flagKey: LDFlagKey, flagValue: Any?) -> FeatureFlag {
        FeatureFlag(flagKey: flagKey,
                    value: flagValue,
                    variation: DarklyServiceMock.Constants.variation,
                    version: DarklyServiceMock.Constants.version,
                    flagVersion: DarklyServiceMock.Constants.flagVersion,
                    trackEvents: true,
                    debugEventsUntilDate: Date().addingTimeInterval(30.0),
                    reason: DarklyServiceMock.Constants.reason,
                    trackReason: false)
    }
}
