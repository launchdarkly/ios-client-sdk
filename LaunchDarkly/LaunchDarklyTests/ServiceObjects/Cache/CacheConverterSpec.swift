//
//  CacheConverterSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class CacheConverterSpec: QuickSpec {

    struct Constants {
        static let maxAgeAlternate: TimeInterval = -1
        static let acceptableInterval: TimeInterval = 0.05
    }

    struct TestContext {
        var clientServiceFactoryMock = ClientServiceMockFactory()
        var cacheConverter: CacheConverter
        var user: LDUser
        var config: LDConfig
        var featureFlagCachingMock: FeatureFlagCachingMock {
            clientServiceFactoryMock.makeFeatureFlagCacheReturnValue
        }
        var expiredCacheThreshold: Date
        var modelsToSearch = [DeprecatedCacheModel]()

        init(maxAge: TimeInterval? = nil, createCacheData: Bool = false, deprecatedCacheData: DeprecatedCacheModel? = nil) {
            if let maxAge = maxAge {
                cacheConverter = CacheConverter(serviceFactory: clientServiceFactoryMock, maxCachedUsers: LDConfig.Defaults.maxCachedUsers, maxAge: maxAge)
            } else {
                cacheConverter = CacheConverter(serviceFactory: clientServiceFactoryMock, maxCachedUsers: LDConfig.Defaults.maxCachedUsers)
            }
            expiredCacheThreshold = Date().addingTimeInterval(maxAge ?? CacheConverter.Constants.maxAge)
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
                let age = Date().addingTimeInterval(cacheConverter.maxAge + 1.0)
                deprecatedCacheMock(for: deprecatedCacheData).retrieveFlagsReturnValue = (user.flagStore.featureFlags, age)
                switch deprecatedCacheData {
                case .version5:
                    modelsToSearch.append(contentsOf: [.version5])
                case .version4:
                    modelsToSearch.append(contentsOf: [.version5, .version4])
                case .version3:
                    modelsToSearch.append(contentsOf: [.version5, .version4, .version3])
                case .version2:
                    modelsToSearch.append(contentsOf: DeprecatedCacheModel.allCases)
                }
            }
            if createCacheData {
                modelsToSearch.removeAll()
            }
        }

        func deprecatedCacheMock(for version: DeprecatedCacheModel) -> DeprecatedCacheMock {
            cacheConverter.deprecatedCaches[version] as! DeprecatedCacheMock
        }

        func expectedretrieveFlagsCallCount(for model: DeprecatedCacheModel) -> Int {
            modelsToSearch.contains(model) ? 1 : 0
        }
    }

    override func spec() {
        initSpec()
        convertCacheDataSpec()
    }

    private func initSpec() {
        var testContext: TestContext!
        describe("init") {
            context("with maxAge") {
                beforeEach {
                    testContext = TestContext(maxAge: Constants.maxAgeAlternate)
                }
                it("creates a cache converter with the specified maxAge") {
                    expect(testContext.cacheConverter.maxAge) == Constants.maxAgeAlternate
                    expect(testContext.clientServiceFactoryMock.makeFeatureFlagCacheCallCount) == 1
                    expect(testContext.cacheConverter.currentCache) === testContext.clientServiceFactoryMock.makeFeatureFlagCacheReturnValue
                    DeprecatedCacheModel.allCases.forEach { deprecatedCacheModel in
                        expect(testContext.cacheConverter.deprecatedCaches[deprecatedCacheModel]).toNot(beNil())
                        expect(testContext.clientServiceFactoryMock.makeDeprecatedCacheModelReceivedModels.contains(deprecatedCacheModel)) == true
                    }
                }
            }
            context("without maxAge") {
                beforeEach {
                    testContext = TestContext(maxAge: nil)
                }
                it("creates a cache converter with the default maxAge") {
                    expect(testContext.cacheConverter.maxAge) == CacheConverter.Constants.maxAge
                    expect(testContext.clientServiceFactoryMock.makeFeatureFlagCacheCallCount) == 1
                    expect(testContext.cacheConverter.currentCache) === testContext.clientServiceFactoryMock.makeFeatureFlagCacheReturnValue
                    DeprecatedCacheModel.allCases.forEach { deprecatedCacheModel in
                        expect(testContext.cacheConverter.deprecatedCaches[deprecatedCacheModel]).toNot(beNil())
                        expect(testContext.clientServiceFactoryMock.makeDeprecatedCacheModelReceivedModels.contains(deprecatedCacheModel)) == true
                    }
                }
            }
        }
    }

    private func convertCacheDataSpec() {
        var testContext: TestContext!
        describe("convertCacheData") {
            context("current cache data exists") {
                context("deprecated cache data does not exist") {
                    beforeEach {
                        testContext = TestContext(maxAge: Constants.maxAgeAlternate, createCacheData: true, deprecatedCacheData: nil)

                        testContext.cacheConverter.convertCacheData(for: testContext.user, and: testContext.config)
                    }
                    it("does not look in the deprecated caches for data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).retrieveFlagsCallCount) == 0
                        }
                    }
                    it("leaves the current cache data unchanged") {
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 0
                    }
                    it("removes expired deprecated cache data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).removeDataCallCount) == 1
                            expect(testContext.deprecatedCacheMock(for: model).removeDataReceivedExpirationDate?
                                .isWithin(Constants.acceptableInterval, of: testContext.expiredCacheThreshold)) == true
                        }
                    }
                }
                context("deprecated version 5 cache data exists") {
                    beforeEach {
                        testContext = TestContext(maxAge: Constants.maxAgeAlternate, createCacheData: true, deprecatedCacheData: .version5)

                        testContext.cacheConverter.convertCacheData(for: testContext.user, and: testContext.config)
                    }
                    it("does not look in the deprecated caches for data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).retrieveFlagsCallCount) == 0
                        }
                    }
                    it("leaves the current cache data unchanged") {
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 0
                    }
                    it("removes expired deprecated cache data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).removeDataCallCount) == 1
                            expect(testContext.deprecatedCacheMock(for: model).removeDataReceivedExpirationDate?
                                .isWithin(Constants.acceptableInterval, of: testContext.expiredCacheThreshold)) == true
                        }
                    }
                }
                context("deprecated version 4 cache data exists") {
                    beforeEach {
                        testContext = TestContext(maxAge: Constants.maxAgeAlternate, createCacheData: true, deprecatedCacheData: .version4)

                        testContext.cacheConverter.convertCacheData(for: testContext.user, and: testContext.config)
                    }
                    it("does not look in the deprecated caches for data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).retrieveFlagsCallCount) == 0
                        }
                    }
                    it("leaves the current cache data unchanged") {
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 0
                    }
                    it("removes expired deprecated cache data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).removeDataCallCount) == 1
                            expect(testContext.deprecatedCacheMock(for: model).removeDataReceivedExpirationDate?
                                .isWithin(Constants.acceptableInterval, of: testContext.expiredCacheThreshold)) == true
                        }
                    }
                }
                context("deprecated version 3 cache data exists") {
                    beforeEach {
                        testContext = TestContext(maxAge: Constants.maxAgeAlternate, createCacheData: true, deprecatedCacheData: .version3)

                        testContext.cacheConverter.convertCacheData(for: testContext.user, and: testContext.config)
                    }
                    it("does not look in the deprecated caches for data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).retrieveFlagsCallCount) == 0
                        }
                    }
                    it("leaves the current cache data unchanged") {
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 0
                    }
                    it("removes expired deprecated cache data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).removeDataCallCount) == 1
                            expect(testContext.deprecatedCacheMock(for: model).removeDataReceivedExpirationDate?
                                .isWithin(Constants.acceptableInterval, of: testContext.expiredCacheThreshold)) == true
                        }
                    }
                }

                context("deprecated version 2 cache data exists") {
                    beforeEach {
                        testContext = TestContext(maxAge: Constants.maxAgeAlternate, createCacheData: true, deprecatedCacheData: .version2)

                        testContext.cacheConverter.convertCacheData(for: testContext.user, and: testContext.config)
                    }
                    it("does not look in the deprecated caches for data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).retrieveFlagsCallCount) == 0
                        }
                    }
                    it("leaves the current cache data unchanged") {
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 0
                    }
                    it("removes expired deprecated cache data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).removeDataCallCount) == 1
                            expect(testContext.deprecatedCacheMock(for: model).removeDataReceivedExpirationDate?
                                .isWithin(Constants.acceptableInterval, of: testContext.expiredCacheThreshold)) == true
                        }
                    }
                }
            }
            context("current cache data does not exist") {
                context("deprecated cache data does not exist") {
                    beforeEach {
                        testContext = TestContext(maxAge: Constants.maxAgeAlternate, createCacheData: false, deprecatedCacheData: nil)

                        testContext.cacheConverter.convertCacheData(for: testContext.user, and: testContext.config)
                    }
                    it("looks in the deprecated caches for data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).retrieveFlagsCallCount) == 1
                        }
                    }
                    it("leaves the current cache data unchanged") {
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 0
                    }
                    it("removes expired deprecated cache data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).removeDataCallCount) == 1
                            expect(testContext.deprecatedCacheMock(for: model).removeDataReceivedExpirationDate?
                                .isWithin(Constants.acceptableInterval, of: testContext.expiredCacheThreshold)) == true
                        }
                    }
                }
                context("deprecated version 5 cache data exists") {
                    beforeEach {
                        testContext = TestContext(maxAge: Constants.maxAgeAlternate, createCacheData: false, deprecatedCacheData: .version5)

                        testContext.cacheConverter.convertCacheData(for: testContext.user, and: testContext.config)
                    }
                    it("looks in the version 5 cache for data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).retrieveFlagsCallCount) == testContext.expectedretrieveFlagsCallCount(for: model)
                        }
                    }
                    it("creates current cache data from the deprecated version 5 cache data") {
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 1
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.featureFlags) ==
                            testContext.deprecatedCacheMock(for: .version5).retrieveFlagsReturnValue?.featureFlags
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.user) == testContext.user
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated) ==
                            testContext.deprecatedCacheMock(for: .version5).retrieveFlagsReturnValue?.lastUpdated
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .sync
                    }
                    it("removes expired deprecated cache data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).removeDataCallCount) == 1
                            expect(testContext.deprecatedCacheMock(for: model).removeDataReceivedExpirationDate?
                                .isWithin(Constants.acceptableInterval, of: testContext.expiredCacheThreshold)) == true
                        }
                    }
                }
                context("deprecated version 4 cache data exists") {
                    beforeEach {
                        testContext = TestContext(maxAge: Constants.maxAgeAlternate, createCacheData: false, deprecatedCacheData: .version4)

                        testContext.cacheConverter.convertCacheData(for: testContext.user, and: testContext.config)
                    }
                    it("looks in the versions 5 and 4 caches for data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).retrieveFlagsCallCount) == testContext.expectedretrieveFlagsCallCount(for: model)
                        }
                    }
                    it("creates current cache data from the deprecated version 4 cache data") {
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 1
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.featureFlags) ==
                            testContext.deprecatedCacheMock(for: .version4).retrieveFlagsReturnValue?.featureFlags
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.user) == testContext.user
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated) ==
                            testContext.deprecatedCacheMock(for: .version4).retrieveFlagsReturnValue?.lastUpdated
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .sync
                    }
                    it("removes expired deprecated cache data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).removeDataCallCount) == 1
                            expect(testContext.deprecatedCacheMock(for: model).removeDataReceivedExpirationDate?
                                .isWithin(Constants.acceptableInterval, of: testContext.expiredCacheThreshold)) == true
                        }
                    }
                }
                context("deprecated version 3 cache data exists") {
                    beforeEach {
                        testContext = TestContext(maxAge: Constants.maxAgeAlternate, createCacheData: false, deprecatedCacheData: .version3)

                        testContext.cacheConverter.convertCacheData(for: testContext.user, and: testContext.config)
                    }
                    it("looks in the versions 5, 4, and 3 caches for data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).retrieveFlagsCallCount) == testContext.expectedretrieveFlagsCallCount(for: model)
                        }
                    }
                    it("creates current cache data from the deprecated version 3 cache data") {
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 1
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.featureFlags) ==
                            testContext.deprecatedCacheMock(for: .version3).retrieveFlagsReturnValue?.featureFlags
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.user) == testContext.user
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated) ==
                            testContext.deprecatedCacheMock(for: .version3).retrieveFlagsReturnValue?.lastUpdated
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .sync
                    }
                    it("removes expired deprecated cache data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).removeDataCallCount) == 1
                            expect(testContext.deprecatedCacheMock(for: model).removeDataReceivedExpirationDate?
                                .isWithin(Constants.acceptableInterval, of: testContext.expiredCacheThreshold)) == true
                        }
                    }
                }
                context("deprecated version 2 cache data exists") {
                    beforeEach {
                        testContext = TestContext(maxAge: Constants.maxAgeAlternate, createCacheData: false, deprecatedCacheData: .version2)

                        testContext.cacheConverter.convertCacheData(for: testContext.user, and: testContext.config)
                    }
                    it("looks in the deprecated caches for data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).retrieveFlagsCallCount) == 1
                        }
                    }
                    it("creates current cache data from the deprecated version 2 cache data") {
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsCallCount) == 1
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.featureFlags) ==
                            testContext.deprecatedCacheMock(for: .version2).retrieveFlagsReturnValue?.featureFlags
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.user) == testContext.user
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.mobileKey) == testContext.config.mobileKey
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.lastUpdated) ==
                            testContext.deprecatedCacheMock(for: .version2).retrieveFlagsReturnValue?.lastUpdated
                        expect(testContext.featureFlagCachingMock.storeFeatureFlagsReceivedArguments?.storeMode) == .sync
                    }
                    it("removes expired deprecated cache data") {
                        DeprecatedCacheModel.allCases.forEach { model in
                            expect(testContext.deprecatedCacheMock(for: model).removeDataCallCount) == 1
                            expect(testContext.deprecatedCacheMock(for: model).removeDataReceivedExpirationDate?
                                .isWithin(Constants.acceptableInterval, of: testContext.expiredCacheThreshold)) == true
                        }
                    }
                }
            }
        }
    }
}
