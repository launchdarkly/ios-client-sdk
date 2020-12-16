//
//  DarklyServiceSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
import OHHTTPStubs
import LDSwiftEventSource
@testable import LaunchDarkly

final class DarklyServiceSpec: QuickSpec {
    
    typealias ServiceResponses = (data: Data?, urlResponse: URLResponse?, error: Error?)
    
    struct Constants {
        static let eventCount = 3
        static let mobileKeyCount = 3

        static let emptyMobileKey = ""

        static let useGetMethod = false
        static let useReportMethod = true
    }

    struct TestContext {
        let user = LDUser.stub()
        var config: LDConfig!
        let mockEventDictionaries: [[String: Any]]?
        var serviceMock: DarklyServiceMock!
        var serviceFactoryMock: ClientServiceMockFactory? {
            service.serviceFactory as? ClientServiceMockFactory
        }
        var service: DarklyService!
        var flagRequestEtag: String?
        var flagRequestEtags = [String: String]()
        var httpHeaders: HTTPHeaders
        var flagStore: FlagMaintaining

        init(mobileKey: String = LDConfig.Constants.mockMobileKey,
             useReport: Bool = Constants.useGetMethod,
             includeMockEventDictionaries: Bool = false,
             operatingSystemName: String? = nil,
             flagRequestEtag: String? = nil,
             mobileKeyCount: Int = 0,
             diagnosticOptOut: Bool = false) {

            let serviceFactoryMock = ClientServiceMockFactory()
            if let operatingSystemName = operatingSystemName {
                serviceFactoryMock.makeEnvironmentReporterReturnValue.systemName = operatingSystemName
            }
            flagStore = FlagStore(featureFlagDictionary: FlagMaintainingMock.stubFlags())
            config = LDConfig.stub(mobileKey: mobileKey, environmentReporter: EnvironmentReportingMock())
            config.useReport = useReport
            config.diagnosticOptOut = diagnosticOptOut
            mockEventDictionaries = includeMockEventDictionaries ? Event.stubEventDictionaries(Constants.eventCount, user: user, config: config) : nil
            serviceMock = DarklyServiceMock(config: config)
            service = DarklyService(config: config, user: user, serviceFactory: serviceFactoryMock)
            httpHeaders = HTTPHeaders(config: config, environmentReporter: config.environmentReporter)
            self.flagRequestEtag = flagRequestEtag
            if let etag = flagRequestEtag {
                HTTPHeaders.setFlagRequestEtag(etag, for: mobileKey)
            }
            while flagRequestEtags.count < mobileKeyCount {
                if flagRequestEtags.isEmpty {
                    flagRequestEtags[mobileKey] = flagRequestEtag ?? UUID().uuidString
                } else {
                    flagRequestEtags[UUID().uuidString] = UUID().uuidString
                }
            }
        }
    }
    
    override func spec() {
        getFeatureFlagsSpec()
        flagRequestEtagSpec()
        clearFlagRequestCacheSpec()
        createEventSourceSpec()
        publishEventDictionariesSpec()
        diagnosticCacheSpec()
        publishDiagnosticSpec()

        afterEach {
            HTTPStubs.removeAllStubs()
            HTTPHeaders.removeFlagRequestEtags()
        }
    }

    private func getFeatureFlagsSpec() {
        var testContext: TestContext!

        describe("getFeatureFlags") {
            var responses: ServiceResponses?
            var getRequestCount = 0
            var reportRequestCount = 0
            var urlRequest: URLRequest?
            beforeEach {
                (responses, getRequestCount, reportRequestCount, urlRequest) = (nil, 0, 0, nil)
            }

            context("using GET method") {
                beforeEach {
                    testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: Constants.useGetMethod)
                }
                context("success") {
                    context("without flag request etag") {
                        beforeEach {
                            waitUntil { done in
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        featureFlags: testContext.flagStore.featureFlags,
                                                                        useReport: Constants.useReportMethod,
                                                                        onActivation: { _, _, _ in
                                                                            reportRequestCount += 1
                                })
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        featureFlags: testContext.flagStore.featureFlags,
                                                                        useReport: Constants.useGetMethod,
                                                                        onActivation: { request, _, _ in
                                                                            getRequestCount += 1
                                                                            urlRequest = request
                                })
                                testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { (data, response, error) in
                                    responses = (data, response, error)
                                    done()
                                })
                            }
                        }
                        it("makes exactly one valid GET request") {
                            expect(getRequestCount) == 1
                            expect(reportRequestCount) == 0
                        }
                        it("creates a GET request") {
                            //GET request url has the form https://<host>/msdk/evalx/users/<base64encodedUser>
                            expect(urlRequest?.url?.host) == testContext.config.baseUrl.host
                            if let path = urlRequest?.url?.path {
                                expect(path.hasPrefix("/\(DarklyService.FlagRequestPath.get)")).to(beTrue())
                                if let encodedUserString = urlRequest?.url?.lastPathComponent,
                                    let decodedUser = LDUser(base64urlEncodedString: encodedUserString) {
                                    expect(decodedUser.isEqual(to: testContext.user)) == true
                                } else {
                                    fail("encoded user string did not create a user")
                                }
                            } else {
                                fail("request path is missing")
                            }
                            expect(urlRequest?.cachePolicy) == .reloadIgnoringLocalCacheData
                            expect(urlRequest?.timeoutInterval) == testContext.config.connectionTimeout
                            expect(urlRequest?.httpMethod) == URLRequest.HTTPMethods.get
                            expect(urlRequest?.httpBody).to(beNil())
                            expect(urlRequest?.httpBodyStream).to(beNil())
                            guard let headers = urlRequest?.allHTTPHeaderFields
                            else {
                                fail("request is missing HTTP headers")
                                return
                            }
                            expect(headers[HTTPHeaders.HeaderKey.authorization]) == "\(HTTPHeaders.HeaderValue.apiKey) \(testContext.config.mobileKey)"
                            expect(headers[HTTPHeaders.HeaderKey.userAgent]) == "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)"
                            expect(headers[HTTPHeaders.HeaderKey.ifNoneMatch]).to(beNil())
                        }
                        it("calls completion with data, response, and no error") {
                            expect(responses).toNot(beNil())
                            expect(responses?.data).toNot(beNil())
                            expect(responses?.data?.flagCollection) == testContext.flagStore.featureFlags
                            expect(responses?.urlResponse?.httpStatusCode) == HTTPURLResponse.StatusCodes.ok
                            expect(responses?.error).to(beNil())
                        }
                    }
                    context("with flag request etag") {
                        beforeEach {
                            testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: Constants.useGetMethod, flagRequestEtag: UUID().uuidString)
                            waitUntil { done in
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        featureFlags: testContext.flagStore.featureFlags,
                                                                        useReport: Constants.useReportMethod,
                                                                        onActivation: { _, _, _ in
                                                                            reportRequestCount += 1
                                })
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        featureFlags: testContext.flagStore.featureFlags,
                                                                        useReport: Constants.useGetMethod,
                                                                        onActivation: { request, _, _ in
                                                                            getRequestCount += 1
                                                                            urlRequest = request
                                })
                                testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { (data, response, error) in
                                    responses = (data, response, error)
                                    done()
                                })
                            }
                        }
                        it("makes exactly one valid GET request") {
                            expect(getRequestCount) == 1
                            expect(reportRequestCount) == 0
                        }
                        it("creates a GET request") {
                            //GET request url has the form https://<host>/msdk/evalx/users/<base64encodedUser>
                            expect(urlRequest?.url?.host) == testContext.config.baseUrl.host
                            if let path = urlRequest?.url?.path {
                                expect(path.hasPrefix("/\(DarklyService.FlagRequestPath.get)")).to(beTrue())
                                if let encodedUserString = urlRequest?.url?.lastPathComponent,
                                    let decodedUser = LDUser(base64urlEncodedString: encodedUserString) {
                                    expect(decodedUser.isEqual(to: testContext.user)) == true
                                } else {
                                    fail("encoded user string did not create a user")
                                }
                            } else {
                                fail("request path is missing")
                            }
                            expect(urlRequest?.cachePolicy) == .reloadRevalidatingCacheData
                            expect(urlRequest?.timeoutInterval) == testContext.config.connectionTimeout
                            expect(urlRequest?.httpMethod) == URLRequest.HTTPMethods.get
                            expect(urlRequest?.httpBody).to(beNil())
                            expect(urlRequest?.httpBodyStream).to(beNil())
                            guard let headers = urlRequest?.allHTTPHeaderFields
                            else {
                                fail("request is missing HTTP headers")
                                return
                            }
                            expect(headers[HTTPHeaders.HeaderKey.authorization]) == "\(HTTPHeaders.HeaderValue.apiKey) \(testContext.config.mobileKey)"
                            expect(headers[HTTPHeaders.HeaderKey.userAgent]) == "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)"
                            expect(headers[HTTPHeaders.HeaderKey.ifNoneMatch]) == testContext.flagRequestEtag
                        }
                        it("calls completion with data, response, and no error") {
                            expect(responses).toNot(beNil())
                            expect(responses?.data).toNot(beNil())
                            expect(responses?.data?.flagCollection) == testContext.flagStore.featureFlags
                            expect(responses?.urlResponse?.httpStatusCode) == HTTPURLResponse.StatusCodes.ok
                            expect(responses?.error).to(beNil())
                        }
                    }
                }
                context("failure") {
                    beforeEach {
                        waitUntil { done in
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                                    useReport: Constants.useReportMethod,
                                                                    onActivation: { _, _, _ in
                                                                        reportRequestCount += 1
                            })
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                                    useReport: Constants.useGetMethod,
                                                                    onActivation: { _, _, _ in
                                                                        getRequestCount += 1
                            })
                            testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { (data, response, error) in
                                responses = (data, response, error)
                                done()
                            })
                        }
                    }
                    it("makes exactly one valid request") {
                        expect(getRequestCount) == 1
                        expect(reportRequestCount) == 0
                    }
                    it("calls completion with error and no data or response") {
                        expect(responses).toNot(beNil())
                        expect(responses?.data).toNot(beNil())
                        expect(responses?.data).to(beEmpty())
                        expect(responses?.urlResponse?.httpStatusCode) == HTTPURLResponse.StatusCodes.internalServerError
                        expect(responses?.error).to(beNil())
                    }
                }
                context("empty mobile key") {
                    beforeEach {
                        testContext = TestContext(mobileKey: Constants.emptyMobileKey, useReport: Constants.useGetMethod)
                        testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                useReport: Constants.useReportMethod,
                                                                onActivation: { _, _, _ in
                                                                    reportRequestCount += 1
                        })
                        testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                useReport: Constants.useGetMethod,
                                                                onActivation: { _, _, _ in
                            getRequestCount += 1
                        })
                        testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { (data, response, error) in
                            responses = (data, response, error)
                        })
                    }
                    it("does not make a request") {
                        expect(getRequestCount) == 0
                        expect(reportRequestCount) == 0
                        expect(responses).to(beNil())
                    }
                }
            }
            context("using REPORT method") {
                beforeEach {
                    testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: Constants.useReportMethod)
                }
                context("success") {
                    context("without a flag requesst etag") {
                        beforeEach {
                            waitUntil { done in
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        featureFlags: testContext.flagStore.featureFlags,
                                                                        useReport: Constants.useGetMethod,
                                                                        onActivation: { _, _, _ in
                                                                            getRequestCount += 1
                                })
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        featureFlags: testContext.flagStore.featureFlags,
                                                                        useReport: Constants.useReportMethod,
                                                                        onActivation: { request, _, _ in
                                                                            reportRequestCount += 1
                                                                            urlRequest = request
                                })
                                testContext.service.getFeatureFlags(useReport: Constants.useReportMethod, completion: { (data, response, error) in
                                    responses = (data, response, error)
                                    done()
                                })
                            }
                        }
                        it("makes exactly one valid REPORT request") {
                            expect(getRequestCount) == 0
                            expect(reportRequestCount) == 1
                        }
                        it("creates a REPORT request") {
                            //REPORT request url has the form https://<host>/msdk/evalx/user; httpBody contains the user dictionary
                            expect(urlRequest?.url?.host) == testContext.config.baseUrl.host
                            if let path = urlRequest?.url?.path {
                                expect(path.hasSuffix(DarklyService.FlagRequestPath.report)).to(beTrue())
                            } else {
                                fail("request path is missing")
                            }
                            expect(urlRequest?.cachePolicy) == .reloadIgnoringLocalCacheData
                            expect(urlRequest?.timeoutInterval) == testContext.config.connectionTimeout
                            expect(urlRequest?.httpMethod) == URLRequest.HTTPMethods.report
                            expect(urlRequest?.httpBodyStream).toNot(beNil())   //Although the service sets the httpBody, OHHTTPStubs seems to convert that into an InputStream, which should be ok
                            guard let headers = urlRequest?.allHTTPHeaderFields
                            else {
                                fail("request is missing HTTP headers")
                                return
                            }
                            expect(headers[HTTPHeaders.HeaderKey.authorization]) == "\(HTTPHeaders.HeaderValue.apiKey) \(testContext.config.mobileKey)"
                            expect(headers[HTTPHeaders.HeaderKey.userAgent]) == "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)"
                            expect(headers[HTTPHeaders.HeaderKey.ifNoneMatch]).to(beNil())
                        }
                        it("calls completion with data, response, and no error") {
                            expect(responses).toNot(beNil())
                            expect(responses?.data).toNot(beNil())
                            expect(responses?.data?.flagCollection) == testContext.flagStore.featureFlags
                            expect(responses?.urlResponse?.httpStatusCode) == HTTPURLResponse.StatusCodes.ok
                            expect(responses?.error).to(beNil())
                        }
                    }
                    context("with a flag requesst etag") {
                        beforeEach {
                            testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: Constants.useReportMethod, flagRequestEtag: UUID().uuidString)
                            waitUntil { done in
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        featureFlags: testContext.flagStore.featureFlags,
                                                                        useReport: Constants.useGetMethod,
                                                                        onActivation: { _, _, _ in
                                                                            getRequestCount += 1
                                })
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        featureFlags: testContext.flagStore.featureFlags,
                                                                        useReport: Constants.useReportMethod,
                                                                        onActivation: { request, _, _ in
                                                                            reportRequestCount += 1
                                                                            urlRequest = request
                                })
                                testContext.service.getFeatureFlags(useReport: Constants.useReportMethod, completion: { (data, response, error) in
                                    responses = (data, response, error)
                                    done()
                                })
                            }
                        }
                        it("makes exactly one valid REPORT request") {
                            expect(getRequestCount) == 0
                            expect(reportRequestCount) == 1
                        }
                        it("creates a REPORT request") {
                            //REPORT request url has the form https://<host>/msdk/evalx/user; httpBody contains the user dictionary
                            expect(urlRequest?.url?.host) == testContext.config.baseUrl.host
                            if let path = urlRequest?.url?.path {
                                expect(path.hasSuffix(DarklyService.FlagRequestPath.report)).to(beTrue())
                            } else {
                                fail("request path is missing")
                            }
                            expect(urlRequest?.cachePolicy) == .reloadRevalidatingCacheData
                            expect(urlRequest?.timeoutInterval) == testContext.config.connectionTimeout
                            expect(urlRequest?.httpMethod) == URLRequest.HTTPMethods.report
                            expect(urlRequest?.httpBodyStream).toNot(beNil())   //Although the service sets the httpBody, OHHTTPStubs seems to convert that into an InputStream, which should be ok
                            guard let headers = urlRequest?.allHTTPHeaderFields
                            else {
                                fail("request is missing HTTP headers")
                                return
                            }
                            expect(headers[HTTPHeaders.HeaderKey.authorization]) == "\(HTTPHeaders.HeaderValue.apiKey) \(testContext.config.mobileKey)"
                            expect(headers[HTTPHeaders.HeaderKey.userAgent]) == "\(EnvironmentReportingMock.Constants.systemName)/\(EnvironmentReportingMock.Constants.sdkVersion)"
                            expect(headers[HTTPHeaders.HeaderKey.ifNoneMatch]) == testContext.flagRequestEtag
                        }
                        it("calls completion with data, response, and no error") {
                            expect(responses).toNot(beNil())
                            expect(responses?.data).toNot(beNil())
                            expect(responses?.data?.flagCollection) == testContext.flagStore.featureFlags
                            expect(responses?.urlResponse?.httpStatusCode) == HTTPURLResponse.StatusCodes.ok
                            expect(responses?.error).to(beNil())
                        }
                    }
                }
                context("failure") {
                    beforeEach {
                        waitUntil { done in
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                                    useReport: Constants.useReportMethod,
                                                                    onActivation: { _, _, _ in
                                                                        reportRequestCount += 1
                            })
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                                    useReport: Constants.useGetMethod,
                                                                    onActivation: { _, _, _ in
                                                                        getRequestCount += 1
                            })
                            testContext.service.getFeatureFlags(useReport: Constants.useReportMethod, completion: { data, response, error in
                                responses = (data, response, error)
                                done()
                            })
                        }
                    }
                    it("makes exactly one valid request") {
                        expect(getRequestCount) == 0
                        expect(reportRequestCount) == 1
                    }
                    it("calls completion with error and no data or response") {
                        expect(responses).toNot(beNil())
                        expect(responses?.data).toNot(beNil())
                        expect(responses?.data).to(beEmpty())
                        expect(responses?.urlResponse?.httpStatusCode) == HTTPURLResponse.StatusCodes.internalServerError
                        expect(responses?.error).to(beNil())
                    }
                }
                context("empty mobile key") {
                    beforeEach {
                        testContext = TestContext(mobileKey: Constants.emptyMobileKey, useReport: Constants.useReportMethod)
                        testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                useReport: Constants.useGetMethod,
                                                                onActivation: { _, _, _ in
                                                                    getRequestCount += 1
                        })
                        testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                useReport: Constants.useReportMethod,
                                                                onActivation: { _, _, _ in
                                                                    reportRequestCount += 1
                        })
                        testContext.service.getFeatureFlags(useReport: Constants.useReportMethod, completion: { data, response, error in
                            responses = (data, response, error)
                        })
                    }
                    it("does not make a request") {
                        expect(getRequestCount) == 0
                        expect(reportRequestCount) == 0
                        expect(responses).to(beNil())
                    }
                }
            }
        }
    }

    private func flagRequestEtagSpec() {
        var testContext: TestContext!
        var flagRequestEtag: String?
        describe("flagRequestEtag") {
            context("no original etag") {
                context("on success") {
                    context("response has etag") {
                        beforeEach {
                            testContext = TestContext()
                            flagRequestEtag = UUID().uuidString
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                    useReport: Constants.useGetMethod,
                                                                    flagResponseEtag: flagRequestEtag,
                                                                    onActivation: { _, _, _ in
                            })
                            waitUntil { done in
                                testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { _, _, _ in
                                    done()
                                })
                            }
                        }
                        it("sets the response etag") {
                            expect(HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]) == flagRequestEtag
                        }
                    }
                    context("response has no etag") {
                        beforeEach {
                            testContext = TestContext()
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                    useReport: Constants.useGetMethod,
                                                                    onActivation: { _, _, _ in
                            })
                            waitUntil { done in
                                testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { _, _, _ in
                                    done()
                                })
                            }
                        }
                        it("leaves the etag empty") {
                            expect(HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]).to(beNil())
                        }
                    }
                }
                context("on not modified") {
                    context("response has etag") {
                        //This should never happen, without an original etag the server should not send a 304 NOT MODIFIED. If it does ignore it.
                        beforeEach {
                            testContext = TestContext()
                            flagRequestEtag = UUID().uuidString
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.notModified,
                                                                    featureFlags: [:],
                                                                    useReport: Constants.useGetMethod,
                                                                    flagResponseEtag: flagRequestEtag,
                                                                    onActivation: { _, _, _ in
                            })
                            waitUntil { done in
                                testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { _, _, _ in
                                    done()
                                })
                            }
                        }
                        it("leaves the etag empty") {
                            expect(HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]).to(beNil())
                        }
                    }
                    context("response has no etag") {
                        //This should never happen, without an original etag the server should not send a 304 NOT MODIFIED. If it does ignore it.
                        beforeEach {
                            testContext = TestContext()
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.notModified,
                                                                    featureFlags: [:],
                                                                    useReport: Constants.useGetMethod,
                                                                    onActivation: { _, _, _ in
                            })
                            waitUntil { done in
                                testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { _, _, _ in
                                    done()
                                })
                            }
                        }
                        it("leaves the etag empty") {
                            expect(HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]).to(beNil())
                        }
                    }
                }
                context("on failure") {
                    context("response has etag") {
                        //This should never happen. The server should not send an etag with a failure status code If it does ignore it.
                        beforeEach {
                            testContext = TestContext()
                            flagRequestEtag = UUID().uuidString
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                                    useReport: Constants.useGetMethod,
                                                                    flagResponseEtag: flagRequestEtag,
                                                                    onActivation: { _, _, _ in
                            })
                            waitUntil { done in
                                testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { _, _, _ in
                                    done()
                                })
                            }
                        }
                        it("leaves the etag empty") {
                            expect(HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]).to(beNil())
                        }
                    }
                    context("response has no etag") {
                        beforeEach {
                            testContext = TestContext()
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                                    useReport: Constants.useGetMethod,
                                                                    onActivation: { _, _, _ in
                            })
                            waitUntil { done in
                                testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { _, _, _ in
                                    done()
                                })
                            }
                        }
                        it("leaves the etag empty") {
                            expect(HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]).to(beNil())
                        }
                    }
                }
            }
            context("with original etag") {
                var originalFlagRequestEtag: String!
                context("on success") {
                    context("response has an etag") {
                        context("same as original etag") {
                            beforeEach {
                                testContext = TestContext(mobileKeyCount: Constants.mobileKeyCount)
                                HTTPHeaders.loadFlagRequestEtags(testContext.flagRequestEtags)
                                originalFlagRequestEtag = HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        useReport: Constants.useGetMethod,
                                                                        flagResponseEtag: originalFlagRequestEtag,
                                                                        onActivation: { _, _, _ in
                                })
                                waitUntil { done in
                                    testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { _, _, _ in
                                        done()
                                    })
                                }
                            }
                            it("retains the original etag") {
                                expect(HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]) == originalFlagRequestEtag
                            }
                        }
                        context("different from the original etag") {
                            beforeEach {
                                testContext = TestContext(mobileKeyCount: Constants.mobileKeyCount)
                                HTTPHeaders.loadFlagRequestEtags(testContext.flagRequestEtags)
                                flagRequestEtag = UUID().uuidString
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        useReport: Constants.useGetMethod,
                                                                        flagResponseEtag: flagRequestEtag,
                                                                        onActivation: { _, _, _ in
                                })
                                waitUntil { done in
                                    testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { _, _, _ in
                                        done()
                                    })
                                }
                            }
                            it("replaces the etag") {
                                expect(HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]) == flagRequestEtag
                            }
                        }
                    }
                    context("response has no etag") {
                        beforeEach {
                            testContext = TestContext(mobileKeyCount: Constants.mobileKeyCount)
                            HTTPHeaders.loadFlagRequestEtags(testContext.flagRequestEtags)
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                    useReport: Constants.useGetMethod,
                                                                    onActivation: { _, _, _ in
                            })
                            waitUntil { done in
                                testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { _, _, _ in
                                    done()
                                })
                            }
                        }
                        it("clears the etag") {
                            expect(HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]).to(beNil())
                        }
                    }
                }
                context("on not modified") {
                    context("response has etag") {
                        context("that matches the original etag") {
                            beforeEach {
                                testContext = TestContext(mobileKeyCount: Constants.mobileKeyCount)
                                HTTPHeaders.loadFlagRequestEtags(testContext.flagRequestEtags)
                                originalFlagRequestEtag = HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.notModified,
                                                                        useReport: Constants.useGetMethod,
                                                                        flagResponseEtag: originalFlagRequestEtag,
                                                                        onActivation: { _, _, _ in
                                })
                                waitUntil { done in
                                    testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { _, _, _ in
                                        done()
                                    })
                                }
                            }
                            it("retains the etag") {
                                expect(HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]) == originalFlagRequestEtag
                            }
                        }
                        context("that differs from the original etag") {
                            //This should not happen. If the response was not modified then the etags should match. In that case ignore the new etag
                            beforeEach {
                                testContext = TestContext(mobileKeyCount: Constants.mobileKeyCount)
                                HTTPHeaders.loadFlagRequestEtags(testContext.flagRequestEtags)
                                originalFlagRequestEtag = HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]
                                flagRequestEtag = UUID().uuidString
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.notModified,
                                                                        useReport: Constants.useGetMethod,
                                                                        flagResponseEtag: flagRequestEtag,
                                                                        onActivation: { _, _, _ in
                                })
                                waitUntil { done in
                                    testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { _, _, _ in
                                        done()
                                    })
                                }
                            }
                            it("retains the original etag") {
                                expect(HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]) == originalFlagRequestEtag
                            }
                        }
                    }
                    context("response has no etag") {
                        //This should not happen. If the response was not modified then the etags should match. In that case ignore the new etag
                        beforeEach {
                            testContext = TestContext(mobileKeyCount: Constants.mobileKeyCount)
                            HTTPHeaders.loadFlagRequestEtags(testContext.flagRequestEtags)
                            originalFlagRequestEtag = HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]
                            flagRequestEtag = UUID().uuidString
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.notModified,
                                                                    useReport: Constants.useGetMethod,
                                                                    onActivation: { _, _, _ in
                            })
                            waitUntil { done in
                                testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { _, _, _ in
                                    done()
                                })
                            }
                        }
                        it("retains the original etag") {
                            expect(HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]) == originalFlagRequestEtag
                        }
                    }
                }
                context("on failure") {
                    context("response has etag") {
                        //This should not happen. If the response was an error then there should be no new etag. Because of the error, clear the etag
                        beforeEach {
                            testContext = TestContext(mobileKeyCount: Constants.mobileKeyCount)
                            HTTPHeaders.loadFlagRequestEtags(testContext.flagRequestEtags)
                            originalFlagRequestEtag = HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]
                            flagRequestEtag = UUID().uuidString
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                                    useReport: Constants.useGetMethod,
                                                                    flagResponseEtag: flagRequestEtag,
                                                                    onActivation: { _, _, _ in
                            })
                            waitUntil { done in
                                testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { _, _, _ in
                                    done()
                                })
                            }
                        }
                        it("clears the etag") {
                            expect(HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]).to(beNil())
                        }
                    }
                    context("response has no etag") {
                        beforeEach {
                            testContext = TestContext(mobileKeyCount: Constants.mobileKeyCount)
                            HTTPHeaders.loadFlagRequestEtags(testContext.flagRequestEtags)
                            originalFlagRequestEtag = HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                                    useReport: Constants.useGetMethod,
                                                                    onActivation: { _, _, _ in
                            })
                            waitUntil { done in
                                testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { _, _, _ in
                                    done()
                                })
                            }
                        }
                        it("clears the etag") {
                            expect(HTTPHeaders.flagRequestEtags[testContext.config.mobileKey]).to(beNil())
                        }
                    }
                }
            }
        }
    }

    private func clearFlagRequestCacheSpec() {
        var testContext: TestContext!
        var flagRequestEtag: String!
        var urlRequest: URLRequest!
        var serviceResponse: ServiceResponse!
        describe("clearFlagResponseCache") {
            context("cached responses and etags exist") {
                beforeEach {
                    testContext = TestContext(mobileKeyCount: Constants.mobileKeyCount)
                    HTTPHeaders.loadFlagRequestEtags(testContext.flagRequestEtags)
                    flagRequestEtag = UUID().uuidString
                    testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                            useReport: Constants.useGetMethod,
                                                            flagResponseEtag: flagRequestEtag,
                                                            onActivation: { request, _, _ in
                                                                urlRequest = request
                    })
                    waitUntil { done in
                        testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { error, response, data in
                            serviceResponse = (error, response, data)
                            done()
                        })
                    }
                    URLCache.shared.storeResponse(serviceResponse, for: urlRequest)

                    testContext.service.clearFlagResponseCache()
                }
                it("removes cached responses and etags") {
                    expect(HTTPHeaders.flagRequestEtags.isEmpty).to(beTrue())
                    expect(URLCache.shared.cachedResponse(for: urlRequest)).to(beNil())
                }
            }
        }
    }

    private func createEventSourceSpec() {
        var testContext: TestContext!

        describe("createEventSource") {
            var eventSource: DarklyStreamingProviderMock?
            context("when using GET method to connect") {
                beforeEach {
                    testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: Constants.useGetMethod)
                    eventSource = testContext.service.createEventSource(useReport: Constants.useGetMethod, handler: EventHandlerMock(), errorHandler: nil) as? DarklyStreamingProviderMock
                }
                it("creates an event source that makes valid GET request") {
                    expect(eventSource).toNot(beNil())
                    expect(testContext.serviceFactoryMock?.makeStreamingProviderCallCount) == 1
                    expect(testContext.serviceFactoryMock?.makeStreamingProviderReceivedArguments).toNot(beNil())
                    let receivedArguments = testContext.serviceFactoryMock?.makeStreamingProviderReceivedArguments
                    expect(receivedArguments!.url.host) == testContext.config.streamUrl.host
                    expect(receivedArguments!.url.pathComponents.contains(DarklyService.StreamRequestPath.meval)).to(beTrue())
                    expect(receivedArguments!.url.pathComponents.contains(DarklyService.StreamRequestPath.mping)).to(beFalse())
                    expect(LDUser(base64urlEncodedString: receivedArguments!.url.lastPathComponent)?.isEqual(to: testContext.user)) == true
                    expect(receivedArguments!.httpHeaders).toNot(beEmpty())
                    expect(receivedArguments!.connectMethod).to(beNil())
                    expect(receivedArguments!.connectBody).to(beNil())
                }
            }
            context("when using REPORT method to connect") {
                beforeEach {
                    testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: Constants.useReportMethod)
                    eventSource = testContext.service.createEventSource(useReport: Constants.useReportMethod, handler: EventHandlerMock(), errorHandler: nil) as? DarklyStreamingProviderMock
                }
                it("creates an event source that makes valid REPORT request") {
                    expect(eventSource).toNot(beNil())
                    expect(testContext.serviceFactoryMock?.makeStreamingProviderCallCount) == 1
                    expect(testContext.serviceFactoryMock?.makeStreamingProviderReceivedArguments).toNot(beNil())
                    let receivedArguments = testContext.serviceFactoryMock?.makeStreamingProviderReceivedArguments
                    expect(receivedArguments!.url.host) == testContext.config.streamUrl.host
                    expect(receivedArguments!.url.lastPathComponent) == DarklyService.StreamRequestPath.meval
                    expect(receivedArguments!.url.pathComponents.contains(DarklyService.StreamRequestPath.mping)).to(beFalse())
                    expect(receivedArguments!.httpHeaders).toNot(beEmpty())
                    expect(receivedArguments!.connectMethod) == DarklyService.HTTPRequestMethod.report
                    expect(LDUser(data: receivedArguments!.connectBody)?.isEqual(to: testContext.user)) == true
                }
            }
        }
    }

    private func publishEventDictionariesSpec() {
        var testContext: TestContext!

        describe("publishEventDictionaries") {
            var eventRequest: URLRequest?

            beforeEach {
                eventRequest = nil
                testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: Constants.useGetMethod, includeMockEventDictionaries: true)
            }
            context("success") {
                var responses: ServiceResponses!
                beforeEach {
                    waitUntil { done in
                        testContext.serviceMock.stubEventRequest(success: true) { request, _, _ in
                            eventRequest = request
                        }
                        testContext.service.publishEventDictionaries(testContext.mockEventDictionaries!, UUID().uuidString) { data, response, error in
                            responses = (data, response, error)
                            done()
                        }
                    }
                }
                it("makes a valid request") {
                    expect(eventRequest).toNot(beNil())
                    expect(eventRequest?.allHTTPHeaderFields?[HTTPHeaders.HeaderKey.eventSchema]) == HTTPHeaders.HeaderValue.eventSchema3
                    expect(eventRequest?.allHTTPHeaderFields?[HTTPHeaders.HeaderKey.eventPayloadIDHeader]?.count) == 36
                }
                it("calls completion with data, response, and no error") {
                    expect(responses.data).toNot(beNil())
                    expect(responses.urlResponse).toNot(beNil())
                    expect(responses.error).to(beNil())
                }
            }
            context("failure") {
                var responses: ServiceResponses!
                beforeEach {
                    waitUntil { done in
                        testContext.serviceMock.stubEventRequest(success: false) { request, _, _ in
                            eventRequest = request
                        }
                        testContext.service.publishEventDictionaries(testContext.mockEventDictionaries!, UUID().uuidString) { data, response, error in
                            responses = (data, response, error)
                            done()
                        }
                    }
                }
                it("makes a valid request") {
                    expect(eventRequest).toNot(beNil())
                    expect(eventRequest?.allHTTPHeaderFields?[HTTPHeaders.HeaderKey.eventSchema]) == HTTPHeaders.HeaderValue.eventSchema3
                    expect(eventRequest?.allHTTPHeaderFields?[HTTPHeaders.HeaderKey.eventPayloadIDHeader]?.count) == 36
                }
                it("calls completion with error and no data or response") {
                    expect(responses.data?.isEmpty ?? true) == true
                    expect(responses.urlResponse).to(beNil())
                    expect(responses.error).toNot(beNil())
                }
            }
            context("empty mobile key") {
                var responses: ServiceResponses!
                var eventsPublished = false
                beforeEach {
                    testContext = TestContext(mobileKey: Constants.emptyMobileKey, useReport: Constants.useGetMethod, includeMockEventDictionaries: true)
                    testContext.serviceMock.stubEventRequest(success: true) { request, _, _ in
                        eventRequest = request
                    }
                    testContext.service.publishEventDictionaries(testContext.mockEventDictionaries!, UUID().uuidString) { data, response, error in
                        responses = (data, response, error)
                        eventsPublished = true
                    }
                }
                it("does not make a request") {
                    expect(eventRequest).to(beNil())
                    expect(eventsPublished) == false
                    expect(responses).to(beNil())
                }
            }
            context("empty event list") {
                var responses: ServiceResponses!
                var eventsPublished = false
                let emptyEventDictionaryList: [[String: Any]] = []
                beforeEach {
                    testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: Constants.useGetMethod, includeMockEventDictionaries: true)
                    testContext.serviceMock.stubEventRequest(success: true) { request, _, _ in
                        eventRequest = request
                    }
                    testContext.service.publishEventDictionaries(emptyEventDictionaryList, "") { data, response, error in
                        responses = (data, response, error)
                        eventsPublished = true
                    }
                }
                it("does not make a request") {
                    expect(eventRequest).to(beNil())
                    expect(eventsPublished) == false
                    expect(responses).to(beNil())
                }
            }
        }
    }

    private func diagnosticCacheSpec() {
        var testContext: TestContext!
        describe("diagnosticCache") {
            context("empty mobileKey") {
                it("does not create cache") {
                    testContext = TestContext(mobileKey: "")
                    expect(testContext.service.diagnosticCache).to(beNil())
                    expect(testContext.serviceFactoryMock?.makeDiagnosticCacheCallCount) == 0
                }
            }
            context("diagnosticOptOut true") {
                it("does not create cache") {
                    testContext = TestContext(diagnosticOptOut: true)
                    expect(testContext.service.diagnosticCache).to(beNil())
                    expect(testContext.serviceFactoryMock?.makeDiagnosticCacheCallCount) == 0
                }
            }
            context("diagnosticOptOut false") {
                it("creates a cache with the mobile key") {
                    testContext = TestContext(diagnosticOptOut: false)
                    expect(testContext.service.diagnosticCache).toNot(beNil())
                    expect(testContext.serviceFactoryMock?.makeDiagnosticCacheCallCount) == 1
                    expect(testContext.serviceFactoryMock?.makeDiagnosticCacheReceivedSdkKey) == LDConfig.Constants.mockMobileKey
                }
            }
        }
    }

    private func stubDiagnostic() -> DiagnosticStats {
        DiagnosticStats(id: DiagnosticId(diagnosticId: "test-id", sdkKey: LDConfig.Constants.mockMobileKey), creationDate: 1000, dataSinceDate: 100, droppedEvents: 0, eventsInLastBatch: 0, streamInits: [])
    }

    private func publishDiagnosticSpec() {
        var testContext: TestContext!

        describe("publishDiagnostic") {
            var diagnosticRequest: URLRequest?

            beforeEach {
                diagnosticRequest = nil
                testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey)
            }
            context("success") {
                var responses: ServiceResponses!
                beforeEach {
                    waitUntil { done in
                        testContext.serviceMock.stubDiagnosticRequest(success: true) { request, _, _ in
                            diagnosticRequest = request
                        }
                        testContext.service.publishDiagnostic(diagnosticEvent: self.stubDiagnostic()) { data, response, error in
                            responses = (data, response, error)
                            done()
                        }
                    }
                }
                it("makes a valid request") {
                    expect(diagnosticRequest).toNot(beNil())
                    expect(diagnosticRequest?.httpMethod) == URLRequest.HTTPMethods.post
                    // Unfortunately, we can't actually test the body here, see:
                    // https://github.com/AliSoftware/OHHTTPStubs#known-limitations
                    //expect(diagnosticRequest?.httpBody) == try? JSONEncoder().encode(self.stubDiagnostic())

                    // Actual header values are tested in HTTPHeadersSpec
                    for (key, value) in testContext.httpHeaders.diagnosticRequestHeaders {
                        expect(diagnosticRequest?.allHTTPHeaderFields?[key]) == value
                    }
                }
                it("calls completion with data, response, and no error") {
                    expect(responses.data).toNot(beNil())
                    expect(responses.urlResponse).toNot(beNil())
                    expect(responses.error).to(beNil())
                }
            }
            context("failure") {
                var responses: ServiceResponses!
                beforeEach {
                    waitUntil { done in
                        testContext.serviceMock.stubEventRequest(success: false) { request, _, _ in
                            diagnosticRequest = request
                        }
                        testContext.service.publishDiagnostic(diagnosticEvent: self.stubDiagnostic()) { data, response, error in
                            responses = (data, response, error)
                            done()
                        }
                    }
                }
                it("makes a valid request") {
                    expect(diagnosticRequest).toNot(beNil())
                    expect(diagnosticRequest?.httpMethod) == URLRequest.HTTPMethods.post
                    // Unfortunately, we can't actually test the body here, see:
                    // https://github.com/AliSoftware/OHHTTPStubs#known-limitations
                    //expect(diagnosticRequest?.httpBody) == try? JSONEncoder().encode(self.stubDiagnostic())

                    // Actual header values are tested in HTTPHeadersSpec
                    for (key, value) in testContext.httpHeaders.diagnosticRequestHeaders {
                        expect(diagnosticRequest?.allHTTPHeaderFields?[key]) == value
                    }
                }
                it("calls completion with error and no data or response") {
                    expect(responses.data?.isEmpty ?? true) == true
                    expect(responses.urlResponse).to(beNil())
                    expect(responses.error).toNot(beNil())
                }
            }
            context("empty mobile key") {
                var diagnosticPublished = false
                beforeEach {
                    testContext = TestContext(mobileKey: Constants.emptyMobileKey)
                    testContext.serviceMock.stubDiagnosticRequest(success: true) { request, _, _ in
                        diagnosticRequest = request
                    }
                    testContext.service.publishDiagnostic(diagnosticEvent: self.stubDiagnostic()) { _ in
                        diagnosticPublished = true
                    }
                }
                it("does not make a request") {
                    expect(diagnosticRequest).to(beNil())
                    expect(diagnosticPublished) == false
                }
            }
        }
    }
}

extension DarklyService.StreamRequestPath {
    static let mping = "mping"
}

extension LDUser {
    init?(base64urlEncodedString: String) {
        let base64encodedString = base64urlEncodedString.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        self.init(data: Data(base64Encoded: base64encodedString))
    }

    init?(data: Data?) {
        guard let data = data,
            let userDictionary = try? JSONSerialization.jsonDictionary(with: data)
        else { return nil }
        self.init(userDictionary: userDictionary)
    }
}

extension HTTPHeaders {
    static func loadFlagRequestEtags(_ flagRequestEtags: [String: String]) {
        flagRequestEtags.forEach { mobileKey, etag in
            HTTPHeaders.setFlagRequestEtag(etag, for: mobileKey)
        }
    }
}
