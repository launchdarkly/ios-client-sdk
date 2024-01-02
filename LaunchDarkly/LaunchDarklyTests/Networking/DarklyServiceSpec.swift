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
        static let useGetMethod = false
        static let useReportMethod = true
    }

    struct TestContext {
        let context = LDContext.stub()
        var config: LDConfig!
        var envReporterMock = EnvironmentReportingMock()
        var serviceMock: DarklyServiceMock!
        var serviceFactoryMock: ClientServiceMockFactory = ClientServiceMockFactory()
        var service: DarklyService!
        var httpHeaders: HTTPHeaders
        let stubFlags = FlagMaintainingMock.stubStoredItems()

        init(mobileKey: String = LDConfig.Constants.mockMobileKey,
             useReport: Bool = Constants.useGetMethod,
             diagnosticOptOut: Bool = false) {

            config = LDConfig.stub(mobileKey: mobileKey, autoEnvAttributes: .disabled, isDebugBuild: true)
            config.useReport = useReport
            config.diagnosticOptOut = diagnosticOptOut
            serviceMock = DarklyServiceMock(config: config)
            service = DarklyService(config: config, context: context, envReporter: envReporterMock, serviceFactory: serviceFactoryMock)
            httpHeaders = HTTPHeaders(config: config, environmentReporter: envReporterMock)
        }

        func runStubbedGet(statusCode: Int, featureFlags: [LDFlagKey: FeatureFlag]? = nil, flagResponseEtag: String? = nil) {
            serviceMock.stubFlagRequest(statusCode: statusCode, useReport: config.useReport, flagResponseEtag: flagResponseEtag)
            waitUntil { done in
                self.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { _ in
                    done()
                })
            }
        }
    }

    override func spec() {
        getFeatureFlagsSpec()
        flagRequestEtagSpec()
        clearFlagRequestCacheSpec()
        createEventSourceSpec()
        publishEventDataSpec()
        diagnosticCacheSpec()
        publishDiagnosticSpec()

        afterEach {
            HTTPStubs.removeAllStubs()
        }
    }

    private func getFeatureFlagsSpec() {
        var testContext: TestContext!
        var requestEtag: String!

        describe("getFeatureFlags") {
            var responses: ServiceResponses?
            var getRequestCount = 0
            var reportRequestCount = 0
            var urlRequest: URLRequest?
            beforeEach {
                requestEtag = UUID().uuidString
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
                                                                        featureFlags: testContext.stubFlags.featureFlags,
                                                                        useReport: Constants.useReportMethod,
                                                                        onActivation: { _ in
                                                                            reportRequestCount += 1
                                })
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        featureFlags: testContext.stubFlags.featureFlags,
                                                                        useReport: Constants.useGetMethod,
                                                                        onActivation: { request in
                                                                            getRequestCount += 1
                                                                            urlRequest = request
                                })
                                testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { response in
                                    responses = (response.data, response.urlResponse, response.error)
                                    done()
                                })
                            }
                        }
                        it("makes exactly one valid GET request") {
                            expect(getRequestCount) == 1
                            expect(reportRequestCount) == 0
                        }
                        it("creates a GET request") {
                            // GET request url has the form https://<host>/msdk/evalx/contexts/<base64encodedContext>
                            expect(urlRequest?.url?.host) == testContext.config.baseUrl.host
                            if let path = urlRequest?.url?.path {
                                expect(path.hasPrefix("/\(DarklyService.FlagRequestPath.get)")).to(beTrue())
                                let expectedContext = encodeToLDValue(testContext.context, userInfo: [LDContext.UserInfoKeys.includePrivateAttributes: true, LDContext.UserInfoKeys.redactAttributes: false])
                                expect(urlRequest?.url?.lastPathComponent.jsonValue) == expectedContext
                            } else {
                                fail("request path is missing")
                            }
                            expect(urlRequest?.cachePolicy) == .reloadIgnoringLocalCacheData
                            expect(urlRequest?.timeoutInterval) == testContext.config.connectionTimeout
                            expect(urlRequest?.httpMethod) == URLRequest.HTTPMethods.get
                            expect(urlRequest?.httpBody).to(beNil())
                            expect(urlRequest?.httpBodyStream).to(beNil())
                            expect(urlRequest?.allHTTPHeaderFields) == testContext.httpHeaders.flagRequestHeaders
                        }
                        it("calls completion with data, response, and no error") {
                            expect(responses).toNot(beNil())
                            expect(responses?.data).toNot(beNil())
                            expect(responses?.data?.flagCollection) == testContext.stubFlags.featureFlags
                            expect(responses?.urlResponse?.httpStatusCode) == HTTPURLResponse.StatusCodes.ok
                            expect(responses?.error).to(beNil())
                        }
                    }
                    context("with flag request etag") {
                        beforeEach {
                            testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: Constants.useGetMethod)
                            testContext.service.flagRequestEtag = requestEtag
                            waitUntil { done in
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        featureFlags: testContext.stubFlags.featureFlags,
                                                                        useReport: Constants.useReportMethod,
                                                                        onActivation: { _ in
                                                                            reportRequestCount += 1
                                })
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        featureFlags: testContext.stubFlags.featureFlags,
                                                                        useReport: Constants.useGetMethod,
                                                                        onActivation: { request in
                                                                            getRequestCount += 1
                                                                            urlRequest = request
                                })
                                testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { response in
                                    responses = (response.data, response.urlResponse, response.error)
                                    done()
                                })
                            }
                        }
                        it("makes exactly one valid GET request") {
                            expect(getRequestCount) == 1
                            expect(reportRequestCount) == 0
                        }
                        it("creates a GET request") {
                            // GET request url has the form https://<host>/msdk/evalx/contexts/<base64encodedContext>
                            expect(urlRequest?.url?.host) == testContext.config.baseUrl.host
                            if let path = urlRequest?.url?.path {
                                expect(path.hasPrefix("/\(DarklyService.FlagRequestPath.get)")).to(beTrue())
                                let expectedContext = encodeToLDValue(testContext.context, userInfo: [LDContext.UserInfoKeys.includePrivateAttributes: true, LDContext.UserInfoKeys.redactAttributes: false])
                                expect(urlRequest?.url?.lastPathComponent.jsonValue) == expectedContext
                            } else {
                                fail("request path is missing")
                            }
                            expect(urlRequest?.cachePolicy) == .reloadIgnoringLocalCacheData
                            expect(urlRequest?.timeoutInterval) == testContext.config.connectionTimeout
                            expect(urlRequest?.httpMethod) == URLRequest.HTTPMethods.get
                            expect(urlRequest?.httpBody).to(beNil())
                            expect(urlRequest?.httpBodyStream).to(beNil())
                            var headers = urlRequest?.allHTTPHeaderFields
                            expect(headers?.removeValue(forKey: HTTPHeaders.HeaderKey.ifNoneMatch)) == requestEtag
                            expect(headers) == testContext.httpHeaders.flagRequestHeaders
                        }
                        it("calls completion with data, response, and no error") {
                            expect(responses).toNot(beNil())
                            expect(responses?.data).toNot(beNil())
                            expect(responses?.data?.flagCollection) == testContext.stubFlags.featureFlags
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
                                                                    onActivation: { _ in
                                                                        reportRequestCount += 1
                            })
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                                    useReport: Constants.useGetMethod,
                                                                    onActivation: { _ in
                                                                        getRequestCount += 1
                            })
                            testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { response in
                                responses = (response.data, response.urlResponse, response.error)
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
                        testContext = TestContext(mobileKey: "", useReport: Constants.useGetMethod)
                        testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                useReport: Constants.useReportMethod,
                                                                onActivation: { _ in
                                                                    reportRequestCount += 1
                        })
                        testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                useReport: Constants.useGetMethod,
                                                                onActivation: { _ in
                            getRequestCount += 1
                        })
                        testContext.service.getFeatureFlags(useReport: Constants.useGetMethod, completion: { response in
                            responses = (response.data, response.urlResponse, response.error)
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
                    context("without a flag request etag") {
                        beforeEach {
                            waitUntil { done in
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        featureFlags: testContext.stubFlags.featureFlags,
                                                                        useReport: Constants.useGetMethod,
                                                                        onActivation: { _ in
                                                                            getRequestCount += 1
                                })
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        featureFlags: testContext.stubFlags.featureFlags,
                                                                        useReport: Constants.useReportMethod,
                                                                        onActivation: { request in
                                                                            reportRequestCount += 1
                                                                            urlRequest = request
                                })
                                testContext.service.getFeatureFlags(useReport: Constants.useReportMethod, completion: { response in
                                    responses = (response.data, response.urlResponse, response.error)
                                    done()
                                })
                            }
                        }
                        it("makes exactly one valid REPORT request") {
                            expect(getRequestCount) == 0
                            expect(reportRequestCount) == 1
                        }
                        it("creates a REPORT request") {
                            // REPORT request url has the form https://<host>/msdk/evalx/context; httpBody contains the context dictionary
                            expect(urlRequest?.url?.host) == testContext.config.baseUrl.host
                            if let path = urlRequest?.url?.path {
                                expect(path.hasSuffix(DarklyService.FlagRequestPath.report)).to(beTrue())
                            } else {
                                fail("request path is missing")
                            }
                            expect(urlRequest?.cachePolicy) == .reloadIgnoringLocalCacheData
                            expect(urlRequest?.timeoutInterval) == testContext.config.connectionTimeout
                            expect(urlRequest?.httpMethod) == URLRequest.HTTPMethods.report
                            expect(urlRequest?.httpBodyStream).toNot(beNil())   // Although the service sets the httpBody, OHHTTPStubs seems to convert that into an InputStream, which should be ok
                            var headers = urlRequest?.allHTTPHeaderFields
                            expect(headers?.removeValue(forKey: "Content-Length")).toNot(beNil())
                            expect(headers) == testContext.httpHeaders.flagRequestHeaders
                        }
                        it("calls completion with data, response, and no error") {
                            expect(responses).toNot(beNil())
                            expect(responses?.data).toNot(beNil())
                            expect(responses?.data?.flagCollection) == testContext.stubFlags.featureFlags
                            expect(responses?.urlResponse?.httpStatusCode) == HTTPURLResponse.StatusCodes.ok
                            expect(responses?.error).to(beNil())
                        }
                    }
                    context("with a flag requesst etag") {
                        beforeEach {
                            testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: Constants.useReportMethod)
                            testContext.service.flagRequestEtag = requestEtag
                            waitUntil { done in
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        featureFlags: testContext.stubFlags.featureFlags,
                                                                        useReport: Constants.useGetMethod,
                                                                        onActivation: { _ in
                                                                            getRequestCount += 1
                                })
                                testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                        featureFlags: testContext.stubFlags.featureFlags,
                                                                        useReport: Constants.useReportMethod,
                                                                        onActivation: { request in
                                                                            reportRequestCount += 1
                                                                            urlRequest = request
                                })
                                testContext.service.getFeatureFlags(useReport: Constants.useReportMethod, completion: { response in
                                    responses = (response.data, response.urlResponse, response.error)
                                    done()
                                })
                            }
                        }
                        it("makes exactly one valid REPORT request") {
                            expect(getRequestCount) == 0
                            expect(reportRequestCount) == 1
                        }
                        it("creates a REPORT request") {
                            // REPORT request url has the form https://<host>/msdk/evalx/context; httpBody contains the context dictionary
                            expect(urlRequest?.url?.host) == testContext.config.baseUrl.host
                            if let path = urlRequest?.url?.path {
                                expect(path.hasSuffix(DarklyService.FlagRequestPath.report)).to(beTrue())
                            } else {
                                fail("request path is missing")
                            }
                            expect(urlRequest?.cachePolicy) == .reloadIgnoringLocalCacheData
                            expect(urlRequest?.timeoutInterval) == testContext.config.connectionTimeout
                            expect(urlRequest?.httpMethod) == URLRequest.HTTPMethods.report
                            expect(urlRequest?.httpBodyStream).toNot(beNil())   // Although the service sets the httpBody, OHHTTPStubs seems to convert that into an InputStream, which should be ok
                            var headers = urlRequest?.allHTTPHeaderFields
                            expect(headers?.removeValue(forKey: "Content-Length")).toNot(beNil())
                            expect(headers?.removeValue(forKey: HTTPHeaders.HeaderKey.ifNoneMatch)) == requestEtag
                            expect(headers) == testContext.httpHeaders.flagRequestHeaders
                        }
                        it("calls completion with data, response, and no error") {
                            expect(responses).toNot(beNil())
                            expect(responses?.data).toNot(beNil())
                            expect(responses?.data?.flagCollection) == testContext.stubFlags.featureFlags
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
                                                                    onActivation: { _ in
                                                                        reportRequestCount += 1
                            })
                            testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                                    useReport: Constants.useGetMethod,
                                                                    onActivation: { _ in
                                                                        getRequestCount += 1
                            })
                            testContext.service.getFeatureFlags(useReport: Constants.useReportMethod, completion: { response in
                                responses = (response.data, response.urlResponse, response.error)
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
                        testContext = TestContext(mobileKey: "", useReport: Constants.useReportMethod)
                        testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                useReport: Constants.useGetMethod,
                                                                onActivation: { _ in
                                                                    getRequestCount += 1
                        })
                        testContext.serviceMock.stubFlagRequest(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                                useReport: Constants.useReportMethod,
                                                                onActivation: { _ in
                                                                    reportRequestCount += 1
                        })
                        testContext.service.getFeatureFlags(useReport: Constants.useReportMethod, completion: { response in
                            responses = (response.data, response.urlResponse, response.error)
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
        var originalFlagRequestEtag: String!
        var testContext: TestContext!
        describe("flagRequestEtag") {
            beforeEach {
                testContext = TestContext()
            }
            context("no request etag") {
                context("on success") {
                    it("sets the etag") {
                        let flagRequestEtag = UUID().uuidString
                        testContext.runStubbedGet(statusCode: HTTPURLResponse.StatusCodes.ok, flagResponseEtag: flagRequestEtag)
                        expect(testContext.service.flagRequestEtag) == flagRequestEtag
                    }
                    it("clears the etag") {
                        testContext.runStubbedGet(statusCode: HTTPURLResponse.StatusCodes.ok)
                        expect(testContext.service.flagRequestEtag).to(beNil())
                    }
                }
                // This should never happen, without an original etag the server should not send a 304 NOT MODIFIED. If it does ignore it.
                context("on not modified") {
                    it("leaves empty when set in response") {
                        testContext.runStubbedGet(statusCode: HTTPURLResponse.StatusCodes.notModified,
                                                  featureFlags: [:],
                                                  flagResponseEtag: UUID().uuidString)
                        expect(testContext.service.flagRequestEtag).to(beNil())
                    }
                    it("leaves empty") {
                        testContext.runStubbedGet(statusCode: HTTPURLResponse.StatusCodes.notModified,
                                                  featureFlags: [:])
                        expect(testContext.service.flagRequestEtag).to(beNil())
                    }
                }
                context("on failure") {
                    it("leaves empty when set in response") {
                        // This should never happen. The server should not send an etag with a failure status code If it does ignore it.
                        testContext.runStubbedGet(statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                  flagResponseEtag: UUID().uuidString)
                        expect(testContext.service.flagRequestEtag).to(beNil())
                    }
                    it("leaves the etag empty") {
                        testContext.runStubbedGet(statusCode: HTTPURLResponse.StatusCodes.internalServerError)
                        expect(testContext.service.flagRequestEtag).to(beNil())
                    }
                }
            }
            context("with request etag") {
                beforeEach {
                    originalFlagRequestEtag = UUID().uuidString
                    testContext.service.flagRequestEtag = originalFlagRequestEtag
                }
                context("on success") {
                    it("response has same etag") {
                        testContext.runStubbedGet(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                  flagResponseEtag: originalFlagRequestEtag)
                        expect(testContext.service.flagRequestEtag) == originalFlagRequestEtag
                    }
                    it("response has different etag") {
                        let flagRequestEtag = UUID().uuidString
                        testContext.runStubbedGet(statusCode: HTTPURLResponse.StatusCodes.ok,
                                                  flagResponseEtag: flagRequestEtag)
                        expect(testContext.service.flagRequestEtag) == flagRequestEtag
                    }
                    it("response has no etag") {
                        testContext.runStubbedGet(statusCode: HTTPURLResponse.StatusCodes.ok)
                        expect(testContext.service.flagRequestEtag).to(beNil())
                    }
                }
                context("on not modified") {
                    it("response has same etag") {
                        testContext.runStubbedGet(statusCode: HTTPURLResponse.StatusCodes.notModified,
                                                  flagResponseEtag: originalFlagRequestEtag)
                        expect(testContext.service.flagRequestEtag) == originalFlagRequestEtag
                    }
                    it("response has different etag") {
                        // This should not happen. If the response was not modified then the etags should match. In that case ignore the new etag
                        testContext.runStubbedGet(statusCode: HTTPURLResponse.StatusCodes.notModified,
                                                  flagResponseEtag: UUID().uuidString)
                        expect(testContext.service.flagRequestEtag) == originalFlagRequestEtag
                    }
                    it("response has no etag") {
                        // This should not happen. If the response was not modified then the etags should match. In that case ignore the new etag
                        testContext.runStubbedGet(statusCode: HTTPURLResponse.StatusCodes.notModified)
                        expect(testContext.service.flagRequestEtag) == originalFlagRequestEtag
                    }
                }
                context("on failure") {
                    it("response has etag") {
                        // This should not happen. If the response was an error then there should be no new etag. Because of the error, clear the etag
                        testContext.runStubbedGet(statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                                  flagResponseEtag: UUID().uuidString)
                        expect(testContext.service.flagRequestEtag).to(beNil())
                    }
                    it("response has no etag") {
                        testContext.runStubbedGet(statusCode: HTTPURLResponse.StatusCodes.internalServerError)
                        expect(testContext.service.flagRequestEtag).to(beNil())
                    }
                }
            }
        }
    }

    private func clearFlagRequestCacheSpec() {
        describe("clearFlagResponseCache") {
            it("clears cached etag") {
                let testContext = TestContext()
                testContext.service.flagRequestEtag = UUID().uuidString
                testContext.service.resetFlagResponseCache(etag: nil)
                expect(testContext.service.flagRequestEtag).to(beNil())
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
                    expect(testContext.serviceFactoryMock.makeStreamingProviderCallCount) == 1
                    expect(testContext.serviceFactoryMock.makeStreamingProviderReceivedArguments).toNot(beNil())
                    let receivedArguments = testContext.serviceFactoryMock.makeStreamingProviderReceivedArguments
                    expect(receivedArguments!.url.host) == testContext.config.streamUrl.host
                    expect(receivedArguments!.url.pathComponents.contains(DarklyService.StreamRequestPath.meval)).to(beTrue())
                    let expectedContext = encodeToLDValue(testContext.context, userInfo: [LDContext.UserInfoKeys.includePrivateAttributes: true, LDContext.UserInfoKeys.redactAttributes: false])
                    expect(receivedArguments!.url.lastPathComponent.jsonValue) == expectedContext
                    expect(receivedArguments!.httpHeaders).toNot(beEmpty())
                    expect(receivedArguments!.connectMethod).to(be("GET"))
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
                    expect(testContext.serviceFactoryMock.makeStreamingProviderCallCount) == 1
                    expect(testContext.serviceFactoryMock.makeStreamingProviderReceivedArguments).toNot(beNil())
                    let receivedArguments = testContext.serviceFactoryMock.makeStreamingProviderReceivedArguments
                    expect(receivedArguments!.url.host) == testContext.config.streamUrl.host
                    expect(receivedArguments!.url.lastPathComponent) == DarklyService.StreamRequestPath.meval
                    expect(receivedArguments!.httpHeaders).toNot(beEmpty())
                    expect(receivedArguments!.connectMethod) == DarklyService.HTTPRequestMethod.report
                    let expectedContext = encodeToLDValue(testContext.context, userInfo: [LDContext.UserInfoKeys.includePrivateAttributes: true, LDContext.UserInfoKeys.redactAttributes: false])
                    expect(try? JSONDecoder().decode(LDValue.self, from: receivedArguments!.connectBody!)) == expectedContext
                }
            }
        }
    }

    private func publishEventDataSpec() {
        let testData = Data("abc".utf8)
        var testContext: TestContext!

        describe("publishEventData") {
            var eventRequest: URLRequest?

            beforeEach {
                eventRequest = nil
                testContext = TestContext(mobileKey: LDConfig.Constants.mockMobileKey, useReport: Constants.useGetMethod)
            }
            context("success") {
                var responses: ServiceResponses!
                beforeEach {
                    waitUntil { done in
                        testContext.serviceMock.stubEventRequest(success: true) { eventRequest = $0 }
                        testContext.service.publishEventData(testData, UUID().uuidString) { response in
                            responses = (response.data, response.urlResponse, response.error)
                            done()
                        }
                    }
                }
                it("makes a valid request") {
                    expect(eventRequest).toNot(beNil())
                    expect(eventRequest?.allHTTPHeaderFields?[HTTPHeaders.HeaderKey.eventSchema]) == HTTPHeaders.HeaderValue.eventSchema4
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
                        testContext.serviceMock.stubEventRequest(success: false) { eventRequest = $0 }
                        testContext.service.publishEventData(testData, UUID().uuidString) { response in
                            responses = (response.data, response.urlResponse, response.error)
                            done()
                        }
                    }
                }
                it("makes a valid request") {
                    expect(eventRequest).toNot(beNil())
                    expect(eventRequest?.allHTTPHeaderFields?[HTTPHeaders.HeaderKey.eventSchema]) == HTTPHeaders.HeaderValue.eventSchema4
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
                    testContext = TestContext(mobileKey: "", useReport: Constants.useGetMethod)
                    testContext.serviceMock.stubEventRequest(success: true) { eventRequest = $0 }
                    testContext.service.publishEventData(testData, UUID().uuidString) { response in
                        responses = (response.data, response.urlResponse, response.error)
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
        describe("diagnosticCache") {
            it("does not create cache with empty mobile key") {
                let testContext = TestContext(mobileKey: "")
                expect(testContext.service.diagnosticCache).to(beNil())
                expect(testContext.serviceFactoryMock.makeDiagnosticCacheCallCount) == 0
            }
            it("does not create cache when diagnosticOptOut set") {
                let testContext = TestContext(diagnosticOptOut: true)
                expect(testContext.service.diagnosticCache).to(beNil())
                expect(testContext.serviceFactoryMock.makeDiagnosticCacheCallCount) == 0
            }
            it("creates a cache with the mobile key") {
                let testContext = TestContext(diagnosticOptOut: false)
                expect(testContext.service.diagnosticCache).toNot(beNil())
                expect(testContext.serviceFactoryMock.makeDiagnosticCacheCallCount) == 1
                expect(testContext.serviceFactoryMock.makeDiagnosticCacheReceivedSdkKey) == LDConfig.Constants.mockMobileKey
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
                        testContext.service.publishDiagnostic(diagnosticEvent: self.stubDiagnostic()) { response in
                            responses = (response.data, response.urlResponse, response.error)
                            done()
                        }
                    }
                }
                it("makes a valid request") {
                    expect(diagnosticRequest).toNot(beNil())
                    expect(diagnosticRequest?.httpMethod) == URLRequest.HTTPMethods.post
                    // Unfortunately, we can't actually test the body here, see:
                    // https://github.com/AliSoftware/OHHTTPStubs#known-limitations
                    // expect(diagnosticRequest?.httpBody) == try? JSONEncoder().encode(self.stubDiagnostic())

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
                        testContext.serviceMock.stubEventRequest(success: false) { diagnosticRequest = $0 }
                        testContext.service.publishDiagnostic(diagnosticEvent: self.stubDiagnostic()) { response in
                            responses = (response.data, response.urlResponse, response.error)
                            done()
                        }
                    }
                }
                it("makes a valid request") {
                    expect(diagnosticRequest).toNot(beNil())
                    expect(diagnosticRequest?.httpMethod) == URLRequest.HTTPMethods.post
                    // Unfortunately, we can't actually test the body here, see:
                    // https://github.com/AliSoftware/OHHTTPStubs#known-limitations
                    // expect(diagnosticRequest?.httpBody) == try? JSONEncoder().encode(self.stubDiagnostic())

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
                    testContext = TestContext(mobileKey: "")
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

private extension Data {
    var flagCollection: [LDFlagKey: FeatureFlag]? {
        return (try? JSONDecoder().decode([LDFlagKey: FeatureFlag].self, from: self))
    }
}

private extension String {
    var jsonValue: LDValue? {
        let base64encodedString = self.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: base64encodedString)
        else { return nil }
        return try? JSONDecoder().decode(LDValue.self, from: data)
    }
}
