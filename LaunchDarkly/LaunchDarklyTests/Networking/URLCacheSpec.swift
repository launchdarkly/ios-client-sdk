//
//  URLCache.swift
//  LaunchDarklyTests
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
import OHHTTPStubs
@testable import LaunchDarkly

// Normally we would not build an AT for system provided services, like URLCache. The SDK uses the URLCache in a non-standard way, sending HTTP requests with a custom verb REPORT. So building this test validates that the URLCache behaves as expected for GET and REPORT requests. Retaining these tests helps provide that assurance through future revisions.
final class URLCacheSpec: QuickSpec {

    struct Constants {
        static let userCount = 3
        static let useReportMethod = true
        static let useGetMethod = false
    }

    struct TestContext {
        var config: LDConfig
        var serviceFactoryMock: ClientServiceMockFactory
        var flagStore: FlagMaintaining

        // per user
        var userServiceObjects = [String: (user: LDUser, service: DarklyService, serviceMock: DarklyServiceMock)]()
        var userKeys: Dictionary<String, (user: LDUser, service: DarklyService, serviceMock: DarklyServiceMock)>.Keys {
            userServiceObjects.keys
        }

        init(userCount: Int = 1, useReport: Bool = false) {
            config = LDConfig.stub
            config.useReport = useReport

            flagStore = FlagStore(featureFlagDictionary: FlagMaintainingMock.stubFlags())

            serviceFactoryMock = ClientServiceMockFactory()

            while userServiceObjects.count < userCount {
                let user = LDUser.stub()
                let service = DarklyService(config: config, user: user, serviceFactory: serviceFactoryMock)
                let serviceMock = DarklyServiceMock(config: config, user: user)
                userServiceObjects[user.key] = (user, service, serviceMock)
            }
        }

        func user(for key: String) -> LDUser? {
            userServiceObjects[key]?.user
        }

        func service(for key: String) -> DarklyService? {
            userServiceObjects[key]?.service
        }

        func serviceMock(for key: String) -> DarklyServiceMock? {
            userServiceObjects[key]?.serviceMock
        }
    }

    override func spec() {
        cacheReportRequestSpec()
    }

    private func cacheReportRequestSpec() {
        var testContext: TestContext!

        describe("storeCachedResponse") {
            context("when flag request uses the get method") {
                var urlRequests = [String: URLRequest]()
                beforeEach {
                    testContext = TestContext(userCount: Constants.userCount, useReport: Constants.useGetMethod)
                    for userKey in testContext.userKeys {
                        guard let service = testContext.service(for: userKey),
                            let serviceMock = testContext.serviceMock(for: userKey)
                        else {
                            fail("test setup failed to create user service objects")
                            return
                        }
                        var urlRequest: URLRequest!
                        serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                    featureFlags: testContext.flagStore.featureFlags,
                                                    useReport: Constants.useGetMethod,
                                                    onActivation: { request, _, _ in
                                                        urlRequest = request
                        })
                        var serviceResponse: ServiceResponse!
                        waitUntil { done in
                            service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { response in
                                serviceResponse = response
                                done()
                            })
                        }
                        urlRequests[userKey] = urlRequest
                        URLCache.shared.storeResponse(serviceResponse, for: urlRequest)
                    }
                }
                it("caches the flag request response") {
                    for userKey in testContext.userKeys {
                        guard let urlRequest = urlRequests[userKey]
                        else {
                            fail("test setup failed to set user or urlRequest for user: \(userKey)")
                            return
                        }
                        expect(URLCache.shared.cachedResponse(for: urlRequest)?.flagCollection) == testContext.flagStore.featureFlags
                    }
                }
            }
            context("when flag request uses the report method") {
                var urlRequests = [String: URLRequest]()
                beforeEach {
                    testContext = TestContext(userCount: Constants.userCount, useReport: Constants.useReportMethod)
                    for userKey in testContext.userKeys {
                        guard let service = testContext.service(for: userKey),
                            let serviceMock = testContext.serviceMock(for: userKey)
                        else {
                            fail("test setup failed to create user service objects")
                            return
                        }
                        var urlRequest: URLRequest!
                        serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                    featureFlags: testContext.flagStore.featureFlags,
                                                    useReport: Constants.useReportMethod,
                                                    onActivation: { request, _, _ in
                                                        urlRequest = request
                        })
                        var serviceResponse: ServiceResponse!
                        waitUntil { done in
                            service.getFeatureFlags(useReport: Constants.useReportMethod, completion: { response in
                                serviceResponse = response
                                done()
                            })
                        }
                        urlRequests[userKey] = urlRequest
                        URLCache.shared.storeResponse(serviceResponse, for: urlRequest)
                    }
                }
                it("caches the flag request response") {
                    for userKey in testContext.userKeys {
                        guard let urlRequest = urlRequests[userKey]
                        else {
                            fail("test setup failed to set user or urlRequest for user: \(userKey)")
                            return
                        }
                        expect(URLCache.shared.cachedResponse(for: urlRequest)?.flagCollection) == testContext.flagStore.featureFlags
                    }
                }
            }
        }
    }
}

extension Data {
    var flagCollection: [LDFlagKey: FeatureFlag]? {
        guard let flagDictionary = try? JSONSerialization.jsonDictionary(with: self, options: .allowFragments)
        else { return nil }
        return flagDictionary.flagCollection
    }
}

extension CachedURLResponse {
    var flagCollection: [LDFlagKey: FeatureFlag]? {
        data.flagCollection
    }
}

extension URLCache {
    func storeResponse(_ serviceResponse: ServiceResponse?, for request: URLRequest?) {
        guard let urlResponse = serviceResponse?.urlResponse,
            let data = serviceResponse?.data,
            let request = request
        else { return }
        URLCache.shared.storeCachedResponse(CachedURLResponse(response: urlResponse, data: data), for: request)
    }

    func cachedResponse(for request: URLRequest?) -> CachedURLResponse? {
        guard let request = request
        else { return nil }
        return URLCache.shared.cachedResponse(for: request)
    }
}
