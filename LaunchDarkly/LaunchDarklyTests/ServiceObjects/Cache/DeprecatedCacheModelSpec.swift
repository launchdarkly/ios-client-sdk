import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

protocol CacheModelTestInterface {
    var cacheKey: String { get }
    func createDeprecatedCache(keyedValueCache: KeyedValueCaching) -> DeprecatedCache
    func modelDictionary(for users: [LDUser], and userEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags], mobileKeys: [MobileKey]) -> [UserKey: Any]?
    func expectedFeatureFlags(originalFlags: [LDFlagKey: FeatureFlag]) -> [LDFlagKey: FeatureFlag]
}

class DeprecatedCacheModelSpec {

    let cacheModelInterface: CacheModelTestInterface

    struct Constants {
        static let offsetInterval: TimeInterval = 0.1
    }

    struct TestContext {
        let cacheModel: CacheModelTestInterface
        var keyedValueCacheMock = KeyedValueCachingMock()
        var deprecatedCache: DeprecatedCache
        var users: [LDUser]
        var userEnvironmentsCollection: [UserKey: CacheableUserEnvironmentFlags]
        var mobileKeys: [MobileKey]
        var sortedLastUpdatedDates: [(userKey: UserKey, lastUpdated: Date)] {
            userEnvironmentsCollection.map { ($0, $1.lastUpdated) }.sorted { tuple1, tuple2 in
                tuple1.lastUpdated.isEarlierThan(tuple2.lastUpdated)
            }
        }
        var userKeys: [UserKey] { users.map { $0.key } }

        init(_ cacheModel: CacheModelTestInterface, userCount: Int = 0) {
            self.cacheModel = cacheModel
            deprecatedCache = cacheModel.createDeprecatedCache(keyedValueCache: keyedValueCacheMock)
            (users, userEnvironmentsCollection, mobileKeys) = CacheableUserEnvironmentFlags.stubCollection(userCount: userCount)
            keyedValueCacheMock.dictionaryReturnValue = cacheModel.modelDictionary(for: users, and: userEnvironmentsCollection, mobileKeys: mobileKeys)
        }

        func featureFlags(for userKey: UserKey, and mobileKey: MobileKey) -> [LDFlagKey: FeatureFlag]? {
            guard let originalFlags = userEnvironmentsCollection[userKey]?.environmentFlags[mobileKey]?.featureFlags
            else { return nil }
            return cacheModel.expectedFeatureFlags(originalFlags: originalFlags)
        }

        func expiredUserKeys(for expirationDate: Date) -> [UserKey] {
            sortedLastUpdatedDates.compactMap { tuple in
                tuple.lastUpdated.isEarlierThan(expirationDate) ? tuple.userKey : nil
            }
        }
    }

    init(cacheModelInterface: CacheModelTestInterface) {
        self.cacheModelInterface = cacheModelInterface
    }

    func spec() {
        initSpec()
        retrieveFlagsSpec()
        removeDataSpec()
    }

    private func initSpec() {
        var testContext: TestContext!
        describe("init") {
            it("creates cache with the keyed value cache") {
                testContext = TestContext(self.cacheModelInterface)
                expect(testContext.deprecatedCache.keyedValueCache) === testContext.keyedValueCacheMock
            }
        }
    }

    private func retrieveFlagsSpec() {
        var testContext: TestContext!
        var cachedData: (featureFlags: [LDFlagKey: FeatureFlag]?, lastUpdated: Date?)!
        describe("retrieveFlags") {
            it("returns nil when no cached data exists") {
                testContext = TestContext(self.cacheModelInterface)
                cachedData = testContext.deprecatedCache.retrieveFlags(for: UUID().uuidString, and: UUID().uuidString)
                expect(cachedData.featureFlags).to(beNil())
                expect(cachedData.lastUpdated).to(beNil())
            }
            context("when cached data exists") {
                it("retrieves cached user") {
                    testContext = TestContext(self.cacheModelInterface, userCount: LDConfig.Defaults.maxCachedUsers)
                    testContext.users.forEach { user in
                        let expectedLastUpdated = testContext.userEnvironmentsCollection[user.key]?.lastUpdated.stringEquivalentDate
                        testContext.mobileKeys.forEach { mobileKey in
                            let expectedFlags = testContext.featureFlags(for: user.key, and: mobileKey)
                            cachedData = testContext.deprecatedCache.retrieveFlags(for: user.key, and: mobileKey)
                            expect(cachedData.featureFlags) == expectedFlags
                            expect(cachedData.lastUpdated) == expectedLastUpdated
                        }
                    }
                }
                it("returns nil for uncached environment") {
                    testContext = TestContext(self.cacheModelInterface, userCount: LDConfig.Defaults.maxCachedUsers)
                    cachedData = testContext.deprecatedCache.retrieveFlags(for: testContext.users.first!.key, and: UUID().uuidString)
                    expect(cachedData.featureFlags).to(beNil())
                    expect(cachedData.lastUpdated).to(beNil())
                }
                it("returns nil for uncached user") {
                    testContext = TestContext(self.cacheModelInterface, userCount: LDConfig.Defaults.maxCachedUsers)
                    cachedData = testContext.deprecatedCache.retrieveFlags(for: UUID().uuidString, and: testContext.mobileKeys.first!)
                    expect(cachedData.featureFlags).to(beNil())
                    expect(cachedData.lastUpdated).to(beNil())
                }
            }
        }
    }

    private func removeDataSpec() {
        var testContext: TestContext!
        var expirationDate: Date!
        describe("removeData") {
            it("no cached data expired") {
                testContext = TestContext(self.cacheModelInterface, userCount: LDConfig.Defaults.maxCachedUsers)
                let oldestLastUpdatedDate = testContext.sortedLastUpdatedDates.first!
                expirationDate = oldestLastUpdatedDate.lastUpdated.addingTimeInterval(-Constants.offsetInterval)

                testContext.deprecatedCache.removeData(olderThan: expirationDate)
                expect(testContext.keyedValueCacheMock.setCallCount) == 0
            }
            it("some cached data expired") {
                testContext = TestContext(self.cacheModelInterface, userCount: LDConfig.Defaults.maxCachedUsers)
                let selectedLastUpdatedDate = testContext.sortedLastUpdatedDates[testContext.users.count / 2]
                expirationDate = selectedLastUpdatedDate.lastUpdated.addingTimeInterval(-Constants.offsetInterval)

                testContext.deprecatedCache.removeData(olderThan: expirationDate)
                expect(testContext.keyedValueCacheMock.setCallCount) == 1
                expect(testContext.keyedValueCacheMock.setReceivedArguments?.forKey) == self.cacheModelInterface.cacheKey
                let recachedData = testContext.keyedValueCacheMock.setReceivedArguments?.value as? [String: Any]
                let expiredUserKeys = testContext.expiredUserKeys(for: expirationDate)
                testContext.userKeys.forEach { userKey in
                    expect(recachedData?.keys.contains(userKey)) == !expiredUserKeys.contains(userKey)
                }
            }
            it("all cached data expired") {
                testContext = TestContext(self.cacheModelInterface, userCount: LDConfig.Defaults.maxCachedUsers)
                let newestLastUpdatedDate = testContext.sortedLastUpdatedDates.last!
                expirationDate = newestLastUpdatedDate.lastUpdated.addingTimeInterval(Constants.offsetInterval)

                testContext.deprecatedCache.removeData(olderThan: expirationDate)
                expect(testContext.keyedValueCacheMock.removeObjectCallCount) == 1
                expect(testContext.keyedValueCacheMock.removeObjectReceivedForKey) == self.cacheModelInterface.cacheKey
            }
            it("no cached data") {
                let testContext = TestContext(self.cacheModelInterface)
                testContext.keyedValueCacheMock.dictionaryReturnValue = nil
                testContext.deprecatedCache.removeData(olderThan: Date())
                expect(testContext.keyedValueCacheMock.setCallCount) == 0
            }
        }
    }
}
