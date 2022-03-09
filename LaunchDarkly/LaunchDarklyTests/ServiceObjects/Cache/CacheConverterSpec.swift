import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class CacheConverterSpec: QuickSpec {
    struct TestContext {
        var clientServiceFactoryMock = ClientServiceMockFactory()
        var cacheConverter: CacheConverter
        var user: LDUser
        var config: LDConfig
        var featureFlagCachingMock: FeatureFlagCachingMock {
            clientServiceFactoryMock.makeFeatureFlagCacheReturnValue
        }
        var expiredCacheThreshold: Date

        init(createCacheData: Bool = false, deprecatedCacheData: DeprecatedCacheModel? = nil) {
            cacheConverter = CacheConverter(serviceFactory: clientServiceFactoryMock, maxCachedUsers: LDConfig.Defaults.maxCachedUsers)
            expiredCacheThreshold = Date().addingTimeInterval(CacheConverter.Constants.maxAge)
            if createCacheData {
                let (users, userEnvironmentFlagsCollection, mobileKeys) = CacheableUserEnvironmentFlags.stubCollection()
                user = users[users.count / 2]
                config = LDConfig(mobileKey: mobileKeys[mobileKeys.count / 2], environmentReporter: EnvironmentReportingMock())
                featureFlagCachingMock.retrieveFeatureFlagsReturnValue = userEnvironmentFlagsCollection[user.key]?.environmentFlags[config.mobileKey]?.featureFlags
            } else {
                user = LDUser.stub()
                config = LDConfig.stub
                featureFlagCachingMock.retrieveFeatureFlagsReturnValue = nil
            }
            DeprecatedCacheModel.allCases.forEach { model in
                deprecatedCacheMock(for: model).retrieveFlagsReturnValue = (nil, nil)
            }
            if let deprecatedCacheData = deprecatedCacheData {
                let age = Date().addingTimeInterval(CacheConverter.Constants.maxAge + 1.0)
                deprecatedCacheMock(for: deprecatedCacheData).retrieveFlagsReturnValue = (FlagMaintainingMock.stubFlags(), age)
            }
        }

        func deprecatedCacheMock(for version: DeprecatedCacheModel) -> DeprecatedCacheMock {
            cacheConverter.deprecatedCaches[version] as! DeprecatedCacheMock
        }
    }

    override func spec() {
        initSpec()
        convertCacheDataSpec()
    }

    private func initSpec() {
        var testContext: TestContext!
        describe("init") {
            it("creates a cache converter") {
                testContext = TestContext()
                expect(testContext.clientServiceFactoryMock.makeFeatureFlagCacheCallCount) == 1
                expect(testContext.cacheConverter.currentCache) === testContext.clientServiceFactoryMock.makeFeatureFlagCacheReturnValue
                DeprecatedCacheModel.allCases.forEach { deprecatedCacheModel in
                    expect(testContext.cacheConverter.deprecatedCaches[deprecatedCacheModel]).toNot(beNil())
                    expect(testContext.clientServiceFactoryMock.makeDeprecatedCacheModelReceivedModels.contains(deprecatedCacheModel)) == true
                }
            }
        }
    }

    private func convertCacheDataSpec() {
        let cacheCases: [DeprecatedCacheModel?] = [.version5, nil] // Nil for no deprecated cache
        var testContext: TestContext!
        describe("convertCacheData") {
            afterEach {
                // The CacheConverter should always remove all expired data
                DeprecatedCacheModel.allCases.forEach { model in
                    expect(testContext.deprecatedCacheMock(for: model).removeDataCallCount) == 1
                    expect(testContext.deprecatedCacheMock(for: model).removeDataReceivedExpirationDate?
                            .isWithin(0.5, of: testContext.expiredCacheThreshold)) == true
                }
            }
            for deprecatedData in cacheCases {
                context("current cache and \(deprecatedData?.rawValue ?? "no") deprecated cache data exists") {
                    it("does not load from deprecated caches") {
                        testContext = TestContext(createCacheData: true, deprecatedCacheData: deprecatedData)
                        testContext.cacheConverter.convertCacheData(for: testContext.user, and: testContext.config)
                        DeprecatedCacheModel.allCases.forEach {
                            expect(testContext.deprecatedCacheMock(for: $0).retrieveFlagsCallCount) == 0
                        }
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 0
                    }
                }
                context("no current cache data and \(deprecatedData?.rawValue ?? "no") deprecated cache data exists") {
                    beforeEach {
                        testContext = TestContext(createCacheData: false, deprecatedCacheData: deprecatedData)
                        testContext.cacheConverter.convertCacheData(for: testContext.user, and: testContext.config)
                    }
                    it("looks in the deprecated caches for data") {
                        let searchUpTo = cacheCases.firstIndex(of: deprecatedData)!
                        DeprecatedCacheModel.allCases.forEach {
                            expect(testContext.deprecatedCacheMock(for: $0).retrieveFlagsCallCount) == (cacheCases.firstIndex(of: $0)! <= searchUpTo ? 1 : 0)
                        }
                    }
                    if let deprecatedData = deprecatedData {
                        it("creates current cache data from the deprecated cache data") {
                            expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 1
                            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.featureFlags) ==
                                testContext.deprecatedCacheMock(for: deprecatedData).retrieveFlagsReturnValue?.featureFlags
                            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.userKey) == testContext.user.key
                            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated) ==
                                testContext.deprecatedCacheMock(for: deprecatedData).retrieveFlagsReturnValue?.lastUpdated
                            expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .sync
                        }
                    } else {
                        it("leaves the current cache data unchanged") {
                            expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 0
                        }
                    }
                }
            }
        }
    }
}
